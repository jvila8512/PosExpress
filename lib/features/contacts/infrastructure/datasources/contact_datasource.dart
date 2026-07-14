import 'package:drift/drift.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/features/contacts/domain/entities/trusted_contact.dart' as domain;

/// Drift datasource for trusted contacts.
class ContactDatasource {
  final AppDatabase _db;

  ContactDatasource(this._db);

  Future<void> createContact(domain.TrustedContact contact) async {
    await _db.into(_db.trustedContacts).insert(
      TrustedContactsCompanion.insert(
        id: contact.id,
        rol: contact.rol,
        usuarioId: contact.usuarioId,
        numeroTelefono: contact.numeroTelefono,
        activo: contact.activo,
      ),
    );
  }

  Future<domain.TrustedContact?> getContactById(String id) async {
    final row = await (_db.select(_db.trustedContacts)
          ..where((c) => c.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return _mapRow(row);
  }

  Future<List<domain.TrustedContact>> getContacts({String? rol}) async {
    final query = _db.select(_db.trustedContacts);
    if (rol != null) {
      query.where((c) => c.rol.equals(rol));
    }
    final rows = await query.get();
    return rows.map(_mapRow).toList();
  }

  Future<List<String>> getActivePhonesForRole(String rol) async {
    final rows = await (_db.select(_db.trustedContacts)
          ..where((c) => c.rol.equals(rol) & c.activo.equals(true)))
        .get();
    return rows.map((r) => r.numeroTelefono).toList();
  }

  Future<void> updateContact(domain.TrustedContact contact) async {
    await (_db.update(_db.trustedContacts)
          ..where((c) => c.id.equals(contact.id)))
        .write(TrustedContactsCompanion(
          rol: Value(contact.rol),
          usuarioId: Value(contact.usuarioId),
          numeroTelefono: Value(contact.numeroTelefono),
          activo: Value(contact.activo),
        ));
  }

  Future<void> toggleContactActive(String id, bool active) async {
    await (_db.update(_db.trustedContacts)
          ..where((c) => c.id.equals(id)))
        .write(TrustedContactsCompanion(
          activo: Value(active),
        ));
  }

  Future<void> deleteContact(String id) async {
    await (_db.delete(_db.trustedContacts)
          ..where((c) => c.id.equals(id)))
        .go();
  }

  domain.TrustedContact _mapRow(TrustedContactRow row) {
    return domain.TrustedContact(
      id: row.id,
      rol: row.rol,
      usuarioId: row.usuarioId,
      numeroTelefono: row.numeroTelefono,
      activo: row.activo,
    );
  }
}
