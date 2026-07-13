/// Estados del ciclo de vida de un pedido.
///
/// Dos flujos:
/// - **Domicilio**: registrado → enCocina → hecho → enCamino → entregado
/// - **Mesa**:      enCocina → hecho → entregadoEnMesa → pagado → cerrado
///
/// Cualquier estado (excepto terminales) puede transicionar a cancelado.
enum OrderState {
  registrado, // Redes crea pedido a domicilio
  enCocina, // Cocina recibe PED o Mesero mesa
  hecho, // Cocina termina
  enCamino, // Domicilio sale a repartir
  entregado, // Domicilio entrega (terminal)
  entregadoEnMesa, // Mesero entrega en mesa
  pagado, // Mesa pagada
  cerrado, // Mesa cerrado (terminal)
  cancelado; // Terminal

  static const validTransitions = {
    registrado: {enCocina, cancelado},
    enCocina: {hecho, cancelado},
    hecho: {enCamino, entregadoEnMesa, cancelado},
    enCamino: {entregado, cancelado},
    entregado: <OrderState>{},
    entregadoEnMesa: {pagado, cancelado},
    pagado: {cerrado, cancelado},
    cerrado: <OrderState>{},
    cancelado: <OrderState>{},
  };

  /// Returns `true` if this state can transition to [next].
  bool canTransitionTo(OrderState next) =>
      validTransitions[this]?.contains(next) ?? false;
}
