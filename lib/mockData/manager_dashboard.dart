import '../data/mock_presales_data.dart';

enum ManagerDashboardPeriod { today, week, month, year }

extension ManagerDashboardPeriodLabel on ManagerDashboardPeriod {
  String get label {
    return switch (this) {
      ManagerDashboardPeriod.today => "Aujourd'hui",
      ManagerDashboardPeriod.week => 'Cette semaine',
      ManagerDashboardPeriod.month => 'Ce mois',
      ManagerDashboardPeriod.year => 'Cette annee',
    };
  }
}

class ManagerDashboardMockData {
  const ManagerDashboardMockData._();

  static const _evolutionByPeriod = {
    ManagerDashboardPeriod.today: ManagerDashboardEvolution(
      revenue: 12,
      orders: 18,
      visits: 8,
      conversionRate: 6,
    ),
    ManagerDashboardPeriod.week: ManagerDashboardEvolution(
      revenue: 15,
      orders: 11,
      visits: 9,
      conversionRate: 4,
    ),
    ManagerDashboardPeriod.month: ManagerDashboardEvolution(
      revenue: 21,
      orders: 17,
      visits: 13,
      conversionRate: 7,
    ),
    ManagerDashboardPeriod.year: ManagerDashboardEvolution(
      revenue: 28,
      orders: 19,
      visits: 16,
      conversionRate: 9,
    ),
  };

  static ManagerDashboardData byPeriod(ManagerDashboardPeriod period) {
    final commercials = commercialSalesByPeriod(period);
    final revenue = commercials.fold<int>(
      0,
      (total, item) => total + item.sales,
    );
    final orders = commercials.fold<int>(
      0,
      (total, item) => total + item.ordersCount,
    );
    final visits = commercials.fold<int>(
      0,
      (total, item) => total + item.visitsCount,
    );

    return ManagerDashboardData(
      period: period,
      stats: ManagerDashboardStats(
        revenue: revenue,
        orders: orders,
        visits: visits,
        conversionRate: visits == 0 ? 0 : ((orders / visits) * 100).round(),
      ),
      evolution:
          _evolutionByPeriod[period] ??
          _evolutionByPeriod[ManagerDashboardPeriod.today]!,
      salesByCommercial: commercials,
    );
  }

  static List<CommercialSales> commercialSalesByPeriod(
    ManagerDashboardPeriod period, {
    bool includeInactive = false,
  }) {
    final factor = _periodFactor(period);

    return MockPreSalesData.commercialUsers(
        includeInactive: includeInactive,
      ).map((commercial) {
        final orders = _ordersForCommercial(commercial.id);
        final visits = _visitsForCommercial(commercial.id);
        final activities = _activitiesForCommercial(commercial.id);
        final dashboard = MockPreSalesData.commercialDashboards[commercial.id];
        final baseSales = orders.fold<double>(
          0,
          (total, order) => total + order.total,
        );
        final baseOrders = orders.length;
        final baseVisits = activities.isNotEmpty
            ? activities.length
            : visits.length;
        final sales = (baseSales * factor).round();
        final ordersCount = (baseOrders * factor).round();
        final visitsCount = (baseVisits * factor).round();

        return CommercialSales(
          commercialId: commercial.id,
          name: commercial.name,
          email: commercial.email,
          phone: commercial.phone,
          isActive: commercial.isActive,
          sales: sales,
          ordersCount: ordersCount,
          visitsCount: visitsCount,
          conversionRate: visitsCount == 0
              ? 0
              : ((ordersCount / visitsCount) * 100).round(),
          evolution: dashboard?.summary.revenueEvolution ?? 0,
        );
      }).toList()
      ..sort((left, right) => right.sales.compareTo(left.sales));
  }

  static double _periodFactor(ManagerDashboardPeriod period) {
    return switch (period) {
      ManagerDashboardPeriod.today => .25,
      ManagerDashboardPeriod.week => 1,
      ManagerDashboardPeriod.month => 4,
      ManagerDashboardPeriod.year => 48,
    };
  }

  static List<CommercialOrder> _ordersForCommercial(int commercialId) {
    final keyedOrders =
        MockPreSalesData.commercialOrders[commercialId] ?? const [];
    final linkedOrders = MockPreSalesData.commercialOrders.values
        .expand((orders) => orders)
        .where((order) => order.commercialId == commercialId)
        .toList();

    if (linkedOrders.isEmpty) return keyedOrders;
    return {...keyedOrders, ...linkedOrders}.toList();
  }

  static List<TourVisit> _visitsForCommercial(int commercialId) {
    final keyedVisits =
        MockPreSalesData.commercialTourVisits[commercialId] ?? const [];
    final linkedVisits = MockPreSalesData.commercialTourVisits.values
        .expand((visits) => visits)
        .where((visit) => visit.commercialId == commercialId)
        .toList();

    if (linkedVisits.isEmpty) return keyedVisits;
    return {...keyedVisits, ...linkedVisits}.toList();
  }

  static List<CommercialActivity> _activitiesForCommercial(int commercialId) {
    final dashboard = MockPreSalesData.commercialDashboards[commercialId];
    final keyedActivities =
        dashboard?.activities ?? const <CommercialActivity>[];
    final linkedActivities = MockPreSalesData.commercialDashboards.values
        .expand((dashboard) => dashboard.activities)
        .where((activity) => activity.commercialId == commercialId)
        .toList();

    if (linkedActivities.isEmpty) return keyedActivities;
    return {...keyedActivities, ...linkedActivities}.toList();
  }
}

class ManagerDashboardData {
  const ManagerDashboardData({
    required this.period,
    required this.stats,
    required this.evolution,
    required this.salesByCommercial,
  });

  final ManagerDashboardPeriod period;
  final ManagerDashboardStats stats;
  final ManagerDashboardEvolution evolution;
  final List<CommercialSales> salesByCommercial;
}

class ManagerDashboardStats {
  const ManagerDashboardStats({
    required this.revenue,
    required this.orders,
    required this.visits,
    required this.conversionRate,
  });

  final int revenue;
  final int orders;
  final int visits;
  final int conversionRate;
}

class ManagerDashboardEvolution {
  const ManagerDashboardEvolution({
    required this.revenue,
    required this.orders,
    required this.visits,
    required this.conversionRate,
  });

  final int revenue;
  final int orders;
  final int visits;
  final int conversionRate;
}

class CommercialSales {
  const CommercialSales({
    required this.commercialId,
    required this.name,
    required this.email,
    required this.phone,
    required this.isActive,
    required this.sales,
    required this.ordersCount,
    required this.visitsCount,
    required this.conversionRate,
    required this.evolution,
  });

  final int commercialId;
  final String name;
  final String email;
  final String phone;
  final bool isActive;
  final int sales;
  final int ordersCount;
  final int visitsCount;
  final int conversionRate;
  final int evolution;
}
