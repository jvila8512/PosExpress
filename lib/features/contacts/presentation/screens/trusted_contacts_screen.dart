import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/core/database/app_database.dart' hide TrustedContact;
import 'package:etecsa/features/contacts/domain/entities/trusted_contact.dart';
import 'package:etecsa/features/contacts/presentation/providers/contact_provider.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';

// ---------------------------------------------------------------------------
// Trusted Contacts Screen
// ---------------------------------------------------------------------------
///
/// List of trusted contacts grouped by role.
/// Each contact shows phone number, associated user, and active toggle.
/// Supports add, toggle active, and delete with confirmation.

class TrustedContactsScreen extends ConsumerStatefulWidget {
  const TrustedContactsScreen({super.key});

  @override
  ConsumerState<TrustedContactsScreen> createState() =>
      _TrustedContactsScreenState();
}

class _TrustedContactsScreenState
    extends ConsumerState<TrustedContactsScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  List<User> _users = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(contactProvider.notifier).loadAll();
      _loadUsers();
    });
  }

  Future<void> _loadUsers() async {
    try {
      final db = AppDatabase.instance;
      final users = await db.getAllUsers();
      if (mounted) {
        setState(() => _users = users);
      }
    } catch (_) {}
  }

  Future<void> _onRefresh() async {
    await ref.read(contactProvider.notifier).loadAll();
    await _loadUsers();
  }

  static const _roleLabels = {
    'redes': 'Redes',
    'cocina': 'Cocina',
    'domicilio': 'Domicilio',
    'admin': 'Admin',
    'mesero': 'Mesero',
  };

  static const _roleIcons = {
    'redes': Icons.share,
    'cocina': Icons.restaurant,
    'domicilio': Icons.delivery_dining,
    'admin': Icons.admin_panel_settings,
    'mesero': Icons.room_service,
  };

  String _roleLabel(String rol) => _roleLabels[rol] ?? rol;
  IconData _roleIcon(String rol) => _roleIcons[rol] ?? Icons.person;

  Future<void> _showAddContactDialog() async {
    String? selectedRol;
    String? selectedUserId;
    final phoneController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Agregar Contacto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Role selector
                DropdownButtonFormField<String>(
                  value: selectedRol,
                  decoration: const InputDecoration(
                    labelText: 'Rol *',
                    prefixIcon: Icon(Icons.badge, size: 20),
                    isDense: true,
                  ),
                  items: _roleLabels.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedRol = v),
                ),
                const SizedBox(height: 12),

                // User selector
                DropdownButtonFormField<String>(
                  value: selectedUserId,
                  decoration: const InputDecoration(
                    labelText: 'Usuario *',
                    prefixIcon: Icon(Icons.person, size: 20),
                    isDense: true,
                  ),
                  items: _users
                      .map((u) => DropdownMenuItem(
                            value: u.id,
                            child: Text(u.fullName.isNotEmpty
                                ? u.fullName
                                : u.username),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedUserId = v),
                ),
                const SizedBox(height: 12),

                // Phone
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono *',
                    prefixIcon: Icon(Icons.phone, size: 20),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (selectedRol == null ||
                    selectedUserId == null ||
                    phoneController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Completá todos los campos')),
                  );
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      final contact = TrustedContact(
        id: const Uuid().v4(),
        rol: selectedRol!,
        usuarioId: selectedUserId!,
        numeroTelefono: phoneController.text.trim(),
        activo: true,
      );
      await ref.read(contactProvider.notifier).create(contact);
    }

    phoneController.dispose();
  }

  Future<void> _confirmDelete(TrustedContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar contacto'),
        content: Text(
            '¿Eliminar contacto ${contact.numeroTelefono}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(contactProvider.notifier).delete(contact.id);
    }
  }

  String _userName(String userId) {
    return _users
            .where((u) => u.id == userId)
            .firstOrNull
            ?.fullName ??
        userId;
  }

  // ─────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.forBrightness(Theme.of(context).brightness);
    final theme = Theme.of(context);
    final contactsAsync = ref.watch(contactProvider);

    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Contactos de Confianza'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddContactDialog,
        child: const Icon(Icons.add),
      ),
      body: contactsAsync.when(
        data: (contacts) =>
            _buildBody(contacts, colors, theme),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    size: 48, color: colors.danger),
                const SizedBox(height: 16),
                Text('Error: $e',
                    style: theme.textTheme.bodyMedium),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _onRefresh,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(List<TrustedContact> contacts,
      AppColorsTheme colors, ThemeData theme) {
    // Group by role
    final grouped = <String, List<TrustedContact>>{};
    for (final c in contacts) {
      grouped.putIfAbsent(c.rol, () => []);
      grouped[c.rol]!.add(c);
    }

    // Role display order
    final roleOrder = ['redes', 'cocina', 'domicilio', 'admin', 'mesero'];

    if (contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.contact_phone_outlined,
                size: 64,
                color: colors.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('No hay contactos de confianza',
                style: theme.textTheme.titleLarge
                    ?.copyWith(color: colors.textSecondary)),
            const SizedBox(height: 8),
            Text(
              'Agregá contactos desde el botón +',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          for (final rol in roleOrder)
            if (grouped.containsKey(rol)) ...[
              _buildRoleHeader(
                  rol, grouped[rol]!.length, colors, theme),
              ...grouped[rol]!.map(
                (c) => _buildContactCard(c, colors, theme),
              ),
            ],
          // Remaining roles not in order
          for (final entry in grouped.entries)
            if (!roleOrder.contains(entry.key)) ...[
              _buildRoleHeader(entry.key, entry.value.length,
                  colors, theme),
              ...entry.value.map(
                (c) => _buildContactCard(c, colors, theme),
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildRoleHeader(String rol, int count,
      AppColorsTheme colors, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Icon(_roleIcon(rol), size: 18, color: colors.accent),
          const SizedBox(width: 8),
          Text(
            _roleLabel(rol),
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(TrustedContact contact,
      AppColorsTheme colors, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.phone,
                          size: 14, color: colors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        contact.numeroTelefono,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: contact.activo
                              ? colors.textPrimary
                              : colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 12, color: colors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        _userName(contact.usuarioId),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: contact.activo
                              ? colors.textSecondary
                              : colors.textSecondary
                                  .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Active toggle
            Switch(
              value: contact.activo,
              onChanged: (v) => ref
                  .read(contactProvider.notifier)
                  .toggleActive(contact.id, v),
            ),

            // Delete
            IconButton(
              icon: Icon(Icons.delete,
                  size: 18, color: colors.danger.withValues(alpha: 0.7)),
              onPressed: () => _confirmDelete(contact),
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}
