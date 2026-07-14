import '../../domain/entities/restaurant_client.dart';
import '../../domain/repositories/client_repository.dart';
import '../datasources/client_datasource.dart';

/// Implementation of [ClientRepository] backed by Drift.
class ClientRepositoryImpl extends ClientRepository {
  final ClientDatasource _datasource;

  ClientRepositoryImpl(this._datasource);

  @override
  Future<void> createClient(RestaurantClient client) =>
      _datasource.createClient(client);

  @override
  Future<RestaurantClient?> getClientById(String id) =>
      _datasource.getClientById(id);

  @override
  Future<List<RestaurantClient>> searchClients(String query) =>
      _datasource.searchClients(query);

  @override
  Future<List<RestaurantClient>> getAllClients() =>
      _datasource.getAllClients();

  @override
  Future<void> updateClient(RestaurantClient client) =>
      _datasource.updateClient(client);

  @override
  Future<void> deleteClient(String id) =>
      _datasource.deleteClient(id);
}
