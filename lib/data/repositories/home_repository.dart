import 'package:etecsa/core/database/app_database.dart';

/// Repository for Home Dashboard data
class HomeRepository {
  final AppDatabase _db = AppDatabase.instance;

  // =====================
  // KPI Data
  // =====================

  /// Get today's sales total
  Future<double> getTodaySales() async {
    return await _db.getTodaySales();
  }

  /// Get yesterday's sales for comparison
  Future<double> getYesterdaySales() async {
    return await _db.getYesterdaySales();
  }

  /// Get transaction count for today
  Future<int> getTodayTransactionCount() async {
    return await _db.getTodayTransactionCount();
  }

  /// Get monthly average for comparison
  Future<double> getMonthlyAverageSales() async {
    return await _db.getMonthlyAverageSales();
  }

  /// Get monthly average transaction count per day
  Future<double> getMonthlyAverageTransactions() async {
    return await _db.getMonthlyAverageTransactions();
  }

  /// Get today's profit
  Future<double> getTodayProfit() async {
    return await _db.getTodayProfit();
  }

  /// Get today's average ticket
  Future<double> getTodayAverageTicket() async {
    return await _db.getTodayAverageTicket();
  }

  // =====================
  // Chart Data
  // =====================

  /// Get daily sales for current month (for bar chart)
  Future<Map<int, double>> getDailySalesThisMonth() async {
    return await _db.getDailySalesThisMonth();
  }

  /// Get payment methods breakdown for today (for donut chart)
  Future<Map<String, double>> getTodayPaymentMethods() async {
    return await _db.getTodayPaymentMethods();
  }

  /// Get top 5 products for today
  Future<List<Map<String, dynamic>>> getTopProductsToday({int limit = 5}) async {
    return await _db.getTopProductsToday(limit: limit);
  }

  // =====================
  // Alerts
  // =====================

  /// Get out of stock products that were sold in last 7 days
  Future<List<Map<String, dynamic>>> getOutOfStockAlerts() async {
    return await _db.getOutOfStockAlerts();
  }

  /// Get critical stock alerts (less than 5 units)
  Future<List<Map<String, dynamic>>> getCriticalStockAlerts() async {
    return await _db.getCriticalStockAlerts();
  }

  /// Get cash difference alerts
  Future<List<Map<String, dynamic>>> getCashDifferenceAlerts() async {
    return await _db.getCashDifferenceAlerts();
  }

  /// Get low sales alert (if sales < 40% of average)
  Future<Map<String, dynamic>?> getLowSalesAlert() async {
    return await _db.getLowSalesAlert();
  }

  /// Get high sales alert (if sales > 130% of average)
  Future<Map<String, dynamic>?> getHighSalesAlert() async {
    return await _db.getHighSalesAlert();
  }

  // =====================
  // Session
  // =====================

  /// Get active session (cash box open)
  Future<Session?> getActiveSession() async {
    return await _db.getActiveSession();
  }

  // =====================
  // Combined Home Data
  // =====================

  /// Load all home data at once for performance
  Future<Map<String, dynamic>> loadHomeData() async {
    final results = await Future.wait([
      getTodaySales(),
      getYesterdaySales(),
      getTodayTransactionCount(),
      getMonthlyAverageSales(),
      getMonthlyAverageTransactions(),
      getTodayProfit(),
      getTodayAverageTicket(),
      getDailySalesThisMonth(),
      getTodayPaymentMethods(),
      getTopProductsToday(),
      getActiveSession(),
      Future.wait([
        getOutOfStockAlerts(),
        getCriticalStockAlerts(),
        getCashDifferenceAlerts(),
        getLowSalesAlert(),
        getHighSalesAlert(),
      ]),
    ]);

    final alertsResults = results[11] as List;

    return {
      'todaySales': results[0] as double,
      'yesterdaySales': results[1] as double,
      'todayTransactions': results[2] as int,
      'monthlyAverage': results[3] as double,
      'monthlyAvgTransactions': results[4] as double,
      'todayProfit': results[5] as double,
      'todayAverageTicket': results[6] as double,
      'dailySales': results[7] as Map<int, double>,
      'paymentMethods': results[8] as Map<String, double>,
      'topProducts': results[9] as List<Map<String, dynamic>>,
      'activeSession': results[10] as Session?,
      'outOfStockAlerts': alertsResults[0] as List<Map<String, dynamic>>,
      'criticalStockAlerts': alertsResults[1] as List<Map<String, dynamic>>,
      'cashDifferenceAlerts': alertsResults[2] as List<Map<String, dynamic>>,
      'lowSalesAlert': alertsResults[3] as Map<String, dynamic>?,
      'highSalesAlert': alertsResults[4] as Map<String, dynamic>?,
    };
  }
}