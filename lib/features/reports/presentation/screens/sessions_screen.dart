import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:etecsa/config/theme/app_theme.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';
import 'package:etecsa/features/shared/widgets/export_options_dialog.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/core/services/export_service.dart';

class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  
  List<Session> _allSessions = [];
  List<Session> _filteredSessions = [];
  DateTime? _filterDate;
  String _sortOrder = 'desc';  // 'desc' o 'asc'
  int _currentPage = 0;
  static const int _pageSize = 31;
  bool _isLoading = true;
  bool _isVendedor = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} $hour:$minute $amPm';
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    
    final storage = const FlutterSecureStorage();
    final role = await storage.read(key: 'user_role') ?? '';
    _isVendedor = role == 'vendedor';
    
    if (_isVendedor) {
      // Vendedor solo ve sus propias sesiones
      final userId = await storage.read(key: 'user_id') ?? '';
      _allSessions = await AppDatabase.instance.getSessionsByUser(userId);
    } else {
      _allSessions = await AppDatabase.instance.getAllSessions();
    }
    
    _applyFilters();
  }

  void _applyFilters() {
    List<Session> result = List.from(_allSessions);

    // Filtro por fecha
    if (_filterDate != null) {
      result = result.where((s) {
        final date = DateTime(s.openingTime.year, s.openingTime.month, s.openingTime.day);
        final filter = DateTime(_filterDate!.year, _filterDate!.month, _filterDate!.day);
        return date == filter;
      }).toList();
    }

    // Ordenar
    result.sort((a, b) {
      final comparison = a.openingTime.compareTo(b.openingTime);
      return _sortOrder == 'desc' ? -comparison : comparison;
    });

    _filteredSessions = result;
    _currentPage = 0;
    setState(() => _isLoading = false);
  }

  void _showDateFilter() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _filterDate = picked);
      _applyFilters();
    }
  }

  void _clearDateFilter() {
    setState(() => _filterDate = null);
    _applyFilters();
  }

  void _toggleSort() {
    setState(() => _sortOrder = _sortOrder == 'desc' ? 'asc' : 'desc');
    _applyFilters();
  }

  void _nextPage() {
    final maxPage = ((_filteredSessions.length - 1) / _pageSize).floor();
    if (_currentPage < maxPage) {
      setState(() => _currentPage++);
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      setState(() => _currentPage--);
    }
  }

  void _exportAllSessions() {
    final buffer = StringBuffer();
    buffer.writeln('======================================');
    buffer.writeln('INFORME DE CAJAS - POSJVL');
    buffer.writeln('======================================');
    buffer.writeln('');
    
    for (final s in _filteredSessions) {
      buffer.writeln('Fecha: ${s.openingTime.toString().substring(0, 16)}');
      buffer.writeln('Estado: ${s.status}');
      buffer.writeln('Ventas: \$${s.totalSales?.toStringAsFixed(2) ?? '0.00'}');
      buffer.writeln('Efectivo: \$${s.totalCash?.toStringAsFixed(2) ?? '0.00'}');
      buffer.writeln('Transfer: \$${s.totalTransfer?.toStringAsFixed(2) ?? '0.00'}');
      buffer.writeln('---');
    }
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reporte de Cajas'),
        content: SingleChildScrollView(
          child: SelectableText(buffer.toString(), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final start = _currentPage * _pageSize;
    final end = (start + _pageSize).clamp(0, _filteredSessions.length);
    final pageSessions = _filteredSessions.isEmpty ? [] : _filteredSessions.sublist(start, end);
    final maxPage = ((_filteredSessions.length - 1) / _pageSize).floor();

    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        title: const Text('Cajas'),
        backgroundColor: AppTheme.colorCeleste,
        leading: IconButton(icon: const Icon(Icons.menu), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
        actions: [
          IconButton(
            icon: const Icon(Icons.assessment_outlined),
            tooltip: 'Reporte de Ventas por Fechas',
            onPressed: _showDateRangeVentas,
          ),
          IconButton(icon: const Icon(Icons.ios_share), tooltip: 'Exportar', onPressed: _exportAllSessions),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda y filtros
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                // Fecha
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showDateFilter,
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(_filterDate != null 
                          ? '${_filterDate!.day}/${_filterDate!.month}/${_filterDate!.year}'
                          : 'Filtrar por fecha'),
                      ),
                    ),
                    if (_filterDate != null) ...[
                      const SizedBox(width: 8),
                      IconButton(icon: const Icon(Icons.clear), onPressed: _clearDateFilter),
                    ],
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(_sortOrder == 'desc' ? Icons.arrow_downward : Icons.arrow_upward),
                      tooltip: _sortOrder == 'desc' ? 'Más reciente primero' : 'Más antiguo primero',
                      onPressed: _toggleSort,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Lista de sesiones
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : pageSessions.isEmpty 
                ? const Center(child: Text('No hay cajas'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: pageSessions.length,
                    itemBuilder: (context, index) {
                      final session = pageSessions[index];
                      final isOpen = session.status == 'open';
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isOpen ? Colors.green : Colors.grey,
                            radius: 16,
                            child: Icon(isOpen ? Icons.play_arrow : Icons.stop, color: Colors.white, size: 18),
                          ),
                          title: Text(
                            _formatDateTime(session.openingTime),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            isOpen ? 'Abierta' : 'Cerrada',
                            style: TextStyle(fontSize: 12, color: isOpen ? Colors.green : Colors.grey),
                          ),
                          trailing: Text(
                            '\$${session.totalSales?.toStringAsFixed(0) ?? '0'}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          onTap: () => context.push('/sessions/detail/${session.id}'),
                        ),
                      );
                    },
                  ),
          ),

          // Paginación simple
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 20),
                  onPressed: _currentPage > 0 ? _prevPage : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                Text('${_currentPage + 1}/${maxPage + 1}', style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 20),
                  onPressed: _currentPage < maxPage ? _nextPage : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                Text('(${_filteredSessions.length})', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDateRangeVentas() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final from = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: 'Fecha inicio',
      cancelText: 'Cancelar',
      confirmText: 'Siguiente',
    );
    if (from == null || !mounted) return;

    final to = await showDatePicker(
      context: context,
      initialDate: from,
      firstDate: from,
      lastDate: now,
      helpText: 'Fecha fin',
      cancelText: 'Cancelar',
      confirmText: 'Generar',
    );
    if (to == null || !mounted) return;

    // Generar reporte
    try {
      final filePath = await ExportService.instance.exportReporteVentasPorFechasExcel(from, to);
      if (mounted) {
        ExportOptionsDialog.show(
          context,
          filePath: filePath,
          shareText: 'Reporte de Ventas por Fechas',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}