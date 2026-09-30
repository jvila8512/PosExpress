# PRD — D'Hamburguezas (apodo del sistema: "HamburGüis")

**Versión:** 1.0
**Fecha:** 18 de agosto de 2026
**Autor:** Javier
**Tipo de documento:** Product Requirements Document (PRD)

---

## 1. Resumen ejecutivo

**D'Hamburguezas** es un negocio de fabricación artesanal de hamburguesas, elaboradas a mano por trabajadores a partir de picadillo (pollo, res o puerco) siguiendo una fórmula estándar. El negocio vende por pedido a clientes registrados, calcula el costo real de producción a partir de los ingredientes, y paga a los trabajadores según la cantidad de hamburguesas que fabrican.

Se necesita una aplicación (de aquí en adelante **"HamburGüis"**, el apodo del sistema) que digitalice todo el flujo operativo diario: registro de clientes y pedidos, seguimiento de producción, control de cobros, pago a trabajadores, gastos, y cierre de caja diario — todo resumido en un dashboard de ventas mensual.

Dado el patrón de trabajo de Javier (PosJVL, offline-first, Flutter/Dart), se recomienda construir HamburGüis como app móvil Android **offline-first**, ya que el negocio opera en el día a día sin depender de conexión.

---

## 2. Problema a resolver

Hoy el control del negocio (o se hace en papel/Excel, o no existe) y se pierde información crítica:

- No hay costeo real por hamburguesa (ingrediente + mano de obra).
- No hay trazabilidad clara de quién debe (pedido entregado pero no pagado).
- No hay registro histórico de cuánto produjo cada trabajador ni cuánto se le debe pagar.
- No hay visibilidad de ganancia real del día (ventas − gastos − pago a trabajadores).
- No hay vista consolidada mensual para tomar decisiones (¿qué días vendo más? ¿cuánto gano al mes?).

---

## 3. Objetivos del producto

1. Registrar clientes, pedidos y su estado (Pedido → Entregado → Pagado).
2. Calcular el costo de producción de cada hamburguesa según la fórmula/receta y el precio de los ingredientes.
3. Registrar trabajadores y su producción diaria (hamburguesas hechas), con pago por unidad configurable.
4. Permitir precio de venta configurable (varía frecuentemente).
5. Registrar gastos del día y descontarlos del total.
6. Generar un cierre de caja diario automático: total vendido, cobrado, por cobrar, hamburguesas hechas, pago a trabajadores, gastos, ganancia neta.
7. Ofrecer un dashboard mensual con historial de ventas diarias.
8. Operar 100% offline (el negocio no depende de internet para trabajar).

---

## 4. Usuarios del sistema

| Rol | Descripción | Acceso |
|---|---|---|
| **Administrador (Javier)** | Dueño del negocio. Configura precios, fórmulas, pagos, ve reportes y dashboard. | Total |
| **Operador de venta del día** | Puede ser el mismo Javier u otra persona. Registra clientes, pedidos, marca entregado/pagado, anota producción. | Operativo (sin configuración) |

*(Los trabajadores de producción no usan la app directamente — su producción la anota el operador.)*

---

## 5. Alcance funcional (módulos)

### 5.1 Módulo de Ingredientes y Fórmula (Costeo)

Permite registrar los ingredientes de la fórmula base de la hamburguesa y calcular el costo por libra y por unidad producida.

**Datos a registrar por ingrediente:**
- Nombre del ingrediente (ej. picadillo de pollo, pan, condimentos, sal, etc.)
- Unidad de medida (libra, onza, unidad, ml, etc.)
- Costo por unidad de medida (configurable, cambia con el tiempo)
- Cantidad usada en la fórmula estándar (por libra de picadillo)

**Fórmula/Receta:**
- Una receta base por tipo de carne (pollo / res / puerco), ya que "siempre es la misma".
- A partir de: cuántas hamburguesas rinde 1 libra de picadillo + costo de los demás ingredientes → el sistema calcula el **costo unitario de producción por hamburguesa**, según el tipo de carne.
- Este costo se recalcula automáticamente si cambia el precio de algún ingrediente.

> Nota: el costo de producción es distinto del pago al trabajador (que es aparte, por unidad hecha) y distinto del precio de venta (configurable). El sistema debe dejar claro: **Costo materia prima + Pago mano de obra = Costo total** vs. **Precio de venta** → margen.

---

### 5.2 Módulo de Clientes

**Datos del cliente:**
- Nombre
- Teléfono (celular y/o fijo)
- Dirección
- Historial de pedidos (automático, no se captura manual)

**Funciones:**
- Alta rápida de cliente desde la pantalla de trabajo del día (sin salir del flujo).
- Búsqueda rápida por nombre o teléfono.

---

### 5.3 Módulo de Pedidos

**Datos del pedido:**
- Cliente asociado
- Fecha del pedido
- Cantidad de hamburguesas solicitadas (en unidades)
- Tipo de carne (pollo/res/puerco) — para saber qué fórmula/costo aplica
- Precio de venta aplicado (toma el precio configurado del día, pero editable por pedido si hace falta un ajuste puntual)
- Estado del pedido, con **3 etapas independientes** (no lineales estrictas, pero con lógica sugerida):
  1. **Pedido** (registrado, aún no producido/entregado)
  2. **Entregado** (ya se le dio la mercancía al cliente)
  3. **Pagado** (ya cobró)

**Reglas:**
- Un pedido puede estar Entregado y no Pagado → esto alimenta la lista de **"Por Cobrar"**.
- Un pedido puede tener pagos parciales (recomendado para negocio real) — a evaluar si se incluye en v1 o v2 (ver sección 9).
- Cada cambio de estado debe quedar con fecha/hora (para trazabilidad de mora en cobros).

---

### 5.4 Módulo de Trabajadores y Producción

**Datos del trabajador:**
- Nombre
- Teléfono

**Registro de producción diaria:**
- Trabajador
- Fecha
- Cantidad de hamburguesas hechas (anotadas por el operador durante el día)
- Tipo de carne producida (opcional, si se quiere desglosar)

**Pago a trabajadores:**
- Precio por hamburguesa hecha, **configurable** (puede variar por trabajador o ser un valor general — a definir con Javier, ver preguntas abiertas).
- El sistema calcula automáticamente el pago total del día por trabajador = cantidad hecha × tarifa vigente.

---

### 5.5 Pantalla principal — "Día de trabajo"

Esta es la pantalla operativa central, tal como la describiste:

- Al abrir la app en modo "día de trabajo", se muestra la lista de **clientes con pedidos del día** (si ya hay pedidos cargados).
- Desde ahí mismo se puede:
  - Agregar un nuevo cliente.
  - Agregar un nuevo pedido a un cliente existente.
  - Marcar un pedido como Entregado.
  - Marcar un pedido como Pagado.
  - Ver rápidamente cuánto lleva vendido/cobrado en lo que va del día.
- Debe ser una pantalla rápida, pensada para usarse con el negocio "caliente" (poco texto, botones grandes, mínimo de toques).

---

### 5.6 Módulo de Gastos del día

- Registrar gastos con: descripción, monto, fecha.
- Los gastos se descuentan del total al hacer el cierre del día.

---

### 5.7 Cierre de Día (Cierre de Caja)

Al finalizar la jornada, el sistema genera automáticamente un resumen con:

- **Total de hamburguesas hechas** (suma de producción de todos los trabajadores).
- **Total de hamburguesas vendidas** (suma de pedidos del día).
- **Total vendido** (en dinero, según precio de venta aplicado).
- **Total cobrado** (pedidos marcados como Pagado).
- **Total por cobrar** (pedidos Entregado pero no Pagado, o Pedido sin entregar aún).
- **Total pagado a trabajadores** (según producción × tarifa).
- **Total de gastos del día.**
- **Ganancia neta del día** = Total cobrado (o vendido, a definir) − Costo de materia prima − Pago a trabajadores − Gastos.

Este cierre debe guardarse como un registro histórico inmutable por día (no se recalcula después, salvo edición explícita).

---

### 5.8 Módulo "Quién me debe" (Cuentas por Cobrar)

- Lista de todos los pedidos Entregados y No Pagados, agrupados por cliente.
- Debe mostrar: cliente, teléfono, monto adeudado, fecha del pedido, días de atraso.
- Acceso directo para marcar como Pagado cuando el cliente salda.

---

### 5.9 Dashboard de Ventas

- Vista mensual con ventas diarias (gráfico de barras o línea, día por día).
- Totales del mes: vendido, cobrado, por cobrar, ganancia neta, gastos, pago a trabajadores.
- Filtro por rango de fechas.
- Comparativa simple mes actual vs. mes anterior (opcional v2).

---

## 6. Modelo de datos (entidades principales)

| Entidad | Campos clave |
|---|---|
| **Ingrediente** | id, nombre, unidad_medida, costo_por_unidad, fecha_actualizacion |
| **Formula** | id, tipo_carne (pollo/res/puerco), rendimiento_por_libra, lista_ingredientes[cantidad] |
| **Cliente** | id, nombre, telefono_celular, telefono_fijo, direccion |
| **Trabajador** | id, nombre, telefono |
| **TarifaTrabajador** | id, trabajador_id (o global), precio_por_unidad, fecha_vigencia |
| **PrecioVenta** | id, precio, fecha_vigencia (histórico de cambios de precio) |
| **Pedido** | id, cliente_id, fecha, cantidad, tipo_carne, precio_aplicado, estado_entregado (bool+fecha), estado_pagado (bool+fecha) |
| **ProduccionDiaria** | id, trabajador_id, fecha, cantidad_hecha, tipo_carne |
| **Gasto** | id, fecha, descripcion, monto |
| **CierreDiario** | id, fecha, total_hecho, total_vendido, total_cobrado, total_por_cobrar, total_pago_trabajadores, total_gastos, ganancia_neta |

---

## 7. Requisitos no funcionales

- **Offline-first:** toda la operación diaria debe funcionar sin internet (consistente con el enfoque ya usado en PosJVL).
- **Plataforma:** Android, Flutter/Dart + SQLite (Drift), alineado con el stack habitual de Javier.
- **Velocidad de captura:** la pantalla de "día de trabajo" debe permitir registrar un pedido en pocos toques.
- **Histórico e inmutabilidad:** precios de venta, tarifas de trabajadores y costos de ingredientes deben guardar historial (para que cambios futuros no alteren cierres pasados).
- **Respaldo/backup:** exportar datos (igual que en PosJVL) para no perder información del negocio.

---

## 8. Fuera de alcance (v1)

- Pagos electrónicos / pasarelas de pago.
- Rutas de entrega / logística de domicilio.
- Multi-sucursal.
- App para que el trabajador registre su propia producción (en v1 lo anota el operador).

---

## 9. Preguntas abiertas para definir antes de desarrollar

1. **Tarifa de trabajadores:** ¿es una tarifa general para todos, o cada trabajador puede tener su propio precio por hamburguesa hecha?
2. **Pagos parciales de clientes:** ¿un cliente puede abonar una parte del pedido, o el estado "Pagado" es todo-o-nada?
3. **Ganancia neta del cierre:** ¿se calcula sobre lo **vendido** (lo que se comprometió a vender) o sobre lo **cobrado** (dinero que realmente entró)? Esto cambia la fórmula del cierre diario.
4. **Precio de venta:** ¿se define una vez al día (precio del día) o puede variar por cliente/pedido dentro del mismo día?
5. **Costo de ingredientes:** ¿se actualiza manual cada vez que cambian los precios, o se quiere alguna alerta cuando el margen se reduce mucho?

---

## 10. Próximos pasos sugeridos

1. Validar y cerrar las preguntas abiertas de la sección 9 con Javier.
2. Definir wireframes de la pantalla "Día de trabajo" (pantalla más usada).
3. Definir el modelo de datos final en Drift/SQLite.
4. Priorizar v1 (MVP): Clientes + Pedidos + Producción + Cierre diario. Dashboard mensual puede ir en v1.1.
