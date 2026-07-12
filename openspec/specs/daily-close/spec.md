# Daily Close Specification

## Purpose

Define the daily financial summary — an automated cierre de caja that combines auto-calculated blocks (sales, cost of production) with manual inputs (purchases, expenses, payroll) to produce net profit and the 30/30/40 distribution.

## Requirements

### Requirement: Auto-Calculated Sales Block

The system MUST calculate total sales per product (solid and liquid categories separately) by summing quantities from `ENTREGADO` orders of the current day. Each product's subtotal = quantity × catalog price. Category subtotals MUST be summed into Total Sales.

#### Scenario: Daily sales calculation

- GIVEN today has 3 delivered orders with 5 solid items and 2 liquid items total
- WHEN the Admin opens the daily close panel
- THEN the system displays: solid sales (quantity × price), liquid sales, subtotals, and Total Sales amount

### Requirement: Cost of Production

The system MUST calculate cost of production as sum of (quantity sold × `costoUnidad`) for each product in today's delivered orders. This MUST auto-populate when the daily close is opened.

#### Scenario: Cost reflects sold quantities

- GIVEN today's delivered orders sold 10 units of CLE at 5900 CUP each
- WHEN cost of production is calculated
- THEN it SHALL be 10 × `costoUnidad` of CLE

### Requirement: Manual Input Blocks

The Admin MUST be able to record purchases, expenses, and payroll data directly in the daily close form. These blocks SHALL persist to their respective tables (`compras`, `gastos`, `nomina`).

#### Scenario: Record a daily expense

- GIVEN the Admin is in the daily close form
- WHEN entering a concept "Carbon" with amount 500 CUP
- THEN the expense is saved to the `gastos` table and added to Total Expenses

### Requirement: Derived Profit Calculations

The system MUST compute: Utilidad Neta = Total Sales − Cost of Production − Total Expenses − Total Purchases − Payroll. Then MUST apply 30/30/40 distribution on net profit.

#### Scenario: Profit distribution display

- GIVEN Utilidad Neta = 10,000 CUP
- WHEN the daily close calculates distribution
- THEN it SHALL display: Yurdenis 3,000 CUP (30%), Mildrey 3,000 CUP (30%), Reinversión 4,000 CUP (40%)

### Requirement: Monthly/Yearly Aggregation (Placeholder)

The system SHOULD provide a placeholder for monthly and yearly aggregation views (F3). When opened, the view MUST display "Coming in a future update" and show a summary count of available daily records.

#### Scenario: Open monthly view

- GIVEN the daily close panel has a "Monthly View" button
- WHEN the Admin taps it
- THEN the system displays "Monthly aggregation coming in Phase 3" and a count of daily records available for the month

### Requirement: Resumen del Día Cache Table

The system MUST persist the computed daily close to a `resumen_dia` table (keyed by date) to enable fast report access without re-aggregating. Re-running the close for the same date MUST update the existing row.

#### Scenario: Re-run daily close

- GIVEN the daily close was already computed for today
- WHEN the Admin edits an expense and taps "Recalculate"
- THEN the system updates the `resumen_dia` row for today with new values
