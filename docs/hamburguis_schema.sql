-- =====================================================================
-- HamburGüis — D'Hamburguezas
-- Esquema SQLite (pensado para usarse con Drift en Flutter, offline-first)
-- =====================================================================

PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------------
-- 1. INGREDIENTES
-- Catálogo de ingredientes usados en las fórmulas de hamburguesa.
-- El costo_por_unidad se actualiza a mano cuando sube el precio.
-- ---------------------------------------------------------------------
CREATE TABLE ingredientes (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre              TEXT    NOT NULL,
    unidad_medida       TEXT    NOT NULL,          -- 'libra', 'onza', 'unidad', 'ml', etc.
    costo_por_unidad    REAL    NOT NULL,           -- costo actual (vigente) por unidad_medida
    activo              INTEGER NOT NULL DEFAULT 1, -- soft delete
    fecha_actualizacion TEXT    NOT NULL            -- ISO8601, se actualiza cada vez que cambia costo_por_unidad
);

-- Historial de costos: cada vez que cambia costo_por_unidad en `ingredientes`,
-- se inserta una fila aquí antes de actualizar. Así los cierres pasados
-- nunca se recalculan con precios nuevos.
CREATE TABLE ingredientes_historial_costo (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    ingrediente_id  INTEGER NOT NULL REFERENCES ingredientes(id),
    costo_por_unidad REAL   NOT NULL,
    vigente_desde   TEXT    NOT NULL,   -- ISO8601
    vigente_hasta   TEXT                -- NULL = todavía vigente
);

-- ---------------------------------------------------------------------
-- 2. FÓRMULAS (recetas base por tipo de carne)
-- "Siempre es la misma fórmula" -> una fila por tipo de carne.
-- ---------------------------------------------------------------------
CREATE TABLE formulas (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    tipo_carne          TEXT    NOT NULL UNIQUE,   -- 'pollo' | 'res' | 'puerco'
    rendimiento_por_libra REAL  NOT NULL,           -- cuántas hamburguesas salen de 1 libra de picadillo
    notas               TEXT
);

-- Ingredientes que componen cada fórmula, con la cantidad usada
-- por libra de picadillo (o por unidad de hamburguesa, a elección).
CREATE TABLE formula_ingredientes (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    formula_id      INTEGER NOT NULL REFERENCES formulas(id),
    ingrediente_id  INTEGER NOT NULL REFERENCES ingredientes(id),
    cantidad        REAL    NOT NULL,   -- cantidad de ese ingrediente por libra de picadillo
    UNIQUE(formula_id, ingrediente_id)
);

-- ---------------------------------------------------------------------
-- 3. CLIENTES
-- ---------------------------------------------------------------------
CREATE TABLE clientes (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre            TEXT    NOT NULL,
    telefono_celular  TEXT,
    telefono_fijo     TEXT,
    direccion         TEXT,
    activo            INTEGER NOT NULL DEFAULT 1,
    fecha_creacion    TEXT    NOT NULL
);

-- ---------------------------------------------------------------------
-- 4. TRABAJADORES
-- ---------------------------------------------------------------------
CREATE TABLE trabajadores (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre          TEXT    NOT NULL,
    telefono        TEXT,
    activo          INTEGER NOT NULL DEFAULT 1,
    fecha_creacion  TEXT    NOT NULL
);

-- Tarifa pagada por hamburguesa hecha. trabajador_id puede ser NULL
-- para representar una tarifa GENERAL (aplica a todos los que no
-- tengan tarifa propia). Si trabajador_id no es NULL, es una tarifa
-- específica para ese trabajador (por si alguno cobra distinto).
CREATE TABLE tarifas_trabajador (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    trabajador_id   INTEGER REFERENCES trabajadores(id),  -- NULL = tarifa general
    precio_por_unidad REAL  NOT NULL,
    vigente_desde   TEXT    NOT NULL,
    vigente_hasta   TEXT                                   -- NULL = vigente actualmente
);

-- ---------------------------------------------------------------------
-- 5. PRECIO DE VENTA
-- Histórico de precios de venta de la hamburguesa (varía mucho).
-- ---------------------------------------------------------------------
CREATE TABLE precios_venta (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    tipo_carne      TEXT    NOT NULL,   -- por si el precio difiere entre pollo/res/puerco
    precio          REAL    NOT NULL,
    vigente_desde   TEXT    NOT NULL,
    vigente_hasta   TEXT                -- NULL = vigente actualmente
);

-- ---------------------------------------------------------------------
-- 6. PEDIDOS
-- ---------------------------------------------------------------------
CREATE TABLE pedidos (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    cliente_id          INTEGER NOT NULL REFERENCES clientes(id),
    fecha               TEXT    NOT NULL,   -- fecha del pedido (ISO8601, solo día)
    cantidad            INTEGER NOT NULL,   -- unidades de hamburguesa
    tipo_carne          TEXT    NOT NULL,   -- 'pollo' | 'res' | 'puerco'
    precio_unitario_aplicado REAL NOT NULL, -- snapshot del precio vigente al crear el pedido
    -- Estado 1: entregado
    entregado           INTEGER NOT NULL DEFAULT 0,
    fecha_entregado      TEXT,
    -- Estado 2: pagado
    pagado              INTEGER NOT NULL DEFAULT 0,
    fecha_pagado         TEXT,
    monto_pagado         REAL    NOT NULL DEFAULT 0,  -- soporta pagos parciales (ver tabla pagos_pedido)
    notas                TEXT,
    fecha_creacion        TEXT    NOT NULL
);

-- Pagos individuales de un pedido (permite abonos/pagos parciales).
-- `pedidos.pagado` se marca en 1 cuando la suma de pagos_pedido
-- cubre el total del pedido (cantidad * precio_unitario_aplicado).
CREATE TABLE pagos_pedido (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    pedido_id   INTEGER NOT NULL REFERENCES pedidos(id),
    monto       REAL    NOT NULL,
    fecha       TEXT    NOT NULL
);

-- ---------------------------------------------------------------------
-- 7. PRODUCCIÓN DIARIA
-- Lo que cada trabajador hizo en el día (anotado por el operador).
-- ---------------------------------------------------------------------
CREATE TABLE producciones (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    trabajador_id   INTEGER NOT NULL REFERENCES trabajadores(id),
    fecha           TEXT    NOT NULL,
    tipo_carne      TEXT    NOT NULL,
    cantidad_hecha  INTEGER NOT NULL,
    tarifa_aplicada REAL    NOT NULL,   -- snapshot de la tarifa vigente ese día para ese trabajador
    fecha_creacion  TEXT    NOT NULL
);

-- ---------------------------------------------------------------------
-- 8. GASTOS
-- ---------------------------------------------------------------------
CREATE TABLE gastos (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    fecha           TEXT    NOT NULL,
    descripcion     TEXT    NOT NULL,
    monto           REAL    NOT NULL,
    fecha_creacion  TEXT    NOT NULL
);

-- ---------------------------------------------------------------------
-- 9. CIERRE DIARIO
-- Snapshot inmutable del resultado del día. Se genera al cerrar la venta
-- y NO se recalcula automáticamente después (si algo cambia, se puede
-- regenerar manual, pero no de forma silenciosa).
-- ---------------------------------------------------------------------
CREATE TABLE cierres_diarios (
    id                        INTEGER PRIMARY KEY AUTOINCREMENT,
    fecha                     TEXT    NOT NULL UNIQUE,
    total_hamburguesas_hechas INTEGER NOT NULL,
    total_hamburguesas_vendidas INTEGER NOT NULL,
    total_vendido             REAL    NOT NULL,  -- suma de (cantidad * precio_unitario_aplicado)
    total_cobrado             REAL    NOT NULL,  -- suma de pagos_pedido del día
    total_por_cobrar          REAL    NOT NULL,  -- total_vendido - total_cobrado (acumulado, no solo del día)
    total_pago_trabajadores   REAL    NOT NULL,  -- suma de (cantidad_hecha * tarifa_aplicada)
    total_costo_materia_prima REAL    NOT NULL,  -- costo de ingredientes de lo producido
    total_gastos              REAL    NOT NULL,
    ganancia_neta             REAL    NOT NULL,  -- ver fórmula abajo
    fecha_cierre               TEXT    NOT NULL   -- momento en que se generó el cierre
);

-- Índices útiles para las consultas más frecuentes
CREATE INDEX idx_pedidos_fecha ON pedidos(fecha);
CREATE INDEX idx_pedidos_cliente ON pedidos(cliente_id);
CREATE INDEX idx_pedidos_pendientes ON pedidos(entregado, pagado);
CREATE INDEX idx_producciones_fecha ON producciones(fecha);
CREATE INDEX idx_producciones_trabajador ON producciones(trabajador_id);
CREATE INDEX idx_gastos_fecha ON gastos(fecha);
