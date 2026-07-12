# PRD — App de Gestión de Pedidos vía SMS (Sin Internet, Sin Red Local)
**Negocio:** Hamburguesas Express
**Versión:** 2.0 — Arquitectura SMS-only
**Stack sugerido:** Flutter + Riverpod + SQLite/Drift (local por dispositivo) + `telephony` (envío/escucha de SMS en background, Android)

---

## 1. Resumen Ejecutivo

Sistema de **apps independientes**, una por rol/dispositivo, cada una con su propia base de datos local (SQLite/Drift). No hay servidor ni red compartida: **el SMS de la red celular es el único medio de sincronización** entre apps. Cada transición de estado del pedido (registrado → en cocina → hecho → entregado) se dispara automáticamente al recibir un SMS con un payload estructurado (tipo JSON compacto), sin que nadie tenga que leer ni transcribir el mensaje manualmente.

## 2. Contexto del Negocio

Según tu operación actual (confirmado con tu planilla de control diario):
- **Roles del día a día:** Atención al Cliente / Facebook (toma el pedido), Cocina 1, Cocina 2, Domicilio (reparto), Administrador (tú).
- **Catálogo real:** ~26 productos sólidos (hamburguesas, patacones, panes, ensalada) + 5 líquidos/postres, con precios en CUP ya definidos en tu Excel.
- **Cuadre actual:** ventas efectivo vs. transferencia, costo de producción, gastos del día, nómina con estímulo por producción — todo se concilia manualmente al cierre.

## 3. Problema Actual

- El pedido se transcribe manualmente entre 3-4 personas por SMS de texto libre → se pierden datos, se duplican, o no llegan.
- No hay confirmación de que el siguiente eslabón (cocina, domicilio) realmente recibió el pedido.
- Al final del día no existe un registro único: hay que reconstruir todo cruzando notas y mensajes (como ya hiciste en tu análisis forense de caja).

## 4. Objetivo del Producto

Que el pedido viaje **una sola vez, de forma estructurada y automática** por SMS entre las apps de cada rol, sin transcripción manual, con confirmación de recepción en cada salto, y que el Administrador tenga visibilidad del ciclo completo de cada pedido para el cierre del día.

## 5. Flujo Propuesto

```
[App REDES]                [App COCINA]              [App DOMICILIO]           [App ADMIN]
    │                            │                          │                       │
 1. Toma pedido (form)           │                          │                       │
    con catálogo de productos    │                          │                       │
    + datos del cliente          │                          │                       │
    │                            │                          │                       │
 2. Confirma → estado REGISTRADO │                          │                       │
    │──────── SMS pedido ───────>│                          │                       │
    │                       3. Auto-registra                │                       │
    │                          estado EN_COCINA              │                       │
    │<────── SMS ACK recibido ───│                          │                       │
 4. marca "confirmado           4. Cocina prepara            │                       │
    en cocina"                   (cronómetro interno)        │                       │
    │                       5. Marca HECHO                   │                       │
    │                            │──── SMS pedido listo ────>│                       │
    │                            │                      6. Auto-registra             │
    │                            │                         "para entregar"           │
    │                            │                      7. Sale, entrega             │
    │                            │                      8. Marca ENTREGADO           │
    │<──────────────────── SMS "entregado + pago" ──────────│                       │
 9. Cierra pedido                │                          │                       │
    (estado CERRADO)             │                          │                       │
    │                                                                                 │
    └──── (copia opcional de cada SMS clave, en "modo supervisión") ────────────────>│
                                                                          10. Admin ve
                                                                          el ciclo completo
                                                                          sin hacer nada
```

Cada app corre en su propio teléfono, de forma independiente. El SMS es el único "cable" entre ellas.

## 6. Roles y Dispositivos

| Rol | Rol de negocio | Qué hace su app |
|---|---|---|
| **Redes / Atención al Cliente** | Quien atiende FB/WhatsApp | Crea el pedido con formulario + catálogo, envía SMS a Cocina, recibe ACK y confirmación final de entrega |
| **Cocina** (1 o 2 dispositivos) | Cocineros | Escucha SMS de Redes, auto-registra pedido, gestiona cola de cocina, marca HECHO, envía SMS a Domicilio |
| **Domicilio** (uno o varios repartidores) | Repartidor | Escucha SMS de Cocina, ve dirección/referencia, marca ENTREGADO, envía SMS de cierre |
| **Administrador** (tú) | Dueño | Opcionalmente recibe copia (CC) de los SMS clave para tener visibilidad en tiempo real sin intervenir; consolida el cierre del día |

Cada app tiene una pantalla de configuración donde se guardan los **números de teléfono de confianza** de los otros roles (ej. Redes solo acepta y procesa SMS que vengan del número configurado de Cocina, ignora cualquier otro).

## 7. Formato del Mensaje SMS (protocolo propio)

El SMS estándar tiene 160 caracteres por segmento (los mensajes largos se concatenan automáticamente, pero cada segmento adicional puede tener costo). Por eso, en vez de JSON completo (con comillas y llaves, que gasta caracteres), se recomienda un **JSON minificado con claves cortas y códigos de producto**, para intentar que la mayoría de los pedidos quepan en 1-2 segmentos.

**Ejemplo de payload (pedido nuevo, de Redes a Cocina):**
```
{"t":"PED","id":"R1-0712-007","cl":"Juan Perez","tl":"53512345","dr":"Calle 23 e/ B y C","rf":"casa azul portal verde","it":[["CLE",1],["SCQ",2]],"hr":"1430","pg":"EF"}
```

Donde:
- `t`: tipo de mensaje (`PED`=pedido nuevo, `ACK`=confirmación, `HEC`=listo en cocina, `ENT`=entregado, `CAN`=cancelado)
- `id`: identificador único = `{origen}-{fecha}-{secuencia}` (ej. R1-0712-007 = Redes 1, 12-jul, pedido #7) — evita choques de ID entre dispositivos que trabajan sin coordinarse
- `cl/tl/dr/rf`: cliente, teléfono, dirección, referencia
- `it`: ítems como pares `[código_producto, cantidad]` usando **códigos cortos generados del catálogo** (igual metodología que ya usas para los catálogos de PosJVL)
- `hr`: hora solicitada
- `pg`: método de pago si ya se conoce (EF=efectivo, TR=transferencia, PD=pendiente)

**Mensajes de confirmación/cierre son mucho más cortos:**
```
{"t":"ACK","id":"R1-0712-007"}
{"t":"HEC","id":"R1-0712-007"}
{"t":"ENT","id":"R1-0712-007","pg":"EF","mt":950}
{"t":"CAN","id":"R1-0712-007","mo":"cliente no contesto"}
```

> Alternativa aún más compacta (si el volumen de pedidos es alto y el costo por segmento importa): formato posicional separado por `|` en vez de JSON, ej. `PED|R1-0712-007|Juan Perez|53512345|Calle 23...|CLE1,SCQ2|1430|EF`. Se puede decidir esto en la fase de implementación según cuánto cueste cada segmento SMS en tu operador.

## 8. Base de Datos (SQLite/Drift) — Reutilizando PosJVL

> Nota: no tengo a la vista el schema Drift exacto de PosJVL en esta conversación, así que esta sección reconstruye la estructura a partir de lo que ya sabemos de esa app (login, roles, licencias con validación SHA-256). Si me pasas el archivo `*.drift`/`*.dart` de tablas de PosJVL, ajusto esto a los nombres y tipos reales en vez de esta reconstrucción.

### 8.1 Se reutiliza tal cual de PosJVL

- **`usuarios`** — login, nombre, hash de contraseña, rol asignado, activo/inactivo.
- **`roles`** — catálogo de roles con sus permisos (en PosJVL son roles de punto de venta; aquí se **renombran/redefinen los valores del rol**, ver 8.2, pero la tabla y su mecanismo de permisos se reutilizan igual).
- **`licencias`** — mismo esquema y misma lógica de validación (código de licencia con hash SHA-256 + clave secreta del lado servidor, dispositivo asociado, fecha de activación/expiración, estado). Esto es clave porque así controlas igual que en PosJVL cuántos dispositivos por negocio tienen la app activa (Redes, Cocina 1, Cocina 2, Domicilio, Admin = normalmente 5 licencias por negocio).
- **`sesiones`** (si existe en PosJVL) — útil aquí además para saber qué **rol tiene asignado cada dispositivo** una vez logueado (ver 8.5).

### 8.2 Se adapta

- **`roles`**: en vez de los roles típicos de un POS de mostrador (cajero, gerente, etc.), los valores pasan a ser: `admin`, `redes`, `cocina`, `domicilio`, `mesero`. El mecanismo de permisos (qué puede ver/hacer cada rol) es el mismo de PosJVL, solo cambia el catálogo de roles.
- **`usuarios`**: se le agrega el vínculo a **`contactos_confianza`** (número de teléfono SMS de ese usuario/dispositivo), porque aquí el "usuario" también es un nodo de la red SMS, no solo un login.
- **`productos`**: en PosJVL es un catálogo genérico de artículos; aquí se especializa a comida (categoría, precio, costo, código corto para el protocolo SMS) pero la tabla base y su relación con `historial_precios` sigue el mismo patrón que ya usas para el catálogo de PosJVL.

### 8.3 Tablas nuevas (específicas de este negocio)

- **`clientes`**, **`mesas`**, **`pedidos`**, **`pedido_items`**, **`historial_estados_pedido`**, **`contactos_confianza`**, **`gastos`**, **`compras`**, **`nomina`**, **`historial_precios`**, **`resumen_dia`**.

### 8.4 Esquema completo

```sql
-- === Reutilizadas de PosJVL ===
usuarios (
  id, nombre, login, passwordHash, rolId FK->roles, dispositivoId,
  activo, fechaCreacion
)

roles (
  id, nombre ENUM(admin, redes, cocina, domicilio, mesero), permisos JSON
)

licencias (
  id, codigoLicencia, dispositivoId, negocioId,
  fechaActivacion, fechaExpiracion, estado, hashValidacion
)

-- === Catálogo (adaptado de PosJVL) ===
productos (
  codigo PK, nombre, categoria, precio, costoUnidad, activo
)

historial_precios (
  id, productoCodigo FK->productos, fechaVigencia,
  precio, costoUnidad, margenPct
)

-- === Núcleo del negocio (nuevas) ===
clientes (
  id, nombre, telefono, direccion, referencia, notas, fechaRegistro
)

mesas (
  id, numero, capacidad, estado ENUM(libre, ocupada), ubicacion
)

pedidos (
  id PK,                          -- {origen}-{fecha}-{seq}
  tipoPedido ENUM(DOMICILIO, MESA),
  clienteId FK->clientes NULLABLE,     -- NULL si es pedido de mesa sin datos de cliente
  mesaId FK->mesas NULLABLE,           -- NULL si es domicilio
  estado ENUM(REGISTRADO, EN_COCINA, HECHO, EN_CAMINO, ENTREGADO, CANCELADO),
  canalOrigen ENUM(facebook, whatsapp, telefono, mesa),
  horaSolicitada, metodoPago, montoTotal,
  creadoPorUsuarioId FK->usuarios, fechaCreacion,
  smsEnviado BOOL, smsConfirmado BOOL, intentosReenvio INT,
  motivoCancelacion TEXT NULLABLE
)

pedido_items (
  id, pedidoId FK->pedidos, productoCodigo FK->productos,
  cantidad, precioUnitario, subtotal
)

historial_estados_pedido (
  id, pedidoId FK->pedidos, estado, timestamp,
  usuarioId FK->usuarios, viaSms BOOL
)

contactos_confianza (
  id, rol ENUM(admin, redes, cocina, domicilio, mesero),
  usuarioId FK->usuarios, numeroTelefono, activo
)

-- === Cierre de día (nuevas, solo relevantes en dispositivo Admin) ===
gastos (
  id, concepto, monto, fecha, registradoPorUsuarioId FK->usuarios
)

compras (
  id, insumo, proveedor, cantidad, costo, fecha, registradoPorUsuarioId FK->usuarios
)

nomina (
  id, usuarioId FK->usuarios, fecha, trabajo BOOL, jornada,
  salarioBase, estimulo, total
)

resumen_dia (                       -- tabla "cache" para reportes rápidos, se recalcula o se guarda al cerrar el día
  fecha PK, totalVentas, ventasEfectivo, ventasTransferencia,
  costoProduccion, totalGastos, totalCompras, utilidadNeta,
  distribucionYurdenis, distribucionMildrey, distribucionNegocio
)
```

### 8.5 Qué tablas necesita cada dispositivo (según su rol)

Como no hay servidor central, cada dispositivo trae el **mismo schema completo** (una sola base de código Drift), pero en la práctica solo usa el subconjunto que le toca según su rol — esto simplifica mantener un único paquete de la app para todos los roles, activando pantallas según el rol logueado (igual patrón que ya usas en PosJVL para mostrar/ocultar funciones por rol):

| Rol | Tablas que realmente usa |
|---|---|
| **Admin** | Todas — es el único dispositivo donde `gastos`, `compras`, `nomina`, `resumen_dia` tienen sentido |
| **Redes** | `usuarios`, `roles`, `licencias`, `productos`, `historial_precios`, `clientes`, `pedidos` (los que crea), `contactos_confianza` |
| **Cocina** | `usuarios`, `licencias`, `productos`, `pedidos` (los que le llegan), `mesas` (si atiende pedidos directos de mesa), `contactos_confianza` |
| **Domicilio** | `usuarios`, `licencias`, `pedidos` (los que le llegan, tipo DOMICILIO), `contactos_confianza` |
| **Mesero** | `usuarios`, `licencias`, `productos`, `mesas`, `pedidos` (los que crea, tipo MESA) |

### 8.6 Pedidos de Mesa (directo a cocina)

Para las mesas del local, el flujo se simplifica porque **no hay traspaso a distancia** — el pedido nace y se cocina en el mismo sitio:

```
NUEVO → EN_COCINA → HECHO → ENTREGADO_EN_MESA → PAGADO → CERRADO
   ↳ (sin pasos REGISTRADO/EN_CAMINO, y sin SMS si Mesero y Cocina están en el mismo local)
```

Dos formas de implementarlo, según cómo estén distribuidos los dispositivos en tu local:

1. **Mismo dispositivo o mismo mostrador:** el Mesero anota directo en la pantalla de Cocina (o en un dispositivo compartido en el mostrador) — no hace falta SMS, es solo una fila más en `pedidos` con `tipoPedido = MESA`, sin pasar por el protocolo de la sección 7.
2. **Mesero con su propio dispositivo, separado de Cocina:** se reutiliza el mismo protocolo SMS (`PED` con `tipoPedido: MESA`, `mesaId` en vez de dirección/cliente) para mantener un solo mecanismo de sincronización en toda la app — más consistente aunque el mesero esté a 5 metros de la cocina.

Para el `resumen_dia`, los pedidos de mesa entran exactamente igual que los de domicilio en Ventas Sólidos/Líquidos y Costo de Producción — solo se diferencian por `tipoPedido` para poder reportar por separado "Ventas Mesa vs. Ventas Domicilio" si te interesa verlo así en el cierre.

## 9. Arquitectura Técnica

- **Flutter + Riverpod**, una sola base de código con "modos" según el rol configurado (redes / cocina / domicilio / admin) — cada instalación se configura una vez y actúa según su rol.
- **SQLite + Drift**, cada dispositivo con su propia base local, igual que en PosJVL.
- **Envío/recepción de SMS:** paquete `telephony` (o equivalente vigente — conviene verificar el estado del paquete al momento de implementar, ya que este ecosistema cambia) para:
  - Enviar SMS programáticamente sin abrir la app de mensajes.
  - Escuchar SMS entrantes en background vía `BroadcastReceiver`, incluso con la app cerrada, filtrando solo por los números de confianza configurados.
  - **Nota:** esto es Android-only (iOS no permite leer SMS entrantes de forma automática) — coherente con que ya trabajas en Android para PosJVL.
- **Parsing:** al recibir un SMS de un número de confianza, se intenta parsear como JSON; si falla (mensaje corrupto/incompleto por corte de segmento), se descarta y se marca visualmente para que el usuario decida reenviar pedir reenvío.
- **Permisos Android:** `RECEIVE_SMS`, `SEND_SMS`, `READ_PHONE_STATE`. Se debe explicar claramente al usuario para qué se usan (control interno del negocio, no lectura de SMS personales).

## 10. Confiabilidad — Resolviendo el "no cuadra"

Este es el corazón del problema que hoy tienes, así que se ataca directamente:

- **Confirmación (ACK) obligatoria:** cada pedido enviado queda en estado "esperando confirmación" hasta que llega el `ACK`. Si no llega en X minutos (configurable, ej. 5 min), la app avisa visualmente ("Cocina no confirmó el pedido #007") para que reenvíes manualmente — así nunca más se "pierde" un pedido en silencio.
- **Deduplicación:** si por reintento de red llega el mismo `id` dos veces, la app lo ignora la segunda vez (no duplica en cocina).
- **Reintento manual asistido:** botón "reenviar SMS" en cualquier pedido que quede pendiente de confirmación.
- **Checksum simple:** se puede añadir un campo `ck` (suma de verificación corta) al payload para detectar SMS truncados por cortes de segmento y descartarlos en vez de procesar datos corruptos.
- **Modo supervisión (CC a Admin):** cada SMS clave (`PED`, `HEC`, `ENT`, `CAN`) se puede enviar también, en paralelo, al número del Administrador. Esto duplica el gasto de SMS en esos mensajes, pero te da visibilidad total en tiempo real sin ningún paso manual — vale la pena evaluarlo contra el costo, o dejarlo como opción activable/desactivable por pedido de alto valor.

## 11. Catálogo de Productos (ejemplo de codificación)

Igual que hiciste para el catálogo de PosJVL: generar códigos cortos automáticamente a partir del nombre.

| Producto | Precio (CUP) | Código sugerido |
|---|---|---|
| Coloso Express | 5900 | CLE |
| Lotus Express | 990 | LTE |
| Especial Express | 1160 | ESE |
| Doble con Queso | 950 | DCQ |
| Sencilla con Queso | 590 | SCQ |
| Sencilla Clásica | 490 | SCL |
| Patacón Especial Express | 1150 | PEE |
| ... (resto del catálogo, ~26 sólidos + 5 líquidos/postres) | | |

*(el listado completo se genera automáticamente desde tu Excel, con la misma lógica de auto-generación de códigos que ya usaste antes para PosJVL — se puede reutilizar ese script)*

## 12. Cierre de Día / Conciliación

- Si activas el **modo supervisión** (sección 10), el Admin ya tiene en su propia base local el 100% de los pedidos del día en tiempo real — el cierre es solo revisar y cerrar caja, no reconstruir nada.
- Si **no** usas modo supervisión (para ahorrar SMS), al final del día cada dispositivo (Redes, Cocina, Domicilio) exporta su registro local del día (archivo `.json`/`.csv`) y se pasa al Admin por **Bluetooth / Nearby Share / cable USB** — no requiere internet, solo cercanía física, y es un paso único al cierre en vez de por cada pedido.
- El Admin, con las 3-4 fuentes reunidas, hace un cruce automático (mismo `id` de pedido debe existir en las 3 apps con estados coherentes) — esto reemplaza tu reconciliación forense manual actual.

## 13. Resumen del Día (Punto de Venta / Cierre de Caja)

Este es el reporte que hoy armas a mano en tu planilla. Con la app se convierte en un cálculo en vivo, en el mismo espíritu de un cierre de caja de punto de venta (igual concepto que ya usas en PosJVL), pero alimentado en parte por los pedidos SMS y en parte por entradas manuales del Admin.

### 13.1 Bloques que se calculan solos (vienen de los pedidos ENTREGADO/PAGADO del día)

| Bloque | Cómo se calcula |
|---|---|
| **Registro de Ventas — Sólidos** | Por cada producto sólido: cantidad = suma de unidades vendidas en pedidos del día; monto = cantidad × precio del catálogo |
| **Registro de Ventas — Líquidos y Postres** | Igual, para la categoría de líquidos/postres |
| **Subtotal Ventas Sólidos / Líquidos** | Suma de cada bloque |
| **Total Ventas del Día** | Subtotal Sólidos + Subtotal Líquidos |
| **Ventas Efectivo / Ventas Transferencia** | Se agrupa el monto total de cada pedido según el campo `pg` reportado en el SMS `ENT` (entregado) |
| **Diferencia (Total − Efectivo − Transferencia)** | En vez de calcularse al final, se muestra **en vivo durante el día**: si un pedido pasa a ENTREGADO sin `pg` definido, la app lo marca como "pago sin confirmar" de inmediato — ya no se descubre al cierre |
| **Costo de Producción** | Por producto: cantidad vendida × `costoUnidad` del catálogo; Total Costo Producción = suma de todos |

### 13.2 Bloques que se ingresan directamente en la app (ya no en Excel)

| Bloque | Cómo se ingresa |
|---|---|
| **Compras e Insumos del Día** | Formulario dentro de la app (insumo, proveedor, cantidad, costo) — reemplaza la fila manual del Excel |
| **Gastos del Día** | Formulario por concepto (salarios, estímulo, carbón/electricidad, domicilio, empaques, insumos varios, publicidad, mantenimiento, otros) |
| **Nómina del Día** | Pantalla donde el Admin marca quién trabajó y la jornada; salario base es configuración fija por persona, guardada una sola vez |

### 13.3 Cálculos automáticos derivados

- **Estímulo por producción:** se aplica la regla que ya usas ("$100 CUP por cada 5000 CUP vendidos sobre 25 000 CUP de venta total del día") tomando el Total Ventas del Día que la app ya calculó — ya no hay que esperar a sumar todo a mano para saber el estímulo de cada trabajador.
- **Cuadre Final del Día:**
  ```
  Utilidad Neta = Total Ventas
                − Costo Producción
                − Total Gastos
                − Total Compras
  ```
- **Distribución de Ganancia:** 30% Yurdenis, 30% Mildrey, 40% Reinversión — calculado automáticamente sobre la Utilidad Neta, sin fórmula manual.

### 13.4 Reporte final del día

Réplica exacta de la estructura de tu planilla actual (Registro de Ventas Sólidos/Líquidos, Costo de Producción, Compras, Gastos, Nómina, Cuadre Final, Distribución de Ganancia), más los indicadores que hoy no tienes visibles en vivo: pedidos cancelados con motivo, tiempo promedio en cocina, tiempo promedio de entrega, y % de pedidos con pago sin confirmar al momento del cierre.

Como ya construiste algo similar para PosJVL (dashboard con KPIs, clasificación ABC de productos, salud del negocio), esa misma lógica de reporte se puede reutilizar aquí — cambia la fuente de datos (pedidos por SMS en vez de ventas de mostrador), pero el cálculo final es el mismo tipo de cierre de caja.

## 14. Módulos que Reemplazan el Resto del Excel

Tu libro tiene 6 hojas: Registro Diario (ya cubierto en la sección 13), Historial de Precios, Calculadora de Precios, Nómina, Corte Mensual y Resumen Anual. Para que la app te lo dé "todo" y ya no necesites abrir el Excel, cada una se convierte en una pantalla de la app, calculada automáticamente a partir de lo que ya se registró día a día — nada de arrastrar fórmulas ni fórmulas rotas (`#REF!`) como pasa hoy al copiar hojas.

### 14.1 Historial de Precios

- Igual que tu regla actual: **nunca se borra un precio anterior**, cambiar el precio de un producto agrega una fila nueva con fecha de vigencia.
- Cada pedido, al calcular su venta, usa el precio/costo **vigente en la fecha del pedido**, no el precio actual — así el histórico de días pasados nunca se altera aunque subas precios después.
- Pantalla de administración: lista de productos con su línea de tiempo de precios, botón "actualizar precio" que simplemente agrega la nueva fila.
- El `margenPct` (columna que ya usas junto a algunos productos) se calcula solo: `(precio − costoUnidad) / precio × 100`.

### 14.2 Calculadora de Precios y Rentabilidad

Mismo espíritu que tu hoja actual, como herramienta dentro de la app:
- **Modo 1 — Calcular precio sugerido:** ingresas costo de producción + % de ganancia deseado → la app calcula el precio de venta sugerido y el food cost resultante.
- **Modo 2 — Verificar precio actual:** ingresas precio de venta y costo → la app calcula ganancia por unidad, % markup, % food cost.
- **Evaluación automática** con la misma escala que ya usas: 🟢 <30% muy rentable, ✅ 30-40% saludable, ⚠️ 40-45% aceptable, 🔴 >45% riesgo de pérdida.
- Se puede lanzar directo desde la ficha de cada producto en el catálogo, para decidir si toca subir un precio.

### 14.3 Corte Mensual (automático)

- Se genera solo, sumando los "Resúmenes del Día" (sección 13) de todos los días del mes: Ventas Total, Efectivo, Transferencia, Costo Producción, Gastos, Compras, Utilidad, Distribución 30/30/40.
- Sin fórmulas manuales que arrastrar entre hojas ni riesgo de referencias rotas al copiar la plantilla de un mes a otro.

### 14.4 Resumen Anual (automático)

- Igual que el Corte Mensual, pero agregando los 12 meses en una sola vista (una columna por mes + columna de Total Año), alimentada automáticamente por los Cortes Mensuales.
- Sirve para ver de un vistazo la tendencia del negocio mes a mes sin mantener una hoja aparte.

Con estos 4 módulos + el Resumen del Día (sección 13), la app cubre el 100% de lo que hoy hace el Excel — el archivo deja de ser necesario para la operación diaria.

## 15. MVP vs Fases Futuras

**MVP:**
- App con 3 modos (Redes, Cocina, Domicilio) + catálogo cargado desde tu Excel (con precio y costo por producto).
- Envío/recepción automática de SMS con ACK y deduplicación.
- Estados básicos: REGISTRADO → EN_COCINA → HECHO → ENTREGADO / CANCELADO.
- **Resumen del Día (sección 13) en la app del Admin**, con formularios de Compras, Gastos y Nómina — desde el día 1 ya no hace falta el Excel para el cierre diario.
- Exportación local del día por dispositivo (para conciliación manual inicial, si aún no usas modo supervisión).

**Fase 2:**
- Modo supervisión (CC automático a Admin) para que el Resumen del Día se arme en vivo, no solo al cerrar.
- Checksum/validación de integridad del SMS.
- Soporte multi-cocina / multi-domicilio con selección de destino (round robin o manual).
- **Historial de Precios y Calculadora de Precios (sección 14.1 y 14.2)** dentro de la app.

**Fase 3:**
- **Corte Mensual y Resumen Anual automáticos (sección 14.3 y 14.4)**, una vez haya suficientes días acumulados en la app para que valga la pena verlos agregados.
- Si en algún momento hay WiFi local disponible (aunque sea sin internet), migrar el "modo supervisión" a sincronización directa por LAN en vez de SMS, sin tocar el resto de la app (el `id` y modelo de datos ya quedan preparados para eso).

## 16. Riesgos y Consideraciones

- **Costo por SMS/segmento:** definir con tu operador cuánto cuesta cada segmento antes de decidir JSON vs. formato posicional — puede cambiar la decisión de formato.
- **Android-only:** la escucha automática de SMS en background no es posible en iOS; si algún rol usa iPhone, esa persona tendría que registrar el pedido manualmente al recibir el SMS visible (fallback aceptable pero rompe la automatización).
- **Retención de permisos:** Android puede pedir confirmación periódica de permisos de SMS; hay que diseñar la UX para que el usuario no lo perciba como fricción.
- **Multi-SIM / cambio de número:** si cambia el número de algún rol, hay que actualizar la configuración de "contactos de confianza" en todas las demás apps.

## 17. Métricas de Éxito

- % de pedidos con `ACK` recibido a tiempo (objetivo: 100%).
- 0 pedidos "fantasma" (existen en una app pero nunca llegaron a la siguiente).
- Tiempo promedio Redes→Cocina→Entregado.
- Diferencia entre lo reportado por conciliación de la app vs. caja física real, al cierre.
