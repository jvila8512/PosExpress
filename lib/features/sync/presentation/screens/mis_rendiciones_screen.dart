import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/config/theme/app_theme.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';
import 'package:intl/intl.dart';

class MisRendicionesScreen extends StatefulWidget {
  const MisRendicionesScreen({super.key});

  @override
  State<MisRendicionesScreen> createState() => _MisRendicionesScreenState();
}

class _MisRendicionesScreenState extends State<MisRendicionesScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  List<RendicionesProcesada> _rendiciones = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRendiciones();
  }

  Future<void> _loadRendiciones() async {
    final db = AppDatabase.instance;
    final data = await db.getAllRendicionesProcesadas();
    if (mounted) {
      setState(() {
        _rendiciones = data;
        _loading = false;
      });
    }
  }

  void _showDetail(RendicionesProcesada rendicion) {
    Map<String, dynamic>? raw;
    try {
      raw = jsonDecode(rendicion.rawJson) as Map<String, dynamic>;
    } catch (_) {}

    final ventas = raw?['ventas'] as List<dynamic>? ?? [];
    final stockRestante = raw?['stockRestante'] as List<dynamic>? ?? [];
    final transferencias = raw?['transferencias'] as List<dynamic>? ?? [];

    final hasVentas = ventas.isNotEmpty;
    final hasStock = stockRestante.isNotEmpty;
    final hasTransfers = transferencias.isNotEmpty;
    final tabCount = [hasVentas, hasStock, hasTransfers].where((b) => b).length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mi Rendición', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(DateFormat('dd/MM/yyyy HH:mm').format(rendicion.fechaRendicion), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _miniCard('Efectivo', '\$${rendicion.totalEfectivo.toStringAsFixed(0)}', Icons.money),
                      const SizedBox(width: 8),
                      _miniCard('Transfer.', '\$${rendicion.totalTransferencia.toStringAsFixed(0)}', Icons.account_balance),
                      const SizedBox(width: 8),
                      _miniCard('Total', '\$${rendicion.totalGeneral.toStringAsFixed(0)}', Icons.attach_money),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: DefaultTabController(
                length: tabCount > 0 ? tabCount : 1,
                child: Column(
                  children: [
                    TabBar(
                      tabs: [
                        if (hasVentas) Tab(text: 'Ventas (${ventas.length})'),
                        if (hasTransfers) Tab(text: 'Transf. (${transferencias.length})'),
                        if (hasStock) Tab(text: 'Stock (${stockRestante.length})'),
                        if (!hasVentas && !hasTransfers && !hasStock) const Tab(text: 'Sin datos'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          if (hasVentas) _ventasList(ventas),
                          if (hasTransfers) _transferenciasList(transferencias),
                          if (hasStock) _stockList(stockRestante),
                          if (!hasVentas && !hasTransfers && !hasStock) const Center(child: Text('Sin datos')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ventasList(List<dynamic> ventas) {
    return ListView.builder(
      itemCount: ventas.length,
      itemBuilder: (_, i) {
        final v = ventas[i] as Map<String, dynamic>;
        return ListTile(
          dense: true,
          title: Text(v['productoNombre'] as String? ?? ''),
          subtitle: Text('${v['metodoPago'] ?? ''}'),
          trailing: Text('${v['cantidad']} × \$${(v['precioUnitario'] as num?)?.toStringAsFixed(0) ?? '0'}'),
        );
      },
    );
  }

  Widget _transferenciasList(List<dynamic> transferencias) {
    return ListView.builder(
      itemCount: transferencias.length,
      itemBuilder: (_, i) {
        final t = transferencias[i] as Map<String, dynamic>;
        final amount = (t['amount'] as num?)?.toDouble() ?? 0;
        final txId = t['transactionId'] as String? ?? '';
        final phone = t['clientPhone'] as String? ?? '';
        final name = t['clientName'] as String? ?? '';
        final bank = t['bank'] as String? ?? '';
        return ListTile(
          dense: true,
          leading: Icon(Icons.swap_horiz, color: Colors.purple.shade400, size: 20),
          title: Text(
            name.isNotEmpty ? name : (phone.isNotEmpty ? phone : 'Sin datos'),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          subtitle: Text(
            '${txId.isNotEmpty ? txId : "Sin TX ID"}${bank.isNotEmpty ? " • $bank" : ""}',
            style: const TextStyle(fontSize: 11),
          ),
          trailing: Text('\$${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple, fontSize: 12)),
        );
      },
    );
  }

  Widget _stockList(List<dynamic> stock) {
    return ListView.builder(
      itemCount: stock.length,
      itemBuilder: (_, i) {
        final s = stock[i] as Map<String, dynamic>;
        return ListTile(
          dense: true,
          title: Text(s['productoNombre'] as String? ?? ''),
          trailing: Text('${s['cantidad']}'),
        );
      },
    );
  }

  Widget _miniCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
        child: Column(
          children: [
            Icon(icon, size: 18, color: AppTheme.colorCeleste),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
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
        title: const Text('Mis Rendiciones'),
        leading: IconButton(icon: const Icon(Icons.menu), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rendiciones.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text('No hay rendiciones enviadas', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRendiciones,
                  child: ListView.builder(
                    itemCount: _rendiciones.length,
                    itemBuilder: (context, index) {
                      final r = _rendiciones[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.colorMorado.withValues(alpha: 0.1),
                            child: const Icon(Icons.assignment, color: AppTheme.colorMorado, size: 20),
                          ),
                          title: Text('Rendición ${DateFormat('dd/MM/yy').format(r.fechaRendicion)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(r.fechaRendicion)),
                          trailing: Text('\$${r.totalGeneral.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.colorMorado)),
                          onTap: () => _showDetail(r),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
