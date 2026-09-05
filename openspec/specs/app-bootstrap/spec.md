# App Bootstrap Specification

## Purpose

Guarantee the splash/startup flow never hangs the device: a hard overall timeout, per-step isolation with step logging, non-fatal device-fingerprint failures, and a preserved, deterministic route fallback chain. This is a NEW spec (no prior main spec existed).

## Requirements

### Requirement: Hard overall timeout with fail-open fallback

The splash startup flow MUST complete within 10 seconds, enforced by a hard timeout wrapping the entire check sequence (`_initApp` + `_checkLicense` equivalent). On timeout, the system SHALL — fail-open — navigate to `/login` (or `/register` when no users exist) and log the timeout reason and last completed step. The timeout value SHALL be a named constant so it can be adjusted or disabled.

#### Scenario: Hung platform call triggers fallback

- GIVEN the sequence hangs at the device fingerprint step (platform channel stuck)
- WHEN 10s elapse with no completion
- THEN the app navigates to `/login` (or `/register` if no users exist)
- AND splash stops showing the loader

#### Scenario: Normal flow beats the clock

- GIVEN all startup steps complete normally
- WHEN the check flow finishes under 10s
- THEN the timeout does not fire and the normal route decision is used

### Requirement: Per-step isolation and step logging

Each sequential awaited step in the startup chain — DB init / default records (admin, jefe), plans init, backup init, exports weekly cleanup, users query, license read/validation, device fingerprint, session read — MUST be individually wrapped try/catch, proceed or abort predictably on failure, and log a step name before starting and after finishing (success or error). This makes the hanging step identifiable in production logs.

#### Scenario: Step failure is isolated

- GIVEN backup init throws
- WHEN the chain reaches that step
- THEN the step logs FAIL without aborting the whole chain
- AND the remaining steps continue from the next one

#### Scenario: Hanging step is identified

- GIVEN the chain hangs at one step
- WHEN 10s timeout fires
- THEN the timeout log names the exact step it was stuck on (from the step log)

### Requirement: Device fingerprint is non-fatal and time-bounded

The `getDeviceFingerprint` call (DeviceInfoPlugin platform channel, license_service.dart) MUST be wrapped with its own timeout. If the platform channel hangs or throws, it MUST be treated as non-fatal and configurable: the fingerprint is treated as unavailable, mismatch checks that compare the license-bound device ID proceed without blocking login. A fingerprint mismatch MUST only prompt re-login (or activation) but MUST NOT hang startup.

#### Scenario: Platform channel fails

- GIVEN DeviceInfoPlugin throws / times out
- WHEN the fingerprint step
- THEN fingerprint is unavailable but splash continues
- AND login remains reachable

#### Scenario: Fingerprint mismatch prompts login without hanging

- GIVEN the license is bound to a different device ID
- WHEN the comparison runs
- THEN the app revokes/blocks login for that license and routes to login with a message
- AND this does not exceed the overall 10s timeout

### Requirement: Preserved route fallback order

The startup routing order MUST be preserved: register if no users → login if no license activated → license-expired when expired → invalid-license → login when device mismatched → home when session valid (<24h) → login otherwise. A timeout or caught error SHALL use `login` as the fallback when users exist, `register` when none.

#### Scenario: Fallback order after every failure

- GIVEN startup aborts early with an error at any step
- WHEN error handling decides where to go
- THEN the same order as the happy-path checks applies
- AND no uncaught error leaves the user on a stuck splash

## REMOVED

- (none — this is a new spec)