import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/features/shared/services/KeyValueStorageService.dart';

class ExpenseFormScreen extends StatefulWidget {
  final Expense? expense; // null = crear, !null = editar

  const ExpenseFormScreen({super.key, this.expense});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  static const List<String> expenseCategories = [
    'Transporte',
    'Alimentación',
    'Construcción/Reparaciones',
    'Inversiones (equipos, neveras)',
    'Pago a trabajadores',
    'Tributos',
    'Otros',
  ];

  static const Map<String, IconData> categoryIcons = {
    'Transporte': Icons.local_shipping,
    'Alimentación': Icons.restaurant,
    'Construcción/Reparaciones': Icons.build,
    'Inversiones (equipos, neveras)': Icons.kitchen,
    'Pago a trabajadores': Icons.people,
    'Tributos': Icons.account_balance,
    'Otros': Icons.category,
  };

  final _formKey = GlobalKey<FormState>();
  final _descriptionCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _selectedCategory = 'Transporte';
  late DateTime _expenseDate;
  String _paymentMethod = 'efectivo';
  bool _isSaving = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _expenseDate = DateTime.now();
    if (widget.expense != null) {
      _isEditing = true;
      _selectedCategory = widget.expense!.category;
      _descriptionCtrl.text = widget.expense!.description;
      _amountCtrl.text = widget.expense!.amount.toStringAsFixed(0);
      _expenseDate = widget.expense!.expenseDate;
      _paymentMethod = widget.expense!.paymentMethod ?? 'efectivo';
      _notesCtrl.text = widget.expense!.notes ?? '';
    }
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _categoryIcon(String cat) {
    final icon = categoryIcons[cat] ?? Icons.category;
    return String.fromCharCode(icon.codePoint);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _expenseDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final db = AppDatabase.instance;
      final storage = KeyValueStorageService();
      final userId = await storage.getValue('user_id');
      final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;

      if (_isEditing) {
        await db.updateExpense(
          id: widget.expense!.id,
          category: _selectedCategory,
          description: _descriptionCtrl.text.trim(),
          amount: amount,
          paymentMethod: _paymentMethod,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          expenseDate: _expenseDate,
        );
      } else {
        final id = 'EXP${DateTime.now().millisecondsSinceEpoch}';
        await db.createExpense(
          id: id,
          category: _selectedCategory,
          description: _descriptionCtrl.text.trim(),
          amount: amount,
          paymentMethod: _paymentMethod,
          registeredBy: userId,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          expenseDate: _expenseDate,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Gasto' : 'Nuevo Gasto'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Categoría
            Text('Categoría', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.7))),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              items: expenseCategories.map((cat) {
                final icon = categoryIcons[cat] ?? Icons.category;
                return DropdownMenuItem(
                  value: cat,
                  child: Row(
                    children: [
                      Icon(icon, size: 20, color: colors.primary),
                      const SizedBox(width: 10),
                      Text(cat),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedCategory = v);
              },
            ),
            const SizedBox(height: 16),

            // Descripción
            Text('Descripción', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.7))),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionCtrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Ej: Pasaje a La Habana, Compra de cemento...',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
            ),
            const SizedBox(height: 16),

            // Monto + Fecha en row
            Row(
              children: [
                // Monto
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Monto (\$)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.7))),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]+'))],
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixText: '\$ ',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Requerido';
                          final n = double.tryParse(v.replaceAll(',', '.'));
                          if (n == null || n <= 0) return 'Monto inválido';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Fecha
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fecha', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.7))),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(DateFormat('dd/MM/yyyy').format(_expenseDate)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Método de pago
            Text('Método de pago', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.7))),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              items: const [
                DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                DropdownMenuItem(value: 'transferencia', child: Text('Transferencia')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _paymentMethod = v);
              },
            ),
            const SizedBox(height: 16),

            // Notas
            Text('Notas (opcional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.7))),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Notas adicionales...',
                contentPadding: EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 32),

            // Botón guardar
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: Text(_isEditing ? 'Actualizar Gasto' : 'Guardar Gasto'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
