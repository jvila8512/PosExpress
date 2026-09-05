import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:uuid/uuid.dart';
import 'package:etecsa/core/security/license_service.dart';

part 'app_database.g.dart';

/// ================================================================
/// TABLAS DE LA BASE DE DATOS CON FIFO
///
/// - categories: Categorías de productos
/// - users: Usuarios/trabajadores con roles
/// - products: Catálogo de productos
/// - inventory_lots: Lotes FIFO para inventario (NUEVO)
/// - inventory: Stock actual por ubicación
/// - stock_movements: Auditoría de movimientos
/// - sales: Ventas del día
/// - sale_items: Detalle de cada venta
/// - expenses: Gastos operativos
/// - app_settings: Configuración de la app
/// - sync_log: Log de sincronización
/// ================================================================

/// --- CATEGORÍAS ---
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get description => text().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get icon => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- USUARIOS / TRABAJADORES ---
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get username => text().unique()();
  TextColumn get passwordHash => text()();
  TextColumn get role => text()();
  TextColumn get fullName => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get androidId => text().nullable()(); // Android ID del dispositivo
  TextColumn get address => text().nullable()();
  DateTimeColumn get hireDate => dateTime().nullable()();
  RealColumn get salary => real().withDefault(const Constant(0.0))();
  RealColumn get commissionRate => real().withDefault(const Constant(0.0))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- LICENCIAS (legacy - mantener para compatibilidad) ---
class Licenses extends Table {
  TextColumn get id => text()();
  TextColumn get licenseKey => text().unique()();
  TextColumn get tipo => text()(); // 'admin' o 'vendedor'
  DateTimeColumn get fechaInicio => dateTime()();
  DateTimeColumn get fechaFin => dateTime()();
  TextColumn get dispositivoId => text().nullable()();
  BoolColumn get activa => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- LICENCIAS DE CLIENTE (nueva tabla) ---
class LicenciasCliente extends Table {
  TextColumn get id => text()();
  TextColumn get clienteId => text().references(Clientes, #id)();
  TextColumn get codigo => text().unique()();
  TextColumn get plan => text()(); // FREE, PRO, NEGOCIO
  DateTimeColumn get fechaCreacion => dateTime()();
  DateTimeColumn get fechaExpiracion => dateTime()();
  DateTimeColumn get fechaCancelacion =>
      dateTime().nullable()(); // NUEVO: Fecha de cancelación
  TextColumn get estado => text().withDefault(
    const Constant('activa'),
  )(); // activa, vencida, cancelada
  RealColumn get precioPagado => real().withDefault(const Constant(0.0))();
  TextColumn get dispositivoId => text().nullable()();
  TextColumn get notas => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- CLIENTES (para licencias) ---
class Clientes extends Table {
  TextColumn get id => text()();
  TextColumn get nombre => text()();
  TextColumn get telefono => text()();
  TextColumn get negocio => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get notas => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- PLANES DE LICENCIAS ---
class LicensePlanes extends Table {
  TextColumn get id => text()(); // Usar texto para mantener compatibilidad
  TextColumn get nombre => text()(); // FREE, PRO, NEGOCIO
  RealColumn get precio => real()(); // precio total del plan
  TextColumn get descripcion => text().nullable()();
  IntColumn get diasDuracion => integer()(); // 30, 365, etc
  IntColumn get maxProductos => integer()();
  IntColumn get maxVendedores => integer()();
  BoolColumn get activa => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- PRODUCTOS ---
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get code => text().unique().nullable()();
  TextColumn get codigoCorto => text().unique().nullable()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get imageUrl => text().nullable()(); // Ruta de imagen local
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  RealColumn get unitPrice => real()();
  RealColumn get costPrice => real().withDefault(const Constant(0.0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- LOTES DE INVENTARIO (FIFO) ---
class InventoryLots extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get productId => text().references(Products, #id)();
  RealColumn get quantity => real()();
  RealColumn get remainingQuantity => real()();
  RealColumn get costPerUnit => real()();
  DateTimeColumn get purchaseDate => dateTime()();
  TextColumn get supplier => text().nullable()();
  TextColumn get reference => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get location => text().withDefault(const Constant('almacen'))();
}

/// --- FACTURAS DE COMPRA ---
class PurchaseInvoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get invoiceNumber => text()(); // FC-0001
  DateTimeColumn get invoiceDate =>
      dateTime().withDefault(currentDateAndTime)();
  RealColumn get totalAmount => real()();
  TextColumn get supplier => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// --- ITEMS DE FACTURA DE COMPRA ---
class PurchaseInvoiceItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get invoiceId => integer().references(PurchaseInvoices, #id)();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get productName =>
      text()(); // snapshot del nombre al momento de la compra
  RealColumn get quantity => real()();
  RealColumn get costPerUnit => real()();
  RealColumn get total => real()();
}

/// --- INVENTARIO (resumen por ubicación) ---
class Inventories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get location => text()();
  RealColumn get quantity => real().withDefault(const Constant(0.0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>>? get uniqueKeys => [
    {productId, location},
  ];
}

/// --- AJUSTES DE STOCK (dedicado) ---
class StockAdjustments extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text().references(Products, #id)();
  IntColumn get inventoryLotId => integer().nullable()();
  TextColumn get adjustmentType => text()(); // 'add', 'remove', 'bulk'
  RealColumn get quantity => real()();
  RealColumn get unitCost => real().withDefault(const Constant(0.0))();
  TextColumn get reason => text().nullable()();
  TextColumn get userId => text().nullable().references(Users, #id)();
  DateTimeColumn get adjustedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- MOVIMIENTOS DE STOCK ---
class StockMovements extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get movementType => text()();
  TextColumn get fromLocation => text().nullable()();
  TextColumn get toLocation => text().nullable()();
  RealColumn get quantity => real()();
  RealColumn get unitCost => real().nullable()();
  TextColumn get referenceId => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get userId => text().nullable().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- VENTAS ---
class Sales extends Table {
  TextColumn get id => text()();
  DateTimeColumn get saleDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get sellerId => text().references(Users, #id)();
  RealColumn get totalAmount => real()();
  TextColumn get paymentMethod => text()();
  RealColumn get sellerCommissionRate =>
      real().withDefault(const Constant(0.0))();
  RealColumn get commissionAmount => real().withDefault(const Constant(0.0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  TextColumn get status => text().withDefault(const Constant('closed'))();
  TextColumn get cancellationReason => text().nullable()();
  TextColumn get cancelledBy => text().nullable().references(Users, #id)();
  DateTimeColumn get cancelledAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get syncBatchId => text().nullable()();
  TextColumn get sessionId => text().nullable().references(Sessions, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- SESIONES DE CAJA (POS) ---
class Sessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  DateTimeColumn get openingTime => dateTime()();
  RealColumn get openingCash => real()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get closingTime => dateTime().nullable()();
  RealColumn get closingCash => real().nullable()();
  RealColumn get totalSales => real().withDefault(const Constant(0.0))();
  RealColumn get totalCash => real().withDefault(const Constant(0.0))();
  RealColumn get totalTransfer => real().withDefault(const Constant(0.0))();
  RealColumn get totalProfit => real().withDefault(const Constant(0.0))();
  TextColumn get status => text().withDefault(const Constant('open'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- PEDIDOS (ORDERS - POS) ---
class Orders extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(Sessions, #id)();
  TextColumn get sellerId => text().references(Users, #id)();
  RealColumn get subtotal => real()();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalAmount => real()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get paidAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- LÍNEAS DE PEDIDO (ORDER ITEMS) ---
class OrderItems extends Table {
  TextColumn get id => text()();
  TextColumn get orderId => text().references(Orders, #id)();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get productName => text()();
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()();
  RealColumn get costPrice => real().withDefault(const Constant(0.0))();
  RealColumn get subtotal => real()();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- PAGOS DE PEDIDOS ---
class OrderPayments extends Table {
  TextColumn get id => text()();
  TextColumn get orderId => text().references(Orders, #id)();
  TextColumn get paymentMethod => text()();
  RealColumn get amount => real()();
  RealColumn get changeGiven => real().withDefault(const Constant(0.0))();
  TextColumn get reference => text().nullable()();
  TextColumn get bank => text().nullable()();
  // Transfer data fields (from PAGOxMOVIL SMS)
  TextColumn get transactionId => text().nullable()();
  TextColumn get purchaseId => text().nullable()();
  TextColumn get clientName => text().nullable()();
  TextColumn get clientPhone => text().nullable()();
  TextColumn get clientCI => text().nullable()();
  TextColumn get transferDate => text().nullable()();
  TextColumn get rawSms => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- DETALLE DE VENTAS ---
class SaleItems extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get productId => text().references(Products, #id)();
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()();
  RealColumn get costPriceAtSale => real().withDefault(const Constant(0.0))();
  RealColumn get subtotal => real()();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- GASTOS OPERATIVOS ---
class Expenses extends Table {
  TextColumn get id => text()();
  DateTimeColumn get expenseDate =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get category => text()();
  TextColumn get description => text()();
  RealColumn get amount => real()();
  TextColumn get paymentMethod => text().nullable()();
  TextColumn get registeredBy => text().nullable().references(Users, #id)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- CONFIGURACIÓN DE LA APP ---
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

/// --- LOG DE SINCRONIZACIÓN ---
class SyncLogs extends Table {
  TextColumn get id => text()();
  TextColumn get batchId => text().unique()();
  TextColumn get syncType => text()();
  DateTimeColumn get importedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get importedBy => text().nullable().references(Users, #id)();
  IntColumn get recordsCount => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- DESPACHOS RECIBIDOS (VENDEDORA) ---
class DespachosRecibidos extends Table {
  TextColumn get id => text()();
  TextColumn get vendedoraId => text()();
  TextColumn get vendedoraNombre => text()();
  DateTimeColumn get fechaDespacho => dateTime()();
  DateTimeColumn get fechaRecibido =>
      dateTime().withDefault(currentDateAndTime)();
  IntColumn get productosCount => integer().withDefault(const Constant(0))();
  TextColumn get tipo => text().withDefault(const Constant('despacho'))();
  TextColumn get rawJson => text()();
  TextColumn get status => text().withDefault(
    const Constant('aplicado'),
  )(); // 'aplicado' | 'solo_vista'

  @override
  Set<Column> get primaryKey => {id};
}

/// --- DESPACHOS ENVIADOS (ADMIN) ---
class DespachosEnviados extends Table {
  TextColumn get id => text()();
  TextColumn get vendedoraId => text()();
  TextColumn get vendedoraNombre => text()();
  DateTimeColumn get fechaEnvio => dateTime().withDefault(currentDateAndTime)();
  IntColumn get productosCount => integer().withDefault(const Constant(0))();
  TextColumn get tipo => text().withDefault(const Constant('despacho'))();
  TextColumn get rawJson => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- RENDICIONES PROCESADAS (ADMIN) ---
class RendicionesProcesadas extends Table {
  TextColumn get id => text()();
  TextColumn get vendedoraId => text()();
  TextColumn get vendedoraNombre => text()();
  DateTimeColumn get fechaRendicion => dateTime()();
  DateTimeColumn get fechaProcesado =>
      dateTime().withDefault(currentDateAndTime)();
  RealColumn get totalEfectivo => real().withDefault(const Constant(0.0))();
  RealColumn get totalTransferencia =>
      real().withDefault(const Constant(0.0))();
  RealColumn get totalGeneral => real().withDefault(const Constant(0.0))();
  IntColumn get totalItems => integer().withDefault(const Constant(0))();
  TextColumn get rawJson => text()();
  TextColumn get sessionId => text().nullable().references(Sessions, #id)();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- IPV SNAPSHOT (Inventario Físico Valorado por caja) ---
class InventorySnapshots extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(Sessions, #id)();
  TextColumn get snapshotType =>
      text().withDefault(const Constant('open'))(); // 'open' o 'close'
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get snapshotData =>
      text()(); // JSON: [{productId, name, quantity, costPerUnit, totalValue, salePrice}]
  RealColumn get totalCostValue => real().withDefault(const Constant(0.0))();
  RealColumn get totalSaleValue => real().withDefault(const Constant(0.0))();
  IntColumn get productCount => integer().withDefault(const Constant(0))();
  RealColumn get totalQuantity => real().withDefault(const Constant(0.0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- RESTAURANT CLIENTS (SMS ordering) ---
class RestaurantClients extends Table {
  TextColumn get id => text()();
  TextColumn get nombre => text()();
  TextColumn get telefono => text()();
  TextColumn get direccion => text().nullable()();
  TextColumn get referencia => text().nullable()();
  TextColumn get notas => text().nullable()();
  DateTimeColumn get fechaRegistro => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- RESTAURANT ORDERS (SMS ordering) ---
class RestaurantOrders extends Table {
  TextColumn get id => text()(); // format: {origen}-{fecha}-{seq}
  TextColumn get tipoPedido => text()(); // DOMICILIO / MESA
  TextColumn get clienteId => text().references(RestaurantClients, #id)();
  TextColumn get mesaId => text().nullable()();
  TextColumn get estado => text()(); // REGISTRADO / EN_COCINA / HECHO / EN_CAMINO / ENTREGADO / CANCELADO
  TextColumn get canalOrigen => text().nullable()();
  TextColumn get horaSolicitada => text().nullable()();
  TextColumn get metodoPago => text().nullable()();
  RealColumn get montoTotal => real().withDefault(const Constant(0.0))();
  TextColumn get creadoPorUsuarioId => text().references(Users, #id)();
  DateTimeColumn get fechaCreacion => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get smsEnviado => boolean().withDefault(const Constant(false))();
  BoolColumn get smsConfirmado => boolean().withDefault(const Constant(false))();
  IntColumn get intentosReenvio => integer().withDefault(const Constant(0))();
  TextColumn get motivoCancelacion => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- RESTAURANT ORDER ITEMS ---
class RestaurantOrderItems extends Table {
  TextColumn get id => text()();
  TextColumn get orderId => text().references(RestaurantOrders, #id)();
  TextColumn get productoCodigo => text()(); // references Products.codigoCorto
  RealColumn get cantidad => real()();
  RealColumn get precioUnitario => real()();
  RealColumn get subtotal => real()();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- TRUSTED CONTACTS (SMS origin whitelist) ---
class TrustedContacts extends Table {
  TextColumn get id => text()();
  TextColumn get rol => text()();
  TextColumn get usuarioId => text().references(Users, #id)();
  TextColumn get numeroTelefono => text()();
  BoolColumn get activo => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- SMS MESSAGES (audit log) ---
class SmsMessages extends Table {
  TextColumn get id => text()();
  TextColumn get orderId => text().references(RestaurantOrders, #id)();
  TextColumn get tipo => text()(); // PED, ACK, HEC, ENT, CAN
  TextColumn get payload => text()();
  TextColumn get origen => text()();
  TextColumn get destino => text()();
  TextColumn get estado => text()(); // sent, delivered, failed
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  IntColumn get intentos => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- RESTAURANT TABLES (mesas del local) ---
class RestaurantTables extends Table {
  TextColumn get id => text()();
  IntColumn get numero => integer().unique()();
  IntColumn get capacidad => integer()();
  TextColumn get estado => text()(); // libre / ocupada
  TextColumn get ubicacion => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- ORDER STATE HISTORY (auditoría de cambios de estado) ---
class OrderStateHistory extends Table {
  TextColumn get id => text()();
  TextColumn get orderId => text().references(RestaurantOrders, #id)();
  TextColumn get estado => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get usuarioId => text().references(Users, #id).nullable()();
  BoolColumn get viaSms => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- PRICE HISTORY (historial de precios por producto) ---
class PriceHistory extends Table {
  TextColumn get id => text()();
  TextColumn get productoCodigo => text()(); // references Products.codigoCorto
  DateTimeColumn get fechaVigencia => dateTime()();
  RealColumn get precio => real()();
  RealColumn get costoUnidad => real()();
  RealColumn get margenPct => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- DAILY SUMMARIES (cached daily close) ---
class DailySummaries extends Table {
  TextColumn get fecha => text()(); // ISO date string as PK
  RealColumn get totalVentas => real().withDefault(const Constant(0.0))();
  RealColumn get ventasEfectivo => real().withDefault(const Constant(0.0))();
  RealColumn get ventasTransferencia => real().withDefault(const Constant(0.0))();
  RealColumn get costoProduccion => real().withDefault(const Constant(0.0))();
  RealColumn get totalGastos => real().withDefault(const Constant(0.0))();
  RealColumn get totalCompras => real().withDefault(const Constant(0.0))();
  RealColumn get utilidadNeta => real().withDefault(const Constant(0.0))();
  RealColumn get distribucionYurdenis => real().withDefault(const Constant(0.0))();
  RealColumn get distribucionMildrey => real().withDefault(const Constant(0.0))();
  RealColumn get distribucionNegocio => real().withDefault(const Constant(0.0))();

  @override
  Set<Column> get primaryKey => {fecha};
}

/// --- DAILY EXPENSES (gastos del día) ---
/// Corresponde a la tabla `gastos` del PRD.
class DailyExpenses extends Table {
  TextColumn get id => text()();
  TextColumn get concepto => text()(); // concepto/gasto
  RealColumn get monto => real()();
  DateTimeColumn get fecha => dateTime()();
  TextColumn get registradoPorUsuarioId => text().references(Users, #id).nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- DAILY PURCHASES (compras/insumos del día) ---
/// Corresponde a la tabla `compras` del PRD.
class DailyPurchases extends Table {
  TextColumn get id => text()();
  TextColumn get insumo => text()(); // nombre del insumo
  TextColumn get proveedor => text().nullable()();
  RealColumn get cantidad => real()();
  RealColumn get costo => real()();
  DateTimeColumn get fecha => dateTime()();
  TextColumn get registradoPorUsuarioId => text().references(Users, #id).nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// --- DAILY PAYROLL (nómina del día) ---
/// Corresponde a la tabla `nomina` del PRD.
class DailyPayroll extends Table {
  TextColumn get id => text()();
  TextColumn get usuarioId => text().references(Users, #id)();
  DateTimeColumn get fecha => dateTime()();
  BoolColumn get trabajo => boolean()(); // si trabajó o no
  TextColumn get jornada => text().nullable()(); // ej. "completa", "medio dia"
  RealColumn get salarioBase => real()();
  RealColumn get estimulo => real().withDefault(const Constant(0.0))();
  RealColumn get total => real()(); // salarioBase + estimulo

  @override
  Set<Column> get primaryKey => {id};
}

/// ================================================================
/// CLASE PRINCIPAL DE LA BASE DE DATOS
/// ================================================================

@DriftDatabase(
  tables: [
    Categories,
    Users,
    Licenses,
    LicenciasCliente,
    Clientes,
    LicensePlanes,
    Products,
    InventoryLots,
    Inventories,
    StockMovements,
    StockAdjustments,
    PurchaseInvoices,
    PurchaseInvoiceItems,
    Sales,
    SaleItems,
    Expenses,
    AppSettings,
    SyncLogs,
    Sessions,
    Orders,
    OrderItems,
    OrderPayments,
    DespachosRecibidos,
    DespachosEnviados,
    RendicionesProcesadas,
    InventorySnapshots,
    RestaurantClients,
    RestaurantOrders,
    RestaurantOrderItems,
    TrustedContacts,
    SmsMessages,
    RestaurantTables,
    OrderStateHistory,
    PriceHistory,
    DailySummaries,
    DailyExpenses,
    DailyPurchases,
    DailyPayroll,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase._internal() : super(_openConnection());

  static AppDatabase? _instance;

  static AppDatabase get instance {
    _instance ??= AppDatabase._internal();
    return _instance!;
  }

  /// Invalidar singleton (necesario después de restaurar backup)
  static void resetInstance() {
    _instance = null;
  }



  @override
  int get schemaVersion => 14;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _createIndexes();
      // Drop POS tables (they exist in annotation for backwards compat
      // but are not used in the restaurant SMS model)
      for (final table in _posDropTables) {
        try {
          await customStatement('DROP TABLE IF EXISTS $table');
        } catch (_) {}
      }
      // Seed food categories for new installs
      await _seedFoodCategories();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        // v2: agregar tablas de facturas de compra
        await m.createTable(purchaseInvoices);
        await m.createTable(purchaseInvoiceItems);
      }
      if (from < 3) {
        // v3: agregar campo androidId a Users
        try {
          await m.addColumn(users, users.androidId);
        } catch (_) {}
      }
      if (from < 4) {
        // v4: agregar tabla de ajustes de stock
        await m.createTable(stockAdjustments);
      }
      if (from < 5) {
        // v5: agregar tablas de despachos y rendiciones
        try {
          await m.createTable(despachosRecibidos);
        } catch (_) {}
        try {
          await m.createTable(despachosEnviados);
        } catch (_) {}
        try {
          await m.createTable(rendicionesProcesadas);
        } catch (_) {}
      }
      if (from < 6) {
        // v6: agregar campos de transferencia a OrderPayments
        try {
          await m.addColumn(orderPayments, orderPayments.transactionId);
        } catch (_) {}
        try {
          await m.addColumn(orderPayments, orderPayments.purchaseId);
        } catch (_) {}
        try {
          await m.addColumn(orderPayments, orderPayments.clientName);
        } catch (_) {}
        try {
          await m.addColumn(orderPayments, orderPayments.clientPhone);
        } catch (_) {}
        try {
          await m.addColumn(orderPayments, orderPayments.clientCI);
        } catch (_) {}
        try {
          await m.addColumn(orderPayments, orderPayments.transferDate);
        } catch (_) {}
        try {
          await m.addColumn(orderPayments, orderPayments.rawSms);
        } catch (_) {}
      }
      if (from < 7) {
        // v7: agregar sessionId a Sales para vincular con pagos
        try {
          await m.addColumn(sales, sales.sessionId);
        } catch (_) {}
      }
      if (from < 8) {
        // v8: agregar índices para rendimiento (evitar full table scan)
        await _createIndexes();
      }
      if (from < 9) {
        // v9: agregar tabla de snapshots de inventario (IPV por caja)
        try {
          await m.createTable(inventorySnapshots);
        } catch (_) {}
      }
      if (from < 10) {
        // v10: agregar snapshotType a inventory_snapshots (open/close)
        try {
          await m.addColumn(
            inventorySnapshots,
            inventorySnapshots.snapshotType,
          );
        } catch (_) {}
      }
      if (from < 11) {
        // v11: agregar campo tipo a despachos (despacho/reposicion)
        try {
          await m.addColumn(despachosEnviados, despachosEnviados.tipo);
        } catch (_) {}
        try {
          await m.addColumn(despachosRecibidos, despachosRecibidos.tipo);
        } catch (_) {}
        // Backfill: leer tipo del rawJson para registros existentes
        final allDespachos = await select(despachosEnviados).get();
        for (final d in allDespachos) {
          String tipo = 'despacho';
          try {
            final raw = jsonDecode(d.rawJson) as Map<String, dynamic>;
            tipo = raw['tipo'] as String? ?? 'despacho';
          } catch (_) {}
          await (update(despachosEnviados)..where((t) => t.id.equals(d.id)))
              .write(DespachosEnviadosCompanion(tipo: Value(tipo)));
        }
        final allRecibidos = await select(despachosRecibidos).get();
        for (final d in allRecibidos) {
          String tipo = 'despacho';
          try {
            final raw = jsonDecode(d.rawJson) as Map<String, dynamic>;
            tipo = raw['tipo'] as String? ?? 'despacho';
          } catch (_) {}
          await (update(despachosRecibidos)..where((t) => t.id.equals(d.id)))
              .write(DespachosRecibidosCompanion(tipo: Value(tipo)));
        }
      }
      // v12 reserved for future wholesale_rules table migration
      if (from < 13) {
        // v13: agregar campo location a inventory_lots (almacen/pv)
        try {
          await m.addColumn(inventoryLots, inventoryLots.location);
        } catch (_) {}
      }
      if (from < 14) {
        // v14: migrate to restaurant SMS schema
        // 1. Drop 16 POS tables (physical drop, keep classes for compat)
        for (final table in _posDropTables) {
          try {
            await customStatement('DROP TABLE IF EXISTS $table');
          } catch (_) {}
        }
        // 2. Create 12 new restaurant tables
        try {
          await m.createTable(restaurantClients);
        } catch (_) {}
        try {
          await m.createTable(restaurantOrders);
        } catch (_) {}
        try {
          await m.createTable(restaurantOrderItems);
        } catch (_) {}
        try {
          await m.createTable(restaurantTables);
        } catch (_) {}
        try {
          await m.createTable(orderStateHistory);
        } catch (_) {}
        try {
          await m.createTable(priceHistory);
        } catch (_) {}
        try {
          await m.createTable(trustedContacts);
        } catch (_) {}
        try {
          await m.createTable(smsMessages);
        } catch (_) {}
        try {
          await m.createTable(dailySummaries);
        } catch (_) {}
        try {
          await m.createTable(dailyExpenses);
        } catch (_) {}
        try {
          await m.createTable(dailyPurchases);
        } catch (_) {}
        try {
          await m.createTable(dailyPayroll);
        } catch (_) {}
        // 3. Add codigoCorto column to products
        try {
          await m.addColumn(products, products.codigoCorto);
        } catch (_) {}
        // 4. Seed food categories
        await _seedFoodCategories();
        // 5. Migrate POS roles to SMS roles
        await _migrateRoles();
      }
    },
  );

  /// List of POS table names to drop in v14 migration (physical drop only).
  /// The table CLASSES remain in @DriftDatabase for compilation compat until
  /// Phase 3 removes the code that references them.
  static const List<String> _posDropTables = [
    'inventory_lots',
    'inventories',
    'stock_movements',
    'stock_adjustments',
    'purchase_invoices',
    'purchase_invoice_items',
    'sales',
    'sale_items',
    'sessions',
    'orders',
    'order_items',
    'order_payments',
    'despachos_recibidos',
    'despachos_enviados',
    'rendiciones_procesadas',
    'inventory_snapshots',
    'sync_logs',
  ];

  /// Seed food categories for the restaurant model.
  Future<void> _seedFoodCategories() async {
    try {
      await into(categories).insert(CategoriesCompanion.insert(
        id: 'solidos',
        name: 'SÓLIDOS',
        description: const Value('Hamburguesas, patacones, panes'),
      ));
    } catch (_) {}
    try {
      await into(categories).insert(CategoriesCompanion.insert(
        id: 'liquidos',
        name: 'LÍQUIDOS',
        description: const Value('Bebidas'),
      ));
    } catch (_) {}
    try {
      await into(categories).insert(CategoriesCompanion.insert(
        id: 'postres',
        name: 'POSTRES',
        description: const Value('Postres'),
      ));
    } catch (_) {}
  }

  /// Map legacy POS roles to SMS roles in the users table.
  Future<void> _migrateRoles() async {
    await customStatement(
      "UPDATE users SET role = 'admin' WHERE role = 'super_admin'",
    );
    await customStatement(
      "UPDATE users SET role = 'redes' WHERE role = 'vendedor'",
    );
    await customStatement(
      "UPDATE users SET role = 'cocina' WHERE role = 'almacenero'",
    );
  }

  /// Crear índices para acelerar queries frecuentes
  /// Sin estos, CADA query hace full table scan
  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sales_sale_date ON sales(sale_date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sales_status ON sales(status)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sales_session_id ON sales(session_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON sale_items(sale_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sale_items_product_id ON sale_items(product_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_orders_session_id ON orders(session_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_orders_paid_at ON orders(paid_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_order_payments_order_id ON order_payments(order_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_order_payments_method ON order_payments(payment_method)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_inventory_lots_product_id ON inventory_lots(product_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_inventory_lots_remaining ON inventory_lots(product_id, remaining_quantity)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(expense_date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sessions_status ON sessions(status)',
    );
  }

  // ================================================================
  // MÉTODOS DE USUARIOS
  // ================================================================

  /// Verificar si es el primer inicio (no hay usuarios)
  Future<bool> isFirstTimeSetup() async {
    final count = await (select(users)..where((u) => u.id.isNotNull())).get();
    return count.isEmpty;
  }

  /// Obtener usuario por username
  Future<User?> getUserByUsername(String username) async {
    return (select(
      users,
    )..where((u) => u.username.equals(username))).getSingleOrNull();
  }

  Future<User?> getUserById(String id) async {
    return (select(users)..where((u) => u.id.equals(id))).getSingleOrNull();
  }

  /// Debug: Listar todos los usuarios
  Future<List<User>> getAllUsers() async {
    return select(users).get();
  }

  /// Crear usuario (con bcrypt)
  Future<void> createUser({
    required String id,
    required String username,
    required String fullName,
    required String password,
    String role = 'vendedor',
    String? androidId,
  }) async {
    // Hashear contraseña con bcrypt
    final passwordHash = _hashPassword(password);

    await into(users).insert(
      UsersCompanion.insert(
        id: id,
        username: username,
        fullName: fullName,
        passwordHash: passwordHash,
        role: role,
        active: const Value(true),
        androidId: Value(androidId),
      ),
    );
  }

  /// Actualizar Android ID del usuario
  Future<void> updateUserAndroidId(String userId, String androidId) async {
    await (update(users)..where((u) => u.id.equals(userId))).write(
      UsersCompanion(androidId: Value(androidId)),
    );
  }

  /// Crear admin por defecto si no existe, o actualizar rol a super_admin
  Future<void> createDefaultAdmin() async {
    try {
      final existing = await getUserByUsername('admin');
      if (existing == null) {
        await createUser(
          id: 'admin-default',
          username: 'admin',
          fullName: 'Administrador',
          password: 'Nathy*070721',
          role: 'super_admin',
        );
        print('=== created new admin: super_admin ===');
      } else if (existing.role != 'super_admin') {
        // Actualizar rol a super_admin si existe pero no es super_admin
        await (update(users)..where((u) => u.id.equals(existing.id))).write(
          UsersCompanion(role: const Value('super_admin')),
        );
        print('=== updated admin to super_admin ===');
      } else {
        print('=== admin already super_admin ===');
      }
    } catch (e) {
      print('Error createDefaultAdmin: $e');
    }
  }

  /// Crear usuario "jefe" hardcodeado si no existe
  Future<void> createDefaultJefe() async {
    try {
      final existing = await getUserByUsername('jefe');
      if (existing == null) {
        await createUser(
          id: 'admin-jefe',
          username: 'jefe',
          fullName: 'Jefe',
          password: 'jefe1234',
          role: 'admin',
        );
        print('=== created default admin: jefe ===');
      }
    } catch (e) {
      print('Error createDefaultJefe: $e');
    }
  }

  /// Actualizar contraseña de usuario
  Future<void> updatePassword(String userId, String newPassword) async {
    final passwordHash = _hashPassword(newPassword);
    await (update(users)..where((u) => u.id.equals(userId))).write(
      UsersCompanion(
        passwordHash: Value(passwordHash),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Iniciar sesión (verificar usuario y contraseña)
  Future<User?> login(String username, String password) async {
    final user = await getUserByUsername(username);
    if (user == null || !user.active) return null;

    if (_verifyPassword(password, user.passwordHash)) {
      return user;
    }
    return null;
  }

  /// Hashear contraseña (SHA256 con salt)
  String _hashPassword(String password) {
    const salt = 'PosJVL2024';
    final bytes = utf8.encode('$password$salt');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verificar contraseña
  bool _verifyPassword(String password, String storedHash) {
    const salt = 'PosJVL2024';
    final bytes = utf8.encode('$password$salt');
    final digest = sha256.convert(bytes);
    return digest.toString() == storedHash;
  }

  // ================================================================
  // MÉTODOS DE CATEGORÍAS
  // ================================================================
  // ================================================================
  // MÉTODOS DE CATEGORÍAS
  // ================================================================

  /// Obtener todas las categorías activas
  Future<List<Category>> getAllCategories() async {
    return (select(categories)
          ..where((c) => c.isActive.equals(true))
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .get();
  }

  /// Obtener categoría por ID
  Future<Category?> getCategoryById(String id) async {
    return (select(
      categories,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  /// Agregar categoría
  Future<void> addCategory({
    required String id,
    required String name,
    String? description,
    String? color,
    String? icon,
  }) async {
    await into(categories).insert(
      CategoriesCompanion.insert(
        id: id,
        name: name,
        description: Value(description),
        color: Value(color),
        icon: Value(icon),
      ),
    );
  }

  /// Actualizar categoría
  Future<void> updateCategory({
    required String id,
    required String name,
    String? description,
    String? color,
    String? icon,
  }) async {
    await (update(categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        name: Value(name),
        description: Value(description),
        color: Value(color),
        icon: Value(icon),
      ),
    );
  }

  /// Eliminar categoría (soft delete)
  Future<void> deleteCategory(String id) async {
    await (update(categories)..where((c) => c.id.equals(id))).write(
      const CategoriesCompanion(isActive: Value(false)),
    );
  }

  // ================================================================
  // MÉTODOS DE PRODUCTOS
  // ================================================================

  /// Obtener todos los productos activos
  Future<List<Product>> getAllProducts() async {
    return (select(products)
          ..where((p) => p.isDeleted.equals(false))
          ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
        .get();
  }

  /// Obtener producto por ID
  Future<Product?> getProductById(String id) async {
    return (select(products)..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  /// Agregar lote de inventario (compra)
  Future<void> addInventoryLot({
    required String productId,
    required double quantity,
    required double costPerUnit,
    required DateTime purchaseDate,
    String? supplier,
    String? reference,
    String location = 'pv',
  }) async {
    await transaction(() async {
      // 1. Crear lote
      await into(inventoryLots).insert(
        InventoryLotsCompanion.insert(
          productId: productId,
          quantity: quantity,
          remainingQuantity: quantity,
          costPerUnit: costPerUnit,
          purchaseDate: purchaseDate,
          supplier: Value(supplier),
          reference: Value(reference),
          location: Value(location),
        ),
      );

      // 2. Actualizar inventario total
      final existing =
          await (select(inventories)..where(
                (i) =>
                    i.productId.equals(productId) & i.location.equals(location),
              ))
              .getSingleOrNull();

      if (existing != null) {
        await (update(
          inventories,
        )..where((i) => i.id.equals(existing.id))).write(
          InventoriesCompanion(
            quantity: Value(existing.quantity + quantity),
            updatedAt: Value(DateTime.now()),
          ),
        );
      } else {
        await into(inventories).insert(
          InventoriesCompanion.insert(
            productId: productId,
            location: location,
            quantity: Value(quantity),
          ),
        );
      }

      // 3. Registrar movimiento
      await into(stockMovements).insert(
        StockMovementsCompanion.insert(
          id: const Uuid().v4(),
          productId: productId,
          movementType: 'purchase',
          toLocation: Value(location),
          quantity: quantity,
          unitCost: Value(costPerUnit),
          referenceId: Value(reference),
        ),
      );
    });
  }

  /// Quitar stock del inventario (ajuste negativo)
  /// Ahora resta directamente de los lotes (FIFO)
  Future<void> removeInventoryStock({
    required String productId,
    required double quantity,
    String location = 'pv',
    String? reference,
  }) async {
    await transaction(() async {
      // 1. Obtener lotes activos de la ubicación específica (FIFO)
      final lots =
          await (select(inventoryLots)
                ..where(
                  (l) =>
                      l.productId.equals(productId) &
                      l.remainingQuantity.isBiggerThanValue(0) &
                      l.location.equals(location),
                )
                ..orderBy([(l) => OrderingTerm.asc(l.purchaseDate)]))
              .get();

      double remainingToRemove = quantity;

      for (final lot in lots) {
        if (remainingToRemove <= 0) break;

        double available = lot.remainingQuantity;
        double toRemoveFromThis = available >= remainingToRemove
            ? remainingToRemove
            : available;

        // Actualizar lote
        await (update(inventoryLots)..where((l) => l.id.equals(lot.id))).write(
          InventoryLotsCompanion(
            remainingQuantity: Value(available - toRemoveFromThis),
          ),
        );

        remainingToRemove -= toRemoveFromThis;
      }

      // Verificar que se pudo quitar todo
      if (remainingToRemove > 0.01) {
        // pequeña tolerancia por decimales
        throw Exception(
          'Stock insuficiente. Lotes disponibles: ${quantity - remainingToRemove}',
        );
      }

      // 2. Registrar movimiento
      await into(stockMovements).insert(
        StockMovementsCompanion.insert(
          id: const Uuid().v4(),
          productId: productId,
          movementType: 'adjustment',
          fromLocation: Value(location),
          quantity: -quantity,
          referenceId: Value(reference),
        ),
      );
    });
  }

  /// Vender con FIFO - retorna el costo total de la venta
  Future<double> sellWithFIFO({
    required String productId,
    required double quantity,
    required String sellerId,
    String? fromLocation,
  }) async {
    double totalCost = 0;
    double remainingToSell = quantity;

    await transaction(() async {
      // 1. Obtener lotes (más antiguos primero - FIFO)
      // Si fromLocation es null, buscar en TODOS los lotes (兼容 datos viejos sin ubicación)

      final lots =
          await (select(inventoryLots)
                ..where(
                  (l) =>
                      l.productId.equals(productId) &
                      l.remainingQuantity.isBiggerThanValue(0) &
                      (fromLocation != null
                          ? l.location.equals(fromLocation)
                          : const Constant(true)),
                )
                ..orderBy([(l) => OrderingTerm.asc(l.purchaseDate)]))
              .get();

      // 2. Consumir lotes en orden FIFO
      for (final lot in lots) {
        if (remainingToSell <= 0) break;

        final available = lot.remainingQuantity;
        final toConsume = available >= remainingToSell
            ? remainingToSell
            : available;

        totalCost += toConsume * lot.costPerUnit;
        remainingToSell -= toConsume;

        // Actualizar lote
        await (update(inventoryLots)..where((l) => l.id.equals(lot.id))).write(
          InventoryLotsCompanion(
            remainingQuantity: Value(lot.remainingQuantity - toConsume),
          ),
        );
      }

      if (remainingToSell > 0) {
        throw Exception('Stock insuficiente. Faltan $remainingToSell unidades');
      }

      // 3. Actualizar inventario (si se especifica ubicación)
      if (fromLocation != null) {
        final inventoryRecord = await (select(
          inventories,
        )..where((i) => i.productId.equals(productId) & i.location.equals(fromLocation))).get();

        if (inventoryRecord.isNotEmpty) {
          final inv = inventoryRecord.first;
          await (update(inventories)..where((i) => i.id.equals(inv.id))).write(
            InventoriesCompanion(
              quantity: Value(inv.quantity - quantity),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      }

      // 4. Registrar movimiento
      await into(stockMovements).insert(
        StockMovementsCompanion.insert(
          id: const Uuid().v4(),
          productId: productId,
          movementType: 'sale',
          fromLocation: Value(fromLocation ?? 'pv'),
          quantity: quantity,
          unitCost: Value(quantity > 0 ? totalCost / quantity : 0),
          userId: Value(sellerId),
        ),
      );
    });

    return totalCost;
  }

  /// Trasladar stock de una ubicación a otra (ej: almacen → pv)
  /// Consume lotes FIFO de la origen y crea lotes nuevos en el destino
  Future<void> transferStock({
    required String productId,
    required double quantity,
    required String fromLocation,
    required String toLocation,
    String? reference,
  }) async {
    if (fromLocation == toLocation) {
      throw Exception('No se puede trasladar a la misma ubicación');
    }

    await transaction(() async {
      // 1. Consumir lotes de la ubicación origen (FIFO)
      double remainingToTransfer = quantity;

      final lots =
          await (select(inventoryLots)
                ..where(
                  (l) =>
                      l.productId.equals(productId) &
                      l.remainingQuantity.isBiggerThanValue(0) &
                      l.location.equals(fromLocation),
                )
                ..orderBy([(l) => OrderingTerm.asc(l.purchaseDate)]))
              .get();

      final List<Map<String, dynamic>> lotDetails = [];

      for (final lot in lots) {
        if (remainingToTransfer <= 0) break;

        final available = lot.remainingQuantity;
        final toTransfer = available >= remainingToTransfer
            ? remainingToTransfer
            : available;

        // Descontar del lote origen
        await (update(inventoryLots)..where((l) => l.id.equals(lot.id))).write(
          InventoryLotsCompanion(
            remainingQuantity: Value(available - toTransfer),
          ),
        );

        lotDetails.add({
          'costPerUnit': lot.costPerUnit,
          'quantity': toTransfer,
          'purchaseDate': lot.purchaseDate,
          'supplier': lot.supplier,
        });

        remainingToTransfer -= toTransfer;
      }

      if (remainingToTransfer > 0.01) {
        throw Exception(
          'Stock insuficiente en $fromLocation. Faltan $remainingToTransfer unidades',
        );
      }

      // 2. Crear lotes nuevos en la ubicación destino
      for (final detail in lotDetails) {
        await into(inventoryLots).insert(
          InventoryLotsCompanion.insert(
            productId: productId,
            quantity: detail['quantity'] as double,
            remainingQuantity: detail['quantity'] as double,
            costPerUnit: detail['costPerUnit'] as double,
            purchaseDate: detail['purchaseDate'] as DateTime,
            supplier: Value(detail['supplier'] as String?),
            reference: Value(reference ?? 'Traslado $fromLocation → $toLocation'),
            location: Value(toLocation),
          ),
        );
      }

      // 3. Actualizar inventario resumen para AMBAS ubicaciones
      // Origen: restar
      final originInv = await (select(inventories)
            ..where((i) =>
                i.productId.equals(productId) &
                i.location.equals(fromLocation)))
          .getSingleOrNull();
      if (originInv != null) {
        await (update(inventories)..where((i) => i.id.equals(originInv.id)))
            .write(InventoriesCompanion(
              quantity: Value(originInv.quantity - quantity),
              updatedAt: Value(DateTime.now()),
            ));
      }

      // Destino: sumar
      final destInv = await (select(inventories)
            ..where((i) =>
                i.productId.equals(productId) &
                i.location.equals(toLocation)))
          .getSingleOrNull();
      if (destInv != null) {
        await (update(inventories)..where((i) => i.id.equals(destInv.id)))
            .write(InventoriesCompanion(
              quantity: Value(destInv.quantity + quantity),
              updatedAt: Value(DateTime.now()),
            ));
      } else {
        await into(inventories).insert(InventoriesCompanion.insert(
          productId: productId,
          location: toLocation,
          quantity: Value(quantity),
        ));
      }

      // 4. Registrar movimiento de stock
      await into(stockMovements).insert(
        StockMovementsCompanion.insert(
          id: const Uuid().v4(),
          productId: productId,
          movementType: 'transfer',
          fromLocation: Value(fromLocation),
          toLocation: Value(toLocation),
          quantity: quantity,
          referenceId: Value(reference),
        ),
      );
    });
  }

  /// Migrar TODO el stock de 'almacen' → 'pv' (al desactivar modo almacén)
  /// Retorna la cantidad de productos migrados
  Future<int> migrateAlmacenToPv() async {
    return await transaction(() async {
      // 1. Migrar inventoryLots: actualizar location de 'almacen' a 'pv'
      final almacenLots = await (select(inventoryLots)
            ..where((l) =>
                l.location.equals('almacen') &
                l.remainingQuantity.isBiggerThanValue(0)))
          .get();

      for (final lot in almacenLots) {
        await (update(inventoryLots)..where((l) => l.id.equals(lot.id))).write(
          InventoryLotsCompanion(
            location: const Value('pv'),
          ),
        );
      }

      // 2. Migrar tabla inventories: merge de 'almacen' → 'pv'
      final almacenInventories = await (select(inventories)
            ..where((i) => i.location.equals('almacen')))
          .get();

      for (final inv in almacenInventories) {
        // Buscar si ya existe registro en 'pv' para este producto
        final pvInv = await (select(inventories)
              ..where((i) =>
                  i.productId.equals(inv.productId) &
                  i.location.equals('pv')))
            .getSingleOrNull();

        if (pvInv != null) {
          // Sumar cantidades
          await (update(inventories)..where((i) => i.id.equals(pvInv.id)))
              .write(InventoriesCompanion(
                quantity: Value(pvInv.quantity + inv.quantity),
                updatedAt: Value(DateTime.now()),
              ));
          // Eliminar el registro de almacen
          await (delete(inventories)..where((i) => i.id.equals(inv.id))).go();
        } else {
          // Cambiar ubicación a 'pv'
          await (update(inventories)..where((i) => i.id.equals(inv.id)))
              .write(InventoriesCompanion(
                location: const Value('pv'),
                updatedAt: Value(DateTime.now()),
              ));
        }
      }

      // 3. Registrar movimiento de migración para trazabilidad
      for (final lot in almacenLots) {
        await into(stockMovements).insert(
          StockMovementsCompanion.insert(
            id: const Uuid().v4(),
            productId: lot.productId,
            movementType: 'transfer',
            fromLocation: const Value('almacen'),
            toLocation: const Value('pv'),
            quantity: lot.remainingQuantity,
            unitCost: Value(lot.costPerUnit),
            referenceId: const Value('MIGRATION_ALMACEN_TO_PV'),
            notes: const Value('Migración automática al desactivar modo almacén'),
          ),
        );
      }

      return almacenLots.length;
    });
  }

  /// Obtener lotes activos de un producto (para mostrar al usuario)
  Future<List<InventoryLot>> getActiveLots(String productId, {String? location}) async {
    return (select(inventoryLots)
          ..where(
            (l) =>
                l.productId.equals(productId) &
                l.remainingQuantity.isBiggerThanValue(0) &
                (location != null
                    ? l.location.equals(location)
                    : const Constant(true)),
          )
          ..orderBy([(l) => OrderingTerm.asc(l.purchaseDate)]))
        .get();
  }

  /// Obtener lotes activos para MÚLTIPLES productos en una sola query (batch).
  Future<List<InventoryLot>> getActiveLotsForProducts(
    List<String> productIds, {
    String? location,
  }) async {
    if (productIds.isEmpty) return [];
    return (select(inventoryLots)
          ..where(
            (l) =>
                l.productId.isIn(productIds) &
                l.remainingQuantity.isBiggerThanValue(0) &
                (location != null ? l.location.equals(location) : const Constant(true)),
          )
          ..orderBy([(l) => OrderingTerm.asc(l.purchaseDate)]))
        .get();
  }

  /// Obtener TODOS los lotes de un producto (incluidos los vendidos)
  Future<List<InventoryLot>> getAllLots(String productId) async {
    return (select(inventoryLots)
          ..where((l) => l.productId.equals(productId))
          ..orderBy([(l) => OrderingTerm.desc(l.purchaseDate)]))
        .get();
  }

  /// Obtener compras del mes actual (todos los lotes del mes)
  Future<List<InventoryLot>> getMonthlyPurchases({DateTime? date}) async {
    final now = date ?? DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return (select(inventoryLots)
          ..where(
            (l) =>
                l.purchaseDate.isBiggerOrEqualValue(startOfMonth) &
                l.purchaseDate.isSmallerOrEqualValue(endOfMonth),
          )
          ..orderBy([(l) => OrderingTerm.desc(l.purchaseDate)]))
        .get();
  }

  /// Crear factura de compra con sus items
  Future<String> createPurchaseInvoice({
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    String? supplier,
    String? notes,
  }) async {
    return await transaction(() async {
      // Generar número de factura secuencial
      final lastInvoice =
          await (select(purchaseInvoices)
                ..orderBy([(i) => OrderingTerm.desc(i.id)])
                ..limit(1))
              .getSingleOrNull();

      int nextNumber = 1;
      if (lastInvoice != null) {
        // Extraer número del formato FC-XXXX
        final parts = lastInvoice.invoiceNumber.split('-');
        if (parts.length == 2) {
          nextNumber = (int.tryParse(parts[1]) ?? 0) + 1;
        }
      }

      final invoiceNumber = 'FC-${nextNumber.toString().padLeft(4, '0')}';

      // Crear factura
      final invoiceId = await into(purchaseInvoices).insert(
        PurchaseInvoicesCompanion.insert(
          invoiceNumber: invoiceNumber,
          totalAmount: totalAmount,
          supplier: Value(supplier),
          notes: Value(notes),
        ),
      );

      // Crear items
      for (final item in items) {
        await into(purchaseInvoiceItems).insert(
          PurchaseInvoiceItemsCompanion.insert(
            invoiceId: invoiceId,
            productId: item['productId'] as String,
            productName: item['productName'] as String,
            quantity: (item['quantity'] as double),
            costPerUnit: (item['costPerUnit'] as double),
            total: (item['total'] as double),
          ),
        );
      }

      return invoiceNumber;
    });
  }

  /// Obtener facturas de compra del mes
  Future<List<PurchaseInvoice>> getMonthlyInvoices({DateTime? date}) async {
    final now = date ?? DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return (select(purchaseInvoices)
          ..where(
            (i) =>
                i.invoiceDate.isBiggerOrEqualValue(startOfMonth) &
                i.invoiceDate.isSmallerOrEqualValue(endOfMonth),
          )
          ..orderBy([(i) => OrderingTerm.desc(i.invoiceDate)]))
        .get();
  }

  /// Obtener facturas de compra por rango de fechas
  Future<List<PurchaseInvoice>> getInvoicesByDateRange({
    required DateTime from,
    required DateTime to,
  }) async {
    return (select(purchaseInvoices)
          ..where(
            (i) =>
                i.invoiceDate.isBiggerOrEqualValue(from) &
                i.invoiceDate.isSmallerOrEqualValue(to),
          )
          ..orderBy([(i) => OrderingTerm.desc(i.invoiceDate)]))
        .get();
  }

  /// Obtener items de una factura
  Future<List<PurchaseInvoiceItem>> getInvoiceItems(int invoiceId) async {
    return (select(
      purchaseInvoiceItems,
    )..where((i) => i.invoiceId.equals(invoiceId))).get();
  }

  /// Obtener costo promedio del inventario
  Future<double> getAverageCost(String productId) async {
    final lots = await getActiveLots(productId);
    if (lots.isEmpty) return 0;

    double totalCost = 0;
    double totalQty = 0;

    for (final lot in lots) {
      totalCost += lot.remainingQuantity * lot.costPerUnit;
      totalQty += lot.remainingQuantity;
    }

    return totalQty > 0 ? totalCost / totalQty : 0;
  }

  // ================================================================
  // GASTOS OPERATIVOS
  // ================================================================

  /// Registrar un nuevo gasto
  Future<void> createExpense({
    required String id,
    required String category,
    required String description,
    required double amount,
    String? paymentMethod,
    String? registeredBy,
    String? notes,
    DateTime? expenseDate,
  }) async {
    await into(expenses).insert(
      ExpensesCompanion.insert(
        id: id,
        category: category,
        description: description,
        amount: amount,
        paymentMethod: Value(paymentMethod),
        registeredBy: Value(registeredBy),
        notes: Value(notes),
        expenseDate: Value(expenseDate ?? DateTime.now()),
      ),
    );
  }

  /// Obtener gastos en un rango de fechas
  Future<List<Expense>> getExpensesByDateRange(
    DateTime from,
    DateTime to,
  ) async {
    return (select(expenses)
          ..where(
            (e) =>
                e.expenseDate.isBiggerOrEqualValue(from) &
                e.expenseDate.isSmallerOrEqualValue(to),
          )
          ..orderBy([(e) => OrderingTerm.desc(e.expenseDate)]))
        .get();
  }

  /// Total de gastos en un rango de fechas
  Future<double> getTotalExpensesByDateRange(DateTime from, DateTime to) async {
    final list = await getExpensesByDateRange(from, to);
    double total = 0;
    for (final e in list) {
      total += e.amount;
    }
    return total;
  }

  /// Gastos agrupados por categoría en un rango
  Future<Map<String, double>> getExpensesByCategory(
    DateTime from,
    DateTime to,
  ) async {
    final list = await getExpensesByDateRange(from, to);
    final map = <String, double>{};
    for (final e in list) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  /// Eliminar un gasto por ID
  Future<void> deleteExpense(String id) async {
    await (delete(expenses)..where((e) => e.id.equals(id))).go();
  }

  /// Actualizar un gasto
  Future<void> updateExpense({
    required String id,
    String? category,
    String? description,
    double? amount,
    String? paymentMethod,
    String? notes,
    DateTime? expenseDate,
  }) async {
    await (update(expenses)..where((e) => e.id.equals(id))).write(
      ExpensesCompanion(
        category: category != null ? Value(category) : const Value.absent(),
        description: description != null
            ? Value(description)
            : const Value.absent(),
        amount: amount != null ? Value(amount) : const Value.absent(),
        paymentMethod: paymentMethod != null
            ? Value(paymentMethod)
            : const Value.absent(),
        notes: notes != null ? Value(notes) : const Value.absent(),
        expenseDate: expenseDate != null
            ? Value(expenseDate)
            : const Value.absent(),
      ),
    );
  }

  /// Obtener todos los stocks (productId -> quantity)
  /// [location] filtra por ubicación. Si es null, suma de TODAS las ubicaciones
  /// (compatibilidad con datos viejos sin ubicación).
  Future<Map<String, double>> getAllStocks({String? location}) async {
    final lots = await (select(
      inventoryLots,
    )..where((l) =>
            l.remainingQuantity.isBiggerThanValue(0) &
            (location != null
                ? l.location.equals(location)
                : const Constant(true)))).get();

    final Map<String, double> stocks = {};
    for (final lot in lots) {
      stocks[lot.productId] =
          (stocks[lot.productId] ?? 0) + lot.remainingQuantity;
    }
    return stocks;
  }

  /// Obtener cantidad total en inventario (desde lotes FIFO)
  Future<double> getTotalQuantity(String productId, {String? location}) async {
    // Primero intentar desde lotes
    final lots =
        await (select(inventoryLots)..where(
              (l) =>
                  l.productId.equals(productId) &
                  l.remainingQuantity.isBiggerThanValue(0) &
                  (location != null
                      ? l.location.equals(location)
                      : const Constant(true)),
            ))
            .get();

    if (lots.isNotEmpty) {
      double total = 0;
      for (final lot in lots) {
        total += lot.remainingQuantity;
      }
      return total;
    }

    // Fallback a tabla inventory
    final inventory = await (select(
      inventories,
    )..where((i) => i.productId.equals(productId))).get();

    double total = 0;
    for (final inv in inventory) {
      total += inv.quantity;
    }
    return total;
  }

  // ================================================================
  // MÉTODOS DE AJUSTES DE STOCK
  // ================================================================

  Future<void> createStockAdjustment({
    required String productId,
    int? inventoryLotId,
    required String adjustmentType,
    required double quantity,
    double unitCost = 0,
    String? reason,
    String? userId,
  }) async {
    await into(stockAdjustments).insert(
      StockAdjustmentsCompanion.insert(
        id: const Uuid().v4(),
        productId: productId,
        inventoryLotId: Value(inventoryLotId),
        adjustmentType: adjustmentType,
        quantity: quantity,
        unitCost: Value(unitCost),
        reason: Value(reason),
        userId: Value(userId),
      ),
    );
  }

  Future<List<StockAdjustment>> getStockAdjustments({
    String? productId,
    String? adjustmentType,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 100,
  }) async {
    var query = select(stockAdjustments);
    query = query
      ..where((a) {
        var expr = a.id.isNotNull();
        if (productId != null) {
          expr = expr & a.productId.equals(productId);
        }
        if (adjustmentType != null) {
          expr = expr & a.adjustmentType.equals(adjustmentType);
        }
        if (dateFrom != null) {
          expr = expr & a.adjustedAt.isBiggerOrEqualValue(dateFrom);
        }
        if (dateTo != null) {
          expr = expr & a.adjustedAt.isSmallerOrEqualValue(dateTo);
        }
        return expr;
      })
      ..orderBy([(a) => OrderingTerm.desc(a.adjustedAt)])
      ..limit(limit);
    return query.get();
  }

  Future<void> addStockToLot({
    required int lotId,
    required double quantity,
    required double unitCost,
    String? reason,
    String? userId,
  }) async {
    await transaction(() async {
      final lot = await (select(
        inventoryLots,
      )..where((l) => l.id.equals(lotId))).getSingleOrNull();
      if (lot == null) throw Exception('Lote no encontrado');

      await (update(inventoryLots)..where((l) => l.id.equals(lotId))).write(
        InventoryLotsCompanion(
          remainingQuantity: Value(lot.remainingQuantity + quantity),
        ),
      );

      final inv =
          await (select(inventories)..where(
                (i) =>
                    i.productId.equals(lot.productId) &
                    i.location.equals('almacen'),
              ))
              .getSingleOrNull();
      if (inv != null) {
        await (update(inventories)..where((i) => i.id.equals(inv.id))).write(
          InventoriesCompanion(
            quantity: Value(inv.quantity + quantity),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }

      await createStockAdjustment(
        productId: lot.productId,
        inventoryLotId: lotId,
        adjustmentType: 'add',
        quantity: quantity,
        unitCost: unitCost,
        reason: reason,
        userId: userId,
      );

      await into(stockMovements).insert(
        StockMovementsCompanion.insert(
          id: const Uuid().v4(),
          productId: lot.productId,
          movementType: 'adjustment',
          toLocation: const Value('almacen'),
          quantity: quantity,
          unitCost: Value(unitCost),
          notes: Value(reason),
          userId: Value(userId),
        ),
      );
    });
  }

  Future<void> removeStockFromLot({
    required int lotId,
    required double quantity,
    String? reason,
    String? userId,
  }) async {
    await transaction(() async {
      final lot = await (select(
        inventoryLots,
      )..where((l) => l.id.equals(lotId))).getSingleOrNull();
      if (lot == null) throw Exception('Lote no encontrado');
      if (lot.remainingQuantity < quantity) {
        throw Exception(
          'Stock insuficiente en lote. Disponible: ${lot.remainingQuantity}',
        );
      }

      await (update(inventoryLots)..where((l) => l.id.equals(lotId))).write(
        InventoryLotsCompanion(
          remainingQuantity: Value(lot.remainingQuantity - quantity),
        ),
      );

      final inv =
          await (select(inventories)..where(
                (i) =>
                    i.productId.equals(lot.productId) &
                    i.location.equals('almacen'),
              ))
              .getSingleOrNull();
      if (inv != null) {
        await (update(inventories)..where((i) => i.id.equals(inv.id))).write(
          InventoriesCompanion(
            quantity: Value(inv.quantity - quantity),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }

      await createStockAdjustment(
        productId: lot.productId,
        inventoryLotId: lotId,
        adjustmentType: 'remove',
        quantity: quantity,
        reason: reason,
        userId: userId,
      );

      await into(stockMovements).insert(
        StockMovementsCompanion.insert(
          id: const Uuid().v4(),
          productId: lot.productId,
          movementType: 'adjustment',
          fromLocation: const Value('almacen'),
          quantity: -quantity,
          notes: Value(reason),
          userId: Value(userId),
        ),
      );
    });
  }

  // ================================================================
  // MÉTODOS DE SESIONES (POS)
  // ================================================================

  /// Obtener sesión activa actual
  Future<Session?> getActiveSession() async {
    return (select(sessions)
          ..where((s) => s.status.equals('open'))
          ..orderBy([(s) => OrderingTerm.desc(s.openingTime)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Abrir nueva sesión
  Future<void> openSession({
    required String id,
    required String userId,
    required double openingCash,
    String? description,
  }) async {
    await into(sessions).insert(
      SessionsCompanion.insert(
        id: id,
        userId: userId,
        openingTime: DateTime.now(),
        openingCash: openingCash,
        description: Value(description),
      ),
    );

    // Auto-generar IPV snapshot al abrir caja
    await createInventorySnapshot(sessionId: id, location: 'pv');
  }

  // ================================================================
  // IPV SNAPSHOTS (Inventario Físico Valorado por caja)
  // ================================================================

  /// Crear snapshot del inventario actual y asociarlo a una sesión
  Future<void> createInventorySnapshot({
    required String sessionId,
    String snapshotType = 'open',
    String? location,
  }) async {
    final allLots = await (select(
      inventoryLots,
    )..where((l) =>
            l.remainingQuantity.isBiggerThanValue(0) &
            (location != null
                ? l.location.equals(location)
                : const Constant(true)))).get();

    // Agrupar por producto
    final lotsByProduct = <String, List<InventoryLot>>{};
    for (final lot in allLots) {
      lotsByProduct.putIfAbsent(lot.productId, () => []).add(lot);
    }

    // Obtener TODOS los productos (incluso los sin stock)
    final products = await getAllProducts();
    final productMap = {for (final p in products) p.id: p};

    double totalCostValue = 0;
    double totalSaleValue = 0;
    double totalQuantity = 0;
    final snapshotItems = <Map<String, dynamic>>[];

    // Iterar TODOS los productos, incluyendo los sin lotes (qty=0)
    for (final product in products) {
      final lots = lotsByProduct[product.id] ?? [];

      double qty = 0;
      double costValue = 0;
      for (final lot in lots) {
        qty += lot.remainingQuantity;
        costValue += lot.remainingQuantity * lot.costPerUnit;
      }
      final saleValue = qty * product.unitPrice;

      totalCostValue += costValue;
      totalSaleValue += saleValue;
      totalQuantity += qty;

      snapshotItems.add({
        'productId': product.id,
        'name': product.name,
        'quantity': qty,
        'costPerUnit': qty > 0 ? costValue / qty : product.costPrice,
        'totalValue': costValue,
        'salePrice': product.unitPrice,
        'saleValue': saleValue,
      });
    }

    final snapshotId = const Uuid().v4();
    await into(inventorySnapshots).insert(
      InventorySnapshotsCompanion.insert(
        id: snapshotId,
        sessionId: sessionId,
        snapshotType: Value(snapshotType),
        snapshotData: const JsonEncoder().convert(snapshotItems),
        totalCostValue: Value(totalCostValue),
        totalSaleValue: Value(totalSaleValue),
        productCount: Value(snapshotItems.length),
        totalQuantity: Value(totalQuantity),
      ),
    );
  }

  /// Obtener el snapshot de apertura de una sesión
  Future<InventorySnapshot?> getSnapshotBySession(String sessionId) async {
    return (select(inventorySnapshots)
          ..where(
            (s) =>
                s.sessionId.equals(sessionId) & s.snapshotType.equals('open'),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  /// Obtener el snapshot de cierre de una sesión
  Future<InventorySnapshot?> getClosingSnapshotBySession(
    String sessionId,
  ) async {
    return (select(inventorySnapshots)
          ..where(
            (s) =>
                s.sessionId.equals(sessionId) & s.snapshotType.equals('close'),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  /// Obtener snapshot de la sesión ANTERIOR a esta (para comparar)
  Future<InventorySnapshot?> getPreviousSnapshot(String sessionId) async {
    final currentSession = await (select(
      sessions,
    )..where((s) => s.id.equals(sessionId))).getSingleOrNull();
    if (currentSession == null) return null;

    final prevSessions =
        await (select(sessions)
              ..where(
                (s) => s.openingTime.isSmallerThanValue(
                  currentSession.openingTime,
                ),
              )
              ..orderBy([(s) => OrderingTerm.desc(s.openingTime)])
              ..limit(1))
            .get();
    if (prevSessions.isEmpty) return null;

    return getSnapshotBySession(prevSessions.first.id);
  }

  /// Cerrar sesión
  Future<void> closeSession({
    required String id,
    required double closingCash,
    required double totalSales,
    required double totalCash,
    required double totalTransfer,
    required double totalProfit,
  }) async {
    await (update(sessions)..where((s) => s.id.equals(id))).write(
      SessionsCompanion(
        closingTime: Value(DateTime.now()),
        closingCash: Value(closingCash),
        totalSales: Value(totalSales),
        totalCash: Value(totalCash),
        totalTransfer: Value(totalTransfer),
        totalProfit: Value(totalProfit),
        status: const Value('closed'),
      ),
    );

    // Auto-generar IPV snapshot de cierre
    await createInventorySnapshot(sessionId: id, snapshotType: 'close', location: 'pv');
  }

  /// Actualizar totales de sesión (sin cerrar)
  Future<void> updateSessionTotals({
    required String id,
    required double totalSales,
    required double totalCash,
    required double totalTransfer,
  }) async {
    await (update(sessions)..where((s) => s.id.equals(id))).write(
      SessionsCompanion(
        totalSales: Value(totalSales),
        totalCash: Value(totalCash),
        totalTransfer: Value(totalTransfer),
      ),
    );
  }

  /// Obtener sesiones por usuario
  Future<List<Session>> getSessionsByUser(String userId) async {
    return (select(sessions)
          ..where((s) => s.userId.equals(userId))
          ..orderBy([(s) => OrderingTerm.desc(s.openingTime)]))
        .get();
  }

  /// Obtener sesiones con límite (mejor rendimiento)
  Future<List<Session>> getAllSessions({int limit = 100}) async {
    return (select(sessions)
          ..orderBy([(s) => OrderingTerm.desc(s.openingTime)])
          ..limit(limit))
        .get();
  }

  /// Obtener última sesión cerrada
  Future<Session?> getLastClosedSession() async {
    final result =
        await (select(sessions)
              ..where((s) => s.status.equals('closed'))
              ..orderBy([(s) => OrderingTerm.desc(s.closingTime)])
              ..limit(1))
            .get();
    return result.isEmpty ? null : result.first;
  }

  // ================================================================
  // MÉTODOS DE PEDIDOS (ORDERS - POS)
  // ================================================================

  /// Crear nuevo pedido
  Future<void> createOrder({
    required String id,
    required String sessionId,
    required String sellerId,
  }) async {
    await into(orders).insert(
      OrdersCompanion.insert(
        id: id,
        sessionId: sessionId,
        sellerId: sellerId,
        subtotal: 0,
        totalAmount: 0,
      ),
    );
  }

  /// Actualizar pedido con totales
  Future<void> updateOrder({
    required String id,
    required double subtotal,
    required double taxAmount,
    required double totalAmount,
  }) async {
    await (update(orders)..where((o) => o.id.equals(id))).write(
      OrdersCompanion(
        subtotal: Value(subtotal),
        taxAmount: Value(taxAmount),
        totalAmount: Value(totalAmount),
      ),
    );
  }

  /// Marcar pedido como pagado
  Future<void> markOrderPaid(String orderId) async {
    await (update(orders)..where((o) => o.id.equals(orderId))).write(
      OrdersCompanion(
        status: const Value('paid'),
        paidAt: Value(DateTime.now()),
      ),
    );
  }

  /// Agregar item al pedido
  Future<void> addOrderItem({
    required String id,
    required String orderId,
    required String productId,
    required String productName,
    required double quantity,
    required double unitPrice,
    required double costPrice,
    required double subtotal,
  }) async {
    await into(orderItems).insert(
      OrderItemsCompanion.insert(
        id: id,
        orderId: orderId,
        productId: productId,
        productName: productName,
        quantity: quantity,
        unitPrice: unitPrice,
        costPrice: Value(costPrice),
        subtotal: subtotal,
      ),
    );
  }

  /// Obtener items de un pedido
  Future<List<OrderItem>> getOrderItems(String orderId) async {
    return (select(
      orderItems,
    )..where((oi) => oi.orderId.equals(orderId))).get();
  }

  /// Buscar nombre de producto desde OrderItems (tiene productName guardado)
  Future<String?> getOrderItemNameByProductId(String productId) async {
    final result =
        await (select(orderItems)
              ..where((oi) => oi.productId.equals(productId))
              ..limit(1))
            .getSingleOrNull();
    return result?.productName;
  }

  /// Obtener pedido por ID
  Future<Order?> getOrderById(String id) async {
    return (select(orders)..where((o) => o.id.equals(id))).getSingleOrNull();
  }

  /// Obtener pedidos pendientes (por pagar)
  Future<List<Order>> getPendingOrders() async {
    return (select(orders)
          ..where((o) => o.status.equals('pending'))
          ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
        .get();
  }

  /// Obtener pedidos pagados por sesión
  Future<List<Order>> getPaidOrdersBySession(String sessionId) async {
    return (select(orders)
          ..where(
            (o) => o.sessionId.equals(sessionId) & o.status.equals('paid'),
          )
          ..orderBy([(o) => OrderingTerm.desc(o.paidAt)]))
        .get();
  }

  /// Anular una venta: marca la orden como 'cancelled', restaura stock y actualiza sesión
  /// Si es una devolución (orderId empieza con 'R'), REMUEVE stock en vez de restaurarlo
  Future<void> cancelOrder({
    required String orderId,
    required String reason,
    required String cancelledByUserId,
  }) async {
    await transaction(() async {
      // 1. Obtener la orden
      final order = await (select(orders)..where((o) => o.id.equals(orderId))).getSingleOrNull();
      if (order == null) throw Exception('Orden no encontrada');
      if (order.status == 'cancelled') throw Exception('Esta venta ya fue anulada');

      // Detectar si es una devolución (orderId empieza con 'R')
      final isReturn = orderId.startsWith('R');

      // 2. Obtener items de la orden
      final items = await getOrderItems(orderId);

      // 3. Ajustar stock (no abortar la anulación si falla)
      try {
        for (final item in items) {
          if (item.quantity > 0) {
            if (isReturn) {
              // Es devolución → al anularla, QUITAR el stock que se devolvió
              await removeInventoryStock(
                productId: item.productId,
                quantity: item.quantity,
                reference: 'CANCEL_RETURN_$orderId',
              );
            } else {
              // Es venta normal → al anularla, RESTAURAR el stock vendido
              // Restaurar a 'pv' (donde se vendió), no a 'almacen'
              final cost = item.costPrice > 0 ? item.costPrice : 0.0;
              await into(inventoryLots).insert(
                InventoryLotsCompanion.insert(
                  productId: item.productId,
                  quantity: item.quantity,
                  remainingQuantity: item.quantity,
                  costPerUnit: cost,
                  purchaseDate: DateTime.now(),
                  supplier: const Value('Devolucion por anulacion'),
                  reference: Value('CANCEL_$orderId'),
                  location: const Value('pv'),
                ),
              );

              // Actualizar tabla inventario
              final existingInv = await (select(inventories)
                    ..where((i) =>
                        i.productId.equals(item.productId) &
                        i.location.equals('pv')))
                  .getSingleOrNull();

              if (existingInv != null) {
                await (update(inventories)..where((i) => i.id.equals(existingInv.id))).write(
                  InventoriesCompanion(
                    quantity: Value(existingInv.quantity + item.quantity),
                    updatedAt: Value(DateTime.now()),
                  ),
                );
              } else {
                await into(inventories).insert(
                  InventoriesCompanion.insert(
                    productId: item.productId,
                    location: 'pv',
                    quantity: Value(item.quantity),
                  ),
                );
              }

              // Registrar movimiento
              await into(stockMovements).insert(
                StockMovementsCompanion.insert(
                  id: const Uuid().v4(),
                  productId: item.productId,
                  movementType: 'return',
                  toLocation: const Value('pv'),
                  quantity: item.quantity,
                  unitCost: Value(cost),
                  referenceId: Value('CANCEL_$orderId'),
                  notes: const Value('Devolucion por anulacion de venta'),
                ),
              );
            }
          }
        }
      } catch (stockError) {
        // Si falla el stock, igual seguimos con la anulación
        print('⚠️ Error restaurando stock en anulación: $stockError');
      }

      // 4. Marcar orden como cancelada
      await (update(orders)..where((o) => o.id.equals(orderId))).write(
        OrdersCompanion(
          status: const Value('cancelled'),
        ),
      );

      // 5. Si tiene sale asociada, marcar también
      final saleId = 'S$orderId';
      final existingSale = await (select(sales)..where((s) => s.id.equals(saleId))).getSingleOrNull();
      if (existingSale != null) {
        await (update(sales)..where((s) => s.id.equals(saleId))).write(
          SalesCompanion(
            status: const Value('cancelled'),
            cancellationReason: Value(reason),
            cancelledBy: Value(cancelledByUserId),
            cancelledAt: Value(DateTime.now()),
          ),
        );
      }

      // 6. Actualizar totales de la sesión
      if (order.sessionId != null) {
        await _recalculateSessionTotals(order.sessionId!);
      }
    });
  }

  /// Recalcular totales de una sesión basándose en las órdenes activas (no canceladas)
  Future<void> _recalculateSessionTotals(String sessionId) async {
    final activeOrders = await (select(orders)
          ..where((o) =>
              o.sessionId.equals(sessionId) &
              o.status.equals('paid')))
        .get();

    double totalSales = 0;
    double totalCash = 0;
    double totalTransfer = 0;

    for (final order in activeOrders) {
      totalSales += order.totalAmount;
      final payments = await getOrderPayments(order.id);
      final isReturn = order.totalAmount < 0;
      for (final p in payments) {
        if (p.amount > 0) {
          if (p.paymentMethod == 'efectivo') {
            // Devoluciones: restar del efectivo (el pago positivo es devolución de dinero)
            totalCash += isReturn ? -p.amount : p.amount;
          } else {
            totalTransfer += isReturn ? -p.amount : p.amount;
          }
        }
      }
    }

    await (update(sessions)..where((s) => s.id.equals(sessionId))).write(
      SessionsCompanion(
        totalSales: Value(totalSales),
        totalCash: Value(totalCash),
        totalTransfer: Value(totalTransfer),
      ),
    );
  }

  /// Obtener todos los pedidos pagados (historial general)
  Future<List<Order>> getAllPaidOrders({int limit = 50, int offset = 0}) async {
    final query = select(orders)
      ..where((o) => o.status.equals('paid'))
      ..orderBy([(o) => OrderingTerm.desc(o.paidAt)])
      ..limit(limit, offset: offset);
    return query.get();
  }

  /// Contar total de pedidos pagados
  Future<int> countPaidOrders() async {
    final result = await customSelect(
      'SELECT COUNT(*) as count FROM orders WHERE status = ?',
      variables: [Variable.withString('paid')],
    ).getSingle();
    return result.read<int>('count');
  }

  // ================================================================
  // MÉTODOS DE PAGOS
  // ================================================================

  /// Registrar pago
  Future<void> addPayment({
    required String id,
    required String orderId,
    required String paymentMethod,
    required double amount,
    double changeGiven = 0,
    String? reference,
    String? bank,
    String? transactionId,
    String? purchaseId,
    String? clientName,
    String? clientPhone,
    String? clientCI,
    String? transferDate,
    String? rawSms,
  }) async {
    await into(orderPayments).insert(
      OrderPaymentsCompanion.insert(
        id: id,
        orderId: orderId,
        paymentMethod: paymentMethod,
        amount: amount,
        changeGiven: Value(changeGiven),
        reference: Value(reference),
        bank: Value(bank),
        transactionId: Value(transactionId),
        purchaseId: Value(purchaseId),
        clientName: Value(clientName),
        clientPhone: Value(clientPhone),
        clientCI: Value(clientCI),
        transferDate: Value(transferDate),
        rawSms: Value(rawSms),
      ),
    );
  }

  /// Obtener pagos de un pedido
  Future<List<OrderPayment>> getOrderPayments(String orderId) async {
    return (select(
      orderPayments,
    )..where((p) => p.orderId.equals(orderId))).get();
  }

  /// Calcula el resumen de pagos de una sesión:
  /// { totalCash, totalTransfer, totalChange, cashPayments }
  Future<Map<String, double>> getSessionPaymentSummary(String sessionId) async {
    final paidOrders = await getPaidOrdersBySession(sessionId);
    if (paidOrders.isEmpty)
      return {
        'totalCash': 0,
        'totalTransfer': 0,
        'totalChange': 0,
        'cashPayments': 0,
      };

    final orderIds = paidOrders.map((o) => o.id).toList();
    final allPayments = await (select(
      orderPayments,
    )..where((p) => p.orderId.isIn(orderIds))).get();

    double totalCash = 0;
    double totalTransfer = 0;
    double totalChange = 0;

    for (final p in allPayments) {
      if (p.paymentMethod == 'efectivo') {
        totalCash += p.amount;
        totalChange += p.changeGiven;
      } else if (p.paymentMethod == 'transferencia') {
        totalTransfer += p.amount;
      }
    }

    return {
      'totalCash': totalCash,
      'totalTransfer': totalTransfer,
      'totalChange': totalChange,
      'cashPayments': totalCash,
    };
  }

  /// Obtener ganancias por sesión
  /// Primero usa el costPrice del item, si es 0 usa el costo promedio del inventario
  Future<double> getSessionProfit(String sessionId) async {
    final paidOrders = await getPaidOrdersBySession(sessionId);
    if (paidOrders.isEmpty) return 0;

    // 1 query batch: todos los items de todas las órdenes
    final orderIds = paidOrders.map((o) => o.id).toList();
    final allItems = await (select(
      orderItems,
    )..where((oi) => oi.orderId.isIn(orderIds))).get();

    // Recopilar productos que necesitan costo promedio
    final productIdsNeedCost = <String>{};
    for (final item in allItems) {
      if (item.costPrice == 0) {
        productIdsNeedCost.add(item.productId);
      }
    }

    // 1 query batch para lotes
    final costCache = <String, double>{};
    if (productIdsNeedCost.isNotEmpty) {
      final allLots = await (select(
        inventoryLots,
      )..where((l) => l.productId.isIn(productIdsNeedCost.toList()))).get();
      final Map<String, List<InventoryLot>> lotsByProduct = {};
      for (final lot in allLots) {
        lotsByProduct.putIfAbsent(lot.productId, () => []);
        lotsByProduct[lot.productId]!.add(lot);
      }
      for (final entry in lotsByProduct.entries) {
        double tc = 0, tq = 0;
        for (final lot in entry.value) {
          tc += lot.remainingQuantity * lot.costPerUnit;
          tq += lot.remainingQuantity;
        }
        costCache[entry.key] = tq > 0 ? tc / tq : 0;
      }
    }

    double profit = 0;
    for (final item in allItems) {
      final cost = item.costPrice != 0
          ? item.costPrice
          : (costCache[item.productId] ?? 0);
      profit += (item.unitPrice - cost) * item.quantity;
    }
    return profit;
  }

  // ================================================================
  // MÉTODOS DE VENTAS (SALES - para dashboard y alertas)
  // ================================================================

  /// Crear venta (se llama desde POS al completar una venta)
  Future<void> createSale({
    required String id,
    required String sellerId,
    required double totalAmount,
    required String paymentMethod,
    double discountAmount = 0,
    String? notes,
    String? sessionId,
    DateTime? saleDate,
  }) async {
    await into(sales).insert(
      SalesCompanion.insert(
        id: id,
        sellerId: sellerId,
        totalAmount: totalAmount,
        paymentMethod: paymentMethod,
        discountAmount: Value(discountAmount),
        notes: Value(notes),
        status: const Value('closed'),
        sessionId: Value(sessionId),
        saleDate: Value(saleDate ?? DateTime.now()),
      ),
    );
  }

  /// Agregar item de venta
  Future<void> addSaleItem({
    required String id,
    required String saleId,
    required String productId,
    required double quantity,
    required double unitPrice,
    required double costPriceAtSale,
    required double subtotal,
    double discountAmount = 0,
  }) async {
    await into(saleItems).insert(
      SaleItemsCompanion.insert(
        id: id,
        saleId: saleId,
        productId: productId,
        quantity: quantity,
        unitPrice: unitPrice,
        costPriceAtSale: Value(costPriceAtSale),
        subtotal: subtotal,
        discountAmount: Value(discountAmount),
      ),
    );
  }

  // ================================================================
  // MÉTODOS DE CLIENTES (para licencias)
  // ================================================================

  /// Obtener todos los clientes
  Future<List<Cliente>> getAllClientes() async {
    return (select(
      clientes,
    )..orderBy([(c) => OrderingTerm.desc(c.createdAt)])).get();
  }

  /// Contar clientes
  Future<int> getClientesCount() async {
    final result = await select(clientes).get();
    return result.length;
  }

  /// Agregar cliente
  Future<void> addCliente({
    required String id,
    required String nombre,
    required String telefono,
    String? negocio,
    String? email,
    String? notas,
  }) async {
    await into(clientes).insert(
      ClientesCompanion.insert(
        id: id,
        nombre: nombre,
        telefono: telefono,
        negocio: Value(negocio),
        email: Value(email),
        notas: Value(notas),
        active: const Value(true),
      ),
    );
  }

  /// Actualizar cliente
  Future<void> updateCliente({
    required String id,
    required String nombre,
    required String telefono,
    String? negocio,
    String? email,
    String? notas,
    bool? active,
  }) async {
    await (update(clientes)..where((c) => c.id.equals(id))).write(
      ClientesCompanion(
        nombre: Value(nombre),
        telefono: Value(telefono),
        negocio: Value(negocio),
        email: Value(email),
        notas: Value(notas),
        active: Value(active ?? true),
      ),
    );
  }

  /// Eliminar cliente (soft delete)
  Future<void> deleteCliente(String id) async {
    await (update(clientes)..where((c) => c.id.equals(id))).write(
      const ClientesCompanion(active: Value(false)),
    );
  }

  /// Reactivar cliente inactivo
  Future<void> reactivarCliente(String id) async {
    await (update(clientes)..where((c) => c.id.equals(id))).write(
      const ClientesCompanion(active: Value(true)),
    );
  }

  /// Obtener clientes inactivos
  Future<List<Cliente>> getInactiveClientes() async {
    return (select(clientes)
          ..where((c) => c.active.equals(false))
          ..orderBy([(c) => OrderingTerm.desc(c.createdAt)]))
        .get();
  }

  /// Obtener cliente por ID
  Future<Cliente?> getClienteById(String id) async {
    return (select(clientes)..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  /// Buscar clientes por nombre o teléfono
  Future<List<Cliente>> searchClientes(String query) async {
    final lowerQuery = '%${query.toLowerCase()}%';
    return (select(clientes)
          ..where(
            (c) =>
                c.nombre.lower().like(lowerQuery) |
                c.telefono.lower().like(lowerQuery) |
                c.negocio.lower().like(lowerQuery),
          )
          ..orderBy([(c) => OrderingTerm.desc(c.createdAt)]))
        .get();
  }

  /// Obtener clientes activos
  Future<List<Cliente>> getActiveClientes() async {
    return (select(clientes)
          ..where((c) => c.active.equals(true))
          ..orderBy([(c) => OrderingTerm.desc(c.createdAt)]))
        .get();
  }

  // ================================================================
  // MÉTODOS DE LICENCIAS
  // ================================================================

  /// Obtener todas las licencias
  Future<List<License>> getAllLicenses() async {
    return (select(
      licenses,
    )..orderBy([(l) => OrderingTerm.desc(l.createdAt)])).get();
  }

  /// Contar licencias activas
  Future<int> getActiveLicensesCount() async {
    final result = await (select(
      licenses,
    )..where((l) => l.activa.equals(true))).get();
    return result.length;
  }

  /// Crear licencia
  Future<void> createLicense({
    required String id,
    required String licenseKey,
    required String tipo,
    required DateTime fechaInicio,
    required DateTime fechaFin,
    String? dispositivoId,
  }) async {
    await into(licenses).insert(
      LicensesCompanion.insert(
        id: id,
        licenseKey: licenseKey,
        tipo: tipo,
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
        dispositivoId: Value(dispositivoId),
      ),
    );
  }

  // ================================================================
  // MÉTODOS DE PLANES DE LICENCIAS
  // ================================================================

  /// Obtener todos los planes activos
  Future<List<LicensePlane>> getAllLicensePlanes() async {
    return (select(licensePlanes)
          ..where((p) => p.activa.equals(true))
          ..orderBy([(p) => OrderingTerm.asc(p.nombre)]))
        .get();
  }

  /// Obtener todos los planes (incluyendo inactivos) — para administración
  Future<List<LicensePlane>> getAllLicensePlanesAdmin() async {
    return (select(
      licensePlanes,
    )..orderBy([(p) => OrderingTerm.asc(p.nombre)])).get();
  }

  /// Obtener plan por nombre
  Future<LicensePlane?> getPlanByName(String nombre) async {
    return (select(licensePlanes)
          ..where((p) => p.nombre.equals(nombre) & p.activa.equals(true)))
        .getSingleOrNull();
  }

  /// Crear plan
  Future<void> createLicensePlan({
    required String nombre,
    required double precio,
    String? descripcion,
    required int diasDuracion,
    required int maxProductos,
    required int maxVendedores,
  }) async {
    // Generate ID from nombre (uppercase)
    final id = nombre.toUpperCase();
    await into(licensePlanes).insert(
      LicensePlanesCompanion.insert(
        id: id,
        nombre: nombre,
        precio: precio,
        descripcion: Value(descripcion),
        diasDuracion: diasDuracion,
        maxProductos: maxProductos,
        maxVendedores: maxVendedores,
        activa: const Value(true),
      ),
    );
  }

  /// Actualizar plan
  Future<void> updateLicensePlan({
    required String id,
    String? nombre,
    double? precio,
    String? descripcion,
    int? diasDuracion,
    int? maxProductos,
    int? maxVendedores,
    bool? activa,
  }) async {
    await (update(licensePlanes)..where((p) => p.id.equals(id))).write(
      LicensePlanesCompanion(
        nombre: nombre != null ? Value(nombre) : const Value.absent(),
        precio: precio != null ? Value(precio) : const Value.absent(),
        descripcion: Value(descripcion),
        diasDuracion: diasDuracion != null
            ? Value(diasDuracion)
            : const Value.absent(),
        maxProductos: maxProductos != null
            ? Value(maxProductos)
            : const Value.absent(),
        maxVendedores: maxVendedores != null
            ? Value(maxVendedores)
            : const Value.absent(),
        activa: activa != null ? Value(activa) : const Value.absent(),
      ),
    );
  }

  /// Eliminar plan (soft delete)
  Future<void> deleteLicensePlan(String id) async {
    await (update(licensePlanes)..where((p) => p.id.equals(id))).write(
      const LicensePlanesCompanion(activa: Value(false)),
    );
  }

  /// Inicializar planes por defecto si no existen
  Future<void> initDefaultPlans() async {
    final plans = await getAllLicensePlanesAdmin();

    // Eliminar planes viejos (3-plan system) si existen
    final oldPlanNames = {'FREE', 'PRO', 'NEGOCIO'};
    final newPlanNames = {'FREE', 'NEGOCIO', 'PRO', 'MAX', 'MAXPRO'};

    bool needsReseed = false;
    if (plans.isEmpty) {
      needsReseed = true;
    } else {
      // Check if old 3-plan data exists (old FREE had 50 products, old PRO had 4.99 price)
      for (final p in plans) {
        if (oldPlanNames.contains(p.nombre)) {
          if ((p.nombre == 'FREE' && p.maxProductos == 50) ||
              (p.nombre == 'PRO' && p.precio == 4.99) ||
              (p.nombre == 'NEGOCIO' && p.precio == 9.99) ||
              !newPlanNames.contains(p.nombre)) {
            needsReseed = true;
            break;
          }
        }
      }
      // Also need reseed if we don't have all 5 plans
      final existingNames = plans
          .where((p) => p.activa)
          .map((p) => p.nombre)
          .toSet();
      if (!newPlanNames.every((n) => existingNames.contains(n))) {
        needsReseed = true;
      }
    }

    if (needsReseed) {
      // Soft-delete all existing plans
      for (final p in plans) {
        await (update(licensePlanes)..where((pl) => pl.id.equals(p.id))).write(
          const LicensePlanesCompanion(activa: Value(false)),
        );
      }

      // Seed new 5-plan system
      await createLicensePlan(
        nombre: 'FREE',
        precio: 0,
        descripcion: 'Plan gratuito - 15 días de prueba',
        diasDuracion: 15,
        maxProductos: 100,
        maxVendedores: 1,
      );
      await createLicensePlan(
        nombre: 'NEGOCIO',
        precio: 3000,
        descripcion: 'Plan negocio - 31 días',
        diasDuracion: 31,
        maxProductos: 100,
        maxVendedores: 1,
      );
      await createLicensePlan(
        nombre: 'PRO',
        precio: 8000,
        descripcion: 'Plan profesional - 90 días',
        diasDuracion: 90,
        maxProductos: 200,
        maxVendedores: 2,
      );
      await createLicensePlan(
        nombre: 'MAX',
        precio: 16000,
        descripcion: 'Plan máximo - 180 días',
        diasDuracion: 180,
        maxProductos: 300,
        maxVendedores: 3,
      );
      await createLicensePlan(
        nombre: 'MAXPRO',
        precio: 30000,
        descripcion: 'Plan máximo pro - 365 días',
        diasDuracion: 365,
        maxProductos: 1000,
        maxVendedores: 5,
      );
    }
  }

  /// Borrar todo y reiniciar (super_admin) — borra TODOS los datos de negocio
  /// Preserva: users, licensePlanes, licenses, licenciasCliente, clientes
  /// NO resetea auto-increment IDs
  Future<void> clearAllDataAdmin() async {
    await transaction(() async {
      // Datos de ventas y órdenes
      await delete(saleItems).go();
      await delete(sales).go();
      await delete(orderPayments).go();
      await delete(orderItems).go();
      await delete(orders).go();
      await delete(sessions).go();

      // Datos de inventario y stock
      await delete(stockAdjustments).go();
      await delete(stockMovements).go();
      await delete(inventoryLots).go();
      await delete(inventories).go();
      await delete(purchaseInvoiceItems).go();
      await delete(purchaseInvoices).go();

      // Productos y categorías
      await delete(products).go();
      await delete(categories).go();

      // Gastos
      await delete(expenses).go();

      // Sincronización e historial
      await delete(syncLogs).go();
      await delete(despachosRecibidos).go();
      await delete(despachosEnviados).go();
      await delete(rendicionesProcesadas).go();

      // Settings de la app (kiosco, etc)
      await delete(appSettings).go();
    });
  }

  /// Poner stock de 10000 a todos los productos activos.
  /// Elimina todos los lotes existentes y crea uno nuevo de 10000 por producto.
  /// También actualiza la tabla de inventario.
  Future<void> setAllStockTo10000() async {
    await transaction(() async {
      final allProducts =
          await (select(products)
                ..where((p) => p.isDeleted.equals(false)))
              .get();

      for (final product in allProducts) {
        // Eliminar lotes existentes de este producto
        await (delete(inventoryLots)
              ..where((l) => l.productId.equals(product.id)))
            .go();

        // Eliminar inventario existente de este producto
        await (delete(inventories)
              ..where((i) => i.productId.equals(product.id)))
            .go();

        // Crear nuevo lote de 10000 con costo del producto
        await into(inventoryLots).insert(
          InventoryLotsCompanion.insert(
            productId: product.id,
            quantity: 10000,
            remainingQuantity: 10000,
            costPerUnit: product.costPrice,
            purchaseDate: DateTime.now(),
            supplier: const Value('Ajuste masivo'),
            reference: const Value('SET_ALL_10000'),
            location: const Value('pv'),
          ),
        );

        // Actualizar tabla inventario
        await into(inventories).insert(
          InventoriesCompanion.insert(
            productId: product.id,
            location: 'pv',
            quantity: const Value(10000),
          ),
        );

        // Registrar movimiento
        await into(stockMovements).insert(
          StockMovementsCompanion.insert(
            id: const Uuid().v4(),
            productId: product.id,
            movementType: 'bulk',
            toLocation: const Value('almacen'),
            quantity: 10000,
            unitCost: Value(product.costPrice),
            notes: const Value('Ajuste masivo: stock = 10000'),
          ),
        );
      }
    });
  }

  /// Reiniciar ciclo — borra SOLO ventas, órdenes, pagos y sesiones.
  /// Conserva: productos, categorías, inventario, compras, gastos, despachos, rendiciones.
  /// Útil para cerrar un mes/período y empezar de cero con ventas.
  Future<void> clearSalesData() async {
    await transaction(() async {
      await delete(saleItems).go();
      await delete(sales).go();
      await delete(orderPayments).go();
      await delete(orderItems).go();
      await delete(orders).go();
      await delete(sessions).go();
    });
  }

  /// Calcular ingresos totales de licencias activas
  Future<double> getTotalLicenseIncome() async {
    final activeLicenses = await (select(
      licenses,
    )..where((l) => l.activa.equals(true))).get();

    double total = 0;
    for (final license in activeLicenses) {
      // Buscar el plan basado en el licenseKey (contiene el tipo de plan)
      final planName = license.licenseKey.split('-').elementAt(1);
      final plan = await (select(
        licensePlanes,
      )..where((p) => p.nombre.equals(planName))).getSingleOrNull();
      if (plan != null) {
        total += plan.precio;
      }
    }
    return total;
  }

  // ================================================================
  // MÉTODOS DE LICENCIAS CLIENTE (NUEVA TABLA)
  // ================================================================

  /// Obtener todas las licencias de clientes
  Future<List<LicenciasClienteData>> getAllLicenciasCliente() async {
    return (select(
      licenciasCliente,
    )..orderBy([(l) => OrderingTerm.desc(l.createdAt)])).get();
  }

  /// Obtener licencias de clientes con paginación
  Future<List<LicenciasClienteData>> getLicenciasClientePaginadas({
    required int limit,
    required int offset,
    String? estado,
  }) async {
    final query = select(licenciasCliente);

    // Aplicar filtro por estado
    if (estado != null && estado.isNotEmpty) {
      query.where((l) => l.estado.equals(estado));
    }

    query
      ..orderBy([(l) => OrderingTerm.desc(l.createdAt)])
      ..limit(limit, offset: offset);

    return query.get();
  }

  /// Contar total de licencias (con filtro opcional por estado)
  Future<int> getLicenciasCount({String? estado}) async {
    final query = select(licenciasCliente);
    if (estado != null && estado.isNotEmpty) {
      query.where((l) => l.estado.equals(estado));
    }
    final result = await query.get();
    return result.length;
  }

  /// Obtener licencias por cliente
  Future<List<LicenciasClienteData>> getLicenciasByCliente(
    String clienteId,
  ) async {
    return (select(licenciasCliente)
          ..where((l) => l.clienteId.equals(clienteId))
          ..orderBy([(l) => OrderingTerm.desc(l.fechaCreacion)]))
        .get();
  }

  /// Obtener licencia activa de un cliente
  Future<LicenciasClienteData?> getActiveLicenciaByCliente(
    String clienteId,
  ) async {
    return (select(licenciasCliente)
          ..where(
            (l) => l.clienteId.equals(clienteId) & l.estado.equals('activa'),
          )
          ..orderBy([(l) => OrderingTerm.desc(l.fechaExpiracion)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Contar licencias por estado
  Future<Map<String, int>> getLicenciasCountByEstado() async {
    final licencias = await getAllLicenciasCliente();
    int activas = 0;
    int vencidas = 0;
    int canceladas = 0;

    final now = DateTime.now();
    for (final lic in licencias) {
      switch (lic.estado) {
        case 'activa':
          if (lic.fechaExpiracion.isAfter(now)) {
            activas++;
          } else {
            // Actualizar estado a vencido
            await (update(
              licenciasCliente,
            )..where((l) => l.id.equals(lic.id))).write(
              const LicenciasClienteCompanion(estado: Value('vencida')),
            );
            vencidas++;
          }
          break;
        case 'vencida':
          vencidas++;
          break;
        case 'cancelada':
          canceladas++;
          break;
        default:
          activas++;
      }
    }

    return {
      'activa': activas,
      'vencida': vencidas,
      'cancelada': canceladas,
      'total': licencias.length,
    };
  }

  /// Calcular ingresos totales por licencias
  Future<double> getTotalLicenciasIngresos() async {
    final licencias = await getAllLicenciasCliente();
    double total = 0;
    for (final lic in licencias) {
      if (lic.estado == 'activa') {
        total += lic.precioPagado;
      }
    }
    return total;
  }

  /// Calcular ingresos por mes
  Future<Map<String, double>> getIngresosPorMes({int months = 12}) async {
    final licencias = await getAllLicenciasCliente();
    final Map<String, double> ingresos = {};
    final now = DateTime.now();

    for (int i = 0; i < months; i++) {
      final date = DateTime(now.year, now.month - i, 1);
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      ingresos[key] = 0;
    }

    for (final lic in licencias) {
      final key =
          '${lic.fechaCreacion.year}-${lic.fechaCreacion.month.toString().padLeft(2, '0')}';
      if (ingresos.containsKey(key)) {
        ingresos[key] = (ingresos[key] ?? 0) + lic.precioPagado;
      }
    }

    return ingresos;
  }

  /// Crear licencia para cliente
  Future<void> createLicenciaCliente({
    required String id,
    required String clienteId,
    required String codigo,
    required String plan,
    required DateTime fechaCreacion,
    required DateTime fechaExpiracion,
    double precioPagado = 0,
    String? dispositivoId,
    String? notas,
    String estado = 'activa',
  }) async {
    await into(licenciasCliente).insert(
      LicenciasClienteCompanion.insert(
        id: id,
        clienteId: clienteId,
        codigo: codigo,
        plan: plan,
        fechaCreacion: fechaCreacion,
        fechaExpiracion: fechaExpiracion,
        estado: Value(estado),
        precioPagado: Value(precioPagado),
        dispositivoId: Value(dispositivoId),
        notas: Value(notas),
      ),
    );
  }

  /// Actualizar licencia de cliente
  Future<void> updateLicenciaCliente({
    required String id,
    String? codigo,
    String? plan,
    DateTime? fechaExpiracion,
    String? estado,
    double? precioPagado,
    String? dispositivoId,
    String? notas,
  }) async {
    await (update(licenciasCliente)..where((l) => l.id.equals(id))).write(
      LicenciasClienteCompanion(
        codigo: codigo != null ? Value(codigo) : const Value.absent(),
        plan: plan != null ? Value(plan) : const Value.absent(),
        fechaExpiracion: fechaExpiracion != null
            ? Value(fechaExpiracion)
            : const Value.absent(),
        estado: estado != null ? Value(estado) : const Value.absent(),
        precioPagado: precioPagado != null
            ? Value(precioPagado)
            : const Value.absent(),
        dispositivoId: Value(dispositivoId),
        notas: Value(notas),
      ),
    );
  }

  /// Renovar licencia
  Future<void> renewLicenciaCliente(String id, int diasExtension) async {
    final licencia = await (select(
      licenciasCliente,
    )..where((l) => l.id.equals(id))).getSingleOrNull();

    if (licencia != null) {
      final nuevaFechaExpiracion = licencia.fechaExpiracion.add(
        Duration(days: diasExtension),
      );
      await (update(licenciasCliente)..where((l) => l.id.equals(id))).write(
        LicenciasClienteCompanion(
          fechaExpiracion: Value(nuevaFechaExpiracion),
          estado: const Value('activa'),
        ),
      );
    }
  }

  /// Renovar TODAS las licencias activas de un cliente de una sola vez
  Future<int> batchRenewLicenciasByCliente(
    String clienteId,
    int diasExtension,
  ) async {
    final activas =
        await (select(licenciasCliente)
              ..where((l) => l.clienteId.equals(clienteId))
              ..where((l) => l.estado.equals('activa')))
            .get();

    for (final lic in activas) {
      final nuevaFecha = lic.fechaExpiracion.add(Duration(days: diasExtension));
      await (update(licenciasCliente)..where((l) => l.id.equals(lic.id))).write(
        LicenciasClienteCompanion(
          fechaExpiracion: Value(nuevaFecha),
          estado: const Value('activa'),
        ),
      );
    }
    return activas.length;
  }

  /// Renovar TODAS las licencias vencidas/activas de un cliente generando código NUEVO
  /// Retorna las licencias renovadas con sus nuevos códigos
  Future<List<Map<String, dynamic>>> batchRenewWithNewCodes(
    String clienteId,
    int diasDuracion,
    String plan, {
    String dispositivoId = '',
  }) async {
    final licencias =
        await (select(licenciasCliente)..where(
              (l) =>
                  l.clienteId.equals(clienteId) &
                  (l.estado.equals('activa') | l.estado.equals('vencida')),
            ))
            .get();

    final renovadas = <Map<String, dynamic>>[];
    for (final lic in licencias) {
      final nuevaFecha = DateTime.now().add(Duration(days: diasDuracion));
      final nuevoCodigo = LicenseService.generateLicenseCode(
        'CLIENTE',
        lic.plan,
        nuevaFecha,
        dispositivoId,
      );

      await (update(licenciasCliente)..where((l) => l.id.equals(lic.id))).write(
        LicenciasClienteCompanion(
          codigo: Value(nuevoCodigo),
          fechaExpiracion: Value(nuevaFecha),
          estado: const Value('activa'),
          fechaCreacion: Value(DateTime.now()),
        ),
      );

      renovadas.add({
        'codigo_anterior': lic.codigo,
        'codigo_nuevo': nuevoCodigo,
        'plan': lic.plan,
      });
    }
    return renovadas;
  }

  /// Cambiar plan de TODAS las licencias de un cliente
  Future<int> batchChangePlanByCliente(
    String clienteId,
    String nuevoPlan,
  ) async {
    final licencias =
        await (select(licenciasCliente)..where(
              (l) =>
                  l.clienteId.equals(clienteId) &
                  (l.estado.equals('activa') | l.estado.equals('vencida')),
            ))
            .get();

    for (final lic in licencias) {
      await (update(licenciasCliente)..where((l) => l.id.equals(lic.id))).write(
        LicenciasClienteCompanion(plan: Value(nuevoPlan)),
      );
    }
    return licencias.length;
  }

  /// Cancelar licencia (cambia estado a cancelada y registra fecha de cancelación)
  Future<void> cancelLicenciaCliente(String id) async {
    await (update(licenciasCliente)..where((l) => l.id.equals(id))).write(
      LicenciasClienteCompanion(
        estado: const Value('cancelada'),
        fechaCancelacion: Value(DateTime.now()),
      ),
    );
  }

  /// Obtener licencias próximas a vencer (en X días)
  Future<List<LicenciasClienteData>> getLicenciasProximasVencer(
    int dias,
  ) async {
    final now = DateTime.now();
    final fechaLimite = now.add(Duration(days: dias));

    return (select(licenciasCliente)
          ..where(
            (l) =>
                l.estado.equals('activa') &
                l.fechaExpiracion.isBiggerOrEqualValue(now) &
                l.fechaExpiracion.isSmallerOrEqualValue(fechaLimite),
          )
          ..orderBy([(l) => OrderingTerm.asc(l.fechaExpiracion)]))
        .get();
  }

  /// Obtener licencias vencidas
  Future<List<LicenciasClienteData>> getLicenciasVencidas() async {
    final now = DateTime.now();

    return (select(licenciasCliente)
          ..where(
            (l) =>
                l.estado.equals('activa') &
                l.fechaExpiracion.isSmallerThanValue(now),
          )
          ..orderBy([(l) => OrderingTerm.desc(l.fechaExpiracion)]))
        .get();
  }

  // ================================================================
  // MÉTODOS DEL HOME DASHBOARD (NUEVO)
  // NOTA: Leen de orders/orderPayments/orderItems (tabla que SIEMPRE tiene datos)
  //       en vez de sales/saleItems (que pueden estar vacías si las ventas son
  //       previas a la implementación del dual-write).
  // ================================================================

  /// Helper: obtener pedidos pagados en un rango de fechas (usando paidAt)
  Future<List<Order>> _getPaidOrdersInRange(
    DateTime start,
    DateTime end,
  ) async {
    final allOrders =
        await (select(orders)..where(
              (o) =>
                  o.status.equals('paid') &
                  o.totalAmount.isBiggerOrEqualValue(0),
            ))
            .get();

    return allOrders.where((o) {
      if (o.paidAt == null) return false;
      return !o.paidAt!.isBefore(start) && o.paidAt!.isBefore(end);
    }).toList();
  }

  Future<List<Order>> getPaidOrdersInRange(
    DateTime start,
    DateTime end,
  ) async {
    return _getPaidOrdersInRange(start, end);
  }

  /// Todas las órdenes pagadas en un rango (incluye devoluciones)
  Future<List<Order>> getAllPaidOrdersInRange(
    DateTime start,
    DateTime end,
  ) async {
    final allOrders =
        await (select(orders)..where(
              (o) => o.status.equals('paid'),
            ))
            .get();

    return allOrders.where((o) {
      if (o.paidAt == null) return false;
      return !o.paidAt!.isBefore(start) && o.paidAt!.isBefore(end);
    }).toList();
  }

  Future<List<Sale>> getSalesByDateRange(DateTime start, DateTime end) async {
    return _getSalesInRange(start, end);
  }

  Future<List<SaleItem>> getSaleItemsBySaleId(String saleId) async {
    return (select(saleItems)..where((si) => si.saleId.equals(saleId))).get();
  }

  /// Top N productos más vendidos por cantidad en un rango de fechas
  Future<List<Map<String, dynamic>>> getTopProductsByDateRange(
    DateTime from,
    DateTime to, {
    int limit = 5,
  }) async {
    return _getTopProductsInRange(from, to, limit: limit);
  }

  /// Top N productos por ganancia en un rango de fechas
  Future<List<Map<String, dynamic>>> getTopProfitProductsByDateRange(
    DateTime from,
    DateTime to, {
    int limit = 5,
  }) async {
    return _getTopProductsInRange(from, to, limit: limit);
    final top = await getTopProductsByDateRange(from, to, limit: 100);
    top.sort(
      (a, b) => (b['profit'] as double).compareTo(a['profit'] as double),
    );
    return top.take(limit).toList();
  }

  /// Ventas agrupadas por día del mes (para frecuencia)
  Future<Map<int, double>> getDailySalesInRange(
    DateTime from,
    DateTime to,
  ) async {
    final sales = await _getSalesInRange(from, to);
    final Map<int, double> daily = {};
    for (final sale in sales) {
      final day = sale.saleDate.day;
      daily[day] = (daily[day] ?? 0) + sale.totalAmount;
    }
    return daily;
  }

  /// Cantidad de tickets (ventas) en un rango
  Future<int> getSalesCountByDateRange(DateTime from, DateTime to) async {
    final sales = await _getSalesInRange(from, to);
    return sales.length;
  }

  /// Ventas agrupadas por día de la semana (0=domingo..6=sábado)
  Future<Map<int, double>> getSalesByDayOfWeek(
    DateTime from,
    DateTime to,
  ) async {
    final sales = await _getSalesInRange(from, to);
    final Map<int, double> byDay = {};
    for (final sale in sales) {
      final dow = sale.saleDate.weekday % 7; // 0=domingo
      byDay[dow] = (byDay[dow] ?? 0) + sale.totalAmount;
    }
    return byDay;
  }

  /// Ventas agrupadas por categoría de producto
  Future<Map<String, double>> getSalesByCategory(
    DateTime from,
    DateTime to,
  ) async {
    final sales = await _getSalesInRange(from, to);
    if (sales.isEmpty) return {};

    // 1 query batch: todos los items
    final saleIds = sales.map((s) => s.id).toList();
    final allItems = await (select(
      saleItems,
    )..where((si) => si.saleId.isIn(saleIds))).get();

    // 1 query batch: todos los productos involucrados
    final productIds = allItems.map((i) => i.productId).toSet().toList();
    final allProducts = await (select(
      products,
    )..where((p) => p.id.isIn(productIds))).get();
    final productMap = {for (final p in allProducts) p.id: p};

    // 1 query batch: todas las categorías
    final categoryIds = allProducts
        .map((p) => p.categoryId)
        .whereType<String>()
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    final catNames = <String, String>{};
    if (categoryIds.isNotEmpty) {
      final cats = await (select(
        categories,
      )..where((c) => c.id.isIn(categoryIds))).get();
      for (final cat in cats) {
        catNames[cat.id] = cat.name;
      }
    }

    // 1 query batch: lotes para costos
    final needCost = productIds.where((pid) {
      final items = allItems.where((i) => i.productId == pid);
      return items.any((i) => i.costPriceAtSale == 0);
    }).toList();
    final costCache = <String, double>{};
    if (needCost.isNotEmpty) {
      final allLots = await (select(
        inventoryLots,
      )..where((l) => l.productId.isIn(needCost))).get();
      final Map<String, List<InventoryLot>> lotsByProduct = {};
      for (final lot in allLots) {
        lotsByProduct.putIfAbsent(lot.productId, () => []);
        lotsByProduct[lot.productId]!.add(lot);
      }
      for (final entry in lotsByProduct.entries) {
        double tc = 0, tq = 0;
        for (final lot in entry.value) {
          tc += lot.remainingQuantity * lot.costPerUnit;
          tq += lot.remainingQuantity;
        }
        costCache[entry.key] = tq > 0 ? tc / tq : 0;
      }
    }

    // Agrupar en memoria
    final Map<String, double> byCategory = {};
    for (final item in allItems) {
      final product = productMap[item.productId];
      if (product != null) {
        final catName = catNames[product.categoryId] ?? 'Sin categoría';
        byCategory[catName] = (byCategory[catName] ?? 0) + item.subtotal;
      }
    }

    return byCategory;
  }

  /// Obtener nombre de categoría por ID
  Future<String> _getCategoryName(String? categoryId) async {
    if (categoryId == null || categoryId.isEmpty) return 'Sin categoría';
    final cat = await (select(
      categories,
    )..where((c) => c.id.equals(categoryId))).getSingleOrNull();
    return cat?.name ?? 'Sin categoría';
  }

  /// Ventas del período anterior de la misma duración (para comparativa)
  Future<double> getPreviousPeriodSales(DateTime from, DateTime to) async {
    final duration = to.difference(from);
    final prevFrom = from.subtract(duration);
    final prevTo = from;
    final sales = await _getSalesInRange(prevFrom, prevTo);
    double total = 0;
    for (final s in sales) {
      total += s.totalAmount;
    }
    return total;
  }

  /// Ganancia del período anterior (para comparativa)
  Future<double> getPreviousPeriodProfit(DateTime from, DateTime to) async {
    final duration = to.difference(from);
    final prevFrom = from.subtract(duration);
    final prevTo = from;
    return getProfitByDateRange(prevFrom, prevTo);
  }

  /// Ventas del rango usando tabla Sales (fuente de verdad para dashboard)
  Future<List<Sale>> _getSalesInRange(DateTime start, DateTime end) async {
    return (select(sales)
          ..where(
            (s) =>
                s.saleDate.isBiggerOrEqualValue(start) &
                s.saleDate.isSmallerOrEqualValue(end) &
                s.totalAmount.isBiggerOrEqualValue(0) &
                s.status.equals('closed'),
          )
          ..orderBy([(s) => OrderingTerm.desc(s.saleDate)]))
        .get();
  }

  /// Devoluciones del rango
  Future<List<Sale>> _getReturnsInRange(DateTime start, DateTime end) async {
    return (select(sales)..where(
          (s) =>
              s.saleDate.isBiggerOrEqualValue(start) &
              s.saleDate.isSmallerOrEqualValue(end) &
              s.totalAmount.isSmallerThanValue(0),
        ))
        .get();
  }

  /// Todas las ventas del rango (incluye devoluciones con total negativo)
  Future<List<Sale>> getSalesInRangeIncludingReturns(
    DateTime start,
    DateTime end,
  ) async {
    return (select(sales)
          ..where(
            (s) =>
                s.saleDate.isBiggerOrEqualValue(start) &
                s.saleDate.isSmallerOrEqualValue(end) &
                s.status.equals('closed'),
          )
          ..orderBy([(s) => OrderingTerm.desc(s.saleDate)]))
        .get();
  }

  /// Ventas del día actual
  /// Ventas de hoy (incluye devoluciones con total negativo)
  Future<double> getTodaySales() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final sales = await getSalesInRangeIncludingReturns(startOfDay, endOfDay);
    double total = 0;
    for (final s in sales) {
      total += s.totalAmount;
    }
    return total;
  }

  /// Ventas del día anterior (incluye devoluciones)
  Future<double> getYesterdaySales() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final startOfYesterday = DateTime(
      yesterday.year,
      yesterday.month,
      yesterday.day,
    );
    final endOfYesterday = startOfYesterday.add(const Duration(days: 1));

    final sales = await getSalesInRangeIncludingReturns(startOfYesterday, endOfYesterday);
    double total = 0;
    for (final s in sales) {
      total += s.totalAmount;
    }
    return total;
  }

  /// Número de transacciones del día
  Future<int> getTodayTransactionCount() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final sales = await _getSalesInRange(startOfDay, endOfDay);
    return sales.length;
  }

  /// Promedio de transacciones diarias del mes actual
  Future<double> getMonthlyAverageTransactions() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);

    final sales = await _getSalesInRange(monthStart, monthEnd);
    if (sales.isEmpty) return 0;

    return sales.length / now.day;
  }

  /// Promedio de ventas diarias del mes actual (incluye devoluciones)
  Future<double> getMonthlyAverageSales() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);

    final sales = await getSalesInRangeIncludingReturns(monthStart, monthEnd);
    if (sales.isEmpty) return 0;

    double total = 0;
    for (final s in sales) {
      total += s.totalAmount;
    }
    return total / now.day;
  }

  /// Ganancia del día (ventas - costo, incluyendo devoluciones) — usa SaleItems para calcular
  Future<double> getTodayProfit() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return _calcProfitInRange(startOfDay, endOfDay);
  }

  /// Ganancia por rango de fechas
  Future<double> getProfitByDateRange(DateTime from, DateTime to) async {
    return _calcProfitInRange(from, to);
  }

  /// Método batch unificado para calcular ganancia en un rango
  /// ANTES: 1 query sales + N queries items + M queries cost = 1+2N queries
  /// AHORA: 1 query sales + 1 query items + 1 query lots = 3 queries
  Future<double> _calcProfitInRange(DateTime from, DateTime to) async {
    final sales = await _getSalesInRange(from, to);
    final returns = await _getReturnsInRange(from, to);

    final allSaleIds = [...sales.map((s) => s.id), ...returns.map((r) => r.id)];
    if (allSaleIds.isEmpty) return 0;

    // 1 query batch para TODOS los items
    final allItems = await (select(
      saleItems,
    )..where((si) => si.saleId.isIn(allSaleIds))).get();

    // Recopilar productIds que necesitan costo promedio
    final productIdsNeedCost = <String>{};
    for (final item in allItems) {
      if (item.costPriceAtSale == 0) {
        productIdsNeedCost.add(item.productId);
      }
    }

    // 1 query batch para TODOS los lotes de productos que necesitan costo
    final costCache = <String, double>{};
    if (productIdsNeedCost.isNotEmpty) {
      final allLots = await (select(
        inventoryLots,
      )..where((l) => l.productId.isIn(productIdsNeedCost.toList()))).get();

      // Agrupar por productId y calcular costo promedio
      final Map<String, List<InventoryLot>> lotsByProduct = {};
      for (final lot in allLots) {
        lotsByProduct.putIfAbsent(lot.productId, () => []);
        lotsByProduct[lot.productId]!.add(lot);
      }
      for (final entry in lotsByProduct.entries) {
        double totalCost = 0;
        double totalQty = 0;
        for (final lot in entry.value) {
          totalCost += lot.remainingQuantity * lot.costPerUnit;
          totalQty += lot.remainingQuantity;
        }
        costCache[entry.key] = totalQty > 0 ? totalCost / totalQty : 0;
      }
    }

    double totalProfit = 0;
    for (final item in allItems) {
      final cost = item.costPriceAtSale != 0
          ? item.costPriceAtSale
          : (costCache[item.productId] ?? 0);
      totalProfit += (item.unitPrice - cost) * item.quantity;
    }

    return totalProfit;
  }

  /// Ticket promedio del día (incluye devoluciones)
  Future<double> getTodayAverageTicket() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final sales = await getSalesInRangeIncludingReturns(startOfDay, endOfDay);
    if (sales.isEmpty) return 0;

    double total = 0;
    for (final s in sales) {
      total += s.totalAmount;
    }
    return total / sales.length;
  }

  /// Ventas por día del mes actual (para gráfico de barras, incluye devoluciones)
  Future<Map<int, double>> getDailySalesThisMonth() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);

    final sales = await getSalesInRangeIncludingReturns(monthStart, monthEnd);

    final Map<int, double> dailySales = {};
    for (int i = 1; i <= now.day; i++) {
      dailySales[i] = 0;
    }

    for (final sale in sales) {
      final day = sale.saleDate.day;
      dailySales[day] = (dailySales[day] ?? 0) + sale.totalAmount;
    }

    return dailySales;
  }

  /// Métodos de pago del día — basado en tabla Sales
  Future<Map<String, double>> getTodayPaymentMethods() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final sales = await getSalesInRangeIncludingReturns(startOfDay, endOfDay);

    double efectivo = 0;
    double transferencia = 0;

    for (final sale in sales) {
      switch (sale.paymentMethod.toLowerCase()) {
        case 'efectivo':
          efectivo += sale.totalAmount;
          break;
        case 'transferencia':
          transferencia += sale.totalAmount;
          break;
        case 'mixto':
          final matchOrders =
              await (select(orders)..where(
                    (o) =>
                        o.sellerId.equals(sale.sellerId) &
                        o.status.equals('paid'),
                  ))
                  .get();
          final matchOrder = matchOrders
              .where(
                (o) =>
                    o.paidAt != null &&
                    o.paidAt!.year == sale.saleDate.year &&
                    o.paidAt!.month == sale.saleDate.month &&
                    o.paidAt!.day == sale.saleDate.day &&
                    (o.totalAmount - sale.totalAmount).abs() < 0.01,
              )
              .firstOrNull;
          if (matchOrder != null) {
            final payments = await getOrderPayments(matchOrder.id);
            for (final p in payments) {
              switch (p.paymentMethod.toLowerCase()) {
                case 'efectivo':
                  efectivo += p.amount - p.changeGiven;
                  break;
                case 'transferencia':
                  transferencia += p.amount;
                  break;
              }
            }
          } else {
            efectivo += sale.totalAmount;
          }
          break;
      }
    }

    return {'efectivo': efectivo, 'transferencia': transferencia};
  }

  /// Top 5 productos del día — basado en SaleItems
  Future<List<Map<String, dynamic>>> getTopProductsToday({
    int limit = 5,
  }) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return _getTopProductsInRange(startOfDay, endOfDay, limit: limit);
  }

  /// Método batch unificado para top products
  /// ANTES: 1 query sales + N queries items + K queries product = 1+N+K queries
  /// AHORA: 1 query sales + 1 query items + 1 query products = 3 queries
  Future<List<Map<String, dynamic>>> _getTopProductsInRange(
    DateTime from,
    DateTime to, {
    int limit = 5,
  }) async {
    final sales = await getSalesInRangeIncludingReturns(from, to);
    if (sales.isEmpty) return [];

    // 1 query batch para TODOS los items
    final saleIds = sales.map((s) => s.id).toList();
    final allItems = await (select(
      saleItems,
    )..where((si) => si.saleId.isIn(saleIds))).get();

    final Map<String, double> productUnits = {};
    final Map<String, double> productRevenue = {};

    for (final item in allItems) {
      productUnits[item.productId] =
          (productUnits[item.productId] ?? 0) + item.quantity;
      productRevenue[item.productId] =
          (productRevenue[item.productId] ?? 0) + item.subtotal;
    }

    final sortedIds = productUnits.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 1 query batch para TODOS los productos top
    final topIds = sortedIds.take(limit).map((e) => e.key).toList();
    if (topIds.isEmpty) return [];

    final productList = await (select(
      products,
    )..where((p) => p.id.isIn(topIds))).get();
    final productMap = {for (final p in productList) p.id: p};

    final List<Map<String, dynamic>> topProducts = [];
    for (final entry in sortedIds.take(limit)) {
      final product = productMap[entry.key];
      if (product != null) {
        topProducts.add({
          'id': entry.key,
          'name': product.name,
          'units': productUnits[entry.key],
          'revenue': productRevenue[entry.key],
        });
      }
    }

    return topProducts;
  }

  // ================================================================
  // MÉTODOS DE ALERTAS
  // ================================================================

  /// Alerta: Stock agotado (productos con 0 stock que vendió en los últimos 7 días)
  Future<List<Map<String, dynamic>>> getOutOfStockAlerts() async {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final now = DateTime.now();

    // Get paid orders from last 7 days (excluir devoluciones)
    final paidOrders = await _getPaidOrdersInRange(sevenDaysAgo, now);

    // 1 query batch: todos los items de todas las órdenes
    final orderIds = paidOrders.map((o) => o.id).toList();
    if (orderIds.isEmpty) return [];

    final allItems = await (select(
      orderItems,
    )..where((oi) => oi.orderId.isIn(orderIds))).get();

    final Set<String> soldProductIds = {};
    for (final item in allItems) {
      soldProductIds.add(item.productId);
    }

    // 1 query batch: stock de TODOS los productos de una vez
    final soldIdsList = soldProductIds.toList();
    final allLots = await (select(
      inventoryLots,
    )..where((l) => l.productId.isIn(soldIdsList))).get();

    final Map<String, double> stockMap = {};
    for (final lot in allLots) {
      stockMap[lot.productId] =
          (stockMap[lot.productId] ?? 0) + lot.remainingQuantity;
    }

    // 1 query batch: info de productos
    final allProducts = await (select(
      products,
    )..where((p) => p.id.isIn(soldIdsList))).get();
    final productMap = {for (final p in allProducts) p.id: p};

    // Check which have no stock
    final List<Map<String, dynamic>> alerts = [];
    for (final productId in soldProductIds) {
      final stock = stockMap[productId] ?? 0;
      if (stock <= 0) {
        final product = productMap[productId];
        if (product != null && product.isActive) {
          alerts.add({
            'name': product.name,
            'code': product.code,
            'stock': 0.0,
          });
        }
      }
    }

    return alerts;
  }

  /// Alerta: Stock crítico (menos de 5 unidades)
  Future<List<Map<String, dynamic>>> getCriticalStockAlerts() async {
    final allProducts = await getAllProducts();

    // 1 query batch: TODOS los lotes activos de una vez
    final productIds = allProducts.map((p) => p.id).toList();
    if (productIds.isEmpty) return [];

    final allLots = await (select(
      inventoryLots,
    )..where((l) => l.productId.isIn(productIds))).get();

    final Map<String, double> stockMap = {};
    for (final lot in allLots) {
      stockMap[lot.productId] =
          (stockMap[lot.productId] ?? 0) + lot.remainingQuantity;
    }

    final List<Map<String, dynamic>> alerts = [];

    for (final product in allProducts) {
      if (product.isActive) {
        final stock = stockMap[product.id] ?? 0;
        if (stock > 0 && stock < 5) {
          alerts.add({'name': product.name, 'stock': stock});
        }
      }
    }

    alerts.sort(
      (a, b) => (a['stock'] as double).compareTo(b['stock'] as double),
    );
    return alerts;
  }

  /// Alerta: Diferencia de caja en sesiones cerradas
  Future<List<Map<String, dynamic>>> getCashDifferenceAlerts() async {
    final closedSessions =
        await (select(sessions)
              ..where((s) => s.status.equals('closed'))
              ..orderBy([(s) => OrderingTerm.desc(s.closingTime)])
              ..limit(10))
            .get();

    final List<Map<String, dynamic>> alerts = [];
    const double threshold = 50;

    for (final session in closedSessions) {
      if (session.closingCash != null) {
        final expected = session.openingCash + session.totalCash;
        final difference = (session.closingCash! - expected).abs();
        if (difference > threshold) {
          alerts.add({
            'sessionId': session.id,
            'closingTime': session.closingTime,
            'difference': difference,
          });
        }
      }
    }

    return alerts;
  }

  /// Alerta: Ventas bajas (menos del 40% del promedio)
  Future<Map<String, dynamic>?> getLowSalesAlert() async {
    final todaySales = await getTodaySales();
    final monthlyAverage = await getMonthlyAverageSales();

    if (monthlyAverage > 0 && todaySales < monthlyAverage * 0.4) {
      return {
        'todaySales': todaySales,
        'averageSales': monthlyAverage,
        'percentage': (todaySales / monthlyAverage) * 100,
      };
    }
    return null;
  }

  /// Alerta positiva: Ventas altas (más del 130% del promedio)
  Future<Map<String, dynamic>?> getHighSalesAlert() async {
    final todaySales = await getTodaySales();
    final monthlyAverage = await getMonthlyAverageSales();

    if (monthlyAverage > 0 && todaySales > monthlyAverage * 1.3) {
      return {
        'todaySales': todaySales,
        'averageSales': monthlyAverage,
        'percentage': (todaySales / monthlyAverage) * 100,
      };
    }
    return null;
  }

  // ================================================================
  // MÉTODOS DE DESPACHOS RECIBIDOS (VENDEDORA)
  // ================================================================

  Future<void> addDespachoRecibido({
    required String id,
    required String vendedoraId,
    required String vendedoraNombre,
    required DateTime fechaDespacho,
    required int productosCount,
    required String rawJson,
    String status = 'aplicado',
    String tipo = 'despacho',
  }) async {
    await into(despachosRecibidos).insert(
      DespachosRecibidosCompanion.insert(
        id: id,
        vendedoraId: vendedoraId,
        vendedoraNombre: vendedoraNombre,
        fechaDespacho: fechaDespacho,
        productosCount: Value(productosCount),
        rawJson: rawJson,
        status: Value(status),
        tipo: Value(tipo),
      ),
    );
  }

  Future<List<DespachosRecibido>> getAllDespachosRecibidos() async {
    return (select(
      despachosRecibidos,
    )..orderBy([(d) => OrderingTerm.desc(d.fechaRecibido)])).get();
  }

  Future<DespachosRecibido?> getDespachoRecibidoById(String id) async {
    return (select(
      despachosRecibidos,
    )..where((d) => d.id.equals(id))).getSingleOrNull();
  }

  // ================================================================
  // MÉTODOS DE DESPACHOS ENVIADOS (ADMIN)
  // ================================================================

  Future<void> addDespachoEnviado({
    required String id,
    required String vendedoraId,
    required String vendedoraNombre,
    required int productosCount,
    required String rawJson,
    String tipo = 'despacho',
  }) async {
    await into(despachosEnviados).insert(
      DespachosEnviadosCompanion.insert(
        id: id,
        vendedoraId: vendedoraId,
        vendedoraNombre: vendedoraNombre,
        productosCount: Value(productosCount),
        rawJson: rawJson,
        tipo: Value(tipo),
      ),
    );
  }

  Future<void> updateDespachoEnviado({
    required String id,
    required int productosCount,
    required String rawJson,
  }) async {
    await (update(despachosEnviados)..where((d) => d.id.equals(id))).write(
      DespachosEnviadosCompanion(
        productosCount: Value(productosCount),
        rawJson: Value(rawJson),
      ),
    );
  }

  Future<List<DespachosEnviado>> getAllDespachosEnviados() async {
    return (select(
      despachosEnviados,
    )..orderBy([(d) => OrderingTerm.desc(d.fechaEnvio)])).get();
  }

  // ================================================================
  // MÉTODOS DE RENDICIONES PROCESADAS (ADMIN)
  // ================================================================

  Future<void> addRendicionProcesada({
    required String id,
    required String vendedoraId,
    required String vendedoraNombre,
    required DateTime fechaRendicion,
    required double totalEfectivo,
    required double totalTransferencia,
    required double totalGeneral,
    required int totalItems,
    required String rawJson,
    String? sessionId,
  }) async {
    await into(rendicionesProcesadas).insert(
      RendicionesProcesadasCompanion.insert(
        id: id,
        vendedoraId: vendedoraId,
        vendedoraNombre: vendedoraNombre,
        fechaRendicion: fechaRendicion,
        totalEfectivo: Value(totalEfectivo),
        totalTransferencia: Value(totalTransferencia),
        totalGeneral: Value(totalGeneral),
        totalItems: Value(totalItems),
        rawJson: rawJson,
        sessionId: Value(sessionId),
      ),
    );
  }

  Future<List<RendicionesProcesada>> getAllRendicionesProcesadas() async {
    return (select(
      rendicionesProcesadas,
    )..orderBy([(r) => OrderingTerm.desc(r.fechaProcesado)])).get();
  }

  Future<RendicionesProcesada?> getRendicionProcesadaById(String id) async {
    return (select(
      rendicionesProcesadas,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
  }

  // ================================================================
  // MÉTODOS DE PAGINACIÓN — SESIONES
  // ================================================================

  Future<List<Session>> getSessionsPaginated({
    int limit = 20,
    int offset = 0,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final query = select(sessions)
      ..orderBy([(s) => OrderingTerm.desc(s.openingTime)])
      ..limit(limit, offset: offset);

    if (fromDate != null || toDate != null) {
      query.where((s) {
        final conditions = <Expression<bool>>[];
        if (fromDate != null)
          conditions.add(s.openingTime.isBiggerOrEqualValue(fromDate));
        if (toDate != null) {
          final endOfDay = toDate.add(
            const Duration(hours: 23, minutes: 59, seconds: 59),
          );
          conditions.add(s.openingTime.isSmallerOrEqualValue(endOfDay));
        }
        return conditions.length == 1
            ? conditions.first
            : conditions.reduce((a, b) => a & b);
      });
    }

    return query.get();
  }

  Future<int> countSessions({DateTime? fromDate, DateTime? toDate}) async {
    var sql = 'SELECT COUNT(*) as count FROM sessions';
    final args = <Variable>[];
    final conditions = <String>[];

    if (fromDate != null) {
      conditions.add('opening_time >= ?');
      args.add(Variable.withDateTime(fromDate));
    }
    if (toDate != null) {
      final endOfDay = toDate.add(
        const Duration(hours: 23, minutes: 59, seconds: 59),
      );
      conditions.add('opening_time <= ?');
      args.add(Variable.withDateTime(endOfDay));
    }

    if (conditions.isNotEmpty) {
      sql += ' WHERE ${conditions.join(' AND ')}';
    }

    final result = await customSelect(sql, variables: args).getSingle();
    return result.read<int>('count');
  }

  // ================================================================
  // MÉTODOS DE PAGINACIÓN — VENTAS
  // ================================================================

  Future<List<Sale>> getSalesPaginated({
    int limit = 20,
    int offset = 0,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final query = select(sales)
      ..where(
        (s) =>
            s.totalAmount.isBiggerOrEqualValue(0) & s.status.equals('closed'),
      )
      ..orderBy([(s) => OrderingTerm.desc(s.saleDate)])
      ..limit(limit, offset: offset);

    if (fromDate != null || toDate != null) {
      query.where((s) {
        final conditions = <Expression<bool>>[
          s.totalAmount.isBiggerOrEqualValue(0),
          s.status.equals('closed'),
        ];
        if (fromDate != null)
          conditions.add(s.saleDate.isBiggerOrEqualValue(fromDate));
        if (toDate != null) {
          final endOfDay = toDate.add(
            const Duration(hours: 23, minutes: 59, seconds: 59),
          );
          conditions.add(s.saleDate.isSmallerOrEqualValue(endOfDay));
        }
        return conditions.length == 2
            ? conditions[0] & conditions[1]
            : conditions.reduce((a, b) => a & b);
      });
    }

    return query.get();
  }

  Future<int> countSales({DateTime? fromDate, DateTime? toDate}) async {
    var sql =
        "SELECT COUNT(*) as count FROM sales WHERE total_amount >= 0 AND status = 'closed'";
    final args = <Variable>[];
    final conditions = <String>[];

    if (fromDate != null) {
      conditions.add('sale_date >= ?');
      args.add(Variable.withDateTime(fromDate));
    }
    if (toDate != null) {
      final endOfDay = toDate.add(
        const Duration(hours: 23, minutes: 59, seconds: 59),
      );
      conditions.add('sale_date <= ?');
      args.add(Variable.withDateTime(endOfDay));
    }

    if (conditions.isNotEmpty) {
      sql += ' AND ${conditions.join(' AND ')}';
    }

    final result = await customSelect(sql, variables: args).getSingle();
    return result.read<int>('count');
  }

  // ================================================================
  // MÉTODOS DE PAGINACIÓN — DESPACHOS ENVIADOS
  // ================================================================

  Future<List<DespachosEnviado>> getDespachosPaginated({
    int limit = 20,
    int offset = 0,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final query = select(despachosEnviados)
      ..orderBy([(d) => OrderingTerm.desc(d.fechaEnvio)])
      ..limit(limit, offset: offset);

    if (fromDate != null || toDate != null) {
      query.where((d) {
        final conditions = <Expression<bool>>[];
        if (fromDate != null)
          conditions.add(d.fechaEnvio.isBiggerOrEqualValue(fromDate));
        if (toDate != null) {
          final endOfDay = toDate.add(
            const Duration(hours: 23, minutes: 59, seconds: 59),
          );
          conditions.add(d.fechaEnvio.isSmallerOrEqualValue(endOfDay));
        }
        return conditions.length == 1
            ? conditions.first
            : conditions.reduce((a, b) => a & b);
      });
    }

    return query.get();
  }

  Future<int> countDespachos({DateTime? fromDate, DateTime? toDate}) async {
    var sql = 'SELECT COUNT(*) as count FROM despachos_enviados';
    final args = <Variable>[];
    final conditions = <String>[];

    if (fromDate != null) {
      conditions.add('fecha_envio >= ?');
      args.add(Variable.withDateTime(fromDate));
    }
    if (toDate != null) {
      final endOfDay = toDate.add(
        const Duration(hours: 23, minutes: 59, seconds: 59),
      );
      conditions.add('fecha_envio <= ?');
      args.add(Variable.withDateTime(endOfDay));
    }

    if (conditions.isNotEmpty) {
      sql += ' WHERE ${conditions.join(' AND ')}';
    }

    final result = await customSelect(sql, variables: args).getSingle();
    return result.read<int>('count');
  }

  // ================================================================
  // MÉTODOS DE PAGINACIÓN — RENDICIONES PROCESADAS
  // ================================================================

  Future<List<RendicionesProcesada>> getRendicionesPaginated({
    int limit = 20,
    int offset = 0,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final query = select(rendicionesProcesadas)
      ..orderBy([(r) => OrderingTerm.desc(r.fechaProcesado)])
      ..limit(limit, offset: offset);

    if (fromDate != null || toDate != null) {
      query.where((r) {
        final conditions = <Expression<bool>>[];
        if (fromDate != null)
          conditions.add(r.fechaProcesado.isBiggerOrEqualValue(fromDate));
        if (toDate != null) {
          final endOfDay = toDate.add(
            const Duration(hours: 23, minutes: 59, seconds: 59),
          );
          conditions.add(r.fechaProcesado.isSmallerOrEqualValue(endOfDay));
        }
        return conditions.length == 1
            ? conditions.first
            : conditions.reduce((a, b) => a & b);
      });
    }

    return query.get();
  }

  Future<int> countRendiciones({DateTime? fromDate, DateTime? toDate}) async {
    var sql = 'SELECT COUNT(*) as count FROM rendiciones_procesadas';
    final args = <Variable>[];
    final conditions = <String>[];

    if (fromDate != null) {
      conditions.add('fecha_procesado >= ?');
      args.add(Variable.withDateTime(fromDate));
    }
    if (toDate != null) {
      final endOfDay = toDate.add(
        const Duration(hours: 23, minutes: 59, seconds: 59),
      );
      conditions.add('fecha_procesado <= ?');
      args.add(Variable.withDateTime(endOfDay));
    }

    if (conditions.isNotEmpty) {
      sql += ' WHERE ${conditions.join(' AND ')}';
    }

    final result = await customSelect(sql, variables: args).getSingle();
    return result.read<int>('count');
  }

  // ================================================================
  // DESHACER RENDICIÓN (eliminar sesión + datos asociados)
  // ================================================================

  /// Elimina una rendición procesada y toda la sesión/ventas/órdenes
  /// creadas por applyRendicion. Usa el sessionId de la rendición.
  Future<void> undoRendicion(String rendicionId) async {
    final rendicion = await getRendicionProcesadaById(rendicionId);
    if (rendicion == null) return;

    final sessionId = rendicion.sessionId;

    await transaction(() async {
      if (sessionId != null) {
        // 1. Borrar órdenes, pagos e items de la sesión
        final sessionOrders = await (select(
          orders,
        )..where((o) => o.sessionId.equals(sessionId))).get();

        for (final order in sessionOrders) {
          await (delete(
            orderPayments,
          )..where((p) => p.orderId.equals(order.id))).go();
          await (delete(
            orderItems,
          )..where((i) => i.orderId.equals(order.id))).go();
        }
        await (delete(
          orders,
        )..where((o) => o.sessionId.equals(sessionId))).go();

        // 2. Borrar SOLO las ventas de ESTA sesión (no todas las SR%)
        final salesToDelete =
            await (select(sales)..where(
                  (s) => s.id.like('SR%') & s.sessionId.equals(sessionId),
                ))
                .get();

        for (final sale in salesToDelete) {
          await (delete(
            saleItems,
          )..where((si) => si.saleId.equals(sale.id))).go();
        }
        await (delete(
          sales,
        )..where((s) => s.id.like('SR%') & s.sessionId.equals(sessionId))).go();

        // 3. Restaurar inventario desde el rawJson de la rendición
        try {
          final raw = jsonDecode(rendicion.rawJson) as Map<String, dynamic>;
          final ventas = raw['ventas'] as List<dynamic>? ?? [];
          for (final v in ventas) {
            final item = v as Map<String, dynamic>;
            final productoId = item['productoId'] as String;
            final cantidad = (item['cantidad'] as num).toDouble();
            final totalItem = (item['total'] as num).toDouble();
            final costPrice = (item['costoUnitario'] as num?)?.toDouble() ?? 0;

            if (totalItem < 0) {
              // Era devolución → applyRendicion agregó stock, ahora lo quitamos
              try {
                await removeInventoryStock(
                  productId: productoId,
                  quantity: cantidad,
                  location: 'pv',
                  reference: 'UNDO_RENDICION',
                );
              } catch (_) {}
            } else {
              // Era venta normal → applyRendicion quitó stock, ahora lo devolvemos
              try {
                await addInventoryLot(
                  productId: productoId,
                  quantity: cantidad,
                  costPerUnit: costPrice.abs(),
                  purchaseDate: DateTime.now(),
                  supplier: 'UNDO_RENDICION',
                  location: 'pv',
                );
              } catch (_) {}
            }
          }
        } catch (_) {}

        // 4. Borrar la sesión de caja
        await (delete(sessions)..where((s) => s.id.equals(sessionId))).go();
      }

      // 5. Borrar la rendición procesada
      await (delete(
        rendicionesProcesadas,
      )..where((r) => r.id.equals(rendicionId))).go();
    });
  }

  /// Obtener pagos de transferencia de una sesión (para mostrar en historial de ventas)
  Future<List<OrderPayment>> getTransferPaymentsBySession(
    String sessionId,
  ) async {
    final sessionOrders = await (select(
      orders,
    )..where((o) => o.sessionId.equals(sessionId))).get();
    final result = <OrderPayment>[];
    for (final order in sessionOrders) {
      final payments =
          await (select(orderPayments)..where(
                (p) =>
                    p.orderId.equals(order.id) &
                    p.paymentMethod.equals('transferencia'),
              ))
              .get();
      result.addAll(payments);
    }
    return result;
  }

  // ================================================================
  // MÉTODOS BATCH (para historiales - evitan N+1 queries)
  // ================================================================

  /// Obtener pagos de transferencia para MÚLTIPLES sesiones en un solo query
  Future<Map<String, List<OrderPayment>>> getTransferPaymentsBySessions(
    List<String> sessionIds,
  ) async {
    if (sessionIds.isEmpty) return {};

    // 1. Obtener órdenes de todas las sesiones
    final sessionOrders = await (select(
      orders,
    )..where((o) => o.sessionId.isIn(sessionIds))).get();

    if (sessionOrders.isEmpty) return {};

    // 2. Obtener pagos de transferencia de esas órdenes en un solo query
    final orderIds = sessionOrders.map((o) => o.id).toList();
    final payments =
        await (select(orderPayments)..where(
              (p) =>
                  p.orderId.isIn(orderIds) &
                  p.paymentMethod.equals('transferencia'),
            ))
            .get();

    // 3. Mapear orderId → sessionId
    final orderIdToSession = <String, String>{};
    for (final order in sessionOrders) {
      orderIdToSession[order.id] = order.sessionId;
    }

    // 4. Agrupar por sessionId
    final result = <String, List<OrderPayment>>{};
    for (final payment in payments) {
      final sessionId = orderIdToSession[payment.orderId];
      if (sessionId != null) {
        result.putIfAbsent(sessionId, () => []);
        result[sessionId]!.add(payment);
      }
    }
    return result;
  }

  /// Obtener items de venta para MÚLTIPLES sales en un solo query
  Future<Map<String, List<SaleItem>>> getSaleItemsBySaleIds(
    List<String> saleIds,
  ) async {
    if (saleIds.isEmpty) return {};
    final items = await (select(
      saleItems,
    )..where((si) => si.saleId.isIn(saleIds))).get();

    final result = <String, List<SaleItem>>{};
    for (final item in items) {
      result.putIfAbsent(item.saleId, () => []);
      result[item.saleId]!.add(item);
    }
    return result;
  }

  /// Obtener pagos de transferencia para sesiones de ventas en un solo query
  Future<Map<String, List<OrderPayment>>> getTransferPaymentsForSales(
    List<String> sessionIds,
  ) async {
    if (sessionIds.isEmpty) return {};

    final sessionOrders = await (select(
      orders,
    )..where((o) => o.sessionId.isIn(sessionIds))).get();

    if (sessionOrders.isEmpty) return {};

    final orderIds = sessionOrders.map((o) => o.id).toList();
    final payments =
        await (select(orderPayments)..where(
              (p) =>
                  p.orderId.isIn(orderIds) &
                  p.paymentMethod.isIn(['transferencia', 'mixto']),
            ))
            .get();

    final orderIdToSession = <String, String>{};
    for (final order in sessionOrders) {
      orderIdToSession[order.id] = order.sessionId;
    }

    final result = <String, List<OrderPayment>>{};
    for (final payment in payments) {
      final sessionId = orderIdToSession[payment.orderId];
      if (sessionId != null) {
        result.putIfAbsent(sessionId, () => []);
        result[sessionId]!.add(payment);
      }
    }
    return result;
  }

  // ================================================================
  // MÉTODOS DE REGLAS DE PRECIO POR MAYOR (JSON via AppSettings)
  // ================================================================

  static const _wholesaleKey = 'wholesale_rules';

  Future<Map<String, dynamic>> _loadWholesaleJson() async {
    final row = await (select(
      appSettings,
    )..where((s) => s.key.equals(_wholesaleKey))).getSingleOrNull();
    if (row != null) {
      try {
        return jsonDecode(row.value) as Map<String, dynamic>;
      } catch (_) {}
    }
    return {};
  }

  Future<void> _saveWholesaleJson(Map<String, dynamic> data) async {
    // FIX: solo borrar la key de wholesale_rules, NO todo el AppSettings
    await (delete(appSettings)..where((s) => s.key.equals(_wholesaleKey))).go();
    await into(appSettings).insert(
      AppSettingsCompanion.insert(key: _wholesaleKey, value: jsonEncode(data)),
    );
  }

  /// Obtener reglas de precio por mayor de un producto
  Future<List<Map<String, dynamic>>> getWholesaleRules(String productId) async {
    final data = await _loadWholesaleJson();
    final rules = (data[productId] as List<dynamic>?) ?? [];
    return rules.cast<Map<String, dynamic>>().toList()..sort(
      (a, b) => (a['minQuantity'] as num).compareTo(b['minQuantity'] as num),
    );
  }

  /// Guardar todas las reglas de un producto
  Future<void> saveWholesaleRulesForProduct(
    String productId,
    List<Map<String, dynamic>> rules,
  ) async {
    final data = await _loadWholesaleJson();
    data[productId] = rules;
    await _saveWholesaleJson(data);
  }

  /// Eliminar todas las reglas de un producto
  Future<void> deleteWholesaleRulesByProduct(String productId) async {
    final data = await _loadWholesaleJson();
    data.remove(productId);
    await _saveWholesaleJson(data);
  }

  /// Obtener TODAS las reglas de precio por mayor (para sync/despacho)
  Future<Map<String, dynamic>> getAllWholesaleRules() async {
    return _loadWholesaleJson();
  }

  /// Reemplazar TODAS las reglas de precio por mayor (para sync/despacho)
  Future<void> setAllWholesaleRules(Map<String, dynamic> data) async {
    await _saveWholesaleJson(data);
  }

  /// Obtener precio mayorista aplicable para una cantidad dada
  Future<double> getWholesalePrice(String productId, double quantity) async {
    final rules = await getWholesaleRules(productId);
    for (final rule in rules.reversed) {
      final minQty = (rule['minQuantity'] as num).toDouble();
      if (quantity >= minQty) {
        return (rule['unitPrice'] as num).toDouble();
      }
    }
    return 0;
  }

  /// --- APERTURA DE CONEXIÓN ---

  /// --- APERTURA DE CONEXIÓN ---
  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'posjvl.db'));
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
      return NativeDatabase.createInBackground(file);
    });
  }
}
