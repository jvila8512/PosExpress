import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:etecsa/core/database/app_database.dart'
    hide RestaurantOrder, RestaurantClient;
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart'
    as order_domain;
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/features/orders/infrastructure/datasources/order_datasource.dart';
import 'package:etecsa/features/clients/domain/entities/restaurant_client.dart';
import 'package:etecsa/features/clients/infrastructure/datasources/client_datasource.dart';

/// Result summary returned after a JSON import.
class ImportResult {
  final int ordersImported;
  final int ordersSkipped;
  final int clientsImported;
  final int clientsUpdated;
  final List<String> errors;

  const ImportResult({
    this.ordersImported = 0,
    this.ordersSkipped = 0,
    this.clientsImported = 0,
    this.clientsUpdated = 0,
    this.errors = const [],
  });

  int get totalOrders => ordersImported + ordersSkipped;
  int get totalClients => clientsImported + clientsUpdated;

  Map<String, dynamic> toJson() => {
    'ordersImported': ordersImported,
    'ordersSkipped': ordersSkipped,
    'clientsImported': clientsImported,
    'clientsUpdated': clientsUpdated,
    'errors': errors,
  };
}

/// Service for importing orders and clients from a JSON file.
///
/// Validates the export format, skips duplicate orders (by ID),
/// and upserts clients (by phone number).
class ImportService {
  final OrderDatasource _orderDatasource;
  final ClientDatasource _clientDatasource;
  final _uuid = const Uuid();

  ImportService({
    OrderDatasource? orderDatasource,
    ClientDatasource? clientDatasource,
  })  : _orderDatasource =
            orderDatasource ?? OrderDatasource(AppDatabase.instance),
        _clientDatasource =
            clientDatasource ?? ClientDatasource(AppDatabase.instance);

  /// Parse [jsonContent], validate structure, and import orders & clients.
  ///
  /// Returns an [ImportResult] summary with counts of imported/skipped items.
  Future<ImportResult> importFromJson(String jsonContent) async {
    final errors = <String>[];
    int ordersImported = 0;
    int ordersSkipped = 0;
    int clientsImported = 0;
    int clientsUpdated = 0;

    Map<String, dynamic> data;
    try {
      data = jsonDecode(jsonContent) as Map<String, dynamic>;
    } catch (e) {
      return ImportResult(errors: ['JSON invalido: $e']);
    }

    // ── Validate version ─────────────────────────────────────
    final version = data['version'] as String?;
    if (version == null || version.isEmpty) {
      return ImportResult(errors: [
        'Version de exportacion no encontrada. Asegurese de usar un archivo .json valido.',
      ]);
    }

    // ── Import clients ───────────────────────────────────────
    final rawClients = data['clients'] as List<dynamic>? ?? [];
    for (final raw in rawClients) {
      try {
        final clientMap = raw as Map<String, dynamic>;
        final phone = clientMap['telefono']?.toString() ?? '';
        final name = clientMap['nombre']?.toString() ?? '';
        final id = clientMap['id']?.toString() ?? _uuid.v4();

        // Check if client exists by phone
        final existing = await _findClientByPhone(phone);
        if (existing != null) {
          // Update existing client
          await _clientDatasource.updateClient(existing.copyWith(
            nombre: name,
            direccion: clientMap['direccion']?.toString(),
            referencia: clientMap['referencia']?.toString(),
            notas: clientMap['notas']?.toString(),
          ));
          clientsUpdated++;
        } else {
          // Insert new client
          await _clientDatasource.createClient(RestaurantClient(
            id: id,
            nombre: name,
            telefono: phone,
            direccion: clientMap['direccion']?.toString(),
            referencia: clientMap['referencia']?.toString(),
            notas: clientMap['notas']?.toString(),
          ));
          clientsImported++;
        }
      } catch (e) {
        errors.add('Error importando cliente: $e');
      }
    }

    // ── Import orders ────────────────────────────────────────
    final rawOrders = data['orders'] as List<dynamic>? ?? [];
    for (final raw in rawOrders) {
      try {
        final orderMap = raw as Map<String, dynamic>;
        final orderId = orderMap['id']?.toString() ?? '';

        // Check for duplicate by ID
        final existing = await _orderDatasource.getOrderById(orderId);
        if (existing != null) {
          ordersSkipped++;
          continue;
        }

        // Parse items
        final rawItems = orderMap['items'] as List<dynamic>? ?? [];
        final items = rawItems.map((i) {
          final m = i as Map<String, dynamic>;
          return order_domain.OrderItem(
            code: m['code']?.toString() ?? '',
            qty: (m['qty'] as num?)?.toInt() ?? 0,
            price: (m['price'] as num?)?.toDouble() ?? 0.0,
          );
        }).toList();

        final order = order_domain.RestaurantOrder(
          id: orderId,
          tipoPedido: orderMap['tipoPedido']?.toString() ?? 'DOMICILIO',
          clienteId: orderMap['clienteId']?.toString() ?? '',
          estado: _parseState(orderMap['estado']?.toString()),
          canalOrigen: orderMap['canalOrigen']?.toString(),
          horaSolicitada: orderMap['horaSolicitada']?.toString(),
          metodoPago: orderMap['metodoPago']?.toString(),
          montoTotal: (orderMap['montoTotal'] as num?)?.toDouble() ?? 0.0,
          creadoPorUsuarioId:
              orderMap['creadoPorUsuarioId']?.toString() ?? 'import',
          fechaCreacion: orderMap['fechaCreacion'] != null
              ? DateTime.tryParse(orderMap['fechaCreacion'].toString())
              : null,
          items: items,
          motivoCancelacion: orderMap['motivoCancelacion']?.toString(),
        );

        await _orderDatasource.createOrder(order);
        ordersImported++;
      } catch (e) {
        errors.add('Error importando pedido: $e');
      }
    }

    return ImportResult(
      ordersImported: ordersImported,
      ordersSkipped: ordersSkipped,
      clientsImported: clientsImported,
      clientsUpdated: clientsUpdated,
      errors: errors,
    );
  }

  /// Open a file picker for .json files and import the selected file.
  ///
  /// Returns an [ImportResult] if a file was selected and imported,
  /// or `null` if the user cancelled the picker.
  Future<ImportResult?> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: false,
      withReadStream: false,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    return importFromJson(content);
  }

  // ── Private helpers ────────────────────────────────────────

  Future<RestaurantClient?> _findClientByPhone(String phone) async {
    if (phone.isEmpty) return null;
    final clients = await _clientDatasource.getAllClients();
    try {
      return clients.firstWhere(
        (c) => c.telefono == phone,
      );
    } catch (_) {
      return null;
    }
  }

  OrderState _parseState(String? state) {
    if (state == null) return OrderState.registrado;
    return OrderState.values.firstWhere(
      (s) => s.name == state,
      orElse: () => OrderState.registrado,
    );
  }
}
