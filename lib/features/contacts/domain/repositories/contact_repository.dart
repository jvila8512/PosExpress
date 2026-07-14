import '../entities/trusted_contact.dart';

/// Abstract repository for trusted contacts.
abstract class ContactRepository {
  /// Create a new trusted contact.
  Future<void> createContact(TrustedContact contact);

  /// Get a contact by ID.
  Future<TrustedContact?> getContactById(String id);

  /// Get all contacts, optionally filtered by role.
  Future<List<TrustedContact>> getContacts({String? rol});

  /// Get active phone numbers for a role.
  Future<List<String>> getActivePhonesForRole(String rol);

  /// Update an existing contact.
  Future<void> updateContact(TrustedContact contact);

  /// Toggle contact active/inactive.
  Future<void> toggleContactActive(String id, bool active);

  /// Delete a contact.
  Future<void> deleteContact(String id);
}
