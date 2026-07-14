import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/features/clients/domain/entities/restaurant_client.dart';
import 'package:etecsa/features/clients/domain/repositories/client_repository.dart';
import 'package:etecsa/features/clients/infrastructure/datasources/client_datasource.dart';
import 'package:etecsa/features/clients/infrastructure/repositories/client_repository_impl.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _clientDatasourceProvider = Provider<ClientDatasource>((ref) {
  return ClientDatasource(AppDatabase.instance);
});

final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  return ClientRepositoryImpl(ref.watch(_clientDatasourceProvider));
});

final clientProvider = NotifierProvider<ClientNotifier, AsyncValue<List<RestaurantClient>>>(
  () => ClientNotifier(),
);

// ---------------------------------------------------------------------------
// Client Notifier
// ---------------------------------------------------------------------------

class ClientNotifier extends Notifier<AsyncValue<List<RestaurantClient>>> {
  ClientRepository get _repository => ref.read(clientRepositoryProvider);

  @override
  AsyncValue<List<RestaurantClient>> build() {
    return const AsyncValue.data([]);
  }

  /// Load all clients.
  Future<void> loadAll() async {
    state = const AsyncValue.loading();
    try {
      final clients = await _repository.getAllClients();
      state = AsyncValue.data(clients);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Search clients by query.
  Future<void> search(String query) async {
    state = const AsyncValue.loading();
    try {
      final clients = await _repository.searchClients(query);
      state = AsyncValue.data(clients);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Create a new client.
  Future<void> create(RestaurantClient client) async {
    try {
      await _repository.createClient(client);
      await loadAll();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Update an existing client.
  Future<void> update(RestaurantClient client) async {
    try {
      await _repository.updateClient(client);
      await loadAll();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Delete a client.
  Future<void> delete(String id) async {
    try {
      await _repository.deleteClient(id);
      await loadAll();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
