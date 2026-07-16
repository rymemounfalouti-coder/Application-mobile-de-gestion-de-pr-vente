/// Revenue rules shared by the manager dashboard and its tests.
///
/// Pending and refused orders must never contribute to CA. Legacy statuses
/// that the backend normalizes to `validee` remain accepted for compatibility.
bool managerOrderContributesToRevenue(String? rawStatus) {
  final status = (rawStatus ?? '')
      .trim()
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll(RegExp(r'\s+'), ' ');

  return const {
    'validee',
    'validated',
    'confirmed',
    'confirmee',
    'delivered',
    'livree',
    'synced',
    'synchronisee',
  }.contains(status);
}

double sumConfirmedManagerRevenue<T>(
  Iterable<T> orders, {
  required String? Function(T order) statusOf,
  required num Function(T order) amountOf,
}) {
  return orders
      .where((order) => managerOrderContributesToRevenue(statusOf(order)))
      .fold<double>(0, (sum, order) => sum + amountOf(order).toDouble());
}
