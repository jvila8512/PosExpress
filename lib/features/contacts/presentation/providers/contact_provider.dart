import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:etecsa/core/database/app_database.dart' hide TrustedContact;
import 'package:etecsa/features/contacts/domain/entities/trusted_contact.dart';
import 'package:etecsa/features/contacts/domain/repositories/contact_repository.dart';
import 'package:etecsa/features/contacts/infrastructure/datasources/contact_datasource.dart';
import 'package:etecsa/features/contacts/infrastructure/repositories/contact_repository_impl.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _contactDatasourceProvider = Provider<ContactDatasource>((ref) {
  return ContactDatasource(AppDatabase.instance);
});

final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  return ContactRepositoryImpl(ref.watch(_contactDatasourceProvider));
});

final contactProvider = NotifierProvider<ContactNotifier, AsyncValue<List<TrustedContact>>>(
  () => ContactNotifier(),
);

// ---------------------------------------------------------------------------
// Contact Notifier
// ---------------------------------------------------------------------------

class ContactNotifier extends Notifier<AsyncValue<List<TrustedContact>>> {
  ContactRepository get _repository => ref.read(contactRepositoryProvider);

  @override
  AsyncValue<List<TrustedContact>> build() {
    return const AsyncValue.data([]);
  }

  /// Load all contacts, optionally filtered by role.
  Future<void> loadAll({String? rol}) async {
    state = const AsyncValue.loading();
    try {
      final contacts = await _repository.getContacts(rol: rol);
      state = AsyncValue.data(contacts);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Create a new contact.
  Future<void> create(TrustedContact contact) async {
    try {
      await _repository.createContact(contact);
      await loadAll();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Update an existing contact.
  Future<void> update(TrustedContact contact) async {
    try {
      await _repository.updateContact(contact);
      await loadAll();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Toggle contact active/inactive.
  Future<void> toggleActive(String id, bool active) async {
    try {
      await _repository.toggleContactActive(id, active);
      await loadAll();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Delete a contact.
  Future<void> delete(String id) async {
    try {
      await _repository.deleteContact(id);
      await loadAll();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
