import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.instance;
  ref.onDispose(() => db.close());
  return db;
});

final isFirstTimeSetupProvider = FutureProvider<bool>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.isFirstTimeSetup();
});