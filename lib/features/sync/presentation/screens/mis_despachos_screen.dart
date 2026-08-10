import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';
import 'package:intl/intl.dart';

class MisDespachosScreen extends StatefulWidget {
  const MisDespachosScreen({super.key});

  @override
  State<MisDespachosScreen> createState() => _MisDespachosScreenState();
}

class _MisDespachosScreenState extends State<MisDespachosScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  List<DespachosRecibido> _despachos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDespachos();
  }

  Future<void> _loadDespachos() async {
    final db = AppDatabase.instance;
    final data = await db.getAllDespachosRecibidos();
    if (mounted) {
      setState(() {
        _despachos = data;
        _loading = false;
      });
    }
  }

  void _showDetail(DespachosRecibido despacho) {
    Map<String, dynamic>? raw;
    try {
      raw = jsonDecode(despacho.rawJson) as Map<String, dynamic>;
    } catch (_) {}

    final productos = raw?['productos'] as List<dynamic>? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Despacho recibido', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: despacho.status == 'aplicado' ? Colors.green.shade50 : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          despacho.status == 'aplicado' ? 'Aplicado' : 'Solo vista',
                          style: TextStyle(
                            fontSize: 11,
                            color: despacho.status == 'aplicado' ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(DateFormat('dd/MM/yyyy HH:mm').format(despacho.fechaRecibido), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('${despacho.productosCount} productos', style: const TextStyle(fontSize: 13, color: AppColors.accent)),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: productos.length,
                itemBuilder: (_, i) {
                  final p = productos[i] as Map<String, dynamic>;
                  return ListTile(
                    dense: true,
                    title: Text(p['nombre'] as String? ?? ''),
                    trailing: Text('${p['cantidad']} × \$${(p['precioVenta'] as num?)?.toStringAsFixed(0) ?? '0'}'),
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
    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        title: const Text('Mis Despachos'),
        leading: IconButton(icon: const Icon(Icons.menu), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _despachos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text('No hay despachos recibidos', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDespachos,
                  child: ListView.builder(
                    itemCount: _despachos.length,
                    itemBuilder: (context, index) {
                      final d = _despachos[index];
                      final esReposicion = d.tipo == 'reposicion';
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: esReposicion
                                ? Colors.orange.withValues(alpha: 0.1)
                                : AppColors.accent.withValues(alpha: 0.1),
                            child: Icon(
                              esReposicion ? Icons.add_circle : Icons.inventory_2_outlined,
                              color: esReposicion ? Colors.orange : AppColors.accent,
                              size: 20,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  esReposicion ? 'Reposición' : 'Despacho',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: esReposicion ? Colors.orange.shade50 : AppColors.accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: esReposicion ? Colors.orange.shade200 : AppColors.accent.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  esReposicion ? 'Reposición' : 'Despacho',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: esReposicion ? Colors.orange.shade700 : AppColors.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text('Recibido: ${DateFormat('dd/MM/yyyy HH:mm').format(d.fechaRecibido)}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${d.productosCount} prod.', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.accent)),
                              if (d.status == 'aplicado')
                                const Icon(Icons.check_circle, size: 16, color: Colors.green)
                              else
                                const Icon(Icons.visibility, size: 16, color: Colors.orange),
                            ],
                          ),
                          onTap: () => _showDetail(d),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
