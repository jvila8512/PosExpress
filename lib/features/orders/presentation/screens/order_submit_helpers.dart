/// Pure helpers for the "Enviar a cocina" submit flow.
///
/// Kept free of Flutter/Provider dependencies so they are trivially
/// unit-testable; [OrderFormScreen] wires them to the UI.
library;

/// Returns the kitchen phone to send the PED SMS to, or null when no
/// active Cocina contact is configured (order is still saved, SMS pending).
String? resolveKitchenPhone(List<String> phones) {
  if (phones.isEmpty) return null;
  return phones.first;
}

/// Returns the message explaining why "Enviar a cocina" cannot run yet,
/// or null when the button is actionable.
///
/// Client selection is checked first: it is the topmost form section.
String? submitBlockerMessage({
  required bool hasClient,
  required bool hasItems,
}) {
  if (!hasClient) return 'Elegí un cliente';
  if (!hasItems) return 'Agregá productos';
  return null;
}
