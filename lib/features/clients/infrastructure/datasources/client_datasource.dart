import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/features/clients/domain/entities/restaurant_client.dart';

/// Drift datasource for restaurant clients.
class ClientDatasource {
  final AppDatabase _db;

  ClientDatasource(this._db);

  Future<void> createClient(RestaurantClient client) async {
    await _db.into(_db.restaurantClients).insert(
      RestaurantClientsCompanion.insert(
        id: client.id,
        nombre: client.nombre,
        telefono: client.telefono,
        direccion: Value(client.direccion),
        referencia: Value(client.referencia),
        notas: Value(client.notas),
      ),
    );
  }

  Future<RestaurantClient?> getClientById(String id) async {
    final row = await (_db.select(_db.restaurantClients)
          ..where((c) => c.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return _mapRow(row);
  }

  Future<List<RestaurantClient>> searchClients(String query) async {
    final term = '%$query%';
    final rows = await (_db.select(_db.restaurantClients)
          ..where((c) =>
              c.nombre.like(term) | c.telefono.like(term))
          ..orderBy([(c) => OrderingTerm.desc(c.fechaRegistro)]))
        .get();
    return rows.map(_mapRow).toList();
  }

  Future<List<RestaurantClient>> getAllClients() async {
    final rows = await (_db.select(_db.restaurantClients)
          ..orderBy([(c) => OrderingTerm.desc(c.fechaRegistro)]))
        .get();
    return rows.map(_mapRow).toList();
  }

  Future<void> updateClient(RestaurantClient client) async {
    await (_db.update(_db.restaurantClients)
          ..where((c) => c.id.equals(client.id)))
        .write(RestaurantClientsCompanion(
          nombre: Value(client.nombre),
          telefono: Value(client.telefono),
          direccion: Value(client.direccion),
          referencia: Value(client.referencia),
          notas: Value(client.notas),
        ));
  }

  Future<void> deleteClient(String id) async {
    await (_db.delete(_db.restaurantClients)
          ..where((c) => c.id.equals(id)))
        .go();
  }

  RestaurantClient _mapRow(RestaurantClientRow row) {
    return RestaurantClient(
      id: row.id,
      nombre: row.nombre,
      telefono: row.telefono,
      direccion: row.direccion,
      referencia: row.referencia,
      notas: row.notas,
      fechaRegistro: row.fechaRegistro,
    );
  }
}
