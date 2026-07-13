# Order Management Specification

## Purpose

Define the order lifecycle — creation, state machine with SMS-bound transitions, item tracking, and cancellation — across all role devices.

## Requirements

### Requirement: Order Creation and ID Format

The system MUST generate a unique order ID per device using the format `{origen}{seq}-{MMDD}-{seq}`, e.g. `R1-0712-007`. The origin prefix identifies the creating role device (R=Redes, C=Cocina, D=Domicilio, A=Admin).

#### Scenario: Redes creates new order

- GIVEN the Redes user fills the order form with client data and items
- WHEN the user confirms the order
- THEN the system assigns an ID, sets state to `REGISTRADO`, and persists the order

### Requirement: Order State Machine (Domicilio)

Domicilio orders MUST follow the state machine: `REGISTRADO → EN_COCINA → HECHO → EN_CAMINO → ENTREGADO` or any state → `CANCELADO`. Transitions MUST be triggered by SMS receipt unless the device created the order locally.

#### Scenario: Kitchen receives PED

- GIVEN the Cocina device receives a `PED` SMS
- WHEN parsed successfully and dedup check passes
- THEN the system creates a new order with state `EN_COCINA`
- AND sends an `ACK` SMS back to the sender

#### Scenario: Full flow from PED to ENTREGADO

- GIVEN an order at state `EN_COCINA`
- WHEN Cocina marks it `HECHO`
- THEN the system sends `HEC` SMS to Domicilio
- WHEN Domicilio device receives `HEC`
- THEN the order state advances to `EN_CAMINO`
- WHEN Domicilio marks `ENTREGADO`
- THEN the system sends `ENT` SMS back to Redes
- AND the Redes device closes the order

### Requirement: Order State Machine (Mesa)

Mesa orders MUST follow the state machine: `NUEVO → EN_COCINA → HECHO → ENTREGADO_EN_MESA → PAGADO → CERRADO` or any state → `CANCELADO`. The initial state for a mesa order is `EN_COCINA` (no REGISTRADO/EN_CAMINO states).

#### Scenario: Mesero creates mesa order (shared device)

- GIVEN the Mesero is on the same device as Cocina
- WHEN the Mesero creates a `MESA` order with table number
- THEN the order is created directly in `EN_COCINA` state
- AND appears in the kitchen queue without SMS
- WHEN Cocina marks `HECHO`
- THEN the Mesero sees the order ready for delivery to the table
- WHEN Mesero marks `ENTREGADO_EN_MESA`
- THEN the order state advances to `ENTREGADO_EN_MESA`
- WHEN the client pays
- THEN the Mesero marks `PAGADO`
- AND the order is `CERRADO`

### Requirement: Order Types and Table Support

The system MUST support `DOMICILIO` and `MESA` order types. `DOMICILIO` orders include client address/reference. `MESA` orders include a `mesaId` FK to `restaurant_tables` instead of client address. The system MUST maintain a `restaurant_tables` registry with table number, capacity, status (libre/ocupada), and location.

#### Scenario: Mesa order with table assignment

- GIVEN the Mesero selects table #5
- WHEN the order is created as `MESA` type
- THEN the table status changes to `ocupada`
- AND the order links to `mesaId = 5`
- WHEN the order reaches `CERRADO`
- THEN the table status returns to `libre`

### Requirement: State History Audit Trail

Every state transition MUST be recorded in `order_state_history` with the order ID, previous state, new state, timestamp, user ID, and whether it was triggered via SMS. This enables the audit trail for Admin review and daily reconciliation.

#### Scenario: Track full state history

- GIVEN an order goes through EN_COCINA → HECHO → EN_CAMINO → ENTREGADO
- WHEN all transitions complete
- THEN the `order_state_history` table has 4 entries, one per transition
- AND each entry records the exact timestamp and triggering user

### Requirement: Cancellation with Reason

The system MUST allow cancellation from any state. Cancellation MUST require a motive (`mo` field). Cancelled orders MUST persist for audit.

#### Scenario: Cancel via CAN SMS

- GIVEN an order in `REGISTRADO` state
- WHEN the Redes device sends `CAN` SMS with motive
- THEN the order transitions to `CANCELADO`
- AND the motive is stored in `motivoCancelacion`

### Requirement: Payment Method Tracking

Every order MUST record a payment method: `EF` (cash), `TR` (transfer), or `PD` (pending). The `ENT` SMS MUST carry the final payment method and amount.

#### Scenario: Complete delivery with payment

- GIVEN Domicilio marks order as delivered
- WHEN the `ENT` SMS includes `"pg":"EF","mt":950`
- THEN the order's payment method and total amount are updated from the SMS
