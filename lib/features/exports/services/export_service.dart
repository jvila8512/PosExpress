import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/features/orders/infrastructure/datasources/order_datasource.dart';
import 'package:etecsa/features/clients/infrastructure/datasources/client_datasource.dart';

/// Strips common Spanish accents and special chars from text for ASCII safety.
String _stripAccents(String text) {
  const withAccents = 'àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞ';
  const withoutAccents = 'aaaaaaaceeeeiiiidnoooooouuuuybAAAAAAACEEEEIIIIDNOOOOOOUUUUYB';
  return text.split('').map((char) {
    final index = withAccents.indexOf(char);
    return index >= 0 ? withoutAccents[index] : char;
  }).join();
}

/// Root-level JSON keys used in the export (full names, not SMS short keys).
const _exportVersion = '1.0';

/// Service for exporting orders and clients to a shareable JSON file.
///
/// This serves as a fallback sync mechanism when SMS costs are too high.
/// The JSON uses full key names (not short SMS keys) and strips accents
/// from all text fields for ASCII safety.
class ExportService {
  final OrderDatasource _orderDatasource;
  final ClientDatasource _clientDatasource;

  ExportService({
    OrderDatasource? orderDatasource,
    ClientDatasource? clientDatasource,
  })  : _orderDatasource =
            orderDatasource ?? OrderDatasource(AppDatabase.instance),
        _clientDatasource =
            clientDatasource ?? ClientDatasource(AppDatabase.instance);

  /// Export today's orders and all clients as a JSON string.
  ///
  /// The JSON uses FULL key names (not short SMS keys) and strips accents
  /// and special chars from all text fields for ASCII safety.
  Future<String> exportTodayAsJson() async {
    final orders = await _orderDatasource.getTodayOrders();
    final clients = await _clientDatasource.getAllClients();

    final deviceName = await _getDeviceName();

    final exportMap = <String, dynamic>{
      'version': _exportVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'device': deviceName,
      'role': _getCurrentRole(),
      'orders': orders.map(_orderToJson).toList(),
      'clients': clients.map(_clientToJson).toList(),
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(exportMap);
  }

  /// Save [jsonContent] to a temp file and share it via the system share sheet.
  Future<void> shareExportFile(String jsonContent) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${tempDir.path}/hamburguesa_export_$timestamp.json');
    await file.writeAsString(jsonContent, flush: true);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Exportacion Hamburguesa Express',
    );
  }

  // ── Private helpers ─────────────────────────────────────────

  Map<String, dynamic> _orderToJson(order) {
    final orderMap = <String, dynamic>{
      'id': order.id,
      'tipoPedido': _stripAccents(order.tipoPedido),
      'clienteId': order.clienteId,
      'estado': order.estado.name,
      'canalOrigen': order.canalOrigen != null
          ? _stripAccents(order.canalOrigen!)
          : null,
      'horaSolicitada': order.horaSolicitada,
      'metodoPago': order.metodoPago,
      'montoTotal': order.montoTotal,
      'creadoPorUsuarioId': order.creadoPorUsuarioId,
      'fechaCreacion': order.fechaCreacion?.toIso8601String(),
      'motivoCancelacion': order.motivoCancelacion != null
          ? _stripAccents(order.motivoCancelacion!)
          : null,
      'items': order.items.map((item) => {
        'code': item.code,
        'qty': item.qty,
        'price': item.price,
        'subtotal': item.subtotal,
      }).toList(),
    };
    // Remove null values for cleaner JSON
    orderMap.removeWhere((_, v) => v == null);
    return orderMap;
  }

  Map<String, dynamic> _clientToJson(client) {
    final clientMap = <String, dynamic>{
      'id': client.id,
      'nombre': _stripAccents(client.nombre),
      'telefono': client.telefono,
      if (client.direccion != null) 'direccion': _stripAccents(client.direccion!),
      if (client.referencia != null) 'referencia': _stripAccents(client.referencia!),
      if (client.notas != null) 'notas': _stripAccents(client.notas!),
    };
    return clientMap;
  }

  Future<String> _getDeviceName() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.brand} ${androidInfo.model}';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return '${iosInfo.model} (iOS ${iosInfo.systemVersion})';
      }
    } catch (_) {
      // Fall through to default
    }
    return 'unknown-device';
  }

  String _getCurrentRole() {
    try {
      // We can't access secure storage from a pure service; default to unknown
      // The UI can override this when constructing the service if needed.
      return 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }
}
