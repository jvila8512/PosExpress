import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:etecsa/core/services/export_service.dart';

/// A reusable bottom sheet that lets the user choose between
/// saving a file to the device's Downloads folder or sharing it
/// via the system share sheet (WhatsApp, Gmail, etc.).
///
/// Usage:
///   final filePath = await ExportService.instance.exportProductsExcel();
///   if (context.mounted) {
///     ExportOptionsDialog.show(context, filePath: filePath, shareText: 'Lista de Productos');
///   }
class ExportOptionsDialog {
  static Future<void> show(
    BuildContext context, {
    required String filePath,
    String shareText = '',
  }) {
    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ExportOptionsSheet(
        filePath: filePath,
        shareText: shareText,
      ),
    );
  }
}

class _ExportOptionsSheet extends StatefulWidget {
  final String filePath;
  final String shareText;

  const _ExportOptionsSheet({
    required this.filePath,
    required this.shareText,
  });

  @override
  State<_ExportOptionsSheet> createState() => _ExportOptionsSheetState();
}

class _ExportOptionsSheetState extends State<_ExportOptionsSheet> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final fileName = widget.filePath.split('/').last;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'Exportar archivo',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            fileName,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          // Save to phone
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _saving ? null : _saveToPhone,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_alt, size: 22),
              label: Text(
                _saving ? 'Guardando...' : 'Guardar en el telefono',
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Share
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ExportService.instance.shareFile(
                  widget.filePath,
                  text: widget.shareText,
                );
              },
              icon: const Icon(Icons.share, size: 22),
              label: const Text('Compartir (WhatsApp, Gmail, etc.)'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _saveToPhone() async {
    setState(() => _saving = true);

    final savedPath = await ExportService.instance.saveToExportsDir(widget.filePath);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!mounted) return;
    Navigator.pop(context);

    if (savedPath != null) {
      // Navigate to exports screen so the user sees the file immediately
      context.go('/exports');
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
}
