# ExpresPOS — Hamburguesas Express SMS Ordering

Sistema de gestión de pedidos vía SMS para **Hamburguesas Express**.

> 🚧 **En transformación**: Proyecto originalmente un POS de mostrador, migrando a un sistema de pedidos SMS sin internet.

## Stack

- **Flutter** 3.x + Dart
- **Riverpod** — State management
- **Drift** — SQLite local (offline-first)
- **GoRouter** — Routing
- **SHA-256** — Auth + Licencias con anti-tampering

## Arquitectura

Clean Architecture por features:

```
lib/
├── core/            # Database, seguridad, servicios compartidos
├── config/          # Router, tema
└── features/
    ├── auth/        # Login, registro, roles
    ├── license/     # Licencias, clientes, planes
    ├── products/    # Catálogo, categorías
    ├── expenses/    # Gastos operativos
    ├── sms/         # Protocolo SMS (nuevo)
    ├── orders/      # Pedidos y estados (nuevo)
    ├── clients/     # Clientes del restaurante (nuevo)
    ├── contacts/    # Contactos de confianza (nuevo)
    └── daily_close/ # Cierre de día (nuevo)
```

## Estado del Proyecto

Actualmente en **MVP** bajo SDD (Spec-Driven Development):
- ✅ Fase 1: Propuesta
- ✅ Fase 2: Especificaciones
- ✅ Fase 3: Diseño técnico
- ✅ Fase 4: Tareas
- 🔄 Fase 5: Implementación (PR 1/3)

## Licencias

Sistema de licencias con:
- Validación SHA-256 + anti-tampering de reloj
- Binding a dispositivo por Android ID
- Planes: FREE, NEGOCIO, PRO, MAX, MAXPRO
- Gestión de clientes y renovaciones

## Equipo

- **Javier Vila** — Desarrollo
