import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_prevente/services/manager_revenue_rules.dart';

void main() {
  test('manager CA includes confirmed orders only', () {
    final orders = <Map<String, Object>>[
      {'status': 'validee', 'total': 1200},
      {'status': 'validated', 'total': 800},
      {'status': 'en_attente', 'total': 5000},
      {'status': 'pending', 'total': 4000},
      {'status': 'refusee', 'total': 3000},
      {'status': 'rejected', 'total': 2000},
    ];

    final revenue = sumConfirmedManagerRevenue(
      orders,
      statusOf: (order) => order['status'] as String,
      amountOf: (order) => order['total'] as num,
    );

    expect(revenue, 2000);
  });

  test('legacy confirmed statuses remain compatible', () {
    for (final status in [
      'Validée',
      'CONFIRMED',
      'livrée',
      'delivered',
      'synced',
    ]) {
      expect(
        managerOrderContributesToRevenue(status),
        isTrue,
        reason: status,
      );
    }
  });

  test('pending, refused, cancelled and unknown statuses never count', () {
    for (final status in [
      '',
      'en_attente',
      'pending',
      'refusee',
      'rejected',
      'cancelled',
      'unknown',
    ]) {
      expect(
        managerOrderContributesToRevenue(status),
        isFalse,
        reason: status,
      );
    }
  });
}
