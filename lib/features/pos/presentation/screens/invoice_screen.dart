import 'package:flutter/material.dart';
import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/features/shared/services/KeyValueStorageService.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class InvoiceItemData {
  final String productName;
  final double quantity;
  final double unitPrice;
  final double subtotal;
  final bool isWholesale;
  final double originalPrice;

  const InvoiceItemData({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.isWholesale = false,
    double? originalPrice,
  }) : originalPrice = originalPrice ?? unitPrice;
}

class InvoiceScreen extends StatefulWidget {
  final String orderId;
  final List<InvoiceItemData> items;
  final double total;
  final String method;
  final double cashAmount;
  final double transferAmount;
  final double change;
  final String sellerId;
  final bool isPrefactura;
  final String? clientPhone;
  final String? clientName;

  const InvoiceScreen({
    super.key,
    required this.orderId,
    required this.items,
    required this.total,
    required this.method,
    required this.cashAmount,
    required this.transferAmount,
    required this.change,
    required this.sellerId,
    this.isPrefactura = false,
    this.clientPhone,
    this.clientName,
  });

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final _whatsappController = TextEditingController();
  String _businessName = '';
  String _businessPhone = '';
  String _sellerName = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.clientPhone != null && widget.clientPhone!.isNotEmpty) {
      _whatsappController.text = widget.clientPhone!;
    }
    _loadData();
  }

  @override
  void dispose() {
    _whatsappController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final storage = KeyValueStorageService();
    final bName = await storage.getValue('business_name');
    final bPhone = await storage.getValue('business_phone');

    final db = AppDatabase.instance;
    String sellerName = widget.sellerId;
    try {
      final users = await db.getAllUsers();
      final user = users.where((u) => u.id == widget.sellerId).firstOrNull;
      if (user != null) sellerName = user.username;
    } catch (_) {}

    setState(() {
      _businessName = bName ?? '';
      _businessPhone = bPhone ?? '';
      _sellerName = sellerName;
      _isLoading = false;
    });
  }

  String _formatDate() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  }

  String _formatTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _formatQty(double qty) {
    if (qty == qty.toInt()) return qty.toInt().toString();
    return qty.toStringAsFixed(1);
  }

  String _getMethodLabel() {
    switch (widget.method) {
      case 'efectivo':
        return 'Efectivo';
      case 'transferencia':
        return 'Transferencia';
      case 'mixto':
        return 'Mixto';
      default:
        return widget.method;
    }
  }

  // Contact picker eliminado — el campo de teléfono se escribe manualmente

  Future<void> _shareByWhatsApp() async {
    final phone = _whatsappController.text.trim();
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final file = await _generatePdf();
    final label = widget.isPrefactura ? 'Prefactura' : 'Factura';
    final business = _businessName.isNotEmpty ? _businessName : 'Mi Negocio';

    if (cleanPhone.isEmpty) {
      // Sin número: compartir PDF normalmente
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '$label - $business',
      );
      return;
    }

    // Con número: intentar abrir WhatsApp directo con texto,
    // luego compartir el PDF por share del sistema (adjuntado)
    final whatsappUri = Uri.parse('whatsapp://send?phone=$cleanPhone&text=${Uri.encodeFull('$label - $business')}');
    final fallbackUri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeFull('$label - $business')}');

    if (await canLaunchUrl(whatsappUri) || await canLaunchUrl(fallbackUri)) {
      // WhatsApp disponible — compartir PDF por share sheet
      // (WhatsApp aparece primero en Android al compartir PDF)
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '$label - $business - Tel: $cleanPhone',
      );
    } else {
      // WhatsApp no instalado
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '$label - $business - Tel: $cleanPhone',
      );
    }
  }

  Future<void> _fallbackShare() async {
    final file = await _generatePdf();
    final label = widget.isPrefactura ? 'Prefactura' : 'Factura';
    String shareText =
        '$label - ${_businessName.isNotEmpty ? _businessName : "Mi Negocio"}';
    final phone = _whatsappController.text.trim();
    if (phone.isNotEmpty) {
      final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      shareText += '\nTel: $cleanPhone';
    }
    await Share.shareXFiles([XFile(file.path)], text: shareText);
  }

  Future<File> _generatePdf() async {
    final docTitle = widget.isPrefactura ? 'Prefactura' : 'Factura';
    final pdf = pw.Document(title: docTitle, author: 'NegocioJV');
    final accentColor = widget.isPrefactura
        ? PdfColors.orange
        : PdfColors.purple;
    final accentColor300 = widget.isPrefactura
        ? PdfColors.orange300
        : PdfColors.purple300;
    final accentColor50 = widget.isPrefactura
        ? PdfColors.orange50
        : PdfColors.purple50;

    final detailData = widget.items
        .map(
          (item) => [
            item.isWholesale
                ? '${item.productName} *'
                : item.productName,
            _formatQty(item.quantity),
            '\$${item.unitPrice.toStringAsFixed(0)}',
            '\$${item.subtotal.toStringAsFixed(0)}',
          ],
        )
        .toList();

    // Calcular si hay items mayoristas para mostrar leyenda
    final hasWholesaleItems = widget.items.any((i) => i.isWholesale);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (widget.isPrefactura)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.orange100,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),
                ),
                child: pw.Text(
                  'PREFACTURA',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.orange900,
                  ),
                ),
              ),
            pw.SizedBox(height: 8),
            pw.Text(
              _businessName.isNotEmpty ? _businessName : 'Mi Negocio',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: accentColor,
              ),
            ),
            if (_businessPhone.isNotEmpty)
              pw.Text(
                'Tel: $_businessPhone',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
            pw.SizedBox(height: 16),
            pw.Divider(color: accentColor, thickness: 1),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Fecha: ${_formatDate()}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'Hora: ${_formatTime()}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                'Atendido por: $_sellerName',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              context: context,
              headers: ['Producto', 'Cant.', 'P. Unit.', 'Subtotal'],
              data: detailData,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(color: accentColor300),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerRight,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
              },
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
              },
            ),
            pw.SizedBox(height: 12),
            if (hasWholesaleItems)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                child: pw.Text(
                  '* Precio por mayor aplicado',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.green800,
                  ),
                ),
              ),
            if (hasWholesaleItems) pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: accentColor50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        widget.isPrefactura ? 'TOTAL ESTIMADO:' : 'TOTAL:',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        '\$${widget.total.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                  if (!widget.isPrefactura) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Pago: ${_getMethodLabel()}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    if (widget.cashAmount > 0)
                      pw.Text(
                        'Efectivo: \$${widget.cashAmount.toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    if (widget.transferAmount > 0)
                      pw.Text(
                        'Transferencia: \$${widget.transferAmount.toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    if (widget.change > 0)
                      pw.Text(
                        'Cambio: \$${widget.change.toStringAsFixed(2)}',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.green,
                        ),
                      ),
                  ],
                  if (widget.isPrefactura) ...[
                    pw.SizedBox(height: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.yellow100,
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(4),
                        ),
                      ),
                      child: pw.Align(
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          'ESTE NO ES UN COMPROBANTE DE PAGO',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                            color: PdfColors.orange900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text(
              'Vuelva pronto',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final exportsDir = Directory('${dir.path}/exports');
    if (!exportsDir.existsSync()) exportsDir.createSync(recursive: true);
    final prefix = widget.isPrefactura ? 'prefactura' : 'factura';
    final file = File('${exportsDir.path}/${prefix}_${widget.orderId}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: widget.isPrefactura
                                    ? Colors.orange.withValues(alpha: 0.1)
                                    : AppColors.accent.withValues(
                                        alpha: 0.1,
                                      ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                widget.isPrefactura
                                    ? Icons.description
                                    : Icons.check_circle,
                                color: widget.isPrefactura
                                    ? Colors.orange
                                    : AppColors.accent,
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.isPrefactura
                                  ? 'PREFACTURA'
                                  : (_businessName.isNotEmpty
                                        ? _businessName
                                        : 'Mi Negocio'),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: widget.isPrefactura
                                    ? Colors.orange
                                    : AppColors.accent,
                              ),
                            ),
                            if (_businessPhone.isNotEmpty)
                              Text(
                                'Tel: $_businessPhone',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            if (widget.isPrefactura) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.amber.shade300,
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.orange,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'ESTE NO ES UN COMPROBANTE DE PAGO',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_formatDate()}  ${_formatTime()}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(
                                    Icons.person,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _sellerName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.clientName != null && widget.clientName!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.person_outline, size: 14, color: Colors.blue.shade700),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Cliente: ${widget.clientName}',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade700),
                                    ),
                                    if (widget.clientPhone != null && widget.clientPhone!.isNotEmpty) ...[
                                      const SizedBox(width: 10),
                                      Icon(Icons.phone, size: 12, color: Colors.blue.shade600),
                                      const SizedBox(width: 4),
                                      Text(widget.clientPhone!, style: TextStyle(fontSize: 11, color: Colors.blue.shade600)),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(12),
                                      ),
                                    ),
                                    child: const Row(
                                      children: [
                                        Expanded(
                                          flex: 4,
                                          child: Text(
                                            'Producto',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            'Cant.',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'P.Unit.',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Subt.',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ...widget.items.map(
                                    (item) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 4,
                                            child: Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    item.productName,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (item.isWholesale) ...[
                                                  const SizedBox(width: 4),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 1,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green.shade100,
                                                      borderRadius: BorderRadius.circular(3),
                                                    ),
                                                    child: Text(
                                                      'MAYO',
                                                      style: TextStyle(
                                                        fontSize: 8,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.green.shade700,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              _formatQty(item.quantity),
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              '\$${item.unitPrice.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              '\$${item.subtotal.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (widget.items.any((i) => i.isWholesale))
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 4),
                                      child: Text(
                                        '* Precio por mayor aplicado',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontStyle: FontStyle.italic,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ),
                                  Container(
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'TOTAL',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              '\$${widget.total.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.accent,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (!widget.isPrefactura) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Pago: ${_getMethodLabel()}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              const SizedBox(),
                                            ],
                                          ),
                                          if (widget.cashAmount > 0)
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'Efectivo',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                Text(
                                                  '\$${widget.cashAmount.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          if (widget.transferAmount > 0)
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'Transferencia',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                Text(
                                                  '\$${widget.transferAmount.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          if (widget.change > 0)
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                const Text(
                                                  'Cambio',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.green,
                                                  ),
                                                ),
                                                Text(
                                                  '\$${widget.change.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.green,
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Vuelva pronto',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                fontStyle: FontStyle.italic,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green.shade300,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.chat,
                                        color: Colors.green.shade600,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Enviar por WhatsApp',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _whatsappController,
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      hintText: 'Número del cliente (opcional)',
                                      prefixText: '+',
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 10,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                          color: Colors.green,
                                          width: 2,
                                        ),
                                      ),
                                      suffixIcon: const Icon(
                                        Icons.phone,
                                        size: 20,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await _shareByWhatsApp();
                              },
                              icon: Icon(Icons.chat, color: Colors.white),
                              label: Text(
                                widget.isPrefactura
                                    ? 'Compartir por WhatsApp'
                                    : 'Compartir factura',
                                style: const TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (widget.isPrefactura)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final file = await _generatePdf();
                                  final label = widget.isPrefactura
                                      ? 'Prefactura'
                                      : 'Factura';
                                  await Share.shareXFiles(
                                    [XFile(file.path)],
                                    text:
                                        '$label - ${_businessName.isNotEmpty ? _businessName : "Mi Negocio"}',
                                  );
                                },
                                icon: Icon(
                                  Icons.share,
                                  color: AppColors.accent,
                                ),
                                label: Text(
                                  'Compartir de otra forma',
                                  style: TextStyle(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: AppColors.accent,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Icon(
                                widget.isPrefactura
                                    ? Icons.arrow_back
                                    : Icons.add_shopping_cart,
                                color: Colors.white,
                              ),
                              label: Text(
                                widget.isPrefactura
                                    ? 'Volver al carrito'
                                    : 'Nueva compra',
                                style: const TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
