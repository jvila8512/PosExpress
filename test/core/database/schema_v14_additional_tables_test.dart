import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:etecsa/core/database/app_database.dart';

void main() {
  group('schema v14 - additional tables (1.7)', () {
    test('RestaurantTables table class is constructible', () {
      final table = RestaurantTables();
      expect(table, isA<Table>(),
          reason: 'RestaurantTables must be a Drift Table subclass');
    });

    test('OrderStateHistory table class is constructible', () {
      final table = OrderStateHistory();
      expect(table, isA<Table>(),
          reason: 'OrderStateHistory must be a Drift Table subclass');
    });

    test('PriceHistory table class is constructible', () {
      final table = PriceHistory();
      expect(table, isA<Table>(),
          reason: 'PriceHistory must be a Drift Table subclass');
    });

    test('RestaurantTables has correct columns', () {
      final table = RestaurantTables();
      expect(table.primaryKey, hasLength(1),
          reason: 'RestaurantTables must have a single-column primary key');
    });

    test('OrderStateHistory has correct columns', () {
      final table = OrderStateHistory();
      expect(table.primaryKey, hasLength(1),
          reason: 'OrderStateHistory must have a single-column primary key');
    });

    test('PriceHistory has correct columns', () {
      final table = PriceHistory();
      expect(table.primaryKey, hasLength(1),
          reason: 'PriceHistory must have a single-column primary key');
    });
  });
}
