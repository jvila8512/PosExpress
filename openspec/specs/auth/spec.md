# Auth Specification

## Purpose

Define the SMS-specific role model for Hamburguesas Express — replacing POS counter roles with restaurant flow roles, and associating user phone numbers for SMS routing.

## Requirements

### Requirement: SMS Role Enum

The system MUST replace the POS role enum (`super_admin`, `admin`, `vendedor`, `almacenero`) with SMS-specific roles: `admin`, `redes`, `cocina`, `domicilio`, `mesero`. The login and license validation flow MUST remain unchanged.

#### Scenario: Admin user authenticates with new role

- GIVEN a user with role `admin` exists in the `users` table
- WHEN the user logs in with correct credentials
- THEN the system grants access with the Admin UI shell

#### Scenario: Redes user cannot access Admin screens

- GIVEN a user with role `redes` is authenticated
- WHEN attempting to navigate to the daily close route
- THEN the system redirects to the Redes home screen with a permission error

### Requirement: User-Phone Association

The `Users` table MUST gain an optional phone number field (`phone`) that links the user to their device number in the SMS network. This field is used to send SMS to this role and to identify incoming SMS origin.

#### Scenario: Configure phone for Redes user

- GIVEN an Admin is editing a Redes user profile
- WHEN the Admin enters the phone number `53512345`
- THEN the system saves the phone and makes it available for SMS routing

### Requirement: Migration from POS Roles

On first run after upgrade, existing users with POS roles MUST be mapped to the nearest SMS role: `super_admin` → `admin`, `admin` → `admin`, `vendedor` → `redes`, `almacenero` → `cocina`. The migration MUST execute once and log the mapping.

#### Scenario: Existing POS user migrates

- GIVEN a user with role `vendedor` exists pre-migration
- WHEN the app starts with the new schema
- THEN the user's role is migrated to `redes`
- AND a migration log entry is created

### Requirement: POS Role Enum Values Removed

POS role values `super_admin`, `vendedor`, `almacenero` are removed from the allowed role set. Reason: the business model changes from POS counter sales to SMS-based order flow. The `admin` value is retained but now maps to the restaurant Admin, not a POS manager.
