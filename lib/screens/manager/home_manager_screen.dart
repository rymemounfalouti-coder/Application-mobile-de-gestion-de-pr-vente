import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../api_service.dart';
import '../../l10n/app_localizations.dart';

import '../../auth/current_user_session.dart';
import '../../data/mock_presales_data.dart';
import '../../l10n/app_locale_controller.dart';
import '../../mockData/manager_dashboard.dart';
import '../../mockData/manager_orders.dart';
import '../../mockData/manager_reports.dart';
import '../../services/commercial_objectives_service.dart';
import '../../settings/app_appearance_controller.dart';

class DashboardManager extends StatefulWidget {
  DashboardManager({super.key});

  @override
  State<DashboardManager> createState() => _DashboardManagerState();
}

@Deprecated('Use DashboardManager instead.')
class HomeManager extends DashboardManager {
  HomeManager({super.key});
}

enum _CommercialFilter {
  all,
  active,
  inactive,
  topRevenue,
  mostOrders,
  mostVisits,
}

extension _CommercialFilterLabel on _CommercialFilter {
  String get label {
    return switch (this) {
      _CommercialFilter.all => 'Tous',
      _CommercialFilter.active => 'Actifs',
      _CommercialFilter.inactive => 'Inactifs',
      _CommercialFilter.topRevenue => 'Meilleur CA',
      _CommercialFilter.mostOrders => 'Plus de commandes',
      _CommercialFilter.mostVisits => 'Plus de visites',
    };
  }
}

enum _ManagerDashboardPeriod {
  today,
  week,
  month,
  previousMonth,
  last3Months,
  last6Months,
  year,
  custom,
}

extension _ManagerDashboardPeriodUi on _ManagerDashboardPeriod {
  String get label {
    return switch (this) {
      _ManagerDashboardPeriod.today => "Aujourd'hui",
      _ManagerDashboardPeriod.week => 'Cette semaine',
      _ManagerDashboardPeriod.month => 'Ce mois',
      _ManagerDashboardPeriod.previousMonth => 'Mois precedent',
      _ManagerDashboardPeriod.last3Months => '3 derniers mois',
      _ManagerDashboardPeriod.last6Months => '6 derniers mois',
      _ManagerDashboardPeriod.year => 'Cette annee',
      _ManagerDashboardPeriod.custom => 'Periode personnalisee',
    };
  }

  DateTimeRange range(DateTimeRange? customRange) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      _ManagerDashboardPeriod.today => DateTimeRange(
        start: today,
        end: today.add(Duration(days: 1)).subtract(Duration(milliseconds: 1)),
      ),
      _ManagerDashboardPeriod.week => DateTimeRange(
        start: today.subtract(Duration(days: today.weekday - 1)),
        end: today.add(Duration(days: 1)).subtract(Duration(milliseconds: 1)),
      ),
      _ManagerDashboardPeriod.month => DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(
          now.year,
          now.month + 1,
          1,
        ).subtract(Duration(milliseconds: 1)),
      ),
      _ManagerDashboardPeriod.previousMonth => DateTimeRange(
        start: DateTime(now.year, now.month - 1, 1),
        end: DateTime(
          now.year,
          now.month,
          1,
        ).subtract(Duration(milliseconds: 1)),
      ),
      _ManagerDashboardPeriod.last3Months => DateTimeRange(
        start: DateTime(now.year, now.month - 2, 1),
        end: DateTime(
          now.year,
          now.month + 1,
          1,
        ).subtract(Duration(milliseconds: 1)),
      ),
      _ManagerDashboardPeriod.last6Months => DateTimeRange(
        start: DateTime(now.year, now.month - 5, 1),
        end: DateTime(
          now.year,
          now.month + 1,
          1,
        ).subtract(Duration(milliseconds: 1)),
      ),
      _ManagerDashboardPeriod.year => DateTimeRange(
        start: DateTime(now.year, 1, 1),
        end: DateTime(now.year + 1, 1, 1).subtract(Duration(milliseconds: 1)),
      ),
      _ManagerDashboardPeriod.custom =>
        customRange ??
            DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
    };
  }
}

enum _ManagerOrderApiStatus { all, pending, validated, refused }

enum _ManagerRecentActivityType { order, report, objective, activity, claim }

final ValueNotifier<int> _managerUnreadNotifications = ValueNotifier<int>(0);

bool _isUnreadManagerNotification(Map<dynamic, dynamic> item) {
  final value = item['is_read'] ?? item['read'] ?? item['lu'];
  if (value is bool) return !value;
  if (value is num) return value == 0;
  if (value is String) {
    return !['true', '1', 'lu', 'read'].contains(value.toLowerCase());
  }
  return true;
}

Future<void> _syncManagerUnreadNotifications() async {
  final user = CurrentUserSession.currentUser;
  if (user == null || !user.isManager) return;
  try {
    final notifications = await ApiService.getNotifications(managerId: user.id);
    _managerUnreadNotifications.value = notifications
        .whereType<Map>()
        .where(_isUnreadManagerNotification)
        .length;
  } catch (error) {
    debugPrint('[MANAGER][NOTIFICATIONS][BADGE][ERROR] $error');
  }
}

class _ManagerHomeData {
  _ManagerHomeData({
    required this.range,
    required this.revenue,
    required this.totalOrders,
    required this.pendingOrders,
    required this.validatedOrders,
    required this.refusedOrders,
    required this.activeCommercials,
    required this.activeClients,
    required this.objectiveRate,
    required this.revenueSeries,
    required this.topCommercials,
    required this.recentActivities,
    this.unreadNotifications = 0,
  });

  final DateTimeRange range;
  final double revenue;
  final int totalOrders;
  final int pendingOrders;
  final int validatedOrders;
  final int refusedOrders;
  final int activeCommercials;
  final int activeClients;
  final int objectiveRate;
  final List<_ManagerRevenuePoint> revenueSeries;
  final List<_ManagerCommercialPerformance> topCommercials;
  final List<_ManagerRecentActivity> recentActivities;
  final int unreadNotifications;

  _ManagerHomeData copyWith({
    int? objectiveRate,
    List<_ManagerCommercialPerformance>? topCommercials,
  }) {
    return _ManagerHomeData(
      range: range,
      revenue: revenue,
      totalOrders: totalOrders,
      pendingOrders: pendingOrders,
      validatedOrders: validatedOrders,
      refusedOrders: refusedOrders,
      activeCommercials: activeCommercials,
      activeClients: activeClients,
      objectiveRate: objectiveRate ?? this.objectiveRate,
      revenueSeries: revenueSeries,
      topCommercials: topCommercials ?? this.topCommercials,
      recentActivities: recentActivities,
      unreadNotifications: unreadNotifications,
    );
  }

  factory _ManagerHomeData.empty() {
    final now = DateTime.now();
    return _ManagerHomeData(
      range: DateTimeRange(start: now, end: now),
      revenue: 0,
      totalOrders: 0,
      pendingOrders: 0,
      validatedOrders: 0,
      refusedOrders: 0,
      activeCommercials: 0,
      activeClients: 0,
      objectiveRate: 0,
      revenueSeries: const [],
      topCommercials: const [],
      recentActivities: const [],
    );
  }

  factory _ManagerHomeData.fromApi({
    required List<dynamic> factures,
    required List<dynamic> users,
    required List<dynamic> notifications,
    required DateTimeRange range,
    required _ManagerDashboardPeriod period,
  }) {
    final orders = factures
        .whereType<Map>()
        .map((item) => _ManagerApiOrder.fromJson(item.cast<String, dynamic>()))
        .where(
          (order) => order.date != null && _dateInRange(order.date!, range),
        )
        .toList();

    final usersList = users
        .whereType<Map>()
        .map((item) => _ManagerApiUser.fromJson(item.cast<String, dynamic>()))
        .toList();
    final usersById = {for (final user in usersList) user.id: user};
    final activeCommercialIds = orders
        .map((order) => order.commercialId)
        .whereType<int>()
        .toSet();
    final activeClientKeys = orders
        .map((order) => order.clientId?.toString() ?? order.clientName)
        .where((value) => value.trim().isNotEmpty)
        .toSet();
    final activeCommercials = activeCommercialIds.length;
    final activeClients = activeClientKeys.length;

    final validated = orders
        .where((order) => order.status == _ManagerOrderApiStatus.validated)
        .toList();
    final revenue = orders.fold<double>(0, (sum, order) => sum + order.total);
    final pendingOrders = orders
        .where((o) => o.status == _ManagerOrderApiStatus.pending)
        .length;
    final refusedOrders = orders
        .where((o) => o.status == _ManagerOrderApiStatus.refused)
        .length;

    final byCommercial = <int, _ManagerCommercialPerformance>{};
    for (final order in orders) {
      final commercialId = order.commercialId ?? 0;
      final existing = byCommercial[commercialId];
      final userName = usersById[commercialId]?.name ?? '';
      final name = existing?.name ?? order.commercialName.ifEmpty(userName);
      byCommercial[commercialId] = _ManagerCommercialPerformance(
        id: commercialId,
        name: name.isEmpty ? 'Commercial' : name,
        revenue: (existing?.revenue ?? 0) + order.total,
        orderCount: (existing?.orderCount ?? 0) + 1,
        objective: existing?.objective ?? 0,
        objectiveRate: 0,
      );
    }
    final top = byCommercial.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    final top5 = top.take(5).toList();

    final objectiveTotal = top.fold<double>(
      0,
      (sum, item) => sum + item.objective,
    );
    final objectiveRate = objectiveTotal <= 0
        ? 0
        : ((revenue / objectiveTotal) * 100).round();
    final unreadNotifications = notifications
        .whereType<Map>()
        .where(_isUnreadManagerNotification)
        .length;
    _managerUnreadNotifications.value = unreadNotifications;

    return _ManagerHomeData(
      range: range,
      revenue: revenue,
      totalOrders: orders.length,
      pendingOrders: pendingOrders,
      validatedOrders: validated.length,
      refusedOrders: refusedOrders,
      activeCommercials: activeCommercials,
      activeClients: activeClients,
      objectiveRate: objectiveRate,
      revenueSeries: _buildRevenueSeries(orders, range, period),
      topCommercials: top5,
      recentActivities: _buildRecentActivities(orders),
      unreadNotifications: unreadNotifications,
    );
  }
}

class _ManagerApiOrder {
  _ManagerApiOrder({
    required this.id,
    required this.total,
    required this.status,
    this.date,
    this.commercialId,
    this.clientId,
    this.commercialName = '',
    this.clientName = '',
    this.orderNumber = '',
  });

  final int id;
  final double total;
  final _ManagerOrderApiStatus status;
  final DateTime? date;
  final int? commercialId;
  final int? clientId;
  final String commercialName;
  final String clientName;
  final String orderNumber;

  factory _ManagerApiOrder.fromJson(Map<String, dynamic> json) {
    return _ManagerApiOrder(
      id: _readInt(json, ['id', 'facture_id']),
      total: _readDouble(json, [
        'total',
        'total_amount',
        'montant_total',
        'amount',
        'net_a_payer',
      ]),
      status: _parseOrderStatus(
        _readString(json, ['status', 'statut', 'etat']),
      ),
      date: _readDate(json, ['date', 'created_at', 'date_facture']),
      commercialId: _readNullableInt(json, [
        'commercial_id',
        'id_commercial',
        'user_id',
        'created_by',
        'vendeur_id',
      ]),
      clientId: _readNullableInt(json, ['client_id', 'id_client']),
      commercialName: _readString(json, [
        'commercial_name',
        'commercial',
        'user_name',
        'vendeur',
      ]),
      clientName: _readString(json, ['client_name', 'client', 'client_nom']),
      orderNumber: _readString(json, [
        'order_number',
        'numero_facture',
        'numero',
        'reference',
      ]),
    );
  }
}

class _ManagerApiUser {
  _ManagerApiUser({
    required this.id,
    required this.name,
    required this.role,
    required this.status,
  });

  final int id;
  final String name;
  final String role;
  final String status;

  bool get isCommercial => role.toLowerCase().contains('commercial');
  bool get isActive => _isActiveStatus(status);

  factory _ManagerApiUser.fromJson(Map<String, dynamic> json) {
    return _ManagerApiUser(
      id: _readInt(json, ['id', 'user_id']),
      name: _readString(json, ['name', 'full_name', 'username', 'nom']),
      role: _readString(json, ['role', 'type']),
      status: _readString(json, ['status', 'statut', 'etat']),
    );
  }
}

class _ManagerRevenuePoint {
  const _ManagerRevenuePoint({required this.label, required this.amount});

  final String label;
  final double amount;
}

class _ManagerCommercialPerformance {
  const _ManagerCommercialPerformance({
    required this.id,
    required this.name,
    required this.revenue,
    required this.orderCount,
    required this.objective,
    required this.objectiveRate,
  });

  final int id;
  final String name;
  final double revenue;
  final int orderCount;
  final double objective;
  final int objectiveRate;
}

class _ManagerRecentActivity {
  const _ManagerRecentActivity({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.date,
    this.orderId,
    this.statusFilter,
  });

  final _ManagerRecentActivityType type;
  final String title;
  final String subtitle;
  final DateTime date;
  final int? orderId;
  final String? statusFilter;
}

List<_ManagerRevenuePoint> _buildRevenueSeries(
  List<_ManagerApiOrder> orders,
  DateTimeRange range,
  _ManagerDashboardPeriod period,
) {
  final days = range.end.difference(range.start).inDays + 1;
  if (period == _ManagerDashboardPeriod.today) {
    return List.generate(24, (hour) {
      final amount = orders
          .where((order) => order.date?.hour == hour)
          .fold<double>(0, (sum, order) => sum + order.total);
      return _ManagerRevenuePoint(label: '${hour}h', amount: amount);
    });
  }
  if (days <= 45) {
    return List.generate(days.clamp(1, 45), (index) {
      final day = DateTime(
        range.start.year,
        range.start.month,
        range.start.day + index,
      );
      final amount = orders
          .where(
            (order) =>
                order.date != null &&
                order.date!.year == day.year &&
                order.date!.month == day.month &&
                order.date!.day == day.day,
          )
          .fold<double>(0, (sum, order) => sum + order.total);
      return _ManagerRevenuePoint(
        label: '${day.day}/${day.month}',
        amount: amount,
      );
    });
  }
  final months = <String, double>{};
  var cursor = DateTime(range.start.year, range.start.month, 1);
  final end = DateTime(range.end.year, range.end.month, 1);
  while (!cursor.isAfter(end)) {
    months['${cursor.month}/${cursor.year}'] = 0;
    cursor = DateTime(cursor.year, cursor.month + 1, 1);
  }
  for (final order in orders) {
    final date = order.date;
    if (date == null) continue;
    final key = '${date.month}/${date.year}';
    months[key] = (months[key] ?? 0) + order.total;
  }
  return months.entries
      .map(
        (entry) => _ManagerRevenuePoint(label: entry.key, amount: entry.value),
      )
      .toList();
}

List<_ManagerRecentActivity> _buildRecentActivities(
  List<_ManagerApiOrder> orders,
) {
  final sorted = [...orders]
    ..sort((a, b) {
      final left = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });
  return sorted.take(5).map((order) {
    final title = switch (order.status) {
      _ManagerOrderApiStatus.pending =>
        'Nouvelle commande ${order.orderNumber.isEmpty ? '#${order.id}' : order.orderNumber} en attente',
      _ManagerOrderApiStatus.validated =>
        'Commande ${order.orderNumber.isEmpty ? '#${order.id}' : order.orderNumber} validee',
      _ManagerOrderApiStatus.refused =>
        'Commande ${order.orderNumber.isEmpty ? '#${order.id}' : order.orderNumber} refusee',
      _ManagerOrderApiStatus.all =>
        'Commande ${order.orderNumber.isEmpty ? '#${order.id}' : order.orderNumber}',
    };
    return _ManagerRecentActivity(
      type: _ManagerRecentActivityType.order,
      title: title,
      subtitle: [
        if (order.commercialName.isNotEmpty) 'Par ${order.commercialName}',
        if (order.clientName.isNotEmpty) order.clientName,
      ].join(' - '),
      date: order.date ?? DateTime.now(),
      orderId: order.id,
      statusFilter: _statusFilterValue(order.status),
    );
  }).toList();
}

bool _dateInRange(DateTime date, DateTimeRange range) {
  return !date.isBefore(range.start) && !date.isAfter(range.end);
}

bool _isActiveStatus(String status) {
  final value = status.toLowerCase().trim();
  return value.isEmpty ||
      value == 'actif' ||
      value == 'active' ||
      value == '1' ||
      value == 'true';
}

_ManagerOrderApiStatus _parseOrderStatus(String raw) {
  final value = raw.toLowerCase().trim();
  if (value.contains('valid') || value.contains('livr')) {
    return _ManagerOrderApiStatus.validated;
  }
  if (value.contains('refus') ||
      value.contains('reject') ||
      value.contains('annul') ||
      value.contains('cancel')) {
    return _ManagerOrderApiStatus.refused;
  }
  if (value.contains('attente') || value.contains('pending')) {
    return _ManagerOrderApiStatus.pending;
  }
  return _ManagerOrderApiStatus.pending;
}

String _statusFilterValue(_ManagerOrderApiStatus status) {
  return switch (status) {
    _ManagerOrderApiStatus.validated => 'validee',
    _ManagerOrderApiStatus.pending => 'en_attente',
    _ManagerOrderApiStatus.refused => 'refusee',
    _ManagerOrderApiStatus.all => 'all',
  };
}

String _readString(Map<dynamic, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null) return value.toString();
  }
  return '';
}

String _readUserDisplayName(Map<dynamic, dynamic> json) {
  final direct = _readString(json, ['name', 'full_name', 'username']).trim();
  if (direct.isNotEmpty) return direct;
  final first = _readString(json, ['prenom', 'first_name']).trim();
  final last = _readString(json, ['nom', 'last_name']).trim();
  return '$first $last'.trim();
}

int _readInt(Map<dynamic, dynamic> json, List<String> keys) {
  return _readNullableInt(json, keys) ?? 0;
}

int? _readNullableInt(Map<dynamic, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return null;
}

double _readDouble(Map<dynamic, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.replaceAll(',', '.'));
      if (parsed != null) return parsed;
    }
  }
  return 0;
}

DateTime? _readDate(Map<dynamic, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
      final httpParsed = _parseHttpDate(value);
      if (httpParsed != null) return httpParsed;
    }
  }
  return null;
}

DateTime? _parseHttpDate(String value) {
  final match = RegExp(
    r'^[A-Za-z]{3},\s+(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+'
    r'(\d{2}):(\d{2}):(\d{2})\s+GMT$',
  ).firstMatch(value.trim());
  if (match == null) return null;
  const months = {
    'Jan': 1,
    'Feb': 2,
    'Mar': 3,
    'Apr': 4,
    'May': 5,
    'Jun': 6,
    'Jul': 7,
    'Aug': 8,
    'Sep': 9,
    'Oct': 10,
    'Nov': 11,
    'Dec': 12,
  };
  final month = months[match.group(2)];
  if (month == null) return null;
  return DateTime.utc(
    int.parse(match.group(3)!),
    month,
    int.parse(match.group(1)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6)!),
  ).toLocal();
}

class _ManagerOrdersCache {
  static final Map<int, _ManagerOrderView> _orders = {};

  static void replaceAll(List<_ManagerOrderView> orders) {
    _orders
      ..clear()
      ..addEntries(orders.map((order) => MapEntry(order.id, order)));
  }

  static _ManagerOrderView? byId(int id) => _orders[id];
}

class _ManagerOrderView {
  _ManagerOrderView({
    required this.id,
    required this.number,
    required this.clientName,
    required this.commercialName,
    required this.status,
    required this.total,
    this.createdAt,
    this.clientPhone = '',
    this.clientCity = '',
    this.clientCategory = '',
    this.clientAddress = '',
    this.clientCode = '',
    this.clientStatus = '',
    this.commercialId,
    this.commercialPhone = '',
    this.commercialCity = '',
    this.commercialMatricule = '',
    this.paymentMode = '',
    this.deliveryDate,
    this.referenceClient = '',
    this.notes = '',
    this.discount = 0,
    this.tax = 0,
    this.managerComments = const [],
    this.history = const [],
    this.lines = const [],
    this.raw = const {},
  });

  final int id;
  final String number;
  final String clientName;
  final String commercialName;
  final _ManagerOrderApiStatus status;
  final double total;
  final DateTime? createdAt;
  final String clientPhone;
  final String clientCity;
  final String clientCategory;
  final String clientAddress;
  final String clientCode;
  final String clientStatus;
  final int? commercialId;
  final String commercialPhone;
  final String commercialCity;
  final String commercialMatricule;
  final String paymentMode;
  final DateTime? deliveryDate;
  final String referenceClient;
  final String notes;
  final double discount;
  final double tax;
  final List<Map<String, dynamic>> managerComments;
  final List<Map<String, dynamic>> history;
  final List<_ManagerOrderLineView> lines;
  final Map<String, dynamic> raw;

  bool matchesSearch(String query) {
    if (query.isEmpty) return true;
    final value = query.toLowerCase();
    return number.toLowerCase().contains(value) ||
        clientName.toLowerCase().contains(value) ||
        commercialName.toLowerCase().contains(value) ||
        clientPhone.toLowerCase().contains(value) ||
        clientCity.toLowerCase().contains(value);
  }

  bool inRange(DateTimeRange range) {
    final date = createdAt;
    if (date == null) return true;
    return _dateInRange(date, range);
  }

  String get dateLabel {
    final date = createdAt;
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String get timeLabel {
    final date = createdAt;
    if (date == null) return '--:--';
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  int get productsCount {
    final rawCount = _readInt(raw, [
      'items_count',
      'products_count',
      'nombre_produits',
      'lignes_count',
    ]);
    if (rawCount > 0) return rawCount;
    return lines.length;
  }

  factory _ManagerOrderView.fromJson(Map<String, dynamic> json) {
    final id = _readInt(json, ['id', 'facture_id']);
    final linesRaw =
        json['details'] ??
        json['details_facture'] ??
        json['lignes'] ??
        json['items'] ??
        const [];
    return _ManagerOrderView(
      id: id,
      number: _readString(json, [
        'order_number',
        'numero_facture',
        'numero',
        'reference',
        'code',
      ]).ifEmpty('CMD-$id'),
      clientName: _readString(json, [
        'client_name',
        'client',
        'client_nom',
        'name_client',
      ]).ifEmpty('Client'),
      commercialName: _readString(json, [
        'commercial_name',
        'commercial',
        'user_name',
        'vendeur',
      ]).ifEmpty('Commercial'),
      status: _parseOrderStatus(
        _readString(json, ['status', 'statut', 'etat']),
      ),
      total: _readDouble(json, [
        'total',
        'total_amount',
        'montant_total',
        'amount',
        'net_a_payer',
      ]),
      createdAt: _readDate(json, [
        'date',
        'created_at',
        'date_facture',
        'createdAt',
      ]),
      clientPhone: _readString(json, ['client_phone', 'phone', 'telephone']),
      clientCity: _readString(json, ['city', 'ville', 'client_city']),
      clientCategory: _readString(json, [
        'category',
        'client_category',
        'categorie',
        'business_type',
      ]),
      clientAddress: _readString(json, [
        'address',
        'adresse',
        'client_address',
      ]),
      clientCode: _readString(json, ['client_code', 'code_client']),
      clientStatus: _readString(json, [
        'client_status',
        'status_client',
        'statut_client',
      ]),
      commercialId: _readNullableInt(json, [
        'commercial_id',
        'id_commercial',
        'user_id',
        'created_by',
        'vendeur_id',
      ]),
      commercialPhone: _readString(json, [
        'commercial_phone',
        'vendeur_phone',
        'user_phone',
      ]),
      commercialCity: _readString(json, [
        'commercial_city',
        'vendeur_city',
        'user_city',
      ]),
      commercialMatricule: _readString(json, [
        'commercial_matricule',
        'matricule',
        'user_code',
      ]),
      paymentMode: _readString(json, [
        'payment_mode',
        'mode_paiement',
        'payment',
      ]),
      deliveryDate: _readDate(json, [
        'delivery_date',
        'date_livraison',
        'date_livraison_souhaitee',
      ]),
      referenceClient: _readString(json, [
        'reference_client',
        'client_reference',
        'ref_client',
      ]),
      notes: _readString(json, ['notes', 'commentaire', 'comments']),
      discount: _readDouble(json, ['discount', 'remise']),
      tax: _readDouble(json, ['tax', 'tva', 'vat']),
      managerComments:
          (json['manager_comments'] ?? json['comments_manager'] ?? const [])
              is List
          ? ((json['manager_comments'] ?? json['comments_manager'] ?? const [])
                    as List)
                .whereType<Map>()
                .map((e) => e.cast<String, dynamic>())
                .toList()
          : const [],
      history: (json['history'] ?? json['historique'] ?? const []) is List
          ? ((json['history'] ?? json['historique'] ?? const []) as List)
                .whereType<Map>()
                .map((e) => e.cast<String, dynamic>())
                .toList()
          : const [],
      lines: linesRaw is List
          ? linesRaw
                .whereType<Map>()
                .map((line) => _ManagerOrderLineView.fromJson(line.cast()))
                .toList()
          : const [],
      raw: json,
    );
  }
}

class _ManagerOrderLineView {
  const _ManagerOrderLineView({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    this.reference = '',
    this.image = '',
    this.discount = 0,
  });

  final String name;
  final double quantity;
  final double unitPrice;
  final double total;
  final String reference;
  final String image;
  final double discount;

  factory _ManagerOrderLineView.fromJson(Map<String, dynamic> json) {
    final quantity = _readDouble(json, ['quantity', 'quantite', 'qty', 'qte']);
    final unitPrice = _readDouble(json, [
      'unit_price',
      'prix_unitaire',
      'prix_vendu',
      'price',
    ]);
    return _ManagerOrderLineView(
      name: _readString(json, [
        'product_name',
        'produit',
        'name',
        'designation',
      ]).ifEmpty('Produit'),
      reference: _readString(json, [
        'reference',
        'product_reference',
        'ref',
        'code',
      ]),
      image: _readString(json, ['image', 'product_image', 'photo']),
      quantity: quantity,
      unitPrice: unitPrice,
      discount: _readDouble(json, ['discount', 'remise']),
      total: _readDouble(json, [
        'total',
        'total_ligne',
        'line_total',
      ]).nonZero(quantity * unitPrice),
    );
  }
}

extension _ManagerStringFallback on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}

extension _ManagerDoubleFallback on double {
  double nonZero(double fallback) => this == 0 ? fallback : this;
}

class _ManagerHomeHeader extends StatelessWidget {
  _ManagerHomeHeader({
    required this.managerName,
    required this.unreadCount,
    required this.onMenuPressed,
    required this.onNotificationsPressed,
    required this.onAvatarPressed,
  });

  final String managerName;
  final int unreadCount;
  final VoidCallback onMenuPressed;
  final VoidCallback onNotificationsPressed;
  final VoidCallback onAvatarPressed;

  @override
  Widget build(BuildContext context) {
    final initials = managerName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
    return Container(
      height: 100,
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
      decoration: BoxDecoration(color: _DashboardManagerState.managerHeader),
      child: Row(
        children: [
          IconButton(
            onPressed: onMenuPressed,
            icon: Icon(LucideIcons.menu, size: 32),
            color: Colors.white,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints.tightFor(width: 42, height: 42),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour, Manager',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Manager',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: Color(0xFFD8E2F3),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<int>(
            valueListenable: _managerUnreadNotifications,
            builder: (context, globalUnread, child) {
              final effectiveUnread = globalUnread;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: onNotificationsPressed,
                    icon: Icon(LucideIcons.bell, size: 27),
                    color: Colors.white,
                  ),
                  if (effectiveUnread > 0)
                    Positioned(
                      right: 7,
                      top: 5,
                      child: Container(
                        constraints: BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: _DashboardManagerState.managerRed,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Center(
                          child: Text(
                            effectiveUnread > 99 ? '99+' : '$effectiveUnread',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          SizedBox(width: 8),
          InkWell(
            onTap: onAvatarPressed,
            borderRadius: BorderRadius.circular(24),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: Color(0xFFE7EFFD),
              child: Text(
                initials.isEmpty ? 'MB' : initials,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: _DashboardManagerState.managerBlue,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagerHomePeriodSelector extends StatelessWidget {
  _ManagerHomePeriodSelector({
    required this.selectedPeriod,
    required this.customRange,
    required this.onChanged,
  });

  final _ManagerDashboardPeriod selectedPeriod;
  final DateTimeRange? customRange;
  final ValueChanged<_ManagerDashboardPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _managerCardDecoration(13),
      child: SizedBox(
        width: 120,
        height: 42,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<_ManagerDashboardPeriod>(
            value: selectedPeriod,
            isExpanded: true,
            borderRadius: BorderRadius.circular(16),
            icon: Icon(LucideIcons.chevronDown, size: 16),
            padding: EdgeInsets.symmetric(horizontal: 8),
            style: TextStyle(
              fontFamily: 'Roboto',
              color: _DashboardManagerState.managerText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            items: _ManagerDashboardPeriod.values
                .map(
                  (period) => DropdownMenuItem(
                    value: period,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.calendar, size: 16),
                        SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            period.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (period) {
              if (period != null) onChanged(period);
            },
          ),
        ),
      ),
    );
  }
}

class _ManagerDashboardLoading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      alignment: Alignment.center,
      child: CircularProgressIndicator(
        color: _DashboardManagerState._primaryBlue,
      ),
    );
  }
}

class _ManagerDashboardError extends StatelessWidget {
  _ManagerDashboardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _ManagerEmptyCard(
      icon: Icons.error_outline_rounded,
      title: 'Erreur',
      message: message,
      actionLabel: 'Reessayer',
      onAction: onRetry,
    );
  }
}

class _ManagerDashboardContent extends StatelessWidget {
  _ManagerDashboardContent({
    required this.data,
    required this.onOpenCommands,
    required this.onOpenCommercials,
    required this.onOpenObjectives,
    required this.onOpenReports,
    required this.onOpenProfile,
    required this.onOpenRecentActivity,
    required this.onOpenCommercialDetail,
  });

  final _ManagerHomeData data;
  final ValueChanged<String> onOpenCommands;
  final VoidCallback onOpenCommercials;
  final VoidCallback onOpenObjectives;
  final VoidCallback onOpenReports;
  final VoidCallback onOpenProfile;
  final ValueChanged<_ManagerRecentActivity> onOpenRecentActivity;
  final ValueChanged<_ManagerCommercialPerformance> onOpenCommercialDetail;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ManagerKpiGrid(data: data, onOpenCommands: onOpenCommands),
        SizedBox(height: 18),
        Column(
          children: [
            _RevenueEvolutionCard(points: data.revenueSeries),
            SizedBox(height: 18),
            _OrderStatusDonutCard(data: data, onOpenCommands: onOpenCommands),
          ],
        ),
        SizedBox(height: 18),
        _TopCommercialsCard(
          commercials: data.topCommercials,
          onViewAll: onOpenCommercials,
          onTap: onOpenCommercialDetail,
        ),
        SizedBox(height: 18),
        _RecentActivitiesCard(
          activities: data.recentActivities,
          onViewAll: onOpenReports,
          onTap: onOpenRecentActivity,
        ),
        SizedBox(height: 18),
        _QuickActionsGrid(
          onPendingOrders: () => onOpenCommands('en_attente'),
          onObjectives: onOpenObjectives,
          onReports: onOpenReports,
          onCommercials: onOpenCommercials,
        ),
      ],
    );
  }
}

class _ManagerKpiGrid extends StatelessWidget {
  _ManagerKpiGrid({required this.data, required this.onOpenCommands});

  final _ManagerHomeData data;
  final ValueChanged<String> onOpenCommands;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _ManagerKpiData(
        title: "Chiffre d'affaires",
        value: '${_formatNumber(data.revenue.round())} DH',
        icon: LucideIcons.dollarSign,
        color: _DashboardManagerState.managerBlue,
        iconBackground: _DashboardManagerState.iconBlueBg,
        onTap: () => onOpenCommands('validee'),
      ),
      _ManagerKpiData(
        title: 'Total commandes',
        value: '${data.totalOrders}',
        icon: LucideIcons.shoppingCart,
        color: _DashboardManagerState.managerGreen,
        iconBackground: _DashboardManagerState.iconGreenBg,
        onTap: () => onOpenCommands('all'),
      ),
      _ManagerKpiData(
        title: 'Commandes en attente',
        value: '${data.pendingOrders}',
        link: 'Voir plus',
        icon: LucideIcons.clock,
        color: _DashboardManagerState.managerOrange,
        iconBackground: _DashboardManagerState.iconOrangeBg,
        onTap: () => onOpenCommands('en_attente'),
      ),
      _ManagerKpiData(
        title: 'Commandes validees',
        value: '${data.validatedOrders}',
        icon: LucideIcons.checkCircle,
        color: _DashboardManagerState.managerGreen,
        iconBackground: _DashboardManagerState.iconGreenBg,
        onTap: () => onOpenCommands('validee'),
      ),
      _ManagerKpiData(
        title: 'Commandes refusees',
        value: '${data.refusedOrders}',
        icon: LucideIcons.xCircle,
        color: _DashboardManagerState.managerRed,
        iconBackground: _DashboardManagerState.iconRedBg,
        onTap: () => onOpenCommands('refusee'),
      ),
      _ManagerKpiData(
        title: 'Commerciaux actifs',
        value: '${data.activeCommercials}',
        link: 'Voir la liste',
        icon: LucideIcons.users,
        color: _DashboardManagerState.managerPurple,
        iconBackground: _DashboardManagerState.iconPurpleBg,
        onTap: () => Navigator.pushNamed(context, '/manager-commerciaux'),
      ),
      _ManagerKpiData(
        title: 'Clients actifs',
        value: '${data.activeClients}',
        icon: LucideIcons.user,
        color: _DashboardManagerState.managerCyan,
        iconBackground: _DashboardManagerState.iconCyanBg,
        onTap: () => Navigator.pushNamed(context, '/manager-commerciaux'),
      ),
      _ManagerKpiData(
        title: 'Objectif global atteint',
        value: '${data.objectiveRate}%',
        icon: LucideIcons.target,
        color: _DashboardManagerState.managerOrange,
        iconBackground: _DashboardManagerState.iconOrangeBg,
        onTap: () => Navigator.pushNamed(context, '/manager-commerciaux'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.33,
          ),
          itemBuilder: (context, index) => _ManagerKpiCard(data: cards[index]),
        );
      },
    );
  }
}

class _ManagerKpiData {
  _ManagerKpiData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.iconBackground,
    this.link,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color iconBackground;
  final VoidCallback onTap;
  final String? link;
}

class _ManagerKpiCard extends StatelessWidget {
  _ManagerKpiCard({required this.data});

  final _ManagerKpiData data;

  @override
  Widget build(BuildContext context) {
    final hasLink = data.link != null;
    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: EdgeInsets.all(hasLink ? 9 : 12),
        decoration: _managerCardDecoration(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ManagerSoftIcon(
              icon: data.icon,
              color: data.color,
              backgroundColor: data.iconBackground,
              size: hasLink ? 30 : 34,
            ),
            SizedBox(height: hasLink ? 3 : 5),
            Text(
              data.title,
              maxLines: hasLink ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Roboto',
                color: _DashboardManagerState.managerText,
                fontSize: hasLink ? 10.2 : 10.8,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: hasLink ? 5 : 8),
            Text(
              data.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Roboto',
                color: data.color,
                fontSize: hasLink ? 15.5 : 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (data.link != null) ...[
              SizedBox(height: 1),
              Text(
                data.link!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: _DashboardManagerState.managerBlue,
                  fontSize: 8.8,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RevenueEvolutionCard extends StatelessWidget {
  _RevenueEvolutionCard({required this.points});

  final List<_ManagerRevenuePoint> points;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 245,
      padding: EdgeInsets.all(16),
      decoration: _managerCardDecoration(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Evolution du chiffre d'affaires",
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: _DashboardManagerState.managerText,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _DashboardManagerState.managerBorder,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '6 mois',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: _DashboardManagerState.managerMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Expanded(
            child: points.isEmpty || points.every((point) => point.amount == 0)
                ? _ManagerEmptyInline(
                    icon: LucideIcons.lineChart,
                    text: 'Aucune donnée disponible pour cette période.',
                  )
                : CustomPaint(
                    painter: _ManagerRevenueLinePainter(points),
                    child: SizedBox.expand(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _OrderStatusDonutCard extends StatelessWidget {
  _OrderStatusDonutCard({required this.data, required this.onOpenCommands});

  final _ManagerHomeData data;
  final ValueChanged<String> onOpenCommands;

  @override
  Widget build(BuildContext context) {
    final total =
        data.validatedOrders + data.pendingOrders + data.refusedOrders;
    final rows = [
      (
        'Validees',
        data.validatedOrders,
        _DashboardManagerState._success,
        'validee',
      ),
      (
        'En attente',
        data.pendingOrders,
        _DashboardManagerState._warning,
        'en_attente',
      ),
      (
        'Refusees',
        data.refusedOrders,
        _DashboardManagerState._danger,
        'refusee',
      ),
    ];
    return Container(
      height: 230,
      padding: EdgeInsets.all(16),
      decoration: _managerCardDecoration(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Repartition des commandes',
            style: TextStyle(
              fontFamily: 'Roboto',
              color: _DashboardManagerState.managerText,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 18),
          if (total == 0)
            Expanded(
              child: _ManagerEmptyInline(
                icon: LucideIcons.pieChart,
                text: 'Aucune donnee disponible.',
              ),
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 138,
                  height: 138,
                  child: CustomPaint(
                    painter: _OrderDonutPainter(
                      validated: data.validatedOrders,
                      pending: data.pendingOrders,
                      refused: data.refusedOrders,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$total',
                            style: TextStyle(
                              color: _DashboardManagerState._textDark,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Total',
                            style: TextStyle(
                              color: _DashboardManagerState._textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 18),
                Expanded(
                  child: Column(
                    children: [
                      for (final row in rows)
                        InkWell(
                          onTap: () => onOpenCommands(row.$4),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: row.$3,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    row.$1,
                                    style: TextStyle(
                                      color: _DashboardManagerState._textDark,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${row.$2} (${((row.$2 / total) * 100).round()}%)',
                                  style: TextStyle(
                                    color: _DashboardManagerState._textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TopCommercialsCard extends StatelessWidget {
  _TopCommercialsCard({
    required this.commercials,
    required this.onViewAll,
    required this.onTap,
  });

  final List<_ManagerCommercialPerformance> commercials;
  final VoidCallback onViewAll;
  final ValueChanged<_ManagerCommercialPerformance> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: _managerCardDecoration(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Top 5 des commerciaux (CA)',
                  style: TextStyle(
                    color: _DashboardManagerState._textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(onPressed: onViewAll, child: Text('Voir tout')),
            ],
          ),
          if (commercials.isEmpty)
            _ManagerEmptyInline(
              icon: LucideIcons.users,
              text: 'Aucune performance disponible pour le moment.',
            )
          else
            for (var i = 0; i < commercials.length; i++)
              _TopCommercialRow(
                rank: i + 1,
                commercial: commercials[i],
                onTap: () => onTap(commercials[i]),
              ),
        ],
      ),
    );
  }
}

class _TopCommercialRow extends StatelessWidget {
  _TopCommercialRow({
    required this.rank,
    required this.commercial,
    required this.onTap,
  });

  final int rank;
  final _ManagerCommercialPerformance commercial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rate = commercial.objective <= 0
        ? 0
        : ((commercial.revenue / commercial.objective) * 100).round();
    final progress = (rate / 100).clamp(0.0, 1.0);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: rank <= 3
                  ? _DashboardManagerState._warning
                  : Color(0xFFE2E8F0),
              child: Text(
                '$rank',
                style: TextStyle(
                  color: rank <= 3
                      ? Colors.white
                      : _DashboardManagerState._textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            SizedBox(width: 10),
            CircleAvatar(
              radius: 16,
              backgroundColor: _DashboardManagerState._primaryBlue.withValues(
                alpha: .12,
              ),
              child: Text(
                commercial.name.isEmpty
                    ? 'C'
                    : commercial.name[0].toUpperCase(),
                style: TextStyle(
                  color: _DashboardManagerState._primaryBlue,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    commercial.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _DashboardManagerState._textDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: Color(0xFFE9EEF8),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _DashboardManagerState._success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_formatNumber(commercial.revenue.round())} DH',
                  style: TextStyle(
                    color: _DashboardManagerState._primaryBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '$rate%',
                  style: TextStyle(
                    color: _DashboardManagerState._success,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivitiesCard extends StatelessWidget {
  _RecentActivitiesCard({
    required this.activities,
    required this.onViewAll,
    required this.onTap,
  });

  final List<_ManagerRecentActivity> activities;
  final VoidCallback onViewAll;
  final ValueChanged<_ManagerRecentActivity> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: _managerCardDecoration(18),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Activites recentes',
                  style: TextStyle(
                    color: _DashboardManagerState._textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(onPressed: onViewAll, child: Text('Voir tout')),
            ],
          ),
          if (activities.isEmpty)
            _ManagerEmptyInline(
              icon: LucideIcons.bell,
              text: 'Aucune activité récente.',
            )
          else
            for (final activity in activities)
              InkWell(
                onTap: () => onTap(activity),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      _ManagerSoftIcon(
                        icon: _activityIcon(activity.type),
                        color: _activityColor(activity.type),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _DashboardManagerState._textDark,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (activity.subtitle.isNotEmpty) ...[
                              SizedBox(height: 3),
                              Text(
                                activity.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _DashboardManagerState._textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        _formatShortDateTime(activity.date),
                        style: TextStyle(
                          color: _DashboardManagerState._textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  _QuickActionsGrid({
    required this.onPendingOrders,
    required this.onObjectives,
    required this.onReports,
    required this.onCommercials,
  });

  final VoidCallback onPendingOrders;
  final VoidCallback onObjectives;
  final VoidCallback onReports;
  final VoidCallback onCommercials;

  @override
  Widget build(BuildContext context) {
    final actions = [
      ('Commandes', 'En attente', LucideIcons.receipt, onPendingOrders),
      ('Objectifs', 'Mensuels', LucideIcons.target, onObjectives),
      ('Rapports', 'Journaliers', LucideIcons.fileText, onReports),
      ('Equipe', 'Commerciaux', LucideIcons.users, onCommercials),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions rapides',
          style: TextStyle(
            fontFamily: 'Roboto',
            color: _DashboardManagerState.managerText,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            return GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: actions.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.25,
              ),
              itemBuilder: (context, index) {
                final action = actions[index];
                return InkWell(
                  onTap: action.$4,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    height: 72,
                    padding: EdgeInsets.all(12),
                    decoration: _managerCardDecoration(18),
                    child: Row(
                      children: [
                        _ManagerSoftIcon(
                          icon: action.$3,
                          color: _DashboardManagerState.managerBlue,
                          backgroundColor: _DashboardManagerState.iconBlueBg,
                          size: 40,
                        ),
                        SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                action.$1,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  color: _DashboardManagerState.managerText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                action.$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  color: _DashboardManagerState.managerMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          LucideIcons.chevronRight,
                          color: _DashboardManagerState.managerMuted,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _ManagerSoftIcon extends StatelessWidget {
  _ManagerSoftIcon({
    required this.icon,
    required this.color,
    this.backgroundColor,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final Color? backgroundColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(size == 52 ? 14 : size * .28),
      ),
      child: Icon(icon, color: color, size: size * .52),
    );
  }
}

class _ManagerEmptyInline extends StatelessWidget {
  _ManagerEmptyInline({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 22),
      child: Row(
        children: [
          _ManagerSoftIcon(
            icon: icon,
            color: _DashboardManagerState._primaryBlue,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: _DashboardManagerState._textMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagerEmptyCard extends StatelessWidget {
  _ManagerEmptyCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18),
      decoration: _managerCardDecoration(18),
      child: Column(
        children: [
          _ManagerSoftIcon(
            icon: icon,
            color: _DashboardManagerState._primaryBlue,
            size: 58,
          ),
          SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: _DashboardManagerState._textDark,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _DashboardManagerState._textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: 14),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

BoxDecoration _managerCardDecoration(double radius) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: _DashboardManagerState.managerBorder),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: .04),
        blurRadius: 14,
        spreadRadius: 0,
        offset: Offset(0, 6),
      ),
    ],
  );
}

IconData _activityIcon(_ManagerRecentActivityType type) {
  return switch (type) {
    _ManagerRecentActivityType.order => LucideIcons.shoppingCart,
    _ManagerRecentActivityType.report => LucideIcons.fileText,
    _ManagerRecentActivityType.objective => LucideIcons.target,
    _ManagerRecentActivityType.activity => LucideIcons.alertTriangle,
    _ManagerRecentActivityType.claim => LucideIcons.heartHandshake,
  };
}

Color _activityColor(_ManagerRecentActivityType type) {
  return switch (type) {
    _ManagerRecentActivityType.order => _DashboardManagerState._success,
    _ManagerRecentActivityType.report => _DashboardManagerState._purple,
    _ManagerRecentActivityType.objective => _DashboardManagerState._warning,
    _ManagerRecentActivityType.activity => _DashboardManagerState._danger,
    _ManagerRecentActivityType.claim => _DashboardManagerState._primaryBlue,
  };
}

String _formatShortDateTime(DateTime date) {
  final now = DateTime.now();
  final hh = date.hour.toString().padLeft(2, '0');
  final mm = date.minute.toString().padLeft(2, '0');
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    return '$hh:$mm';
  }
  return '${date.day}/${date.month} $hh:$mm';
}

class _ManagerRevenueLinePainter extends CustomPainter {
  _ManagerRevenueLinePainter(this.points);

  final List<_ManagerRevenuePoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(30, 10, size.width - 38, size.height - 42);
    final gridPaint = Paint()
      ..color = _DashboardManagerState._border
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = chart.bottom - chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
    final maxValue = points.fold<double>(
      1,
      (max, point) => point.amount > max ? point.amount : max,
    );
    final offsets = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? chart.left
          : chart.left + chart.width * i / (points.length - 1);
      final y = chart.bottom - chart.height * (points[i].amount / maxValue);
      offsets.add(Offset(x, y));
    }
    final linePaint = Paint()
      ..color = _DashboardManagerState._primaryBlue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < offsets.length; i++) {
      if (i == 0) {
        path.moveTo(offsets[i].dx, offsets[i].dy);
      } else {
        path.lineTo(offsets[i].dx, offsets[i].dy);
      }
    }
    canvas.drawPath(path, linePaint);
    final dotPaint = Paint()..color = _DashboardManagerState._primaryBlue;
    for (final offset in offsets) {
      canvas.drawCircle(offset, 4, dotPaint);
    }
    final step = points.length <= 7 ? 1 : (points.length / 6).ceil();
    final textStyle = TextStyle(
      color: _DashboardManagerState._textMuted,
      fontSize: 10,
      fontWeight: FontWeight.w700,
    );
    for (var i = 0; i < points.length; i += step) {
      final x = points.length == 1
          ? chart.left
          : chart.left + chart.width * i / (points.length - 1);
      final painter = TextPainter(
        text: TextSpan(text: points[i].label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 52);
      painter.paint(canvas, Offset(x - painter.width / 2, chart.bottom + 12));
    }
  }

  @override
  bool shouldRepaint(covariant _ManagerRevenueLinePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _OrderDonutPainter extends CustomPainter {
  _OrderDonutPainter({
    required this.validated,
    required this.pending,
    required this.refused,
  });

  final int validated;
  final int pending;
  final int refused;

  @override
  void paint(Canvas canvas, Size size) {
    final total = validated + pending + refused;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24;
    if (total == 0) {
      paint.color = _DashboardManagerState._border;
      canvas.drawArc(rect.deflate(16), -math.pi / 2, math.pi * 2, false, paint);
      return;
    }
    var start = -math.pi / 2;
    for (final segment in [
      (validated, _DashboardManagerState._success),
      (pending, _DashboardManagerState._warning),
      (refused, _DashboardManagerState._danger),
    ]) {
      if (segment.$1 == 0) continue;
      final sweep = math.pi * 2 * segment.$1 / total;
      paint.color = segment.$2;
      canvas.drawArc(rect.deflate(16), start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _OrderDonutPainter oldDelegate) {
    return oldDelegate.validated != validated ||
        oldDelegate.pending != pending ||
        oldDelegate.refused != refused;
  }
}

class CommerciauxManager extends StatefulWidget {
  CommerciauxManager({super.key});

  @override
  State<CommerciauxManager> createState() => _CommerciauxManagerApiState();
}

class _ManagerCommercialsCache {
  static final Map<int, _ManagerCommercialView> _items = {};
  static void replaceAll(List<_ManagerCommercialView> items) {
    _items
      ..clear()
      ..addEntries(items.map((item) => MapEntry(item.id, item)));
  }

  static _ManagerCommercialView? byId(int id) => _items[id];
}

enum _ManagerCommercialStatus { all, active, leave, disabled }

class _ManagerCommercialView {
  const _ManagerCommercialView({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.city,
    required this.address,
    required this.matricule,
    required this.role,
    required this.status,
    required this.revenue,
    required this.objective,
    required this.ordersCount,
    required this.clientsCount,
    required this.activitiesCount,
    required this.reportsCount,
    this.hiredAt,
  });

  final int id;
  final String name;
  final String email;
  final String phone;
  final String city;
  final String address;
  final String matricule;
  final String role;
  final _ManagerCommercialStatus status;
  final double revenue;
  final double objective;
  final int ordersCount;
  final int clientsCount;
  final int activitiesCount;
  final int reportsCount;
  final DateTime? hiredAt;

  int get objectiveRate =>
      objective <= 0 ? 0 : ((revenue / objective) * 100).round();
  bool get isActive => status == _ManagerCommercialStatus.active;

  bool matchesSearch(String query) {
    if (query.isEmpty) return true;
    final value = query.toLowerCase();
    return name.toLowerCase().contains(value) ||
        email.toLowerCase().contains(value) ||
        phone.toLowerCase().contains(value) ||
        matricule.toLowerCase().contains(value);
  }
}

class _ManagerCommercialsData {
  const _ManagerCommercialsData({required this.items});
  final List<_ManagerCommercialView> items;

  int get total => items.length;
  int get active => items
      .where((item) => item.status == _ManagerCommercialStatus.active)
      .length;
  int get leave => items
      .where((item) => item.status == _ManagerCommercialStatus.leave)
      .length;
  int get disabled => items
      .where((item) => item.status == _ManagerCommercialStatus.disabled)
      .length;
  double get revenue => items.fold(0, (sum, item) => sum + item.revenue);
  int get objectiveRate {
    if (items.isEmpty) return 0;
    final rates = items.map((item) => item.objectiveRate).toList();
    return (rates.fold<int>(0, (sum, rate) => sum + rate) / rates.length)
        .round();
  }
}

class _CommerciauxManagerApiState extends State<CommerciauxManager> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  _ManagerDashboardPeriod _selectedPeriod = _ManagerDashboardPeriod.month;
  DateTimeRange? _customRange;
  _ManagerCommercialStatus _selectedStatus = _ManagerCommercialStatus.all;
  Future<_ManagerCommercialsData>? _future;
  String _cityFilter = '';
  String _commercialFilter = '';
  String _performanceFilter = '';
  int? _minObjectiveRate;
  int? _minOrders;
  int? _minClients;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _future = _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final routeEmail = args is Map ? args['email']?.toString() ?? '' : '';
    final sessionUser = CurrentUserSession.currentUser;
    final user = sessionUser?.isManager == true
        ? MockPreSalesData.userByEmail(sessionUser!.email)
        : MockPreSalesData.userByEmail(routeEmail);

    if (sessionUser == null && user == null) {
      _redirectAfterBuild(context, '/login');
      return Scaffold(backgroundColor: Colors.white);
    }
    if (sessionUser?.isCommercial == true ||
        user?.role == MockUserRole.commercial) {
      _redirectAfterBuild(context, '/home-commercial');
      return Scaffold(backgroundColor: Colors.white);
    }
    if (sessionUser?.isAdmin == true || user?.role == MockUserRole.admin) {
      _redirectAfterBuild(context, '/dashboard-admin');
      return Scaffold(backgroundColor: Colors.white);
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _DashboardManagerState.managerSurface,
      drawer: _ManagerDrawer(),
      body: _ManagerMobileShell(
        selectedTab: _ManagerTab.commerciaux,
        child: RefreshIndicator(
          color: _DashboardManagerState.managerBlue,
          onRefresh: () async => _refresh(),
          child: FutureBuilder<_ManagerCommercialsData>(
            future: _future,
            builder: (context, snapshot) {
              final data =
                  snapshot.data ?? const _ManagerCommercialsData(items: []);
              final visible = _visible(data.items);
              return SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ManagerHomeHeader(
                      managerName: _managerName(user),
                      unreadCount: 0,
                      onMenuPressed: () =>
                          _scaffoldKey.currentState?.openDrawer(),
                      onNotificationsPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NotificationsScreen(),
                          ),
                        );
                      },
                      onAvatarPressed: () {},
                    ),
                    Transform.translate(
                      offset: Offset(0, -10),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.fromLTRB(16, 22, 16, 96),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ManagerCommercialsTitleRow(
                              selectedPeriod: _selectedPeriod,
                              customRange: _customRange,
                              onPeriodChanged: _changePeriod,
                            ),
                            SizedBox(height: 18),
                            if (snapshot.connectionState ==
                                ConnectionState.waiting)
                              _ManagerCommercialsSkeleton()
                            else if (snapshot.hasError)
                              _ManagerDashboardError(
                                message:
                                    'Impossible de charger les commerciaux.',
                                onRetry: _refresh,
                              )
                            else ...[
                              _ManagerCommercialsKpis(data: data),
                              SizedBox(height: 16),
                              _ManagerCommercialSearchFilter(
                                controller: _searchController,
                                activeFiltersCount: _activeFiltersCount,
                                onFilterPressed: _openFilterSheet,
                              ),
                              SizedBox(height: 14),
                              _ManagerCommercialChips(
                                selected: _selectedStatus,
                                data: data,
                                onChanged: (status) {
                                  setState(() => _selectedStatus = status);
                                },
                              ),
                              SizedBox(height: 14),
                              _ManagerCommercialTop3(
                                items: data.items.take(3).toList(),
                                onViewAll: _resetFilters,
                                onTap: _openCommercialDetail,
                              ),
                              SizedBox(height: 14),
                              if (visible.isEmpty)
                                _ManagerCommercialEmptyState(
                                  hasFilters:
                                      _activeFiltersCount > 0 ||
                                      _searchController.text
                                          .trim()
                                          .isNotEmpty ||
                                      _selectedStatus !=
                                          _ManagerCommercialStatus.all,
                                  onReset: _resetFilters,
                                )
                              else
                                for (final commercial in visible) ...[
                                  _ManagerCommercialModernCard(
                                    commercial: commercial,
                                    onTap: () =>
                                        _openCommercialDetail(commercial),
                                  ),
                                  SizedBox(height: 12),
                                ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<_ManagerCommercialsData> _loadData() async {
    await _syncManagerUnreadNotifications();
    final range = _selectedPeriod.range(_customRange);
    final results = await Future.wait<List<dynamic>>([
      _safeApiList(ApiService.getUsers),
      _safeApiList(ApiService.getFactures),
      _safeApiList(ApiService.getClients),
    ]);
    final users = results[0].whereType<Map>().map(
      (e) => e.cast<String, dynamic>(),
    );
    final factures = results[1]
        .whereType<Map>()
        .map((e) => _ManagerOrderView.fromJson(e.cast<String, dynamic>()))
        .where((order) => order.inRange(range))
        .toList();
    final clients = results[2].whereType<Map>().toList();
    final items = <_ManagerCommercialView>[];
    for (final userJson in users) {
      final role = _readString(userJson, ['role', 'type']);
      if (!role.toLowerCase().contains('commercial')) continue;
      final id = _readInt(userJson, ['id', 'user_id']);
      final orders = factures
          .where((order) => _commercialMatches(order, id, userJson))
          .toList();
      final validated = orders
          .where((order) => order.status == _ManagerOrderApiStatus.validated)
          .toList();
      final objective = await CommercialObjectivesService.instance.getObjective(
        id,
      );
      final assignedClients = clients.where((client) {
        final commercialId = _readNullableInt(client, [
          'commercial_id',
          'id_commercial',
          'user_id',
          'created_by',
        ]);
        return commercialId == null || commercialId == id;
      }).length;
      items.add(
        _ManagerCommercialView(
          id: id,
          name: _readUserDisplayName(userJson).ifEmpty('Commercial'),
          email: _readString(userJson, ['email']),
          phone: _readString(userJson, ['phone', 'telephone']),
          city: _readString(userJson, ['city', 'ville']).ifEmpty('-'),
          address: _readString(userJson, ['address', 'adresse']),
          matricule: _readString(userJson, [
            'matricule',
            'code',
          ]).ifEmpty('COM-${id.toString().padLeft(3, '0')}'),
          role: 'Commercial',
          status: _parseCommercialStatus(
            _readString(userJson, ['status', 'statut', 'etat']),
          ),
          revenue: validated.fold(0, (sum, order) => sum + order.total),
          objective: objective?.revenueTarget ?? 0,
          ordersCount: orders.length,
          clientsCount: assignedClients,
          activitiesCount: 0,
          reportsCount: 0,
          hiredAt: _readDate(userJson, ['hire_date', 'created_at']),
        ),
      );
    }
    items.sort((a, b) => b.revenue.compareTo(a.revenue));
    _ManagerCommercialsCache.replaceAll(items);
    return _ManagerCommercialsData(items: items);
  }

  Future<List<dynamic>> _safeApiList(Future<List<dynamic>> Function() loader) {
    return loader().catchError((_) => <dynamic>[]);
  }

  bool _commercialMatches(
    _ManagerOrderView order,
    int id,
    Map<String, dynamic> user,
  ) {
    final rawId = _readNullableInt(order.raw, [
      'commercial_id',
      'user_id',
      'created_by',
      'vendeur_id',
    ]);
    if (rawId != null) return rawId == id;
    final name = _readUserDisplayName(user);
    return name.isNotEmpty &&
        order.commercialName.toLowerCase().contains(name.toLowerCase());
  }

  List<_ManagerCommercialView> _visible(List<_ManagerCommercialView> source) {
    final query = _searchController.text.trim().toLowerCase();
    return source.where((commercial) {
      final matchesStatus =
          _selectedStatus == _ManagerCommercialStatus.all ||
          commercial.status == _selectedStatus;
      final matchesCity =
          _cityFilter.isEmpty ||
          commercial.city.toLowerCase().contains(_cityFilter.toLowerCase());
      final matchesName =
          _commercialFilter.isEmpty ||
          commercial.name.toLowerCase().contains(
            _commercialFilter.toLowerCase(),
          );
      final matchesPerformance =
          _performanceFilter.isEmpty ||
          (_performanceFilter == 'top' && commercial.revenue > 0);
      final matchesObjective =
          _minObjectiveRate == null ||
          commercial.objectiveRate >= _minObjectiveRate!;
      final matchesOrders =
          _minOrders == null || commercial.ordersCount >= _minOrders!;
      final matchesClients =
          _minClients == null || commercial.clientsCount >= _minClients!;
      return commercial.matchesSearch(query) &&
          matchesStatus &&
          matchesCity &&
          matchesName &&
          matchesPerformance &&
          matchesObjective &&
          matchesOrders &&
          matchesClients;
    }).toList();
  }

  int get _activeFiltersCount {
    var count = 0;
    if (_selectedStatus != _ManagerCommercialStatus.all) count++;
    if (_cityFilter.isNotEmpty) count++;
    if (_commercialFilter.isNotEmpty) count++;
    if (_performanceFilter.isNotEmpty) count++;
    if (_minObjectiveRate != null) count++;
    if (_minOrders != null) count++;
    if (_minClients != null) count++;
    return count;
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _selectedStatus = _ManagerCommercialStatus.all;
      _cityFilter = '';
      _commercialFilter = '';
      _performanceFilter = '';
      _minObjectiveRate = null;
      _minOrders = null;
      _minClients = null;
    });
  }

  Future<void> _changePeriod(_ManagerDashboardPeriod period) async {
    DateTimeRange? range = _customRange;
    if (period == _ManagerDashboardPeriod.custom) {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 5),
        lastDate: DateTime(now.year + 1),
        initialDateRange:
            range ??
            DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
      );
      if (picked == null) return;
      range = picked;
    }
    setState(() {
      _selectedPeriod = period;
      _customRange = range;
      _future = _loadData();
    });
  }

  void _refresh() {
    setState(() => _future = _loadData());
  }

  void _openCommercialDetail(_ManagerCommercialView commercial) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailCommercialScreen(
          commercialId: commercial.id,
          commercialName: commercial.name,
        ),
      ),
    ).then((_) => _refresh());
  }

  void _openFilterSheet() {
    final city = TextEditingController(text: _cityFilter);
    final commercial = TextEditingController(text: _commercialFilter);
    final objective = TextEditingController(
      text: _minObjectiveRate?.toString() ?? '',
    );
    final orders = TextEditingController(text: _minOrders?.toString() ?? '');
    final clients = TextEditingController(text: _minClients?.toString() ?? '');
    var performance = _performanceFilter;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  MediaQuery.of(context).viewInsets.bottom + 18,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filtres commerciaux',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: _DashboardManagerState.managerText,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 14),
                      _ManagerCommercialStatusPicker(
                        selected: _selectedStatus,
                        onChanged: (status) {
                          setState(() => _selectedStatus = status);
                          setSheetState(() {});
                        },
                      ),
                      SizedBox(height: 12),
                      _ManagerFilterField(controller: city, label: 'Ville'),
                      _ManagerFilterField(
                        controller: commercial,
                        label: 'Commercial',
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text('Performance élevée'),
                            selected: performance == 'top',
                            onSelected: (selected) {
                              setSheetState(() {
                                performance = selected ? 'top' : '';
                              });
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      _ManagerFilterField(
                        controller: objective,
                        label: 'Objectif atteint min (%)',
                        keyboardType: TextInputType.number,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _ManagerFilterField(
                              controller: orders,
                              label: 'Commandes min',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: _ManagerFilterField(
                              controller: clients,
                              label: 'Clients min',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                _resetFilters();
                                Navigator.pop(context);
                              },
                              child: Text('Réinitialiser'),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _cityFilter = city.text.trim();
                                  _commercialFilter = commercial.text.trim();
                                  _performanceFilter = performance;
                                  _minObjectiveRate = int.tryParse(
                                    objective.text.trim(),
                                  );
                                  _minOrders = int.tryParse(orders.text.trim());
                                  _minClients = int.tryParse(
                                    clients.text.trim(),
                                  );
                                });
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _DashboardManagerState.managerBlue,
                                foregroundColor: Colors.white,
                              ),
                              child: Text('Appliquer'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _managerName(MockUserProfile? fallbackUser) {
    final sessionName = CurrentUserSession.currentUser?.fullName.trim() ?? '';
    if (sessionName.isNotEmpty) return sessionName;
    final fallbackName = fallbackUser?.name.trim() ?? '';
    return fallbackName.isNotEmpty ? fallbackName : 'Manager';
  }

  void _redirectAfterBuild(BuildContext context, String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
    });
  }
}

// ignore: unused_element
class _CommerciauxManagerState extends State<CommerciauxManager> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  _CommercialFilter _filter = _CommercialFilter.all;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final routeEmail = args is Map ? args['email']?.toString() ?? '' : '';
    final sessionUser = CurrentUserSession.currentUser;
    final user = sessionUser?.isManager == true
        ? MockPreSalesData.userByEmail(sessionUser!.email)
        : MockPreSalesData.userByEmail(routeEmail);

    if (sessionUser == null && user == null) {
      _redirectAfterBuild(context, '/login');
      return Scaffold(backgroundColor: Colors.white);
    }
    if (sessionUser?.isCommercial == true ||
        user?.role == MockUserRole.commercial) {
      _redirectAfterBuild(context, '/home-commercial');
      return Scaffold(backgroundColor: Colors.white);
    }
    if (sessionUser?.isAdmin == true || user?.role == MockUserRole.admin) {
      _redirectAfterBuild(context, '/dashboard-admin');
      return Scaffold(backgroundColor: Colors.white);
    }

    final allCommercials = _loadCommercials();
    final visibleCommercials = _visibleCommercials(allCommercials);
    final summary = _CommercialsSummary.from(allCommercials);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _DashboardManagerState._surface,
      drawer: _ManagerDrawer(),
      body: _ManagerMobileShell(
        selectedTab: _ManagerTab.commerciaux,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(14, 14, 14, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                title: AppLocalizations.globalText('Commerciaux'),
                showNotificationBadge: true,
                onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
                onNotificationsPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NotificationsScreen()),
                  );
                },
              ),
              SizedBox(height: 16),
              _CommercialSearchBar(
                controller: _searchController,
                onFilterPressed: _openFilterPanel,
              ),
              SizedBox(height: 14),
              _CommercialSummaryCards(summary: summary),
              SizedBox(height: 14),
              if (_isLoading)
                _CommercialsLoadingState()
              else if (_errorMessage != null)
                _CommercialsEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: AppLocalizations.globalText('Erreur de donnees'),
                  message: _errorMessage!,
                )
              else if (allCommercials.isEmpty)
                _CommercialsEmptyState(
                  icon: Icons.groups_2_outlined,
                  title: AppLocalizations.globalText('Aucun commercial'),
                  message: 'Aucun compte commercial actif ou inactif.',
                )
              else if (visibleCommercials.isEmpty)
                _CommercialsEmptyState(
                  icon: Icons.search_off_rounded,
                  title: AppLocalizations.globalText('Aucun resultat'),
                  message:
                      'Essayez une autre recherche ou un filtre different.',
                )
              else
                for (final commercial in visibleCommercials) ...[
                  _CommercialCard(
                    commercial: commercial,
                    onTap: () => _openCommercialDetail(commercial),
                  ),
                  SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }

  List<CommercialSales> _loadCommercials() {
    try {
      _errorMessage = null;
      return ManagerDashboardMockData.commercialSalesByPeriod(
        ManagerDashboardPeriod.month,
        includeInactive: true,
      );
    } catch (error) {
      _errorMessage = 'Impossible de charger les commerciaux.';
      return [];
    }
  }

  List<CommercialSales> _visibleCommercials(List<CommercialSales> source) {
    final query = _searchController.text.trim().toLowerCase();
    var items = source.where((commercial) {
      final matchesQuery =
          query.isEmpty ||
          commercial.name.toLowerCase().contains(query) ||
          commercial.email.toLowerCase().contains(query) ||
          commercial.phone.toLowerCase().contains(query);
      final matchesFilter = switch (_filter) {
        _CommercialFilter.active => commercial.isActive,
        _CommercialFilter.inactive => !commercial.isActive,
        _ => true,
      };
      return matchesQuery && matchesFilter;
    }).toList();

    switch (_filter) {
      case _CommercialFilter.topRevenue:
        items.sort((left, right) => right.sales.compareTo(left.sales));
      case _CommercialFilter.mostOrders:
        items.sort(
          (left, right) => right.ordersCount.compareTo(left.ordersCount),
        );
      case _CommercialFilter.mostVisits:
        items.sort(
          (left, right) => right.visitsCount.compareTo(left.visitsCount),
        );
      case _CommercialFilter.all:
      case _CommercialFilter.active:
      case _CommercialFilter.inactive:
        items.sort((left, right) => left.name.compareTo(right.name));
    }
    return items;
  }

  void _openFilterPanel() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.globalText('Filtrer les commerciaux'),
                  style: TextStyle(
                    color: _DashboardManagerState._textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 12),
                for (final filter in _CommercialFilter.values)
                  _FilterOptionTile(
                    label: filter.label,
                    selected: _filter == filter,
                    onTap: () {
                      setState(() => _filter = filter);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openCommercialDetail(CommercialSales commercial) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailCommercialScreen(
          commercialId: commercial.commercialId,
          commercialName: commercial.name,
        ),
      ),
    );
  }

  void _redirectAfterBuild(BuildContext context, String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
    });
  }
}

class OrdersManagerScreen extends StatefulWidget {
  OrdersManagerScreen({super.key});

  @override
  State<OrdersManagerScreen> createState() => _OrdersManagerApiScreenState();
}

class _OrdersManagerApiScreenState extends State<OrdersManagerScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  _ManagerDashboardPeriod _selectedPeriod = _ManagerDashboardPeriod.month;
  DateTimeRange? _customRange;
  _ManagerOrderApiStatus _selectedStatus = _ManagerOrderApiStatus.all;
  Future<List<_ManagerOrderView>>? _ordersFuture;
  Timer? _refreshTimer;
  bool _appliedRouteArgs = false;
  String _commercialFilter = '';
  String _clientFilter = '';
  String _categoryFilter = '';
  double? _minAmount;
  double? _maxAmount;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _ordersFuture = _loadOrders();
    _refreshTimer = Timer.periodic(Duration(seconds: 5), (_) {
      if (mounted) _refreshOrders();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appliedRouteArgs) return;
    _appliedRouteArgs = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) return;
    final status = args['status']?.toString();
    final period = args['period']?.toString();
    final startDate = DateTime.tryParse(args['startDate']?.toString() ?? '');
    final endDate = DateTime.tryParse(args['endDate']?.toString() ?? '');
    setState(() {
      _selectedStatus = switch (status) {
        'en_attente' => _ManagerOrderApiStatus.pending,
        'validee' => _ManagerOrderApiStatus.validated,
        'refusee' => _ManagerOrderApiStatus.refused,
        _ => _ManagerOrderApiStatus.all,
      };
      _selectedPeriod = _ManagerDashboardPeriod.values.firstWhere(
        (item) => item.name == period,
        orElse: () => _selectedPeriod,
      );
      if (startDate != null && endDate != null) {
        _customRange = DateTimeRange(start: startDate, end: endDate);
      }
      _ordersFuture = _loadOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final routeEmail = args is Map ? args['email']?.toString() ?? '' : '';
    final sessionUser = CurrentUserSession.currentUser;
    final user = sessionUser?.isManager == true
        ? MockPreSalesData.userByEmail(sessionUser!.email)
        : MockPreSalesData.userByEmail(routeEmail);

    if (sessionUser == null && user == null) {
      _redirectAfterBuild(context, '/login');
      return Scaffold(backgroundColor: Colors.white);
    }
    if (sessionUser?.isCommercial == true ||
        user?.role == MockUserRole.commercial) {
      _redirectAfterBuild(context, '/home-commercial');
      return Scaffold(backgroundColor: Colors.white);
    }
    if (sessionUser?.isAdmin == true || user?.role == MockUserRole.admin) {
      _redirectAfterBuild(context, '/dashboard-admin');
      return Scaffold(backgroundColor: Colors.white);
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _DashboardManagerState.managerSurface,
      drawer: _ManagerDrawer(),
      body: _ManagerMobileShell(
        selectedTab: _ManagerTab.commandes,
        child: RefreshIndicator(
          color: _DashboardManagerState.managerBlue,
          onRefresh: () async => _refreshOrders(),
          child: FutureBuilder<List<_ManagerOrderView>>(
            future: _ordersFuture,
            builder: (context, snapshot) {
              final orders = snapshot.data ?? const <_ManagerOrderView>[];
              final summary = _ManagerOrdersSummary.from(orders);
              final visibleOrders = _filteredOrders(orders);

              return SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ManagerHomeHeader(
                      managerName: _managerName(user),
                      unreadCount: summary.pending,
                      onMenuPressed: () =>
                          _scaffoldKey.currentState?.openDrawer(),
                      onNotificationsPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NotificationsScreen(),
                          ),
                        );
                      },
                      onAvatarPressed: () {},
                    ),
                    Transform.translate(
                      offset: Offset(0, -10),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.fromLTRB(16, 22, 16, 96),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ManagerOrdersTitleRow(
                              selectedPeriod: _selectedPeriod,
                              customRange: _customRange,
                              onPeriodChanged: _changePeriod,
                            ),
                            SizedBox(height: 18),
                            if (snapshot.connectionState ==
                                ConnectionState.waiting)
                              _ManagerDashboardLoading()
                            else if (_errorMessage != null)
                              _ManagerDashboardError(
                                message:
                                    _errorMessage ??
                                    'Impossible de charger les commandes.',
                                onRetry: _refreshOrders,
                              )
                            else ...[
                              _ManagerOrdersKpiGrid(summary: summary),
                              SizedBox(height: 16),
                              _ManagerOrdersSearchAndFilter(
                                controller: _searchController,
                                activeFiltersCount: _activeFiltersCount,
                                onFilterPressed: _openFilterSheet,
                              ),
                              SizedBox(height: 14),
                              _ManagerOrdersStatusChips(
                                selectedStatus: _selectedStatus,
                                summary: summary,
                                onChanged: (status) {
                                  setState(() => _selectedStatus = status);
                                },
                              ),
                              SizedBox(height: 14),
                              if (visibleOrders.isEmpty)
                                _ManagerOrdersEmptyState(
                                  hasFilters:
                                      _activeFiltersCount > 0 ||
                                      _searchController.text
                                          .trim()
                                          .isNotEmpty ||
                                      _selectedStatus !=
                                          _ManagerOrderApiStatus.all,
                                  onReset: _resetFilters,
                                )
                              else
                                _ManagerOrdersModernList(
                                  orders: visibleOrders,
                                  onTap: _openOrderDetail,
                                  onValidate: _validateOrderFromSwipe,
                                  onRefuse: _refuseOrderFromSwipe,
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openFilterSheet,
        backgroundColor: _DashboardManagerState.managerBlue,
        foregroundColor: Colors.white,
        child: Icon(LucideIcons.slidersHorizontal, size: 24),
      ),
    );
  }

  Future<List<_ManagerOrderView>> _loadOrders() async {
    try {
      await _syncManagerUnreadNotifications();
      _errorMessage = null;
      final range = _selectedPeriod.range(_customRange);
      final raw = await ApiService.getManagerCommandes(
        managerId: CurrentUserSession.currentUser?.id,
      );
      final orders =
          raw
              .whereType<Map>()
              .map((item) => _ManagerOrderView.fromJson(item.cast()))
              .where((order) => order.inRange(range))
              .toList()
            ..sort((a, b) {
              final left =
                  a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final right =
                  b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return right.compareTo(left);
            });
      debugPrint(
        '[MANAGER][COMMANDES] api=${raw.length} visible=${orders.length} '
        'period=${_selectedPeriod.name} manager_id=${CurrentUserSession.currentUser?.id}',
      );
      _ManagerOrdersCache.replaceAll(orders);
      return orders;
    } catch (error) {
      _errorMessage = 'Impossible de charger les commandes PostgreSQL.';
      debugPrint('[MANAGER][COMMANDES][ERROR] $error');
      _ManagerOrdersCache.replaceAll(const []);
      return const [];
    }
  }

  List<_ManagerOrderView> _filteredOrders(List<_ManagerOrderView> source) {
    final query = _searchController.text.trim().toLowerCase();
    return source.where((order) {
      final matchesStatus =
          _selectedStatus == _ManagerOrderApiStatus.all ||
          order.status == _selectedStatus;
      final matchesCommercial =
          _commercialFilter.isEmpty ||
          order.commercialName.toLowerCase().contains(
            _commercialFilter.toLowerCase(),
          );
      final matchesClient =
          _clientFilter.isEmpty ||
          order.clientName.toLowerCase().contains(_clientFilter.toLowerCase());
      final matchesCategory =
          _categoryFilter.isEmpty ||
          order.clientCategory.toLowerCase().contains(
            _categoryFilter.toLowerCase(),
          );
      final matchesMin = _minAmount == null || order.total >= _minAmount!;
      final matchesMax = _maxAmount == null || order.total <= _maxAmount!;
      return order.matchesSearch(query) &&
          matchesStatus &&
          matchesCommercial &&
          matchesClient &&
          matchesCategory &&
          matchesMin &&
          matchesMax;
    }).toList();
  }

  int get _activeFiltersCount {
    var count = 0;
    if (_selectedStatus != _ManagerOrderApiStatus.all) count++;
    if (_commercialFilter.isNotEmpty) count++;
    if (_clientFilter.isNotEmpty) count++;
    if (_categoryFilter.isNotEmpty) count++;
    if (_minAmount != null) count++;
    if (_maxAmount != null) count++;
    return count;
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _selectedStatus = _ManagerOrderApiStatus.all;
      _commercialFilter = '';
      _clientFilter = '';
      _categoryFilter = '';
      _minAmount = null;
      _maxAmount = null;
    });
  }

  Future<void> _changePeriod(_ManagerDashboardPeriod period) async {
    DateTimeRange? range = _customRange;
    if (period == _ManagerDashboardPeriod.custom) {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 5),
        lastDate: DateTime(now.year + 1),
        initialDateRange:
            range ??
            DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
      );
      if (picked == null) return;
      range = picked;
    }
    setState(() {
      _selectedPeriod = period;
      _customRange = range;
      _ordersFuture = _loadOrders();
    });
  }

  void _refreshOrders() {
    setState(() => _ordersFuture = _loadOrders());
  }

  void _openOrderDetail(_ManagerOrderView order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _ManagerOrderDetailPage(orderId: order.id, initial: order),
      ),
    ).then((_) {
      if (mounted) _refreshOrders();
    });
  }

  Future<bool> _validateOrderFromSwipe(_ManagerOrderView order) async {
    if (order.status != _ManagerOrderApiStatus.pending) return false;
    try {
      await ApiService.updateFactureStatus(
        order.id,
        'validee',
        managerId: CurrentUserSession.currentUser?.id,
      );
      if (mounted) _refreshOrders();
      return true;
    } catch (_) {
      _showOrderActionError();
      return false;
    }
  }

  Future<bool> _refuseOrderFromSwipe(_ManagerOrderView order) async {
    if (order.status != _ManagerOrderApiStatus.pending) return false;
    final reason = await _askRefusalReason();
    if (reason == null) return false;
    try {
      await ApiService.updateFactureStatus(
        order.id,
        'refusee',
        refusalReason: reason,
        managerId: CurrentUserSession.currentUser?.id,
      );
      if (mounted) _refreshOrders();
      return true;
    } catch (_) {
      _showOrderActionError();
      return false;
    }
  }

  Future<String?> _askRefusalReason() {
    return showDialog<String>(
      context: context,
      builder: (context) {
        String selected = 'Prix incorrect';
        final customController = TextEditingController();
        return AlertDialog(
          title: Text('Motif de refus'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              final reasons = [
                'Prix incorrect',
                'Stock indisponible',
                'Informations client incomplètes',
                'Doublon',
                'Autre',
              ];
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final reason in reasons)
                    ListTile(
                      onTap: () => setDialogState(() => selected = reason),
                      leading: Icon(
                        selected == reason
                            ? LucideIcons.checkCircle
                            : LucideIcons.circle,
                        color: selected == reason
                            ? _DashboardManagerState.managerBlue
                            : _DashboardManagerState.managerMuted,
                      ),
                      title: Text(reason),
                    ),
                  if (selected == 'Autre')
                    TextField(
                      controller: customController,
                      decoration: InputDecoration(labelText: 'Motif'),
                    ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  selected == 'Autre'
                      ? customController.text.trim().ifEmpty('Autre')
                      : selected,
                );
              },
              child: Text('Refuser'),
            ),
          ],
        );
      },
    );
  }

  void _showOrderActionError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Impossible de mettre à jour la commande.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _openFilterSheet() {
    var draftStatus = _selectedStatus;
    final commercialController = TextEditingController(text: _commercialFilter);
    final clientController = TextEditingController(text: _clientFilter);
    final categoryController = TextEditingController(text: _categoryFilter);
    final minController = TextEditingController(
      text: _minAmount?.toStringAsFixed(0) ?? '',
    );
    final maxController = TextEditingController(
      text: _maxAmount?.toStringAsFixed(0) ?? '',
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  MediaQuery.of(context).viewInsets.bottom + 18,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filtres avancés',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: _DashboardManagerState.managerText,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 14),
                      _ManagerOrdersBottomStatus(
                        selected: draftStatus,
                        onChanged: (status) {
                          setSheetState(() => draftStatus = status);
                        },
                      ),
                      SizedBox(height: 12),
                      _ManagerFilterField(
                        controller: commercialController,
                        label: 'Commercial',
                      ),
                      _ManagerFilterField(
                        controller: clientController,
                        label: 'Client',
                      ),
                      _ManagerFilterField(
                        controller: categoryController,
                        label: 'Catégorie client',
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _ManagerFilterField(
                              controller: minController,
                              label: 'Montant min',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: _ManagerFilterField(
                              controller: maxController,
                              label: 'Montant max',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedStatus = _ManagerOrderApiStatus.all;
                                  _commercialFilter = '';
                                  _clientFilter = '';
                                  _categoryFilter = '';
                                  _minAmount = null;
                                  _maxAmount = null;
                                });
                                Navigator.pop(context);
                              },
                              child: Text('Réinitialiser'),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedStatus = draftStatus;
                                  _commercialFilter = commercialController.text
                                      .trim();
                                  _clientFilter = clientController.text.trim();
                                  _categoryFilter = categoryController.text
                                      .trim();
                                  _minAmount = double.tryParse(
                                    minController.text.replaceAll(',', '.'),
                                  );
                                  _maxAmount = double.tryParse(
                                    maxController.text.replaceAll(',', '.'),
                                  );
                                });
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _DashboardManagerState.managerBlue,
                                foregroundColor: Colors.white,
                              ),
                              child: Text('Appliquer'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _managerName(MockUserProfile? fallbackUser) {
    final sessionName = CurrentUserSession.currentUser?.fullName.trim() ?? '';
    if (sessionName.isNotEmpty) return sessionName;
    final fallbackName = fallbackUser?.name.trim() ?? '';
    return fallbackName.isNotEmpty ? fallbackName : 'Manager';
  }

  void _redirectAfterBuild(BuildContext context, String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
    });
  }
}

// ignore: unused_element
class _OrdersManagerScreenState extends State<OrdersManagerScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  ManagerOrderStatus _selectedStatus = ManagerOrderStatus.all;
  int _currentPage = 1;
  bool _isLoading = true;
  String? _errorMessage;

  static final _itemsPerPage = 5;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _currentPage = 1);
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final routeEmail = args is Map ? args['email']?.toString() ?? '' : '';
    final sessionUser = CurrentUserSession.currentUser;
    final user = sessionUser?.isManager == true
        ? MockPreSalesData.userByEmail(sessionUser!.email)
        : MockPreSalesData.userByEmail(routeEmail);

    if (sessionUser == null && user == null) {
      _redirectAfterBuild(context, '/login');
      return Scaffold(backgroundColor: Colors.white);
    }
    if (sessionUser?.isCommercial == true ||
        user?.role == MockUserRole.commercial) {
      _redirectAfterBuild(context, '/home-commercial');
      return Scaffold(backgroundColor: Colors.white);
    }
    if (sessionUser?.isAdmin == true || user?.role == MockUserRole.admin) {
      _redirectAfterBuild(context, '/dashboard-admin');
      return Scaffold(backgroundColor: Colors.white);
    }

    final allOrders = _loadOrders();
    final summary = ManagerOrdersMockData.summary(allOrders);
    final filteredOrders = _filteredOrders(allOrders);
    final totalPages = math.max(
      1,
      (filteredOrders.length / _itemsPerPage).ceil(),
    );
    final page = _currentPage.clamp(1, totalPages);
    final pageOrders = filteredOrders
        .skip((page - 1) * _itemsPerPage)
        .take(_itemsPerPage)
        .toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _DashboardManagerState._surface,
      drawer: _ManagerDrawer(),
      body: _ManagerMobileShell(
        selectedTab: _ManagerTab.commandes,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OrdersHeader(
                badgeCount: summary.pendingOrders,
                onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
                onNotificationsPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NotificationsScreen()),
                  );
                },
              ),
              SizedBox(height: 22),
              _OrdersSearchRow(
                controller: _searchController,
                onFilterPressed: _openFilterSheet,
              ),
              SizedBox(height: 18),
              _OrdersStatsGrid(summary: summary),
              SizedBox(height: 18),
              _OrdersStatusTabs(
                selectedStatus: _selectedStatus,
                onChanged: (status) {
                  setState(() {
                    _selectedStatus = status;
                    _currentPage = 1;
                  });
                },
              ),
              SizedBox(height: 14),
              if (_isLoading)
                _CommercialsLoadingState()
              else if (_errorMessage != null)
                _CommercialsEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: AppLocalizations.globalText('Erreur de chargement'),
                  message: _errorMessage!,
                )
              else if (allOrders.isEmpty)
                _CommercialsEmptyState(
                  icon: Icons.receipt_long_rounded,
                  title: AppLocalizations.globalText('Aucune commande'),
                  message: 'Aucune commande disponible pour le moment.',
                )
              else if (filteredOrders.isEmpty)
                _CommercialsEmptyState(
                  icon: Icons.search_off_rounded,
                  title: AppLocalizations.globalText('Aucun résultat'),
                  message: 'Essayez une autre recherche ou un autre statut.',
                )
              else ...[
                _OrdersListCard(
                  orders: pageOrders,
                  onOrderTap: _openOrderDetail,
                ),
                SizedBox(height: 14),
                _OrdersPagination(
                  currentPage: page,
                  totalPages: totalPages,
                  totalItems: filteredOrders.length,
                  visibleCount: pageOrders.length,
                  onPageChanged: (nextPage) {
                    setState(() => _currentPage = nextPage);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<ManagerOrderItem> _loadOrders() {
    try {
      _errorMessage = null;
      return ManagerOrdersMockData.allOrders();
    } catch (_) {
      _errorMessage = 'Impossible de charger les commandes.';
      return [];
    }
  }

  List<ManagerOrderItem> _filteredOrders(List<ManagerOrderItem> source) {
    final query = _searchController.text.trim().toLowerCase();
    return source.where((order) {
      final matchesStatus =
          _selectedStatus == ManagerOrderStatus.all ||
          order.status == _selectedStatus;
      final matchesSearch =
          query.isEmpty ||
          order.orderNumber.toLowerCase().contains(query) ||
          order.clientName.toLowerCase().contains(query) ||
          order.commercialName.toLowerCase().contains(query);
      return matchesStatus && matchesSearch;
    }).toList();
  }

  void _openFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.globalText('Filtrer les commandes'),
                  style: TextStyle(
                    color: _DashboardManagerState._textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 12),
                for (final status in ManagerOrderStatus.values)
                  _FilterOptionTile(
                    label: status.label,
                    selected: _selectedStatus == status,
                    onTap: () {
                      setState(() {
                        _selectedStatus = status;
                        _currentPage = 1;
                      });
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openOrderDetail(ManagerOrderItem order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailCommandeScreen(orderId: order.id),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _redirectAfterBuild(BuildContext context, String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
    });
  }
}

class ReportsManagerScreen extends StatefulWidget {
  ReportsManagerScreen({super.key});

  @override
  State<ReportsManagerScreen> createState() => _ReportsManagerApiScreenState();
}

enum _ReportPeriod {
  today,
  yesterday,
  week,
  month,
  previousMonth,
  last3,
  last6,
  year,
  custom,
}

enum _ReportTab { all, unread, read, missing }

class _ManagerReportView {
  const _ManagerReportView({
    required this.id,
    required this.commercialId,
    required this.commercialName,
    required this.city,
    required this.matricule,
    required this.phone,
    required this.email,
    required this.date,
    required this.sent,
    required this.read,
    required this.summary,
    required this.activities,
    required this.clients,
    required this.calls,
    required this.meetings,
    required this.tasks,
    required this.claims,
    required this.orders,
    required this.comments,
  });

  final int id;
  final int commercialId;
  final String commercialName;
  final String city;
  final String matricule;
  final String phone;
  final String email;
  final DateTime date;
  final bool sent;
  final bool read;
  final String summary;
  final int activities;
  final int clients;
  final int calls;
  final int meetings;
  final int tasks;
  final int claims;
  final int orders;
  final String comments;

  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return commercialName.toLowerCase().contains(q) ||
        matricule.toLowerCase().contains(q) ||
        city.toLowerCase().contains(q) ||
        summary.toLowerCase().contains(q) ||
        _dateLabel(date).contains(q);
  }
}

class _ManagerReportsData {
  const _ManagerReportsData({required this.items, required this.commercials});
  final List<_ManagerReportView> items;
  final List<_ManagerCommercialView> commercials;

  int get sent => items.where((item) => item.sent).length;
  int get read => items.where((item) => item.sent && item.read).length;
  int get unread => items.where((item) => item.sent && !item.read).length;
  int get missing => items.where((item) => !item.sent).length;
  int get expected => commercials.length;
}

class _ReportsManagerApiScreenState extends State<ReportsManagerScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  _ReportPeriod _period = _ReportPeriod.today;
  DateTimeRange? _customRange;
  _ReportTab _tab = _ReportTab.all;
  Future<_ManagerReportsData>? _future;
  String _commercialFilter = '';
  String _cityFilter = '';
  bool? _readFilter;
  bool? _sentFilter;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _future = _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final routeEmail = args is Map ? args['email']?.toString() ?? '' : '';
    final sessionUser = CurrentUserSession.currentUser;
    final user = sessionUser?.isManager == true
        ? MockPreSalesData.userByEmail(sessionUser!.email)
        : MockPreSalesData.userByEmail(routeEmail);

    if (sessionUser == null && user == null) {
      _redirectAfterBuild(context, '/login');
      return Scaffold(backgroundColor: Colors.white);
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _DashboardManagerState.managerSurface,
      drawer: _ManagerDrawer(),
      body: _ManagerMobileShell(
        selectedTab: _ManagerTab.rapports,
        child: RefreshIndicator(
          color: _DashboardManagerState.managerBlue,
          onRefresh: () async => _refresh(),
          child: FutureBuilder<_ManagerReportsData>(
            future: _future,
            builder: (context, snapshot) {
              final data =
                  snapshot.data ??
                  const _ManagerReportsData(items: [], commercials: []);
              final visible = _visible(data.items);
              return SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ManagerHomeHeader(
                      managerName: _managerName(user),
                      unreadCount: data.unread,
                      onMenuPressed: () =>
                          _scaffoldKey.currentState?.openDrawer(),
                      onNotificationsPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NotificationsScreen(),
                        ),
                      ),
                      onAvatarPressed: () {},
                    ),
                    Transform.translate(
                      offset: Offset(0, -10),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.fromLTRB(16, 22, 16, 96),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ManagerReportsTitleRow(
                              period: _period,
                              onPeriodChanged: _changePeriod,
                              onExport: () => _openExportSheet(data),
                            ),
                            SizedBox(height: 18),
                            if (snapshot.connectionState ==
                                ConnectionState.waiting)
                              _ManagerCommercialsSkeleton()
                            else if (snapshot.hasError)
                              _ManagerDashboardError(
                                message: 'Impossible de charger les rapports.',
                                onRetry: _refresh,
                              )
                            else ...[
                              _ManagerReportsKpis(data: data),
                              SizedBox(height: 20),
                              _ManagerReportsSearchFilter(
                                controller: _searchController,
                                activeFiltersCount: _activeFiltersCount,
                                onFilterPressed: _openFilterSheet,
                              ),
                              SizedBox(height: 20),
                              _ManagerReportQuickChips(
                                data: data,
                                selected: _period,
                                onChanged: _changePeriod,
                              ),
                              SizedBox(height: 20),
                              _ManagerReportTabs(
                                data: data,
                                selected: _tab,
                                onChanged: (tab) => setState(() => _tab = tab),
                              ),
                              SizedBox(height: 20),
                              if (visible.isEmpty)
                                _ManagerReportsEmptyState(
                                  hasFilters: _hasFilters,
                                  onReset: _resetFilters,
                                )
                              else
                                _ManagerReportsList(
                                  items: visible,
                                  onOpen: _openReportDetail,
                                  onPdf: _downloadPdf,
                                ),
                              SizedBox(height: 4),
                              _ManagerReportHint(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<_ManagerReportsData> _loadData() async {
    await _syncManagerUnreadNotifications();
    final range = _reportRange(_period, _customRange);
    final users = await _safeApiList(ApiService.getUsers);
    final reportsRaw = await _safeApiList(ApiService.getRapports);
    final commercials = <_ManagerCommercialView>[];
    for (final userJson in users.whereType<Map>().map(
      (e) => e.cast<String, dynamic>(),
    )) {
      final role = _readString(userJson, ['role', 'type']);
      if (!role.toLowerCase().contains('commercial')) continue;
      final id = _readInt(userJson, ['id', 'user_id']);
      commercials.add(
        _ManagerCommercialView(
          id: id,
          name: _readUserDisplayName(userJson).ifEmpty('Commercial'),
          email: _readString(userJson, ['email']),
          phone: _readString(userJson, ['phone', 'telephone']),
          city: _readString(userJson, ['city', 'ville']).ifEmpty('-'),
          address: _readString(userJson, ['address', 'adresse']),
          matricule: _readString(userJson, [
            'matricule',
            'code',
          ]).ifEmpty('COM-${id.toString().padLeft(3, '0')}'),
          role: 'Commercial',
          status: _parseCommercialStatus(
            _readString(userJson, ['status', 'statut', 'etat']),
          ),
          revenue: 0,
          objective: 0,
          ordersCount: 0,
          clientsCount: 0,
          activitiesCount: 0,
          reportsCount: 0,
        ),
      );
    }
    final reports = reportsRaw
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    final sentReports = <_ManagerReportView>[];
    final sentIds = <int>{};
    for (final json in reports) {
      final date =
          _readDate(json, ['date', 'created_at', 'sent_at', 'report_date']) ??
          DateTime.now();
      if (!_dateInRange(date, range)) continue;
      final commercialId =
          _readNullableInt(json, ['commercial_id', 'user_id', 'created_by']) ??
          0;
      final commercial = commercials
          .where((c) => c.id == commercialId)
          .firstOrNull;
      sentIds.add(commercialId);
      sentReports.add(
        _ManagerReportView(
          id: _readInt(json, ['id', 'rapport_id']),
          commercialId: commercialId,
          commercialName: _readString(json, [
            'commercial_name',
            'commercial',
          ]).ifEmpty(commercial?.name ?? 'Commercial'),
          city: _readString(json, [
            'city',
            'ville',
          ]).ifEmpty(commercial?.city ?? '-'),
          matricule: _readString(json, [
            'matricule',
            'code',
          ]).ifEmpty(commercial?.matricule ?? '-'),
          phone: _readString(json, [
            'phone',
            'telephone',
          ]).ifEmpty(commercial?.phone ?? ''),
          email: _readString(json, ['email']).ifEmpty(commercial?.email ?? ''),
          date: date,
          sent: true,
          read: _readBool(json, ['is_read', 'read', 'lu']),
          summary: _readString(json, [
            'summary',
            'resume',
            'content',
            'contenu',
          ]),
          activities: _readInt(json, [
            'activities_count',
            'activites',
            'activities',
          ]),
          clients: _readInt(json, [
            'clients_count',
            'clients_visited',
            'clients',
          ]),
          calls: _readInt(json, ['calls', 'appels']),
          meetings: _readInt(json, ['meetings', 'reunions']),
          tasks: _readInt(json, ['tasks', 'taches']),
          claims: _readInt(json, ['claims', 'reclamations']),
          orders: _readInt(json, ['orders_count', 'commandes']),
          comments: _readString(json, [
            'manager_comment',
            'commentaire_manager',
            'comments',
          ]),
        ),
      );
    }
    for (final commercial in commercials) {
      if (sentIds.contains(commercial.id)) continue;
      sentReports.add(
        _ManagerReportView(
          id: -commercial.id,
          commercialId: commercial.id,
          commercialName: commercial.name,
          city: commercial.city,
          matricule: commercial.matricule,
          phone: commercial.phone,
          email: commercial.email,
          date: range.start,
          sent: false,
          read: false,
          summary: '',
          activities: 0,
          clients: 0,
          calls: 0,
          meetings: 0,
          tasks: 0,
          claims: 0,
          orders: 0,
          comments: '',
        ),
      );
    }
    sentReports.sort((a, b) => b.date.compareTo(a.date));
    return _ManagerReportsData(items: sentReports, commercials: commercials);
  }

  List<_ManagerReportView> _visible(List<_ManagerReportView> source) {
    final query = _searchController.text.trim().toLowerCase();
    return source.where((item) {
      final tabOk = switch (_tab) {
        _ReportTab.all => true,
        _ReportTab.unread => item.sent && !item.read,
        _ReportTab.read => item.sent && item.read,
        _ReportTab.missing => !item.sent,
      };
      return tabOk &&
          item.matches(query) &&
          (_commercialFilter.isEmpty ||
              item.commercialName.toLowerCase().contains(
                _commercialFilter.toLowerCase(),
              )) &&
          (_cityFilter.isEmpty ||
              item.city.toLowerCase().contains(_cityFilter.toLowerCase())) &&
          (_readFilter == null || item.read == _readFilter) &&
          (_sentFilter == null || item.sent == _sentFilter);
    }).toList();
  }

  int get _activeFiltersCount {
    var count = 0;
    if (_commercialFilter.isNotEmpty) count++;
    if (_cityFilter.isNotEmpty) count++;
    if (_readFilter != null) count++;
    if (_sentFilter != null) count++;
    return count;
  }

  bool get _hasFilters =>
      _activeFiltersCount > 0 ||
      _searchController.text.trim().isNotEmpty ||
      _tab != _ReportTab.all;

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _tab = _ReportTab.all;
      _commercialFilter = '';
      _cityFilter = '';
      _readFilter = null;
      _sentFilter = null;
    });
  }

  Future<void> _changePeriod(_ReportPeriod period) async {
    DateTimeRange? range = _customRange;
    if (period == _ReportPeriod.custom) {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 5),
        lastDate: DateTime(now.year + 1),
        initialDateRange:
            range ??
            DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
      );
      if (picked == null) return;
      range = picked;
    }
    setState(() {
      _period = period;
      _customRange = range;
      _future = _loadData();
    });
  }

  void _refresh() => setState(() => _future = _loadData());

  Future<List<dynamic>> _safeApiList(Future<List<dynamic>> Function() loader) =>
      loader().catchError((_) => <dynamic>[]);

  void _openFilterSheet() {
    final commercial = TextEditingController(text: _commercialFilter);
    final city = TextEditingController(text: _cityFilter);
    var read = _readFilter;
    var sent = _sentFilter;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                18,
                18,
                MediaQuery.of(context).viewInsets.bottom + 18,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filtres rapports',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        color: _DashboardManagerState.managerText,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 12),
                    _ManagerFilterField(
                      controller: commercial,
                      label: 'Commercial',
                    ),
                    _ManagerFilterField(controller: city, label: 'Ville'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text('Rapport lu'),
                          selected: read == true,
                          onSelected: (_) => setSheetState(() => read = true),
                        ),
                        ChoiceChip(
                          label: Text('Rapport non lu'),
                          selected: read == false,
                          onSelected: (_) => setSheetState(() => read = false),
                        ),
                        ChoiceChip(
                          label: Text('Envoyé'),
                          selected: sent == true,
                          onSelected: (_) => setSheetState(() => sent = true),
                        ),
                        ChoiceChip(
                          label: Text('Non envoyé'),
                          selected: sent == false,
                          onSelected: (_) => setSheetState(() => sent = false),
                        ),
                      ],
                    ),
                    SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _resetFilters();
                              Navigator.pop(context);
                            },
                            child: Text('Réinitialiser'),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _commercialFilter = commercial.text.trim();
                                _cityFilter = city.text.trim();
                                _readFilter = read;
                                _sentFilter = sent;
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _DashboardManagerState.managerBlue,
                              foregroundColor: Colors.white,
                            ),
                            child: Text('Appliquer'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openExportSheet(_ManagerReportsData data) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(LucideIcons.fileText),
                title: Text('Export PDF'),
                onTap: () {
                  Navigator.pop(context);
                  _exportPdf(data.items);
                },
              ),
              ListTile(
                leading: Icon(LucideIcons.table),
                title: Text('Export Excel'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: Icon(LucideIcons.fileDown),
                title: Text('Export CSV'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openReportDetail(_ManagerReportView report) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _ReportDetailScreen(report: report)),
    ).then((_) => _refresh());
  }

  Future<void> _downloadPdf(_ManagerReportView report) async {
    final bytes = await _buildReportPdf([report]);
    await Printing.sharePdf(bytes: bytes, filename: 'rapport_${report.id}.pdf');
  }

  Future<void> _exportPdf(List<_ManagerReportView> reports) async {
    final bytes = await _buildReportPdf(reports);
    await Printing.sharePdf(bytes: bytes, filename: 'rapports_manager.pdf');
  }

  String _managerName(MockUserProfile? fallbackUser) {
    final sessionName = CurrentUserSession.currentUser?.fullName.trim() ?? '';
    if (sessionName.isNotEmpty) return sessionName;
    final fallbackName = fallbackUser?.name.trim() ?? '';
    return fallbackName.isNotEmpty ? fallbackName : 'Manager';
  }

  void _redirectAfterBuild(BuildContext context, String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
    });
  }
}

// ignore: unused_element
class _ReportsManagerScreenState extends State<ReportsManagerScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  ManagerDashboardPeriod _selectedPeriod = ManagerDashboardPeriod.month;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final routeEmail = args is Map ? args['email']?.toString() ?? '' : '';
    final sessionUser = CurrentUserSession.currentUser;
    final user = sessionUser?.isManager == true
        ? MockPreSalesData.userByEmail(sessionUser!.email)
        : MockPreSalesData.userByEmail(routeEmail);

    if (sessionUser == null && user == null) {
      _redirectAfterBuild(context, '/login');
      return Scaffold(backgroundColor: Colors.white);
    }
    if (sessionUser?.isCommercial == true ||
        user?.role == MockUserRole.commercial) {
      _redirectAfterBuild(context, '/home-commercial');
      return Scaffold(backgroundColor: Colors.white);
    }
    if (sessionUser?.isAdmin == true || user?.role == MockUserRole.admin) {
      _redirectAfterBuild(context, '/dashboard-admin');
      return Scaffold(backgroundColor: Colors.white);
    }

    final reports = _loadReports();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _DashboardManagerState._surface,
      drawer: _ManagerDrawer(),
      body: _ManagerMobileShell(
        selectedTab: _ManagerTab.rapports,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReportsHeader(
                selectedPeriod: _selectedPeriod,
                onPeriodChanged: (period) {
                  setState(() => _selectedPeriod = period);
                },
                onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              SizedBox(height: 16),
              if (_isLoading)
                _CommercialsLoadingState()
              else if (_errorMessage != null)
                _CommercialsEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: AppLocalizations.globalText('Erreur de chargement'),
                  message: _errorMessage!,
                )
              else if (reports.revenueEvolution.isEmpty)
                _CommercialsEmptyState(
                  icon: Icons.insights_rounded,
                  title: AppLocalizations.globalText('Aucune donnée'),
                  message: 'Aucun rapport disponible pour cette période.',
                )
              else ...[
                _RevenueReportCard(
                  data: reports,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RevenueDetailsScreen()),
                    );
                  },
                ),
                SizedBox(height: 16),
                _OrdersStatusReportCard(
                  statuses: reports.statuses,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrdersStatusDetailsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  ReportsData _loadReports() {
    try {
      _errorMessage = null;
      return ManagerReportsMockData.byPeriod(_selectedPeriod);
    } catch (_) {
      _errorMessage = 'Impossible de charger les rapports.';
      return ManagerReportsMockData.byPeriod(ManagerDashboardPeriod.month);
    }
  }

  void _redirectAfterBuild(BuildContext context, String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
    });
  }
}

class _DashboardManagerState extends State<DashboardManager> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  _ManagerDashboardPeriod _selectedPeriod = _ManagerDashboardPeriod.month;
  DateTimeRange? _customRange;
  Future<_ManagerHomeData>? _dashboardFuture;
  Timer? _refreshTimer;

  static const _primaryBlue = Color(0xFF2674F8);
  static const _deepBlue = Color(0xFF155EE8);
  static const _success = Color(0xFF28C77B);
  static const _warning = Color(0xFFFF941A);
  static const _danger = Color(0xFFFF3B30);
  static const _purple = Color(0xFF7C3AED);
  static const _textDark = Color(0xFF14204A);
  static const _textMuted = Color(0xFF6D7790);
  static const _surface = Color(0xFFF7F9FD);
  static const _border = Color(0xFFE7ECF5);

  static const managerHeader = Color(0xFF061B4F);
  static const managerText = Color(0xFF0B1748);
  static const managerMuted = Color(0xFF6F7890);
  static const managerSurface = Color(0xFFF4F7FB);
  static const managerBorder = Color(0xFFE4EAF3);
  static const managerBlue = Color(0xFF2F73FF);
  static const managerGreen = Color(0xFF27C76F);
  static const managerOrange = Color(0xFFFF9800);
  static const managerRed = Color(0xFFFF3B30);
  static const managerPurple = Color(0xFF7C4DFF);
  static const managerCyan = Color(0xFF12A8C8);
  static const iconBlueBg = Color(0xFFEAF2FF);
  static const iconGreenBg = Color(0xFFE8F8EF);
  static const iconOrangeBg = Color(0xFFFFF3E3);
  static const iconRedBg = Color(0xFFFFE8E8);
  static const iconPurpleBg = Color(0xFFF1E9FF);
  static const iconCyanBg = Color(0xFFE6F8FC);

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboard();
    _refreshTimer = Timer.periodic(Duration(seconds: 5), (_) {
      if (mounted) _refreshDashboard(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refreshDashboard({bool silent = false}) {
    final future = _loadDashboard();
    if (!mounted) return;
    setState(() => _dashboardFuture = future);
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final routeEmail = args is Map ? args['email']?.toString() ?? '' : '';
    final sessionUser = CurrentUserSession.currentUser;
    final user = sessionUser?.isManager == true
        ? MockPreSalesData.userByEmail(sessionUser!.email)
        : MockPreSalesData.userByEmail(routeEmail);

    if (sessionUser == null && user == null) {
      _redirectAfterBuild(context, '/login');
      return Scaffold(backgroundColor: Colors.white);
    }
    if (sessionUser?.isCommercial == true ||
        user?.role == MockUserRole.commercial) {
      _redirectAfterBuild(context, '/home-commercial');
      return Scaffold(backgroundColor: Colors.white);
    }
    if (sessionUser?.isAdmin == true || user?.role == MockUserRole.admin) {
      _redirectAfterBuild(context, '/dashboard-admin');
      return Scaffold(backgroundColor: Colors.white);
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: managerSurface,
      drawer: _ManagerDrawer(),
      body: _ManagerMobileShell(
        selectedTab: _ManagerTab.dashboard,
        child: RefreshIndicator(
          color: managerBlue,
          onRefresh: () async => _refreshDashboard(),
          child: FutureBuilder<_ManagerHomeData>(
            future: _dashboardFuture,
            builder: (context, snapshot) {
              return SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ManagerHomeHeader(
                      managerName: _managerName(user),
                      unreadCount: snapshot.data?.unreadNotifications ?? 0,
                      onMenuPressed: () =>
                          _scaffoldKey.currentState?.openDrawer(),
                      onNotificationsPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NotificationsScreen(),
                          ),
                        );
                      },
                      onAvatarPressed: _openProfile,
                    ),
                    Transform.translate(
                      offset: Offset(0, -10),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.fromLTRB(16, 22, 16, 90),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    AppLocalizations.globalText(
                                      'Tableau de bord',
                                    ),
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      color: managerText,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: 10),
                                SizedBox(
                                  width: 120,
                                  height: 42,
                                  child: _ManagerHomePeriodSelector(
                                    selectedPeriod: _selectedPeriod,
                                    customRange: _customRange,
                                    onChanged: _changePeriod,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 18),
                            if (snapshot.connectionState ==
                                ConnectionState.waiting)
                              _ManagerDashboardLoading()
                            else if (snapshot.hasError)
                              _ManagerDashboardError(
                                message:
                                    'Impossible de charger les donnees du tableau de bord.',
                                onRetry: _refreshDashboard,
                              )
                            else
                              _ManagerDashboardContent(
                                data: snapshot.data ?? _ManagerHomeData.empty(),
                                onOpenCommands: _openCommands,
                                onOpenCommercials: _openCommercials,
                                onOpenObjectives: _openObjectives,
                                onOpenReports: _openReports,
                                onOpenProfile: _openProfile,
                                onOpenRecentActivity: _openRecentActivity,
                                onOpenCommercialDetail: _openCommercialDetail,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _managerName(MockUserProfile? fallbackUser) {
    final sessionName = CurrentUserSession.currentUser?.fullName.trim() ?? '';
    if (sessionName.isNotEmpty) return sessionName;
    final fallbackName = fallbackUser?.name.trim() ?? '';
    return fallbackName.isNotEmpty ? fallbackName : 'Manager';
  }

  Future<void> _changePeriod(_ManagerDashboardPeriod period) async {
    DateTimeRange? range = _customRange;
    if (period == _ManagerDashboardPeriod.custom) {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 5),
        lastDate: DateTime(now.year + 1),
        initialDateRange:
            range ??
            DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
      );
      if (picked == null) return;
      range = picked;
    }
    setState(() {
      _selectedPeriod = period;
      _customRange = range;
      _dashboardFuture = _loadDashboard();
    });
  }

  Future<_ManagerHomeData> _loadDashboard() async {
    final range = _selectedPeriod.range(_customRange);
    final results = await Future.wait<List<dynamic>>([
      _safeApiList(
        () => ApiService.getManagerCommandes(
          managerId: CurrentUserSession.currentUser?.id,
        ),
      ),
      _safeApiList(ApiService.getUsers),
      _safeApiList(
        () => ApiService.getNotifications(
          managerId: CurrentUserSession.currentUser?.id,
        ),
      ),
    ]);
    final data = _ManagerHomeData.fromApi(
      factures: results[0],
      users: results[1],
      notifications: results[2],
      range: range,
      period: _selectedPeriod,
    );
    return _applyObjectives(data);
  }

  Future<_ManagerHomeData> _applyObjectives(_ManagerHomeData data) async {
    final updatedCommercials = <_ManagerCommercialPerformance>[];
    var objectiveTotal = 0.0;
    for (final commercial in data.topCommercials) {
      final objective = await CommercialObjectivesService.instance.getObjective(
        commercial.id,
      );
      final revenueTarget = objective?.revenueTarget ?? 0;
      objectiveTotal += revenueTarget;
      updatedCommercials.add(
        _ManagerCommercialPerformance(
          id: commercial.id,
          name: commercial.name,
          revenue: commercial.revenue,
          orderCount: commercial.orderCount,
          objective: revenueTarget,
          objectiveRate: revenueTarget <= 0
              ? 0
              : ((commercial.revenue / revenueTarget) * 100).round(),
        ),
      );
    }
    return data.copyWith(
      topCommercials: updatedCommercials,
      objectiveRate: objectiveTotal <= 0
          ? 0
          : ((data.revenue / objectiveTotal) * 100).round(),
    );
  }

  Future<List<dynamic>> _safeApiList(Future<List<dynamic>> Function() loader) {
    return loader().catchError((_) => <dynamic>[]);
  }

  void _openCommands(String status) {
    Navigator.pushNamed(
      context,
      '/manager-commandes',
      arguments: {
        'status': status,
        'period': _selectedPeriod.name,
        'startDate': _selectedPeriod
            .range(_customRange)
            .start
            .toIso8601String(),
        'endDate': _selectedPeriod.range(_customRange).end.toIso8601String(),
      },
    );
  }

  void _openCommercials({_ManagerCommercialPerformance? selected}) {
    if (selected != null) {
      _openCommercialDetail(selected);
      return;
    }
    Navigator.pushNamed(
      context,
      '/manager-commerciaux',
      arguments: {'sort': 'ca_desc', 'period': _selectedPeriod.name},
    );
  }

  void _openCommercialDetail(_ManagerCommercialPerformance commercial) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailCommercialScreen(
          commercialId: commercial.id,
          commercialName: commercial.name,
        ),
      ),
    );
  }

  void _openObjectives() {
    Navigator.pushNamed(
      context,
      '/manager-objectifs',
      arguments: {'openObjectives': true, 'period': _selectedPeriod.name},
    );
  }

  void _openReports() {
    Navigator.pushNamed(
      context,
      '/manager-rapports',
      arguments: {'period': _selectedPeriod.name},
    );
  }

  void _openProfile() {
    Navigator.pushNamed(context, '/manager-profil');
  }

  void _openRecentActivity(_ManagerRecentActivity activity) {
    if (activity.orderId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailCommandeScreen(orderId: activity.orderId!),
        ),
      );
      return;
    }
    if (activity.type == _ManagerRecentActivityType.report) {
      _openReports();
    } else {
      _openCommands(activity.statusFilter ?? 'all');
    }
  }

  void _redirectAfterBuild(BuildContext context, String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
    });
  }
}

class _Header extends StatelessWidget {
  _Header({
    required this.title,
    required this.onMenuPressed,
    required this.onNotificationsPressed,
    this.showNotificationBadge = false,
  });

  final String title;
  final VoidCallback onMenuPressed;
  final VoidCallback onNotificationsPressed;
  final bool showNotificationBadge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onMenuPressed,
          icon: Icon(Icons.menu_rounded),
          color: _DashboardManagerState._textDark,
          tooltip: 'Menu',
        ),
        SizedBox(width: 2),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: _DashboardManagerState._textDark,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        ValueListenableBuilder<int>(
          valueListenable: _managerUnreadNotifications,
          builder: (context, unread, child) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: onNotificationsPressed,
                  icon: Icon(Icons.notifications_none_rounded),
                  color: _DashboardManagerState._textDark,
                  tooltip: 'Notifications',
                ),
                if (unread > 0)
                  Positioned(
                    right: 7,
                    top: 5,
                    child: Container(
                      constraints: BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: _DashboardManagerState._primaryBlue,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: Colors.white, width: 1.4),
                      ),
                      child: Center(
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ManagerOrdersSummary {
  const _ManagerOrdersSummary({
    required this.total,
    required this.pending,
    required this.validated,
    required this.refused,
  });

  final int total;
  final int pending;
  final int validated;
  final int refused;

  factory _ManagerOrdersSummary.from(List<_ManagerOrderView> orders) {
    int count(_ManagerOrderApiStatus status) =>
        orders.where((order) => order.status == status).length;
    return _ManagerOrdersSummary(
      total: orders.length,
      pending: count(_ManagerOrderApiStatus.pending),
      validated: count(_ManagerOrderApiStatus.validated),
      refused: count(_ManagerOrderApiStatus.refused),
    );
  }

  int countFor(_ManagerOrderApiStatus status) {
    return switch (status) {
      _ManagerOrderApiStatus.all => total,
      _ManagerOrderApiStatus.pending => pending,
      _ManagerOrderApiStatus.validated => validated,
      _ManagerOrderApiStatus.refused => refused,
    };
  }
}

class _ManagerOrdersTitleRow extends StatelessWidget {
  const _ManagerOrdersTitleRow({
    required this.selectedPeriod,
    required this.customRange,
    required this.onPeriodChanged,
  });

  final _ManagerDashboardPeriod selectedPeriod;
  final DateTimeRange? customRange;
  final ValueChanged<_ManagerDashboardPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Commandes',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: _DashboardManagerState.managerText,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Gérez et suivez toutes les commandes de votre équipe',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: _DashboardManagerState.managerMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 10),
        SizedBox(
          width: 120,
          height: 42,
          child: _ManagerHomePeriodSelector(
            selectedPeriod: selectedPeriod,
            customRange: customRange,
            onChanged: onPeriodChanged,
          ),
        ),
      ],
    );
  }
}

class _ManagerCommercialsTitleRow extends StatelessWidget {
  const _ManagerCommercialsTitleRow({
    required this.selectedPeriod,
    required this.customRange,
    required this.onPeriodChanged,
  });

  final _ManagerDashboardPeriod selectedPeriod;
  final DateTimeRange? customRange;
  final ValueChanged<_ManagerDashboardPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Commerciaux',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: _DashboardManagerState.managerText,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Suivez et analysez les performances de votre équipe commerciale',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: _DashboardManagerState.managerMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 10),
        SizedBox(
          width: 120,
          height: 42,
          child: _ManagerHomePeriodSelector(
            selectedPeriod: selectedPeriod,
            customRange: customRange,
            onChanged: onPeriodChanged,
          ),
        ),
      ],
    );
  }
}

class _ManagerObjectivesTitleRow extends StatelessWidget {
  const _ManagerObjectivesTitleRow({
    required this.selectedPeriod,
    required this.customRange,
    required this.onPeriodChanged,
    required this.onDefine,
  });

  final _ManagerDashboardPeriod selectedPeriod;
  final DateTimeRange? customRange;
  final ValueChanged<_ManagerDashboardPeriod> onPeriodChanged;
  final VoidCallback onDefine;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Objectifs',
          style: TextStyle(
            fontFamily: 'Roboto',
            color: _DashboardManagerState.managerText,
            fontSize: 30,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Définissez et suivez les objectifs mensuels de votre équipe commerciale.',
          style: TextStyle(
            fontFamily: 'Roboto',
            color: _DashboardManagerState.managerMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 42,
                child: _ManagerHomePeriodSelector(
                  selectedPeriod: selectedPeriod,
                  customRange: customRange,
                  onChanged: onPeriodChanged,
                ),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: onDefine,
                  icon: Icon(LucideIcons.plus, size: 18),
                  label: FittedBox(child: Text('Définir objectifs')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _DashboardManagerState.managerBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ManagerReportsTitleRow extends StatelessWidget {
  const _ManagerReportsTitleRow({
    required this.period,
    required this.onPeriodChanged,
    required this.onExport,
  });

  final _ReportPeriod period;
  final ValueChanged<_ReportPeriod> onPeriodChanged;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rapports',
          style: TextStyle(
            fontFamily: 'Roboto',
            color: _DashboardManagerState.managerText,
            fontSize: 30,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Consultez et suivez les rapports journaliers envoyés par votre équipe.',
          style: TextStyle(
            fontFamily: 'Roboto',
            color: _DashboardManagerState.managerMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _ReportPeriodSelector(
                period: period,
                onChanged: onPeriodChanged,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: onExport,
                  icon: Icon(LucideIcons.download, size: 17),
                  label: Text('Exporter'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _DashboardManagerState.managerBlue,
                    side: BorderSide(color: _DashboardManagerState.managerBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReportPeriodSelector extends StatelessWidget {
  const _ReportPeriodSelector({required this.period, required this.onChanged});
  final _ReportPeriod period;
  final ValueChanged<_ReportPeriod> onChanged;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _managerCardDecoration(13),
      child: SizedBox(
        height: 48,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<_ReportPeriod>(
            value: period,
            isExpanded: true,
            padding: EdgeInsets.symmetric(horizontal: 8),
            icon: Icon(LucideIcons.chevronDown, size: 16),
            items: _ReportPeriod.values
                .map(
                  (p) => DropdownMenuItem(
                    value: p,
                    child: Text(
                      _reportPeriodLabel(p),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
        ),
      ),
    );
  }
}

class _ManagerReportsKpis extends StatelessWidget {
  const _ManagerReportsKpis({required this.data});
  final _ManagerReportsData data;
  @override
  Widget build(BuildContext context) {
    final expected = data.expected;
    final cards = [
      (
        'Rapports reçus',
        data.sent,
        'Sur $expected commerciaux attendus',
        data.sent / math.max(1, expected),
        LucideIcons.fileText,
        _DashboardManagerState.managerBlue,
      ),
      (
        'Rapports lus',
        data.read,
        '${_pct(data.read, data.sent)}% des reçus',
        data.read / math.max(1, data.sent),
        LucideIcons.checkCircle,
        _DashboardManagerState.managerGreen,
      ),
      (
        'En attente de lecture',
        data.unread,
        '${_pct(data.unread, data.sent)}% des reçus',
        data.unread / math.max(1, data.sent),
        LucideIcons.clock,
        _DashboardManagerState.managerOrange,
      ),
      (
        'Non envoyés',
        data.missing,
        'Sur $expected commerciaux',
        data.missing / math.max(1, expected),
        LucideIcons.xCircle,
        _DashboardManagerState.managerRed,
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.18,
      ),
      itemBuilder: (context, index) {
        final c = cards[index];
        final bg = c.$6.withValues(alpha: .12);
        return Container(
          padding: EdgeInsets.all(10),
          decoration: _managerCardDecoration(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ManagerSoftIcon(
                icon: c.$5,
                color: c.$6,
                backgroundColor: bg,
                size: 30,
              ),
              SizedBox(height: 4),
              Text(
                c.$1,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: _DashboardManagerState.managerText,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 2),
              Text(
                '${c.$2}',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: c.$6,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                c.$3,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: _DashboardManagerState.managerMuted,
                  fontSize: 9.5,
                ),
              ),
              SizedBox(height: 6),
              LinearProgressIndicator(
                value: c.$4.clamp(0, 1),
                minHeight: 5,
                color: c.$6,
                backgroundColor: _DashboardManagerState.managerBorder,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ManagerReportsSearchFilter extends StatelessWidget {
  const _ManagerReportsSearchFilter({
    required this.controller,
    required this.activeFiltersCount,
    required this.onFilterPressed,
  });
  final TextEditingController controller;
  final int activeFiltersCount;
  final VoidCallback onFilterPressed;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Container(
          height: 48,
          decoration: _managerCardDecoration(16),
          child: TextField(
            controller: controller,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: _DashboardManagerState.managerText,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              prefixIcon: Icon(
                LucideIcons.search,
                color: _DashboardManagerState.managerMuted,
                size: 20,
              ),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Effacer',
                      onPressed: controller.clear,
                      icon: Icon(
                        LucideIcons.x,
                        color: _DashboardManagerState.managerMuted,
                        size: 18,
                      ),
                    ),
              hintText: 'Rechercher un rapport ou un commercial...',
              hintStyle: TextStyle(
                fontFamily: 'Roboto',
                color: _DashboardManagerState.managerMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
      SizedBox(width: 10),
      InkWell(
        onTap: onFilterPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: 13),
          decoration: _managerCardDecoration(16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.filter,
                color: _DashboardManagerState.managerText,
                size: 19,
              ),
              SizedBox(width: 7),
              Text(
                activeFiltersCount > 0
                    ? 'Filtres ($activeFiltersCount)'
                    : 'Filtres',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: _DashboardManagerState.managerText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _ManagerReportQuickChips extends StatelessWidget {
  const _ManagerReportQuickChips({
    required this.data,
    required this.selected,
    required this.onChanged,
  });
  final _ManagerReportsData data;
  final _ReportPeriod selected;
  final ValueChanged<_ReportPeriod> onChanged;
  @override
  Widget build(BuildContext context) {
    final chips = [
      (_ReportPeriod.today, "Aujourd'hui", data.sent),
      (_ReportPeriod.week, 'Cette semaine', data.sent),
      (_ReportPeriod.month, 'Ce mois', data.sent),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _ReportChip(
            label: 'Tous',
            count: data.items.length,
            selected: false,
            onTap: () {},
          ),
          SizedBox(width: 10),
          for (final chip in chips) ...[
            _ReportChip(
              label: chip.$2,
              count: chip.$3,
              selected: selected == chip.$1,
              onTap: () => onChanged(chip.$1),
            ),
            SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _ReportChip extends StatelessWidget {
  const _ReportChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(15),
    child: Container(
      height: 48,
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: selected ? _DashboardManagerState.managerBlue : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: selected
              ? _DashboardManagerState.managerBlue
              : _DashboardManagerState.managerBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: selected
                  ? Colors.white
                  : _DashboardManagerState.managerText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 8),
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white
                  : _DashboardManagerState.iconGreenBg,
              shape: BoxShape.circle,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: selected
                      ? _DashboardManagerState.managerBlue
                      : _DashboardManagerState.managerGreen,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ManagerReportTabs extends StatelessWidget {
  const _ManagerReportTabs({
    required this.data,
    required this.selected,
    required this.onChanged,
  });
  final _ManagerReportsData data;
  final _ReportTab selected;
  final ValueChanged<_ReportTab> onChanged;
  @override
  Widget build(BuildContext context) {
    final tabs = [
      (_ReportTab.all, 'Tous les rapports', data.items.length),
      (_ReportTab.unread, 'À lire', data.unread),
      (_ReportTab.read, 'Lus', data.read),
      (_ReportTab.missing, 'Non envoyés', data.missing),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in tabs)
            Padding(
              padding: EdgeInsets.only(right: 8),
              child: _ManagerReportTabButton(
                label: tab.$2,
                count: tab.$3,
                selected: selected == tab.$1,
                onTap: () => onChanged(tab.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _ManagerReportTabButton extends StatelessWidget {
  const _ManagerReportTabButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      height: 46,
      padding: EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: selected
            ? _DashboardManagerState.managerBlue.withValues(alpha: .08)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? _DashboardManagerState.managerBlue
              : _DashboardManagerState.managerBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: selected
                  ? _DashboardManagerState.managerBlue
                  : _DashboardManagerState.managerText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 8),
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? _DashboardManagerState.managerBlue
                  : _DashboardManagerState.managerBorder,
              shape: BoxShape.circle,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: selected
                      ? Colors.white
                      : _DashboardManagerState.managerMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ManagerReportsList extends StatelessWidget {
  const _ManagerReportsList({
    required this.items,
    required this.onOpen,
    required this.onPdf,
  });
  final List<_ManagerReportView> items;
  final ValueChanged<_ManagerReportView> onOpen;
  final ValueChanged<_ManagerReportView> onPdf;
  @override
  Widget build(BuildContext context) => Container(
    decoration: _managerCardDecoration(18),
    child: Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          _ManagerDailyReportCard(
            report: items[i],
            onOpen: () => onOpen(items[i]),
            onPdf: items[i].sent ? () => onPdf(items[i]) : null,
          ),
          if (i != items.length - 1)
            Divider(height: 1, color: _DashboardManagerState.managerBorder),
        ],
      ],
    ),
  );
}

class _ManagerDailyReportCard extends StatelessWidget {
  const _ManagerDailyReportCard({
    required this.report,
    required this.onOpen,
    this.onPdf,
  });
  final _ManagerReportView report;
  final VoidCallback onOpen;
  final VoidCallback? onPdf;
  @override
  Widget build(BuildContext context) {
    final color = !report.sent
        ? _DashboardManagerState.managerRed
        : report.read
        ? _DashboardManagerState.managerGreen
        : _DashboardManagerState.managerOrange;
    final label = !report.sent
        ? 'Non envoyé'
        : report.read
        ? 'Lu'
        : 'En attente';
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: _DashboardManagerState.iconBlueBg,
              child: Text(
                _initials(report.commercialName),
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: _DashboardManagerState.managerBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.commercialName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: _DashboardManagerState.managerText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    report.city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: _DashboardManagerState.managerMuted,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    'Matricule : ${report.matricule}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: _DashboardManagerState.managerMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dateLabel(report.date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: _DashboardManagerState.managerText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    report.sent
                        ? 'Envoyé à ${_timeLabel(report.date)}'
                        : 'Non envoyé',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: report.sent
                          ? _DashboardManagerState.managerMuted
                          : _DashboardManagerState.managerRed,
                      fontSize: 10,
                    ),
                  ),
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    report.sent
                        ? '${report.activities} activités, ${report.clients} clients'
                        : 'Aucun rapport',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: _DashboardManagerState.managerMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            if (onPdf != null)
              IconButton(
                onPressed: onPdf,
                icon: Icon(
                  LucideIcons.download,
                  color: _DashboardManagerState.managerBlue,
                  size: 20,
                ),
              ),
            CircleAvatar(
              radius: 17,
              backgroundColor: _DashboardManagerState.iconBlueBg,
              child: Icon(
                LucideIcons.chevronRight,
                color: _DashboardManagerState.managerBlue,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagerReportsEmptyState extends StatelessWidget {
  const _ManagerReportsEmptyState({
    required this.hasFilters,
    required this.onReset,
  });
  final bool hasFilters;
  final VoidCallback onReset;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.fromLTRB(22, 30, 22, 28),
    decoration: _managerCardDecoration(20),
    child: Column(
      children: [
        _ManagerSoftIcon(
          icon: LucideIcons.fileText,
          color: _DashboardManagerState.managerBlue,
          backgroundColor: _DashboardManagerState.iconBlueBg,
          size: 76,
        ),
        SizedBox(height: 16),
        Text(
          'Aucun rapport disponible pour cette période.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Roboto',
            color: _DashboardManagerState.managerText,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 8),
        Text(
          hasFilters
              ? 'Aucun rapport ne correspond aux filtres.'
              : 'Les rapports envoyés apparaîtront ici.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Roboto',
            color: _DashboardManagerState.managerMuted,
            fontSize: 12,
          ),
        ),
        if (hasFilters) ...[
          SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onReset,
            icon: Icon(LucideIcons.rotateCcw, size: 17),
            label: Text('Réinitialiser les filtres'),
          ),
        ],
      ],
    ),
  );
}

class _ManagerReportHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.only(top: 4),
    padding: EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _DashboardManagerState.iconBlueBg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: _DashboardManagerState.managerBlue.withValues(alpha: .35),
      ),
    ),
    child: Row(
      children: [
        Icon(LucideIcons.info, color: _DashboardManagerState.managerBlue),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Les rapports sont générés par les commerciaux chaque jour.',
            style: TextStyle(
              fontFamily: 'Roboto',
              color: _DashboardManagerState.managerText,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ReportDetailScreen extends StatelessWidget {
  const _ReportDetailScreen({required this.report});
  final _ManagerReportView report;
  @override
  Widget build(BuildContext context) => _DetailOrderShell(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(18, 14, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(LucideIcons.arrowLeft),
            color: _DashboardManagerState.managerText,
          ),
          SizedBox(height: 12),
          _ManagerDetailCard(
            children: [
              _ManagerDetailLine('Commercial', report.commercialName),
              _ManagerDetailLine('Téléphone', report.phone.ifEmpty('-')),
              _ManagerDetailLine('Email', report.email.ifEmpty('-')),
              _ManagerDetailLine('Ville', report.city),
              _ManagerDetailLine('Matricule', report.matricule),
              _ManagerDetailLine(
                'Date',
                '${_dateLabel(report.date)} • ${_timeLabel(report.date)}',
              ),
            ],
          ),
          SizedBox(height: 14),
          _ManagerDetailCard(
            title: 'Rapport journalier complet',
            children: [
              _ManagerDetailLine(
                'Résumé',
                report.summary.ifEmpty(
                  report.sent ? '-' : 'Aucun rapport disponible.',
                ),
              ),
              _ManagerDetailLine('Visites', '${report.clients}'),
              _ManagerDetailLine('Appels', '${report.calls}'),
              _ManagerDetailLine('Réunions', '${report.meetings}'),
              _ManagerDetailLine('Tâches', '${report.tasks}'),
              _ManagerDetailLine('Réclamations', '${report.claims}'),
              _ManagerDetailLine('Commandes créées', '${report.orders}'),
              _ManagerDetailLine('Commentaires', report.comments.ifEmpty('-')),
            ],
          ),
          SizedBox(height: 14),
          _ManagerDetailCard(
            title: 'Actions Manager',
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DetailActionChip(
                    'Marquer comme lu',
                    LucideIcons.checkCircle,
                  ),
                  _DetailActionChip(
                    'Ajouter commentaire',
                    LucideIcons.messageSquare,
                  ),
                  _DetailActionChip('Télécharger PDF', LucideIcons.download),
                  _DetailActionChip('Partager', LucideIcons.share2),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Future<Uint8List> _buildReportPdf(List<_ManagerReportView> reports) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      build: (context) => [
        pw.Text(
          'Rapports Manager',
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 16),
        for (final report in reports)
          pw.Container(
            margin: pw.EdgeInsets.only(bottom: 14),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  report.commercialName,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text('Date: ${_dateLabel(report.date)}'),
                pw.Text('Resume: ${report.summary}'),
                pw.Text(
                  'Activites: ${report.activities} - Clients: ${report.clients} - Commandes: ${report.orders}',
                ),
                pw.Text('Commentaires: ${report.comments}'),
              ],
            ),
          ),
      ],
    ),
  );
  return doc.save();
}

int _pct(int value, int total) =>
    total == 0 ? 0 : ((value / total) * 100).round();
String _dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String _timeLabel(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
bool _readBool(Map<dynamic, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String)
      return value.toLowerCase() == 'true' ||
          value == '1' ||
          value.toLowerCase() == 'lu';
  }
  return false;
}

DateTimeRange _reportRange(_ReportPeriod period, DateTimeRange? custom) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return switch (period) {
    _ReportPeriod.today => DateTimeRange(
      start: today,
      end: today.add(Duration(days: 1)).subtract(Duration(milliseconds: 1)),
    ),
    _ReportPeriod.yesterday => DateTimeRange(
      start: today.subtract(Duration(days: 1)),
      end: today.subtract(Duration(milliseconds: 1)),
    ),
    _ReportPeriod.week => DateTimeRange(
      start: today.subtract(Duration(days: today.weekday - 1)),
      end: today.add(Duration(days: 1)).subtract(Duration(milliseconds: 1)),
    ),
    _ReportPeriod.month => DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(
        now.year,
        now.month + 1,
        1,
      ).subtract(Duration(milliseconds: 1)),
    ),
    _ReportPeriod.previousMonth => DateTimeRange(
      start: DateTime(now.year, now.month - 1, 1),
      end: DateTime(now.year, now.month, 1).subtract(Duration(milliseconds: 1)),
    ),
    _ReportPeriod.last3 => DateTimeRange(
      start: DateTime(now.year, now.month - 2, 1),
      end: now,
    ),
    _ReportPeriod.last6 => DateTimeRange(
      start: DateTime(now.year, now.month - 5, 1),
      end: now,
    ),
    _ReportPeriod.year => DateTimeRange(
      start: DateTime(now.year, 1, 1),
      end: now,
    ),
    _ReportPeriod.custom =>
      custom ??
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
  };
}

String _reportPeriodLabel(_ReportPeriod period) => switch (period) {
  _ReportPeriod.today => "Aujourd'hui",
  _ReportPeriod.yesterday => 'Hier',
  _ReportPeriod.week => 'Cette semaine',
  _ReportPeriod.month => 'Ce mois',
  _ReportPeriod.previousMonth => 'Mois précédent',
  _ReportPeriod.last3 => '3 derniers mois',
  _ReportPeriod.last6 => '6 derniers mois',
  _ReportPeriod.year => 'Cette année',
  _ReportPeriod.custom => 'Période personnalisée',
};

class _ManagerObjectivesKpis extends StatelessWidget {
  const _ManagerObjectivesKpis({required this.data});
  final _ManagerCommercialsData data;

  @override
  Widget build(BuildContext context) {
    final orderTarget = data.items.fold<int>(
      0,
      (sum, item) => sum + item.reportsCount,
    );
    final revenueTarget = data.items.fold<double>(
      0,
      (sum, item) => sum + item.objective,
    );
    final cards = [
      (
        'Commerciaux',
        '${data.total}',
        'Total de l’équipe',
        LucideIcons.target,
        _DashboardManagerState.managerBlue,
        _DashboardManagerState.iconBlueBg,
      ),
      (
        'Objectif CA total',
        '${_formatNumber(revenueTarget.round())} DH',
        'Mois sélectionné',
        LucideIcons.trendingUp,
        _DashboardManagerState.managerGreen,
        _DashboardManagerState.iconGreenBg,
      ),
      (
        'Objectif Commandes',
        '$orderTarget',
        'Mois sélectionné',
        LucideIcons.shoppingCart,
        _DashboardManagerState.managerPurple,
        _DashboardManagerState.iconPurpleBg,
      ),
      (
        'Atteinte moyenne',
        '${data.objectiveRate}%',
        'vs mois précédent',
        LucideIcons.clock,
        _DashboardManagerState.managerOrange,
        _DashboardManagerState.iconOrangeBg,
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.18,
      ),
      itemBuilder: (context, index) {
        final item = cards[index];
        return Container(
          padding: EdgeInsets.all(11),
          decoration: _managerCardDecoration(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ManagerSoftIcon(
                icon: item.$4,
                color: item.$5,
                backgroundColor: item.$6,
                size: 34,
              ),
              SizedBox(height: 6),
              Text(
                item.$1,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: _DashboardManagerState.managerText,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 3),
              Text(
                item.$2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: item.$5,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 1),
              Text(
                item.$3,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: _DashboardManagerState.managerMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ManagerObjectivesSearchFilter extends StatelessWidget {
  const _ManagerObjectivesSearchFilter({
    required this.controller,
    required this.activeFiltersCount,
    required this.onFilterPressed,
  });

  final TextEditingController controller;
  final int activeFiltersCount;
  final VoidCallback onFilterPressed;

  @override
  Widget build(BuildContext context) {
    return _ManagerOrdersSearchAndFilter(
      controller: controller,
      activeFiltersCount: activeFiltersCount,
      onFilterPressed: onFilterPressed,
    );
  }
}

class _ManagerObjectiveChips extends StatelessWidget {
  const _ManagerObjectiveChips({
    required this.selected,
    required this.data,
    required this.onChanged,
  });
  final _ObjectiveChipFilter selected;
  final _ManagerCommercialsData data;
  final ValueChanged<_ObjectiveChipFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final withObj = data.items
        .where((item) => item.objective > 0 || item.reportsCount > 0)
        .length;
    final chips = [
      (_ObjectiveChipFilter.all, 'Tous', data.total),
      (_ObjectiveChipFilter.withObjective, 'Avec objectifs', withObj),
      (
        _ObjectiveChipFilter.withoutObjective,
        'Sans objectifs',
        data.total - withObj,
      ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final chip in chips) ...[
            InkWell(
              onTap: () => onChanged(chip.$1),
              borderRadius: BorderRadius.circular(15),
              child: Container(
                height: 48,
                constraints: BoxConstraints(minWidth: 142),
                padding: EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: selected == chip.$1
                      ? _DashboardManagerState.managerBlue
                      : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: selected == chip.$1
                        ? _DashboardManagerState.managerBlue
                        : _DashboardManagerState.managerBorder,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      chip.$2,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        color: selected == chip.$1
                            ? Colors.white
                            : _DashboardManagerState.managerText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      constraints: BoxConstraints(minWidth: 24, minHeight: 24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected == chip.$1
                            ? Colors.white
                            : _DashboardManagerState.iconOrangeBg,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${chip.$3}',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: selected == chip.$1
                              ? _DashboardManagerState.managerBlue
                              : _DashboardManagerState.managerOrange,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _ManagerObjectiveCard extends StatelessWidget {
  const _ManagerObjectiveCard({required this.commercial, required this.onTap});
  final _ManagerCommercialView commercial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rate = commercial.objectiveRate;
    final orderRate = commercial.reportsCount <= 0
        ? 0
        : ((commercial.ordersCount / commercial.reportsCount) * 100).round();
    final color = _objectiveRateColor(rate);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border(
            left: BorderSide(color: color, width: 4),
            top: BorderSide(color: _DashboardManagerState.managerBorder),
            right: BorderSide(color: _DashboardManagerState.managerBorder),
            bottom: BorderSide(color: _DashboardManagerState.managerBorder),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .04),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _DashboardManagerState.iconBlueBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _initials(commercial.name).ifEmpty('C'),
                    style: TextStyle(
                      color: _DashboardManagerState.managerBlue,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        commercial.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _DashboardManagerState.managerText,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        commercial.email.ifEmpty(commercial.role),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _DashboardManagerState.managerMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  LucideIcons.chevronRight,
                  color: _DashboardManagerState.managerMuted,
                ),
              ],
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ObjectiveInfoPill(
                  label: 'Objectif CA',
                  value: '${_formatNumber(commercial.objective.round())} DH',
                ),
                _ObjectiveInfoPill(
                  label: 'Objectif cmd',
                  value: '${commercial.reportsCount}',
                ),
                _ObjectiveInfoPill(
                  label: 'CA atteint',
                  value: '$rate%',
                  valueColor: color,
                ),
                _ObjectiveInfoPill(
                  label: 'Cmd atteint',
                  value: '$orderRate%',
                  valueColor: _objectiveRateColor(orderRate),
                ),
              ],
            ),
            SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (rate / 100).clamp(0, 1),
                minHeight: 6,
                color: color,
                backgroundColor: _DashboardManagerState.managerBorder,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ObjectiveInfoPill extends StatelessWidget {
  const _ObjectiveInfoPill({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 138,
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _DashboardManagerState.managerSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _DashboardManagerState.managerBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _DashboardManagerState.managerMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? _DashboardManagerState.managerText,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagerObjectiveEmptyState extends StatelessWidget {
  const _ManagerObjectiveEmptyState({
    required this.hasFilters,
    required this.onReset,
    required this.onDefine,
  });
  final bool hasFilters;
  final VoidCallback onReset;
  final VoidCallback onDefine;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22, 30, 22, 28),
      decoration: _managerCardDecoration(20),
      child: Column(
        children: [
          _ManagerSoftIcon(
            icon: LucideIcons.target,
            color: _DashboardManagerState.managerBlue,
            backgroundColor: _DashboardManagerState.iconBlueBg,
            size: 76,
          ),
          SizedBox(height: 16),
          Text(
            'Aucun objectif défini pour cette période.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: _DashboardManagerState.managerText,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            hasFilters
                ? 'Aucun objectif ne correspond aux filtres.'
                : 'Définissez des objectifs pour suivre les performances.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: _DashboardManagerState.managerMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: hasFilters ? onReset : onDefine,
            icon: Icon(
              hasFilters ? LucideIcons.rotateCcw : LucideIcons.plus,
              size: 17,
            ),
            label: Text(
              hasFilters ? 'Réinitialiser les filtres' : 'Définir un objectif',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _DashboardManagerState.managerBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagerObjectiveHint extends StatelessWidget {
  const _ManagerObjectiveHint({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 4),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _DashboardManagerState.iconBlueBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _DashboardManagerState.managerBlue.withValues(alpha: .35),
        ),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.info, color: _DashboardManagerState.managerBlue),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Définissez les objectifs manquants pour améliorer le suivi.',
              style: TextStyle(
                fontFamily: 'Roboto',
                color: _DashboardManagerState.managerText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(onPressed: onTap, child: Text('Voir')),
        ],
      ),
    );
  }
}

Color _objectiveRateColor(int rate) {
  if (rate >= 100) return _DashboardManagerState.managerGreen;
  if (rate >= 90) return _DashboardManagerState.managerBlue;
  if (rate >= 70) return _DashboardManagerState.managerOrange;
  return _DashboardManagerState.managerRed;
}

class _ManagerCommercialsKpis extends StatelessWidget {
  const _ManagerCommercialsKpis({required this.data});

  final _ManagerCommercialsData data;

  @override
  Widget build(BuildContext context) {
    final activePct = data.total == 0
        ? 0
        : ((data.active / data.total) * 100).round();
    final cards = [
      (
        'Total commerciaux',
        data.total.toString(),
        'Tous les commerciaux',
        LucideIcons.users,
        _DashboardManagerState.managerBlue,
        _DashboardManagerState.iconBlueBg,
      ),
      (
        "Actifs aujourd'hui",
        data.active.toString(),
        '$activePct% de l’équipe active',
        LucideIcons.userCheck,
        _DashboardManagerState.managerGreen,
        _DashboardManagerState.iconGreenBg,
      ),
      (
        'CA total du mois',
        '${_formatNumber(data.revenue.round())} DH',
        'Commandes validées',
        LucideIcons.coins,
        _DashboardManagerState.managerPurple,
        _DashboardManagerState.iconPurpleBg,
      ),
      (
        'Objectif atteint',
        '${data.objectiveRate}%',
        'Objectif global',
        LucideIcons.target,
        _DashboardManagerState.managerOrange,
        _DashboardManagerState.iconOrangeBg,
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.18,
      ),
      itemBuilder: (context, index) {
        final item = cards[index];
        return Container(
          padding: EdgeInsets.all(11),
          decoration: _managerCardDecoration(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ManagerSoftIcon(
                icon: item.$4,
                color: item.$5,
                backgroundColor: item.$6,
                size: 34,
              ),
              SizedBox(height: 6),
              Text(
                item.$1,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: _DashboardManagerState.managerText,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 3),
              Text(
                item.$2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: item.$5,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 1),
              Text(
                item.$3,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: _DashboardManagerState.managerMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ManagerCommercialSearchFilter extends StatelessWidget {
  const _ManagerCommercialSearchFilter({
    required this.controller,
    required this.activeFiltersCount,
    required this.onFilterPressed,
  });

  final TextEditingController controller;
  final int activeFiltersCount;
  final VoidCallback onFilterPressed;

  @override
  Widget build(BuildContext context) {
    return _ManagerOrdersSearchAndFilter(
      controller: controller,
      activeFiltersCount: activeFiltersCount,
      onFilterPressed: onFilterPressed,
    );
  }
}

class _ManagerCommercialChips extends StatelessWidget {
  const _ManagerCommercialChips({
    required this.selected,
    required this.data,
    required this.onChanged,
  });

  final _ManagerCommercialStatus selected;
  final _ManagerCommercialsData data;
  final ValueChanged<_ManagerCommercialStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final chips = [
      (_ManagerCommercialStatus.all, 'Tous', data.total),
      (_ManagerCommercialStatus.active, 'Actifs', data.active),
      (_ManagerCommercialStatus.leave, 'En congé', data.leave),
      (_ManagerCommercialStatus.disabled, 'Désactivés', data.disabled),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final chip in chips) ...[
            InkWell(
              onTap: () => onChanged(chip.$1),
              borderRadius: BorderRadius.circular(15),
              child: Container(
                height: 48,
                constraints: BoxConstraints(minWidth: 112),
                padding: EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: selected == chip.$1
                      ? _DashboardManagerState.managerBlue
                      : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: selected == chip.$1
                        ? _DashboardManagerState.managerBlue
                        : _DashboardManagerState.managerBorder,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      chip.$2,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        color: selected == chip.$1
                            ? Colors.white
                            : _DashboardManagerState.managerText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      constraints: BoxConstraints(minWidth: 24, minHeight: 24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected == chip.$1
                            ? Colors.white
                            : _commercialStatusStyle(chip.$1).bg,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${chip.$3}',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: selected == chip.$1
                              ? _DashboardManagerState.managerBlue
                              : _commercialStatusStyle(chip.$1).fg,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _ManagerCommercialTop3 extends StatelessWidget {
  const _ManagerCommercialTop3({
    required this.items,
    required this.onViewAll,
    required this.onTap,
  });

  final List<_ManagerCommercialView> items;
  final VoidCallback onViewAll;
  final ValueChanged<_ManagerCommercialView> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14),
      decoration: _managerCardDecoration(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Top 3 des commerciaux',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: _DashboardManagerState.managerText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(onPressed: onViewAll, child: Text('Voir tout')),
            ],
          ),
          if (items.isEmpty)
            _ManagerEmptyInline(
              icon: LucideIcons.users,
              text: 'Aucune performance disponible.',
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => onTap(items[i]),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 3),
                        padding: EdgeInsets.all(i == 0 ? 12 : 10),
                        decoration: BoxDecoration(
                          color: i == 0 ? Color(0xFFFFFBED) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: i == 0
                                ? _DashboardManagerState.managerOrange
                                : _DashboardManagerState.managerBorder,
                          ),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: i == 0 ? 25 : 22,
                              backgroundColor:
                                  _DashboardManagerState.iconBlueBg,
                              child: Text(
                                _initials(items[i].name),
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  color: _DashboardManagerState.managerBlue,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              items[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                color: _DashboardManagerState.managerText,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${_formatNumber(items[i].revenue.round())} DH',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                color: _DashboardManagerState.managerBlue,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 5),
                            LinearProgressIndicator(
                              value: (items[i].objectiveRate / 100).clamp(0, 1),
                              minHeight: 4,
                              color: items[i].objectiveRate >= 100
                                  ? _DashboardManagerState.managerGreen
                                  : _DashboardManagerState.managerBlue,
                              backgroundColor:
                                  _DashboardManagerState.managerBorder,
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${items[i].objectiveRate}%',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                color: _DashboardManagerState.managerText,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ManagerCommercialModernCard extends StatelessWidget {
  const _ManagerCommercialModernCard({
    required this.commercial,
    required this.onTap,
  });

  final _ManagerCommercialView commercial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _commercialStatusStyle(commercial.status);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: _managerCardDecoration(18),
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: _DashboardManagerState.iconBlueBg,
                      child: Text(
                        _initials(commercial.name),
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: _DashboardManagerState.managerBlue,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: CircleAvatar(radius: 6, backgroundColor: style.fg),
                    ),
                  ],
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        commercial.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: _DashboardManagerState.managerText,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        commercial.role,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: _DashboardManagerState.managerMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _SmallPill(
                            icon: LucideIcons.mapPin,
                            label: commercial.city,
                          ),
                          _SmallPill(label: 'ID : ${commercial.matricule}'),
                        ],
                      ),
                    ],
                  ),
                ),
                _CommercialStatusBadge(status: commercial.status),
                Icon(
                  LucideIcons.chevronRight,
                  color: _DashboardManagerState.managerMuted,
                  size: 20,
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MiniCommercialMetric(
                    label: 'CA du mois',
                    value: '${_formatNumber(commercial.revenue.round())} DH',
                    color: _DashboardManagerState.managerBlue,
                  ),
                ),
                Expanded(
                  child: _MiniCommercialMetric(
                    label: 'Objectif',
                    value: commercial.objective <= 0
                        ? '0 DH'
                        : '${_formatNumber(commercial.objective.round())} DH',
                  ),
                ),
                Expanded(
                  child: _MiniCommercialMetric(
                    label: 'Commandes',
                    value: '${commercial.ordersCount}',
                  ),
                ),
                Expanded(
                  child: _MiniCommercialMetric(
                    label: 'Clients',
                    value: '${commercial.clientsCount}',
                  ),
                ),
              ],
            ),
            SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (commercial.objectiveRate / 100).clamp(0, 1),
                minHeight: 5,
                color: commercial.objectiveRate >= 100
                    ? _DashboardManagerState.managerGreen
                    : _DashboardManagerState.managerBlue,
                backgroundColor: _DashboardManagerState.managerBorder,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagerOrdersKpiGrid extends StatelessWidget {
  const _ManagerOrdersKpiGrid({required this.summary});

  final _ManagerOrdersSummary summary;

  @override
  Widget build(BuildContext context) {
    final total = summary.total;
    final cards = [
      (
        'En attente',
        summary.pending,
        _DashboardManagerState.managerOrange,
        _DashboardManagerState.iconOrangeBg,
        LucideIcons.clock,
      ),
      (
        'Validées',
        summary.validated,
        _DashboardManagerState.managerGreen,
        _DashboardManagerState.iconGreenBg,
        LucideIcons.checkCircle,
      ),
      (
        'Refusées',
        summary.refused,
        _DashboardManagerState.managerRed,
        _DashboardManagerState.iconRedBg,
        LucideIcons.xCircle,
      ),
      (
        'Total commandes',
        total,
        _DashboardManagerState.managerBlue,
        _DashboardManagerState.iconBlueBg,
        LucideIcons.shoppingCart,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.18,
      ),
      itemBuilder: (context, index) {
        final item = cards[index];
        final percent = total == 0 ? 0.0 : (item.$2 / total) * 100;
        return Container(
          padding: EdgeInsets.all(11),
          decoration: _managerCardDecoration(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ManagerSoftIcon(
                icon: item.$5,
                color: item.$3,
                backgroundColor: item.$4,
                size: 34,
              ),
              SizedBox(height: 6),
              Text(
                item.$1,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: _DashboardManagerState.managerText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 3),
              Text(
                '${item.$2}',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: item.$3,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 1),
              Text(
                '${percent.toStringAsFixed(total == 0 ? 0 : 1)}% du total',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: _DashboardManagerState.managerMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ManagerOrdersSearchAndFilter extends StatelessWidget {
  const _ManagerOrdersSearchAndFilter({
    required this.controller,
    required this.activeFiltersCount,
    required this.onFilterPressed,
  });

  final TextEditingController controller;
  final int activeFiltersCount;
  final VoidCallback onFilterPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              style: TextStyle(
                fontFamily: 'Roboto',
                color: _DashboardManagerState.managerText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Rechercher une commande, client...',
                hintStyle: TextStyle(
                  fontFamily: 'Roboto',
                  color: _DashboardManagerState.managerMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Icon(
                  LucideIcons.search,
                  color: _DashboardManagerState.managerMuted,
                  size: 20,
                ),
                suffixIcon: controller.text.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: controller.clear,
                        icon: Icon(LucideIcons.x, size: 18),
                        color: _DashboardManagerState.managerMuted,
                      ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.zero,
                enabledBorder: _managerInputBorder(),
                focusedBorder: _managerInputBorder(
                  color: _DashboardManagerState.managerBlue,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 8),
        SizedBox(
          height: 52,
          width: 104,
          child: OutlinedButton(
            onPressed: onFilterPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: _DashboardManagerState.managerText,
              backgroundColor: Colors.white,
              side: BorderSide(color: _DashboardManagerState.managerBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.filter, size: 18),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Filtres',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (activeFiltersCount > 0) ...[
                  SizedBox(width: 5),
                  Container(
                    constraints: BoxConstraints(minWidth: 18, minHeight: 18),
                    padding: EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: _DashboardManagerState.managerBlue,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$activeFiltersCount',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ManagerOrdersStatusChips extends StatelessWidget {
  const _ManagerOrdersStatusChips({
    required this.selectedStatus,
    required this.summary,
    required this.onChanged,
  });

  final _ManagerOrderApiStatus selectedStatus;
  final _ManagerOrdersSummary summary;
  final ValueChanged<_ManagerOrderApiStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final statuses = [
      _ManagerOrderApiStatus.all,
      _ManagerOrderApiStatus.pending,
      _ManagerOrderApiStatus.validated,
      _ManagerOrderApiStatus.refused,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final status in statuses) ...[
            InkWell(
              onTap: () => onChanged(status),
              borderRadius: BorderRadius.circular(15),
              child: Container(
                height: 48,
                constraints: BoxConstraints(minWidth: 112),
                padding: EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: selectedStatus == status
                      ? _DashboardManagerState.managerBlue
                      : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: selectedStatus == status
                        ? _DashboardManagerState.managerBlue
                        : _DashboardManagerState.managerBorder,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _apiStatusLabel(status),
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        color: selectedStatus == status
                            ? Colors.white
                            : _DashboardManagerState.managerText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      constraints: BoxConstraints(minWidth: 24, minHeight: 24),
                      padding: EdgeInsets.symmetric(horizontal: 7),
                      decoration: BoxDecoration(
                        color: selectedStatus == status
                            ? Colors.white.withValues(alpha: .9)
                            : _apiStatusStyle(status).bg,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${summary.countFor(status)}',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: selectedStatus == status
                              ? _DashboardManagerState.managerBlue
                              : _apiStatusStyle(status).fg,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _ManagerOrdersModernList extends StatelessWidget {
  const _ManagerOrdersModernList({
    required this.orders,
    required this.onTap,
    required this.onValidate,
    required this.onRefuse,
  });

  final List<_ManagerOrderView> orders;
  final ValueChanged<_ManagerOrderView> onTap;
  final Future<bool> Function(_ManagerOrderView order) onValidate;
  final Future<bool> Function(_ManagerOrderView order) onRefuse;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final order in orders) ...[
          _ManagerOrderModernCard(
            order: order,
            onTap: () => onTap(order),
            onValidate: () => onValidate(order),
            onRefuse: () => onRefuse(order),
          ),
          SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ManagerOrdersEmptyState extends StatelessWidget {
  const _ManagerOrdersEmptyState({
    required this.hasFilters,
    required this.onReset,
  });

  final bool hasFilters;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22, 30, 22, 28),
      decoration: _managerCardDecoration(20),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: _DashboardManagerState.iconBlueBg,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              LucideIcons.receipt,
              color: _DashboardManagerState.managerBlue,
              size: 38,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Aucune commande',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: _DashboardManagerState.managerText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            hasFilters
                ? 'Aucune commande ne correspond aux filtres appliqués.'
                : 'Aucune commande disponible pour cette période.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: _DashboardManagerState.managerMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (hasFilters) ...[
            SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: Icon(LucideIcons.rotateCcw, size: 17),
              label: Text('Réinitialiser les filtres'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _DashboardManagerState.managerBlue,
                side: BorderSide(color: _DashboardManagerState.managerBlue),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ManagerOrderModernCard extends StatelessWidget {
  const _ManagerOrderModernCard({
    required this.order,
    required this.onTap,
    required this.onValidate,
    required this.onRefuse,
  });

  final _ManagerOrderView order;
  final VoidCallback onTap;
  final Future<bool> Function() onValidate;
  final Future<bool> Function() onRefuse;

  @override
  Widget build(BuildContext context) {
    final style = _apiStatusStyle(order.status);
    final card = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: _managerCardDecoration(18),
        child: Row(
          children: [
            _ManagerSoftIcon(
              icon: style.icon,
              color: style.fg,
              backgroundColor: style.bg,
              size: 58,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          order.number,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: _DashboardManagerState.managerText,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _ManagerApiStatusBadge(status: order.status),
                    ],
                  ),
                  SizedBox(height: 5),
                  Text(
                    order.clientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: _DashboardManagerState.managerText,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    order.commercialName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: _DashboardManagerState.managerMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${order.dateLabel} • ${order.timeLabel}',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: _DashboardManagerState.managerMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '${order.productsCount} produits',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: _DashboardManagerState.managerMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Montant',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: _DashboardManagerState.managerMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 3),
                SizedBox(
                  width: 82,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${_formatNumber(order.total.round())} DH',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        color: style.fg,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                CircleAvatar(
                  radius: 17,
                  backgroundColor: _DashboardManagerState.iconBlueBg,
                  child: Icon(
                    LucideIcons.chevronRight,
                    color: _DashboardManagerState.managerBlue,
                    size: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (order.status != _ManagerOrderApiStatus.pending) return card;

    return Dismissible(
      key: ValueKey('manager-order-${order.id}-${order.status.name}'),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await onValidate();
          return false;
        }
        await onRefuse();
        return false;
      },
      background: _ManagerSwipeBackground(
        alignment: Alignment.centerLeft,
        color: _DashboardManagerState.managerGreen,
        icon: LucideIcons.checkCircle,
        label: 'Valider',
      ),
      secondaryBackground: _ManagerSwipeBackground(
        alignment: Alignment.centerRight,
        color: _DashboardManagerState.managerRed,
        icon: LucideIcons.xCircle,
        label: 'Refuser',
      ),
      child: card,
    );
  }
}

class _ManagerSwipeBackground extends StatelessWidget {
  const _ManagerSwipeBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.centerLeft;
    return Container(
      margin: EdgeInsets.only(bottom: 0),
      padding: EdgeInsets.symmetric(horizontal: 18),
      alignment: alignment,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: isLeft
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          if (!isLeft) Text(label, style: _swipeTextStyle(color)),
          if (!isLeft) SizedBox(width: 8),
          Icon(icon, color: color),
          if (isLeft) SizedBox(width: 8),
          if (isLeft) Text(label, style: _swipeTextStyle(color)),
        ],
      ),
    );
  }

  TextStyle _swipeTextStyle(Color color) {
    return TextStyle(
      fontFamily: 'Roboto',
      color: color,
      fontSize: 13,
      fontWeight: FontWeight.w700,
    );
  }
}

class _ManagerApiStatusBadge extends StatelessWidget {
  const _ManagerApiStatusBadge({required this.status});

  final _ManagerOrderApiStatus status;

  @override
  Widget build(BuildContext context) {
    final style = _apiStatusStyle(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        _apiStatusLabel(status),
        style: TextStyle(
          fontFamily: 'Roboto',
          color: style.fg,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ManagerOrdersBottomStatus extends StatelessWidget {
  const _ManagerOrdersBottomStatus({
    required this.selected,
    required this.onChanged,
  });

  final _ManagerOrderApiStatus selected;
  final ValueChanged<_ManagerOrderApiStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final status in [
          _ManagerOrderApiStatus.all,
          _ManagerOrderApiStatus.pending,
          _ManagerOrderApiStatus.validated,
          _ManagerOrderApiStatus.refused,
        ])
          ChoiceChip(
            selected: selected == status,
            label: Text(_apiStatusLabel(status)),
            onSelected: (_) => onChanged(status),
          ),
      ],
    );
  }
}

class _ManagerFilterField extends StatelessWidget {
  const _ManagerFilterField({
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: _managerInputBorder(),
          enabledBorder: _managerInputBorder(),
          focusedBorder: _managerInputBorder(
            color: _DashboardManagerState.managerBlue,
          ),
        ),
      ),
    );
  }
}

_OrderStatusStyle _apiStatusStyle(_ManagerOrderApiStatus status) {
  return switch (status) {
    _ManagerOrderApiStatus.validated => _OrderStatusStyle(
      label: 'Validée',
      icon: LucideIcons.checkCircle,
      fg: _DashboardManagerState.managerGreen,
      bg: _DashboardManagerState.iconGreenBg,
    ),
    _ManagerOrderApiStatus.pending => _OrderStatusStyle(
      label: 'En attente',
      icon: LucideIcons.clock,
      fg: _DashboardManagerState.managerOrange,
      bg: _DashboardManagerState.iconOrangeBg,
    ),
    _ManagerOrderApiStatus.refused => _OrderStatusStyle(
      label: 'Refusée',
      icon: LucideIcons.xCircle,
      fg: _DashboardManagerState.managerRed,
      bg: _DashboardManagerState.iconRedBg,
    ),
    _ManagerOrderApiStatus.all => _OrderStatusStyle(
      label: 'Toutes',
      icon: LucideIcons.shoppingCart,
      fg: _DashboardManagerState.managerBlue,
      bg: _DashboardManagerState.iconBlueBg,
    ),
  };
}

String _apiStatusLabel(_ManagerOrderApiStatus status) {
  return _apiStatusStyle(status).label;
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({this.icon, required this.label});

  final IconData? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: _DashboardManagerState.iconBlueBg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: _DashboardManagerState.managerBlue),
            SizedBox(width: 3),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: _DashboardManagerState.managerBlue,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniCommercialMetric extends StatelessWidget {
  const _MiniCommercialMetric({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Roboto',
            color: _DashboardManagerState.managerMuted,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Roboto',
            color: color ?? _DashboardManagerState.managerText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CommercialStatusBadge extends StatelessWidget {
  const _CommercialStatusBadge({required this.status});

  final _ManagerCommercialStatus status;

  @override
  Widget build(BuildContext context) {
    final style = _commercialStatusStyle(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          fontFamily: 'Roboto',
          color: style.fg,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ManagerCommercialEmptyState extends StatelessWidget {
  const _ManagerCommercialEmptyState({
    required this.hasFilters,
    required this.onReset,
  });

  final bool hasFilters;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22, 30, 22, 28),
      decoration: _managerCardDecoration(20),
      child: Column(
        children: [
          _ManagerSoftIcon(
            icon: LucideIcons.users,
            color: _DashboardManagerState.managerBlue,
            backgroundColor: _DashboardManagerState.iconBlueBg,
            size: 76,
          ),
          SizedBox(height: 16),
          Text(
            'Aucun commercial disponible.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: _DashboardManagerState.managerText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            hasFilters
                ? 'Aucun commercial ne correspond aux filtres appliqués.'
                : 'Les commerciaux apparaîtront ici dès qu’ils existent dans la base.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: _DashboardManagerState.managerMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (hasFilters) ...[
            SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: Icon(LucideIcons.rotateCcw, size: 17),
              label: Text('Réinitialiser les filtres'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ManagerCommercialsSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 4; i++) ...[
          Container(
            height: i == 0 ? 130 : 92,
            decoration: _managerCardDecoration(18),
          ),
          SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ManagerCommercialStatusPicker extends StatelessWidget {
  const _ManagerCommercialStatusPicker({
    required this.selected,
    required this.onChanged,
  });

  final _ManagerCommercialStatus selected;
  final ValueChanged<_ManagerCommercialStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final status in _ManagerCommercialStatus.values)
          ChoiceChip(
            selected: selected == status,
            label: Text(_commercialStatusStyle(status).label),
            onSelected: (_) => onChanged(status),
          ),
      ],
    );
  }
}

_OrderStatusStyle _commercialStatusStyle(_ManagerCommercialStatus status) {
  return switch (status) {
    _ManagerCommercialStatus.active => _OrderStatusStyle(
      label: 'Actif',
      icon: LucideIcons.userCheck,
      fg: _DashboardManagerState.managerGreen,
      bg: _DashboardManagerState.iconGreenBg,
    ),
    _ManagerCommercialStatus.leave => _OrderStatusStyle(
      label: 'En congé',
      icon: LucideIcons.clock,
      fg: _DashboardManagerState.managerOrange,
      bg: _DashboardManagerState.iconOrangeBg,
    ),
    _ManagerCommercialStatus.disabled => _OrderStatusStyle(
      label: 'Désactivé',
      icon: LucideIcons.userX,
      fg: _DashboardManagerState.managerRed,
      bg: _DashboardManagerState.iconRedBg,
    ),
    _ManagerCommercialStatus.all => _OrderStatusStyle(
      label: 'Tous',
      icon: LucideIcons.users,
      fg: _DashboardManagerState.managerBlue,
      bg: _DashboardManagerState.iconBlueBg,
    ),
  };
}

_ManagerCommercialStatus _parseCommercialStatus(String raw) {
  final value = raw.toLowerCase().trim();
  if (value.contains('cong')) return _ManagerCommercialStatus.leave;
  if (value.contains('des') ||
      value.contains('inact') ||
      value.contains('inactive') ||
      value == '0' ||
      value == 'false') {
    return _ManagerCommercialStatus.disabled;
  }
  return _ManagerCommercialStatus.active;
}

// ignore: unused_element
class _PeriodSelector extends StatelessWidget {
  _PeriodSelector({required this.selectedPeriod, required this.onChanged});

  final ManagerDashboardPeriod selectedPeriod;
  final ValueChanged<ManagerDashboardPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _DashboardManagerState._border),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF1C4B92).withValues(alpha: .05),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ManagerDashboardPeriod>(
          value: selectedPeriod,
          borderRadius: BorderRadius.circular(14),
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 19),
          padding: EdgeInsets.symmetric(horizontal: 12),
          style: TextStyle(
            color: _DashboardManagerState._textDark,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
          items: ManagerDashboardPeriod.values
              .map(
                (period) =>
                    DropdownMenuItem(value: period, child: Text(period.label)),
              )
              .toList(),
          onChanged: (period) {
            if (period != null) onChanged(period);
          },
        ),
      ),
    );
  }
}

// ignore: unused_element
class _StatsGrid extends StatelessWidget {
  _StatsGrid({required this.data});

  final ManagerDashboardData data;

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatCardData(
        title: AppLocalizations.globalText("Chiffre d'affaires"),
        value: '${_formatNumber(data.stats.revenue)} MAD',
        evolution: data.evolution.revenue,
      ),
      _StatCardData(
        title: AppLocalizations.globalText('Commandes'),
        value: data.stats.orders.toString(),
        evolution: data.evolution.orders,
      ),
      _StatCardData(
        title: AppLocalizations.globalText('Visites'),
        value: data.stats.visits.toString(),
        evolution: data.evolution.visits,
      ),
      _StatCardData(
        title: AppLocalizations.globalText('Taux de transformation'),
        value: '${data.stats.conversionRate}%',
        evolution: data.evolution.conversionRate,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.48,
      ),
      itemBuilder: (context, index) => _StatCard(data: stats[index]),
    );
  }
}

class _StatCard extends StatelessWidget {
  _StatCard({required this.data});

  final _StatCardData data;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _DashboardManagerState._border),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF1C4B92).withValues(alpha: .07),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 13, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _DashboardManagerState._textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                data.value,
                style: TextStyle(
                  color: _DashboardManagerState._textDark,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Spacer(),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '+ ${data.evolution}%',
                style: TextStyle(
                  color: _DashboardManagerState._success,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _SalesByCommercialChart extends StatelessWidget {
  _SalesByCommercialChart({required this.items, required this.onSelected});

  final List<CommercialSales> items;
  final ValueChanged<CommercialSales> onSelected;

  @override
  Widget build(BuildContext context) {
    final maxSales = items.fold<int>(
      1,
      (maxValue, item) => item.sales > maxValue ? item.sales : maxValue,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _DashboardManagerState._border),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF1C4B92).withValues(alpha: .06),
            blurRadius: 16,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 15, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.globalText('Ventes par commercial'),
              style: TextStyle(
                color: _DashboardManagerState._textDark,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 16),
            for (final item in items) ...[
              _SalesBar(
                item: item,
                maxSales: maxSales,
                onTap: () => onSelected(item),
              ),
              SizedBox(height: 11),
            ],
            SizedBox(height: 4),
            _ChartAxis(),
            SizedBox(height: 10),
            Center(child: _ChartLegend()),
          ],
        ),
      ),
    );
  }
}

class _SalesBar extends StatelessWidget {
  _SalesBar({required this.item, required this.maxSales, required this.onTap});

  final CommercialSales item;
  final int maxSales;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final percent = item.sales / maxSales;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 62,
              child: Text(
                item.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _DashboardManagerState._textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: Color(0xFFE9EEF8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: percent.clamp(.08, 1),
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _DashboardManagerState._primaryBlue,
                            _DashboardManagerState._deepBlue,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: _DashboardManagerState._primaryBlue
                                .withValues(alpha: .22),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            SizedBox(
              width: 66,
              child: Text(
                '${_formatCompact(item.sales)} MAD',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: _DashboardManagerState._textDark,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartAxis extends StatelessWidget {
  _ChartAxis();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 62, right: 74),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('0', style: _axisStyle),
          Text(AppLocalizations.globalText('10k'), style: _axisStyle),
          Text(AppLocalizations.globalText('20k'), style: _axisStyle),
          Text(AppLocalizations.globalText('30k'), style: _axisStyle),
          Text(AppLocalizations.globalText('40k'), style: _axisStyle),
        ],
      ),
    );
  }

  static const _axisStyle = TextStyle(
    color: _DashboardManagerState._textMuted,
    fontSize: 10,
    fontWeight: FontWeight.w800,
  );
}

class _ChartLegend extends StatelessWidget {
  _ChartLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: _DashboardManagerState._primaryBlue),
          child: SizedBox(width: 10, height: 10),
        ),
        SizedBox(width: 8),
        Text(
          AppLocalizations.globalText('MAD'),
          style: TextStyle(
            color: _DashboardManagerState._textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _OrdersHeader extends StatelessWidget {
  _OrdersHeader({
    required this.badgeCount,
    required this.onMenuPressed,
    required this.onNotificationsPressed,
  });

  final int badgeCount;
  final VoidCallback onMenuPressed;
  final VoidCallback onNotificationsPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onMenuPressed,
          icon: Icon(Icons.menu_rounded),
          color: _DashboardManagerState._textDark,
          tooltip: 'Menu',
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            AppLocalizations.globalText('Commandes'),
            style: TextStyle(
              color: _DashboardManagerState._textDark,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        ValueListenableBuilder<int>(
          valueListenable: _managerUnreadNotifications,
          builder: (context, unread, child) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: onNotificationsPressed,
                  icon: Icon(Icons.notifications_none_rounded),
                  color: _DashboardManagerState._textDark,
                  tooltip: 'Notifications',
                ),
                if (unread > 0)
                  Positioned(
                    right: 7,
                    top: 5,
                    child: Container(
                      constraints: BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: _DashboardManagerState._primaryBlue,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Center(
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _OrdersSearchRow extends StatelessWidget {
  _OrdersSearchRow({required this.controller, required this.onFilterPressed});

  final TextEditingController controller;
  final VoidCallback onFilterPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            style: TextStyle(
              color: _DashboardManagerState._textDark,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: AppLocalizations.globalText(
                'Rechercher une commande...',
              ),
              hintStyle: TextStyle(
                color: Color(0xFF8A95AA),
                fontWeight: FontWeight.w700,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: _DashboardManagerState._textMuted,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(vertical: 16),
              enabledBorder: _managerInputBorder(),
              focusedBorder: _managerInputBorder(
                color: _DashboardManagerState._primaryBlue,
              ),
            ),
          ),
        ),
        SizedBox(width: 10),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: onFilterPressed,
            icon: Icon(Icons.tune_rounded, size: 18),
            label: Text(AppLocalizations.globalText('Filtres')),
            style: OutlinedButton.styleFrom(
              foregroundColor: _DashboardManagerState._textDark,
              backgroundColor: Colors.white,
              side: BorderSide(color: _DashboardManagerState._border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }
}

class _OrdersStatsGrid extends StatelessWidget {
  _OrdersStatsGrid({required this.summary});

  final ManagerOrdersSummary summary;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _OrderStatData(
        title: AppLocalizations.globalText('Total commandes'),
        value: summary.totalOrders,
        evolution: 12,
        icon: Icons.inventory_2_outlined,
        color: _DashboardManagerState._primaryBlue,
      ),
      _OrderStatData(
        title: AppLocalizations.globalText('Validées'),
        value: summary.validatedOrders,
        evolution: 15,
        icon: Icons.check_circle_outline_rounded,
        color: _DashboardManagerState._success,
      ),
      _OrderStatData(
        title: AppLocalizations.globalText('En attente'),
        value: summary.pendingOrders,
        evolution: 5,
        icon: Icons.schedule_rounded,
        color: Color(0xFFFF941A),
      ),
      _OrderStatData(
        title: AppLocalizations.globalText('Annulées'),
        value: summary.cancelledOrders,
        evolution: -8,
        icon: Icons.cancel_outlined,
        color: Color(0xFFFF3B30),
      ),
    ];

    return SizedBox(
      height: 136,
      child: GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: cards.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          childAspectRatio: .62,
        ),
        itemBuilder: (context, index) => _OrderStatCard(data: cards[index]),
      ),
    );
  }
}

class _OrderStatCard extends StatelessWidget {
  _OrderStatCard({required this.data});

  final _OrderStatData data;

  @override
  Widget build(BuildContext context) {
    final trendIcon = data.evolution >= 0
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _DashboardManagerState._border),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF1C4B92).withValues(alpha: .055),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 8, 8, 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Icon(data.icon, color: data.color, size: 18),
            ),
            SizedBox(height: 8),
            Text(
              data.value.toString(),
              style: TextStyle(
                color: _DashboardManagerState._textDark,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              data.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _DashboardManagerState._textMuted,
                fontSize: 9,
                height: 1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
            Spacer(),
            Row(
              children: [
                Icon(trendIcon, color: data.color, size: 12),
                Text(
                  '${data.evolution.abs()}%',
                  style: TextStyle(
                    color: data.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersStatusTabs extends StatelessWidget {
  _OrdersStatusTabs({required this.selectedStatus, required this.onChanged});

  final ManagerOrderStatus selectedStatus;
  final ValueChanged<ManagerOrderStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _DashboardManagerState._border),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF1C4B92).withValues(alpha: .045),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            for (final status in ManagerOrderStatus.values)
              Expanded(
                child: InkWell(
                  onTap: () => onChanged(status),
                  borderRadius: BorderRadius.circular(14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        status.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selectedStatus == status
                              ? _DashboardManagerState._primaryBlue
                              : _DashboardManagerState._textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 8),
                      AnimatedContainer(
                        duration: Duration(milliseconds: 180),
                        width: selectedStatus == status ? 42 : 0,
                        height: 3,
                        decoration: BoxDecoration(
                          color: _DashboardManagerState._primaryBlue,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OrdersListCard extends StatelessWidget {
  _OrdersListCard({required this.orders, required this.onOrderTap});

  final List<ManagerOrderItem> orders;
  final ValueChanged<ManagerOrderItem> onOrderTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _DashboardManagerState._border),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF1C4B92).withValues(alpha: .05),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < orders.length; i++) ...[
            _OrderRow(order: orders[i], onTap: () => onOrderTap(orders[i])),
            if (i != orders.length - 1)
              Divider(height: 1, color: _DashboardManagerState._border),
          ],
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  _OrderRow({required this.order, required this.onTap});

  final ManagerOrderItem order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _orderStatusStyle(order.status);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 14, 9, 14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: style.bg,
                shape: BoxShape.circle,
              ),
              child: Icon(style.icon, color: style.fg, size: 24),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.orderNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _DashboardManagerState._textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    order.dateLabel,
                    style: TextStyle(
                      color: _DashboardManagerState._textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 11),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: _DashboardManagerState._primaryBlue
                            .withValues(alpha: .10),
                        child: Text(
                          _initials(order.commercialName),
                          style: TextStyle(
                            color: _DashboardManagerState._primaryBlue,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.commercialName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _DashboardManagerState._textDark,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              AppLocalizations.globalText('Commercial'),
                              style: TextStyle(
                                color: _DashboardManagerState._textMuted,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            SizedBox(
              width: 92,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _OrderStatusBadge(status: order.status),
                  SizedBox(height: 17),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${_formatNumber(order.total)} MAD',
                      style: TextStyle(
                        color: _DashboardManagerState._textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${order.itemsCount} articles',
                    style: TextStyle(
                      color: _DashboardManagerState._textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: _DashboardManagerState._textDark,
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderStatusBadge extends StatelessWidget {
  _OrderStatusBadge({required this.status});

  final ManagerOrderStatus status;

  @override
  Widget build(BuildContext context) {
    final style = _orderStatusStyle(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label == 'Toutes' ? 'Validée' : _singleStatusLabel(status),
        style: TextStyle(
          color: style.fg,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _OrdersPagination extends StatelessWidget {
  _OrdersPagination({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.visibleCount,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int visibleCount;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final start = totalItems == 0 ? 0 : ((currentPage - 1) * 5) + 1;
    final end = math.min(totalItems, start + visibleCount - 1);

    return Container(
      padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _DashboardManagerState._border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Affichage $start à $end sur $totalItems',
              style: TextStyle(
                color: _DashboardManagerState._textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _PageButton(
            icon: Icons.chevron_left_rounded,
            enabled: currentPage > 1,
            onTap: () => onPageChanged(currentPage - 1),
          ),
          SizedBox(width: 6),
          _PageNumberButton(
            label: currentPage.toString(),
            selected: true,
            onTap: () {},
          ),
          if (currentPage < totalPages) ...[
            SizedBox(width: 6),
            _PageNumberButton(
              label: (currentPage + 1).toString(),
              onTap: () => onPageChanged(currentPage + 1),
            ),
          ],
          SizedBox(width: 6),
          _PageButton(
            icon: Icons.chevron_right_rounded,
            enabled: currentPage < totalPages,
            onTap: () => onPageChanged(currentPage + 1),
          ),
        ],
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  _PageButton({required this.icon, required this.enabled, required this.onTap});

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white
              : _DashboardManagerState._border.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _DashboardManagerState._border),
        ),
        child: Icon(
          icon,
          color: enabled
              ? _DashboardManagerState._textDark
              : _DashboardManagerState._textMuted.withValues(alpha: .55),
        ),
      ),
    );
  }
}

class _PageNumberButton extends StatelessWidget {
  _PageNumberButton({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _DashboardManagerState._primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? _DashboardManagerState._primaryBlue
                : _DashboardManagerState._border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _DashboardManagerState._textDark,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ReportsHeader extends StatelessWidget {
  _ReportsHeader({
    required this.selectedPeriod,
    required this.onPeriodChanged,
    required this.onMenuPressed,
  });

  final ManagerDashboardPeriod selectedPeriod;
  final ValueChanged<ManagerDashboardPeriod> onPeriodChanged;
  final VoidCallback onMenuPressed;

  @override
  Widget build(BuildContext context) {
    final data = ManagerReportsMockData.byPeriod(selectedPeriod);

    return Row(
      children: [
        IconButton(
          onPressed: onMenuPressed,
          icon: Icon(Icons.menu_rounded),
          color: _DashboardManagerState._textDark,
          tooltip: 'Menu',
        ),
        SizedBox(width: 2),
        Expanded(
          child: Text(
            AppLocalizations.globalText('Rapports'),
            style: TextStyle(
              color: _DashboardManagerState._textDark,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _DashboardManagerState._border),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF1C4B92).withValues(alpha: .04),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<ManagerDashboardPeriod>(
              value: selectedPeriod,
              borderRadius: BorderRadius.circular(14),
              icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              padding: EdgeInsets.symmetric(horizontal: 10),
              style: TextStyle(
                color: _DashboardManagerState._textDark,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
              items: ManagerDashboardPeriod.values
                  .map(
                    (period) => DropdownMenuItem(
                      value: period,
                      child: Text(
                        ManagerReportsMockData.byPeriod(period).periodLabel,
                      ),
                    ),
                  )
                  .toList(),
              selectedItemBuilder: (context) {
                return ManagerDashboardPeriod.values
                    .map((_) => Center(child: Text(data.periodLabel)))
                    .toList();
              },
              onChanged: (period) {
                if (period != null) onPeriodChanged(period);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _RevenueReportCard extends StatelessWidget {
  _RevenueReportCard({required this.data, required this.onTap});

  final ReportsData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ReportCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.globalText("Chiffre d'affaires"),
            style: TextStyle(
              color: _DashboardManagerState._textDark,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '${_formatNumber(data.revenue)} MAD',
            style: TextStyle(
              color: _DashboardManagerState._textDark,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 14),
          SizedBox(
            height: 132,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, progress, _) {
                return CustomPaint(
                  painter: _RevenueLinePainter(
                    points: data.revenueEvolution,
                    progress: progress,
                  ),
                  child: SizedBox.expand(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersStatusReportCard extends StatelessWidget {
  _OrdersStatusReportCard({required this.statuses, required this.onTap});

  final List<OrderStatusReport> statuses;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ReportCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.globalText('Commandes par statut'),
            style: TextStyle(
              color: _DashboardManagerState._textDark,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                width: 132,
                height: 132,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, progress, _) {
                    return CustomPaint(
                      painter: _DonutChartPainter(
                        statuses: statuses,
                        progress: progress,
                      ),
                    );
                  },
                ),
              ),
              SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    for (final status in statuses)
                      _StatusLegendRow(status: status),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  _ReportCard({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _DashboardManagerState._border),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF1C4B92).withValues(alpha: .055),
                blurRadius: 18,
                offset: Offset(0, 9),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _StatusLegendRow extends StatelessWidget {
  _StatusLegendRow({required this.status});

  final OrderStatusReport status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Color(status.colorHex),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              status.label,
              style: TextStyle(
                color: _DashboardManagerState._textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '${status.percent}%',
            style: TextStyle(
              color: _DashboardManagerState._textDark,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueLinePainter extends CustomPainter {
  _RevenueLinePainter({required this.points, required this.progress});

  final List<RevenuePoint> points;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final left = 31.0;
    final top = 6.0;
    final bottom = 24.0;
    final right = 6.0;
    final chart = Rect.fromLTWH(
      left,
      top,
      size.width - left - right,
      size.height - top - bottom,
    );
    final maxAmount = points
        .map((point) => point.amount)
        .fold<int>(1, (max, value) => value > max ? value : max);
    final maxDay = points
        .map((point) => point.day)
        .fold<int>(1, (max, value) => value > max ? value : max);

    final gridPaint = Paint()
      ..color = const Color(0xFFE9EEF8)
      ..strokeWidth = 1;
    final labelPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (var i = 0; i <= 3; i++) {
      final y = chart.bottom - chart.height * (i / 3);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      final value = (maxAmount * i / 3 / 1000).round();
      labelPainter.text = TextSpan(
        text: i == 0 ? '0' : '${value}k',
        style: TextStyle(
          color: _DashboardManagerState._textMuted,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      );
      labelPainter.layout();
      labelPainter.paint(canvas, Offset(0, y - 6));
    }

    final dayLabels = [1, 7, 14, 21, 31];
    for (final day in dayLabels) {
      final x =
          chart.left + chart.width * ((day - 1) / (maxDay - 1).clamp(1, 99));
      canvas.drawLine(Offset(x, chart.top), Offset(x, chart.bottom), gridPaint);
      labelPainter.text = TextSpan(
        text: day.toString().padLeft(2, '0'),
        style: TextStyle(
          color: _DashboardManagerState._textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      );
      labelPainter.layout();
      labelPainter.paint(
        canvas,
        Offset(x - labelPainter.width / 2, chart.bottom + 8),
      );
    }

    final offsets = points.map((point) {
      final x =
          chart.left +
          chart.width * ((point.day - 1) / (maxDay - 1).clamp(1, 99));
      final y = chart.bottom - chart.height * (point.amount / maxAmount);
      return Offset(x, y);
    }).toList();
    final visibleCount = (offsets.length * progress)
        .clamp(1, offsets.length)
        .ceil();
    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (var i = 1; i < visibleCount; i++) {
      path.lineTo(offsets[i].dx, offsets[i].dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(offsets[visibleCount - 1].dx, chart.bottom)
      ..lineTo(offsets.first.dx, chart.bottom)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _DashboardManagerState._primaryBlue.withValues(alpha: .16),
          _DashboardManagerState._primaryBlue.withValues(alpha: .02),
        ],
      ).createShader(chart);
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = _DashboardManagerState._primaryBlue
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = _DashboardManagerState._primaryBlue;
    for (var i = 0; i < visibleCount; i++) {
      canvas.drawCircle(offsets[i], 3.2, Paint()..color = Colors.white);
      canvas.drawCircle(offsets[i], 2.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RevenueLinePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.points != points;
  }
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({required this.statuses, required this.progress});

  final List<OrderStatusReport> statuses;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final total = statuses.fold<int>(0, (sum, item) => sum + item.percent);
    if (total == 0) return;

    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = math.min(size.width, size.height) / 2;
    final strokeWidth = radius * .38;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    var start = -math.pi / 2;
    for (final status in statuses) {
      final sweep = (status.percent / total) * math.pi * 2 * progress;
      paint.color = Color(status.colorHex);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        start,
        sweep,
        false,
        paint,
      );
      start += sweep;
    }

    canvas.drawCircle(center, radius * .48, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.statuses != statuses;
  }
}

class _CommercialSearchBar extends StatelessWidget {
  _CommercialSearchBar({
    required this.controller,
    required this.onFilterPressed,
  });

  final TextEditingController controller;
  final VoidCallback onFilterPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            style: TextStyle(
              color: _DashboardManagerState._textDark,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: AppLocalizations.globalText(
                'Rechercher un commercial...',
              ),
              hintStyle: TextStyle(
                color: Color(0xFF9AA6BA),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: _DashboardManagerState._textMuted,
                size: 21,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 15,
              ),
              enabledBorder: _managerInputBorder(),
              focusedBorder: _managerInputBorder(
                color: _DashboardManagerState._primaryBlue,
              ),
            ),
          ),
        ),
        SizedBox(width: 10),
        SizedBox(
          width: 48,
          height: 48,
          child: OutlinedButton(
            onPressed: onFilterPressed,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: _DashboardManagerState._textDark,
              side: BorderSide(color: _DashboardManagerState._border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              backgroundColor: Colors.white,
            ),
            child: Icon(Icons.tune_rounded, size: 20),
          ),
        ),
      ],
    );
  }
}

class _CommercialSummaryCards extends StatelessWidget {
  _CommercialSummaryCards({required this.summary});

  final _CommercialsSummary summary;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MiniSummaryData(
        icon: Icons.groups_rounded,
        iconColor: _DashboardManagerState._primaryBlue,
        value: summary.activeCommercials.toString(),
        label: AppLocalizations.globalText('Commerciaux actifs'),
      ),
      _MiniSummaryData(
        icon: Icons.trending_up_rounded,
        iconColor: _DashboardManagerState._success,
        value: _formatNumber(summary.totalRevenue),
        label: AppLocalizations.globalText('CA total (MAD)'),
        evolution: 12,
      ),
      _MiniSummaryData(
        icon: Icons.shopping_bag_outlined,
        iconColor: Color(0xFF7A57FF),
        value: summary.totalOrders.toString(),
        label: AppLocalizations.globalText('Commandes'),
        evolution: 9,
      ),
      _MiniSummaryData(
        icon: Icons.location_on_rounded,
        iconColor: Color(0xFFFF8A2A),
        value: summary.totalVisits.toString(),
        label: AppLocalizations.globalText('Visites'),
        evolution: 6,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        childAspectRatio: .92,
      ),
      itemBuilder: (context, index) => _MiniSummaryCard(data: cards[index]),
    );
  }
}

class _MiniSummaryCard extends StatelessWidget {
  _MiniSummaryCard({required this.data});

  final _MiniSummaryData data;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _DashboardManagerState._border),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF1C4B92).withValues(alpha: .05),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(data.icon, color: data.iconColor, size: 18),
            Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                data.value,
                style: TextStyle(
                  color: _DashboardManagerState._textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              data.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _DashboardManagerState._textMuted,
                fontSize: 9,
                height: 1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (data.evolution != null)
              Text(
                '+${data.evolution}%',
                style: TextStyle(
                  color: _DashboardManagerState._success,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CommercialCard extends StatelessWidget {
  _CommercialCard({required this.commercial, required this.onTap});

  final CommercialSales commercial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.fromLTRB(12, 12, 10, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _DashboardManagerState._border),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF1C4B92).withValues(alpha: .055),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              _CommercialAvatar(commercial: commercial),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      commercial.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _DashboardManagerState._textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      commercial.isActive ? 'Commercial' : 'Commercial inactif',
                      style: TextStyle(
                        color: _DashboardManagerState._textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _CommercialMetric(
                            icon: Icons.trending_up_rounded,
                            iconColor: _DashboardManagerState._primaryBlue,
                            value: '${_formatNumber(commercial.sales)} MAD',
                            label: AppLocalizations.globalText('CA'),
                          ),
                        ),
                        Expanded(
                          child: _CommercialMetric(
                            icon: Icons.shopping_bag_outlined,
                            iconColor: Color(0xFF7A57FF),
                            value: commercial.ordersCount.toString(),
                            label: AppLocalizations.globalText('Commandes'),
                          ),
                        ),
                        Expanded(
                          child: _CommercialMetric(
                            icon: Icons.location_on_rounded,
                            iconColor: Color(0xFFFF8A2A),
                            value: commercial.visitsCount.toString(),
                            label: AppLocalizations.globalText('Visites'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              SizedBox(
                width: 58,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${commercial.conversionRate}%',
                      style: TextStyle(
                        color: _DashboardManagerState._textDark,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      AppLocalizations.globalText('Taux de\ntransformation'),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: _DashboardManagerState._textMuted,
                        fontSize: 9,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      '+${commercial.evolution}%',
                      style: TextStyle(
                        color: _DashboardManagerState._success,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 5),
              Icon(
                Icons.chevron_right_rounded,
                color: _DashboardManagerState._textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommercialAvatar extends StatelessWidget {
  _CommercialAvatar({required this.commercial});

  final CommercialSales commercial;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: _DashboardManagerState._primaryBlue.withValues(
            alpha: .10,
          ),
          child: Text(
            _initials(commercial.name),
            style: TextStyle(
              color: _DashboardManagerState._primaryBlue,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Positioned(
          right: -1,
          top: 2,
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: commercial.isActive
                  ? _DashboardManagerState._success
                  : _DashboardManagerState._textMuted,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _CommercialMetric extends StatelessWidget {
  _CommercialMetric({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    color: _DashboardManagerState._textDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _DashboardManagerState._textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommercialsLoadingState extends StatelessWidget {
  _CommercialsLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 44),
        child: CircularProgressIndicator(
          color: _DashboardManagerState._primaryBlue,
        ),
      ),
    );
  }
}

class _CommercialsEmptyState extends StatelessWidget {
  _CommercialsEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 22, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _DashboardManagerState._border),
      ),
      child: Column(
        children: [
          Icon(icon, color: _DashboardManagerState._primaryBlue, size: 36),
          SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: _DashboardManagerState._textDark,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _DashboardManagerState._textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterOptionTile extends StatelessWidget {
  _FilterOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      title: Text(
        label,
        style: TextStyle(
          color: selected
              ? _DashboardManagerState._primaryBlue
              : _DashboardManagerState._textDark,
          fontWeight: FontWeight.w900,
        ),
      ),
      trailing: selected
          ? Icon(
              Icons.check_circle_rounded,
              color: _DashboardManagerState._primaryBlue,
            )
          : null,
    );
  }
}

class ProfileManagerScreen extends StatefulWidget {
  ProfileManagerScreen({super.key});

  @override
  State<ProfileManagerScreen> createState() => _ProfileManagerScreenState();
}

class _ManagerProfileData {
  const _ManagerProfileData({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.city,
    required this.address,
    required this.createdAt,
    required this.birthDate,
    required this.gender,
    required this.avatar,
    required this.notificationsEnabled,
    required this.languageCode,
    required this.theme,
  });

  final int id;
  final String fullName;
  final String email;
  final String phone;
  final String city;
  final String address;
  final DateTime? createdAt;
  final DateTime? birthDate;
  final String gender;
  final String avatar;
  final bool notificationsEnabled;
  final String languageCode;
  final AppThemePreference theme;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'MB';
    final first = parts.first.characters.first;
    final second = parts.length > 1 && parts[1].isNotEmpty
        ? parts[1].characters.first
        : '';
    return '$first$second'.toUpperCase();
  }

  factory _ManagerProfileData.fromJson(
    Map<String, dynamic> json,
    AuthenticatedUser session,
  ) {
    final name = _readString(json, [
      'full_name',
      'name',
      'nom_complet',
      'username',
      'nom',
    ]).ifEmpty(session.fullName);
    final themeName = _readString(json, ['theme', 'app_theme']);
    return _ManagerProfileData(
      id: _readInt(json, ['id', 'user_id']).nonZeroOr(session.id),
      fullName: name.ifEmpty('Manager'),
      email: _readString(json, ['email']).ifEmpty(session.email),
      phone: _readString(json, ['phone', 'telephone']).ifEmpty(session.phone),
      city: _readString(json, ['city', 'ville']).ifEmpty('-'),
      address: _readString(json, ['address', 'adresse']).ifEmpty('-'),
      createdAt: _readDate(json, ['created_at', 'date_creation']),
      birthDate: _readDate(json, ['birth_date', 'date_naissance']),
      gender: _readString(json, ['gender', 'genre']).ifEmpty('-'),
      avatar: _readString(json, ['avatar', 'photo', 'image']),
      notificationsEnabled:
          json.containsKey('notifications_enabled') ||
              json.containsKey('notifications')
          ? _readBool(json, ['notifications_enabled', 'notifications'])
          : true,
      languageCode: _readString(json, [
        'language',
        'language_code',
        'langue',
      ]).ifEmpty(AppLocaleController.instance.languageCode),
      theme: switch (themeName) {
        'light' || 'clair' => AppThemePreference.light,
        'dark' || 'sombre' => AppThemePreference.dark,
        _ => AppAppearanceController.instance.theme,
      },
    );
  }

  Map<String, dynamic> toUpdateJson({
    required String fullName,
    required String email,
    required String phone,
    required String city,
    required String address,
    DateTime? birthDate,
    required String gender,
  }) {
    return {
      'name': fullName,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'city': city,
      'address': address,
      'birth_date': birthDate?.toIso8601String(),
      'gender': gender,
    };
  }
}

extension _IntNonZero on int {
  int nonZeroOr(int fallback) => this == 0 ? fallback : this;
}

class _ProfileManagerScreenState extends State<ProfileManagerScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  Future<_ManagerProfileData>? _future;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _future = _loadProfile();
  }

  Future<_ManagerProfileData> _loadProfile() async {
    await _syncManagerUnreadNotifications();
    final session = CurrentUserSession.currentUser;
    if (session == null || !session.isManager) {
      throw Exception('Session manager introuvable');
    }
    var profileJson = _sessionProfileJson(session);
    try {
      final users = await ApiService.getUsers();
      profileJson = users
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .firstWhere(
            (user) =>
                _readInt(user, ['id', 'user_id']) == session.id ||
                _readString(user, ['email']).toLowerCase() ==
                    session.email.toLowerCase(),
            orElse: () => profileJson,
          );
    } catch (_) {
      profileJson = _sessionProfileJson(session);
    }
    final data = _ManagerProfileData.fromJson(profileJson, session);
    _notificationsEnabled = data.notificationsEnabled;
    return data;
  }

  Map<String, dynamic> _sessionProfileJson(AuthenticatedUser session) {
    return {
      'id': session.id,
      'name': session.fullName,
      'email': session.email,
      'phone': session.phone,
      'role': 'manager',
      'theme': AppAppearanceController.instance.theme.name,
      'language': AppLocaleController.instance.languageCode,
      'notifications_enabled': true,
    };
  }

  Future<void> _refresh() async {
    setState(() => _future = _loadProfile());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _DashboardManagerState.managerSurface,
      drawer: _ManagerDrawer(),
      body: _ManagerMobileShell(
        selectedTab: _ManagerTab.profil,
        child: RefreshIndicator(
          color: _DashboardManagerState.managerBlue,
          onRefresh: _refresh,
          child: FutureBuilder<_ManagerProfileData>(
            future: _future,
            builder: (context, snapshot) {
              final data = snapshot.data;
              return SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ManagerHomeHeader(
                      managerName: data?.fullName ?? 'Manager',
                      unreadCount: 0,
                      onMenuPressed: () =>
                          _scaffoldKey.currentState?.openDrawer(),
                      onNotificationsPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NotificationsScreen(),
                        ),
                      ),
                      onAvatarPressed: () {},
                    ),
                    Transform.translate(
                      offset: Offset(0, -10),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.fromLTRB(16, 22, 16, 96),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        child:
                            snapshot.connectionState == ConnectionState.waiting
                            ? _ManagerCommercialsSkeleton()
                            : snapshot.hasError
                            ? _ManagerDashboardError(
                                message: 'Impossible de charger le profil.',
                                onRetry: _refresh,
                              )
                            : _ManagerProfileContent(
                                data: data!,
                                notificationsEnabled: _notificationsEnabled,
                                onEdit: () => _openEdit(data),
                                onSecurity: () => _openPassword(data),
                                onNotificationsChanged: (value) =>
                                    _updateNotifications(data, value),
                                onLanguage: () => _openLanguageSheet(data),
                                onTheme: () => _openThemeSheet(data),
                                onSupport: _openSupport,
                                onAbout: _openAbout,
                                onLogout: _confirmLogout,
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openEdit(_ManagerProfileData data) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _ManagerEditProfilePage(data: data)),
    );
    if (saved == true && mounted) await _refresh();
  }

  void _openPassword(_ManagerProfileData data) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _ManagerChangePasswordPage(data: data)),
    );
  }

  Future<void> _updateNotifications(
    _ManagerProfileData data,
    bool value,
  ) async {
    setState(() => _notificationsEnabled = value);
    try {
      await ApiService.updateUserPreferences(data.id, {
        'notifications_enabled': value,
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _notificationsEnabled = !value);
      _showManagerSnack(context, 'Impossible de sauvegarder la preference.');
    }
  }

  void _openLanguageSheet(_ManagerProfileData data) {
    final options = [
      ('Français', Locale('fr')),
      ('العربية', Locale('ar')),
      ('English', Locale('en')),
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ManagerSheetTitle('Langue'),
              for (final option in options)
                _ManagerChoiceTile(
                  label: option.$1,
                  selected:
                      AppLocaleController.instance.languageCode ==
                      option.$2.languageCode,
                  onTap: () async {
                    await AppLocaleController.instance.setLocale(option.$2);
                    await ApiService.updateUserPreferences(data.id, {
                      'language': option.$2.languageCode,
                    }).catchError((_) => <String, dynamic>{});
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openThemeSheet(_ManagerProfileData data) {
    final options = [
      ('Clair', AppThemePreference.light),
      ('Sombre', AppThemePreference.dark),
      ('Système', AppThemePreference.system),
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ManagerSheetTitle('Thème'),
              for (final option in options)
                _ManagerChoiceTile(
                  label: option.$1,
                  selected: AppAppearanceController.instance.theme == option.$2,
                  onTap: () async {
                    await AppAppearanceController.instance.setTheme(option.$2);
                    await ApiService.updateUserPreferences(data.id, {
                      'theme': option.$2.name,
                    }).catchError((_) => <String, dynamic>{});
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSupport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _ManagerSupportPage()),
    );
  }

  void _openAbout() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _ManagerAboutPage()),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Déconnexion'),
        content: Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _DashboardManagerState.managerRed,
              foregroundColor: Colors.white,
            ),
            child: Text('Déconnexion'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    CurrentUserSession.signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }
}

class _ManagerProfileContent extends StatelessWidget {
  const _ManagerProfileContent({
    required this.data,
    required this.notificationsEnabled,
    required this.onEdit,
    required this.onSecurity,
    required this.onNotificationsChanged,
    required this.onLanguage,
    required this.onTheme,
    required this.onSupport,
    required this.onAbout,
    required this.onLogout,
  });

  final _ManagerProfileData data;
  final bool notificationsEnabled;
  final VoidCallback onEdit;
  final VoidCallback onSecurity;
  final ValueChanged<bool> onNotificationsChanged;
  final VoidCallback onLanguage;
  final VoidCallback onTheme;
  final VoidCallback onSupport;
  final VoidCallback onAbout;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profil',
          style: TextStyle(
            fontFamily: 'Roboto',
            color: _DashboardManagerState.managerText,
            fontSize: 30,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Gérez vos informations personnelles et les paramètres de votre compte.',
          style: TextStyle(
            fontFamily: 'Roboto',
            color: _DashboardManagerState.managerMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 20),
        _ManagerProfileCard(data: data, onTap: onEdit),
        SizedBox(height: 22),
        Text(
          'Paramètres du compte',
          style: TextStyle(
            fontFamily: 'Roboto',
            color: _DashboardManagerState.managerText,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 12),
        Container(
          decoration: _managerCardDecoration(20),
          child: Column(
            children: [
              _ManagerProfileSettingTile(
                icon: LucideIcons.user,
                iconColor: _DashboardManagerState.managerBlue,
                iconBg: _DashboardManagerState.iconBlueBg,
                title: 'Informations personnelles',
                subtitle: 'Gérez vos informations personnelles.',
                onTap: onEdit,
              ),
              _ManagerSettingDivider(),
              _ManagerProfileSettingTile(
                icon: LucideIcons.lock,
                iconColor: _DashboardManagerState.managerGreen,
                iconBg: _DashboardManagerState.iconGreenBg,
                title: 'Sécurité',
                subtitle: 'Modifier votre mot de passe.',
                onTap: onSecurity,
              ),
              _ManagerSettingDivider(),
              _ManagerProfileSettingTile(
                icon: LucideIcons.bell,
                iconColor: _DashboardManagerState.managerOrange,
                iconBg: _DashboardManagerState.iconOrangeBg,
                title: 'Notifications',
                subtitle: 'Gérer les préférences de notifications.',
                trailing: Switch(
                  value: notificationsEnabled,
                  activeThumbColor: _DashboardManagerState.managerBlue,
                  onChanged: onNotificationsChanged,
                ),
              ),
              _ManagerSettingDivider(),
              _ManagerProfileSettingTile(
                icon: LucideIcons.globe2,
                iconColor: _DashboardManagerState.managerPurple,
                iconBg: _DashboardManagerState.iconPurpleBg,
                title: 'Langue',
                subtitle: "Choisir la langue de l'application.",
                trailingText: _languageLabel(
                  AppLocaleController.instance.languageCode,
                ),
                onTap: onLanguage,
              ),
              _ManagerSettingDivider(),
              _ManagerProfileSettingTile(
                icon: LucideIcons.moon,
                iconColor: _DashboardManagerState.managerBlue,
                iconBg: _DashboardManagerState.iconBlueBg,
                title: 'Thème',
                subtitle: "Sélectionner le thème de l'application.",
                trailingText: _themeLabel(
                  AppAppearanceController.instance.theme,
                ),
                onTap: onTheme,
              ),
              _ManagerSettingDivider(),
              _ManagerProfileSettingTile(
                icon: LucideIcons.helpCircle,
                iconColor: _DashboardManagerState.managerOrange,
                iconBg: _DashboardManagerState.iconOrangeBg,
                title: 'Aide et support',
                subtitle: "FAQ, centre d'aide et contact.",
                onTap: onSupport,
              ),
              _ManagerSettingDivider(),
              _ManagerProfileSettingTile(
                icon: LucideIcons.info,
                iconColor: _DashboardManagerState.managerGreen,
                iconBg: _DashboardManagerState.iconGreenBg,
                title: 'À propos',
                subtitle: "Version de l'application et informations légales.",
                trailingText: 'Version',
                onTap: onAbout,
              ),
            ],
          ),
        ),
        SizedBox(height: 24),
        _ManagerLogoutCard(onTap: onLogout),
      ],
    );
  }
}

class _ManagerProfileCard extends StatelessWidget {
  const _ManagerProfileCard({required this.data, required this.onTap});

  final _ManagerProfileData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: EdgeInsets.all(16),
      decoration: _managerCardDecoration(20),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _ManagerProfileAvatar(data: data, size: 86),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _DashboardManagerState.managerBlue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Icon(
                    LucideIcons.camera,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: _DashboardManagerState.managerText,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    _ManagerMiniBadge('Manager'),
                  ],
                ),
                SizedBox(height: 10),
                _ManagerProfileInfoLine(LucideIcons.mail, data.email),
                _ManagerProfileInfoLine(
                  LucideIcons.phone,
                  data.phone.ifEmpty('-'),
                ),
                _ManagerProfileInfoLine(LucideIcons.mapPin, data.city),
                _ManagerProfileInfoLine(
                  LucideIcons.calendar,
                  data.createdAt == null
                      ? 'Compte créé'
                      : 'Compte créé le ${_dateLabel(data.createdAt!)}',
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Icon(
            LucideIcons.chevronRight,
            color: _DashboardManagerState.managerMuted,
            size: 22,
          ),
        ],
      ),
    ),
  );
}

class _ManagerProfileAvatar extends StatelessWidget {
  const _ManagerProfileAvatar({required this.data, required this.size});

  final _ManagerProfileData data;
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatar = data.avatar.trim();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: _DashboardManagerState.iconBlueBg,
      backgroundImage: avatar.startsWith('http') ? NetworkImage(avatar) : null,
      child: avatar.startsWith('http')
          ? null
          : Text(
              data.initials,
              style: TextStyle(
                fontFamily: 'Roboto',
                color: _DashboardManagerState.managerBlue,
                fontSize: size * .28,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

class _ManagerMiniBadge extends StatelessWidget {
  const _ManagerMiniBadge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _DashboardManagerState.iconBlueBg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontFamily: 'Roboto',
        color: _DashboardManagerState.managerBlue,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ManagerProfileInfoLine extends StatelessWidget {
  const _ManagerProfileInfoLine(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 5),
    child: Row(
      children: [
        Icon(icon, size: 15, color: _DashboardManagerState.managerMuted),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: _DashboardManagerState.managerMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ManagerProfileSettingTile extends StatelessWidget {
  const _ManagerProfileSettingTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.trailingText,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final String? trailingText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _ManagerSoftIcon(
            icon: icon,
            color: iconColor,
            backgroundColor: iconBg,
            size: 48,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: _DashboardManagerState.managerText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: _DashboardManagerState.managerMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else ...[
            if (trailingText != null)
              Padding(
                padding: EdgeInsets.only(right: 8),
                child: Text(
                  trailingText!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: _DashboardManagerState.managerMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Icon(
              LucideIcons.chevronRight,
              color: _DashboardManagerState.managerMuted,
              size: 19,
            ),
          ],
        ],
      ),
    ),
  );
}

class _ManagerSettingDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    indent: 74,
    color: _DashboardManagerState.managerBorder,
  );
}

class _ManagerLogoutCard extends StatelessWidget {
  const _ManagerLogoutCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _DashboardManagerState.managerRed.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _DashboardManagerState.managerRed.withValues(alpha: .45),
        ),
      ),
      child: Row(
        children: [
          _ManagerSoftIcon(
            icon: LucideIcons.logOut,
            color: _DashboardManagerState.managerRed,
            backgroundColor: _DashboardManagerState.iconRedBg,
            size: 48,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Déconnexion',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: _DashboardManagerState.managerRed,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Se déconnecter du compte.',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: _DashboardManagerState.managerMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ManagerEditProfilePage extends StatefulWidget {
  const _ManagerEditProfilePage({required this.data});
  final _ManagerProfileData data;

  @override
  State<_ManagerEditProfilePage> createState() =>
      _ManagerEditProfilePageState();
}

class _ManagerEditProfilePageState extends State<_ManagerEditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _cityController;
  late final TextEditingController _addressController;
  late final TextEditingController _genderController;
  DateTime? _birthDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.data.fullName);
    _emailController = TextEditingController(text: widget.data.email);
    _phoneController = TextEditingController(text: widget.data.phone);
    _cityController = TextEditingController(
      text: widget.data.city == '-' ? '' : widget.data.city,
    );
    _addressController = TextEditingController(
      text: widget.data.address == '-' ? '' : widget.data.address,
    );
    _genderController = TextEditingController(
      text: widget.data.gender == '-' ? '' : widget.data.gender,
    );
    _birthDate = widget.data.birthDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _genderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ManagerSimplePageShell(
    title: 'Modifier le profil',
    subtitle: 'Mettez à jour vos informations personnelles.',
    child: Form(
      key: _formKey,
      child: Column(
        children: [
          _ManagerProfileAvatar(data: widget.data, size: 94),
          SizedBox(height: 18),
          _ManagerProfileField(
            controller: _nameController,
            label: 'Nom complet',
            validator: _required,
          ),
          _ManagerProfileField(
            controller: _emailController,
            label: 'Adresse email',
            keyboardType: TextInputType.emailAddress,
            validator: _emailValidator,
          ),
          _ManagerProfileField(
            controller: _phoneController,
            label: 'Téléphone',
            keyboardType: TextInputType.phone,
          ),
          _ManagerProfileField(controller: _cityController, label: 'Ville'),
          _ManagerProfileField(
            controller: _addressController,
            label: 'Adresse',
          ),
          _ManagerProfileField(controller: _genderController, label: 'Genre'),
          InkWell(
            onTap: _pickBirthDate,
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Date de naissance',
                border: _managerInputBorder(),
                enabledBorder: _managerInputBorder(),
              ),
              child: Text(
                _birthDate == null ? '-' : _dateLabel(_birthDate!),
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: _DashboardManagerState.managerText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: Text('Annuler'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _DashboardManagerState.managerBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ApiService.updateUser(
        widget.data.id,
        widget.data.toUpdateJson(
          fullName: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          city: _cityController.text.trim(),
          address: _addressController.text.trim(),
          birthDate: _birthDate,
          gender: _genderController.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showManagerSnack(context, 'Impossible de mettre à jour le profil.');
    }
  }
}

class _ManagerChangePasswordPage extends StatefulWidget {
  const _ManagerChangePasswordPage({required this.data});
  final _ManagerProfileData data;

  @override
  State<_ManagerChangePasswordPage> createState() =>
      _ManagerChangePasswordPageState();
}

class _ManagerChangePasswordPageState
    extends State<_ManagerChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _saving = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ManagerSimplePageShell(
    title: 'Sécurité',
    subtitle: 'Modifier votre mot de passe.',
    child: Form(
      key: _formKey,
      child: Column(
        children: [
          _ManagerProfileField(
            controller: _currentController,
            label: 'Mot de passe actuel',
            obscureText: _obscure,
            validator: _required,
            suffix: _passwordToggle(),
          ),
          _ManagerProfileField(
            controller: _newController,
            label: 'Nouveau mot de passe',
            obscureText: _obscure,
            validator: _passwordValidator,
            suffix: _passwordToggle(),
          ),
          _ManagerProfileField(
            controller: _confirmController,
            label: 'Confirmation',
            obscureText: _obscure,
            validator: (value) {
              if (value != _newController.text) {
                return 'La confirmation ne correspond pas.';
              }
              return null;
            },
            suffix: _passwordToggle(),
          ),
          SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _DashboardManagerState.managerBlue,
                foregroundColor: Colors.white,
              ),
              child: Text(_saving ? 'Modification...' : 'Modifier'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _passwordToggle() => IconButton(
    onPressed: () => setState(() => _obscure = !_obscure),
    icon: Icon(_obscure ? LucideIcons.eye : LucideIcons.eyeOff, size: 18),
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ApiService.changePassword(
        widget.data.id,
        _currentController.text,
        _newController.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      _showManagerSnack(context, 'Mot de passe modifié.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showManagerSnack(context, 'Impossible de modifier le mot de passe.');
    }
  }
}

class _ManagerSupportPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _ManagerSimplePageShell(
    title: 'Aide et support',
    subtitle: 'FAQ, assistance et contact.',
    child: Column(
      children: [
        _ManagerInfoTile('FAQ', 'Consultez les questions fréquentes.'),
        _ManagerInfoTile('Contacter le support', 'Support TeaSud'),
        _ManagerInfoTile('Téléphone', '-'),
        _ManagerInfoTile('Email', '-'),
        _ManagerInfoTile('Politique de confidentialité', '-'),
        _ManagerInfoTile("Conditions d'utilisation", '-'),
      ],
    ),
  );
}

class _ManagerAboutPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _ManagerSimplePageShell(
    title: 'À propos',
    subtitle: "Informations sur l'application.",
    child: Column(
      children: [
        _ManagerInfoTile('Nom application', 'TeaSud'),
        _ManagerInfoTile('Version', '-'),
        _ManagerInfoTile('Développeur', '-'),
        _ManagerInfoTile('Entreprise', '-'),
        _ManagerInfoTile('Licence', '-'),
        _ManagerInfoTile('Mentions légales', '-'),
      ],
    ),
  );
}

class _ManagerSimplePageShell extends StatelessWidget {
  const _ManagerSimplePageShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _DashboardManagerState.managerSurface,
    body: _ManagerMobileShell(
      selectedTab: _ManagerTab.profil,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(LucideIcons.arrowLeft),
              color: _DashboardManagerState.managerBlue,
              tooltip: 'Retour',
            ),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Roboto',
                color: _DashboardManagerState.managerText,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'Roboto',
                color: _DashboardManagerState.managerMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: _managerCardDecoration(20),
              child: child,
            ),
          ],
        ),
      ),
    ),
  );
}

class _ManagerProfileField extends StatelessWidget {
  const _ManagerProfileField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: suffix,
        border: _managerInputBorder(),
        enabledBorder: _managerInputBorder(),
        focusedBorder: _managerInputBorder(
          color: _DashboardManagerState.managerBlue,
        ),
      ),
    ),
  );
}

class _ManagerInfoTile extends StatelessWidget {
  const _ManagerInfoTile(this.title, this.value);
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: _DashboardManagerState.managerText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: _DashboardManagerState.managerMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ManagerSheetTitle extends StatelessWidget {
  const _ManagerSheetTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 10),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Roboto',
          color: _DashboardManagerState.managerText,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _ManagerChoiceTile extends StatelessWidget {
  const _ManagerChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    onTap: onTap,
    title: Text(label),
    trailing: selected
        ? Icon(
            LucideIcons.checkCircle,
            color: _DashboardManagerState.managerBlue,
          )
        : null,
  );
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Champ obligatoire.' : null;

String? _emailValidator(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Champ obligatoire.';
  if (!v.contains('@') || !v.contains('.')) return 'Email invalide.';
  return null;
}

String? _passwordValidator(String? value) {
  final v = value ?? '';
  if (v.length < 8) return 'Minimum 8 caractères.';
  if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Ajouter une majuscule.';
  if (!RegExp(r'[a-z]').hasMatch(v)) return 'Ajouter une minuscule.';
  if (!RegExp(r'\d').hasMatch(v)) return 'Ajouter un chiffre.';
  if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=]').hasMatch(v)) {
    return 'Ajouter un caractère spécial.';
  }
  return null;
}

String _languageLabel(String code) => switch (code) {
  'ar' => 'العربية',
  'en' => 'English',
  _ => 'Français',
};

String _themeLabel(AppThemePreference theme) => switch (theme) {
  AppThemePreference.light => 'Clair',
  AppThemePreference.dark => 'Sombre',
  AppThemePreference.system => 'Système',
};

void _showManagerSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}

enum _ManagerTab {
  dashboard,
  commandes,
  commerciaux,
  objectifs,
  rapports,
  profil,
}

class _ManagerMobileShell extends StatelessWidget {
  _ManagerMobileShell({required this.selectedTab, required this.child});

  final _ManagerTab selectedTab;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final phoneWidth = constraints.maxWidth > 390
            ? 390.0
            : constraints.maxWidth;
        final phoneRadius = constraints.maxWidth > phoneWidth ? 28.0 : 0.0;

        return Center(
          child: SizedBox(
            width: phoneWidth,
            height: constraints.maxHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(phoneRadius),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(phoneRadius),
                child: Column(
                  children: [
                    Expanded(child: child),
                    _ManagerBottomNavigation(selectedTab: selectedTab),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ManagerBottomNavigation extends StatelessWidget {
  _ManagerBottomNavigation({required this.selectedTab});

  final _ManagerTab selectedTab;

  @override
  Widget build(BuildContext context) {
    final List<(IconData, String, _ManagerTab, String?)> items = [
      (LucideIcons.home, 'Accueil', _ManagerTab.dashboard, '/home-manager'),
      (
        LucideIcons.receipt,
        'Commandes',
        _ManagerTab.commandes,
        '/manager-commandes',
      ),
      (
        LucideIcons.users,
        'Commerciaux',
        _ManagerTab.commerciaux,
        '/manager-commerciaux',
      ),
      (
        LucideIcons.target,
        'Objectifs',
        _ManagerTab.objectifs,
        '/manager-objectifs',
      ),
      (
        LucideIcons.barChart3,
        'Rapports',
        _ManagerTab.rapports,
        '/manager-rapports',
      ),
      (LucideIcons.user, 'Profil', _ManagerTab.profil, '/manager-profil'),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 14,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final item in items)
                  _ManagerNavItem(
                    icon: item.$1,
                    label: item.$2,
                    selected: selectedTab == item.$3,
                    onTap: selectedTab == item.$3 || item.$4 == null
                        ? null
                        : () =>
                              Navigator.pushReplacementNamed(context, item.$4!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ManagerNavItem extends StatelessWidget {
  _ManagerNavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? _DashboardManagerState.managerBlue
        : _DashboardManagerState.managerMuted;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 21),
              SizedBox(height: 2),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: color,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagerDrawer extends StatelessWidget {
  _ManagerDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text(
                AppLocalizations.globalText('Manager'),
                style: TextStyle(
                  color: _DashboardManagerState._textDark,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _DrawerTile(
              icon: Icons.dashboard_rounded,
              label: AppLocalizations.globalText('Dashboard'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/home-manager');
              },
            ),
            _DrawerTile(
              icon: Icons.groups_rounded,
              label: AppLocalizations.globalText('Commerciaux'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/manager-commerciaux');
              },
            ),
            _DrawerTile(
              icon: Icons.receipt_long_rounded,
              label: AppLocalizations.globalText('Commandes'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/manager-commandes');
              },
            ),
            _DrawerTile(
              icon: Icons.bar_chart_rounded,
              label: AppLocalizations.globalText('Rapports'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/manager-rapports');
              },
            ),
            Spacer(),
            _DrawerTile(
              icon: Icons.logout_rounded,
              label: AppLocalizations.globalText('Deconnexion'),
              onTap: () {
                CurrentUserSession.signOut();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  _DrawerTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: _DashboardManagerState._primaryBlue),
      title: Text(
        label,
        style: TextStyle(
          color: _DashboardManagerState._textDark,
          fontWeight: FontWeight.w800,
        ),
      ),
      onTap: onTap,
    );
  }
}

class DetailCommercialScreen extends StatefulWidget {
  DetailCommercialScreen({
    super.key,
    required this.commercialId,
    required this.commercialName,
  });

  final int commercialId;
  final String commercialName;

  @override
  State<DetailCommercialScreen> createState() => _DetailCommercialScreenState();
}

class _DetailCommercialScreenState extends State<DetailCommercialScreen> {
  final _ordersController = TextEditingController();
  final _revenueController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadObjective();
  }

  @override
  void dispose() {
    _ordersController.dispose();
    _revenueController.dispose();
    super.dispose();
  }

  Future<void> _loadObjective() async {
    final objective = await CommercialObjectivesService.instance.getObjective(
      widget.commercialId,
    );
    if (!mounted) return;
    _ordersController.text = objective?.orderTarget?.toString() ?? '';
    _revenueController.text = objective?.revenueTarget == null
        ? ''
        : objective!.revenueTarget!.round().toString();
    setState(() => _loading = false);
  }

  Future<void> _saveObjective() async {
    final orderTarget = int.tryParse(_ordersController.text.trim());
    final revenueTarget = double.tryParse(
      _revenueController.text.trim().replaceAll(',', '.'),
    );
    setState(() => _saving = true);
    await CommercialObjectivesService.instance.saveObjective(
      CommercialObjective(
        commercialId: widget.commercialId,
        orderTarget: orderTarget != null && orderTarget > 0
            ? orderTarget
            : null,
        revenueTarget: revenueTarget != null && revenueTarget > 0
            ? revenueTarget
            : null,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Objectifs sauvegardés.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _DashboardManagerState._textDark,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final apiCommercial = _ManagerCommercialsCache.byId(widget.commercialId);
    if (apiCommercial != null) {
      return _DetailOrderShell(
        child: _ManagerCommercialApiDetail(
          commercial: apiCommercial,
          onSetObjectives: () {},
        ),
      );
    }
    return _DetailOrderShell(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(18, 14, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back_rounded),
              color: _DashboardManagerState._textDark,
              tooltip: 'Retour',
            ),
            SizedBox(height: 16),
            Text(
              widget.commercialName,
              style: TextStyle(
                color: _DashboardManagerState._textDark,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Définir les objectifs mensuels du commercial',
              style: TextStyle(
                color: _DashboardManagerState._textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 18),
            if (_loading)
              _CommercialsLoadingState()
            else
              _DetailCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Objectifs mensuels',
                      style: TextStyle(
                        color: _DashboardManagerState._textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 14),
                    TextField(
                      controller: _ordersController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Objectif nombre de commandes',
                        prefixIcon: Icon(Icons.shopping_bag_outlined),
                        border: _managerInputBorder(),
                        enabledBorder: _managerInputBorder(),
                        focusedBorder: _managerInputBorder(
                          color: _DashboardManagerState._primaryBlue,
                        ),
                      ),
                    ),
                    SizedBox(height: 14),
                    TextField(
                      controller: _revenueController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Objectif chiffre d'affaires mensuel",
                        suffixText: 'DH',
                        prefixIcon: Icon(Icons.trending_up_rounded),
                        border: _managerInputBorder(),
                        enabledBorder: _managerInputBorder(),
                        focusedBorder: _managerInputBorder(
                          color: _DashboardManagerState._primaryBlue,
                        ),
                      ),
                    ),
                    SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _saveObjective,
                        icon: _saving
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(Icons.save_outlined),
                        label: Text(_saving ? 'Sauvegarde...' : 'Sauvegarder'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _DashboardManagerState._primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ManagerCommercialApiDetail extends StatelessWidget {
  const _ManagerCommercialApiDetail({
    required this.commercial,
    required this.onSetObjectives,
  });

  final _ManagerCommercialView commercial;
  final VoidCallback onSetObjectives;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(18, 14, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(LucideIcons.arrowLeft),
            color: _DashboardManagerState.managerText,
          ),
          SizedBox(height: 12),
          _ManagerDetailCard(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: _DashboardManagerState.iconBlueBg,
                    child: Text(
                      _initials(commercial.name),
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        color: _DashboardManagerState.managerBlue,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          commercial.name,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: _DashboardManagerState.managerText,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          commercial.role,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: _DashboardManagerState.managerBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 6),
                        _CommercialStatusBadge(status: commercial.status),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18),
              _ManagerDetailLine('Téléphone', commercial.phone.ifEmpty('-')),
              _ManagerDetailLine('Email', commercial.email.ifEmpty('-')),
              _ManagerDetailLine('Ville', commercial.city),
              _ManagerDetailLine('Adresse', commercial.address.ifEmpty('-')),
              _ManagerDetailLine('Matricule', commercial.matricule),
              _ManagerDetailLine(
                'Embauche',
                commercial.hiredAt == null
                    ? '-'
                    : '${commercial.hiredAt!.day}/${commercial.hiredAt!.month}/${commercial.hiredAt!.year}',
              ),
            ],
          ),
          SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              _DetailKpi(
                'CA du mois',
                '${_formatNumber(commercial.revenue.round())} DH',
                LucideIcons.coins,
              ),
              _DetailKpi(
                'Objectif',
                commercial.objective <= 0
                    ? '0 DH'
                    : '${_formatNumber(commercial.objective.round())} DH',
                LucideIcons.target,
              ),
              _DetailKpi(
                'Commandes',
                '${commercial.ordersCount}',
                LucideIcons.receipt,
              ),
              _DetailKpi(
                'Clients',
                '${commercial.clientsCount}',
                LucideIcons.users,
              ),
              _DetailKpi(
                'Activités',
                '${commercial.activitiesCount}',
                LucideIcons.calendarCheck,
              ),
              _DetailKpi(
                'Rapports',
                '${commercial.reportsCount}',
                LucideIcons.fileText,
              ),
            ],
          ),
          SizedBox(height: 14),
          _ManagerDetailCard(
            title: 'Graphiques',
            children: [
              _ManagerEmptyInline(
                icon: LucideIcons.lineChart,
                text:
                    'Évolution disponible dès que les données historiques existent.',
              ),
            ],
          ),
          SizedBox(height: 14),
          _ManagerDetailCard(
            title: 'Sections',
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DetailActionChip('Clients', LucideIcons.users),
                  _DetailActionChip('Commandes', LucideIcons.receipt),
                  _DetailActionChip('Activités', LucideIcons.calendarCheck),
                  _DetailActionChip('Rapports', LucideIcons.fileText),
                ],
              ),
            ],
          ),
          SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSetObjectives,
              icon: Icon(LucideIcons.target),
              label: Text('Définir les objectifs'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _DashboardManagerState.managerBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ObjectifsManagerScreen extends StatefulWidget {
  ObjectifsManagerScreen({super.key});

  @override
  State<ObjectifsManagerScreen> createState() => _ObjectifsManagerScreenState();
}

enum _ObjectiveChipFilter { all, withObjective, withoutObjective }

class _ObjectifsManagerScreenState extends State<ObjectifsManagerScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  _ManagerDashboardPeriod _selectedPeriod = _ManagerDashboardPeriod.month;
  DateTimeRange? _customRange;
  _ObjectiveChipFilter _chipFilter = _ObjectiveChipFilter.all;
  Future<_ManagerCommercialsData>? _future;
  String _cityFilter = '';
  String _commercialFilter = '';
  bool? _withObjective;
  bool? _objectiveReached;
  int? _minRate;
  int? _maxRate;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _future = _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final routeEmail = args is Map ? args['email']?.toString() ?? '' : '';
    final sessionUser = CurrentUserSession.currentUser;
    final user = sessionUser?.isManager == true
        ? MockPreSalesData.userByEmail(sessionUser!.email)
        : MockPreSalesData.userByEmail(routeEmail);

    if (sessionUser == null && user == null) {
      _redirectAfterBuild(context, '/login');
      return Scaffold(backgroundColor: Colors.white);
    }
    if (sessionUser?.isCommercial == true ||
        user?.role == MockUserRole.commercial) {
      _redirectAfterBuild(context, '/home-commercial');
      return Scaffold(backgroundColor: Colors.white);
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _DashboardManagerState.managerSurface,
      drawer: _ManagerDrawer(),
      body: _ManagerMobileShell(
        selectedTab: _ManagerTab.objectifs,
        child: RefreshIndicator(
          color: _DashboardManagerState.managerBlue,
          onRefresh: () async => _refresh(),
          child: FutureBuilder<_ManagerCommercialsData>(
            future: _future,
            builder: (context, snapshot) {
              final data =
                  snapshot.data ?? const _ManagerCommercialsData(items: []);
              final visible = _visible(data.items);
              return SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ManagerHomeHeader(
                      managerName: _managerName(user),
                      unreadCount: 0,
                      onMenuPressed: () =>
                          _scaffoldKey.currentState?.openDrawer(),
                      onNotificationsPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NotificationsScreen(),
                          ),
                        );
                      },
                      onAvatarPressed: () {},
                    ),
                    Transform.translate(
                      offset: Offset(0, -10),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.fromLTRB(16, 22, 16, 96),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ManagerObjectivesTitleRow(
                              selectedPeriod: _selectedPeriod,
                              customRange: _customRange,
                              onPeriodChanged: _changePeriod,
                              onDefine: _openDefineObjective,
                            ),
                            SizedBox(height: 18),
                            if (snapshot.connectionState ==
                                ConnectionState.waiting)
                              _ManagerCommercialsSkeleton()
                            else if (snapshot.hasError)
                              _ManagerDashboardError(
                                message: 'Impossible de charger les objectifs.',
                                onRetry: _refresh,
                              )
                            else ...[
                              _ManagerObjectivesKpis(data: data),
                              SizedBox(height: 16),
                              _ManagerObjectivesSearchFilter(
                                controller: _searchController,
                                activeFiltersCount: _activeFiltersCount,
                                onFilterPressed: _openFilterSheet,
                              ),
                              SizedBox(height: 14),
                              _ManagerObjectiveChips(
                                selected: _chipFilter,
                                data: data,
                                onChanged: _setObjectiveChipFilter,
                              ),
                              SizedBox(height: 14),
                              if (visible.isEmpty)
                                _ManagerObjectiveEmptyState(
                                  hasFilters:
                                      _activeFiltersCount > 0 ||
                                      _searchController.text
                                          .trim()
                                          .isNotEmpty ||
                                      _chipFilter != _ObjectiveChipFilter.all,
                                  onReset: _resetFilters,
                                  onDefine: _openDefineObjective,
                                )
                              else
                                for (final commercial in visible) ...[
                                  _ManagerObjectiveCard(
                                    commercial: commercial,
                                    onTap: () =>
                                        _openObjectiveDetail(commercial),
                                  ),
                                  SizedBox(height: 12),
                                ],
                              if (data.items.any((item) => item.objective <= 0))
                                _ManagerObjectiveHint(
                                  onTap: () => setState(
                                    () => _chipFilter =
                                        _ObjectiveChipFilter.withoutObjective,
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<_ManagerCommercialsData> _loadData() async {
    await _syncManagerUnreadNotifications();
    final range = _selectedPeriod.range(_customRange);
    final results = await Future.wait<List<dynamic>>([
      _safeApiList(ApiService.getUsers),
      _safeApiList(ApiService.getFactures),
      _safeApiList(ApiService.getClients),
    ]);
    final orders = results[1]
        .whereType<Map>()
        .map((e) => _ManagerOrderView.fromJson(e.cast<String, dynamic>()))
        .where((order) => order.inRange(range))
        .toList();
    final items = <_ManagerCommercialView>[];
    for (final userJson in results[0].whereType<Map>().map(
      (e) => e.cast<String, dynamic>(),
    )) {
      final role = _readString(userJson, ['role', 'type']);
      if (!role.toLowerCase().contains('commercial')) continue;
      final id = _readInt(userJson, ['id', 'user_id']);
      final commercialOrders = orders
          .where((order) => _commercialMatches(order, id, userJson))
          .toList();
      final validated = commercialOrders
          .where((order) => order.status == _ManagerOrderApiStatus.validated)
          .toList();
      final objective = await CommercialObjectivesService.instance.getObjective(
        id,
      );
      items.add(
        _ManagerCommercialView(
          id: id,
          name: _readUserDisplayName(userJson).ifEmpty('Commercial'),
          email: _readString(userJson, ['email']),
          phone: _readString(userJson, ['phone', 'telephone']),
          city: _readString(userJson, ['city', 'ville']).ifEmpty('-'),
          address: _readString(userJson, ['address', 'adresse']),
          matricule: _readString(userJson, [
            'matricule',
            'code',
          ]).ifEmpty('COM-${id.toString().padLeft(3, '0')}'),
          role: 'Commercial',
          status: _parseCommercialStatus(
            _readString(userJson, ['status', 'statut', 'etat']),
          ),
          revenue: validated.fold(0, (sum, order) => sum + order.total),
          objective: objective?.revenueTarget ?? 0,
          ordersCount: validated.length,
          clientsCount: results[2].whereType<Map>().where((client) {
            final commercialId = _readNullableInt(client, [
              'commercial_id',
              'id_commercial',
              'user_id',
              'created_by',
            ]);
            return commercialId == null || commercialId == id;
          }).length,
          activitiesCount: 0,
          reportsCount: objective?.orderTarget ?? 0,
          hiredAt: _readDate(userJson, ['hire_date', 'created_at']),
        ),
      );
    }
    items.sort((a, b) => b.objectiveRate.compareTo(a.objectiveRate));
    _ManagerCommercialsCache.replaceAll(items);
    return _ManagerCommercialsData(items: items);
  }

  bool _commercialMatches(
    _ManagerOrderView order,
    int id,
    Map<String, dynamic> user,
  ) {
    final rawId = _readNullableInt(order.raw, [
      'commercial_id',
      'user_id',
      'created_by',
      'vendeur_id',
    ]);
    if (rawId != null) return rawId == id;
    final name = _readUserDisplayName(user);
    return name.isNotEmpty &&
        order.commercialName.toLowerCase().contains(name.toLowerCase());
  }

  List<_ManagerCommercialView> _visible(List<_ManagerCommercialView> source) {
    final query = _searchController.text.trim().toLowerCase();
    return source.where((item) {
      final hasObjective = item.objective > 0 || item.reportsCount > 0;
      final chipOk = switch (_chipFilter) {
        _ObjectiveChipFilter.all => true,
        _ObjectiveChipFilter.withObjective => hasObjective,
        _ObjectiveChipFilter.withoutObjective => !hasObjective,
      };
      return item.matchesSearch(query) &&
          chipOk &&
          (_cityFilter.isEmpty ||
              item.city.toLowerCase().contains(_cityFilter.toLowerCase())) &&
          (_commercialFilter.isEmpty ||
              item.name.toLowerCase().contains(
                _commercialFilter.toLowerCase(),
              )) &&
          (_withObjective == null || hasObjective == _withObjective) &&
          (_objectiveReached == null ||
              (item.objectiveRate >= 100) == _objectiveReached) &&
          (_minRate == null || item.objectiveRate >= _minRate!) &&
          (_maxRate == null || item.objectiveRate <= _maxRate!);
    }).toList();
  }

  void _setObjectiveChipFilter(_ObjectiveChipFilter filter) {
    _searchController.clear();
    setState(() {
      _chipFilter = filter;
      _cityFilter = '';
      _commercialFilter = '';
      _withObjective = null;
      _objectiveReached = null;
      _minRate = null;
      _maxRate = null;
    });
  }

  int get _activeFiltersCount {
    var count = 0;
    if (_cityFilter.isNotEmpty) count++;
    if (_commercialFilter.isNotEmpty) count++;
    if (_withObjective != null) count++;
    if (_objectiveReached != null) count++;
    if (_minRate != null) count++;
    if (_maxRate != null) count++;
    return count;
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _chipFilter = _ObjectiveChipFilter.all;
      _cityFilter = '';
      _commercialFilter = '';
      _withObjective = null;
      _objectiveReached = null;
      _minRate = null;
      _maxRate = null;
    });
  }

  Future<void> _changePeriod(_ManagerDashboardPeriod period) async {
    DateTimeRange? range = _customRange;
    if (period == _ManagerDashboardPeriod.custom) {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 5),
        lastDate: DateTime(now.year + 1),
        initialDateRange:
            range ??
            DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
      );
      if (picked == null) return;
      range = picked;
    }
    setState(() {
      _selectedPeriod = period;
      _customRange = range;
      _future = _loadData();
    });
  }

  void _refresh() {
    setState(() => _future = _loadData());
  }

  Future<List<dynamic>> _safeApiList(Future<List<dynamic>> Function() loader) {
    return loader().catchError((_) => <dynamic>[]);
  }

  void _openDefineObjective() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DefineObjectiveScreen(
          commercials: _ManagerCommercialsCache._items.values.toList(),
        ),
      ),
    ).then((_) => _refresh());
  }

  void _openObjectiveDetail(_ManagerCommercialView commercial) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ObjectiveDetailScreen(commercial: commercial),
      ),
    ).then((_) => _refresh());
  }

  void _openFilterSheet() {
    final city = TextEditingController(text: _cityFilter);
    final commercial = TextEditingController(text: _commercialFilter);
    final min = TextEditingController(text: _minRate?.toString() ?? '');
    final max = TextEditingController(text: _maxRate?.toString() ?? '');
    var withObjective = _withObjective;
    var objectiveReached = _objectiveReached;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  MediaQuery.of(context).viewInsets.bottom + 18,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filtres objectifs',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: _DashboardManagerState.managerText,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 12),
                      _ManagerFilterField(controller: city, label: 'Ville'),
                      _ManagerFilterField(
                        controller: commercial,
                        label: 'Commercial',
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text('Avec objectif'),
                            selected: withObjective == true,
                            onSelected: (_) =>
                                setSheetState(() => withObjective = true),
                          ),
                          ChoiceChip(
                            label: Text('Sans objectif'),
                            selected: withObjective == false,
                            onSelected: (_) =>
                                setSheetState(() => withObjective = false),
                          ),
                          ChoiceChip(
                            label: Text('Objectif atteint'),
                            selected: objectiveReached == true,
                            onSelected: (_) =>
                                setSheetState(() => objectiveReached = true),
                          ),
                          ChoiceChip(
                            label: Text('Non atteint'),
                            selected: objectiveReached == false,
                            onSelected: (_) =>
                                setSheetState(() => objectiveReached = false),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ManagerFilterField(
                              controller: min,
                              label: '% min',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: _ManagerFilterField(
                              controller: max,
                              label: '% max',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                _resetFilters();
                                Navigator.pop(context);
                              },
                              child: Text('Réinitialiser'),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _cityFilter = city.text.trim();
                                  _commercialFilter = commercial.text.trim();
                                  _withObjective = withObjective;
                                  _objectiveReached = objectiveReached;
                                  _minRate = int.tryParse(min.text.trim());
                                  _maxRate = int.tryParse(max.text.trim());
                                });
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _DashboardManagerState.managerBlue,
                                foregroundColor: Colors.white,
                              ),
                              child: Text('Appliquer'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _managerName(MockUserProfile? fallbackUser) {
    final sessionName = CurrentUserSession.currentUser?.fullName.trim() ?? '';
    if (sessionName.isNotEmpty) return sessionName;
    final fallbackName = fallbackUser?.name.trim() ?? '';
    return fallbackName.isNotEmpty ? fallbackName : 'Manager';
  }

  void _redirectAfterBuild(BuildContext context, String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
    });
  }
}

class _DetailKpi extends StatelessWidget {
  const _DetailKpi(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: _managerCardDecoration(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _DashboardManagerState.managerBlue, size: 20),
          Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: _DashboardManagerState.managerText,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: _DashboardManagerState.managerMuted,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailActionChip extends StatelessWidget {
  const _DetailActionChip(this.label, this.icon);
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: _DashboardManagerState.managerBlue),
      label: Text(label),
      backgroundColor: _DashboardManagerState.iconBlueBg,
    );
  }
}

class _ObjectiveDetailScreen extends StatelessWidget {
  const _ObjectiveDetailScreen({required this.commercial});
  final _ManagerCommercialView commercial;

  @override
  Widget build(BuildContext context) {
    final orderRate = commercial.reportsCount <= 0
        ? 0
        : ((commercial.ordersCount / commercial.reportsCount) * 100).round();
    return _DetailOrderShell(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(18, 14, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(LucideIcons.arrowLeft),
              color: _DashboardManagerState.managerText,
            ),
            SizedBox(height: 12),
            _ManagerDetailCard(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: _DashboardManagerState.iconBlueBg,
                      child: Text(
                        _initials(commercial.name),
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: _DashboardManagerState.managerBlue,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            commercial.name,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              color: _DashboardManagerState.managerText,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            commercial.email.ifEmpty('-'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              color: _DashboardManagerState.managerMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                _ManagerDetailLine('Téléphone', commercial.phone.ifEmpty('-')),
                _ManagerDetailLine('Ville', commercial.city),
                _ManagerDetailLine('Matricule', commercial.matricule),
              ],
            ),
            SizedBox(height: 14),
            _ManagerDetailCard(
              title: 'Objectif chiffre d’affaires',
              children: [
                _ManagerDetailLine(
                  'Objectif CA',
                  '${_formatNumber(commercial.objective.round())} DH',
                ),
                _ManagerDetailLine(
                  'CA réalisé',
                  '${_formatNumber(commercial.revenue.round())} DH',
                ),
                _ManagerDetailLine(
                  'Pourcentage',
                  '${commercial.objectiveRate}%',
                ),
                LinearProgressIndicator(
                  value: (commercial.objectiveRate / 100).clamp(0, 1),
                  minHeight: 6,
                  color: _objectiveRateColor(commercial.objectiveRate),
                  backgroundColor: _DashboardManagerState.managerBorder,
                ),
              ],
            ),
            SizedBox(height: 14),
            _ManagerDetailCard(
              title: 'Objectif commandes',
              children: [
                _ManagerDetailLine(
                  'Objectif commandes',
                  '${commercial.reportsCount}',
                ),
                _ManagerDetailLine(
                  'Commandes réalisées',
                  '${commercial.ordersCount}',
                ),
                _ManagerDetailLine('Pourcentage', '$orderRate%'),
                LinearProgressIndicator(
                  value: (orderRate / 100).clamp(0, 1),
                  minHeight: 6,
                  color: _objectiveRateColor(orderRate),
                  backgroundColor: _DashboardManagerState.managerBorder,
                ),
              ],
            ),
            SizedBox(height: 14),
            _ManagerDetailCard(
              title: 'Graphiques',
              children: [
                _ManagerEmptyInline(
                  icon: LucideIcons.lineChart,
                  text:
                      'Évolution du CA et des commandes disponible avec l’historique.',
                ),
              ],
            ),
            SizedBox(height: 14),
            _ManagerDetailCard(
              title: 'Historique et commentaires',
              children: [
                Text(
                  'Aucun commentaire manager enregistré.',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: _DashboardManagerState.managerMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DefineObjectiveScreen extends StatefulWidget {
  const _DefineObjectiveScreen({required this.commercials});
  final List<_ManagerCommercialView> commercials;

  @override
  State<_DefineObjectiveScreen> createState() => _DefineObjectiveScreenState();
}

class _DefineObjectiveScreenState extends State<_DefineObjectiveScreen> {
  _ManagerCommercialView? _selected;
  final _revenueController = TextEditingController();
  final _ordersController = TextEditingController();
  final _commentController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.commercials.isNotEmpty) {
      _selected = widget.commercials.first;
      _fill(_selected!);
    }
  }

  @override
  void dispose() {
    _revenueController.dispose();
    _ordersController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _fill(_ManagerCommercialView commercial) {
    _revenueController.text = commercial.objective > 0
        ? commercial.objective.round().toString()
        : '';
    _ordersController.text = commercial.reportsCount > 0
        ? commercial.reportsCount.toString()
        : '';
  }

  @override
  Widget build(BuildContext context) {
    return _DetailOrderShell(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(18, 14, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(LucideIcons.arrowLeft),
              color: _DashboardManagerState.managerText,
            ),
            SizedBox(height: 12),
            Text(
              'Définir les objectifs',
              style: TextStyle(
                fontFamily: 'Roboto',
                color: _DashboardManagerState.managerText,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Créez ou modifiez les objectifs mensuels.',
              style: TextStyle(
                fontFamily: 'Roboto',
                color: _DashboardManagerState.managerMuted,
                fontSize: 12,
              ),
            ),
            SizedBox(height: 18),
            _ManagerDetailCard(
              children: [
                DropdownButtonFormField<_ManagerCommercialView>(
                  initialValue: _selected,
                  items: widget.commercials
                      .map(
                        (commercial) => DropdownMenuItem(
                          value: commercial,
                          child: Text(commercial.name),
                        ),
                      )
                      .toList(),
                  onChanged: (commercial) {
                    if (commercial == null) return;
                    setState(() {
                      _selected = commercial;
                      _fill(commercial);
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Commercial',
                    border: _managerInputBorder(),
                    enabledBorder: _managerInputBorder(),
                  ),
                ),
                SizedBox(height: 14),
                TextField(
                  controller: _revenueController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Objectif CA',
                    suffixText: 'DH',
                    border: _managerInputBorder(),
                    enabledBorder: _managerInputBorder(),
                  ),
                ),
                SizedBox(height: 14),
                TextField(
                  controller: _ordersController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Objectif nombre de commandes',
                    border: _managerInputBorder(),
                    enabledBorder: _managerInputBorder(),
                  ),
                ),
                SizedBox(height: 14),
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Commentaire',
                    border: _managerInputBorder(),
                    enabledBorder: _managerInputBorder(),
                  ),
                ),
                SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        child: Text('Annuler'),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _DashboardManagerState.managerBlue,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          _saving ? 'Enregistrement...' : 'Enregistrer',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final selected = _selected;
    final revenue = double.tryParse(
      _revenueController.text.replaceAll(',', '.'),
    );
    final orders = int.tryParse(_ordersController.text.trim());
    if (selected == null ||
        revenue == null ||
        revenue <= 0 ||
        orders == null ||
        orders <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Le CA doit être positif et les commandes supérieures à zéro.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    await CommercialObjectivesService.instance.saveObjective(
      CommercialObjective(
        commercialId: selected.id,
        revenueTarget: revenue,
        orderTarget: orders,
      ),
    );
    if (!mounted) return;
    Navigator.pop(context);
  }
}

class _ManagerOrderDetailPage extends StatefulWidget {
  const _ManagerOrderDetailPage({required this.orderId, this.initial});

  final int orderId;
  final _ManagerOrderView? initial;

  @override
  State<_ManagerOrderDetailPage> createState() =>
      _ManagerOrderDetailPageState();
}

class _ManagerOrderDetailHeader extends StatelessWidget {
  const _ManagerOrderDetailHeader({
    required this.title,
    required this.subtitle,
  });
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
    height: 104,
    padding: EdgeInsets.fromLTRB(10, 8, 16, 0),
    color: _DashboardManagerState.managerHeader,
    child: Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(LucideIcons.arrowLeft, size: 30),
          color: Colors.white,
        ),
        SizedBox(width: 4),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: Color(0xFFD8E2F3),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        ValueListenableBuilder<int>(
          valueListenable: _managerUnreadNotifications,
          builder: (context, unread, child) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NotificationsScreen()),
                  ),
                  icon: Icon(LucideIcons.bell),
                  color: Colors.white,
                ),
                if (unread > 0)
                  Positioned(
                    right: 7,
                    top: 5,
                    child: Container(
                      constraints: BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: _DashboardManagerState.managerRed,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Center(
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        CircleAvatar(
          radius: 24,
          backgroundColor: _DashboardManagerState.iconBlueBg,
          child: Text(
            'MB',
            style: TextStyle(
              fontFamily: 'Roboto',
              color: _DashboardManagerState.managerBlue,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ManagerOrderDetailMessage extends StatelessWidget {
  const _ManagerOrderDetailMessage({
    required this.icon,
    required this.title,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(24),
        decoration: _managerCardDecoration(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ManagerSoftIcon(
              icon: icon,
              color: _DashboardManagerState.managerBlue,
              backgroundColor: _DashboardManagerState.iconBlueBg,
              size: 72,
            ),
            SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                color: _DashboardManagerState.managerText,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(onPressed: onPressed, child: Text(buttonLabel)),
          ],
        ),
      ),
    ),
  );
}

class _ManagerOrderDetailContent extends StatelessWidget {
  const _ManagerOrderDetailContent({
    required this.order,
    required this.commentController,
    required this.onSaveComment,
    required this.onOpenCommercial,
    required this.onOpenClient,
  });

  final _ManagerOrderView order;
  final TextEditingController commentController;
  final VoidCallback onSaveComment;
  final VoidCallback onOpenCommercial;
  final VoidCallback onOpenClient;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _ManagerOrderMainCard(order: order),
      SizedBox(height: 14),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _ManagerOrderPersonCard.commercial(order, onOpenCommercial),
          ),
          SizedBox(width: 10),
          Expanded(child: _ManagerOrderPersonCard.client(order, onOpenClient)),
        ],
      ),
      SizedBox(height: 14),
      _ManagerOrderInfoCard(order: order),
      SizedBox(height: 14),
      _ManagerOrderProductsCard(order: order),
      SizedBox(height: 14),
      _ManagerOrderNotesCard(order: order),
      SizedBox(height: 14),
      _ManagerOrderCommentsCard(
        order: order,
        controller: commentController,
        onSave: onSaveComment,
      ),
      SizedBox(height: 14),
      _ManagerOrderHistoryCard(order: order),
    ],
  );
}

class _ManagerOrderMainCard extends StatelessWidget {
  const _ManagerOrderMainCard({required this.order});
  final _ManagerOrderView order;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(16),
    decoration: _managerCardDecoration(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ManagerApiStatusBadge(status: order.status),
        SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                'Commande #${order.number}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: _DashboardManagerState.managerText,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Montant total',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: _DashboardManagerState.managerMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${_formatMoney(order.total)} DH',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: _DashboardManagerState.managerBlue,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Icon(
              LucideIcons.calendar,
              size: 16,
              color: _DashboardManagerState.managerMuted,
            ),
            SizedBox(width: 8),
            Text(
              '${order.dateLabel} à ${order.timeLabel}',
              style: TextStyle(
                fontFamily: 'Roboto',
                color: _DashboardManagerState.managerMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ManagerOrderPersonCard extends StatelessWidget {
  const _ManagerOrderPersonCard._({
    required this.title,
    required this.name,
    required this.code,
    required this.phone,
    required this.city,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  factory _ManagerOrderPersonCard.commercial(
    _ManagerOrderView order,
    VoidCallback onTap,
  ) => _ManagerOrderPersonCard._(
    title: 'Commercial',
    name: order.commercialName,
    code: order.commercialMatricule.ifEmpty('-'),
    phone: order.commercialPhone.ifEmpty('-'),
    city: order.commercialCity.ifEmpty('-'),
    icon: LucideIcons.user,
    color: _DashboardManagerState.managerBlue,
    onTap: onTap,
  );

  factory _ManagerOrderPersonCard.client(
    _ManagerOrderView order,
    VoidCallback onTap,
  ) => _ManagerOrderPersonCard._(
    title: 'Client',
    name: order.clientName,
    code: order.clientCode.ifEmpty('-'),
    phone: order.clientPhone.ifEmpty('-'),
    city: order.clientCity.ifEmpty('-'),
    icon: LucideIcons.store,
    color: _DashboardManagerState.managerGreen,
    onTap: onTap,
  );

  final String title;
  final String name;
  final String code;
  final String phone;
  final String city;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: EdgeInsets.all(13),
      decoration: _managerCardDecoration(20),
      child: Column(
        children: [
          Row(
            children: [
              _ManagerSoftIcon(
                icon: icon,
                color: color,
                backgroundColor: color.withValues(alpha: .12),
                size: 42,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: _DashboardManagerState.managerMuted,
              ),
            ],
          ),
          SizedBox(height: 12),
          CircleAvatar(
            radius: 30,
            backgroundColor: color.withValues(alpha: .12),
            child: Text(
              _orderInitials(name),
              style: TextStyle(
                fontFamily: 'Roboto',
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: 10),
          Text(
            name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: _DashboardManagerState.managerText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 3),
          Text(
            code,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: _DashboardManagerState.managerMuted,
              fontSize: 11,
            ),
          ),
          SizedBox(height: 8),
          _MiniInfo(icon: LucideIcons.phone, text: phone),
          _MiniInfo(icon: LucideIcons.mapPin, text: city),
        ],
      ),
    ),
  );
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Icon(icon, size: 13, color: _DashboardManagerState.managerMuted),
        SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: _DashboardManagerState.managerMuted,
              fontSize: 10.5,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ManagerOrderInfoCard extends StatelessWidget {
  const _ManagerOrderInfoCard({required this.order});
  final _ManagerOrderView order;
  @override
  Widget build(BuildContext context) => _ManagerDetailCard(
    title: 'Informations commande',
    children: [
      _ManagerDetailLine('Statut', _orderStatusLabel(order.status)),
      _ManagerDetailLine('Mode de paiement', order.paymentMode.ifEmpty('-')),
      _ManagerDetailLine(
        'Date de livraison',
        order.deliveryDate == null ? '-' : _dateLabel(order.deliveryDate!),
      ),
      _ManagerDetailLine(
        'Référence commande',
        order.referenceClient.ifEmpty(order.number),
      ),
      _ManagerDetailLine('Remises', '${_formatMoney(order.discount)} DH'),
      _ManagerDetailLine('Observations', order.notes.ifEmpty('-')),
    ],
  );
}

class _ManagerOrderProductsCard extends StatelessWidget {
  const _ManagerOrderProductsCard({required this.order});
  final _ManagerOrderView order;
  @override
  Widget build(BuildContext context) => Container(
    decoration: _managerCardDecoration(20),
    child: Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                LucideIcons.shoppingCart,
                color: _DashboardManagerState.managerBlue,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Produits commandés',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: _DashboardManagerState.managerText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${order.productsCount} produits',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: _DashboardManagerState.managerMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (order.lines.isEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'Aucun produit disponible.',
              style: TextStyle(
                fontFamily: 'Roboto',
                color: _DashboardManagerState.managerMuted,
                fontSize: 12,
              ),
            ),
          )
        else
          for (final line in order.lines) _ManagerOrderProductLine(line: line),
        Divider(height: 1, color: _DashboardManagerState.managerBorder),
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              _TotalLine('Sous-total', _orderSubtotal(order)),
              _TotalLine('Remise totale', order.discount),
              _TotalLine('TVA', order.tax),
              _TotalLine('Montant total TTC', order.total, strong: true),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ManagerOrderProductLine extends StatelessWidget {
  const _ManagerOrderProductLine({required this.line});
  final _ManagerOrderLineView line;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _DashboardManagerState.iconBlueBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: line.image.startsWith('http')
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(line.image, fit: BoxFit.cover),
                )
              : Icon(
                  LucideIcons.package,
                  color: _DashboardManagerState.managerBlue,
                ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: _DashboardManagerState.managerText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                line.reference.ifEmpty('-'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: _DashboardManagerState.managerMuted,
                  fontSize: 10.5,
                ),
              ),
              Text(
                '${_formatMoney(line.unitPrice)} DH x ${_compactQty(line.quantity)}',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: _DashboardManagerState.managerMuted,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${_formatMoney(line.total)} DH',
              style: TextStyle(
                fontFamily: 'Roboto',
                color: _DashboardManagerState.managerText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (line.discount > 0)
              Text(
                '-${_formatMoney(line.discount)} DH',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: _DashboardManagerState.managerRed,
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

class _TotalLine extends StatelessWidget {
  const _TotalLine(this.label, this.value, {this.strong = false});
  final String label;
  final double value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: strong
                  ? _DashboardManagerState.managerBlue
                  : _DashboardManagerState.managerMuted,
              fontSize: strong ? 14 : 12,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
        Text(
          '${_formatMoney(value)} DH',
          style: TextStyle(
            fontFamily: 'Roboto',
            color: strong
                ? _DashboardManagerState.managerBlue
                : _DashboardManagerState.managerText,
            fontSize: strong ? 15 : 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _ManagerOrderNotesCard extends StatelessWidget {
  const _ManagerOrderNotesCard({required this.order});
  final _ManagerOrderView order;
  @override
  Widget build(BuildContext context) => _ManagerDetailCard(
    title: 'Notes du commercial',
    children: [
      Text(
        order.notes.ifEmpty('Aucune note.'),
        style: TextStyle(
          fontFamily: 'Roboto',
          color: _DashboardManagerState.managerMuted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

class _ManagerOrderCommentsCard extends StatelessWidget {
  const _ManagerOrderCommentsCard({
    required this.order,
    required this.controller,
    required this.onSave,
  });
  final _ManagerOrderView order;
  final TextEditingController controller;
  final VoidCallback onSave;
  @override
  Widget build(BuildContext context) => _ManagerDetailCard(
    title: 'Commentaires manager',
    children: [
      if (order.managerComments.isEmpty)
        Text(
          'Aucun commentaire.',
          style: TextStyle(
            fontFamily: 'Roboto',
            color: _DashboardManagerState.managerMuted,
            fontSize: 12,
          ),
        )
      else
        for (final comment in order.managerComments)
          _ManagerDetailLine(
            _readString(comment, [
              'manager_name',
              'manager',
            ]).ifEmpty('Manager'),
            _readString(comment, ['comment', 'text', 'message']),
          ),
      SizedBox(height: 12),
      TextField(
        controller: controller,
        minLines: 2,
        maxLines: 4,
        decoration: InputDecoration(
          labelText: 'Ajouter un commentaire',
          border: _managerInputBorder(),
          enabledBorder: _managerInputBorder(),
        ),
      ),
      SizedBox(height: 10),
      Align(
        alignment: Alignment.centerRight,
        child: ElevatedButton(onPressed: onSave, child: Text('Enregistrer')),
      ),
    ],
  );
}

class _ManagerOrderHistoryCard extends StatelessWidget {
  const _ManagerOrderHistoryCard({required this.order});
  final _ManagerOrderView order;
  @override
  Widget build(BuildContext context) {
    final history = order.history.isEmpty
        ? [
            {
              'title': 'Commande créée',
              'date': '${order.dateLabel} ${order.timeLabel}',
              'user': order.commercialName,
            },
            if (order.status == _ManagerOrderApiStatus.validated)
              {'title': 'Commande validée', 'date': '-', 'user': 'Manager'},
            if (order.status == _ManagerOrderApiStatus.refused)
              {'title': 'Commande refusée', 'date': '-', 'user': 'Manager'},
          ]
        : order.history;
    return _ManagerDetailCard(
      title: 'Historique',
      children: [
        for (final item in history)
          _ManagerHistoryRow(
            title: _readString(item, [
              'title',
              'action',
              'description',
            ]).ifEmpty('Événement'),
            subtitle:
                '${_readString(item, ['date', 'created_at']).ifEmpty('-')} • ${_readString(item, ['user', 'username']).ifEmpty('-')}',
          ),
      ],
    );
  }
}

class _ManagerHistoryRow extends StatelessWidget {
  const _ManagerHistoryRow({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: EdgeInsets.only(top: 5),
          decoration: BoxDecoration(
            color: _DashboardManagerState.managerBlue,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: _DashboardManagerState.managerText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: _DashboardManagerState.managerMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ManagerOrderStickyActions extends StatelessWidget {
  const _ManagerOrderStickyActions({
    required this.order,
    required this.saving,
    required this.onPdf,
    this.onValidate,
    this.onRefuse,
  });
  final _ManagerOrderView order;
  final bool saving;
  final VoidCallback onPdf;
  final VoidCallback? onValidate;
  final VoidCallback? onRefuse;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .08),
          blurRadius: 18,
          offset: Offset(0, -6),
        ),
      ],
      border: Border(
        top: BorderSide(color: _DashboardManagerState.managerBorder),
      ),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: saving ? null : onPdf,
                icon: Icon(LucideIcons.download, size: 17),
                label: Text('PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _DashboardManagerState.managerBlue,
                  side: BorderSide(color: _DashboardManagerState.managerBlue),
                ),
              ),
            ),
            if (onRefuse != null) ...[
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: saving ? null : onRefuse,
                  icon: Icon(LucideIcons.x, size: 17),
                  label: Text('Refuser'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _DashboardManagerState.managerRed,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
            if (onValidate != null) ...[
              SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: saving ? null : onValidate,
                  icon: Icon(LucideIcons.checkCircle, size: 17),
                  label: Text('Valider'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _DashboardManagerState.managerGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

double _orderSubtotal(_ManagerOrderView order) => order.lines
    .fold<double>(0, (sum, line) => sum + line.total)
    .nonZero(order.total + order.discount - order.tax);

String _formatMoney(double value) => value
    .toStringAsFixed(2)
    .replaceAll('.', ',')
    .replaceAll(RegExp(r',00$'), '');

String _compactQty(double value) => value.truncateToDouble() == value
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

String _orderStatusLabel(_ManagerOrderApiStatus status) => switch (status) {
  _ManagerOrderApiStatus.pending => 'En attente',
  _ManagerOrderApiStatus.validated => 'Validée',
  _ManagerOrderApiStatus.refused => 'Refusée',
  _ManagerOrderApiStatus.all => 'Toutes',
};

String _orderInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .take(2)
      .toList();
  if (parts.isEmpty) return '--';
  return parts.map((e) => e.characters.first).join().toUpperCase();
}

class _ManagerOrderDetailPageState extends State<_ManagerOrderDetailPage> {
  late Future<_ManagerOrderView?> _future;
  final _commentController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<_ManagerOrderView?> _load() async {
    try {
      await _syncManagerUnreadNotifications();
      final json = await ApiService.getCommande(widget.orderId);
      final data = json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : json;
      return _ManagerOrderView.fromJson(data);
    } catch (_) {
      return widget.initial ?? _ManagerOrdersCache.byId(widget.orderId);
    }
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _DashboardManagerState.managerSurface,
    body: _ManagerMobileShell(
      selectedTab: _ManagerTab.commandes,
      child: FutureBuilder<_ManagerOrderView?>(
        future: _future,
        builder: (context, snapshot) {
          final order = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              children: [
                _ManagerOrderDetailHeader(
                  title: 'Détail commande',
                  subtitle: 'Chargement',
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: _ManagerCommercialsSkeleton(),
                  ),
                ),
              ],
            );
          }
          if (order == null) {
            return Column(
              children: [
                _ManagerOrderDetailHeader(
                  title: 'Détail commande',
                  subtitle: 'Commande introuvable',
                ),
                Expanded(
                  child: _ManagerOrderDetailMessage(
                    icon: LucideIcons.searchX,
                    title: snapshot.hasError
                        ? 'Impossible de charger cette commande.'
                        : 'Commande introuvable.',
                    buttonLabel: snapshot.hasError ? 'Réessayer' : 'Retour',
                    onPressed: snapshot.hasError
                        ? _refresh
                        : () => Navigator.pop(context),
                  ),
                ),
              ],
            );
          }
          return Column(
            children: [
              _ManagerOrderDetailHeader(
                title: 'Détail commande',
                subtitle: 'Commande #${order.number}',
              ),
              Expanded(
                child: Stack(
                  children: [
                    RefreshIndicator(
                      color: _DashboardManagerState.managerBlue,
                      onRefresh: _refresh,
                      child: SingleChildScrollView(
                        physics: AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(16, 18, 16, 132),
                        child: _ManagerOrderDetailContent(
                          order: order,
                          commentController: _commentController,
                          onSaveComment: () => _saveComment(order),
                          onOpenCommercial: () => _openCommercial(order),
                          onOpenClient: () => _openClient(order),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _ManagerOrderStickyActions(
                        order: order,
                        saving: _saving,
                        onPdf: () => _downloadPdf(order),
                        onValidate:
                            order.status == _ManagerOrderApiStatus.pending
                            ? () => _confirmValidate(order)
                            : null,
                        onRefuse: order.status == _ManagerOrderApiStatus.pending
                            ? () => _openRefuseSheet(order)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Future<void> _saveComment(_ManagerOrderView order) async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ApiService.addCommandeComment(
        order.id,
        comment,
        managerId: CurrentUserSession.currentUser?.id,
      );
      _commentController.clear();
      await _refresh();
    } catch (_) {
      if (mounted)
        _showManagerSnack(context, 'Impossible d’enregistrer le commentaire.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmValidate(_ManagerOrderView order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmer la validation ?'),
        content: Text('La commande #${order.number} sera validée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Valider'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _updateStatus(order, 'validee');
  }

  Future<void> _openRefuseSheet(_ManagerOrderView order) async {
    final reasonController = TextEditingController();
    String selected = 'Prix incorrect';
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              18,
              18,
              18 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Motif du refus',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 12),
                for (final option in [
                  'Prix incorrect',
                  'Quantité incorrecte',
                  'Informations manquantes',
                  'Autre',
                ])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => setSheetState(() => selected = option),
                    leading: Icon(
                      selected == option
                          ? LucideIcons.checkCircle
                          : LucideIcons.circle,
                      color: selected == option
                          ? _DashboardManagerState.managerBlue
                          : _DashboardManagerState.managerMuted,
                    ),
                    title: Text(option),
                  ),
                TextField(
                  controller: reasonController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: selected == 'Autre'
                        ? 'Motif obligatoire'
                        : 'Détail du motif',
                    border: _managerInputBorder(),
                    enabledBorder: _managerInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _DashboardManagerState.managerRed,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      final typed = reasonController.text.trim();
                      if (selected == 'Autre' && typed.isEmpty) return;
                      Navigator.pop(context, typed.ifEmpty(selected));
                    },
                    child: Text('Confirmer le refus'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (reason != null) await _updateStatus(order, 'refusee', reason: reason);
  }

  Future<void> _updateStatus(
    _ManagerOrderView order,
    String status, {
    String? reason,
  }) async {
    setState(() => _saving = true);
    try {
      await ApiService.updateCommandeStatus(
        order.id,
        status,
        refusalReason: reason,
        managerId: CurrentUserSession.currentUser?.id,
      );
      await _refresh();
    } catch (_) {
      if (mounted)
        _showManagerSnack(context, 'Impossible de mettre à jour la commande.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _downloadPdf(_ManagerOrderView order) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            'Commande #${order.number}',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Date: ${order.dateLabel} ${order.timeLabel}'),
          pw.Text('Commercial: ${order.commercialName}'),
          pw.Text('Client: ${order.clientName}'),
          pw.Text('Statut: ${_orderStatusLabel(order.status)}'),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Produit', 'Réf.', 'Qté', 'PU', 'Remise', 'Total'],
            data: order.lines
                .map(
                  (line) => [
                    line.name,
                    line.reference,
                    _compactQty(line.quantity),
                    '${_formatMoney(line.unitPrice)} DH',
                    '${_formatMoney(line.discount)} DH',
                    '${_formatMoney(line.total)} DH',
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Sous-total: ${_formatMoney(_orderSubtotal(order))} DH'),
          pw.Text('Remise: ${_formatMoney(order.discount)} DH'),
          pw.Text('TVA: ${_formatMoney(order.tax)} DH'),
          pw.Text('Total TTC: ${_formatMoney(order.total)} DH'),
          pw.SizedBox(height: 12),
          pw.Text('Notes: ${order.notes.ifEmpty('Aucune note.')}'),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  void _openCommercial(_ManagerOrderView order) {
    if (order.commercialId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailCommercialScreen(
          commercialId: order.commercialId!,
          commercialName: order.commercialName,
        ),
      ),
    );
  }

  void _openClient(_ManagerOrderView order) {
    _showManagerSnack(context, 'Fiche client non configurée dans les routes.');
  }
}

class DetailCommandeScreen extends StatefulWidget {
  DetailCommandeScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<DetailCommandeScreen> createState() => _DetailCommandeScreenState();
}

class _DetailCommandeScreenState extends State<DetailCommandeScreen> {
  final bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final sessionUser = CurrentUserSession.currentUser;
    final apiOrder = _ManagerOrdersCache.byId(widget.orderId);
    if (apiOrder != null) {
      return _DetailOrderShell(
        child: _ManagerApiOrderDetail(
          order: apiOrder,
          canManage: sessionUser?.isManager == true,
          onChanged: () => setState(() {}),
        ),
      );
    }
    final order = ManagerOrdersMockData.orderById(widget.orderId);
    final canManage = sessionUser?.isManager == true;

    if (order == null) {
      return _DetailOrderShell(
        child: _CommercialsEmptyState(
          icon: Icons.search_off_rounded,
          title: AppLocalizations.globalText('Commande introuvable'),
          message: 'Impossible de retrouver cette commande.',
        ),
      );
    }

    if (sessionUser?.isCommercial == true &&
        sessionUser?.id != order.commercialId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home-commercial',
          (route) => false,
        );
      });
      return Scaffold(backgroundColor: _DashboardManagerState._surface);
    }

    return _DetailOrderShell(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(18, 14, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back_rounded),
                  color: _DashboardManagerState._textDark,
                  tooltip: 'Retour',
                ),
              ],
            ),
            SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.orderNumber,
                    style: TextStyle(
                      color: _DashboardManagerState._textDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                _OrderStatusBadge(status: order.status),
              ],
            ),
            SizedBox(height: 16),
            if (_isLoading)
              _CommercialsLoadingState()
            else if (_errorMessage != null)
              _CommercialsEmptyState(
                icon: Icons.error_outline_rounded,
                title: AppLocalizations.globalText('Erreur de données'),
                message: _errorMessage!,
              )
            else ...[
              _DetailInfoCard(order: order),
              SizedBox(height: 14),
              _DetailProductsCard(lines: order.lines),
              SizedBox(height: 14),
              if (canManage)
                _DetailActionsCard(
                  order: order,
                  onApprove: () => _approve(order),
                  onEdit: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ModifierCommandeScreen(order: order),
                      ),
                    );
                  },
                  onCancel: () => _confirmCancel(order),
                  onViewInvoice: () => _openTemporaryAction(
                    title: AppLocalizations.globalText('Facture'),
                    subtitle: 'Page temporaire : ${order.orderNumber}',
                    icon: Icons.picture_as_pdf_rounded,
                  ),
                  onViewReturn: () => _openTemporaryAction(
                    title: AppLocalizations.globalText('Voir retour'),
                    subtitle: 'Page temporaire : ${order.orderNumber}',
                    icon: Icons.assignment_return_rounded,
                  ),
                  onReturnHistory: () => _openTemporaryAction(
                    title: AppLocalizations.globalText('Historique retour'),
                    subtitle: 'Page temporaire : ${order.orderNumber}',
                    icon: Icons.history_rounded,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _approve(ManagerOrderItem order) {
    ManagerOrdersMockData.updateStatus(order.id, ManagerOrderStatus.validated);
    setState(() {});
    _showSuccess('Commande approuvée avec succès.');
  }

  Future<void> _confirmCancel(ManagerOrderItem order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.globalText('Annuler la commande ?')),
        content: Text('Confirmer l’annulation de ${order.orderNumber}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.globalText('Retour')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.globalText('Annuler la commande')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    ManagerOrdersMockData.updateStatus(order.id, ManagerOrderStatus.cancelled);
    setState(() {});
    _showSuccess('Commande annulée avec succès.');
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _DashboardManagerState._textDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  void _openTemporaryAction({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _TemporaryManagerPage(title: title, subtitle: subtitle, icon: icon),
      ),
    );
  }
}

class _ManagerApiOrderDetail extends StatefulWidget {
  const _ManagerApiOrderDetail({
    required this.order,
    required this.canManage,
    required this.onChanged,
  });

  final _ManagerOrderView order;
  final bool canManage;
  final VoidCallback onChanged;

  @override
  State<_ManagerApiOrderDetail> createState() => _ManagerApiOrderDetailState();
}

class _ManagerApiOrderDetailState extends State<_ManagerApiOrderDetail> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(18, 14, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(LucideIcons.arrowLeft),
            color: _DashboardManagerState.managerText,
            tooltip: 'Retour',
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  order.number,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: _DashboardManagerState.managerText,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _ManagerApiStatusBadge(status: order.status),
            ],
          ),
          SizedBox(height: 14),
          _ManagerDetailCard(
            children: [
              _ManagerDetailLine('Client', order.clientName),
              _ManagerDetailLine('Commercial', order.commercialName),
              _ManagerDetailLine('Téléphone', order.clientPhone.ifEmpty('-')),
              _ManagerDetailLine('Adresse', order.clientAddress.ifEmpty('-')),
              _ManagerDetailLine(
                'Date',
                '${order.dateLabel} • ${order.timeLabel}',
              ),
              _ManagerDetailLine(
                'Montant total',
                '${_formatNumber(order.total.round())} DH',
              ),
              _ManagerDetailLine(
                'Remise',
                order.discount == 0
                    ? '-'
                    : '${_formatNumber(order.discount.round())} DH',
              ),
              _ManagerDetailLine('Notes', order.notes.ifEmpty('-')),
            ],
          ),
          SizedBox(height: 14),
          _ManagerDetailCard(
            title: 'Produits commandés',
            children: order.lines.isEmpty
                ? [
                    Text(
                      'Aucune ligne de produit disponible.',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        color: _DashboardManagerState.managerMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ]
                : [
                    for (final line in order.lines)
                      Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                line.name,
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  color: _DashboardManagerState.managerText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${line.quantity.toStringAsFixed(line.quantity.truncateToDouble() == line.quantity ? 0 : 1)} x ${_formatNumber(line.unitPrice.round())} DH',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                color: _DashboardManagerState.managerMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
          ),
          SizedBox(height: 14),
          _ManagerDetailCard(
            title: 'Historique',
            children: [
              _ManagerDetailLine(
                'Créée',
                '${order.dateLabel} • ${order.timeLabel}',
              ),
              if (order.status == _ManagerOrderApiStatus.validated)
                _ManagerDetailLine('Validée', 'Par manager'),
              if (order.status == _ManagerOrderApiStatus.refused)
                _ManagerDetailLine('Refusée', 'Par manager'),
            ],
          ),
          if (widget.canManage &&
              order.status == _ManagerOrderApiStatus.pending) ...[
            SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : _refuse,
                    child: Text('Refuser'),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _validate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _DashboardManagerState.managerGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_saving ? 'Traitement...' : 'Valider'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _validate() async {
    await _updateStatus('validee');
  }

  Future<void> _refuse() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        String selected = 'Prix incorrect';
        final customController = TextEditingController();
        return AlertDialog(
          title: Text('Motif de refus'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              final reasons = [
                'Prix incorrect',
                'Stock indisponible',
                'Informations client incomplètes',
                'Doublon',
                'Autre',
              ];
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final reason in reasons)
                    ListTile(
                      onTap: () => setDialogState(() => selected = reason),
                      leading: Icon(
                        selected == reason
                            ? LucideIcons.checkCircle
                            : LucideIcons.circle,
                        color: selected == reason
                            ? _DashboardManagerState.managerBlue
                            : _DashboardManagerState.managerMuted,
                      ),
                      title: Text(reason),
                    ),
                  if (selected == 'Autre')
                    TextField(
                      controller: customController,
                      decoration: InputDecoration(labelText: 'Motif'),
                    ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  selected == 'Autre'
                      ? customController.text.trim().ifEmpty('Autre')
                      : selected,
                );
              },
              child: Text('Refuser'),
            ),
          ],
        );
      },
    );
    if (reason == null) return;
    await _updateStatus('refusee', reason: reason);
  }

  Future<void> _updateStatus(String status, {String? reason}) async {
    setState(() => _saving = true);
    try {
      await ApiService.updateFactureStatus(
        widget.order.id,
        status,
        refusalReason: reason,
        managerId: CurrentUserSession.currentUser?.id,
      );
      if (!mounted) return;
      widget.onChanged();
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Impossible de mettre à jour la commande.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }
}

class _ManagerDetailCard extends StatelessWidget {
  const _ManagerDetailCard({this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: _managerCardDecoration(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: TextStyle(
                fontFamily: 'Roboto',
                color: _DashboardManagerState.managerText,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 12),
          ],
          ...children,
        ],
      ),
    );
  }
}

class _ManagerDetailLine extends StatelessWidget {
  const _ManagerDetailLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Roboto',
                color: _DashboardManagerState.managerMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Roboto',
                color: _DashboardManagerState.managerText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailOrderShell extends StatelessWidget {
  _DetailOrderShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DashboardManagerState._surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 430),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF1C4B92).withValues(alpha: .08),
                    blurRadius: 28,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailInfoCard extends StatelessWidget {
  _DetailInfoCard({required this.order});

  final ManagerOrderItem order;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      child: Column(
        children: [
          _DetailInfoRow(
            label: AppLocalizations.globalText('Client'),
            value: order.clientName,
          ),
          _DetailInfoRow(
            label: AppLocalizations.globalText('Date'),
            value: order.dateLabel,
          ),
          _DetailInfoRow(
            label: AppLocalizations.globalText('Commercial'),
            value: order.commercialName,
          ),
          _DetailInfoRow(
            label: AppLocalizations.globalText('Montant total'),
            value: '${_formatNumber(order.total)} MAD',
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _DetailProductsCard extends StatelessWidget {
  _DetailProductsCard({required this.lines});

  final List<ManagerOrderLine> lines;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.globalText('Produits'),
            style: TextStyle(
              color: _DashboardManagerState._textDark,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 12),
          for (final line in lines)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      line.productName,
                      style: TextStyle(
                        color: _DashboardManagerState._textDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    'x${line.quantity}',
                    style: TextStyle(
                      color: _DashboardManagerState._textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(width: 20),
                  SizedBox(
                    width: 86,
                    child: Text(
                      '${_formatNumber(line.lineTotal)} MAD',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: _DashboardManagerState._textDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailActionsCard extends StatelessWidget {
  _DetailActionsCard({
    required this.order,
    required this.onApprove,
    required this.onEdit,
    required this.onCancel,
    required this.onViewInvoice,
    required this.onViewReturn,
    required this.onReturnHistory,
  });

  final ManagerOrderItem order;
  final VoidCallback onApprove;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onViewInvoice;
  final VoidCallback onViewReturn;
  final VoidCallback onReturnHistory;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.globalText('Actions'),
            style: TextStyle(
              color: _DashboardManagerState._textDark,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 18),
          _actionsForStatus(context),
        ],
      ),
    );
  }

  Widget _actionsForStatus(BuildContext context) {
    return switch (order.status) {
      ManagerOrderStatus.pending => Row(
        children: [
          Expanded(
            child: _ActionButton(
              label: AppLocalizations.globalText('Approuver'),
              color: _DashboardManagerState._success,
              filled: true,
              onTap: onApprove,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _ActionButton(
              label: AppLocalizations.globalText('Modifier'),
              color: _DashboardManagerState._primaryBlue,
              onTap: onEdit,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _ActionButton(
              label: AppLocalizations.globalText('Annuler'),
              color: Color(0xFFFF3B30),
              onTap: onCancel,
            ),
          ),
        ],
      ),
      ManagerOrderStatus.validated => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusMessage(
            icon: Icons.check_circle_outline_rounded,
            text: 'Commande validée',
            color: _DashboardManagerState._success,
          ),
          SizedBox(height: 14),
          Center(
            child: SizedBox(
              width: 150,
              child: _ActionButton(
                label: AppLocalizations.globalText('Voir facture'),
                color: _DashboardManagerState._primaryBlue,
                filled: true,
                onTap: onViewInvoice,
              ),
            ),
          ),
        ],
      ),
      ManagerOrderStatus.cancelled => _StatusMessage(
        icon: Icons.cancel_outlined,
        text: 'Commande annulée',
        color: Color(0xFFFF3B30),
      ),
      ManagerOrderStatus.returned => Row(
        children: [
          Expanded(
            child: _ActionButton(
              label: AppLocalizations.globalText('Voir retour'),
              color: Color(0xFF7B61FF),
              filled: true,
              onTap: onViewReturn,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _ActionButton(
              label: AppLocalizations.globalText('Historique retour'),
              color: _DashboardManagerState._primaryBlue,
              onTap: onReturnHistory,
            ),
          ),
        ],
      ),
      ManagerOrderStatus.all => SizedBox.shrink(),
    };
  }
}

class _StatusMessage extends StatelessWidget {
  _StatusMessage({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 9),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: filled ? color : Colors.white,
          foregroundColor: filled ? Colors.white : color,
          side: BorderSide(color: color),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          padding: EdgeInsets.zero,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class _DetailInfoRow extends StatelessWidget {
  _DetailInfoRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: _DashboardManagerState._textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: _DashboardManagerState._textDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: _DashboardManagerState._border),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  _DetailCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _DashboardManagerState._border),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF1C4B92).withValues(alpha: .045),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(padding: EdgeInsets.all(16), child: child),
    );
  }
}

class ModifierCommandeScreen extends StatelessWidget {
  ModifierCommandeScreen({super.key, required this.order});

  final ManagerOrderItem order;

  @override
  Widget build(BuildContext context) {
    return _TemporaryManagerPage(
      title: AppLocalizations.globalText('Modifier commande'),
      subtitle: 'Page temporaire : ${order.orderNumber}',
      icon: Icons.edit_note_rounded,
    );
  }
}

enum _ManagerNotificationFilter {
  all,
  unread,
  commandes,
  rapports,
  clients,
  activites,
  objectifs,
  utilisateurs,
  systeme,
}

extension _ManagerNotificationFilterLabel on _ManagerNotificationFilter {
  String get label {
    return switch (this) {
      _ManagerNotificationFilter.all => 'Toutes',
      _ManagerNotificationFilter.unread => 'Non lues',
      _ManagerNotificationFilter.commandes => 'Commandes',
      _ManagerNotificationFilter.rapports => 'Rapports',
      _ManagerNotificationFilter.clients => 'Clients',
      _ManagerNotificationFilter.activites => 'Activités',
      _ManagerNotificationFilter.objectifs => 'Objectifs',
      _ManagerNotificationFilter.utilisateurs => 'Utilisateurs',
      _ManagerNotificationFilter.systeme => 'Système',
    };
  }
}

class _ManagerNotificationItem {
  _ManagerNotificationItem({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.commercialId,
    this.managerId,
    this.commandeId,
    this.clientId,
  });

  final int id;
  final String title;
  final String description;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final int? commercialId;
  final int? managerId;
  final int? commandeId;
  final int? clientId;

  factory _ManagerNotificationItem.fromJson(Map<String, dynamic> json) {
    return _ManagerNotificationItem(
      id: _readInt(json, ['id']),
      title: _readString(json, ['titre', 'title']).ifEmpty('Notification'),
      description: _readString(json, [
        'description',
        'message',
        'body',
      ]).ifEmpty('-'),
      type: _normalizeManagerNotificationType(_readString(json, ['type'])),
      isRead: _readBool(json, ['is_read', 'read', 'lu']),
      createdAt:
          _readDate(json, ['created_at', 'date', 'sent_at']) ?? DateTime.now(),
      commercialId: _readNullableInt(json, ['commercial_id']),
      managerId: _readNullableInt(json, ['manager_id']),
      commandeId: _readNullableInt(json, ['commande_id', 'order_id']),
      clientId: _readNullableInt(json, ['client_id']),
    );
  }

  _ManagerNotificationItem copyWith({bool? isRead}) {
    return _ManagerNotificationItem(
      id: id,
      title: title,
      description: description,
      type: type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      commercialId: commercialId,
      managerId: managerId,
      commandeId: commandeId,
      clientId: clientId,
    );
  }
}

String _normalizeManagerNotificationType(String raw) {
  final value = raw.toLowerCase().trim();
  if (value.contains('commande') || value.contains('order')) return 'commandes';
  if (value.contains('rapport') || value.contains('report')) return 'rapports';
  if (value.contains('client') || value.contains('prospect')) return 'clients';
  if (value.contains('activ')) return 'activites';
  if (value.contains('objectif')) return 'objectifs';
  if (value.contains('user') ||
      value.contains('utilisateur') ||
      value.contains('commercial') ||
      value.contains('manager')) {
    return 'utilisateurs';
  }
  if (value.contains('system') ||
      value.contains('système') ||
      value.contains('maintenance') ||
      value.contains('erreur')) {
    return 'systeme';
  }
  return 'generales';
}

class NotificationsScreen extends StatefulWidget {
  NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  _ManagerNotificationFilter _filter = _ManagerNotificationFilter.all;
  bool _loading = true;
  String? _error;
  List<_ManagerNotificationItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  int? get _managerId => CurrentUserSession.currentUser?.id;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await ApiService.getNotifications(managerId: _managerId);
      final items =
          raw
              .whereType<Map>()
              .map(
                (item) => _ManagerNotificationItem.fromJson(
                  item.cast<String, dynamic>(),
                ),
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
      _managerUnreadNotifications.value = items
          .where((item) => !item.isRead)
          .length;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les notifications.';
        _loading = false;
      });
    }
  }

  List<_ManagerNotificationItem> get _visibleItems {
    return _items.where((item) {
      return switch (_filter) {
        _ManagerNotificationFilter.all => true,
        _ManagerNotificationFilter.unread => !item.isRead,
        _ManagerNotificationFilter.commandes => item.type == 'commandes',
        _ManagerNotificationFilter.rapports => item.type == 'rapports',
        _ManagerNotificationFilter.clients => item.type == 'clients',
        _ManagerNotificationFilter.activites => item.type == 'activites',
        _ManagerNotificationFilter.objectifs => item.type == 'objectifs',
        _ManagerNotificationFilter.utilisateurs => item.type == 'utilisateurs',
        _ManagerNotificationFilter.systeme => item.type == 'systeme',
      };
    }).toList();
  }

  Future<void> _openNotification(_ManagerNotificationItem item) async {
    if (!item.isRead) {
      await _markRead(item);
    }
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ManagerNotificationDetails(item: item),
    );
  }

  Future<void> _markRead(_ManagerNotificationItem item) async {
    setState(() {
      _items = [
        for (final current in _items)
          current.id == item.id ? current.copyWith(isRead: true) : current,
      ];
    });
    _managerUnreadNotifications.value = _items
        .where((item) => !item.isRead)
        .length;
    try {
      await ApiService.markNotificationRead(item.id);
    } catch (_) {
      await _load();
    }
  }

  Future<void> _markAllRead() async {
    setState(() {
      _items = [for (final item in _items) item.copyWith(isRead: true)];
    });
    _managerUnreadNotifications.value = 0;
    try {
      await ApiService.markAllNotificationsRead(managerId: _managerId);
    } catch (_) {
      await _load();
    }
  }

  Future<void> _deleteNotification(_ManagerNotificationItem item) async {
    final previous = _items;
    setState(
      () => _items = _items.where((current) => current.id != item.id).toList(),
    );
    _managerUnreadNotifications.value = _items
        .where((item) => !item.isRead)
        .length;
    try {
      await ApiService.deleteNotification(item.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _items = previous);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((item) => !item.isRead).length;
    final visibleItems = _visibleItems;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back_rounded),
                        color: Color(0xFF14204A),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Notifications',
                          style: TextStyle(
                            color: Color(0xFF14204A),
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: unread == 0 ? null : _markAllRead,
                        child: Text('Tout lu'),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 46,
                  child: ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: _ManagerNotificationFilter.values.length,
                    separatorBuilder: (context, index) => SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = _ManagerNotificationFilter.values[index];
                      final selected = filter == _filter;
                      return ChoiceChip(
                        selected: selected,
                        label: Text(filter.label),
                        onSelected: (_) => setState(() => _filter = filter),
                        selectedColor: Color(0xFF2563EB),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Color(0xFF6F7A90),
                          fontWeight: FontWeight.w800,
                        ),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: Color(0xFFE2E8F0)),
                      );
                    },
                  ),
                ),
                SizedBox(height: 12),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: _loading
                        ? ListView(
                            children: [
                              SizedBox(height: 220),
                              Center(child: CircularProgressIndicator()),
                            ],
                          )
                        : _error != null
                        ? ListView(
                            padding: EdgeInsets.all(20),
                            children: [
                              _ManagerNotificationEmpty(text: _error!),
                            ],
                          )
                        : visibleItems.isEmpty
                        ? ListView(
                            padding: EdgeInsets.all(20),
                            children: [
                              _ManagerNotificationEmpty(
                                text: 'Aucune notification disponible.',
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
                            itemBuilder: (context, index) {
                              final item = visibleItems[index];
                              return _ManagerNotificationTile(
                                item: item,
                                onTap: () => _openNotification(item),
                                onDelete: () => _deleteNotification(item),
                              );
                            },
                            separatorBuilder: (context, index) =>
                                SizedBox(height: 10),
                            itemCount: visibleItems.length,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ManagerNotificationTile extends StatelessWidget {
  const _ManagerNotificationTile({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  final _ManagerNotificationItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final style = _managerNotificationStyle(item.type);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Row(
            children: [
              SizedBox(
                width: 10,
                child: item.isRead
                    ? SizedBox.shrink()
                    : Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                      ),
              ),
              SizedBox(width: 10),
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(style.icon, color: style.color),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF14204A),
                              fontWeight: item.isRead
                                  ? FontWeight.w700
                                  : FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Text(
                          _managerNotificationTime(item.createdAt),
                          style: TextStyle(
                            color: Color(0xFF6F7A90),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 5),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF6F7A90),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded),
                color: Color(0xFFEF4444),
                tooltip: 'Supprimer',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagerNotificationDetails extends StatelessWidget {
  const _ManagerNotificationDetails({required this.item});

  final _ManagerNotificationItem item;

  @override
  Widget build(BuildContext context) {
    final style = _managerNotificationStyle(item.type);
    return Container(
      padding: EdgeInsets.fromLTRB(22, 22, 22, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(style.icon, color: style.color, size: 30),
            ),
            SizedBox(height: 16),
            Text(
              item.title,
              style: TextStyle(
                color: Color(0xFF14204A),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              item.description,
              style: TextStyle(
                color: Color(0xFF6F7A90),
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16),
            Text(
              '${_managerNotificationTypeLabel(item.type)} • ${_managerNotificationTime(item.createdAt)}',
              style: TextStyle(color: style.color, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagerNotificationEmpty extends StatelessWidget {
  const _ManagerNotificationEmpty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 52,
            color: Color(0xFF2563EB),
          ),
          SizedBox(height: 14),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF6F7A90),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

({IconData icon, Color color}) _managerNotificationStyle(String type) {
  return switch (type) {
    'commandes' => (icon: LucideIcons.receipt, color: Color(0xFFF59E0B)),
    'rapports' => (icon: LucideIcons.fileText, color: Color(0xFF7C3AED)),
    'clients' => (icon: LucideIcons.users, color: Color(0xFF22C55E)),
    'activites' => (icon: LucideIcons.calendarClock, color: Color(0xFF2563EB)),
    'objectifs' => (icon: LucideIcons.target, color: Color(0xFF0EA5E9)),
    'utilisateurs' => (icon: LucideIcons.userCog, color: Color(0xFF64748B)),
    'systeme' => (icon: LucideIcons.settings, color: Color(0xFFEF4444)),
    _ => (icon: LucideIcons.bell, color: Color(0xFF2563EB)),
  };
}

String _managerNotificationTypeLabel(String type) {
  return switch (type) {
    'commandes' => 'Commandes',
    'rapports' => 'Rapports',
    'clients' => 'Clients',
    'activites' => 'Activités',
    'objectifs' => 'Objectifs',
    'utilisateurs' => 'Utilisateurs',
    'systeme' => 'Système',
    _ => 'Général',
  };
}

String _managerNotificationTime(DateTime date) {
  final now = DateTime.now();
  if (DateUtils.isSameDay(date, now)) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class RevenueDetailsScreen extends StatelessWidget {
  RevenueDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _TemporaryManagerPage(
      title: AppLocalizations.globalText("Chiffre d'affaires"),
      subtitle: AppLocalizations.globalText('Page temporaire'),
      icon: Icons.trending_up_rounded,
    );
  }
}

class OrdersStatusDetailsScreen extends StatelessWidget {
  OrdersStatusDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _TemporaryManagerPage(
      title: AppLocalizations.globalText('Commandes par statut'),
      subtitle: AppLocalizations.globalText('Page temporaire'),
      icon: Icons.donut_large_rounded,
    );
  }
}

class DashboardAdmin extends StatelessWidget {
  DashboardAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    return _TemporaryManagerPage(
      title: AppLocalizations.globalText('Dashboard Admin'),
      subtitle: AppLocalizations.globalText('Espace administrateur temporaire'),
      icon: Icons.admin_panel_settings_rounded,
    );
  }
}

class _TemporaryManagerPage extends StatelessWidget {
  _TemporaryManagerPage({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DashboardManagerState._surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _DashboardManagerState._textDark,
        elevation: 0,
        title: Text(title),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _DashboardManagerState._primaryBlue.withValues(
                    alpha: .10,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon,
                  color: _DashboardManagerState._primaryBlue,
                  size: 36,
                ),
              ),
              SizedBox(height: 18),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _DashboardManagerState._textDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCardData {
  _StatCardData({
    required this.title,
    required this.value,
    required this.evolution,
  });

  final String title;
  final String value;
  final int evolution;
}

class _MiniSummaryData {
  _MiniSummaryData({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.evolution,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final int? evolution;
}

class _OrderStatData {
  _OrderStatData({
    required this.title,
    required this.value,
    required this.evolution,
    required this.icon,
    required this.color,
  });

  final String title;
  final int value;
  final int evolution;
  final IconData icon;
  final Color color;
}

class _CommercialsSummary {
  _CommercialsSummary({
    required this.activeCommercials,
    required this.totalRevenue,
    required this.totalOrders,
    required this.totalVisits,
  });

  factory _CommercialsSummary.from(List<CommercialSales> commercials) {
    return _CommercialsSummary(
      activeCommercials: commercials.where((item) => item.isActive).length,
      totalRevenue: commercials.fold<int>(
        0,
        (total, item) => total + item.sales,
      ),
      totalOrders: commercials.fold<int>(
        0,
        (total, item) => total + item.ordersCount,
      ),
      totalVisits: commercials.fold<int>(
        0,
        (total, item) => total + item.visitsCount,
      ),
    );
  }

  final int activeCommercials;
  final int totalRevenue;
  final int totalOrders;
  final int totalVisits;
}

OutlineInputBorder _managerInputBorder({
  Color color = _DashboardManagerState._border,
}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color),
  );
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

_OrderStatusStyle _orderStatusStyle(ManagerOrderStatus status) {
  return switch (status) {
    ManagerOrderStatus.validated => _OrderStatusStyle(
      label: AppLocalizations.globalText('Validée'),
      icon: Icons.check_circle_outline_rounded,
      fg: Color(0xFF12B76A),
      bg: Color(0xFFE7F8EF),
    ),
    ManagerOrderStatus.pending => _OrderStatusStyle(
      label: AppLocalizations.globalText('En attente'),
      icon: Icons.schedule_rounded,
      fg: Color(0xFFFF8A00),
      bg: Color(0xFFFFF1DF),
    ),
    ManagerOrderStatus.cancelled => _OrderStatusStyle(
      label: AppLocalizations.globalText('Annulée'),
      icon: Icons.cancel_outlined,
      fg: Color(0xFFFF3B30),
      bg: Color(0xFFFFE9E8),
    ),
    ManagerOrderStatus.returned => _OrderStatusStyle(
      label: AppLocalizations.globalText('Retour'),
      icon: Icons.keyboard_return_rounded,
      fg: Color(0xFF2674F8),
      bg: Color(0xFFE8EEFF),
    ),
    ManagerOrderStatus.all => _OrderStatusStyle(
      label: AppLocalizations.globalText('Toutes'),
      icon: Icons.shopping_cart_rounded,
      fg: Color(0xFF2674F8),
      bg: Color(0xFFE8EEFF),
    ),
  };
}

String _singleStatusLabel(ManagerOrderStatus status) {
  return _orderStatusStyle(status).label;
}

class _OrderStatusStyle {
  _OrderStatusStyle({
    required this.label,
    required this.icon,
    required this.fg,
    required this.bg,
  });

  final String label;
  final IconData icon;
  final Color fg;
  final Color bg;
}

String _formatNumber(num value) {
  final text = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final indexFromEnd = text.length - i;
    buffer.write(text[i]);
    if (indexFromEnd > 1 && indexFromEnd % 3 == 1) buffer.write(' ');
  }
  return buffer.toString();
}

String _formatCompact(int value) {
  if (value >= 1000000) {
    final millions = value / 1000000;
    return '${millions.toStringAsFixed(millions >= 10 ? 0 : 1)}M';
  }
  if (value >= 1000) return '${(value / 1000).round()}k';
  return value.toString();
}
