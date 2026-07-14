import 'order_state.dart';

/// An item within a restaurant order.
class OrderItem {
  final String code;
  final int qty;
  final double price;

  const OrderItem({
    required this.code,
    required this.qty,
    required this.price,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      code: json['code']?.toString() ?? '',
      qty: (json['qty'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'qty': qty,
    'price': price,
  };

  double get subtotal => qty * price;
}

/// Represents a restaurant order in the SMS ordering system.
///
/// Supports two flows:
/// - **DOMICILIO**: registrado → enCocina → hecho → enCamino → entregado
/// - **MESA**: enCocina → hecho → entregadoEnMesa → pagado → cerrado
class RestaurantOrder {
  final String id;
  final String tipoPedido; // DOMICILIO | MESA
  final String clienteId;
  final String? mesaId;
  final OrderState estado;
  final String? canalOrigen;
  final String? horaSolicitada;
  final String? metodoPago;
  final double montoTotal;
  final String creadoPorUsuarioId;
  final DateTime? fechaCreacion;
  final List<OrderItem> items;
  final String? motivoCancelacion;

  const RestaurantOrder({
    required this.id,
    required this.tipoPedido,
    required this.clienteId,
    this.mesaId,
    this.estado = OrderState.registrado,
    this.canalOrigen,
    this.horaSolicitada,
    this.metodoPago,
    this.montoTotal = 0.0,
    required this.creadoPorUsuarioId,
    this.fechaCreacion,
    this.items = const [],
    this.motivoCancelacion,
  });

  /// Create from a JSON map (deserialized from API or storage).
  factory RestaurantOrder.fromJson(Map<String, dynamic> json) {
    return RestaurantOrder(
      id: json['id']?.toString() ?? '',
      tipoPedido: json['tipo_pedido']?.toString() ?? '',
      clienteId: json['cliente_id']?.toString() ?? '',
      mesaId: json['mesa_id']?.toString(),
      estado: _parseState(json['estado']?.toString()),
      canalOrigen: json['canal_origen']?.toString(),
      horaSolicitada: json['hora_solicitada']?.toString(),
      metodoPago: json['metodo_pago']?.toString(),
      montoTotal: (json['monto_total'] as num?)?.toDouble() ?? 0.0,
      creadoPorUsuarioId: json['creado_por_usuario_id']?.toString() ?? '',
      fechaCreacion: json['fecha_creacion'] != null
          ? DateTime.tryParse(json['fecha_creacion'].toString())
          : null,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      motivoCancelacion: json['motivo_cancelacion']?.toString(),
    );
  }

  /// Serialize to a JSON map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'tipo_pedido': tipoPedido,
    'cliente_id': clienteId,
    if (mesaId != null) 'mesa_id': mesaId,
    'estado': estado.name,
    if (canalOrigen != null) 'canal_origen': canalOrigen,
    if (horaSolicitada != null) 'hora_solicitada': horaSolicitada,
    if (metodoPago != null) 'metodo_pago': metodoPago,
    'monto_total': montoTotal,
    'creado_por_usuario_id': creadoPorUsuarioId,
    if (fechaCreacion != null) 'fecha_creacion': fechaCreacion!.toIso8601String(),
    'items': items.map((e) => e.toJson()).toList(),
    if (motivoCancelacion != null) 'motivo_cancelacion': motivoCancelacion,
  };

  /// Create a copy with updated fields.
  RestaurantOrder copyWith({
    String? id,
    String? tipoPedido,
    String? clienteId,
    String? mesaId,
    OrderState? estado,
    String? canalOrigen,
    String? horaSolicitada,
    String? metodoPago,
    double? montoTotal,
    String? creadoPorUsuarioId,
    DateTime? fechaCreacion,
    List<OrderItem>? items,
    String? motivoCancelacion,
  }) {
    return RestaurantOrder(
      id: id ?? this.id,
      tipoPedido: tipoPedido ?? this.tipoPedido,
      clienteId: clienteId ?? this.clienteId,
      mesaId: mesaId ?? this.mesaId,
      estado: estado ?? this.estado,
      canalOrigen: canalOrigen ?? this.canalOrigen,
      horaSolicitada: horaSolicitada ?? this.horaSolicitada,
      metodoPago: metodoPago ?? this.metodoPago,
      montoTotal: montoTotal ?? this.montoTotal,
      creadoPorUsuarioId: creadoPorUsuarioId ?? this.creadoPorUsuarioId,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      items: items ?? this.items,
      motivoCancelacion: motivoCancelacion ?? this.motivoCancelacion,
    );
  }

  static OrderState _parseState(String? state) {
    if (state == null) return OrderState.registrado;
    return OrderState.values.firstWhere(
      (s) => s.name == state,
      orElse: () => OrderState.registrado,
    );
  }
}
