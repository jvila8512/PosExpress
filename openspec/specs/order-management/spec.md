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

### Requirement: Order State Machine

Orders MUST follow the state machine: `REGISTRADO → EN_COCINA → HECHO → EN_CAMINO → ENTREGADO` or any state → `CANCELADO`. Transitions MUST be triggered by SMS receipt unless the device created the order locally.

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

### Requirement: Order Types

The system MUST support `DOMICILIO` and `MESA` order types. `DOMICILIO` orders include client address/reference. `MESA` orders include a table number instead. Both types follow the same state machine.

#### Scenario: Mesa order without SMS

- GIVEN a Mesero creates a `MESA` order on the same device as Cocina
- WHEN the device is shared
- THEN the order transitions locally without SMS

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
