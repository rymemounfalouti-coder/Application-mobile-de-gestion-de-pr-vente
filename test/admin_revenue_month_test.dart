import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_prevente/screens/admin/admin_screens.dart';
import 'package:gestion_prevente/screens/admin/home_admin.dart';

void main() {
  AdminOrder order(String date, double total, {String status = 'validated'}) =>
      AdminOrder(
        number: 'X',
        client: 'C',
        commercial: 'V',
        date: date,
        total: total,
        subtotal: total,
        discount: 0,
        status: status,
        items: const [],
      );

  test('adminRevenueByMonth buckets by month, drops undated/out-of-window', () {
    final points = adminRevenueByMonth([
      order('10/07/2026', 100), // July -> current month
      order('20/07/2026', 50), // July
      order('05/06/2026', 200), // June
      order('01/01/2020', 999), // outside 6-month window -> dropped
      order('-', 999), // undated -> dropped
    ], now: DateTime(2026, 7, 15));

    expect(points.length, 6);
    expect(points.last.label, 'Juil');
    expect(points.last.amount, 150);
    expect(points[points.length - 2].amount, 200); // June bucket
    // Only the 5 in-window months + current are summed; strays excluded.
    expect(points.fold<double>(0, (s, p) => s + p.amount), 350);
  });

  test('admin revenue only includes accepted orders', () {
    final orders = [
      order('10/07/2026', 1200),
      order('11/07/2026', 900, status: 'pending'),
      order('12/07/2026', 400, status: 'refused'),
      order('13/07/2026', 300),
    ];

    expect(adminAcceptedRevenue(orders), 1500);
  });
}
