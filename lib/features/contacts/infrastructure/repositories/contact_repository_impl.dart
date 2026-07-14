import '../../domain/entities/trusted_contact.dart';
import '../../domain/repositories/contact_repository.dart';
import '../datasources/contact_datasource.dart';

/// Implementation of [ContactRepository] backed by Drift.
class ContactRepositoryImpl extends ContactRepository {
  final ContactDatasource _datasource;

  ContactRepositoryImpl(this._datasource);

  @override
  Future<void> createContact(TrustedContact contact) =>
      _datasource.createContact(contact);

  @override
  Future<TrustedContact?> getContactById(String id) =>
      _datasource.getContactById(id);

  @override
  Future<List<TrustedContact>> getContacts({String? rol}) =>
      _datasource.getContacts(rol: rol);

  @override
  Future<List<String>> getActivePhonesForRole(String rol) =>
      _datasource.getActivePhonesForRole(rol);

  @override
  Future<void> updateContact(TrustedContact contact) =>
      _datasource.updateContact(contact);

  @override
  Future<void> toggleContactActive(String id, bool active) =>
      _datasource.toggleContactActive(id, active);

  @override
  Future<void> deleteContact(String id) =>
      _datasource.deleteContact(id);
}
