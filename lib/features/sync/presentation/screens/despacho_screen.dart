import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/core/services/sync_service.dart';
import 'package:etecsa/config/theme/app_theme.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';
import 'package:etecsa/features/shared/widgets/export_options_dialog.dart';
import 'package:etecsa/features/shared/services/KeyValueStorageService.dart';

class DespachoScreen extends ConsumerStatefulWidget {
  const DespachoScreen({super.key});

  @override
  ConsumerState<DespachoScreen> createState() => _DespachoScreenState();
}

class _DespachoScreenState extends ConsumerState<DespachoScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  List<User> _vendedoras = [];
  User? _selectedVendedora;
  List<Product> _products = [];
  Map<String, double> _stocks = {};
  final Map<String, double> _selectedQtys = {};
  final Map<String, TextEditingController> _qtyControllers = {};
  /// Productos eliminados del despacho (ocultos en la lista)
  final Set<String> _removedProductIds = {};
  bool _loading = true;
  bool _exporting = false;
  bool _hasDraft = false;
  bool _isReposicion = false; // false = despacho (reemplazo), true = reposición (agregar stock)

  static const _draftKey = 'despacho_draft';

  /// Formatea cantidad respetando decimales (1.5 -> "1.5", 2.0 -> "2")
  String _fmtQty(double qty) {
    if (qty == qty.truncateToDouble()) return qty.toInt().toString();
    return qty.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final c in _qtyControllers.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _loadData() async {
    final db = AppDatabase.instance;
    final users = await db.getAllUsers();
    final vendedoras = users.where((u) => u.role == 'vendedor' && u.active).toList();
    final products = await db.getAllProducts();
    final stocks = await db.getAllStocks();

    if (mounted) {
      setState(() {
        _vendedoras = vendedoras;
        _products = products.where((p) => p.isActive).toList();
        _products.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _stocks = stocks;
        _loading = false;
      });

      // Autocompletar stock y luego cargar borrador (que puede sobreescribir cantidades)
      _autofillStock();
      await _loadDraft();
    }
  }

  /// Llena todos los productos con su stock actual como cantidad
  void _autofillStock() {
    for (final product in _products) {
      final stock = _stocks[product.id] ?? 0;
      _selectedQtys[product.id] = stock;
      final ctrl = _qtyControllers.putIfAbsent(product.id, () => TextEditingController());
      ctrl.text = _fmtQty(stock);
    }
    setState(() {});
  }

  /// Guarda el borrador actual en SecureStorage
  Future<void> _saveDraft() async {
    final storage = KeyValueStorageService();
    final draft = {
      'vendedoraId': _selectedVendedora?.id ?? '',
      'removedIds': _removedProductIds.toList(),
      'qtys': _selectedQtys.map((k, v) => MapEntry(k, v)),
    };
    await storage.setKeyValue(_draftKey, jsonEncode(draft));
    setState(() => _hasDraft = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Borrador guardado'), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
      );
    }
  }

  /// Carga el borrador desde SecureStorage (si existe)
  Future<void> _loadDraft() async {
    final storage = KeyValueStorageService();
    final raw = await storage.getValue(_draftKey);
    if (raw == null || raw.isEmpty) {
      setState(() => _hasDraft = false);
      return;
    }

    try {
      final draft = jsonDecode(raw) as Map<String, dynamic>;

      // Restaurar vendedora
      final vendedoraId = draft['vendedoraId'] as String? ?? '';
      if (vendedoraId.isNotEmpty) {
        final match = _vendedoras.where((v) => v.id == vendedoraId).firstOrNull;
        if (match != null) _selectedVendedora = match;
      }

      // Restaurar productos eliminados
      final removedIds = draft['removedIds'] as List<dynamic>? ?? [];
      _removedProductIds.clear();
      for (final id in removedIds) {
        _removedProductIds.add(id as String);
      }

      // Restaurar cantidades
      final qtys = draft['qtys'] as Map<String, dynamic>? ?? {};
      _selectedQtys.clear();
      for (final entry in qtys.entries) {
        final qty = (entry.value as num).toDouble();
        _selectedQtys[entry.key] = qty;
        final ctrl = _qtyControllers.putIfAbsent(entry.key, () => TextEditingController());
        ctrl.text = _fmtQty(qty);
      }

      // Asegurar que los productos no eliminados y no presentes en qtys tengan su stock
      for (final product in _products) {
        if (!_removedProductIds.contains(product.id) && !_selectedQtys.containsKey(product.id)) {
          final stock = _stocks[product.id] ?? 0;
          _selectedQtys[product.id] = stock;
          final ctrl = _qtyControllers.putIfAbsent(product.id, () => TextEditingController());
          ctrl.text = _fmtQty(stock);
        }
      }

      setState(() => _hasDraft = true);
    } catch (_) {
      // Borrador corrupto, ignorar
      setState(() => _hasDraft = false);
    }
  }

  /// Elimina el borrador del storage
  Future<void> _clearDraft() async {
    final storage = KeyValueStorageService();
    await storage.removeKey(_draftKey);
    setState(() => _hasDraft = false);
  }

  /// Resetea el formulario para un nuevo despacho
  void _resetForm() {
    _searchController.clear();
    _selectedVendedora = null;
    _removedProductIds.clear();
    _isReposicion = false;
    for (final c in _qtyControllers.values) { c.dispose(); }
    _qtyControllers.clear();
    _autofillStock();
  }

  /// Muestra dialog de advertencia cuando el admin intenta hacer reposición.
  /// Retorna true si el admin confirma que ya compró el stock.
  Future<bool> _showReposicionWarning(List<Map<String, dynamic>> selectedProducts) async {
    bool confirmed = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          icon: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 48),
          title: const Text('Reposición de stock'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estás por enviar stock a ${_selectedVendedora!.fullName}. '
                  'Para que tu inventario sea consistente, primero debés haber comprado ese stock.',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Productos a reposicionar:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800, fontSize: 12)),
                      const SizedBox(height: 6),
                      for (final p in selectedProducts) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p['nombre'] as String,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              'Envías: ${_fmtQty(p['cantidad'] as double)}  |  Tenés: ${_fmtQty(_stocks[p['id']] ?? 0)}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: confirmed,
                      onChanged: (v) => setDialogState(() => confirmed = v ?? false),
                      activeColor: AppTheme.colorMorado,
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDialogState(() => confirmed = !confirmed),
                        child: const Text(
                          'Confirmo que ya realicé la compra de este stock',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: confirmed ? () => Navigator.pop(ctx) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmed ? AppTheme.colorMorado : Colors.grey,
              ),
              child: const Text('ENVIAR REPOSICIÓN', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    return confirmed;
  }

  /// Elimina un producto del despacho (lo oculta de la lista)
  void _removeProduct(String productId) {
    setState(() {
      _removedProductIds.add(productId);
      _selectedQtys.remove(productId);
    });
    // Dispose y remover controller
    final ctrl = _qtyControllers.remove(productId);
    ctrl?.dispose();
  }

  /// Restaura un producto previamente eliminado
  void _restoreProduct(String productId) {
    setState(() {
      _removedProductIds.remove(productId);
      final stock = _stocks[productId] ?? 0;
      _selectedQtys[productId] = stock;
      final ctrl = _qtyControllers.putIfAbsent(productId, () => TextEditingController());
      ctrl.text = _fmtQty(stock);
    });
  }

  List<Product> get _visibleProducts {
    final query = _searchController.text.toLowerCase();
    final filtered = _products.where((p) {
      if (_removedProductIds.contains(p.id)) return false;
      if (query.isEmpty) return true;
      return p.name.toLowerCase().contains(query) || (p.code?.toLowerCase().contains(query) ?? false);
    }).toList();
    filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return filtered;
  }

  List<Map<String, dynamic>> _getSelectedProducts() {
    return _selectedQtys.entries
        .where((e) => e.value > 0 && !_removedProductIds.contains(e.key))
        .map((e) {
      final product = _products.firstWhere((p) => p.id == e.key);
      return {
        'id': product.id,
        'nombre': product.name,
        'codigo': product.code,
        'categoriaId': product.categoryId,
        'precioVenta': product.unitPrice,
        'precioCosto': product.costPrice,
        'cantidad': e.value,
      };
    }).toList();
  }

  Future<void> _exportDespacho() async {
    if (_selectedVendedora == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccioná un vendedor'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_exporting) return;

    final selectedProducts = _getSelectedProducts();
    if (selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccioná al menos un producto con cantidad'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Validar stock: no enviar más de lo que se tiene
    final overStock = <String>[];
    for (final p in selectedProducts) {
      final available = _stocks[p['id']] ?? 0;
      final requested = p['cantidad'] as double;
      if (requested > available) {
        overStock.add('${p['nombre']} (pedís ${_fmtQty(requested)}, tenés ${_fmtQty(available)})');
      }
    }
    if (overStock.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No tenés suficiente stock:\n${overStock.join('\n')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    // Si es REPOSICIÓN, mostrar advertencia sobre compra de stock
    if (_isReposicion) {
      final confirmed = await _showReposicionWarning(selectedProducts);
      if (!confirmed) return;
    }

    setState(() => _exporting = true);
    try {
      final tipo = _isReposicion ? 'reposicion' : 'despacho';
      final filePath = await SyncService.instance.exportDespacho(
        vendedoraId: _selectedVendedora!.id,
        vendedoraNombre: _selectedVendedora!.fullName,
        productos: selectedProducts,
        tipo: tipo,
      );

      // Exportación exitosa → limpiar borrador
      await _clearDraft();

      if (mounted) {
        final label = _isReposicion ? 'Reposición' : 'Despacho';
        await ExportOptionsDialog.show(
          context,
          filePath: filePath,
          shareText: '$label para ${_selectedVendedora!.fullName}',
        );

        // Después de compartir/guardar, mostrar confirmación con opción de nuevo despacho
        if (mounted) {
          final vendedoraName = _selectedVendedora!.fullName;
          final productCount = selectedProducts.length;
          final totalUnits = selectedProducts.fold(0.0, (sum, p) => sum + (p['cantidad'] as double)).ceil();

          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
              title: Text('$label enviado'),
              content: Text(
                '$label para $vendedoraName enviado correctamente.\n'
                '$productCount productos · $totalUnits unidades',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/');
                  },
                  child: const Text('Volver al inicio'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _resetForm();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.colorMorado),
                  child: const Text('Nuevo despacho', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showRemovedProducts() {
    final removed = _products.where((p) => _removedProductIds.contains(p.id)).toList();
    removed.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (removed.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('Productos eliminados', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  Text('${removed.length}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: removed.length,
                itemBuilder: (context, index) {
                  final product = removed[index];
                  return ListTile(
                    title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Stock: ${_fmtQty(_stocks[product.id] ?? 0)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.restore, color: AppTheme.colorCeleste),
                      tooltip: 'Restaurar',
                      onPressed: () {
                        _restoreProduct(product.id);
                        Navigator.pop(context);
                        if (removed.length <= 1) {
                          // Era el último, el bottom sheet quedaría vacío
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final selectedProducts = _getSelectedProducts();
    final visibleProducts = _visibleProducts;
    final removedCount = _removedProductIds.length;

    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        title: const Text('Despacho'),
        leading: IconButton(icon: const Icon(Icons.menu), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
        actions: [
          if (removedCount > 0)
            TextButton.icon(
              onPressed: _showRemovedProducts,
              icon: const Icon(Icons.restore_from_trash, color: Colors.white70, size: 18),
              label: Text('$removedCount', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ),
          if (_hasDraft)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white70),
              tooltip: 'Borrar borrador',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Borrar borrador'),
                    content: const Text('¿Querés eliminar el borrador guardado? Se re-cargarán los stocks actuales.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Borrar')),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _clearDraft();
                  _autofillStock();
                  setState(() {
                    _selectedVendedora = null;
                    _removedProductIds.clear();
                  });
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Header compacto: vendedora + toggle reposición
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Column(
              children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<User>(
                          value: _selectedVendedora,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: 'Vendedor',
                            prefixIcon: Icon(Icons.person, size: 18),
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          ),
                          items: _vendedoras.map((v) => DropdownMenuItem(value: v, child: Text(v.fullName, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (v) => setState(() => _selectedVendedora = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isReposicion ? 'Reposic.' : 'Despacho',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _isReposicion ? Colors.orange : AppTheme.colorCeleste),
                          ),
                          Switch(
                            value: _isReposicion,
                            onChanged: (v) {
                              setState(() {
                                _isReposicion = v;
                                if (v) {
                                  for (final product in _products) {
                                    _selectedQtys[product.id] = 0;
                                    final ctrl = _qtyControllers[product.id];
                                    if (ctrl != null) ctrl.text = '0';
                                  }
                                } else {
                                  _autofillStock();
                                }
                              });
                            },
                            activeColor: Colors.orange,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Buscador + contador en una sola fila
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Buscar producto...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${selectedProducts.length} sel.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Lista de productos (ocupa todo el espacio restante)
          Expanded(
            child: visibleProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text('Todos los productos fueron eliminados', style: TextStyle(color: Colors.grey.shade500)),
                        const SizedBox(height: 12),
                        if (_removedProductIds.isNotEmpty)
                          TextButton.icon(
                            onPressed: _showRemovedProducts,
                            icon: const Icon(Icons.restore),
                            label: const Text('Restaurar productos'),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: visibleProducts.length,
                    itemBuilder: (context, index) {
                      final product = visibleProducts[index];
                      final stock = _stocks[product.id] ?? 0;
                      final ctrl = _qtyControllers.putIfAbsent(product.id, () => TextEditingController(text: _fmtQty(_selectedQtys[product.id] ?? stock)));

                      return Dismissible(
                        key: Key(product.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text('Quitar ${product.name}'),
                              content: const Text('¿Querés eliminar este producto del despacho?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Quitar')),
                              ],
                            ),
                          );
                          return confirm ?? false;
                        },
                        onDismissed: (_) => _removeProduct(product.id),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          color: Colors.red.shade100,
                          child: Icon(Icons.delete, color: Colors.red.shade400),
                        ),
                        child: Card(
                          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      Text(
                                        'Stock: ${_fmtQty(stock)} | Costo: \$${product.costPrice.toStringAsFixed(0)} | Venta: \$${product.unitPrice.toStringAsFixed(0)}',
                                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                      ),
                                      if ((_selectedQtys[product.id] ?? 0) > stock)
                                        Text(
                                          'Excede stock por ${_fmtQty((_selectedQtys[product.id] ?? 0) - stock)}',
                                          style: TextStyle(fontSize: 9, color: Colors.red.shade700, fontWeight: FontWeight.bold),
                                        ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 70,
                                  child: TextField(
                                    controller: ctrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: (_selectedQtys[product.id] ?? 0) > stock ? Colors.red : null,
                                      fontWeight: (_selectedQtys[product.id] ?? 0) > stock ? FontWeight.bold : null,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      hintText: '0',
                                      contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: (_selectedQtys[product.id] ?? 0) > stock
                                            ? const BorderSide(color: Colors.red, width: 1.5)
                                            : BorderSide(color: Colors.grey.shade400),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: (_selectedQtys[product.id] ?? 0) > stock
                                            ? const BorderSide(color: Colors.red, width: 2)
                                            : const BorderSide(color: AppTheme.colorCeleste),
                                      ),
                                    ),
                                    onChanged: (val) {
                                      final qty = double.tryParse(val) ?? 0;
                                      setState(() {
                                        _selectedQtys[product.id] = qty;
                                      });
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close, size: 16, color: Colors.red.shade300),
                                  padding: const EdgeInsets.all(2),
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  tooltip: 'Quitar del despacho',
                                  onPressed: () => _removeProduct(product.id),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Footer compacto
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selectedProducts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${selectedProducts.length} prod. | ${selectedProducts.fold(0.0, (sum, p) => sum + (p['cantidad'] as double)).ceil()} unid.', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          Text('\$${selectedProducts.fold(0.0, (sum, p) => sum + (p['cantidad'] as double) * (p['precioCosto'] as double)).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saveDraft,
                          icon: const Icon(Icons.save_outlined, size: 16),
                          label: const Text('BORRADOR', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.colorCeleste,
                            side: const BorderSide(color: AppTheme.colorCeleste),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: FloatingActionButton.extended(
                          onPressed: _exporting ? null : _exportDespacho,
                          backgroundColor: _exporting
                              ? Colors.grey
                              : _isReposicion
                                  ? Colors.orange
                                  : AppTheme.colorMorado,
                          foregroundColor: Colors.white,
                          icon: _exporting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Icon(_isReposicion ? Icons.add_circle : Icons.send, size: 18),
                          label: Text(
                            _exporting
                                ? 'GENERANDO...'
                                : _isReposicion
                                    ? 'ENVIAR REPOSICIÓN'
                                    : 'ENVIAR DESPACHO',
                            style: const TextStyle(fontSize: 12),
                          ),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
