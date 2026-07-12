import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:etecsa/core/services/export_service.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';

class ExportsScreen extends StatefulWidget {
  const ExportsScreen({super.key});

  @override
  State<ExportsScreen> createState() => _ExportsScreenState();
}

class _ExportsScreenState extends State<ExportsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _exportService = ExportService.instance;
  List<Map<String, dynamic>> _files = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExports();
  }

  Future<void> _loadExports() async {
    setState(() => _isLoading = true);
    try {
      final files = await _exportService.getExportsList();
      if (mounted) setState(() => _files = files);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar exportaciones: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _shareFile(String filePath, String fileName) async {
    await _exportService.shareFile(filePath, text: fileName);
  }

  Future<void> _openFile(String filePath) async {
    final opened = await _exportService.openFile(filePath);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el archivo. Probá con "Compartir" desde el menú ⋮'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _deleteFile(String filePath, String fileName, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar archivo'),
        content: Text('¿Eliminar "$fileName" de tus exportaciones?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final deleted = await _exportService.deleteExport(filePath);
      if (deleted && mounted) {
        setState(() => _files.removeAt(index));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$fileName" eliminado'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _saveToPhone(String filePath, String fileName) async {
    final savedPath = await _exportService.saveToExportsDir(filePath);
    if (!mounted) return;
    if (savedPath != null) {
      // Mostrar solo el directorio, no el nombre del archivo
      final dir = savedPath.substring(0, savedPath.lastIndexOf('/'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Guardado en $dir'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar. Usá "Compartir" como alternativa.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _deleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar todo'),
        content: Text('¿Eliminar los ${_files.length} archivos de exportaciones?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Borrar todo'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      int deleted = 0;
      for (final file in List<Map<String, dynamic>>.from(_files)) {
        final ok = await _exportService.deleteExport(file['path'] as String);
        if (ok) deleted++;
      }
      if (mounted) {
        setState(() => _files.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$deleted archivos eliminados'), backgroundColor: Colors.green),
        );
      }
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'excel':
        return Icons.table_chart;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'pdf':
        return Colors.red;
      case 'excel':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final df = DateFormat('dd/MM/yy HH:mm');
    return df.format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Exportaciones'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          if (_files.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
              tooltip: 'Borrar todo',
              onPressed: _deleteAll,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Recargar',
              onPressed: _loadExports,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? _buildEmptyState()
              : _buildFileList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 72,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay archivos exportados',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Exportá un reporte desde Productos, Ventas o Inventario\ny aparecerá acá automáticamente.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    return RefreshIndicator(
      onRefresh: _loadExports,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _files.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          final file = _files[index];
          final name = file['name'] as String;
          final path = file['path'] as String;
          final type = file['type'] as String;
          final size = file['size'] as int;
          final lastModified = file['lastModified'] as DateTime;

          return ListTile(
            onTap: () => _openFile(path),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _colorForType(type).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _iconForType(type),
                color: _colorForType(type),
                size: 26,
              ),
            ),
            title: Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                name,
                softWrap: true,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ),
            subtitle: Row(
              children: [
                Text(
                  _exportService.formatFileSize(size),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(lastModified),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (action) {
                switch (action) {
                  case 'open':
                    _openFile(path);
                    break;
                  case 'share':
                    _shareFile(path, name);
                    break;
                  case 'save':
                    _saveToPhone(path, name);
                    break;
                  case 'delete':
                    _deleteFile(path, name, index);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'open',
                  child: ListTile(
                    leading: Icon(Icons.open_in_new),
                    title: Text('Abrir'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    leading: Icon(Icons.share),
                    title: Text('Compartir'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'save',
                  child: ListTile(
                    leading: Icon(Icons.save_alt),
                    title: Text('Guardar en el teléfono'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: Colors.red),
                    title: Text('Eliminar', style: TextStyle(color: Colors.red)),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
