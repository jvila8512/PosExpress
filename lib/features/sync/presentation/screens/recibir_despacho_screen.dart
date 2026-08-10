import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/core/services/sync_service.dart';
import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';
import 'package:etecsa/features/products/presentation/providers/products_provider.dart';
import 'package:etecsa/features/products/presentation/providers/categories_provider.dart';
import 'package:etecsa/features/pos/presentation/providers/pos_provider.dart';
import 'package:etecsa/features/home/presentation/screens/home_screen.dart';
import 'package:uuid/uuid.dart';

class RecibirDespachoScreen extends ConsumerStatefulWidget {
  const RecibirDespachoScreen({super.key});

  @override
  ConsumerState<RecibirDespachoScreen> createState() => _RecibirDespachoScreenState();
}

class _RecibirDespachoScreenState extends ConsumerState<RecibirDespachoScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic>? _despacho;
  bool _loading = false;
  String _status = ''; // '', 'aplicado', 'solo_vista'

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _loading = true);
      try {
        final data = await SyncService.instance.importDespacho(result.files.single.path!);
        setState(() {
          _despacho = data;
          _loading = false;
          _status = '';
        });
      } catch (e) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al importar: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _applyDespacho() async {
    if (_despacho == null) return;

    final tipo = _despacho!['tipo'] as String? ?? 'despacho';

    // Si es despacho (no reposición), mostrar confirmación
    if (tipo != 'reposicion') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Text('¿Aplicar Despacho?'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Esto va a REEMPLAZAR todos tus datos actuales por los del nuevo despacho:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                const Row(children: [Icon(Icons.inventory, size: 18, color: Colors.red), SizedBox(width: 8), Flexible(child: Text('Se borrarán todos los productos actuales'))]),
                const SizedBox(height: 4),
                const Row(children: [Icon(Icons.category, size: 18, color: Colors.red), SizedBox(width: 8), Flexible(child: Text('Se borrarán todas las categorías'))]),
                const SizedBox(height: 4),
                const Row(children: [Icon(Icons.point_of_sale, size: 18, color: Colors.red), SizedBox(width: 8), Flexible(child: Text('Se cerrará la caja actual'))]),
                const SizedBox(height: 16),
                const Text(
                  'Los datos históricos (ventas, rendiciones) NO se pierden.\n\n¿Estás segura de que querés aplicar este despacho?',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('APLICAR DESPACHO'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _loading = true);
    try {
      if (tipo == 'reposicion') {
        await SyncService.instance.applyReposicion(_despacho!);
      } else {
        await SyncService.instance.applyDespacho(_despacho!);
      }
      setState(() {
        _loading = false;
        _status = 'aplicado';
      });
      // Refrescar providers para que todo se vea al instante (sin cerrar/reabrir app)
      ref.read(productsProvider.notifier).loadProducts();
      await ref.read(stocksProvider.notifier).refresh();
      ref.invalidate(homeDataProvider);
      ref.invalidate(currentSessionProvider); // La caja se cerró con el despacho
      ref.read(cartProvider.notifier).clear(); // Limpiar carrito residual
      ref.read(categoriesProvider.notifier).loadCategories(); // Categorías se recrearon
      if (mounted) {
        final label = tipo == 'reposicion' ? 'Reposición' : 'Despacho';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label aplicado correctamente'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al aplicar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _soloVer() async {
    if (_despacho == null) return;

    setState(() => _loading = true);
    try {
      final db = AppDatabase.instance;
      final despachoId = const Uuid().v4();
      final productos = _despacho!['productos'] as List<dynamic>? ?? [];
      final vendedoraId = _despacho!['vendedoraId'] as String? ?? '';
      final vendedoraNombre = _despacho!['vendedoraNombre'] as String? ?? '';
      final fechaDespacho = _despacho!['fecha'] as String? ?? DateTime.now().toIso8601String();

      await db.addDespachoRecibido(
        id: despachoId,
        vendedoraId: vendedoraId,
        vendedoraNombre: vendedoraNombre,
        fechaDespacho: DateTime.parse(fechaDespacho),
        productosCount: productos.length,
        rawJson: const JsonEncoder.withIndent(' ').convert(_despacho!),
        status: 'solo_vista',
      );

      setState(() {
        _loading = false;
        _status = 'solo_vista';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Despacho guardado como "solo vista" - no se modificó el inventario'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productos = (_despacho?['productos'] as List<dynamic>? ?? []).toList();
    productos.sort((a, b) => (a['nombre'] as String? ?? '').toLowerCase().compareTo((b['nombre'] as String? ?? '').toLowerCase()));
    final tipo = _despacho?['tipo'] as String? ?? 'despacho';
    final isReposicion = tipo == 'reposicion';

    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
        appBar: AppBar(
          title: Text(isReposicion ? 'Recibir Reposición' : 'Recibir Despacho'),
        leading: IconButton(icon: const Icon(Icons.menu), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _despacho == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_download, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text('Seleccioná el archivo de despacho', style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 24),
                      FloatingActionButton.extended(
                        onPressed: _pickFile,
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        icon: const Icon(Icons.file_open),
                        label: const Text('IMPORTAR JSON'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: isReposicion
                          ? Colors.orange.withValues(alpha: 0.1)
                          : AppColors.accent.withValues(alpha: 0.1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isReposicion ? Icons.add_circle : Icons.inventory_2,
                                color: isReposicion ? Colors.orange : AppColors.accent,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isReposicion ? 'Reposición de:' : 'Despacho de:',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                          Text('${_despacho!['vendedoraNombre'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Fecha: ${_despacho!['fecha'] ?? ''}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          Text('${productos.length} productos', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          if (isReposicion)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '⚠️ Se agregará stock sin borrar lo existente',
                                style: TextStyle(color: Colors.orange.shade700, fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: productos.length,
                        itemBuilder: (context, index) {
                          final p = productos[index];
                          return ListTile(
                            title: Text(p['nombre'] as String),
                            subtitle: Text('Cantidad: ${p['cantidad']}'),
                            leading: CircleAvatar(
                              backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                              child: Text('${p['cantidad']}', style: const TextStyle(fontSize: 12)),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_status.isEmpty)
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: FloatingActionButton.extended(
                                  heroTag: 'apply',
                                  onPressed: _applyDespacho,
                                  backgroundColor: isReposicion ? Colors.orange : AppColors.accent,
                                  foregroundColor: Colors.white,
                                  icon: Icon(isReposicion ? Icons.add_circle : Icons.check),
                                  label: Text(isReposicion ? 'APLICAR REPOSICIÓN' : 'APLICAR DESPACHO'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _soloVer,
                                  icon: const Icon(Icons.visibility, color: Colors.orange),
                                  label: const Text('SOLO VER (no aplicar)', style: TextStyle(color: Colors.orange)),
                                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_status == 'aplicado')
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle, color: Colors.green),
                                SizedBox(width: 8),
                                Text('Despacho aplicado', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.visibility, color: Colors.orange),
                                SizedBox(width: 8),
                                Text('Solo vista - Inventario sin cambios', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
