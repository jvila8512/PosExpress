import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:etecsa/config/theme/app_theme.dart';
import 'package:etecsa/core/services/pagoxmovil_sms_parser.dart';

class PaymentScreen extends StatefulWidget {
  final double total;
  final VoidCallback onPaymentComplete;

  const PaymentScreen({
    super.key,
    required this.total,
    required this.onPaymentComplete,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _paymentMethod = 'efectivo';

  // Efectivo
  final _efectivoController = TextEditingController();
  // Transferencia
  final _transferController = TextEditingController(text: '0');
  // Transfer data
  final _bankController = TextEditingController();
  final _txIdController = TextEditingController();
  final _purchaseIdController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  final _clientCIController = TextEditingController();
  final _transferDateController = TextEditingController();

  String? _rawSms;
  String? _smsFormatInfo;

  @override
  void initState() {
    super.initState();
    _efectivoController.text = widget.total.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _efectivoController.dispose();
    _transferController.dispose();
    _bankController.dispose();
    _txIdController.dispose();
    _purchaseIdController.dispose();
    _clientNameController.dispose();
    _clientPhoneController.dispose();
    _clientCIController.dispose();
    _transferDateController.dispose();
    super.dispose();
  }

  double get _efectivo => double.tryParse(_efectivoController.text) ?? 0;
  double get _transferAmount => double.tryParse(_transferController.text) ?? 0;

  double get _efectivoFinal {
    if (_paymentMethod == 'efectivo') return _efectivo;
    if (_paymentMethod == 'ambos') return _efectivo;
    return 0;
  }

  double get _transferFinal {
    if (_paymentMethod == 'transferencia') return _transferAmount;
    if (_paymentMethod == 'ambos') return _transferAmount;
    return 0;
  }

  double get _cambio {
    if (_paymentMethod == 'efectivo') return _efectivo > widget.total ? _efectivo - widget.total : 0;
    if (_paymentMethod == 'ambos') return _efectivo > (widget.total - _transferAmount) ? _efectivo - (widget.total - _transferAmount) : 0;
    return 0;
  }

  double get _falta {
    final pagado = _efectivoFinal + _transferFinal;
    // Usar tolerancia de 0.01 para evitar problemas de precisión floating point
    // Ejemplo: 1.11 × 100 = 11.100000000000001 en memoria, parseamos 11.10 → falta = 0.000000001
    return (widget.total - pagado) > 0.01 ? widget.total - pagado : 0;
  }

  bool get _isFullPayment {
    final pagado = _efectivoFinal + _transferFinal;
    // Usar tolerancia de 0.01 para evitar problemas de precisión floating point
    if ((widget.total - pagado) > 0.01) return false;
    if (_paymentMethod == 'ambos' && (_efectivoFinal <= 0 || _transferFinal <= 0)) return false;
    return true;
  }

  /// Returns an error message if the transfer amount doesn't match what's expected.
  /// Null = no error (amount is valid).
  String? get _transferAmountError {
    if (_paymentMethod == 'efectivo') return null; // no transfer in efectivo mode
    if (_transferAmount <= 0) return null; // no amount entered yet

    if (_paymentMethod == 'transferencia') {
      // Transfer must cover the FULL total
      if (_transferAmount > widget.total) {
        return 'El monto (\$${_transferAmount.toStringAsFixed(2)}) supera el total (\$${widget.total.toStringAsFixed(2)})';
      }
      if (_transferAmount < widget.total) {
        return 'El monto (\$${_transferAmount.toStringAsFixed(2)}) es menor al total (\$${widget.total.toStringAsFixed(2)})';
      }
    } else if (_paymentMethod == 'ambos') {
      // In "ambos", transfer can be partial but can't exceed the total
      if (_transferAmount > widget.total) {
        return 'La transferencia (\$${_transferAmount.toStringAsFixed(2)}) supera el total (\$${widget.total.toStringAsFixed(2)})';
      }
    }
    return null;
  }

  void _selectMethod(String method) {
    setState(() {
      _paymentMethod = method;
      if (method == 'efectivo') {
        _efectivoController.text = widget.total.toStringAsFixed(2);
        _transferController.text = '0';
      } else if (method == 'transferencia') {
        _transferController.text = widget.total.toStringAsFixed(2);
        _efectivoController.text = '0';
      } else {
        _efectivoController.clear();
        _transferController.clear();
      }
    });
  }

  Future<void> _pasteSms() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null) {
      final parsed = PagoXMovilSmsParser.parse(clipboardData!.text!);
      if (parsed != null) {
        setState(() {
          _rawSms = parsed.rawSms;
          _smsFormatInfo = parsed.formatDescription;
          if (parsed.transactionId != null) _txIdController.text = parsed.transactionId!;
          if (parsed.purchaseId != null) _purchaseIdController.text = parsed.purchaseId!;
          if (parsed.clientPhone != null) _clientPhoneController.text = parsed.clientPhone!;
          if (parsed.transferDate != null) _transferDateController.text = parsed.transferDate!;
          if (parsed.amount != null) _transferController.text = parsed.amount!.toStringAsFixed(2);
          if (parsed.clientName != null) _clientNameController.text = parsed.clientName!;
          if (parsed.clientCI != null) _clientCIController.text = parsed.clientCI!;
          // Poner tipo de transferencia en campo Banco
          _bankController.text = parsed.transferType;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('SMS detectado: ${parsed.formatDescription}'), backgroundColor: Colors.purple),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se detectó un SMS de PAGOxMOVIL válido'), backgroundColor: Colors.orange),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El portapapeles está vacío'), backgroundColor: Colors.grey),
        );
      }
    }
  }

  void _confirm() {
    Navigator.pop(context, _buildResult());
  }

  Map<String, dynamic>? _buildResult() {
    if (!_isFullPayment) return null;
    return {
      'method': _paymentMethod,
      'cashAmount': _efectivoFinal,
      'transferAmount': _transferFinal,
      'reference': '', // kept in model but hidden from UI
      'bank': _bankController.text.isNotEmpty ? _bankController.text : null,
      'transactionId': _txIdController.text.isNotEmpty ? _txIdController.text : null,
      'purchaseId': _purchaseIdController.text.isNotEmpty ? _purchaseIdController.text : null,
      'clientName': _clientNameController.text.isNotEmpty ? _clientNameController.text : null,
      'clientPhone': _clientPhoneController.text.isNotEmpty ? _clientPhoneController.text : null,
      'clientCI': _clientCIController.text.isNotEmpty ? _clientCIController.text : null,
      'transferDate': _transferDateController.text.isNotEmpty ? _transferDateController.text : null,
      'rawSms': _rawSms,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Seguir Comprando',
        ),
        title: const Text('Cobrar'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '\$${widget.total.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // === MÉTODO DE PAGO ===
                  Text('Método de pago', style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(children: [
                    _buildMethodButton('Efectivo', _paymentMethod == 'efectivo', () => _selectMethod('efectivo')),
                    const SizedBox(width: 8),
                    _buildMethodButton('Transf.', _paymentMethod == 'transferencia', () => _selectMethod('transferencia')),
                    const SizedBox(width: 8),
                    _buildMethodButton('Ambos', _paymentMethod == 'ambos', () => _selectMethod('ambos')),
                  ]),
                  const SizedBox(height: 20),

                  // === DATOS DEL CLIENTE (siempre visibles, opcionales) ===
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person_outline, color: Colors.blue.shade700, size: 18),
                            const SizedBox(width: 6),
                            Text('Datos del cliente (opcional)',
                                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue.shade700, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _clientNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'Nombre del cliente',
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: const Icon(Icons.person, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _clientPhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Celular del cliente',
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: const Icon(Icons.phone, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // === EFECTIVO ===
                  if (_paymentMethod == 'efectivo' || _paymentMethod == 'ambos') ...[
                    TextField(
                      controller: _efectivoController,
                      keyboardType: TextInputType.number,
                      autofocus: _paymentMethod != 'transferencia',
                      decoration: InputDecoration(
                        labelText: 'Efectivo',
                        prefixText: '\$ ',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_cambio > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Cambio: \$${_cambio.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    const SizedBox(height: 16),
                  ],

                  // === TRANSFERENCIA ===
                  if (_paymentMethod == 'transferencia' || _paymentMethod == 'ambos') ...[
              TextField(
              controller: _transferController,
              keyboardType: TextInputType.number,
              autofocus: _paymentMethod == 'transferencia',
              decoration: InputDecoration(
                labelText: 'Monto Transferencia',
                prefixText: '\$ ',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                errorText: _transferAmountError,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

                    // --- Panel Datos de Transferencia ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header con botón Pegar SMS
                          Row(
                            children: [
                              Icon(Icons.swap_horiz, color: Colors.purple.shade700, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Datos de Transferencia',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple.shade700, fontSize: 15)),
                              ),
                              ElevatedButton.icon(
                                onPressed: _pasteSms,
                                icon: const Icon(Icons.content_paste, size: 18),
                                label: const Text('Pegar SMS'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                          if (_smsFormatInfo != null) ...[
                            const SizedBox(height: 4),
                            Text('Formato: $_smsFormatInfo',
                                style: TextStyle(fontSize: 11, color: Colors.purple.shade600, fontStyle: FontStyle.italic)),
                          ],
                          const SizedBox(height: 12),

                          // Banco
                          TextField(
                            controller: _bankController,
                            decoration: InputDecoration(
                              labelText: 'Tipo/Banco',
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // No. Transacción
                          TextField(
                            controller: _txIdController,
                            decoration: InputDecoration(
                              labelText: 'No. Transacción',
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Id Compra
                          TextField(
                            controller: _purchaseIdController,
                            decoration: InputDecoration(
                              labelText: 'Id Compra',
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Fecha transferencia
                          TextField(
                            controller: _transferDateController,
                            decoration: InputDecoration(
                              labelText: 'Fecha transferencia',
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // CI del cliente (solo en transferencias)
                          TextField(
                            controller: _clientCIController,
                            decoration: InputDecoration(
                              labelText: 'CI del cliente',
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: const Icon(Icons.badge, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 10),

                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),

                  // === RESUMEN (solo Ambos) ===
                  if (_paymentMethod == 'ambos') ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isFullPayment ? Colors.green.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _isFullPayment ? Colors.green.shade200 : Colors.orange.shade200),
                      ),
                      child: Column(children: [
                        if (_efectivoFinal > 0) Text('Efectivo: \$${_efectivoFinal.toStringAsFixed(2)}'),
                        if (_transferFinal > 0) Text('Transferencia: \$${_transferFinal.toStringAsFixed(2)}'),
                        if (_cambio > 0) Text('Cambio: \$${_cambio.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        if (_falta > 0) Text('Falta: \$${_falta.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        Text('Total: \$${(_efectivoFinal + _transferFinal).toStringAsFixed(2)}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: _isFullPayment ? Colors.green : Colors.orange)),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // === BOTÓN CONFIRMAR FIJO ABAJO ===
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_falta > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('Falta: \$${_falta.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                child: ElevatedButton(
                  onPressed: (_isFullPayment && _transferAmountError == null) ? _confirm : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.colorMorado,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      child: const Text('CONFIRMAR'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodButton(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppTheme.colorCeleste : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
            border: selected ? null : Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
