import 'package:flutter/material.dart';
import 'package:etecsa/config/theme/app_theme.dart';
import 'package:etecsa/features/shared/services/KeyValueStorageService.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  String _userRole = 'admin';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = await KeyValueStorageService().getValue('user_role') ?? 'admin';
    if (mounted) {
      setState(() {
        _userRole = role;
        _loading = false;
      });
    }
  }

  String get _roleLabel {
    switch (_userRole) {
      case 'vendedor':
        return 'Vendedora';
      case 'super_admin':
        return 'Super Administrador';
      case 'admin':
      default:
        return 'Administrador';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        title: const Text('Ayuda'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      drawer: SideMenu(scaffoldKey: scaffoldKey),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.colorCeleste,
                          AppTheme.colorCeleste.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.help_outline,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Manual de Ayuda',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'PosJVL',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Rol: $_roleLabel',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Role-based content
                  ..._buildRoleContent(),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  // ─── Role-based content dispatch ─────────────────────────────────────────

  List<Widget> _buildRoleContent() {
    switch (_userRole) {
      case 'vendedor':
        return _buildVendedorContent();
      case 'super_admin':
        return _buildSuperAdminContent();
      case 'admin':
      default:
        return _buildAdminContent();
    }
  }

  // ─── VENDEDORA ──────────────────────────────────────────────────────────

  List<Widget> _buildVendedorContent() {
    return [
      _buildSection(
        title: '🛒 Cómo Vender',
        icon: Icons.point_of_sale,
        children: [
          _buildCard(
            title: 'Agregar productos al carrito',
            content: '''
• Busca el producto por nombre o código en la pestaña "Productos"
• Toca el producto para agregarlo al carrito (pestaña "Carrito")
• El sistema valida el stock disponible. Si no hay suficiente, te avisa
• Si el producto ya está en el carrito, se suma una unidad más''',
            icon: Icons.search,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Cambiar cantidad',
            content: '''
• En el carrito, tocá el número de cantidad para editar directamente
• Ingresá la cantidad deseada (admite decimales, ej: 1.5)
• Si la cantidad supera el stock disponible, el sistema no permite el cambio y te avisa
• Para eliminar un producto, deslizá hacia la izquierda o tocá la X''',
            icon: Icons.edit,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Cobrar la venta',
            content: '''
• Tocá "COBRAR" para ir a la pantalla de pago
• Seleccioná el método de pago: Efectivo, Transferencia o Ambos
• En efectivo: ingresá el monto que entrega el cliente y se calcula el vuelto
• En transferencia: podés pegar el SMS de PAGOxMOVIL para cargar los datos automáticamente
• Con "Ambos": ingresá cuánto paga en efectivo y cuánto por transferencia
• Ingresá nombre y teléfono del cliente (opcional) - aparece en todos los métodos de pago
• Tocá "CONFIRMAR" para registrar la venta y generar el comprobante
• Si ingresaste el teléfono del cliente, el campo de WhatsApp en la factura se auto-llena''',
            icon: Icons.check_circle_outline,
          ),
        ],
      ),
      const SizedBox(height: 24),

      _buildSection(
        title: '🚫 Anular Ventas',
        icon: Icons.cancel_outlined,
        children: [
          _buildCard(
            title: 'Anular una venta',
            content: '''
• En el menú → "Detalle de Caja" → pestaña "Ventas"
• Cada venta tiene un botón (❌) para anularla
• Escribí el motivo de la anulación (obligatorio)
• El stock se restaura automáticamente
• Si es una devolución (venta negativa), se quita el stock devuelto
• Las devoluciones se descuentan del efectivo y transferencia en la sesión
• Solo el administrador puede anular ventas''',
            icon: Icons.cancel_outlined,
          ),
        ],
      ),
      const SizedBox(height: 24),

      _buildSection(
        title: '↩️ Devoluciones',
        icon: Icons.keyboard_return,
        children: [
          _buildCard(
            title: 'Procesar una devolución',
            content: '''
• En el carrito, cargá los productos que el cliente quiere devolver
• Tocá "DEVOLVER" (botón naranja debajo del total)
• Seleccioná el método de devolución: Efectivo o Transferencia
• Confirmá la devolución
• El stock se restaura automáticamente
• La devolución se registra como una venta negativa en la sesión de caja activa''',
            icon: Icons.assignment_return_outlined,
          ),
        ],
      ),
      const SizedBox(height: 24),

      _buildSection(
        title: '🏧 Sesión de Caja',
        icon: Icons.account_balance_wallet_outlined,
        children: [
          _buildCard(
            title: 'Sesión automática',
            content: '''
• Al cobrar tu primera venta, se abre una sesión de caja automáticamente
• No necesitás abrirla manualmente
• La sesión queda activa mientras vendés
• Podés ver el resumen de tu sesión activa en cualquier momento''',
            icon: Icons.login,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Lo que ves en tu sesión',
            content: '''
• Total de ventas realizadas
• Total cobrado en efectivo
• Total cobrado por transferencia
• Transferencias agrupadas por tipo (EnZona, Pago en línea, Bancaria)
• Cada venta muestra: nombre y teléfono del cliente (si los ingresaste)
• Cada venta tiene un botón de anular (si es admin)
• NO podés ver las ganancias - esa información es solo para el administrador''',
            icon: Icons.summarize_outlined,
          ),
        ],
      ),
      const SizedBox(height: 24),

      _buildSection(
        title: '📦 Recibir Despacho o Reposición',
        icon: Icons.download,
        children: [
          _buildCard(
            title: 'Importar despacho/reposición',
            content: '''
• El administrador te envía un archivo JSON con productos
• Menú → "Recibir Despacho" → Seleccioná el archivo
• Podés ver el contenido antes de aplicarlo (vista previa)
• Al confirmar, los productos y el inventario se cargan en tu app
• También podés ver el archivo sin aplicarlo ("Solo vista") para revisar primero
• Si es un DESPACHO: reemplaza todo tu inventario
• Si es una REPOSICIÓN: solo agrega stock nuevo sin borrar lo existente''',
            icon: Icons.file_open,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Diferencia entre despacho y reposición',
            content: '''
• DESPACHO: borrás todo y empezás con lo que te mandan
• REPOSICIÓN: te suman productos a lo que ya tenés
• Ejemplo: tenés 20 productos y te faltan 2 → la admin te hace reposición de esos 2
• En "Mis Despachos" ves los badges: [Despacho] en azul, [Reposición] en naranja''',
            icon: Icons.compare_arrows,
          ),
        ],
      ),
      const SizedBox(height: 24),

      _buildSection(
        title: '📋 Rendición',
        icon: Icons.assignment,
        children: [
          _buildCard(
            title: 'Generar rendición',
            content: '''
• Menú → "Rendición" → Seleccioná la sesión de caja
• Se muestra un resumen: total de ventas, efectivo, transferencia y stock restante
• Las devoluciones se descuentan del efectivo y transferencia
• Tocá "ENVIAR RENDICIÓN" para generar el archivo JSON y compartirlo con el administrador
• La rendición incluye todas las ventas, transferencias con datos completos y el stock que te queda
• Tus rendiciones se guardan automáticamente en "Mis Rendiciones"''',
            icon: Icons.send,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Lo que ve el admin al procesar tu rendición',
            content: '''
• Se crea una sesión de caja automática con tus ventas
• El stock se descuenta de tu inventario en el celular del admin
• Se capturan snapshots de inventario antes y después
• El admin puede ver el IPV (Inventario Físico Valorado) con el detalle exacto''',
            icon: Icons.visibility,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Limpiar datos (cierre de ciclo)',
            content: '''
• Después de enviar la rendición, tocá "LIMPIAR DATOS"
• Esto elimina: productos, ventas, pagos, sesiones e inventario de tu app
• Se CONSERVAN: historial de despachos recibidos y rendiciones enviadas
• Podés ver tus rendiciones anteriores en "Mis Rendiciones" con todos los detalles
• Las transferencias de cada rendición se ven en el tab "Transf." dentro del detalle''',
            icon: Icons.delete_forever,
          ),
        ],
      ),
      const SizedBox(height: 24),

      _buildSection(
        title: '📁 Historiales',
        icon: Icons.history,
        children: [
          _buildFeatureCard(
            icon: Icons.receipt_long,
            title: 'Historial de Ventas',
            description: 'Menú → "Historial Ventas". Lista de todas las ventas realizadas con fecha, monto y método de pago. Podés ver el detalle de cada una.',
          ),
          _buildFeatureCard(
            icon: Icons.inventory_2_outlined,
            title: 'Mis Despachos',
            description: 'Menú → "Mis Despachos". Muestra todos los despachos recibidos con fecha, cantidad de productos y estado (Aplicado o Solo vista). Tocá uno para ver el detalle.',
          ),
          _buildFeatureCard(
            icon: Icons.assignment_outlined,
            title: 'Mis Rendiciones',
            description: 'Menú → "Mis Rendiciones". Muestra todas las rendiciones enviadas con fecha y totales. Tocá una para ver el detalle con tabs: Ventas, Transferencias y Stock restante.',
          ),
          _buildFeatureCard(
            icon: Icons.swap_horiz,
            title: 'Hist. Transferencias',
            description: 'Menú → "Hist. Transferencias". Muestra las transferencias agrupadas por sesión de caja. Expandí una caja para ver cada transferencia con sus datos (TX ID, cliente, banco, monto).',
          ),
        ],
      ),
      const SizedBox(height: 24),

      _buildSection(
        title: '💡 Tips para Vendedoras',
        icon: Icons.lightbulb_outline,
        children: [
          _buildTipCard(
            tip: 'No podés cambiar los precios de los productos - están definidos por el administrador.',
          ),
          _buildTipCard(
            tip: 'No podés ver las ganancias de las ventas - esa información es solo para el administrador.',
          ),
          _buildTipCard(
            tip: 'Solo podés cobrar en efectivo y transferencia. Si el cliente paga con ambos, usá "Ambos".',
          ),
          _buildTipCard(
            tip: 'Usá "Pegar SMS" para cargar los datos de transferencia rápido y sin errores.',
          ),
          _buildTipCard(
            tip: 'Siempre enviá la rendición antes de limpiar los datos. Así el administrador recibe toda la información.',
          ),
          _buildTipCard(
            tip: 'Después de limpiar datos, tus rendiciones anteriores siguen disponibles en "Mis Rendiciones".',
          ),
          _buildTipCard(
            tip: 'Si un producto se agotó (stock 0) y el cliente lo devuelve, tocá el producto en el POS - te va a preguntar si es una devolución.',
          ),
          _buildTipCard(
            tip: 'Si recibís una reposición, no se borra lo que ya tenés - solo se suman los productos nuevos.',
          ),
          _buildTipCard(
            tip: 'Las transferencias se agrupan por tipo: EnZona, Pago en línea o Bancaria. El tipo se detecta automáticamente del SMS.',
          ),
          _buildTipCard(
            tip: 'En el Detalle de Caja, el tag "M" naranja al lado del producto indica que se vendió a precio de mayoreo.',
          ),
        ],
      ),
    ];
  }

  // ─── ADMIN ───────────────────────────────────────────────────────────────

  List<Widget> _buildAdminContent() {
    return [
      // ── Vendedor content (included) ──
      _buildSection(
        title: '🛒 Cómo Vender (POS)',
        icon: Icons.point_of_sale,
        children: [
          _buildCard(
            title: 'Agregar productos al carrito',
            content: '''
• Busca el producto por nombre o código en la pestaña "Productos"
• Toca el producto para agregarlo al carrito
• El sistema valida el stock disponible en tiempo real
• Si el producto ya está en el carrito, se suma una unidad más''',
            icon: Icons.search,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Cambiar cantidad y precio',
            content: '''
• En el carrito, tocá el número de cantidad para editar directamente
• Ingresá la cantidad deseada (admite decimales, ej: 1.5)
• Si la cantidad supera el stock, el sistema no permite el cambio
• Como admin, podés tocar el precio para editarlo directamente en el carrito
• Para eliminar un producto, deslizá hacia la izquierda o tocá la X''',
            icon: Icons.tune,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Cobrar la venta',
            content: '''
• Tocá "COBRAR" para ir a la pantalla de pago completo
• Seleccioná el método: Efectivo, Transferencia o Ambos
• Efectivo: ingresá monto recibido, se calcula el vuelto
• Transferencia: ingresá datos manualmente o "Pegar SMS" de PAGOxMOVIL
• Ambos: combiná efectivo + transferencia
• Tocá "CONFIRMAR" para registrar la venta y ver el comprobante''',
            icon: Icons.check_circle_outline,
          ),
        ],
      ),
      const SizedBox(height: 24),

      _buildSection(
        title: '💳 Métodos de Pago y Transferencias',
        icon: Icons.payment,
        children: [
          _buildCard(
            title: 'PAGOxMOVIL - Pegar SMS',
            content: '''
• En la pantalla de pago, tocá "Pegar SMS" con el método Transferencia o Ambos
• Copiá el SMS que recibiste en tu teléfono y pegalo
• El sistema detecta el formato automáticamente y extrae:
  - No. de Transacción
  - Nombre o teléfono del cliente
  - Banco (o tipo de transferencia)
  - Fecha de la transferencia (la fecha de EnZona se toma del día actual)
• Los campos de Nombre y Teléfono del cliente aparecen en TODOS los métodos de pago
• El campo CI solo aparece en transferencias (no en efectivo)
• El tipo de transferencia se detecta automáticamente: EnZona, Pago en línea o Bancaria''',
            icon: Icons.sms,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Historial de Transferencias',
            content: '''
• Menú → "Hist. Transferencias"
• Las transferencias se muestran agrupadas por sesión de caja
• Cada tipo de transferencia tiene su propio sub-título (EnZona, Pago en línea, Bancaria)
• Expandí una caja para ver cada transferencia con sus datos completos
• Tocá una transferencia para ver el detalle completo
• Podés exportar todo a Excel con el botón de descarga''',
            icon: Icons.swap_horiz,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Reportes de Transferencias por Tipo',
            content: '''
• Desde Detalle de Caja → botón de exportar, podés generar:
  - Excel de todas las transferencias (con columna "Tipo")
  - PDF de todas las transferencias
  - PDF solo de transferencias Pago en línea
• Las transferencias con campo "Banco" vacío se muestran como "Bancaria"
• El tipo se detecta automáticamente del SMS: EnZona, Pago en línea o Bancaria
• La fecha de EnZona se toma del día actual (no viene en el SMS)''',
            icon: Icons.assessment_outlined,
          ),
        ],
      ),
      const SizedBox(height: 24),

      _buildSection(
        title: '↩️ Devoluciones',
        icon: Icons.keyboard_return,
        children: [
          _buildCard(
            title: 'Procesar una devolución',
            content: '''
• En el carrito del POS, cargá los productos que el cliente devuelve
• Tocá "DEVOLVER" (botón naranja debajo del total)
• Seleccioná el método de devolución (efectivo o transferencia)
• Confirmá - el stock se restaura y se registra como venta negativa en la sesión activa
• Las devoluciones se descuentan del total de la sesión de caja''',
            icon: Icons.assignment_return_outlined,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Devolver producto sin stock',
            content: '''
• Si un producto tiene stock 0, aparece con badge [DEV] naranja en el POS
• Tocá el producto → se pregunta "¿Es una devolución?"
• Si confirmás, se agrega al carrito (sin validación de stock)
• Después tocá "DEVOLVER" para procesar la devolución normalmente
• Así podés devolver productos que ya se agotaron''',
            icon: Icons.undo,
          ),
        ],
      ),
      const SizedBox(height: 24),

      _buildSection(
        title: '🏧 Sesión de Caja',
        icon: Icons.account_balance_wallet_outlined,
        children: [
          _buildCard(
            title: 'Abrir y cerrar sesión',
            content: '''
• La sesión se abre automáticamente al cobrar la primera venta
• También podés abrirla manualmente con un fondo de caja inicial
• Al cerrar: ingresá el monto real en caja para el arqueo
• El sistema calcula la diferencia (faltante o sobrante)''',
            icon: Icons.swap_vertical_circle_outlined,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Ver ganancias en la sesión',
            content: '''
• Como administrador, podés ver las ganancias de cada sesión de caja
• El resumen muestra: ventas totales, costo de productos vendidos y ganancia neta
• Los vendedores NO ven esta información''',
            icon: Icons.trending_up,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Detalle de Caja - Ventas',
            content: '''
• Cada venta muestra: monto, hora, productos y datos del cliente (nombre y teléfono)
• Los productos vendidos a precio de mayoreo tienen un tag "M" naranja
• Las transferencias se agrupan por tipo (EnZona, Pago en línea, Bancaria) con subtotales
• El monto de cada transferencia aparece centrado
• Podés anular cualquier venta con el botón ❌ (se restaura el stock)
• Las ventas anuladas aparecen en rojo tachadas''',
            icon: Icons.receipt_long,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'IPV - Inventario Físico Valorado',
            content: '''
• Al abrir una sesión, se captura automáticamente el inventario completo (snapshot)
• Al cerrar la sesión, se captura el inventario restante
• En el detalle de la caja, ves: unidades iniciales, vendidas, restantes y valor en costo
• Podés exportar el IPV a Excel o PDF desde el menú de exportación de la sesión
• Si es una rendición de vendedora, el IPV muestra el stock que tenía antes y después''',
            icon: Icons.assessment,
          ),
        ],
      ),
      const SizedBox(height: 24),

      // ── Admin-only content ──
      _buildSection(
        title: '📦 Gestión de Productos y Categorías',
        icon: Icons.inventory_2_outlined,
        children: [
          _buildFeatureCard(
            icon: Icons.category_outlined,
            title: 'Categorías',
            description: 'Crea y organiza categorías para agrupar productos. Usa nombres claros (Ej: Bebidas, Lácteos, Limpieza). No se permiten nombres duplicados.',
          ),
          _buildFeatureCard(
            icon: Icons.add_box_outlined,
            title: 'Crear producto',
            description: 'Menú → Productos → Botón (+). Completa nombre, precio de venta, precio de costo, código de barras, categoría y stock inicial. Si el costo es mayor al precio de venta, se muestra una advertencia.',
          ),
          _buildFeatureCard(
            icon: Icons.edit_outlined,
            title: 'Editar producto',
            description: 'Toca un producto para ver detalles → "Editar". Podés cambiar precio, costo, categoría y más.',
          ),
          _buildFeatureCard(
            icon: Icons.visibility_off_outlined,
            title: 'Desactivar producto',
            description: 'Si un producto ya no se vende, desactivalo en vez de eliminarlo. Se mantiene el historial y ya no aparece en el POS.',
          ),
        ],
      ),
      const SizedBox(height: 24),

      _buildSection(
        title: '🗃️ Inventario',
        icon: Icons.warehouse_outlined,
        children: [
          _buildCard(
            title: 'Compra de mercadería (carrito)',
            content: '''
• Menú → Inventario → pestaña "Compra"
• Buscá productos con el campo de búsqueda (por nombre O código de barras)
• Tocá el carrito (+) para agregarlos al carrito de compra
• Cada producto agregado permite editar cantidad y costo unitario
• El total se calcula automáticamente
• Botón "Seleccionar todos" arriba a la derecha: agrega/quita todos los productos filtrados
• Revisá el resumen en "Ver carrito" antes de comprar
• Cuando toques "Confirmar compra":
  - Aparece un indicador de carga mientras se procesa
  - El botón se bloquea para evitar compras duplicadas
  - Con muchos productos puede tomar unos segundos
• Al finalizar, la app te lleva automáticamente a la pestaña "Compras" con la factura nueva visible''',
            icon: Icons.shopping_cart,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Ajustes de inventario',
            content: '''
• Menú → Inventario → Ajustes
• Usá ajustes positivos (+) para registrar ingreso de mercadería
• Usá ajustes negativos (−) para registrar pérdidas o roturas
• Cada ajuste requiere una razón (compra, pérdida, corrección, etc.)''',
            icon: Icons.tune,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Lotes FIFO - Cómo funciona',
            content: '''
FIFO = "Primero en entrar, primero en salir". Es como una fila: lo que llega primero se vende primero.

EJEMPLO PRÁCTICO:
1. Comprás 10 Pan a \$5 c/u (Lote 1 - 1 enero)
2. Después comprás 5 Pan a \$6 c/u (Lote 2 - 15 enero)
3. Vendés 12 Pan

¿Qué pasa? El sistema descuenta así:
  → Lote 1: vende los 10 a \$5 (todos los del lote más viejo)
  → Lote 2: vende 2 a \$6 (los 2 restantes del lote más nuevo)
  → Te quedan 3 Pan del Lote 2 a \$6

La ganancia se calcula con el costo REAL de cada lote, no con un promedio.
Así sabés exactamente cuánto ganaste en cada venta.''',
            icon: Icons.layers_outlined,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Costo vs Precio de venta',
            content: '''
• COSTO: cuánto te costó comprar el producto (lo que pagás al proveedor)
• PRECIO DE VENTA: cuánto le cobrás al cliente

EJEMPLO:
  → Costo: \$5 | Precio venta: \$8 → Ganancia: \$3 por unidad (60%)

REGLA DE ORO: el precio de venta SIEMPRE debe ser mayor al costo.
Si el costo es mayor al precio de venta, la app te muestra una advertencia.
Si vendés a pérdida, el sistema igual lo registra (a veces hay promociones).

CASOS ESPECIALES:
  → Si costo = precio: vendés a \$0 de ganancia (sin perder, sin ganar)
  → Si costo > precio: vendés con pérdida (cuidado, solo en promociones)
  → Si no sabés el costo: podés poner 0, pero la ganancia se calcula como \$0

CONSEJO: si no conocés el costo real, consultá al proveedor o revisá la factura de compra anterior.''',
            icon: Icons.attach_money,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Error al comprar - Cómo corregir',
            content: '''
Si te equivocaste al registrar una compra (precio, cantidad o producto):

OPCIÓN 1: Ajuste de inventario (recomendado)
  → Menú → Inventario → pestaña "Ajustes"
  → Si sobra stock: ajuste NEGATIVO (−) con el exceso
  → Si faltó stock: ajuste POSITIVO (+) con la cantidad faltante
  → Poné la razón correcta (ej: "Error en compra #123")

OPCIÓN 2: Compra con cantidad negativa
  → En la pestaña "Compra", agregá el producto con cantidad NEGATIVA
  → Ejemplo: si compraste 10 de más, poné -10
  → Al confirmar, se descuenta del inventario

OPCIÓN 3: Ajuste desde el lote (solo admin)
  → Menú → Inventario → pestaña "Stock" → tocá el producto
  → Ves los lotes individuales con su costo y cantidad
  → Desde ahí podés ajustar cantidades específicas

IMPORTANTE: no podés "borrar" un lote que ya fue vendido parcialmente.
Si ya vendiste parte de ese lote, el ajuste solo afecta el stock restante.''',
            icon: Icons.warning_amber_outlined,
          ),
        ],
      ),
      const SizedBox(height: 24),

      _buildSection(
        title: '🏢 Modo Almacén',
        icon: Icons.warehouse_outlined,
        children: [
          _buildCard(
            title: '¿Qué es el Modo Almacén?',
            content: '''
Cuando lo activás, separá tu inventario en DOS ubicaciones:
  • ALMACÉN: donde guardás mercadería de reserva
  • PV (Punto de Venta): lo que tenés disponible para vender

Ideal si tenés un almacén físico separado del local de ventas, o si guardás mercadería en un depósito.''',
            icon: Icons.help_outline,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Activar el Modo Almacén',
            content: '''
• Menú → Configuración → "Usar Almacén separado"
• Al activarlo, aparece un diálogo explicando el flujo
• Desde ese momento, las compras van al Almacén por defecto
• El stock del Almacén NO se vende directamente - primero hay que transferir a PV''',
            icon: Icons.toggle_on,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Ver stock por ubicación',
            content: '''
• En Inventario, aparece un selector arriba de las tabs: [Almacén] [PV]
• Al tocar cada uno, se carga el stock de esa ubicación
• La Valoración de Inventario muestra el total COMBINADO (Almacén + PV)
  con el desglose de cada uno''',
            icon: Icons.inventory_2,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Transferir stock (Almacén → PV)',
            content: '''
• En el tab "Stock" del Inventario, aparece el botón "Transferir Almacén → PV"
• Seleccioná el producto que querés mover
• Escribí la cantidad (o usá los botones rápidos: Todo, 5, 10)
• Tocá "Transferir" - el stock se mueve usando FIFO (lotes más viejos primero)
• El stock transferido queda disponible para vender en el POS''',
            icon: Icons.swap_horiz,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: '¿Dónde va cada cosa?',
            content: '''
COMPRAS → van al Almacén (si está activo) o al PV (si no)
VENTAS → salen del PV (siempre)
AJUSTES → a la ubicación que estés viendo
DEVOLUCIONES → vuelven al PV (donde se vendió)
DESPACHOS A VENDEDORAS → salen del PV''',
            icon: Icons.rule,
          ),
        ],
      ),
      const SizedBox(height: 24),

      _buildSection(
        title: '📤 Despachos y Reposiciones a Vendedoras',
        icon: Icons.send,
        children: [
          _buildCard(
            title: 'Crear despacho (reemplazo total)',
            content: '''
• Menú → "Despacho"
• Seleccioná la vendedora
• El modo por defecto es "Despacho" - reemplaza TODO el inventario de la vendedora
• Usá el buscador para encontrar productos rápido (por nombre o código)
• Los productos aparecen con su stock actual como cantidad por defecto
• Generá el archivo JSON y compartilo con la vendedora
• Si ya enviaste un despacho a esa vendedora HOY, se SOBRESCRIBE (no se duplica)''',
            icon: Icons.inventory_2_outlined,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Crear reposición (agregar stock)',
            content: '''
• En la pantalla de Despacho, activá el toggle "Reposición"
• En modo Reposición, las cantidades arrancan en 0
• Solo escribí la cantidad en los productos que querés reposicionar
• Usá el buscador para encontrar el producto rápido
• La reposición AGREGA stock sin borrar lo que ya tiene la vendedora
• Podés enviar varias reposiciones por día (cada una es un evento nuevo)
• Ejemplo: se le acabó el Pan → le mandás 10 Pan. Se le acabó la Leche → le mandás 5 Leche''',
            icon: Icons.add_circle_outline,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Historial de despachos',
            content: '''
• Menú → "Hist. Despachos"
• Cada despacho muestra un badge: [Despacho] en azul o [Reposición] en naranja
• Tocá uno para ver el detalle completo con todos los productos
• Podés filtrar por rango de fechas y exportar a Excel o PDF''',
            icon: Icons.history,
          ),
        ],
      ),
      const SizedBox(height: 24),

      _buildSection(
        title: '📥 Procesar Rendiciones',
        icon: Icons.assignment_return,
        children: [
          _buildCard(
            title: 'Importar rendición',
            content: '''
• La vendedora te envía un archivo JSON de rendición
• Menú → "Procesar Rendición" → Seleccioná el archivo
• Se muestra el resumen: efectivo, transferencia, total general
• Podés ver las ventas y las transferencias con datos completos en los tabs''',
            icon: Icons.file_open,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Aplicar rendición',
            content: '''
• Tocá "PROCESAR RENDICIÓN" para registrar todo en tu app
• Se crea automáticamente una sesión de caja con los datos de la rendición
• Las ventas se registran con método de pago (efectivo/transferencia/mixto)
• Las transferencias se cargan con todos sus datos (TX ID, cliente, banco, etc.)
• El stock se descuenta automáticamente usando FIFO (lotes más antiguos primero)
• Se capturan snapshots de inventario: uno antes (apertura) y otro después (cierre)
• En el detalle de la caja, ves el IPV con el movimiento exacto de stock''',
            icon: Icons.check_circle,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Hist. Rendiciones',
            content: '''
• Menú → "Hist. Rendiciones"
• Lista de todas las rendiciones procesadas con vendedora, fecha y totales
• Tocá una para ver el detalle completo con tabs: Ventas, Transferencias y Stock
• Cada rendición tiene su propia sesión de caja con IPV''',
            icon: Icons.history,
          ),
        ],
      ),
      const SizedBox(height: 24),

      _buildSection(
        title: '🧾 Gastos y Facturas de Compra',
        icon: Icons.receipt_long_outlined,
        children: [
          _buildFeatureCard(
            icon: Icons.money_off_outlined,
            title: 'Registrar gastos',
            description: 'Menú → Gastos → Botón (+). Registra gastos operativos (alquiler, servicios, sueldos, etc.) con categoría y monto.',
          ),
          _buildFeatureCard(
            icon: Icons.receipt_outlined,
            title: 'Facturas de compra',
            description: 'Registra las facturas de tus proveedores. Ingresa proveedor, número de factura, detalle y monto total.',
          ),
          _buildFeatureCard(
            icon: Icons.category_outlined,
            title: 'Categorías de gasto',
            description: 'Organiza los gastos en categorías (Alquiler, Servicios, Proveedores, Varios) para reportes más claros.',
          ),
        ],
      ),
      const SizedBox(height: 24),

      _buildSection(
        title: '📊 Reportes',
        icon: Icons.analytics_outlined,
        children: [
          _buildFeatureCard(
            icon: Icons.shopping_cart_outlined,
            title: 'Reporte de ventas',
            description: 'Ventas por período (diario, semanal, mensual). Filtra por vendedor, categoría de producto o método de pago.',
          ),
          _buildFeatureCard(
            icon: Icons.trending_up,
            title: 'Reporte de ganancias',
            description: 'Ganancia neta por período. Muestra: ingresos por ventas - costo de productos - gastos operativos.',
          ),
          _buildFeatureCard(
            icon: Icons.money_off_csred_outlined,
            title: 'Reporte de gastos',
            description: 'Detalle de gastos por categoría y período. Identifica dónde se va el dinero y optimiza costos.',
          ),
          _buildFeatureCard(
            icon: Icons.assessment_outlined,
            title: 'Reporte de Ventas (Excel)',
            description: 'Menú → Detalle de Caja → Exportar → Reporte Ventas. Tabla con fórmulas: Inicio, Entrada=0, Disponible, Vendido, Final, Costo y Ventas. Footer "Diseñado por PosJVL".',
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            icon: Icons.assessment_outlined,
            title: 'Reporte de Transferencias (Excel/PDF)',
            description: 'Desde Detalle de Caja → Exportar. Podés generar Excel de todas las transferencias (con columna "Tipo"), PDF de todas, o PDF solo de Pago en línea. Las transferencias con banco vacío se muestran como "Bancaria".',
          ),
        ],
      ),
      const SizedBox(height: 24),

      _buildSection(
        title: '📂 Exportaciones',
        icon: Icons.folder_open_outlined,
        children: [
          _buildCard(
            title: 'Ver archivos exportados',
            content: '''
• Menú → Exportaciones (en el menú lateral)
• Todos los reportes que exportás (PDF, Excel) se guardan automáticamente
• La lista muestra: nombre completo del archivo, tipo (PDF/Excel), tamaño y fecha
• Los archivos más recientes aparecen primero
• Usá el botón de recargar (↻) si no ves uno que acabás de exportar''',
            icon: Icons.list_alt,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Acciones disponibles',
            content: '''
Cada archivo tiene un menú (⋮) con estas opciones:

👁️ Abrir → abre el archivo con la app predeterminada del celular
  (PDF → lector de PDF, Excel → Google Sheets / Excel)

📤 Compartir → envía el archivo por WhatsApp, Gmail, Telegram, etc.

💾 Guardar en el teléfono → guarda el archivo en una ubicación fija
  (ya no depende de cada modelo de celular, siempre el mismo lugar)

🗑️ Eliminar → borra el archivo de la app (con confirmación)''',
            icon: Icons.more_vert,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: '¿Dónde se guardan los archivos?',
            content: '''
• Todos los archivos exportados quedan guardados en la carpeta interna de la app
• NO importa qué modelo de celular tengas - siempre están en el mismo lugar
• Accedé a ellos desde Menú → Exportaciones
• Si además elegís "Guardar en el teléfono", se copian al almacenamiento externo
  del dispositivo en una carpeta fija llamada NegocioJV/Exportaciones''',
            icon: Icons.storage_outlined,
          ),
        ],
      ),
      const SizedBox(height: 24),

      _buildSection(
        title: '👥 Trabajadores',
        icon: Icons.people_outline,
        children: [
          _buildCard(
            title: 'Crear vendedoras',
            content: '''
• Menú → Trabajadores → Botón (+)
• Ingresa nombre, username y contraseña para la vendedora
• La vendedora solo puede acceder al POS, despachos y rendiciones
• Las vendedoras NO pueden ver ganancias, reportes ni configuración''',
            icon: Icons.person_add_outlined,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Límite de vendedoras por plan',
            content: '''
• El número de vendedoras que podés crear depende de tu plan:
  - Plan FREE: 1 vendedora
  - Plan NEGOCIO: 1 vendedora
  - Plan PRO: 2 vendedoras
  - Plan MAX: 3 vendedoras
  - Plan MAXPRO: 5 vendedoras
• Si alcanzás el límite, no podés crear más hasta mejorar el plan''',
            icon: Icons.info_outline,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Desactivar vendedora',
            content: '''
• Si una vendedora deja de trabajar, desactivala en vez de eliminarla
• Se mantiene el historial de sus ventas y sesiones de caja
• Ya no podrá iniciar sesión en la app''',
            icon: Icons.person_remove_outlined,
          ),
        ],
      ),
      const SizedBox(height: 24),

      _buildSection(
        title: '💡 Tips para Administradores',
        icon: Icons.lightbulb_outline,
        children: [
          _buildTipCard(
            tip: 'Revisá los reportes semanales para identificar tendencias y tomar mejores decisiones de compra.',
          ),
          _buildTipCard(
            tip: 'Mantené el inventario actualizado. Registrá cada ingreso de mercadería para que el FIFO funcione correctamente.',
          ),
          _buildTipCard(
            tip: 'Usá "Pegar SMS" en las transferencias para cargar los datos rápido y sin errores de tipeo.',
          ),
          _buildTipCard(
            tip: 'Revisá las transferencias en "Hist. Transferencias" para verificar los datos de cada pago recibido.',
          ),
          _buildTipCard(
            tip: 'Revisá los arqueos de caja de tus vendedoras para detectar diferencias a tiempo.',
          ),
          _buildTipCard(
            tip: 'Desactivá productos que ya no vendés en vez de eliminarlos, así no perdés el historial.',
          ),
          _buildTipCard(
            tip: 'Revisá el IPV (Inventario Físico Valorado) en el detalle de cada caja para ver exactamente qué se vendió y qué queda en stock.',
          ),
          _buildTipCard(
            tip: 'Exportá el IPV a Excel o PDF para tener un registro impreso del inventario por sesión.',
          ),
          _buildTipCard(
            tip: 'Usá Reposición cuando la vendedora solo necesita reposicionar algunos productos. Las cantidades arrancan en 0 - solo escribí en los que necesites.',
          ),
          _buildTipCard(
            tip: 'Si enviaste un despacho por error, hacé otro despacho para la misma vendedora el mismo día - se sobreescribe automáticamente.',
          ),
          _buildTipCard(
            tip: 'Podés enviar varias reposiciones por día. Cada una es un evento nuevo en el historial.',
          ),
          _buildTipCard(
            tip: 'Al comprar en Inventario, esperá a que termine el proceso (mostrará un spinner). NO toques el botón de nuevo - el sistema ya lo bloquea para evitar compras duplicadas.',
          ),
          _buildTipCard(
            tip: 'Después de una compra en Inventario, la app te lleva directo a la pestaña "Compras" para que veas la factura nueva.',
          ),
          _buildTipCard(
            tip: 'Usá Menú → Exportaciones para ver todos tus reportes exportados en un solo lugar. Podés abrirlos, compartirlos o eliminarlos desde ahí.',
          ),
          _buildTipCard(
            tip: 'Ya no importa qué celular tengas - los archivos exportados siempre se guardan en la misma ubicación. Accedé desde Menú → Exportaciones.',
          ),
          _buildTipCard(
            tip: 'Al anular una venta desde el Detalle de Caja, escribí el motivo (obligatorio). El stock se restaura automáticamente.',
          ),
          _buildTipCard(
            tip: 'Cada venta en el Detalle de Caja muestra el nombre y teléfono del cliente si los ingresaste al cobrar.',
          ),
          _buildTipCard(
            tip: 'Los productos vendidos a precio de mayoreo tienen un tag "M" naranja al lado del nombre en el Detalle de Caja.',
          ),
          _buildTipCard(
            tip: 'Podés generar reportes de transferencias por tipo: Excel de todas, PDF de todas, o PDF solo de Pago en línea.',
          ),
          _buildTipCard(
            tip: 'El campo CI del cliente solo aparece al cobrar con transferencia - no en efectivo.',
          ),
          _buildTipCard(
            tip: 'En la pestaña Compra del Inventario, usá el botón de selección rápida para agregar/quitar todos los productos filtrados de golpe.',
          ),
          _buildTipCard(
            tip: 'Si activás el Modo Almacén, recordá transferir stock de Almacén a PV antes de que se agote en el local. Los clientes solo compran del PV.',
          ),
          _buildTipCard(
            tip: 'La Valoración de Inventario cuando el Almacén está activo muestra el total COMBINADO de ambas ubicaciones, con el desglose individual.',
          ),
        ],
      ),
    ];
  }

  // ─── SUPER ADMIN ─────────────────────────────────────────────────────────

  List<Widget> _buildSuperAdminContent() {
    return [
      _buildSection(
        title: '🔑 Licencias',
        icon: Icons.vpn_key_outlined,
        children: [
          _buildCard(
            title: 'Activar licencia',
            content: '''
• Al instalar la app por primera vez, se solicita una licencia
• Ingresá el código de licencia proporcionado
• La licencia se valida contra el servidor y se activa el plan correspondiente
• Si la licencia es inválida o expiró, la app queda en modo restringido''',
            icon: Icons.verified_user_outlined,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Ver detalles del plan',
            content: '''
• Menú → Licencia para ver el plan activo y su estado
• Muestra: tipo de plan, fecha de activación, fecha de vencimiento
• También muestra los límites actuales y el uso (productos y vendedoras registrados)''',
            icon: Icons.description_outlined,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Planes disponibles',
            content: '''
• Plan FREE - \$0 - 15 días de prueba
  - Máximo 100 productos, 1 vendedora
  - Funcionalidad básica del POS

• Plan NEGOCIO - \$3,000 - 31 días
  - Máximo 100 productos, 1 vendedora
  - Ideal para negocios pequeños en etapa inicial

• Plan PRO - \$8,000 - 90 días
  - Máximo 200 productos, 2 vendedoras
  - Reportes completos y funcionalidad avanzada

• Plan MAX - \$16,000 - 180 días
  - Máximo 300 productos, 3 vendedoras
  - Mayor capacidad para negocio en crecimiento

• Plan MAXPRO - \$30,000 - 365 días
  - Máximo 1.000 productos, 5 vendedoras
  - Todo incluido, máxima capacidad''',
            icon: Icons.list_alt_outlined,
          ),
        ],
      ),
      const SizedBox(height: 24),

      _buildSection(
        title: '🛡️ Gestión de Administradores',
        icon: Icons.admin_panel_settings_outlined,
        children: [
          _buildCard(
            title: 'Crear usuarios administrador',
            content: '''
• Como Super Admin, podés crear cuentas de administrador
• Menú → Trabajadores → Botón (+) → Seleccionar rol "Admin"
• El administrador tiene acceso completo a la app (excepto gestión de licencias)
• Cada admin puede crear vendedoras dentro de los límites del plan''',
            icon: Icons.person_add_outlined,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Transferencia (PAGOxMOVIL)',
            content: '''
• Seleccioná "Transferencia" como método de pago
• Podés ingresar los datos manualmente o usar "Pegar SMS"
• Al pegar un SMS de PAGOxMOVIL, el sistema extrae automáticamente:
  - No. de Transacción
  - Nombre del cliente (si aparece)
  - Teléfono del cliente
  - Tipo de transferencia (EnZona, Pago en línea, Bancaria)
  - Fecha de la transferencia
• El tipo de transferencia se detecta automáticamente del SMS
• Los campos de Nombre y Teléfono del cliente aparecen en TODOS los métodos de pago
• El campo CI solo aparece en transferencias (no en efectivo)
• Si ingresaste el teléfono del cliente, el campo de WhatsApp en la factura se auto-llena''',
            icon: Icons.swap_horiz,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Desactivar administrador',
            content: '''
• Si un admin ya no debe tener acceso, desactivalo
• Se conserva todo el historial de sus acciones
• Ya no podrá iniciar sesión en la app''',
            icon: Icons.person_remove_outlined,
          ),
        ],
      ),
      const SizedBox(height: 24),

      _buildSection(
        title: '📂 Exportaciones',
        icon: Icons.folder_open_outlined,
        children: [
          _buildCard(
            title: 'Ver archivos exportados',
            content: '''
• Menú → Exportaciones (en el menú lateral)
• Todos los reportes que exportás (PDF, Excel) se guardan automáticamente
• La lista muestra: nombre completo del archivo, tipo (PDF/Excel), tamaño y fecha
• Los archivos más recientes aparecen primero
• Usá el botón de recargar (↻) si no ves uno que acabás de exportar''',
            icon: Icons.list_alt,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Acciones disponibles',
            content: '''
Cada archivo tiene un menú (⋮) con estas opciones:

👁️ Abrir → abre el archivo con la app predeterminada del celular
📤 Compartir → envía el archivo por WhatsApp, Gmail, Telegram, etc.
💾 Guardar en el teléfono → guarda en ubicación fija (no varía por celular)
🗑️ Eliminar → borra el archivo de la app (con confirmación)''',
            icon: Icons.more_vert,
          ),
        ],
      ),
      const SizedBox(height: 24),

      _buildSection(
        title: '📞 Contacto Soporte',
        icon: Icons.support_agent,
        children: [
          _buildCard(
            title: 'Soporte por WhatsApp',
            content: '''
• Para cualquier problema técnico, contactá por WhatsApp
• Enviá una captura de pantalla del error si es posible
• Incluí el número de licencia y el nombre del negocio
• Horario de atención: lunes a viernes, 9:00 - 18:00''',
            icon: Icons.chat_outlined,
          ),
        ],
      ),
      const SizedBox(height: 24),

      _buildSection(
        title: '💡 Tips para Super Admin',
        icon: Icons.lightbulb_outline,
        children: [
          _buildTipCard(
            tip: 'Verificá el estado de la licencia antes de reportar problemas - muchas veces es un vencimiento del plan.',
          ),
          _buildTipCard(
            tip: 'Creá solo los administradores necesarios. Cada admin puede crear vendedoras y modificar el negocio.',
          ),
          _buildTipCard(
            tip: 'Si un cliente alcanza el límite de productos o vendedoras, ofrecele la actualización de plan.',
          ),
          _buildTipCard(
            tip: 'Mantené un registro de las licencias activas para dar seguimiento a los vencimientos.',
          ),
          _buildTipCard(
            tip: 'Al comprar en Inventario, esperá a que termine el proceso (spinner). El botón se bloquea solo para evitar compras duplicadas.',
          ),
          _buildTipCard(
            tip: 'Usá Menú → Exportaciones para ver todos tus reportes exportados. Podés abrirlos, compartirlos o eliminarlos.',
          ),
          _buildTipCard(
            tip: 'En Configuración → "Poner stock de 10000 a todos" resetea el inventario de cada producto a 10000 unidades. Útil para pruebas o re-inventario rápido.',
          ),
          _buildTipCard(
            tip: 'Las transferencias con campo "Banco" vacío se muestran como "Bancaria" por defecto en todos los informes.',
          ),
        ],
      ),
    ];
  }

  // ─── Reusable widget builders ────────────────────────────────────────────

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppTheme.colorCeleste, size: 24),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required String content,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.colorCeleste.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.colorCeleste, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content.trim(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.colorCeleste.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.colorCeleste.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.colorCeleste, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard({required String tip}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tips_and_updates, color: Colors.amber.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                fontSize: 14,
                color: Colors.amber.shade900,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
