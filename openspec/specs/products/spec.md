# Products Specification

## Purpose

Define the product model for the Hamburguesas Express SMS ordering system — each product has a short code for SMS protocol, food-specific categories, cost price tracking, and full price history.

## Requirements

### Requirement: Short Code for SMS Protocol

The `Products` table MUST gain a `codigoCorto` column (3-4 uppercase characters) used as the product identifier in SMS payloads (`it` field). This code MUST be unique per product.

#### Scenario: New product with short code

- GIVEN the Admin creates a new product "Coloso Express" with price 5900
- WHEN the Admin also enters a short code `CLE`
- THEN the product is saved with `codigoCorto = "CLE"`
- AND the code appears in the product catalog for SMS composition

#### Scenario: Send order with short codes

- GIVEN a product "Coloso Express" has `codigoCorto = "CLE"`
- WHEN Redes creates an order with 2 units of this product
- THEN the SMS payload contains `"it":[["CLE",2]]` instead of full product names

### Requirement: Auto-Generate Short Codes

The system SHOULD auto-generate a `codigoCorto` from the product name when not provided (first letters of significant words, max 4 chars). The user MAY override the generated value.

#### Scenario: Auto-code from product name

- GIVEN a new product named "Sencilla Clásica"
- WHEN no short code is entered
- THEN the system generates `SCL` as the default short code

### Requirement: Food-Specific Categories

The existing `Categories` table MUST be seeded with food-specific values: `SÓLIDOS` (hamburguesas, patacones, panes), `LÍQUIDOS` (bebidas), `POSTRES`. These replace any generic POS categories.

#### Scenario: Seed food categories on first run

- GIVEN the app starts for the first time after upgrade
- WHEN categories are initialized
- THEN the system creates `SÓLIDOS`, `LÍQUIDOS`, and `POSTRES` as the default categories

### Requirement: Cost Price for Production Cost

The `Products` table's existing `costPrice` field MUST be used to calculate Cost of Production in the daily close. It SHALL be editable per product and independent of the sale price.

#### Scenario: Update cost price

- GIVEN a product "Coloso Express" has sale price 5900 and cost price 2500
- WHEN the Admin updates the cost price to 2700
- THEN future daily close calculations use 2700 as cost per unit for this product

### Requirement: Price History

The system MUST track price changes in a `price_history` table. Every time a product's price or cost changes, the previous values MUST be preserved with a `fechaVigencia` timestamp. Each order MUST use the price/cost **vigente at the order's date**, not the current catalog values. The `margenPct` SHALL be auto-calculated as `(precio − costoUnidad) / precio × 100`.

#### Scenario: Price change preserves history

- GIVEN a product "Coloso Express" had cost 2500 and price 5900 in January
- WHEN the Admin updates the price to 6500 in February
- THEN the `price_history` table contains two entries for this product
- AND January orders still reference the January price/cost
- AND February orders use the new price/cost

#### Scenario: View price timeline

- GIVEN a product has 3 price changes over 6 months
- WHEN the Admin opens the price history view
- THEN the system displays a timeline of all 3 changes with dates, prices, costs, and margin %

### Requirement: Product Identification

The system MUST identify products by both `id` (UUID, internal) and `codigoCorto` (SMS protocol). The `codigoCorto` is the external identifier used in order items and SMS payloads. (Previously: products were identified only by internal UUID `id` and optional alphanumeric `code`.)

#### Scenario: Look up product by short code

- GIVEN a `PED` SMS arrives with item `["CLE",2]`
- WHEN the parser resolves `CLE` to a product
- THEN the system finds the product with `codigoCorto = "CLE"` and creates the order item
