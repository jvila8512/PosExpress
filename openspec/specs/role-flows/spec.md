# Role Flows Specification

## Purpose

Define the role-gated UI shells that present only the screens and actions relevant to each role. The same app binary loads different interfaces based on the authenticated user's role.

## Requirements

### Requirement: Role-Gated Navigation

The system MUST restrict navigation and screen access based on the authenticated user's role. Unauthorized routes MUST redirect to the role's home screen or show a permission-denied message.

#### Scenario: Redes sees only Redes screens

- GIVEN a user with role `redes` is authenticated
- WHEN browsing the app navigation
- THEN the user MUST see only: Order Form, Order History, Catalog, Client List, Settings
- AND MUST NOT see: Kitchen Queue, Delivery List, Daily Close

### Requirement: Redes UI — Order Form

The Redes interface MUST provide an order creation form with: product catalog with short codes, client selector (search or create), item quantity picker, order type (domicilio/mesa), and a "Confirm & Send SMS" button.

#### Scenario: Redes sends order via SMS

- GIVEN Redes has filled the order form and confirmed
- WHEN tapping "Confirm & Send SMS"
- THEN the system persists the order, serializes as `PED` SMS, and sends to the Cocina trusted number

### Requirement: Cocina UI — Order Queue

The Cocina interface MUST display an incoming order queue showing: order ID, items, client name, elapsed time since receipt. Each order MUST have a "Mark as Done" (HECHO) button.

#### Scenario: Cocina marks order as done

- GIVEN an order is in `EN_COCINA` state
- WHEN Cocina taps "Mark as Done"
- THEN the system transitions state to `HECHO`, sends `HEC` SMS to Domicilio, and removes the order from the active queue

### Requirement: Domicilio UI — Delivery List

The Domicilio interface MUST show a list of orders in `EN_CAMINO` state with: client name, address, reference, items. Each SHALL have a "Mark as Delivered" (ENTREGADO) button that sends `ENT` SMS to Redes.

#### Scenario: Domicilio completes delivery

- GIVEN an order is in `EN_CAMINO` state with client address and reference
- WHEN Domicilio taps "Mark as Delivered" and optionally enters payment method and amount
- THEN the system transitions to `ENTREGADO` and sends `ENT` SMS to Redes

### Requirement: Admin UI — Dashboard

The Admin interface MUST provide: daily summary view, order history (all), client registry, trusted contacts management, products management, expenses/purchases/payroll forms, and the daily close panel. Admin MUST be able to view and export any data.

#### Scenario: Admin views all active orders

- GIVEN the Admin is authenticated
- WHEN navigating to "All Orders"
- THEN the system displays every order for the current day regardless of state or origin device
