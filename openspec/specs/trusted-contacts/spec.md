# Trusted Contacts Specification

## Purpose

Define the phone number whitelist per role that serves as the SMS origin filter. Only SMS from registered trusted numbers are processed; all others are discarded. This is the security boundary of the SMS protocol.

## Requirements

### Requirement: Contact CRUD per Role

The system MUST provide CRUD operations for trusted contacts, each associated with a role (`admin`, `redes`, `cocina`, `domicilio`, `mesero`). Each contact SHALL have a phone number, an optional user reference, and an active/inactive flag.

#### Scenario: Admin adds Cocina trusted number

- GIVEN the Admin opens the trusted contacts settings
- WHEN creating a contact with role `cocina`, phone `53567890`, and an optional user assignment
- THEN the contact is saved and activated by default

#### Scenario: Deactivate a contact

- GIVEN an active trusted contact exists
- WHEN the Admin toggles the contact to inactive
- THEN the system MUST retain the record but skip it during SMS filtering

### Requirement: SMS Origin Filter

The SMS `BroadcastReceiver` MUST check every incoming SMS origin against the active trusted contacts for the device's current role. If the origin number does not match any active contact, the SMS MUST be discarded and logged.

#### Scenario: SMS from trusted Cocina number

- GIVEN the Redes device has `53567890` registered as Cocina trusted contact
- WHEN an SMS arrives from `53567890` with a valid `PED` payload
- THEN the system SHALL process the SMS normally

#### Scenario: SMS from unknown number

- GIVEN the device has no trusted contact matching `+53599999`
- WHEN an SMS arrives from `+53599999`
- THEN the system MUST discard the SMS
- AND log a security event: "Discarded SMS from untrusted number +53599999"

### Requirement: Role-Appropriate Contact Types

Each device SHALL only register contacts relevant to its role. Redes registers Cocina and Domicilio. Cocina registers Redes and Domicilio. Domicilio registers Cocina. Admin MAY register all roles.

#### Scenario: Cocina cannot add another Cocina

- GIVEN a Cocina device is configuring trusted contacts
- WHEN attempting to add a contact with role `cocina`
- THEN the system SHOULD warn that Cocina can only register `redes` and `domicilio` contacts

### Requirement: Contact Validation

Phone numbers MUST be validated as Cuban mobile numbers (prefix `5` after country code, minimum 8 digits). Invalid numbers SHOULD be rejected at creation time with a descriptive error.

#### Scenario: Invalid phone number

- GIVEN the user enters `1234` as a phone number
- WHEN creating a trusted contact
- THEN the system MUST reject the input and display "Invalid phone number format"
