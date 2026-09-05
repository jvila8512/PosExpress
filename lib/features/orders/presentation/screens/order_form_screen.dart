import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/features/auth/presentation/providers/auth_provider.dart';
import 'package:etecsa/features/clients/domain/entities/restaurant_client.dart';
import 'package:etecsa/features/clients/presentation/providers/client_provider.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/features/contacts/presentation/providers/contact_provider.dart';
import 'package:etecsa/features/orders/presentation/providers/order_provider.dart';
import 'package:etecsa/features/orders/presentation/screens/order_submit_helpers.dart';
import 'package:etecsa/features/products/presentation/providers/products_provider.dart';
import 'package:etecsa/features/products/presentation/providers/categories_provider.dart';
import 'package:etecsa/core/database/app_database.dart'
    show Product, Category;
import 'package:etecsa/features/shared/widgets/side_menu.dart';

// ---------------------------------------------------------------------------
// Redes Order Form Screen
// ---------------------------------------------------------------------------
///
/// Crea un pedido desde Redes (atención al cliente / redes sociales).
/// Flujo:
/// 1. Buscar cliente por teléfono → si no existe, formulario de creación.
/// 2. Seleccionar productos del catálogo con contadores +/-.
/// 3. Enviar a cocina → genera folio, crea orden, envía SMS PED.

class OrderFormScreen extends ConsumerStatefulWidget {
  const OrderFormScreen({super.key});

  @override
  ConsumerState<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends ConsumerState<OrderFormScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  // ── Cliente ──────────────────────────────────────────────────────────
  final _phoneSearchController = TextEditingController();
  RestaurantClient? _selectedClient;
  bool _isSearchingClient = false;
  List<RestaurantClient> _searchResults = [];

  // ── Cliente nuevo ────────────────────────────────────────────────────
  bool _showCreateForm = false;
  final _newNameController = TextEditingController();
  final _newPhoneController = TextEditingController();
  final _newAddressController = TextEditingController();
  final _newReferenceController = TextEditingController();

  // ── Catálogo ─────────────────────────────────────────────────────────
  String? _selectedCategoryId; // null = "todos"
  final Map<String, int> _quantities = {}; // productId → cantidad

  // ── Envío ────────────────────────────────────────────────────────────
  bool _isSubmitting = false;
  bool _orderSent = false;
  bool _smsPending = false;
  String? _createdOrderId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(productsProvider.notifier).loadProducts();
      ref.read(categoriesProvider.notifier).loadCategories();
      ref.read(clientProvider.notifier).loadAll();
    });
  }

  @override
  void dispose() {
    _phoneSearchController.dispose();
    _newNameController.dispose();
    _newPhoneController.dispose();
    _newAddressController.dispose();
    _newReferenceController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────
  // LÓGICA DE CLIENTE
  // ─────────────────────────────────────────────────────────────────────

  Future<void> _searchClient() async {
    final phone = _phoneSearchController.text.trim();
    if (phone.isEmpty) return;

    setState(() {
      _isSearchingClient = true;
      _showCreateForm = false;
      _selectedClient = null;
    });

    await ref.read(clientProvider.notifier).search(phone);

    // Read search results into local list
    final asyncVal = ref.read(clientProvider);
    List<RestaurantClient> results;
    if (asyncVal is AsyncData<List<RestaurantClient>>) {
      results = asyncVal.value;
    } else {
      results = const [];
    }
    _searchResults = results;

    // Buscar coincidencia exacta de teléfono primero
    final exact =
        results.where((c) => c.telefono == phone).toList();
    if (exact.isNotEmpty) {
      setState(() {
        _selectedClient = exact.first;
        _isSearchingClient = false;
      });
    } else if (results.isNotEmpty) {
      // Tomar el primer resultado aproximado
      setState(() {
        _selectedClient = results.first;
        _isSearchingClient = false;
      });
    } else {
      // No encontrado → mostrar formulario de creación
      setState(() {
        _showCreateForm = true;
        _isSearchingClient = false;
        _newPhoneController.text = phone;
      });
    }
  }

  Future<void> _createClient() async {
    final name = _newNameController.text.trim();
    final phone = _newPhoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      _showSnack('Completá nombre y teléfono del cliente');
      return;
    }

    final client = RestaurantClient(
      id: const Uuid().v4(),
      nombre: name,
      telefono: phone,
      direccion: _newAddressController.text.trim().isEmpty
          ? null
          : _newAddressController.text.trim(),
      referencia: _newReferenceController.text.trim().isEmpty
          ? null
          : _newReferenceController.text.trim(),
    );

    await ref.read(clientProvider.notifier).create(client);

    // Buscar el cliente recién creado
    await ref.read(clientProvider.notifier).search(phone);
    final asyncVal = ref.read(clientProvider);
    List<RestaurantClient> results;
    if (asyncVal is AsyncData<List<RestaurantClient>>) {
      results = asyncVal.value;
    } else {
      results = const [];
    }
    _searchResults = results;
    final created = results.where((c) => c.telefono == phone).toList();

    setState(() {
      if (created.isNotEmpty) {
        _selectedClient = created.first;
      } else {
        _selectedClient = client;
      }
      _showCreateForm = false;
    });
  }

  void _clearClient() {
    setState(() {
      _selectedClient = null;
      _showCreateForm = false;
      _phoneSearchController.clear();
      _newNameController.clear();
      _newPhoneController.clear();
      _newAddressController.clear();
      _newReferenceController.clear();
    });
  }

  // ─────────────────────────────────────────────────────────────────────
  // LÓGICA DE PRODUCTOS
  // ─────────────────────────────────────────────────────────────────────

  int _qty(String productId) => _quantities[productId] ?? 0;

  void _increment(String productId) {
    setState(() {
      _quantities[productId] = (_quantities[productId] ?? 0) + 1;
    });
  }

  void _decrement(String productId) {
    setState(() {
      final current = _quantities[productId] ?? 0;
      if (current <= 1) {
        _quantities.remove(productId);
      } else {
        _quantities[productId] = current - 1;
      }
    });
  }

  double get _total {
    final products = ref.read(productsProvider).products;
    double sum = 0;
    for (final entry in _quantities.entries) {
      final product = products.where((p) => p.id == entry.key).firstOrNull;
      if (product != null) {
        sum += product.unitPrice * entry.value;
      }
    }
    return sum;
  }

  int get _totalItems {
    return _quantities.values.fold(0, (a, b) => a + b);
  }

  bool get _hasItems => _quantities.isNotEmpty;

  // ─────────────────────────────────────────────────────────────────────
  // GENERAR FOLIO
  // ─────────────────────────────────────────────────────────────────────

  String _generateOrderId() {
    final user = ref.read(authProvider).user;
    final userId = user?.id ?? '0';
    final now = DateTime.now();
    final mmdd =
        '${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final existingOrders = ref.read(orderProvider.notifier).orders;
    final count = existingOrders
        .where((o) => o.id.contains('-$mmdd-'))
        .length;
    return 'R${userId}-${mmdd}-${(count + 1).toString().padLeft(3, '0')}';
  }

  // ─────────────────────────────────────────────────────────────────────
  // ENVIAR A COCINA
  // ─────────────────────────────────────────────────────────────────────

  Future<void> _submitOrder() async {
    if (_selectedClient == null) {
      _showSnack('Buscá o creá un cliente primero');
      return;
    }
    if (!_hasItems) {
      _showSnack('Agregá al menos un producto');
      return;
    }

    setState(() => _isSubmitting = true);    final products = ref.read(productsProvider).products;
    final orderId = _generateOrderId();
    final now = DateTime.now();

    final items = _quantities.entries.map((entry) {
      final product =
          products.where((p) => p.id == entry.key).firstOrNull;
      return OrderItem(
        code: product?.codigoCorto ?? product?.code ?? entry.key,
        qty: entry.value,
        price: product?.unitPrice ?? 0,
      );
    }).toList();

    final order = RestaurantOrder(
      id: orderId,
      tipoPedido: 'DOMICILIO',
      clienteId: _selectedClient!.id,
      estado: OrderState.registrado,
      canalOrigen: 'REDES',
      horaSolicitada:
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      montoTotal: _total,
      creadoPorUsuarioId: ref.read(authProvider).user?.id ?? '',
      fechaCreacion: now,
      items: items,
    );

    try {
      // Resolver el número de Cocina desde Contactos de Confianza.
      final kitchenPhones = await ref
          .read(contactRepositoryProvider)
          .getActivePhonesForRole('cocina');
      final kitchenPhone = resolveKitchenPhone(kitchenPhones);

      final smsOk = await ref
          .read(orderProvider.notifier)
          .createOrder(order, destinationPhone: kitchenPhone);

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _orderSent = true;
          _createdOrderId = orderId;
          _smsPending = kitchenPhone == null || !smsOk;
        });
        if (kitchenPhone == null) {
          _showSnack(
              'Pedido guardado SIN enviar SMS: configurá el número de Cocina en Contactos de Confianza');
        } else if (smsOk) {
          _showSnack(
              'Pedido $orderId enviado a cocina — esperando confirmación');
        } else {
          _showSnack(
              'Pedido guardado pero SMS no enviado — reintentá desde Seguimiento');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSnack('Error al enviar pedido: $e');
      }
    }
  }

  /// Handler del botón "Enviar a cocina".
  ///
  /// El botón nunca queda en silencio: si falta cliente o productos,
  /// explica qué falta en vez de quedar deshabilitado sin feedback.
  void _handleSendPressed() {
    final blocker = submitBlockerMessage(
      hasClient: _selectedClient != null,
      hasItems: _hasItems,
    );
    if (blocker != null) {
      _showSnack(blocker);
      return;
    }
    _submitOrder();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.forBrightness(Theme.of(context).brightness);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Providers
    final productsState = ref.watch(productsProvider);
    final categoriesState = ref.watch(categoriesProvider);
    final clientsAsync = ref.watch(clientProvider);

    // Productos filtrados (no eliminados — ya filtrado por provider)
    final allProducts = productsState.products;

    // Categorías: todas las que existan en la BD
    final categories = categoriesState.categories;

    // Productos agrupados por categoría
    final grouped = <String, List<Product>>{};
    for (final cat in categories) {
      final catProducts = allProducts
          .where((p) => p.categoryId == cat.id)
          .toList();
      if (catProducts.isNotEmpty) {
        grouped[cat.id] = catProducts;
      }
    }
    // Productos sin categoría
    final uncategorized = allProducts
        .where((p) =>
            p.categoryId == null ||
            !categories.any((c) => c.id == p.categoryId))
        .toList();
    if (uncategorized.isNotEmpty) {
      grouped['__sin_categoria__'] = uncategorized;
    }

    // Productos de la categoría seleccionada (o todos)
    final displayedProducts = _selectedCategoryId == null
        ? allProducts
        : (grouped[_selectedCategoryId] ?? []);

    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          _orderSent ? 'Pedido Enviado' : 'Nuevo Pedido',
        ),
        actions: [
          if (_orderSent)
            TextButton.icon(
              onPressed: () => context.go('/orders/tracking'),
              icon: const Icon(Icons.list_alt, size: 20),
              label: const Text('Ver tracking'),
            ),
        ],
      ),
      body: _orderSent ? _buildSentView(colors, theme) : _buildForm(colors, theme, clientsAsync, categories, displayedProducts),
      bottomNavigationBar: _orderSent
          ? null
          : _buildBottomBar(colors, theme),
    );
  }

  // ─── VISTA DE ENVIADO ───────────────────────────────────────────────

  Widget _buildSentView(AppColorsTheme colors, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: 80, color: colors.success),
            const SizedBox(height: 24),
            Text(
              'Pedido enviado a cocina',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (_createdOrderId != null)
              Text(
                _createdOrderId!,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colors.accent,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Esperando confirmación de cocina…',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (_smsPending) ...[
              const SizedBox(height: 8),
              Text(
                'SMS pendiente de envío — reintentá desde Seguimiento',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.warning,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Cuando cocina confirme, el estado cambiará automáticamente.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _orderSent = false;
                  _smsPending = false;
                  _createdOrderId = null;
                  _quantities.clear();
                  _clearClient();
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Nuevo pedido'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── FORMULARIO PRINCIPAL ───────────────────────────────────────────

  Widget _buildForm(
    AppColorsTheme colors,
    ThemeData theme,
    AsyncValue<List<RestaurantClient>> clientsAsync,
    List<Category> categories,
    List<Product> displayedProducts,
  ) {
    final productsState = ref.watch(productsProvider);
    final allProducts = productsState.products;
    final isLoading = productsState.isLoading;

    return Column(
      children: [
        // Folio preview
        if (!_showCreateForm && _selectedClient != null)
          _buildFolioPreview(colors, theme),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── BLOQUE CLIENTE (siempre visible) ─────────
                _buildClientSection(colors, theme, clientsAsync),

                const SizedBox(height: 8),

                // ── CATÁLOGO DE PRODUCTOS ──────────────────
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (allProducts.isEmpty)
                  _buildEmptyProducts(colors, theme)
                else ...[
                  // Tabs de categorías
                  _buildCategoryTabs(colors, theme, categories),

                  const SizedBox(height: 8),

                  // Lista de productos
                  if (displayedProducts.isEmpty)
                    _buildEmptyCategory(colors, theme)
                  else
                    ...displayedProducts.map(
                      (p) => _buildProductRow(p, colors, theme),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── PREVIEW DE FOLIO ──────────────────────────────────────────────

  Widget _buildFolioPreview(AppColorsTheme colors, ThemeData theme) {
    final folio = _generateOrderId();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colors.surface,
      child: Row(
        children: [
          Text('Folio: ', style: theme.textTheme.bodySmall),
          Text(
            folio,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.accent,
            ),
          ),
          const Spacer(),
          Text(
            '\$${_total.toStringAsFixed(2)}',
            style: theme.textTheme.titleLarge?.copyWith(
              color: colors.accent,
            ),
          ),
        ],
      ),
    );
  }

  // ─── SECCIÓN CLIENTE ───────────────────────────────────────────────

  Widget _buildClientSection(
    AppColorsTheme colors,
    ThemeData theme,
    AsyncValue<List<RestaurantClient>> clientsAsync,
  ) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.accent.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, size: 20, color: colors.accent),
              const SizedBox(width: 8),
              Text('Cliente',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: colors.accent)),
            ],
          ),
          const SizedBox(height: 12),

          if (_selectedClient != null) ...[
            // ── Cliente seleccionado ──
            _buildClientInfo(_selectedClient!, colors, theme),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _clearClient,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Cambiar cliente'),
              ),
            ),
          ] else if (_showCreateForm) ...[
            // ── Formulario de creación ──
            _buildCreateClientForm(colors, theme),
          ] else ...[
            // ── Búsqueda por teléfono ──
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _phoneSearchController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: 'Teléfono del cliente',
                      prefixIcon: Icon(Icons.phone, size: 20),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _searchClient(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed:
                        _isSearchingClient ? null : _searchClient,
                    child: _isSearchingClient
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClientInfo(
    RestaurantClient client,
    AppColorsTheme colors,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          client.nombre,
          style: theme.textTheme.titleLarge?.copyWith(
            fontFamily: GoogleFonts.dmSans().fontFamily,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.phone, size: 14, color: colors.textSecondary),
            const SizedBox(width: 4),
            Text(client.telefono,
                style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.textSecondary)),
          ],
        ),
        if (client.direccion != null && client.direccion!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on,
                  size: 14, color: colors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(client.direccion!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary)),
              ),
            ],
          ),
        ],
        if (client.referencia != null &&
            client.referencia!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.notes, size: 14, color: colors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text('Ref: ${client.referencia}',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCreateClientForm(
    AppColorsTheme colors,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cliente no encontrado. Crear nuevo:',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: colors.warning)),
        const SizedBox(height: 12),
        TextField(
          controller: _newNameController,
          decoration: const InputDecoration(
            labelText: 'Nombre *',
            prefixIcon: Icon(Icons.person_outline, size: 20),
            isDense: true,
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _newPhoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Teléfono *',
            prefixIcon: Icon(Icons.phone, size: 20),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _newAddressController,
          decoration: const InputDecoration(
            labelText: 'Dirección',
            prefixIcon: Icon(Icons.location_on, size: 20),
            isDense: true,
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _newReferenceController,
          decoration: const InputDecoration(
            labelText: 'Referencia',
            prefixIcon: Icon(Icons.notes, size: 20),
            isDense: true,
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _createClient,
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Guardar cliente'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () =>
                  setState(() => _showCreateForm = false),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ],
    );
  }

  // ─── CATEGORÍA TABS ─────────────────────────────────────────────────

  Widget _buildCategoryTabs(
    AppColorsTheme colors,
    ThemeData theme,
    List<Category> categories,
  ) {
    final tabs = <Widget>[];
    // "Todos"
    tabs.add(_buildCategoryChip(
      label: 'TODOS',
      selected: _selectedCategoryId == null,
      onTap: () => setState(() => _selectedCategoryId = null),
      colors: colors,
    ));

    for (final cat in categories) {
      tabs.add(const SizedBox(width: 8));
      tabs.add(_buildCategoryChip(
        label: cat.name,
        selected: _selectedCategoryId == cat.id,
        onTap: () => setState(() => _selectedCategoryId = cat.id),
        colors: colors,
      ));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: tabs),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required AppColorsTheme colors,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colors.accent : colors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? colors.accent : colors.textSecondary.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : colors.textPrimary,
          ),
        ),
      ),
    );
  }

  // ─── FILA DE PRODUCTO ──────────────────────────────────────────────

  Widget _buildProductRow(
    Product product,
    AppColorsTheme colors,
    ThemeData theme,
  ) {
    final qty = _qty(product.id);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Info del producto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\$${product.unitPrice.toStringAsFixed(2)}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colors.accent,
                    ),
                  ),
                ],
              ),
            ),

            // Controles +/-
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildQtyButton(
                  icon: Icons.remove,
                  onTap: () => _decrement(product.id),
                  colors: colors,
                  enabled: qty > 0,
                ),
                Container(
                  width: 40,
                  alignment: Alignment.center,
                  child: Text(
                    qty.toString(),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                _buildQtyButton(
                  icon: Icons.add,
                  onTap: () => _increment(product.id),
                  colors: colors,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQtyButton({
    required IconData icon,
    required VoidCallback onTap,
    required AppColorsTheme colors,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled
              ? colors.accent.withValues(alpha: 0.15)
              : colors.textSecondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? colors.accent : colors.textSecondary,
        ),
      ),
    );
  }

  // ─── BARRA INFERIOR ─────────────────────────────────────────────────

  Widget _buildBottomBar(AppColorsTheme colors, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: colors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Total
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.textSecondary),
                  ),
                  Text(
                    '\$${_total.toStringAsFixed(2)}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colors.accent,
                    ),
                  ),
                  if (_totalItems > 0)
                    Text(
                      '$_totalItems producto${_totalItems != 1 ? 's' : ''}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colors.textSecondary),
                    ),
                ],
              ),
            ),

            // Botón Enviar a cocina: siempre responde; si falta algo,
            // _handleSendPressed explica qué falta con un Snack.
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _handleSendPressed,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send, size: 20),
              label: Text(
                _isSubmitting
                    ? 'Enviando…'
                    : 'Enviar a cocina',
              ),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                minimumSize: const Size(180, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ESTADOS VACÍOS ─────────────────────────────────────────────────

  Widget _buildEmptyProducts(AppColorsTheme colors, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 64, color: colors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('No hay productos cargados',
                style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.textSecondary)),
            const SizedBox(height: 8),
            Text('Agregá productos desde el panel de administración',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCategory(AppColorsTheme colors, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text('No hay productos en esta categoría',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: colors.textSecondary)),
      ),
    );
  }
}
