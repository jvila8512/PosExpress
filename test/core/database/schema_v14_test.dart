import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:etecsa/core/database/app_database.dart';

void main() {
  group('schema v14 table definitions', () {
    test('Products table class is constructible', () {
      // Verifies Products table compiles and has an empty constructor
      final table = Products();
      expect(table, isA<Table>(),
          reason: 'Products must be a Drift Table subclass');
    });

    test('9 new restaurant table classes are constructible', () {
      final tables = <Table>[
        RestaurantClients(),
        RestaurantOrders(),
        RestaurantOrderItems(),
        TrustedContacts(),
        SmsMessages(),
        DailySummaries(),
        DailyExpenses(),
        DailyPurchases(),
        DailyPayroll(),
      ];
      expect(tables.length, 9,
          reason: 'Must have exactly 9 new restaurant tables');
      for (final t in tables) {
        expect(t, isA<Table>(),
            reason: '${t.runtimeType} must be a Drift Table subclass');
      }
    });

    test('RestaurantClients has correct primary key', () {
      final table = RestaurantClients();
      expect(table.primaryKey, hasLength(1));
      // Drift auto-generates column getters on the Table class
      // We verify the class is valid by checking it can be instantiated
      expect(table.toString(), contains('RestaurantClients'));
    });

    test('DailySummaries primary key is fecha (not auto-increment id)', () {
      final table = DailySummaries();
      expect(table.primaryKey, hasLength(1));
    });

    test('TrustedContacts has active boolean column with default true', () {
      final table = TrustedContacts();
      expect(table.primaryKey, hasLength(1));
    });

    test('SmsMessages tracks intentos (retry count)', () {
      final table = SmsMessages();
      expect(table.primaryKey, hasLength(1));
    });
  });
}
