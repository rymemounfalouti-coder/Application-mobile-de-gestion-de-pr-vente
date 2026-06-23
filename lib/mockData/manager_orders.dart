import '../data/mock_presales_data.dart';

enum ManagerOrderStatus { all, validated, pending, cancelled, returned }

extension ManagerOrderStatusLabel on ManagerOrderStatus {
  String get label {
    return switch (this) {
      ManagerOrderStatus.all => 'Toutes',
      ManagerOrderStatus.validated => 'Validées',
      ManagerOrderStatus.pending => 'En attente',
      ManagerOrderStatus.cancelled => 'Annulées',
      ManagerOrderStatus.returned => 'Retour',
    };
  }
}

class ManagerOrdersMockData {
  const ManagerOrdersMockData._();

  static final Map<int, ManagerOrderStatus> _statusOverrides = {};

  static List<ManagerOrderItem> allOrders() {
    final usersById = {
      for (final user in MockPreSalesData.commercialUsers(
        includeInactive: true,
      ))
        user.id: user,
    };
    final orders = <ManagerOrderItem>[];

    for (final entry in MockPreSalesData.commercialOrders.entries) {
      final commercial = usersById[entry.key];
      if (commercial == null) continue;

      for (final order in entry.value) {
        final status = _statusOverrides[order.id] ?? _statusFor(order);
        orders.add(
          ManagerOrderItem(
            id: order.id,
            orderNumber: order.orderNumber,
            clientName: order.clientName,
            commercialId: commercial.id,
            commercialName: commercial.name,
            total: order.total.round(),
            itemsCount: order.productsCount,
            dateLabel: _dateTimeLabel(order),
            status: status,
            lines: [
              for (final item in order.items)
                ManagerOrderLine(
                  productName: item.productName,
                  quantity: item.quantity,
                  lineTotal: item.total.round(),
                ),
            ],
          ),
        );
      }
    }

    orders.sort((left, right) => right.id.compareTo(left.id));
    return orders;
  }

  static ManagerOrderItem? orderById(int orderId) {
    for (final order in allOrders()) {
      if (order.id == orderId) return order;
    }
    return null;
  }

  static void updateStatus(int orderId, ManagerOrderStatus status) {
    _statusOverrides[orderId] = status;
  }

  static ManagerOrdersSummary summary(List<ManagerOrderItem> orders) {
    int count(ManagerOrderStatus status) {
      return orders.where((order) => order.status == status).length;
    }

    return ManagerOrdersSummary(
      totalOrders: orders.length,
      validatedOrders: count(ManagerOrderStatus.validated),
      pendingOrders: count(ManagerOrderStatus.pending),
      cancelledOrders: count(ManagerOrderStatus.cancelled),
      returnedOrders: count(ManagerOrderStatus.returned),
    );
  }

  static ManagerOrderStatus _statusFor(CommercialOrder order) {
    return switch (order.status) {
      OrderStatus.pending => ManagerOrderStatus.pending,
      OrderStatus.synced ||
      OrderStatus.delivered => ManagerOrderStatus.validated,
      OrderStatus.cancelled =>
        order.id.isEven
            ? ManagerOrderStatus.cancelled
            : ManagerOrderStatus.returned,
    };
  }

  static String _dateTimeLabel(CommercialOrder order) {
    final hour = 8 + (order.id % 9);
    final minute = (order.id * 7) % 60;
    return '${order.date} • ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}

class ManagerOrdersSummary {
  const ManagerOrdersSummary({
    required this.totalOrders,
    required this.validatedOrders,
    required this.pendingOrders,
    required this.cancelledOrders,
    required this.returnedOrders,
  });

  final int totalOrders;
  final int validatedOrders;
  final int pendingOrders;
  final int cancelledOrders;
  final int returnedOrders;
}

class ManagerOrderItem {
  const ManagerOrderItem({
    required this.id,
    required this.orderNumber,
    required this.clientName,
    required this.commercialId,
    required this.commercialName,
    required this.total,
    required this.itemsCount,
    required this.dateLabel,
    required this.status,
    required this.lines,
  });

  final int id;
  final String orderNumber;
  final String clientName;
  final int commercialId;
  final String commercialName;
  final int total;
  final int itemsCount;
  final String dateLabel;
  final ManagerOrderStatus status;
  final List<ManagerOrderLine> lines;
}

class ManagerOrderLine {
  const ManagerOrderLine({
    required this.productName,
    required this.quantity,
    required this.lineTotal,
  });

  final String productName;
  final int quantity;
  final int lineTotal;
}
