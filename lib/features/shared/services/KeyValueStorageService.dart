import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeyValueStorageService {
  final storage = const FlutterSecureStorage();

  Future<void> setKeyValue<T>(String key, T value) async {
    await storage.write(key: key, value: value.toString());
  }

  Future<String?> getValue(String key) async {
    return await storage.read(key: key);
  }

  Future<void> removeKey(String key) async {
    await storage.delete(key: key);
  }
}