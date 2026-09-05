import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/features/clients/domain/entities/restaurant_client.dart';
import 'package:etecsa/features/clients/presentation/providers/client_provider.dart';
import 'package:etecsa/features/orders/presentation/providers/order_provider.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';

// ---------------------------------------------------------------------------
// Client Management Screen
// ---------------------------------------------------------------------------
///
/// Searchable list of clients with create/edit via dialog.
/// Shows name, phone, address, reference, and order count.

class ClientManagementScreen extends ConsumerStatefulWidget {
  const ClientManagementScreen({super.key});

  @override
  ConsumerState<ClientManagementScreen> createState() =>
      _ClientManagementScreenState();
}

class _ClientManagementScreenState
    extends ConsumerState<ClientManagementScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(clientProvider.notifier).loadAll();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await ref.read(clientProvider.notifier).loadAll();
  }

  void _onSearch(String query) {
    if (query.trim().isEmpty) {
      ref.read(clientProvider.notifier).loadAll();
    } else {
      ref.read(clientProvider.notifier).search(query);
    }
  }

  Future<void> _showClientDialog({RestaurantClient? client}) async {
    final nameController =
        TextEditingController(text: client?.nombre ?? '');
    final phoneController =
        TextEditingController(text: client?.telefono ?? '');
    final addressController =
        TextEditingController(text: client?.direccion ?? '');
    final referenceController =
        TextEditingController(text: client?.referencia ?? '');
    final notesController =
        TextEditingController(text: client?.notas ?? '');
    final isEditing = client != null;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Editar Cliente' : 'Nuevo Cliente'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  prefixIcon: Icon(Icons.person_outline, size: 20),
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono *',
                  prefixIcon: Icon(Icons.phone, size: 20),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Dirección',
                  prefixIcon: Icon(Icons.location_on, size: 20),
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: referenceController,
                decoration: const InputDecoration(
                  labelText: 'Referencia',
                  prefixIcon: Icon(Icons.notes, size: 20),
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notas',
                  prefixIcon: Icon(Icons.comment, size: 20),
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
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
            onPressed: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              if (name.isEmpty || phone.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text('Nombre y teléfono son requeridos')),
                );
                return;
              }
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final name = nameController.text.trim();
      final phone = phoneController.text.trim();
      final address = addressController.text.trim();
      final reference = referenceController.text.trim();
      final notes = notesController.text.trim();

      if (isEditing) {
        await ref.read(clientProvider.notifier).update(
              client!.copyWith(
                nombre: name,
                telefono: phone,
                direccion: address.isEmpty ? null : address,
                referencia: reference.isEmpty ? null : reference,
                notas: notes.isEmpty ? null : notes,
              ),
            );
      } else {
        await ref.read(clientProvider.notifier).create(
              RestaurantClient(
                id: const Uuid().v4(),
                nombre: name,
                telefono: phone,
                direccion: address.isEmpty ? null : address,
                referencia: reference.isEmpty ? null : reference,
                notas: notes.isEmpty ? null : notes,
              ),
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                isEditing ? 'Cliente actualizado' : 'Cliente creado'),
          ),
        );
      }
    }

    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    referenceController.dispose();
    notesController.dispose();
  }

  Future<void> _confirmDelete(RestaurantClient client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cliente'),
        content: Text('¿Eliminar a "${client.nombre}"?'),
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
      await ref.read(clientProvider.notifier).delete(client.id);
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.forBrightness(Theme.of(context).brightness);
    final theme = Theme.of(context);
    final clientsAsync = ref.watch(clientProvider);

    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Clientes'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showClientDialog(),
        child: const Icon(Icons.add),
      ),
      body: clientsAsync.when(
        data: (clients) => _buildBody(clients, colors, theme),
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

  Widget _buildBody(List<RestaurantClient> clients,
      AppColorsTheme colors, ThemeData theme) {
    return Column(
      children: [
        // Search
        Container(
          padding: const EdgeInsets.all(12),
          color: colors.surface,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o teléfono...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 10, horizontal: 12),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearch('');
                      },
                    )
                  : null,
            ),
            onChanged: _onSearch,
          ),
        ),
        // Count
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '${clients.length} clientes',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
        // List
        Expanded(
          child: clients.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline,
                          size: 64,
                          color: colors.textSecondary
                              .withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text('No hay clientes',
                          style: theme.textTheme.titleLarge?.copyWith(
                              color: colors.textSecondary)),
                      const SizedBox(height: 8),
                      Text(
                        'Agregá clientes desde el botón +',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.textSecondary),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.only(bottom: 80),
                    itemCount: clients.length,
                    itemBuilder: (context, index) =>
                        _buildClientCard(
                            clients[index], colors, theme),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildClientCard(RestaurantClient client,
      AppColorsTheme colors, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showClientDialog(client: client),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    client.nombre.isNotEmpty
                        ? client.nombre[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.bungee(
                      fontSize: 18,
                      color: colors.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.nombre,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.phone,
                            size: 12,
                            color: colors.textSecondary),
                        const SizedBox(width: 4),
                        Text(client.telefono,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(
                                    color: colors.textSecondary)),
                      ],
                    ),
                    if (client.direccion != null &&
                        client.direccion!.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        client.direccion!,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Actions
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit,
                        size: 18, color: colors.textSecondary),
                    onPressed: () =>
                        _showClientDialog(client: client),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 32, minHeight: 32),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete,
                        size: 18, color: colors.danger),
                    onPressed: () => _confirmDelete(client),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
