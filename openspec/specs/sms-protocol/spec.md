# SMS Protocol Specification

## Purpose

Define the structured SMS payload format and transport layer used to synchronize order state between role devices. Every state transition is carried over SMS with ACK confirmation and deduplication.

## Requirements

### Requirement: Payload Types

The system MUST support five payload types identified by the `t` field: `PED` (new order), `ACK` (acknowledgment), `HEC` (ready/from kitchen), `ENT` (delivered), `CAN` (cancelled).

#### Scenario: Sending PED triggers ACK

- GIVEN a Redes user creates and confirms an order
- WHEN the system sends a `PED` SMS to the Cocina trusted number
- THEN the Cocina device receives, parses, and auto-acknowledges with `ACK`
- AND the Redes device registers the order as confirmed-in-cocina

#### Scenario: ACK timeout triggers visual warning

- GIVEN the Redes device sent a `PED` but received no `ACK` within 5 minutes
- WHEN the ACK timer expires
- THEN the system SHALL display a visual alert: "Cocina did not confirm order #ID"
- AND the user MAY tap "resend" to re-send the `PED` SMS

### Requirement: JSON Minified Format

The system MUST transmit payloads as minified JSON with short keys: `t` (type), `id` (order ID), `cl` (client name), `tl` (phone), `dr` (address), `rf` (reference), `it` (items as `[[code, qty]]`), `hr` (time), `pg` (payment method), `mo` (motive).

#### Scenario: New order fits one SMS segment

- GIVEN a typical order with 3 items and client data
- WHEN serialized as minified JSON
- THEN the payload MUST be under 160 characters

### Requirement: Background SMS Reception

The system MUST register a `BroadcastReceiver` via the `telephony` package to receive SMS in background, even with the app closed. Received SMS MUST be parsed as JSON; unparseable messages MUST be discarded with a log entry.

#### Scenario: Incoming SMS from untrusted number

- GIVEN an SMS arrives from a number NOT in the trusted contacts list
- WHEN the receiver filters the origin
- THEN the SMS MUST be discarded and NOT processed

### Requirement: Deduplication by Order ID

The system MUST ignore duplicate `PED` payloads by checking the `id` field against existing orders. Duplicates MUST NOT create new orders or trigger repeated state transitions.

#### Scenario: Duplicate PED arrives

- GIVEN an order with ID `R1-0712-007` already exists
- WHEN a second `PED` with the same `id` arrives
- THEN the system MUST ignore it and NOT modify any order state

### Requirement: Pipe-Delimited Fallback

The system MAY support a pipe-delimited fallback format (`PED|ID|client|phone|...`) for environments where JSON segments exceed cost thresholds. Implementation MUST auto-detect format on receipt.

#### Scenario: Fallback format received

- GIVEN an incoming SMS does not start with `{`
- WHEN the parser attempts pipe-delimited parsing
- THEN the system SHALL parse fields positionally if format matches
