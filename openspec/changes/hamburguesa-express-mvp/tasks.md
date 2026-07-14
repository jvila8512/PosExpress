# Tasks: Hamburguesas Express SMS Ordering — MVP

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~2,450 (PR1: ~610, PR2: ~850, PR3: ~850, PR1-fix: ~190) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR1 (schema+auth) → PR2 (SMS core) → PR3 (screens+cleanup) |
| Delivery strategy | ask-on-risk |
| Chain strategy | feature-branch-chain |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Base |
|------|------|-----------|------|
| 1 | Schema v14 + auth migration + Drift tables + codigoCorto | PR 1 | feature/tracker branch |
| 2 | SMS protocol + OrderStateMachine + Riverpod providers | PR 2 | PR 1 branch |
| 3 | Role-gated screens + daily close + router + delete POS modules | PR 3 | PR 2 branch |

## Phase 1: Schema v14 — Foundation (PR 1)

- [x] 1.1 Add Drift tables `restaurant_clients`, `restaurant_orders`, `restaurant_order_items`, `trusted_contacts`, `sms_messages`, `daily_summaries` (+ `daily_expenses`, `daily_purchases`, `daily_payroll` per design) in `app_database.dart` — **9 new tables total**
- [x] 1.2 Add `codigoCorto TEXT UNIQUE` to `Products` table
- [x] 1.3 Bump `schemaVersion` to 14, write `onUpgrade`: drop 16 POS tables, create 9 new, add codigoCorto, seed `SÓLIDOS`/`LÍQUIDOS`/`POSTRES` categories, map `vendedor→redes`/`almacenero→cocina`/`super_admin→admin`
- [x] 1.4 Update auth: add SMS role getters in `User` entity (`isRedes`/`isCocina`/`isDomicilio`/`isMesero`), add `mapPosRoleToSmsRole()`, update `auth_datasource_impl.dart` role mapping on login/register/checkAuthStatus, update `AuthState` with SMS getters
- [x] 1.5 Add `phone` field to auth `User` entity, save/load phone from `FlutterSecureStorage` in `AuthDataSourceImpl`, mapped in login/checkAuthStatus
- [x] 1.6 Run `dart run build_runner build --delete-conflicting-outputs` — **201 outputs generated successfully**. Verify `.g.dart` includes all new tables and `codigoCorto`
- [x] 1.7 Add missing tables: `restaurant_tables`, `order_state_history`, `price_history` — **3 additional tables** con schema alineado al PRD
- [x] 1.8 Create `OrderState` enum with dual flow: `registrado→enCocina→hecho→enCamino→entregado` (domicilio) and `enCocina→hecho→entregadoEnMesa→pagado→cerrado` (mesa), with `validTransitions` map + `canTransitionTo()` method
- [x] 1.9 Align daily tables with PRD schema: `DailyExpenses→gastos` (concepto, monto, fecha, registradoPorUsuarioId), `DailyPurchases→compras` (insumo, proveedor, cantidad, costo, fecha, registradoPorUsuarioId), `DailyPayroll→nomina` (usuarioId, fecha, trabajo, jornada, salarioBase, estimulo, total)
- [x] 1.10 Run `build_runner` — all 12 new tables compile successfully, `.g.dart` regenerated

## Phase 2: SMS Protocol & Order Core (PR 2)

- [x] 2.1 Create `lib/features/sms/` — `SmsPayload` entity, `SmsParser` (JSON + pipe fallback), `SmsSerializer` (<160 chars, embebido en `SmsPayload.toJson()`)
- [x] ~~2.2 Create `OrderState` enum~~ — **Done in 1.8**, skip
- [x] 2.3 Create `RestaurantOrder` entity, abstract `OrderRepository`, Drift datasource, `OrderRepositoryImpl`
- [x] 2.4 Create `SmsService` wrapping `telephony` — send, bg listener, ACK timer (5 min), dedup by `id` (telephony stub con TODO, requiere Android)
- [x] 2.5 Create `BroadcastReceiver` — bg SMS reception, origin filter from trusted contacts, dispatch (telephony stub)
- [x] 2.6 Create `RestaurantClient` + `TrustedContact` entities, datasources, repositories (separate from license `Clientes`)
- [x] 2.7 Create Riverpod providers: `orderProvider`, `clientProvider`, `contactProvider`
- [x] 2.8 Unit tests: SmsParser, SmsSerializer, OrderStateMachine, dedup, ACK timer — **70 tests pasan**

## Phase 3: Screens, Router & Cleanup (PR 3)

- [x] 3.1 Create Redes order form — catalog with short codes, client search/create, quantity picker, confirm & send PED SMS
- [x] 3.2 Create Cocina kitchen queue — incoming orders, elapsed time, "Mark as Done" (→HECHO + HEC SMS)
- [x] 3.3 Create Domicilio delivery list — EN_CAMINO orders, address/reference, "Mark as Delivered" (→ENTREGADO + ENT SMS)
- [x] 3.4 Create Admin daily close — auto sales aggregation, cost of production, manual purchases/expenses/payroll, 30/30/40 split
- [x] 3.5 Create order history + client management + trusted contacts screens
- [x] 3.6 Update GoRouter: add SMS-order routes, remove POS/sync routes, add role-based redirect guards
- [x] 3.7 Update `home_screen.dart` — role-gated dashboard (redes→form, cocina→queue, domicilio→delivery, admin→close)
- [x] 3.8 Update `product_form_screen.dart` + `products_provider.dart` — add codigoCorto field, auto-generate, include in CRUD
- [x] 3.9 Delete `lib/features/pos/`, `inventory/`, `sync/`, `workers/` dirs + remove import refs
- [x] 3.10 Remove POS report screens: `sessions_screen.dart`, `session_detail_screen.dart`
- [x] 3.11 Add `telephony: ^0.8.0` to `pubspec.yaml`
- [x] 3.12 Widget tests: Redes form, Cocina queue, role gating. Integration: full PED→ACK→HEC→ENT flow (mocked SMS) — **pendiente: tests de integración con telephony real require Android**
