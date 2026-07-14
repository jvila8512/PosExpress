import '../entities/restaurant_client.dart';

/// Abstract repository for restaurant clients.
abstract class ClientRepository {
  /// Create a new client.
  Future<void> createClient(RestaurantClient client);

  /// Get a client by ID.
  Future<RestaurantClient?> getClientById(String id);

  /// Search clients by name or phone (partial matching).
  Future<List<RestaurantClient>> searchClients(String query);

  /// Get all clients, ordered by most recent first.
  Future<List<RestaurantClient>> getAllClients();

  /// Update an existing client.
  Future<void> updateClient(RestaurantClient client);

  /// Soft-delete a client.
  Future<void> deleteClient(String id);
}
