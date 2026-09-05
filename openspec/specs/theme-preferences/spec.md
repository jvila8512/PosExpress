# Theme Preferences Specification

## Purpose

Provide the app-wide theming contract: a single brand token palette, a role-aware default theme, a user-persisted theme choice, a Settings selector, legible login in both modes, and a brand-styled splash. This is a NEW spec (no prior main spec existed).

## Requirements

### Requirement: Unified brand token palette — app-wide migration

The system MUST derive ALL app colors from `HamburguesaThemeData` / `AppColors` tokens (Achiote `#D9531E`, Carbon `#241A14`, Plancha `#382A21`, Papel `#F6ECDF`, Mostaza, Mojo, Guayaba). Screens SHALL NOT use `AppTheme.colorCeleste` / `AppTheme.colorMorado` (cyan/purple) or hardcoded brand colors. The migration covers ~43 files / ~305 usages and MUST proceed in feature batches (auth, home, pos, products, license, sync, reports, shared widgets); each batch SHALL be independently verifiable. Legacy constants SHALL be deleted from `app_theme.dart` only after 0 usages remain.

#### Scenario: Clean migration pass per batch

- GIVEN one feature batch (e.g., home) is migrated
- WHEN a grep runs over `lib/` excluding `app_theme.dart`
- THEN 0 matches for `AppTheme.colorCeleste|AppTheme.colorMorado` in that feature's files
- AND the feature still renders with the Achiote accent in both modes

#### Scenario: Legacy constants removed

- GIVEN all batches are migrated
- WHEN `AppTheme` legacy constants are removed
- THEN the app compiles without those references

### Requirement: Light default with role override (non-cocina)

The system MUST default to `ThemeMode.light` (currently hardcoded `dark` — theme_provider.dart:11). `setDefaultThemeForRole` (dead code today, theme_provider.dart:66) MUST be invoked after auth resolves, applying dark for `cocina` and light for all other roles (`redes`, `admin`, `super_admin`, `domicilio`, `mesero`). Per-role defaults apply only when the user has NOT explicitly saved a choice.

#### Scenario: First login defaults by role

- GIVEN an `admin`/`redes`/`domicilio`/`mesero` user with no saved theme
- WHEN the user logs in
- THEN theme is `light`

#### Scenario: Cocina defaults dark

- GIVEN a `cocina` user with no saved theme
- WHEN the user logs in
- THEN theme is `dark`
- AND the theme stays dark until the user overrides it

### Requirement: Persistent theme choice (Settings toggle)

Settings MUST expose a theme selector (Light / Dark / System) that writes to the preference store, takes effect immediately, and persists across restarts. A saved user choice MUST override the role default. The persisted value SHALL be read at startup before the first frame when feasible.

#### Scenario: Choice survives restart

- GIVEN the user sets `dark` in Settings
- WHEN the app restarts and the user logs in
- THEN the theme is `dark` from the first frame

#### Scenario: System mode

- GIVEN the user picked `system`
- WHEN the OS brightness changes
- THEN the app follows the OS brightness

### Requirement: Light theme uses Papel background

The light theme MUST use `#F6ECDF` (Papel) as scaffold background, `#FFFFFF` for surfaces, and `#241A14` text. Resolved decision: Papel cream IS the brand light background; "light theme available" means it is functional and the default for non-cocina roles. No pure-white light background substitution is required.

#### Scenario: Light tokens render

- GIVEN light mode is active
- WHEN any screen renders
- THEN scaffold bg is `#F6ECDF`, cards are `#FFFFFF`, text is `#241A14`

### Requirement: Login legible in both modes (no forced white)

The login screen MUST NOT force `backgroundColor: Colors.white` (currently login_screen.dart forces white while the app can be in dark mode inheriting cream text — that combination made labels illegible). In light mode, login MUST render dark text on light app surfaces. In dark mode, login MUST render light text on the dark surface palette. Text contrast SHALL meet at least 3:1 on all login elements in both modes.

#### Scenario: Legible in dark

- GIVEN the app is in dark mode
- WHEN the login screen renders
- THEN background is a dark surface and labels/text are light
- AND contrast between text and background is ≥ 3:1

#### Scenario: Legible in light

- GIVEN the app is in light mode
- WHEN the login screen renders
- THEN background is Papel/white and text is `#241A14`
- AND no element inherits dark-theme cream text on white

### Requirement: Splash brand accent

The splash screen MUST use the brand accent (Achiote) and theme tokens — not the legacy cyan `AppTheme.colorCeleste` currently used at splash_screen background.

#### Scenario: Splash renders brand

- GIVEN the app launches
- WHEN the splash screen shows
- THEN the background uses the Achiote/orange accent
- AND no legacy cyan from `AppTheme` appears

## REMOVED

- (none — this is a new spec)