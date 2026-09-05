import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';

/// Estados cuyos pedidos cuentan como venta del día en el cierre.
///
/// Terminales de venta: domicilio entregado + mesa (entregada, pagada,
/// cerrada). Se excluyen registrado, enCocina, hecho, enCamino y cancelado.
const Set<OrderState> validSaleStates = {
  OrderState.entregado,
  OrderState.entregadoEnMesa,
  OrderState.pagado,
  OrderState.cerrado,
};

/// Returns `true` if orders in [state] count as sales for the daily close.
bool isValidSale(OrderState state) => validSaleStates.contains(state);

/// Agregado puro de ventas del día sobre pedidos ya filtrados por fecha.
///
/// Solo los pedidos en [validSaleStates] alimentan totales, desglose de
/// pago, diferencia y conteo de pagos sin confirmar (aquellos válidos con
/// `metodoPago == null`).
class SalesBreakdown {
  final double totalSales;
  final double cashSales;
  final double transferSales;
  final double diferencia;
  final int unconfirmedCount;
  final double unconfirmedPct;

  const SalesBreakdown({
    required this.totalSales,
    required this.cashSales,
    required this.transferSales,
    required this.diferencia,
    required this.unconfirmedCount,
    required this.unconfirmedPct,
  });
}

/// Summarizes the day's sales from [orders], counting only valid sale states.
SalesBreakdown summarizeSales(List<RestaurantOrder> orders) {
  double totalSales = 0;
  double cashSales = 0;
  double transferSales = 0;
  int unconfirmedCount = 0;

  for (final order in orders) {
    if (!validSaleStates.contains(order.estado)) continue;

    totalSales += order.montoTotal;

    final metodo = (order.metodoPago ?? '').toLowerCase();
    if (metodo == 'efectivo' || metodo == 'cash') {
      cashSales += order.montoTotal;
    } else if (metodo == 'transferencia' || metodo == 'transfer') {
      transferSales += order.montoTotal;
    }

    if (order.metodoPago == null) unconfirmedCount++;
  }

  final diferencia = totalSales - cashSales - transferSales;
  final unconfirmedPct =
      totalSales > 0 ? diferencia / totalSales * 100 : 0.0;

  return SalesBreakdown(
    totalSales: totalSales,
    cashSales: cashSales,
    transferSales: transferSales,
    diferencia: diferencia,
    unconfirmedCount: unconfirmedCount,
    unconfirmedPct: unconfirmedPct,
  );
}
