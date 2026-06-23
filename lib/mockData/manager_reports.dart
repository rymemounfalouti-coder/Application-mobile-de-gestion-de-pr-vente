import '../data/mock_presales_data.dart';
import 'manager_dashboard.dart';

class ManagerReportsMockData {
  const ManagerReportsMockData._();

  static ReportsData byPeriod(ManagerDashboardPeriod period) {
    final factor = _periodFactor(period);
    final orders = MockPreSalesData.commercialOrders.values
        .expand((orders) => orders)
        .toList();
    final validated = orders.where(_isValidated).toList();
    final pending = orders.where(
      (order) => order.status == OrderStatus.pending,
    );
    final cancelled = orders.where(
      (order) => order.status == OrderStatus.cancelled,
    );

    final baseRevenue = validated.fold<double>(
      0,
      (total, order) => total + order.total,
    );
    final revenue = (baseRevenue * factor).round();
    final validatedCount = (validated.length * factor).round();
    final pendingCount = (pending.length * factor).round();
    final cancelledCount = (cancelled.length * factor).round();
    final returnedCount = _returnsFor(period);
    final totalStatus =
        validatedCount + pendingCount + cancelledCount + returnedCount;

    return ReportsData(
      period: period,
      periodLabel: _periodLabel(period),
      revenue: revenue,
      revenueEvolution: _revenueEvolution(period, revenue),
      statuses: [
        OrderStatusReport(
          label: 'Validées',
          count: validatedCount,
          percent: _percent(validatedCount, totalStatus),
          colorHex: 0xFF2674F8,
        ),
        OrderStatusReport(
          label: 'En attente',
          count: pendingCount,
          percent: _percent(pendingCount, totalStatus),
          colorHex: 0xFFFFC043,
        ),
        OrderStatusReport(
          label: 'Annulées',
          count: cancelledCount,
          percent: _percent(cancelledCount, totalStatus),
          colorHex: 0xFFFF5B45,
        ),
        OrderStatusReport(
          label: 'Retour',
          count: returnedCount,
          percent: _percent(returnedCount, totalStatus),
          colorHex: 0xFF7B61FF,
        ),
      ],
    );
  }

  static bool _isValidated(CommercialOrder order) {
    return order.status == OrderStatus.synced ||
        order.status == OrderStatus.delivered;
  }

  static double _periodFactor(ManagerDashboardPeriod period) {
    return switch (period) {
      ManagerDashboardPeriod.today => .25,
      ManagerDashboardPeriod.week => 1,
      ManagerDashboardPeriod.month => 4,
      ManagerDashboardPeriod.year => 48,
    };
  }

  static int _returnsFor(ManagerDashboardPeriod period) {
    return switch (period) {
      ManagerDashboardPeriod.today => 0,
      ManagerDashboardPeriod.week => 1,
      ManagerDashboardPeriod.month => 3,
      ManagerDashboardPeriod.year => 26,
    };
  }

  static int _percent(int count, int total) {
    if (total == 0) return 0;
    return ((count / total) * 100).round();
  }

  static String _periodLabel(ManagerDashboardPeriod period) {
    return switch (period) {
      ManagerDashboardPeriod.today => "Aujourd'hui",
      ManagerDashboardPeriod.week => 'Cette semaine',
      ManagerDashboardPeriod.month => 'Mai 2024',
      ManagerDashboardPeriod.year => 'Cette année',
    };
  }

  static List<RevenuePoint> _revenueEvolution(
    ManagerDashboardPeriod period,
    int revenue,
  ) {
    final days = switch (period) {
      ManagerDashboardPeriod.today => [8, 10, 12, 14, 16, 18],
      ManagerDashboardPeriod.week => [1, 2, 3, 4, 5, 6, 7],
      ManagerDashboardPeriod.month => [1, 5, 10, 15, 20, 25, 31],
      ManagerDashboardPeriod.year => [1, 2, 4, 6, 8, 10, 12],
    };
    const ratios = [.22, .34, .28, .48, .64, .78, 1.0];
    final usableRatios = ratios.take(days.length).toList();

    return [
      for (var i = 0; i < days.length; i++)
        RevenuePoint(day: days[i], amount: (revenue * usableRatios[i]).round()),
    ];
  }
}

class ReportsData {
  const ReportsData({
    required this.period,
    required this.periodLabel,
    required this.revenue,
    required this.revenueEvolution,
    required this.statuses,
  });

  final ManagerDashboardPeriod period;
  final String periodLabel;
  final int revenue;
  final List<RevenuePoint> revenueEvolution;
  final List<OrderStatusReport> statuses;
}

class RevenuePoint {
  const RevenuePoint({required this.day, required this.amount});

  final int day;
  final int amount;
}

class OrderStatusReport {
  const OrderStatusReport({
    required this.label,
    required this.count,
    required this.percent,
    required this.colorHex,
  });

  final String label;
  final int count;
  final int percent;
  final int colorHex;
}
