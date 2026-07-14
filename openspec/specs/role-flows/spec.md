# Role Flows Specification

## Purpose

Define the role-gated UI shells with the visual identity anchored in the business (parrilla, paladar cubano, ticket de cocina). Each role device loads the same binary but renders role-specific screens, theme default, and notification behavior.

## Requirements

### Requirement: Design System — Color Tokens

The system MUST implement two complete color palettes (dark and light mode) using the exact hex values below. All roles MUST support both modes with a manual toggle. Color representation MUST be consistent across all screens and roles.

#### Dark Mode Palette

| Token | Hex | Usage |
|-------|-----|-------|
| `bg` (Carbón) | `#241A14` | Screen background |
| `surface` (Plancha) | `#382A21` | Cards, panels |
| `text-primary` | `#F6ECDF` | Primary text |
| `text-secondary` | `#B0A196` | Secondary text, metadata |
| `accent` (Achiote) | `#D9531E` | Brand, primary buttons, "en cocina" state |
| `warning` (Mostaza) | `#E4A22E` | "Confirmed" state, time alerts |
| `success` (Mojo) | `#7C9A3B` | "Ready"/"Delivered" state |
| `danger` (Guayaba) | `#C2495B` | "Cancelled" state, errors, time exceeded |

#### Light Mode Palette

| Token | Hex | Usage |
|-------|-----|-------|
| `bg` (Papel) | `#F6ECDF` | Screen background |
| `surface` | `#FFFFFF` | Cards, panels |
| `text-primary` | `#241A14` | Primary text |
| `text-secondary` | `#8A7A6C` | Secondary text, metadata |
| `accent` (Achiote) | `#D9531E` | Brand — does NOT change between modes |
| `warning` (Mostaza) | `#B97A1E` | Darkened for contrast on white |
| `success` (Mojo) | `#5E7A2A` | Darkened for contrast on white |
| `danger` (Guayaba) | `#A03347` | Darkened for contrast on white |

#### Scenario: Color tokens render correctly in both modes

- GIVEN the app is in dark mode
- WHEN rendering any screen
- THEN the background SHALL be `#241A14`, cards `#382A21`, text `#F6ECDF`, accent `#D9531E`
- WHEN the user toggles to light mode
- THEN the background SHALL be `#F6ECDF`, cards `#FFFFFF`, text `#241A14`, accent still `#D9531E`

### Requirement: Design System — Typography

The system MUST use three font families: **Bungee** for screen titles and large product names, **DM Sans** for body text and forms, and **JetBrains Mono** for order IDs, amounts, timers, and cronometers.

#### Scenario: Typography by context

- GIVEN the screen title "Nuevo Pedido"
- WHEN rendered
- THEN the text SHALL use Bungee font
- GIVEN an order ID "R1-0712-009" or timer "14:32"
- WHEN displayed
- THEN the text SHALL use JetBrains Mono font
- GIVEN body text in a form or list
- WHEN rendered
- THEN the text SHALL use DM Sans font

### Requirement: Theme Default by Role

Each role SHALL have a suggested default theme (dark for Cocina, light for Redes/Domicilio/Admin). The user MUST be able to override the theme via Settings at any time. The toggle SHALL be persistent across sessions.

#### Scenario: Cocina default dark

- GIVEN a user with role `cocina` logs in for the first time
- WHEN the home screen loads
- THEN the system SHALL apply dark theme (bg `#241A14`, surface `#382A21`)
- WHEN the user goes to Settings and toggles to light
- THEN the system SHALL switch to light theme immediately and persist the choice

### Requirement: Redes UI — New Order Form

The Redes order form MUST display:
- **Header**: Folio (e.g. `R1-0712-009`) in JetBrains Mono
- **Client block**: name, phone, address/reference — always visible, large text, never behind an accordion
- **Catalog**: product photo (if available), name, price, +/- quantity counter, filterable by category tabs (Sólidos / Líquidos)
- **Total**: always visible at the bottom, updated in real-time as items are added
- **Send button**: "Enviar a cocina" — persists order as `REGISTRADO`, sends `PED` SMS to Cocina trusted number
- **Status after send**: shows "Esperando confirmación de cocina" → changes to "Confirmado en cocina" when `ACK` arrives

#### Scenario: Redes creates and sends order

- GIVEN Redes has selected a client, added 2 CLE and 1 SCQ via +/- counters
- WHEN the total shows `12,390 CUP` and Redes taps "Enviar a cocina"
- THEN the system creates the order, sends `PED` SMS, and shows "Esperando confirmación de cocina"
- WHEN the `ACK` SMS arrives from Cocina
- THEN the status changes to "Confirmado en cocina"

### Requirement: Cocina UI — Order Queue with Notification

The Cocina interface MUST have two critical behaviors:

**Notification on incoming `PED`:**
- MUST fire a **high-priority Android notification** with: strong distinctive sound (not default notification tone), long vibration, screen wake even if device is locked
- Sound MUST **repeat every few seconds** until a user taps "Recibido" on the order card
- Requires a high-importance notification channel with custom sound
- If device is in "Do Not Disturb" mode, the app MUST request the additional permission required to bypass it

**Order Queue columns:**
- Three columns: **Confirmado** (just arrived), **En cocina** (being prepared), **Listo** (done)
- Each card shows: order ID, items, client name, **cronometer** visible from when marked "en cocina"
- Cronometer color: default (white/bright) → **Mostaza** (`#E4A22E`) at configurable time threshold (default 15 min) → **Guayaba** (`#C2495B`) if exceeded
- **"Marcar hecho"** button: transitions to `HECHO`, sends `HEC` SMS to Domicilio

#### Scenario: Cocina receives and processes PED

- GIVEN the Cocina device receives a `PED` SMS
- WHEN parsed successfully
- THEN a notification fires with custom sound + vibration + screen wake
- AND the order appears in the "Confirmado" column
- WHEN Cocina taps the card and then "Recibido"
- THEN the notification stops repeating
- AND the order moves to "En cocina" column with cronometer started
- WHEN the cronometer reaches 15 min
- THEN the timer color changes to Mostaza `#E4A22E`
- WHEN Cocina taps "Marcar hecho" before 20 min
- THEN the order moves to "Listo" column
- AND a `HEC` SMS is sent to Domicilio

### Requirement: Domicilio UI — Delivery View

The Domicilio delivery list MUST display:
- **Delivery data**: client name (large text), **"Llamar" button** that opens the dialer with the client's phone number pre-filled
- **Address and reference** always visible
- **Items and amount to collect** (if payment is cash on delivery)
- **Cronometer** from when the order left the kitchen (same color alert pattern as Cocina)
- **"Marcar entregado" button** with a payment method selector (EF/TR/PD) — the ACTUAL payment method may differ from what was recorded at order creation

#### Scenario: Domicilio completes delivery

- GIVEN a delivery order in `EN_CAMINO` state with client "Juan Perez", phone "53512345"
- WHEN Domicilio taps the phone icon
- THEN the system opens the dialer with `53512345` pre-filled
- WHEN Domicilio taps "Marcar entregado" and selects `EF` as payment with amount `950`
- THEN the order transitions to `ENTREGADO`
- AND an `ENT` SMS with `"pg":"EF","mt":950` is sent to Redes

### Requirement: Redes UI — Order Tracking

The Redes tracking screen MUST display a list of all orders created during the current shift with live status updates. As `ACK`, `HEC`, `ENT` SMS messages arrive, the status MUST update automatically without user intervention.

#### Scenario: Redes sees full cycle

- GIVEN Redes created order R1-0712-009
- WHEN the `ACK` arrives from Cocina
- THEN the order status changes from "Esperando confirmación" to "En cocina"
- WHEN the `ENT` arrives from Domicilio
- THEN the status changes to "Entregado"

### Requirement: Admin UI — Daily Close Dashboard

The Admin dashboard MUST display:
- **Header**: Total sales for the day in large JetBrains Mono, with EF/TR breakdown
- **Product sales ranking**: ordered list from highest to lowest quantity sold, with amount per product
- **Net Profit block**: Utilidad Neta formula + automatic 30/30/40 distribution
- **Operational indicators** (color-coded per palette):
  - Average kitchen time
  - Average delivery time
  - Cancelled orders with motive
  - Orders with unconfirmed payment
- **Same traffic-light colors**: Mojo = good, Mostaza = attention, Guayaba = problem

#### Scenario: Admin reviews the day

- GIVEN it's end of day with 23 delivered orders
- WHEN Admin opens the dashboard
- THEN they see Total Sales in large text, product ranking (CLE: 15 units = 88,500 CUP), Utilidad Neta, and each operational indicator with its color

### Requirement: Reusable Components

The system MUST provide three reusable widgets used across multiple roles:

1. **StatusBadge**: colored pill mapped to order state using the palette (Achiote=EN_COCINA, Mostaza=confirmado, Mojo=HECHO/ENTREGADO, Guayaba=CANCELADO)
2. **TicketCard**: card with perforated/dotted border at the top, used for Cocina queue items and cart summary in Redes
3. **Cronometer**: JetBrains Mono number that changes color based on elapsed time relative to a configurable threshold

#### Scenario: TicketCard renders correctly

- GIVEN a Cocina order card
- WHEN rendered
- THEN the card SHALL have a dotted top border with circle perforations (visual ticket style)
- AND the cronometer SHALL display elapsed time in JetBrains Mono
- AND the StatusBadge SHALL show the current state in the correct color
