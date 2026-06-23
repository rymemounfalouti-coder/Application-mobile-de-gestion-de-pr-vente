import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/current_user_session.dart';
import '../../data/mock_presales_data.dart';
import '../../l10n/app_localizations.dart';
import '../../services/commercial_objectives_service.dart';
import '../../services/pricing_service.dart';
import 'profile_screen.dart';

final Map<String, List<CommercialOrder>> _runtimeCommercialOrdersByEmail = {};

List<CommercialOrder> _runtimeOrdersForEmail(String email) {
  return _runtimeCommercialOrdersByEmail[email.toLowerCase().trim()] ??
      const [];
}

void _addRuntimeOrderForEmail(String email, CommercialOrder order) {
  final key = email.toLowerCase().trim();
  final orders = _runtimeCommercialOrdersByEmail.putIfAbsent(key, () => []);
  orders.removeWhere((item) => item.orderNumber == order.orderNumber);
  orders.insert(0, order);
}

final Map<String, List<CommercialClient>> _runtimeCommercialClientsByEmail = {};

List<CommercialClient> _runtimeClientsForEmail(String email) {
  return _runtimeCommercialClientsByEmail[email.toLowerCase().trim()] ??
      const [];
}

void _addRuntimeClientForEmail(String email, CommercialClient client) {
  final key = email.toLowerCase().trim();
  final clients = _runtimeCommercialClientsByEmail.putIfAbsent(key, () => []);
  clients.removeWhere((item) => item.id == client.id);
  clients.insert(0, client);
}

class _CommercialRanking {
  _CommercialRanking({
    required this.rank,
    required this.totalCommercials,
    required this.hasActivity,
  });

  final int rank;
  final int totalCommercials;
  final bool hasActivity;
}

class _CommercialRankingScore {
  _CommercialRankingScore({
    required this.commercialId,
    required this.revenue,
    required this.validatedOrders,
  });

  final int commercialId;
  final double revenue;
  final int validatedOrders;
}

_CommercialRanking _commercialRankingFor(int commercialId) {
  final commercials = MockPreSalesData.commercialUsers(includeInactive: true);
  final scores = <_CommercialRankingScore>[];

  for (final commercial in commercials) {
    final orders = [
      ...MockPreSalesData.ordersForUser(commercial),
      ..._runtimeOrdersForEmail(commercial.email),
    ];
    final validatedOrders = orders
        .where((order) => _isValidatedStatus(order.status))
        .toList();
    scores.add(
      _CommercialRankingScore(
        commercialId: commercial.id,
        revenue: validatedOrders.fold<double>(
          0,
          (total, order) => total + order.total,
        ),
        validatedOrders: validatedOrders.length,
      ),
    );
  }

  final hasActivity = scores.any(
    (score) => score.revenue > 0 || score.validatedOrders > 0,
  );
  if (!hasActivity) {
    return _CommercialRanking(
      rank: 0,
      totalCommercials: commercials.length,
      hasActivity: false,
    );
  }

  scores.sort((left, right) {
    final revenueCompare = right.revenue.compareTo(left.revenue);
    if (revenueCompare != 0) return revenueCompare;
    return right.validatedOrders.compareTo(left.validatedOrders);
  });
  final index = scores.indexWhere(
    (score) => score.commercialId == commercialId,
  );
  return _CommercialRanking(
    rank: index < 0 ? scores.length : index + 1,
    totalCommercials: scores.length,
    hasActivity: true,
  );
}

class HomeCommercial extends StatefulWidget {
  HomeCommercial({super.key});

  @override
  State<HomeCommercial> createState() => _HomeCommercialState();
}

class _HomeCommercialState extends State<HomeCommercial> {
  int _selectedIndex = 0;
  bool _initialIndexApplied = false;
  final List<CommercialClient> _addedClients = [];
  final List<_CommercialActivityItem> _addedActivities = [];
  int? _objectiveCommercialId;
  CommercialObjective? _commercialObjective;

  static const primaryBlue = Color(0xFF2674F8);
  static Color textDark = const Color(0xFF14204A);
  static Color textMuted = const Color(0xFF6F7A90);
  static Color surface = const Color(0xFFF8FAFC);
  static Color cardBg = Colors.white;
  static const success = Color(0xFF20C47B);
  static const error = Color(0xFFEF4444);

  static void syncTheme(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    textDark = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF14204A);
    textMuted = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF6F7A90);
    surface = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    cardBg = isDark ? const Color(0xFF111827) : Colors.white;
  }

  void _loadObjectiveIfNeeded(int commercialId) {
    if (commercialId <= 0 || _objectiveCommercialId == commercialId) return;
    _objectiveCommercialId = commercialId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final objective = await CommercialObjectivesService.instance.getObjective(
        commercialId,
      );
      if (!mounted || _objectiveCommercialId != commercialId) return;
      setState(() => _commercialObjective = objective);
    });
  }

  void _redirectAfterBuild(BuildContext context, String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
    });
  }

  @override
  Widget build(BuildContext context) {
    syncTheme(context);
    final args = ModalRoute.of(context)?.settings.arguments;
    final routeEmail = args is Map ? args['email']?.toString() ?? '' : '';
    final fallbackName = args is Map ? args['name']?.toString() ?? '' : '';
    final sessionUser = CurrentUserSession.currentUser;
    final user = sessionUser?.isCommercial == true
        ? MockPreSalesData.userByEmail(sessionUser!.email)
        : MockPreSalesData.userByEmail(routeEmail);

    if (sessionUser == null && user == null) {
      _redirectAfterBuild(context, '/login');
      return Scaffold(backgroundColor: surface);
    }
    if (sessionUser?.isManager == true || user?.role == MockUserRole.manager) {
      _redirectAfterBuild(context, '/home-manager');
      return Scaffold(backgroundColor: surface);
    }

    final email = user?.email ?? sessionUser?.email ?? routeEmail;
    final commercialId = user?.id ?? sessionUser?.id ?? 0;
    _loadObjectiveIfNeeded(commercialId);
    final dashboard = MockPreSalesData.dashboardForUser(user);
    final clients = [
      ...MockPreSalesData.clientsForUser(user),
      ..._addedClients,
    ];
    final tourVisits = MockPreSalesData.tourVisitsForUser(user);
    final orders = [
      ...MockPreSalesData.ordersForUser(user),
      ..._runtimeOrdersForEmail(email),
    ];
    final userName = user?.name ?? sessionUser?.fullName ?? fallbackName;
    if (!_initialIndexApplied && args is Map) {
      final initialIndex = args['initialIndex'];
      if (initialIndex is int && initialIndex >= 0 && initialIndex <= 4) {
        _selectedIndex = initialIndex;
      }
      _initialIndexApplied = true;
    }

    return Scaffold(
      backgroundColor: surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final phoneWidth = constraints.maxWidth > 390
                ? 390.0
                : constraints.maxWidth;

            return Center(
              child: SizedBox(
                width: phoneWidth,
                height: constraints.maxHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF18315E).withValues(alpha: .08),
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Column(
                      children: [
                        Expanded(
                          child: IndexedStack(
                            index: _selectedIndex,
                            children: [
                              _DashboardTab(
                                userName: userName,
                                summary:
                                    dashboard?.summary ??
                                    CommercialDashboardData.empty().summary,
                                objective: _commercialObjective,
                                ranking: _commercialRankingFor(commercialId),
                                activities: dashboard?.activities ?? [],
                                orders: orders,
                                visits: tourVisits,
                                clients: clients,
                                createdActivities: _addedActivities,
                                currentEmail: email,
                                unreadNotificationCount:
                                    _commercialUnreadNotificationCount(),
                                onClientAdded: (client) {
                                  setState(() => _addedClients.add(client));
                                  _addRuntimeClientForEmail(email, client);
                                  _notifyClientAdded(email, client);
                                },
                                onActivityCreated: (activity) {
                                  setState(
                                    () => _addedActivities.insert(0, activity),
                                  );
                                  _notifyActivityPlanned(email, activity);
                                },
                                onNavigate: (index) {
                                  setState(() => _selectedIndex = index);
                                },
                              ),
                              ClientsCommercial(
                                clients: clients,
                                currentEmail: email,
                                currentUserName: userName,
                                unreadNotificationCount:
                                    _commercialUnreadNotificationCount(),
                                onClientAdded: (client) {
                                  setState(() => _addedClients.add(client));
                                  _addRuntimeClientForEmail(email, client);
                                  _notifyClientAdded(email, client);
                                },
                              ),
                              if (_selectedIndex == -3)
                                _TemporaryTab(
                                  title: AppLocalizations.globalText(
                                    'Commandes',
                                  ),
                                  subtitle: AppLocalizations.globalText(
                                    'Commandes réelles à connecter bientôt.',
                                  ),
                                  icon: Icons.receipt_long_rounded,
                                ),
                              OrdersCommercial(
                                orders: orders,
                                clients: clients,
                                currentEmail: email,
                                currentUserName: userName,
                                unreadNotificationCount:
                                    _commercialUnreadNotificationCount(),
                                onNavigate: (index) {
                                  setState(() => _selectedIndex = index);
                                },
                              ),
                              if (tourVisits.isEmpty && _selectedIndex == -1)
                                _TemporaryTab(
                                  title: AppLocalizations.globalText(
                                    'Activit\u00E9s',
                                  ),
                                  subtitle: AppLocalizations.globalText(
                                    'Planning, visites et géolocalisation à venir.',
                                  ),
                                  icon: Icons.event_available_rounded,
                                ),
                              ActivitiesCommercial(
                                visits: tourVisits,
                                clients: clients,
                                currentEmail: email,
                                currentUserName: userName,
                                unreadNotificationCount:
                                    _commercialUnreadNotificationCount(),
                              ),
                              ProfileCommercialScreen(
                                user: user,
                                fallbackName: userName,
                                fallbackEmail: email,
                                unreadNotificationCount:
                                    _commercialUnreadNotificationCount(),
                                onNotificationsTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          CommercialNotificationsPage(),
                                    ),
                                  );
                                },
                                onNavigate: (index) {
                                  setState(() => _selectedIndex = index);
                                },
                              ),
                            ],
                          ),
                        ),
                        _CommercialBottomNav(
                          selectedIndex: _selectedIndex,
                          onChanged: (index) {
                            setState(() => _selectedIndex = index);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ClientsCommercial extends StatefulWidget {
  ClientsCommercial({
    super.key,
    required this.clients,
    required this.currentEmail,
    required this.currentUserName,
    required this.unreadNotificationCount,
    required this.onClientAdded,
  });

  final List<CommercialClient> clients;
  final String currentEmail;
  final String currentUserName;
  final int unreadNotificationCount;
  final ValueChanged<CommercialClient> onClientAdded;

  @override
  State<ClientsCommercial> createState() => _ClientsCommercialState();
}

class _ClientsCommercialState extends State<ClientsCommercial> {
  final _searchController = TextEditingController();
  String? _selectedCategory;
  String _query = '';
  int _clientRevision = _clientDataRevision.value;

  static final _categoryTabs = <String?>[
    null,
    'Supermarchés & Grandes Surfaces',
    'Grossistes',
    'Épiceries',
    'Cafés & Restaurants',
  ];

  @override
  void initState() {
    super.initState();
    _clientDataRevision.addListener(_handleClientRevision);
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _clientDataRevision.removeListener(_handleClientRevision);
    _searchController.dispose();
    super.dispose();
  }

  void _handleClientRevision() {
    if (!mounted) return;
    setState(() => _clientRevision = _clientDataRevision.value);
  }

  List<CommercialClient> get _effectiveClients {
    // Depend on _clientRevision so Flutter recomputes counts after external changes.
    final _ = _clientRevision;
    return [
      for (final client in widget.clients) _withConvertedOrderStatus(client),
    ];
  }

  List<_ClientViewData> get _clients {
    final effectiveClients = _effectiveClients;
    final views = [
      for (var i = 0; i < effectiveClients.length; i++)
        _ClientViewData.fromClient(effectiveClients[i], index: i),
    ];
    return views.where((client) {
      final matchesSearch =
          _query.isEmpty ||
          client.name.toLowerCase().contains(_query) ||
          client.type.toLowerCase().contains(_query) ||
          client.client.clientCode.toLowerCase().contains(_query) ||
          client.client.contactName.toLowerCase().contains(_query) ||
          client.client.city.toLowerCase().contains(_query);
      final matchesCategory =
          _selectedCategory == null || client.type == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  int _countForCategory(String? category) {
    final effectiveClients = _effectiveClients;
    if (category == null) return effectiveClients.length;
    return effectiveClients
        .where((client) => client.businessType == category)
        .length;
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CommercialNotificationsPage()),
    );
  }

  void _openClientDetails(CommercialClient client) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailClient(
          client: client,
          currentEmail: widget.currentEmail,
          currentUserName: widget.currentUserName,
        ),
        settings: RouteSettings(arguments: {'id': client.id}),
      ),
    );
  }

  Future<void> _openAddClient() async {
    final client = await Navigator.push<CommercialClient>(
      context,
      MaterialPageRoute(
        builder: (_) => NouveauClientScreen(
          currentEmail: widget.currentEmail,
          currentUserName: widget.currentUserName,
          existingClients: _effectiveClients,
        ),
      ),
    );
    if (client == null) return;
    widget.onClientAdded(client);
    _clientDataRevision.value++;
  }

  void _openFilterSheet() {
    _showMobileOrderSheet<void>(
      context: context,
      child: _ClientFilterSheet(
        selectedCategory: _selectedCategory,
        categories: _categoryTabs,
        onSelected: (category) {
          setState(() => _selectedCategory = category);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clients = _clients;
    final effectiveClients = _effectiveClients;
    return Stack(
      children: [
        CustomScrollView(
          physics: BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 22, 20, 88),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _ClientsPremiumHeader(
                    onNotificationTap: _openNotifications,
                    unreadNotificationCount: widget.unreadNotificationCount,
                  ),
                  SizedBox(height: 24),
                  _ClientsSearchAndFilter(
                    controller: _searchController,
                    onFilterTap: _openFilterSheet,
                    activeFilterLabel: _clientFilterButtonLabel(
                      _selectedCategory,
                    ),
                  ),
                  SizedBox(height: 18),
                  _ClientKpiGrid(clients: effectiveClients),
                  SizedBox(height: 22),
                  _ClientTabs(
                    selectedCategory: _selectedCategory,
                    categories: _categoryTabs,
                    countFor: _countForCategory,
                    onChanged: (category) =>
                        setState(() => _selectedCategory = category),
                  ),
                  SizedBox(height: 18),
                  if (clients.isEmpty)
                    _EmptyClients()
                  else
                    for (final client in clients) ...[
                      _ClientCard(
                        data: client,
                        onTap: () => _openClientDetails(client.client),
                      ),
                      SizedBox(height: 12),
                    ],
                ]),
              ),
            ),
          ],
        ),
        Positioned(
          right: 22,
          bottom: 20,
          child: FloatingActionButton(
            heroTag: 'commercial-clients-fab',
            onPressed: _openAddClient,
            backgroundColor: _DashboardTab._blue,
            foregroundColor: Colors.white,
            elevation: 12,
            child: Icon(Icons.add_rounded, size: 34),
          ),
        ),
      ],
    );
  }
}

enum _ClientUiStatus { active, inactive, prospect }

extension _ClientUiStatusText on _ClientUiStatus {
  String get label {
    return switch (this) {
      _ClientUiStatus.active => AppLocalizations.globalText('Actif'),
      _ClientUiStatus.inactive => AppLocalizations.globalText('Inactif'),
      _ClientUiStatus.prospect => AppLocalizations.globalText('Prospect'),
    };
  }

  Color get color {
    return switch (this) {
      _ClientUiStatus.active => _DashboardTab._green,
      _ClientUiStatus.inactive => _HomeCommercialState.error,
      _ClientUiStatus.prospect => _DashboardTab._orange,
    };
  }
}

class _ClientViewData {
  _ClientViewData({
    required this.client,
    required this.name,
    required this.type,
    required this.uiStatus,
    required this.orderCount,
    required this.revenue,
    required this.lastActivityRank,
    required this.logoIcon,
    required this.logoColor,
    this.logoText,
  });

  final CommercialClient client;
  final String name;
  final String type;
  final _ClientUiStatus uiStatus;
  final int orderCount;
  final double revenue;
  final int lastActivityRank;
  final IconData logoIcon;
  final Color logoColor;
  final String? logoText;

  factory _ClientViewData.fromClient(CommercialClient client, {int index = 0}) {
    final effectiveClient = _withConvertedOrderStatus(client);
    final preset =
        _createdClientPresets[effectiveClient.id] ??
        _clientPreset(effectiveClient.name, index);
    final calculatedRevenue = effectiveClient.orders.fold<double>(
      0,
      (total, order) => total + order.amount,
    );
    return _ClientViewData(
      client: effectiveClient,
      name: preset.name ?? effectiveClient.name,
      type: effectiveClient.businessType,
      uiStatus: _clientUiStatusFromStatus(effectiveClient.status),
      orderCount: preset.orders ?? effectiveClient.orders.length,
      revenue: preset.revenue ?? calculatedRevenue,
      lastActivityRank: preset.rank,
      logoIcon: preset.icon,
      logoColor: preset.color,
      logoText: preset.logoText,
    );
  }
}

_ClientUiStatus _clientUiStatusFromStatus(ClientStatus status) {
  return switch (status) {
    ClientStatus.visited => _ClientUiStatus.active,
    ClientStatus.inactive => _ClientUiStatus.inactive,
    ClientStatus.toVisit => _ClientUiStatus.prospect,
  };
}

String _clientFilterButtonLabel(String? category) {
  return category == null ? 'Filtre : Tous' : 'Filtre : $category';
}

String _clientFilterOptionLabel(String? category) {
  return category ?? 'Tous';
}

class _ClientPreset {
  _ClientPreset({
    this.name,
    required this.type,
    required this.status,
    this.orders,
    this.revenue,
    required this.rank,
    required this.icon,
    required this.color,
    this.logoText,
  });

  final String? name;
  final String type;
  final _ClientUiStatus status;
  final int? orders;
  final double? revenue;
  final int rank;
  final IconData icon;
  final Color color;
  final String? logoText;
}

final Map<int, _ClientPreset> _createdClientPresets = {};

List<CommercialClient> get _fallbackCommercialClients =>
    MockPreSalesData.clientsForEmail('ahmed@presales.ma');

final Set<int> _convertedOrderClientIds = <int>{};
final ValueNotifier<int> _clientDataRevision = ValueNotifier<int>(0);

CommercialClient _withConvertedOrderStatus(CommercialClient client) {
  if (!_convertedOrderClientIds.contains(client.id)) return client;
  return client.copyWith(status: ClientStatus.visited);
}

_ClientPreset _clientPreset(String rawName, int index) {
  final name = rawName.toLowerCase();
  if (name.contains('bim')) {
    return _ClientPreset(
      name: 'Bim',
      type: 'Supermarch\u00E9',
      status: _ClientUiStatus.active,
      orders: 10,
      revenue: 28750,
      rank: 4,
      icon: Icons.shopping_bag_rounded,
      color: Color(0xFF0B63CE),
      logoText: 'bim',
    );
  }
  if (name.contains('atacadao')) {
    return _ClientPreset(
      name: 'Atacadao',
      type: 'Cash & Carry',
      status: _ClientUiStatus.active,
      orders: 8,
      revenue: 32000,
      rank: 5,
      icon: Icons.local_mall_rounded,
      color: Color(0xFFE11D48),
      logoText: 'A',
    );
  }
  return _ClientPreset(
    type: 'Commerce de proximit\u00E9',
    status: index % 5 == 0 ? _ClientUiStatus.inactive : _ClientUiStatus.active,
    orders: null,
    revenue: null,
    rank: index,
    icon: Icons.storefront_rounded,
    color: _DashboardTab._blue,
  );
}

class OrdersCommercial extends StatefulWidget {
  OrdersCommercial({
    super.key,
    required this.orders,
    required this.clients,
    required this.currentEmail,
    required this.currentUserName,
    required this.unreadNotificationCount,
    required this.onNavigate,
  });

  final List<CommercialOrder> orders;
  final List<CommercialClient> clients;
  final String currentEmail;
  final String currentUserName;
  final int unreadNotificationCount;
  final ValueChanged<int> onNavigate;

  @override
  State<OrdersCommercial> createState() => _OrdersCommercialState();
}

class _OrdersCommercialState extends State<OrdersCommercial> {
  final _searchController = TextEditingController();
  _OrderQuickFilter _selectedFilter = _OrderQuickFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CommercialOrder> get _filteredOrders {
    return widget.orders.where((order) {
      final matchesSearch =
          _query.isEmpty ||
          order.orderNumber.toLowerCase().contains(_query) ||
          order.clientName.toLowerCase().contains(_query) ||
          order.items.any(
            (item) => item.productName.toLowerCase().contains(_query),
          );
      return matchesSearch && _matchesQuickFilter(order);
    }).toList();
  }

  bool _matchesQuickFilter(CommercialOrder order) {
    return switch (_selectedFilter) {
      _OrderQuickFilter.all => true,
      _OrderQuickFilter.pending => order.status == OrderStatus.pending,
      _OrderQuickFilter.validated => _isValidatedStatus(order.status),
      _OrderQuickFilter.rejected => order.status == OrderStatus.cancelled,
      _OrderQuickFilter.today => _isToday(order.date),
      _OrderQuickFilter.week => _isThisWeek(order.date),
    };
  }

  int get _pendingCount => widget.orders
      .where((order) => order.status == OrderStatus.pending)
      .length;
  int get _validatedCount =>
      widget.orders.where((order) => _isValidatedStatus(order.status)).length;
  int get _rejectedCount => widget.orders
      .where((order) => order.status == OrderStatus.cancelled)
      .length;

  void _openFilterSheet() {
    _showMobileOrderSheet<void>(
      context: context,
      child: _OrderFilterSheet(
        selectedFilter: _selectedFilter,
        filters: _OrderQuickFilter.values,
        onSelected: (filter) {
          setState(() => _selectedFilter = filter);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CommercialNotificationsPage()),
    );
  }

  void _createOrder() {
    if (widget.clients.isEmpty) {
      widget.onNavigate(1);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NouvelleCommandeClientSelection(
          clients: widget.clients,
          currentEmail: widget.currentEmail,
          currentUserName: widget.currentUserName,
        ),
      ),
    );
  }

  void _openOrder(CommercialOrder order) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailCommande(order: order)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = _filteredOrders;

    return Stack(
      children: [
        CustomScrollView(
          physics: BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 124),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _OrdersHeader(
                    onNotificationsTap: _openNotifications,
                    unreadNotificationCount: widget.unreadNotificationCount,
                  ),
                  SizedBox(height: 24),
                  _OrdersKpiSummary(
                    totalOrders: widget.orders.length,
                    pendingOrders: _pendingCount,
                    validatedOrders: _validatedCount,
                    rejectedOrders: _rejectedCount,
                  ),
                  SizedBox(height: 18),
                  _OrdersSearchBar(
                    controller: _searchController,
                    onFilterTap: _openFilterSheet,
                  ),
                  SizedBox(height: 18),
                  _OrderQuickFilters(
                    selectedFilter: _selectedFilter,
                    onChanged: (filter) {
                      setState(() => _selectedFilter = filter);
                    },
                  ),
                  SizedBox(height: 18),
                  if (widget.orders.isEmpty)
                    _EmptyOrdersState(onCreate: _createOrder)
                  else if (orders.isEmpty)
                    _EmptyDetailMessage(text: 'Aucune commande trouv\u00E9e')
                  else
                    for (final order in orders) ...[
                      _OrderCard(order: order, onTap: () => _openOrder(order)),
                      SizedBox(height: 12),
                    ],
                ]),
              ),
            ),
          ],
        ),
        Positioned(
          right: 22,
          bottom: 22,
          child: FloatingActionButton(
            heroTag: 'commercial-orders-fab',
            onPressed: _createOrder,
            backgroundColor: _HomeCommercialState.primaryBlue,
            foregroundColor: Colors.white,
            elevation: 10,
            child: Icon(Icons.add_rounded, size: 34),
          ),
        ),
      ],
    );
  }
}

class _OrderFilterSheet extends StatelessWidget {
  _OrderFilterSheet({
    required this.selectedFilter,
    required this.filters,
    required this.onSelected,
  });

  final _OrderQuickFilter selectedFilter;
  final Iterable<_OrderQuickFilter> filters;
  final ValueChanged<_OrderQuickFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0F172A).withValues(alpha: .16),
            blurRadius: 28,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.globalText('Filtres commandes'),
                style: TextStyle(
                  color: _DashboardTab._navy,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                AppLocalizations.globalText(
                  'Affichez uniquement les commandes correspondant au filtre sélectionné.',
                ),
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 16),
              for (final filter in filters)
                InkWell(
                  onTap: () => onSelected(filter),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selectedFilter == filter
                                  ? _DashboardTab._blue
                                  : Color(0xFFCBD5E1),
                              width: 2,
                            ),
                          ),
                          child: selectedFilter == filter
                              ? Center(
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _DashboardTab._blue,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _orderQuickFilterLabel(filter),
                            softWrap: true,
                            style: TextStyle(
                              color: _DashboardTab._navy,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
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

class _OrdersHeader extends StatelessWidget {
  _OrdersHeader({
    required this.onNotificationsTap,
    required this.unreadNotificationCount,
  });

  final VoidCallback onNotificationsTap;
  final int unreadNotificationCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.globalText('Commandes'),
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                AppLocalizations.globalText(
                  'Suivez et g\u00E9rez vos commandes',
                ),
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        _CommercialNotificationButton(
          onTap: onNotificationsTap,
          unreadCount: unreadNotificationCount,
        ),
      ],
    );
  }
}

class _OrdersSearchBar extends StatelessWidget {
  _OrdersSearchBar({required this.controller, required this.onFilterTap});

  final TextEditingController controller;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: AppLocalizations.globalText('Rechercher une commande'),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: Color(0xFF64748B),
                size: 27,
              ),
              filled: true,
              fillColor: _HomeCommercialState.cardBg,
              contentPadding: EdgeInsets.symmetric(vertical: 16),
              enabledBorder: _searchBorder(),
              focusedBorder: _searchBorder(
                color: _HomeCommercialState.primaryBlue,
              ),
            ),
          ),
        ),
        SizedBox(width: 10),
        SizedBox(
          width: 56,
          height: 56,
          child: OutlinedButton(
            onPressed: onFilterTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: Color(0xFF475569),
              backgroundColor: _HomeCommercialState.cardBg,
              side: BorderSide(color: Color(0xFFE3E8F2)),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: Icon(Icons.filter_alt_outlined, size: 25),
          ),
        ),
      ],
    );
  }
}

class _OrdersKpiSummary extends StatelessWidget {
  _OrdersKpiSummary({
    required this.totalOrders,
    required this.pendingOrders,
    required this.validatedOrders,
    required this.rejectedOrders,
  });

  final int totalOrders;
  final int pendingOrders;
  final int validatedOrders;
  final int rejectedOrders;

  @override
  Widget build(BuildContext context) {
    final items = [
      _OrderKpiData(
        title: AppLocalizations.globalText('Total'),
        value: totalOrders,
        icon: Icons.shopping_bag_outlined,
        color: Color(0xFF2563EB),
      ),
      _OrderKpiData(
        title: AppLocalizations.globalText('En attente'),
        value: pendingOrders,
        icon: Icons.schedule_rounded,
        color: Color(0xFFF59E0B),
      ),
      _OrderKpiData(
        title: AppLocalizations.globalText('Valid\u00E9es'),
        value: validatedOrders,
        icon: Icons.assignment_turned_in_outlined,
        color: Color(0xFF22C55E),
      ),
      _OrderKpiData(
        title: AppLocalizations.globalText('Refus\u00E9es'),
        value: rejectedOrders,
        icon: Icons.cancel_outlined,
        color: Color(0xFFEF4444),
      ),
    ];

    return Container(
      constraints: BoxConstraints(minHeight: 106),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFFE8EEF7)),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0F172A).withValues(alpha: .055),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Expanded(child: _OrderKpiMini(data: items[i])),
            if (i != items.length - 1)
              Container(width: 1, height: 72, color: Color(0xFFE8EEF7)),
          ],
        ],
      ),
    );
  }
}

class _OrderKpiData {
  _OrderKpiData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final int value;
  final IconData icon;
  final Color color;
}

class _OrderKpiMini extends StatelessWidget {
  _OrderKpiMini({required this.data});

  final _OrderKpiData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(data.icon, color: data.color, size: 21),
          ),
          SizedBox(height: 8),
          SizedBox(
            height: 17,
            width: double.infinity,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  data.title,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '${data.value}',
            style: TextStyle(
              color: data.color,
              fontSize: 27,
              height: .95,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderQuickFilters extends StatelessWidget {
  _OrderQuickFilters({required this.selectedFilter, required this.onChanged});

  final _OrderQuickFilter selectedFilter;
  final ValueChanged<_OrderQuickFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: BouncingScrollPhysics(),
        itemCount: _OrderQuickFilter.values.length,
        separatorBuilder: (context, index) => SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _OrderQuickFilter.values[index];
          final selected = selectedFilter == filter;
          return InkWell(
            onTap: () => onChanged(filter),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(horizontal: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Color(0xFF2563EB) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? Color(0xFF2563EB) : Color(0xFFE8EEF7),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF0F172A).withValues(alpha: .055),
                    blurRadius: 14,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: Text(
                _orderQuickFilterLabel(filter),
                style: TextStyle(
                  color: selected ? Colors.white : Color(0xFF475569),
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  _OrderCard({required this.order, required this.onTap});

  final CommercialOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = _orderStatusColor(order.status);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: EdgeInsets.fromLTRB(14, 14, 12, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Color(0xFFE8EEF7)),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF0F172A).withValues(alpha: .045),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Color(0xFF2563EB).withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xFF2563EB),
                  size: 23,
                ),
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
                            order.orderNumber,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        _OrderStatusBadge(status: order.status),
                      ],
                    ),
                    SizedBox(height: 7),
                    Text(
                      order.clientName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 13,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 9),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: Color(0xFF64748B).withValues(alpha: .85),
                        ),
                        SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            _formatCommercialOrderDate(order.date),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '${_money(order.total)} DH',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: statusColor, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderStatusBadge extends StatelessWidget {
  _OrderStatusBadge({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _orderStatusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _commercialOrderStatusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyOrdersState extends StatelessWidget {
  _EmptyOrdersState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 30, 24, 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0F172A).withValues(alpha: .06),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              color: Color(0xFF2563EB).withValues(alpha: .08),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFF2563EB),
              size: 54,
            ),
          ),
          SizedBox(height: 20),
          Text(
            AppLocalizations.globalText('Aucune commande disponible'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: onCreate,
            icon: Icon(Icons.add_rounded),
            label: Text(AppLocalizations.globalText('Cr\u00E9er une commande')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DetailCommande extends StatelessWidget {
  DetailCommande({super.key, required this.order});

  final CommercialOrder order;

  static const _surface = Color(0xFFF8FAFC);
  static const _primary = Color(0xFF2563EB);
  static const _text = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _line = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final user = CurrentUserSession.currentUser;
    final commercialName = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName
        : 'Commercial';
    final lines = _detailLines(order);
    final subtotal = lines.fold<double>(0, (total, line) => total + line.total);
    final total = subtotal;

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final phoneWidth = constraints.maxWidth > 428
                ? 428.0
                : constraints.maxWidth;
            return Center(
              child: SizedBox(
                width: phoneWidth,
                height: constraints.maxHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF18315E).withValues(alpha: .08),
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Column(
                      children: [
                        Expanded(
                          child: CustomScrollView(
                            physics: BouncingScrollPhysics(),
                            slivers: [
                              SliverPadding(
                                padding: EdgeInsets.fromLTRB(18, 18, 18, 22),
                                sliver: SliverList(
                                  delegate: SliverChildListDelegate([
                                    _OrderDetailHeader(
                                      onBack: () => Navigator.pop(context),
                                      onPdf: () => _showAction(
                                        context,
                                        'Bon de commande PDF en pr\u00e9paration.',
                                      ),
                                      onShare: () => _showAction(
                                        context,
                                        'Partage du bon de commande en pr\u00e9paration.',
                                      ),
                                      onMenu: () => _showActionsMenu(context),
                                    ),
                                    SizedBox(height: 18),
                                    _DetailOrderInfoCard(
                                      order: order,
                                      commercialName: commercialName,
                                    ),
                                    SizedBox(height: 16),
                                    _OrderedProductsCard(lines: lines),
                                    SizedBox(height: 16),
                                    _OrderSummaryCard(
                                      subtotal: subtotal,
                                      total: total,
                                    ),
                                    SizedBox(height: 16),
                                    _OrderHistoryCard(
                                      order: order,
                                      commercialName: commercialName,
                                    ),
                                    SizedBox(height: 16),
                                    _OrderActionsCard(
                                      canCancel:
                                          order.status == OrderStatus.pending,
                                      onPdf: () => _showAction(
                                        context,
                                        'Bon de commande PDF en pr\u00e9paration.',
                                      ),
                                      onDuplicate: () =>
                                          _duplicateOrder(context),
                                      onCancel:
                                          order.status == OrderStatus.pending
                                          ? () => _showAction(
                                              context,
                                              'Demande d\u2019annulation envoy\u00e9e.',
                                            )
                                          : null,
                                    ),
                                  ]),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _CommercialBottomNav(
                          selectedIndex: 2,
                          onChanged: (index) =>
                              _navigateFromDetail(context, index),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _navigateFromDetail(BuildContext context, int index) {
    if (index == 2) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home-commercial',
      (route) => false,
      arguments: {'initialIndex': index},
    );
  }

  void _duplicateOrder(BuildContext context) {
    final user = CurrentUserSession.currentUser;
    final clients = MockPreSalesData.clientsForEmail(user?.email ?? '');
    CommercialClient? selectedClient;
    for (final client in clients) {
      if (client.name.toLowerCase() == order.clientName.toLowerCase()) {
        selectedClient = client;
        break;
      }
    }
    if (selectedClient == null) {
      _showAction(context, 'Client introuvable pour dupliquer cette commande.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NouvelleCommande(
          client: selectedClient!,
          currentEmail: user?.email ?? '',
          currentUserName: user?.fullName ?? '',
        ),
        settings: RouteSettings(arguments: {'sourceOrderId': order.id}),
      ),
    );
  }

  void _showActionsMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _HomeCommercialState.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _OrderMenuTile(
                  icon: Icons.picture_as_pdf_outlined,
                  label: AppLocalizations.globalText(
                    'T\u00e9l\u00e9charger PDF',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showAction(
                      context,
                      'Bon de commande PDF en pr\u00e9paration.',
                    );
                  },
                ),
                _OrderMenuTile(
                  icon: Icons.copy_rounded,
                  label: AppLocalizations.globalText('Dupliquer commande'),
                  onTap: () {
                    Navigator.pop(context);
                    _duplicateOrder(context);
                  },
                ),
                _OrderMenuTile(
                  icon: Icons.info_outline_rounded,
                  label: AppLocalizations.globalText('Informations statut'),
                  onTap: () {
                    Navigator.pop(context);
                    _showAction(
                      context,
                      _commercialOrderStatusLabel(order.status),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAction(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _OrderDetailHeader extends StatelessWidget {
  _OrderDetailHeader({
    required this.onBack,
    required this.onPdf,
    required this.onShare,
    required this.onMenu,
  });
  final VoidCallback onBack;
  final VoidCallback onPdf;
  final VoidCallback onShare;
  final VoidCallback onMenu;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HeaderIconButton(icon: Icons.arrow_back_rounded, onTap: onBack),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            AppLocalizations.globalText('D\u00e9tail commande'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: DetailCommande._text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        _HeaderIconButton(icon: Icons.picture_as_pdf_outlined, onTap: onPdf),
        SizedBox(width: 8),
        _HeaderIconButton(icon: Icons.share_outlined, onTap: onShare),
        SizedBox(width: 8),
        _HeaderIconButton(icon: Icons.more_horiz_rounded, onTap: onMenu),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  _HeaderIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 38,
    height: 38,
    child: IconButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      icon: Icon(icon, color: DetailCommande._text, size: 25),
    ),
  );
}

class _DetailOrderInfoCard extends StatelessWidget {
  _DetailOrderInfoCard({required this.order, required this.commercialName});
  final CommercialOrder order;
  final String commercialName;
  @override
  Widget build(BuildContext context) {
    return _OrderDetailShellCard(
      padding: EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: DetailCommande._primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.assignment_outlined,
                  color: DetailCommande._primary,
                  size: 32,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  order.orderNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: DetailCommande._text,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _OrderStatusBadge(status: order.status),
            ],
          ),
          SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _OrderInfoBlock(
                  label: AppLocalizations.globalText('Client'),
                  value: order.clientName,
                  icon: Icons.storefront_rounded,
                ),
              ),
              _VerticalDivider(),
              Expanded(
                child: _OrderInfoBlock(
                  label: AppLocalizations.globalText('Date'),
                  value: _formatCommercialOrderDate(order.date),
                  icon: Icons.calendar_today_outlined,
                ),
              ),
              _VerticalDivider(),
              Expanded(
                child: _OrderInfoBlock(
                  label: AppLocalizations.globalText('Commercial'),
                  value: commercialName,
                  icon: Icons.person_outline_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderInfoBlock extends StatelessWidget {
  _OrderInfoBlock({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 15, color: DetailCommande._muted),
          SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: DetailCommande._muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      SizedBox(height: 8),
      Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: DetailCommande._text,
          fontSize: 13,
          height: 1.25,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _VerticalDivider extends StatelessWidget {
  _VerticalDivider();
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 50,
    margin: EdgeInsets.symmetric(horizontal: 10),
    color: DetailCommande._line,
  );
}

class _OrderedProductsCard extends StatelessWidget {
  _OrderedProductsCard({required this.lines});
  final List<_OrderDetailLine> lines;
  @override
  Widget build(BuildContext context) {
    return _OrderDetailShellCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.globalText('Produits command\u00e9s'),
                    style: TextStyle(
                      color: DetailCommande._text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                  decoration: BoxDecoration(
                    color: DetailCommande._primary.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${lines.length} ${lines.length <= 1 ? 'article' : 'articles'}',
                    style: TextStyle(
                      color: DetailCommande._primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: DetailCommande._line),
          for (var i = 0; i < lines.length; i++) ...[
            _ProductLineTile(line: lines[i]),
            if (i != lines.length - 1)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: Divider(height: 1, color: DetailCommande._line),
              ),
          ],
        ],
      ),
    );
  }
}

class _ProductLineTile extends StatelessWidget {
  _ProductLineTile({required this.line});
  final _OrderDetailLine line;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: DetailCommande._line),
            ),
            child: Icon(line.icon, color: line.color, size: 28),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: DetailCommande._text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'R\u00e9f : ${line.reference}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: DetailCommande._muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Tarif : ${line.tariffLabel} • Remise : -${(line.discountRate * 100).toStringAsFixed(0)}%',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: DetailCommande._muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Column(
            children: [
              Container(
                width: 50,
                padding: EdgeInsets.symmetric(vertical: 7),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: DetailCommande._primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${line.quantity}',
                  style: TextStyle(
                    color: DetailCommande._primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'x ${_dh(line.unitPrice)}',
                style: TextStyle(
                  color: DetailCommande._muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 58,
            child: Text(
              _dh(line.total),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: DetailCommande._text,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  _OrderSummaryCard({required this.subtotal, required this.total});
  final double subtotal;
  final double total;
  @override
  Widget build(BuildContext context) => _OrderDetailShellCard(
    padding: EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.globalText('R\u00e9sum\u00e9 de la commande'),
          style: TextStyle(
            color: DetailCommande._text,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 18),
        _SummaryLine(
          label: AppLocalizations.globalText('Sous-total'),
          value: _dh(subtotal),
        ),
        SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.only(top: 4, bottom: 16),
          child: Divider(height: 1, color: DetailCommande._line),
        ),
        _SummaryLine(
          label: AppLocalizations.globalText('Total'),
          value: _dh(total),
          total: true,
        ),
      ],
    ),
  );
}

class _SummaryLine extends StatelessWidget {
  _SummaryLine({required this.label, required this.value, this.total = false});
  final String label;
  final String value;
  final bool total;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            color: DetailCommande._text,
            fontSize: total ? 17 : 15,
            fontWeight: total ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
      Text(
        value,
        style: TextStyle(
          color: total ? DetailCommande._primary : DetailCommande._text,
          fontSize: total ? 21 : 15,
          fontWeight: total ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    ],
  );
}

class _OrderHistoryCard extends StatelessWidget {
  _OrderHistoryCard({required this.order, required this.commercialName});
  final CommercialOrder order;
  final String commercialName;
  @override
  Widget build(BuildContext context) {
    final items = _historyItems(order, commercialName);
    return _OrderDetailShellCard(
      padding: EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.globalText('Historique de la commande'),
            style: TextStyle(
              color: DetailCommande._text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 18),
          for (var i = 0; i < items.length; i++)
            _TimelineItem(data: items[i], isLast: i == items.length - 1),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  _TimelineItem({required this.data, required this.isLast});
  final _OrderHistoryItem data;
  final bool isLast;
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: data.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: data.color.withValues(alpha: .24),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(data.icon, color: Colors.white, size: 19),
            ),
            if (!isLast)
              Expanded(
                child: Container(
                  width: 2,
                  margin: EdgeInsets.symmetric(vertical: 3),
                  color: DetailCommande._line,
                ),
              ),
          ],
        ),
        SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.title,
                        style: TextStyle(
                          color: DetailCommande._text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Par ${data.actor}',
                        style: TextStyle(
                          color: DetailCommande._muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (data.reason != null) ...[
                        SizedBox(height: 7),
                        Text(
                          data.reason!,
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  data.date,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: DetailCommande._muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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

class _OrderActionsCard extends StatelessWidget {
  _OrderActionsCard({
    required this.canCancel,
    required this.onPdf,
    required this.onDuplicate,
    required this.onCancel,
  });
  final bool canCancel;
  final VoidCallback onPdf;
  final VoidCallback onDuplicate;
  final VoidCallback? onCancel;
  @override
  Widget build(BuildContext context) => _OrderDetailShellCard(
    padding: EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.globalText('Actions'),
          style: TextStyle(
            color: DetailCommande._text,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _ActionPill(
              icon: Icons.picture_as_pdf_outlined,
              label: AppLocalizations.globalText('T\u00e9l\u00e9charger PDF'),
              color: DetailCommande._primary,
              onTap: onPdf,
            ),
            _ActionPill(
              icon: Icons.copy_rounded,
              label: AppLocalizations.globalText('Dupliquer commande'),
              color: DetailCommande._primary,
              onTap: onDuplicate,
            ),
            _ActionPill(
              icon: Icons.delete_outline_rounded,
              label: AppLocalizations.globalText('Annuler commande'),
              color: Color(0xFFDC2626),
              onTap: onCancel,
            ),
          ],
        ),
      ],
    ),
  );
}

class _ActionPill extends StatelessWidget {
  _ActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: enabled ? color : DetailCommande._muted,
        backgroundColor: enabled ? Colors.white : Color(0xFFF1F5F9),
        side: BorderSide(
          color: enabled ? color.withValues(alpha: .22) : DetailCommande._line,
        ),
        padding: EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _OrderMenuTile extends StatelessWidget {
  _OrderMenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: DetailCommande._primary),
    title: Text(label, style: TextStyle(fontWeight: FontWeight.w700)),
    onTap: onTap,
  );
}

class _OrderDetailShellCard extends StatelessWidget {
  _OrderDetailShellCard({required this.child, required this.padding});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Color(0xFFE8EEF7)),
      boxShadow: [
        BoxShadow(
          color: Color(0xFF0F172A).withValues(alpha: .055),
          blurRadius: 20,
          offset: Offset(0, 9),
        ),
      ],
    ),
    child: child,
  );
}

class _OrderDetailLine {
  _OrderDetailLine({
    required this.name,
    required this.reference,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.icon,
    required this.color,
    this.tariffLabel = 'Standard',
    this.discountRate = 0,
  });
  final String name;
  final String reference;
  final int quantity;
  final double unitPrice;
  final double total;
  final IconData icon;
  final Color color;
  final String tariffLabel;
  final double discountRate;
}

class _OrderHistoryItem {
  _OrderHistoryItem({
    required this.title,
    required this.actor,
    required this.date,
    required this.icon,
    required this.color,
    this.reason,
  });
  final String title;
  final String actor;
  final String date;
  final IconData icon;
  final Color color;
  final String? reason;
}

List<_OrderDetailLine> _detailLines(CommercialOrder order) {
  return order.items.map((item) {
    final product = _findProductForLine(item);
    final unitPrice = item.quantity == 0 ? 0.0 : item.total / item.quantity;
    return _OrderDetailLine(
      name: item.productName,
      reference: product?.reference ?? 'Ligne ${order.items.indexOf(item) + 1}',
      quantity: item.quantity,
      unitPrice: unitPrice,
      total: item.total,
      icon: product?.icon ?? Icons.inventory_2_outlined,
      color: product?.imageColor ?? DetailCommande._primary,
      tariffLabel: 'Historique',
      discountRate: 0,
    );
  }).toList();
}

OrderProduct? _findProductForLine(OrderLine line) {
  final source = _normalizeProductName(line.productName);
  for (final product in MockPreSalesData.orderProducts) {
    final candidate = _normalizeProductName(product.name);
    if (candidate == source ||
        source.contains(candidate) ||
        candidate.contains(source)) {
      return product;
    }
  }
  return null;
}

String _normalizeProductName(String value) => value
    .toLowerCase()
    .replaceAll('é', 'e')
    .replaceAll('é', 'e')
    .replaceAll('è', 'e')
    .replaceAll('ê', 'e')
    .replaceAll('à', 'a')
    .replaceAll('ô', 'o')
    .replaceAll(' ', '')
    .replaceAll("'", '');

List<_OrderHistoryItem> _historyItems(
  CommercialOrder order,
  String commercialName,
) {
  final date = order.date;
  final items = <_OrderHistoryItem>[
    _OrderHistoryItem(
      title: AppLocalizations.globalText('Commande cr\u00e9\u00e9e'),
      actor: commercialName,
      date: date,
      icon: Icons.add_rounded,
      color: Color(0xFF22C55E),
    ),
    _OrderHistoryItem(
      title: AppLocalizations.globalText('Envoy\u00e9e au manager'),
      actor: commercialName,
      date: date,
      icon: Icons.send_rounded,
      color: DetailCommande._primary,
    ),
  ];
  if (order.status == OrderStatus.pending) {
    items.add(
      _OrderHistoryItem(
        title: AppLocalizations.globalText('En attente de validation'),
        actor: 'Manager',
        date: date,
        icon: Icons.schedule_rounded,
        color: Color(0xFFF59E0B),
      ),
    );
  } else if (_isValidatedStatus(order.status)) {
    items.add(
      _OrderHistoryItem(
        title: AppLocalizations.globalText('Commande valid\u00e9e'),
        actor: 'Manager',
        date: date,
        icon: Icons.check_rounded,
        color: Color(0xFF16A34A),
      ),
    );
  } else if (order.status == OrderStatus.cancelled) {
    items.add(
      _OrderHistoryItem(
        title: AppLocalizations.globalText('Commande refus\u00e9e'),
        actor: 'Manager',
        date: date,
        icon: Icons.close_rounded,
        color: Color(0xFFDC2626),
        reason: 'Motif : commande refus\u00e9e par le manager.',
      ),
    );
  }
  return items;
}

enum _OrderQuickFilter { all, pending, validated, rejected, today, week }

String _orderQuickFilterLabel(_OrderQuickFilter filter) {
  return switch (filter) {
    _OrderQuickFilter.all => AppLocalizations.globalText('Toutes'),
    _OrderQuickFilter.pending => AppLocalizations.globalText('En attente'),
    _OrderQuickFilter.validated => AppLocalizations.globalText('Validées'),
    _OrderQuickFilter.rejected => AppLocalizations.globalText('Refusées'),
    _OrderQuickFilter.today => "Aujourd'hui",
    _OrderQuickFilter.week => AppLocalizations.globalText('Cette semaine'),
  };
}

bool _isValidatedStatus(OrderStatus status) {
  return status == OrderStatus.synced || status == OrderStatus.delivered;
}

String _commercialOrderStatusLabel(OrderStatus status) {
  return switch (status) {
    OrderStatus.pending => AppLocalizations.globalText('En attente'),
    OrderStatus.synced => AppLocalizations.globalText('Validée'),
    OrderStatus.delivered => AppLocalizations.globalText('Validée'),
    OrderStatus.cancelled => AppLocalizations.globalText('Refusée'),
  };
}

DateTime? _parseOrderDate(String value) {
  final parts = value.split('/');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

bool _isToday(String value) {
  final date = _parseOrderDate(value);
  if (date == null) return false;
  final now = DateTime.now();
  return date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
}

bool _isThisWeek(String value) {
  final date = _parseOrderDate(value);
  if (date == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final weekEnd = weekStart.add(Duration(days: 7));
  return !date.isBefore(weekStart) && date.isBefore(weekEnd);
}

String _formatCommercialOrderDate(String value) {
  final date = _parseOrderDate(value);
  if (date == null) return value;
  final months = [
    'janvier',
    'f\u00E9vrier',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'ao\u00FBt',
    'septembre',
    'octobre',
    'novembre',
    'd\u00E9cembre',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

Color _orderStatusColor(OrderStatus status) {
  return switch (status) {
    OrderStatus.pending => Color(0xFFFF8A1F),
    OrderStatus.synced => Color(0xFF16A34A),
    OrderStatus.delivered => _HomeCommercialState.success,
    OrderStatus.cancelled => Color(0xFFFF3B30),
  };
}

IconData _orderStatusIcon(OrderStatus status) {
  return switch (status) {
    OrderStatus.pending => Icons.schedule_rounded,
    OrderStatus.synced => Icons.sync_rounded,
    OrderStatus.delivered => Icons.check_rounded,
    OrderStatus.cancelled => Icons.close_rounded,
  };
}

class ProfileCommercial extends StatelessWidget {
  ProfileCommercial({
    super.key,
    required this.user,
    required this.fallbackName,
    required this.fallbackEmail,
    required this.onNavigate,
  });

  final MockUserProfile? user;
  final String fallbackName;
  final String fallbackEmail;
  final ValueChanged<int> onNavigate;

  String get _name {
    final value = user?.name ?? fallbackName;
    return value.trim().isEmpty ? 'Commercial PreSales' : value;
  }

  String get _email {
    final value = user?.email ?? fallbackEmail;
    return value.trim().isEmpty ? 'commercial@presales.ma' : value;
  }

  String get _phone => user?.phone ?? 'Non renseigné';

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 18),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _ProfileHeader(),
              SizedBox(height: 24),
              _ProfileUserCard(
                name: _name,
                email: _email,
                phone: _phone,
                role: 'Commercial',
              ),
              SizedBox(height: 18),
              _ProfileMenuCard(
                items: [
                  _ProfileMenuItemData(
                    icon: Icons.person_outline_rounded,
                    title: AppLocalizations.globalText('Mon compte'),
                    subtitle: AppLocalizations.globalText(
                      'Informations personnelles',
                    ),
                    onTap: () => _openTemporary(context, 'Mon compte'),
                  ),
                  _ProfileMenuItemData(
                    icon: Icons.work_outline_rounded,
                    title: AppLocalizations.globalText('Mon activité'),
                    subtitle: AppLocalizations.globalText(
                      'Résumé de votre activité',
                    ),
                    onTap: () => _openTemporary(context, 'Mon activité'),
                  ),
                  _ProfileMenuItemData(
                    icon: Icons.track_changes_rounded,
                    title: AppLocalizations.globalText('Objectifs'),
                    subtitle: AppLocalizations.globalText(
                      'Suivi de vos objectifs',
                    ),
                    onTap: () => _openTemporary(context, 'Objectifs'),
                  ),
                  _ProfileMenuItemData(
                    icon: Icons.settings_outlined,
                    title: AppLocalizations.globalText('Paramètres'),
                    subtitle: AppLocalizations.globalText(
                      "Préférences de l'application",
                    ),
                    onTap: () => _openTemporary(context, 'Paramètres'),
                  ),
                  _ProfileMenuItemData(
                    icon: Icons.help_outline_rounded,
                    title: AppLocalizations.globalText('Aide et support'),
                    subtitle: AppLocalizations.globalText('FAQ et assistance'),
                    onTap: () => _openTemporary(context, 'Aide et support'),
                  ),
                  _ProfileMenuItemData(
                    icon: Icons.shield_outlined,
                    title: AppLocalizations.globalText('Sécurité'),
                    subtitle: AppLocalizations.globalText(
                      'Mot de passe et sécurité',
                    ),
                    onTap: () => _openTemporary(context, 'Sécurité'),
                  ),
                  _ProfileMenuItemData(
                    icon: Icons.logout_rounded,
                    title: AppLocalizations.globalText('Déconnexion'),
                    subtitle: AppLocalizations.globalText(
                      "Se déconnecter de l'application",
                    ),
                    color: Color(0xFFFF3B30),
                    onTap: () => _confirmLogout(context),
                  ),
                ],
              ),
              SizedBox(height: 18),
              _AboutPreSalesCard(
                onTap: () => _openTemporary(context, 'À propos de PreSales'),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  void _openTemporary(BuildContext context, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _ProfileTemporaryPage(title: title)),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.globalText('Déconnexion')),
          content: Text(
            AppLocalizations.globalText(
              'Voulez-vous vraiment vous déconnecter ?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.globalText('Non')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppLocalizations.globalText('Oui')),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true && context.mounted) {
      CurrentUserSession.signOut();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.globalText('Profil'),
                style: TextStyle(
                  color: _HomeCommercialState.textDark,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                AppLocalizations.globalText(
                  'Gérez votre compte et vos préférences',
                ),
                style: TextStyle(
                  color: _HomeCommercialState.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        _CommercialNotificationButton(
          onTap: null,
          unreadCount: _commercialUnreadNotificationCount(),
        ),
      ],
    );
  }
}

class _CommercialNotificationButton extends StatelessWidget {
  _CommercialNotificationButton({
    required this.onTap,
    required this.unreadCount,
  });

  final VoidCallback? onTap;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _commercialNotificationRevision,
      builder: (context, _, child) {
        final count = _commercialUnreadNotificationCount();
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: onTap,
                icon: Icon(Icons.notifications_none_rounded),
                color: _HomeCommercialState.textDark,
              ),
            ),
            if (count > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  constraints: BoxConstraints(minWidth: 12),
                  height: 12,
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ProfileUserCard extends StatelessWidget {
  _ProfileUserCard({
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
  });

  final String name;
  final String email;
  final String phone;
  final String role;

  @override
  Widget build(BuildContext context) {
    return _ProfileCard(
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: _HomeCommercialState.primaryBlue,
                child: Text(
                  _initials(name),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Positioned(
                right: 2,
                bottom: 6,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: _HomeCommercialState.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _HomeCommercialState.textDark,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  role,
                  style: TextStyle(
                    color: _HomeCommercialState.primaryBlue,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _HomeCommercialState.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  phone,
                  style: TextStyle(
                    color: _HomeCommercialState.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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

class _ProfileMenuCard extends StatelessWidget {
  _ProfileMenuCard({required this.items});

  final List<_ProfileMenuItemData> items;

  @override
  Widget build(BuildContext context) {
    return _ProfileCard(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            _ProfileMenuRow(item: items[i], isLast: i == items.length - 1),
        ],
      ),
    );
  }
}

class _ProfileMenuRow extends StatelessWidget {
  _ProfileMenuRow({required this.item, required this.isLast});

  final _ProfileMenuItemData item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = item.color ?? Color(0xFF123F8C);
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          border: Border(
            bottom: isLast
                ? BorderSide.none
                : BorderSide(color: Color(0xFFE8EDF5)),
          ),
        ),
        child: Row(
          children: [
            Icon(item.icon, color: color, size: 28),
            SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: _HomeCommercialState.textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      color: _HomeCommercialState.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: _HomeCommercialState.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutPreSalesCard extends StatelessWidget {
  _AboutPreSalesCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ProfileCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.globalText('À propos de PreSales'),
              style: TextStyle(
                color: _HomeCommercialState.textDark,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: _HomeCommercialState.primaryBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.bar_chart_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.globalText('PreSales'),
                        style: TextStyle(
                          color: _HomeCommercialState.textDark,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        AppLocalizations.globalText('Version 1.0.0'),
                        style: TextStyle(
                          color: _HomeCommercialState.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: _HomeCommercialState.textMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  _ProfileCard({required this.child, this.padding = const EdgeInsets.all(22)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF18315E).withValues(alpha: .07),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ProfileMenuItemData {
  _ProfileMenuItemData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? color;
}

class _ProfileTemporaryPage extends StatelessWidget {
  _ProfileTemporaryPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _HomeCommercialState.surface,
      appBar: AppBar(
        backgroundColor: _HomeCommercialState.cardBg,
        foregroundColor: _HomeCommercialState.textDark,
        elevation: 0,
        title: Text(title),
      ),
      body: Center(
        child: Text(
          title,
          style: TextStyle(
            color: _HomeCommercialState.textDark,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return 'PS';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

class ActivitiesCommercial extends StatefulWidget {
  ActivitiesCommercial({
    super.key,
    required this.visits,
    required this.clients,
    required this.currentEmail,
    required this.currentUserName,
    required this.unreadNotificationCount,
  });

  final List<TourVisit> visits;
  final List<CommercialClient> clients;
  final String currentEmail;
  final String currentUserName;
  final int unreadNotificationCount;

  @override
  State<ActivitiesCommercial> createState() => _ActivitiesCommercialState();
}

class _ActivitiesCommercialState extends State<ActivitiesCommercial> {
  int? _selectedVisitId;

  TourVisit? get _selectedVisit {
    for (final visit in widget.visits) {
      if (visit.id == _selectedVisitId) return visit;
    }
    return widget.visits.isEmpty ? null : widget.visits.first;
  }

  void _openClient(TourVisit visit) {
    final client = _clientForVisit(visit);
    if (client == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.globalText('Client introuvable')),
          ),
        );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailClient(
          client: client,
          currentEmail: widget.currentEmail,
          currentUserName: widget.currentUserName,
        ),
        settings: RouteSettings(arguments: {'id': client.id}),
      ),
    );
  }

  CommercialClient? _clientForVisit(TourVisit visit) {
    for (final client in widget.clients) {
      if (client.id == visit.clientId) return client;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PremiumActivitiesPage(
      visits: widget.visits,
      clients: widget.clients,
      currentEmail: widget.currentEmail,
      currentUserName: widget.currentUserName,
      unreadNotificationCount: widget.unreadNotificationCount,
    );

    // ignore: dead_code
    final visits = widget.visits;

    if (visits.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.globalText('Aucune activité prévue'),
          style: TextStyle(
            color: _HomeCommercialState.textMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return CustomScrollView(
      physics: BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 18),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _TourMapCard(
                visits: visits,
                selectedVisit: _selectedVisit,
                onVisitSelected: (visit) {
                  setState(() => _selectedVisitId = visit.id);
                },
              ),
              SizedBox(height: 0),
              _TourVisitsCard(
                visits: visits,
                selectedVisitId: _selectedVisitId,
                onVisitTap: _openClient,
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

enum _CommercialActivityStatus { todo, inProgress, done, late }

enum _ActivityFilter { all, todo, inProgress, done }

extension _ActivityFilterText on _ActivityFilter {
  String get label {
    return switch (this) {
      _ActivityFilter.all => AppLocalizations.globalText('Toutes'),
      _ActivityFilter.todo => AppLocalizations.globalText('À faire'),
      _ActivityFilter.inProgress => AppLocalizations.globalText('En cours'),
      _ActivityFilter.done => AppLocalizations.globalText('Terminées'),
    };
  }

  bool matches(_CommercialActivityStatus status) {
    return switch (this) {
      _ActivityFilter.all => true,
      _ActivityFilter.todo => status == _CommercialActivityStatus.todo,
      _ActivityFilter.inProgress =>
        status == _CommercialActivityStatus.inProgress,
      _ActivityFilter.done => status == _CommercialActivityStatus.done,
    };
  }
}

class _CommercialActivityItem {
  _CommercialActivityItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.location,
    required this.time,
    required this.date,
    required this.status,
    required this.icon,
    required this.color,
    this.client,
    this.phone = '',
    this.notes = '',
  });

  factory _CommercialActivityItem.fromVisit({
    required TourVisit visit,
    required CommercialClient? client,
    required DateTime date,
  }) {
    return _CommercialActivityItem(
      id: visit.id,
      title: AppLocalizations.globalText('Visite client'),
      subtitle: visit.clientName,
      location: 'Casablanca',
      time: visit.time,
      date: date,
      status: _visitActivityStatus(visit),
      icon: Icons.groups_rounded,
      color: _HomeCommercialState.primaryBlue,
      client: client,
      phone: client?.phone ?? '',
      notes: 'Visite commerciale planifi\u00e9e \u00e0 Casablanca.',
    );
  }

  final int id;
  final String title;
  final String subtitle;
  final String location;
  final String time;
  final DateTime date;
  final _CommercialActivityStatus status;
  final IconData icon;
  final Color color;
  final CommercialClient? client;
  final String phone;
  final String notes;
}

_CommercialActivityStatus _visitActivityStatus(TourVisit visit) {
  if (visit.status == TourVisitStatus.visited)
    return _CommercialActivityStatus.done;
  final now = DateTime.now();
  final parts = visit.time.split(':');
  final hour = int.tryParse(parts.first) ?? 0;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  final visitTime = DateTime(now.year, now.month, now.day, hour, minute);
  if (visitTime.isBefore(now)) return _CommercialActivityStatus.late;
  return _CommercialActivityStatus.todo;
}

class PremiumActivitiesPage extends StatefulWidget {
  PremiumActivitiesPage({
    super.key,
    required this.visits,
    required this.clients,
    required this.currentEmail,
    required this.currentUserName,
    required this.unreadNotificationCount,
  });

  final List<TourVisit> visits;
  final List<CommercialClient> clients;
  final String currentEmail;
  final String currentUserName;
  final int unreadNotificationCount;

  @override
  State<PremiumActivitiesPage> createState() => _PremiumActivitiesPageState();
}

class _PremiumActivitiesPageState extends State<PremiumActivitiesPage> {
  late DateTime _selectedDate;
  _ActivityFilter _selectedFilter = _ActivityFilter.all;
  final List<_CommercialActivityItem> _createdActivities = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateUtils.dateOnly(DateTime.now());
  }

  CommercialClient? _clientForVisit(TourVisit visit) {
    for (final client in widget.clients) {
      if (client.id == visit.clientId) return client;
    }
    return null;
  }

  bool _isCasablancaClient(CommercialClient client) {
    final city = client.city.toLowerCase();
    return city.contains('casablanca') || city.contains('bouskoura');
  }

  bool _isCasablancaVisit(TourVisit visit) {
    final client = _clientForVisit(visit);
    if (client == null) return true;
    return _isCasablancaClient(client);
  }

  List<_CommercialActivityItem> get _selectedDateActivities {
    final visitActivities = widget.visits
        .where(_isCasablancaVisit)
        .map(
          (visit) => _CommercialActivityItem.fromVisit(
            visit: visit,
            client: _clientForVisit(visit),
            date: DateUtils.dateOnly(DateTime.now()),
          ),
        );
    return [...visitActivities, ..._createdActivities]
        .where((activity) => DateUtils.isSameDay(activity.date, _selectedDate))
        .toList()
      ..sort((left, right) => left.time.compareTo(right.time));
  }

  List<_CommercialActivityItem> get _visibleActivities {
    return _selectedDateActivities
        .where((activity) => _selectedFilter.matches(activity.status))
        .toList();
  }

  int _countStatus(_CommercialActivityStatus status) {
    return _selectedDateActivities
        .where((activity) => activity.status == status)
        .length;
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CommercialNotificationsPage()),
    );
  }

  void _openActivity(_CommercialActivityItem activity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ActivityVisitDetailPage(activity: activity),
      ),
    );
  }

  Future<void> _openNewActivity() async {
    final created = await Navigator.push<_CommercialActivityItem>(
      context,
      MaterialPageRoute(
        builder: (_) => NewActivityPage(
          clients: widget.clients.where(_isCasablancaClient).toList(),
          selectedDate: _selectedDate,
        ),
      ),
    );
    if (created == null || !mounted) return;
    setState(() {
      _createdActivities.add(created);
      _selectedDate = DateUtils.dateOnly(created.date);
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Activité créée avec succès')));
  }

  @override
  Widget build(BuildContext context) {
    final dayActivities = _selectedDateActivities;
    final visibleActivities = _visibleActivities;
    return Stack(
      children: [
        CustomScrollView(
          physics: BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 96),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _ActivitiesHeader(
                    onNotificationsTap: _openNotifications,
                    unreadNotificationCount: widget.unreadNotificationCount,
                  ),
                  SizedBox(height: 18),
                  _ActivityDateSelector(
                    selectedDate: _selectedDate,
                    onChanged: (date) {
                      setState(() => _selectedDate = DateUtils.dateOnly(date));
                    },
                  ),
                  SizedBox(height: 24),
                  _ActivitySectionTitle('Vue d\'ensemble'),
                  SizedBox(height: 12),
                  _ActivityKpiCard(
                    total: dayActivities.length,
                    inProgress: _countStatus(
                      _CommercialActivityStatus.inProgress,
                    ),
                    done: _countStatus(_CommercialActivityStatus.done),
                    late: _countStatus(_CommercialActivityStatus.late),
                  ),
                  SizedBox(height: 18),
                  _ActivityFilterTabs(
                    selectedFilter: _selectedFilter,
                    onChanged: (filter) =>
                        setState(() => _selectedFilter = filter),
                  ),
                  SizedBox(height: 18),
                  Text(
                    _activityDayTitle(_selectedDate),
                    style: TextStyle(
                      color: _HomeCommercialState.textDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 12),
                  if (visibleActivities.isEmpty)
                    _EmptyActivitiesCard()
                  else
                    _ActivitiesListCard(
                      activities: visibleActivities,
                      onTap: _openActivity,
                    ),
                ]),
              ),
            ),
          ],
        ),
        Positioned(
          right: 20,
          bottom: 18,
          child: FloatingActionButton(
            onPressed: _openNewActivity,
            backgroundColor: _HomeCommercialState.primaryBlue,
            foregroundColor: Colors.white,
            elevation: 10,
            child: Icon(Icons.add_rounded, size: 34),
          ),
        ),
      ],
    );
  }
}

String _activityDayTitle(DateTime selectedDate) {
  final today = DateUtils.dateOnly(DateTime.now());
  final tomorrow = today.add(Duration(days: 1));
  if (DateUtils.isSameDay(selectedDate, today)) return "Aujourd'hui";
  if (DateUtils.isSameDay(selectedDate, tomorrow)) return 'Demain';
  return _fullActivityDateLabel(selectedDate);
}

String _fullActivityDateLabel(DateTime date) {
  final days = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];
  return '${days[date.weekday - 1]} ${date.day}';
}

String _activityMonthLabel(DateTime date) {
  final months = [
    'Jan',
    'F\u00e9v',
    'Mar',
    'Avr',
    'Mai',
    'Juin',
    'Juil',
    'Ao\u00fbt',
    'Sep',
    'Oct',
    'Nov',
    'D\u00e9c',
  ];
  return months[date.month - 1];
}

class _ActivitiesHeader extends StatelessWidget {
  _ActivitiesHeader({
    required this.onNotificationsTap,
    required this.unreadNotificationCount,
  });
  final VoidCallback onNotificationsTap;
  final int unreadNotificationCount;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.globalText('Activit\u00e9s'),
                style: TextStyle(
                  color: _HomeCommercialState.textDark,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                AppLocalizations.globalText(
                  'Suivez vos t\u00e2ches et votre planning',
                ),
                style: TextStyle(
                  color: _HomeCommercialState.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        _CommercialNotificationButton(
          onTap: onNotificationsTap,
          unreadCount: unreadNotificationCount,
        ),
      ],
    );
  }
}

class _ActivityDateSelector extends StatelessWidget {
  _ActivityDateSelector({required this.selectedDate, required this.onChanged});
  final DateTime selectedDate;
  final ValueChanged<DateTime> onChanged;
  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final dates = List.generate(7, (index) => today.add(Duration(days: index)));
    return Container(
      padding: EdgeInsets.fromLTRB(8, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0F172A).withValues(alpha: .055),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          for (final date in dates)
            Expanded(
              child: _ActivityDateTile(
                date: date,
                selected: DateUtils.isSameDay(date, selectedDate),
                onTap: () => onChanged(date),
              ),
            ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.calendar_today_outlined,
              color: _HomeCommercialState.textMuted,
              size: 21,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityDateTile extends StatelessWidget {
  _ActivityDateTile({
    required this.date,
    required this.selected,
    required this.onTap,
  });
  final DateTime date;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? _HomeCommercialState.primaryBlue
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                Text(
                  days[date.weekday - 1],
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : _HomeCommercialState.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '${date.day}',
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : _HomeCommercialState.textDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _activityMonthLabel(date),
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : _HomeCommercialState.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 5),
          SizedBox(
            height: 8,
            child: selected
                ? CircleAvatar(
                    radius: 4,
                    backgroundColor: _HomeCommercialState.primaryBlue,
                  )
                : SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _ActivitySectionTitle extends StatelessWidget {
  _ActivitySectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Text(
    title,
    style: TextStyle(
      color: _HomeCommercialState.textDark,
      fontSize: 18,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _ActivityKpiCard extends StatelessWidget {
  _ActivityKpiCard({
    required this.total,
    required this.inProgress,
    required this.done,
    required this.late,
  });
  final int total;
  final int inProgress;
  final int done;
  final int late;
  @override
  Widget build(BuildContext context) {
    final items = [
      _ActivityKpiData(
        'Total',
        total,
        Icons.assignment_outlined,
        _HomeCommercialState.primaryBlue,
      ),
      _ActivityKpiData(
        'En cours',
        inProgress,
        Icons.schedule_rounded,
        Color(0xFFF59E0B),
      ),
      _ActivityKpiData(
        'Termin\u00e9es',
        done,
        Icons.check_circle_outline_rounded,
        Color(0xFF22C55E),
      ),
      _ActivityKpiData(
        'En retard',
        late,
        Icons.close_rounded,
        Color(0xFFEF4444),
      ),
    ];
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0F172A).withValues(alpha: .055),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Expanded(child: _ActivityKpiMini(data: items[i])),
            if (i != items.length - 1)
              Container(width: 1, height: 74, color: Color(0xFFE8EEF7)),
          ],
        ],
      ),
    );
  }
}

class _ActivityKpiData {
  _ActivityKpiData(this.label, this.value, this.icon, this.color);
  final String label;
  final int value;
  final IconData icon;
  final Color color;
}

class _ActivityKpiMini extends StatelessWidget {
  _ActivityKpiMini({required this.data});
  final _ActivityKpiData data;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: data.color.withValues(alpha: .11),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(data.icon, color: data.color, size: 24),
      ),
      SizedBox(height: 10),
      Text(
        '${data.value}',
        style: TextStyle(
          color: data.color,
          fontSize: 23,
          fontWeight: FontWeight.w700,
        ),
      ),
      SizedBox(height: 5),
      Text(
        data.label,
        style: TextStyle(
          color: _HomeCommercialState.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      SizedBox(height: 8),
      Container(
        width: 44,
        height: 4,
        decoration: BoxDecoration(
          color: data.color,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    ],
  );
}

class _ActivityFilterTabs extends StatelessWidget {
  _ActivityFilterTabs({required this.selectedFilter, required this.onChanged});
  final _ActivityFilter selectedFilter;
  final ValueChanged<_ActivityFilter> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: Color(0xFF0F172A).withValues(alpha: .045),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      children: [
        for (final filter in _ActivityFilter.values)
          Expanded(
            child: InkWell(
              onTap: () => onChanged(filter),
              borderRadius: BorderRadius.circular(15),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selectedFilter == filter
                      ? _HomeCommercialState.primaryBlue
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  filter.label,
                  style: TextStyle(
                    color: selectedFilter == filter
                        ? Colors.white
                        : _HomeCommercialState.textMuted,
                    fontSize: 13,
                    fontWeight: selectedFilter == filter
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _ActivitiesListCard extends StatelessWidget {
  _ActivitiesListCard({required this.activities, required this.onTap});
  final List<_CommercialActivityItem> activities;
  final ValueChanged<_CommercialActivityItem> onTap;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Color(0xFF0F172A).withValues(alpha: .055),
          blurRadius: 22,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      children: [
        for (var i = 0; i < activities.length; i++) ...[
          _ActivityRow(
            activity: activities[i],
            onTap: () => onTap(activities[i]),
          ),
          if (i != activities.length - 1)
            Divider(height: 1, color: Color(0xFFE8EEF7)),
        ],
      ],
    ),
  );
}

class _ActivityRow extends StatelessWidget {
  _ActivityRow({required this.activity, required this.onTap});
  final _CommercialActivityItem activity;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final status = _ActivityStatusStyle.fromStatus(activity.status);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 14, 16),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: activity.color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(activity.icon, color: activity.color, size: 30),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      color: _HomeCommercialState.textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    activity.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _HomeCommercialState.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 7),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        color: _HomeCommercialState.textMuted,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        AppLocalizations.globalText('Casablanca'),
                        style: TextStyle(
                          color: _HomeCommercialState.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  activity.time,
                  style: TextStyle(
                    color: status.color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 10),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: status.color.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status.label,
                    style: TextStyle(
                      color: status.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: _HomeCommercialState.textMuted,
              size: 25,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityStatusStyle {
  _ActivityStatusStyle(this.label, this.color);
  factory _ActivityStatusStyle.fromStatus(_CommercialActivityStatus status) {
    return switch (status) {
      _CommercialActivityStatus.todo => _ActivityStatusStyle(
        '\u00c0 faire',
        Color(0xFF2563EB),
      ),
      _CommercialActivityStatus.inProgress => _ActivityStatusStyle(
        'En cours',
        Color(0xFF2563EB),
      ),
      _CommercialActivityStatus.done => _ActivityStatusStyle(
        'Termin\u00e9e',
        Color(0xFF22C55E),
      ),
      _CommercialActivityStatus.late => _ActivityStatusStyle(
        'En retard',
        Color(0xFFEF4444),
      ),
    };
  }
  final String label;
  final Color color;
}

class _EmptyActivitiesCard extends StatelessWidget {
  _EmptyActivitiesCard();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.fromLTRB(22, 34, 22, 30),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Color(0xFF0F172A).withValues(alpha: .045),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      children: [
        Icon(
          Icons.event_available_rounded,
          color: _HomeCommercialState.primaryBlue,
          size: 42,
        ),
        SizedBox(height: 14),
        Text(
          AppLocalizations.globalText('Aucune activit\u00e9 pour cette date'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _HomeCommercialState.textDark,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 6),
        Text(
          AppLocalizations.globalText(
            'Les activit\u00e9s du commercial seront affich\u00e9es ici d\u00e8s leur chargement.',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _HomeCommercialState.textMuted,
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

class _ActivityVisitDetailPage extends StatelessWidget {
  _ActivityVisitDetailPage({required this.activity});
  final _CommercialActivityItem activity;

  @override
  Widget build(BuildContext context) {
    return _ActivityDetailScaffold(
      title: AppLocalizations.globalText('D\u00e9tail visite client'),
      icon: Icons.groups_rounded,
      color: _HomeCommercialState.primaryBlue,
      children: [
        _ActivityDetailRow(
          label: AppLocalizations.globalText('Nom client'),
          value: activity.subtitle,
        ),
        _ActivityDetailRow(
          label: AppLocalizations.globalText('Adresse'),
          value: activity.client?.address ?? 'Casablanca',
        ),
        _ActivityDetailRow(
          label: AppLocalizations.globalText('T\u00e9l\u00e9phone'),
          value: activity.phone,
        ),
        _ActivityDetailRow(
          label: AppLocalizations.globalText('Heure pr\u00e9vue'),
          value: activity.time,
        ),
        _ActivityDetailRow(
          label: AppLocalizations.globalText('Notes'),
          value: activity.notes,
        ),
        _ActivityDetailRow(
          label: AppLocalizations.globalText('Statut'),
          value: _ActivityStatusStyle.fromStatus(activity.status).label,
        ),
        SizedBox(height: 18),
        _ActivityPrimaryButton(
          label: AppLocalizations.globalText('D\u00e9marrer visite'),
          icon: Icons.play_arrow_rounded,
        ),
        SizedBox(height: 10),
        _ActivityPrimaryButton(
          label: AppLocalizations.globalText('Terminer visite'),
          icon: Icons.check_rounded,
        ),
        SizedBox(height: 10),
        _ActivitySecondaryButton(
          label: AppLocalizations.globalText('Ajouter compte rendu'),
          icon: Icons.note_add_outlined,
        ),
      ],
    );
  }
}

// ignore: unused_element
class _ActivityCallDetailPage extends StatelessWidget {
  _ActivityCallDetailPage({required this.activity});
  final _CommercialActivityItem activity;

  @override
  Widget build(BuildContext context) {
    return _ActivityDetailScaffold(
      title: AppLocalizations.globalText('D\u00e9tail appel client'),
      icon: Icons.call_outlined,
      color: Color(0xFFF59E0B),
      children: [
        _ActivityDetailRow(
          label: AppLocalizations.globalText('Client'),
          value: activity.subtitle,
        ),
        _ActivityDetailRow(
          label: AppLocalizations.globalText('T\u00e9l\u00e9phone'),
          value: activity.phone,
        ),
        _ActivityDetailRow(
          label: AppLocalizations.globalText('Historique'),
          value: 'Historique charg\u00e9 depuis les activit\u00e9s client.',
        ),
        _ActivityDetailRow(
          label: AppLocalizations.globalText('Notes'),
          value: activity.notes,
        ),
        SizedBox(height: 18),
        _ActivityPrimaryButton(
          label: AppLocalizations.globalText('Appeler'),
          icon: Icons.call_rounded,
        ),
      ],
    );
  }
}

class _ActivityDetailScaffold extends StatelessWidget {
  _ActivityDetailScaffold({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _HomeCommercialState.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 428),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(Icons.arrow_back_rounded),
                              color: _HomeCommercialState.textDark,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  color: _HomeCommercialState.textDark,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 22),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(18),
                          decoration: _premiumCardDecoration(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: .11),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(icon, color: color, size: 31),
                              ),
                              SizedBox(height: 18),
                              ...children,
                            ],
                          ),
                        ),
                      ],
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

class _ActivityDetailRow extends StatelessWidget {
  _ActivityDetailRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _HomeCommercialState.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 5),
          Text(
            value.trim().isEmpty ? '-' : value,
            style: TextStyle(
              color: _HomeCommercialState.textDark,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityPrimaryButton extends StatelessWidget {
  _ActivityPrimaryButton({required this.label, required this.icon});
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {},
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: _HomeCommercialState.primaryBlue,
          foregroundColor: Colors.white,
          textStyle: TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _ActivitySecondaryButton extends StatelessWidget {
  _ActivitySecondaryButton({required this.label, required this.icon});
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {},
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: _HomeCommercialState.primaryBlue,
          side: BorderSide(color: _HomeCommercialState.primaryBlue),
          textStyle: TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class NewActivityPage extends StatefulWidget {
  NewActivityPage({
    super.key,
    required this.clients,
    required this.selectedDate,
    this.initialType = 'Visite client',
  });
  final List<CommercialClient> clients;
  final DateTime selectedDate;
  final String initialType;

  @override
  State<NewActivityPage> createState() => _NewActivityPageState();
}

class _NewActivityPageState extends State<NewActivityPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _participantsController = TextEditingController();
  final _placeController = TextEditingController();
  final _objectiveController = TextEditingController();
  final _notesController = TextEditingController();
  final _claimReasonController = TextEditingController();

  late String _type;
  CommercialClient? _client;
  late DateTime _date;
  TimeOfDay _time = TimeOfDay(hour: 9, minute: 30);
  String _duration = '30 min';
  String _priority = 'Haute';
  String _reminder = '30 min avant';
  String _status = 'Planifiée';
  String _result = 'À relancer';
  String _visitAddress = '';

  static const _activityTypes = [
    'Visite client',
    'Appel de suivi',
    'Réunion',
    'Tâche',
    'Réclamation client',
  ];
  static const _statuses = ['Planifiée', 'Réalisée', 'Reportée', 'Annulée'];
  static const _results = [
    'Commande obtenue',
    'Client absent',
    'À relancer',
    'Refus',
    'Visite réalisée',
    'Réclamation résolue',
  ];

  @override
  void initState() {
    super.initState();
    _type = _activityTypes.contains(widget.initialType)
        ? widget.initialType
        : 'Visite client';
    _date = widget.selectedDate;
    _client = widget.clients.isEmpty ? null : widget.clients.first;
    _syncClientAddress();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _participantsController.dispose();
    _placeController.dispose();
    _objectiveController.dispose();
    _notesController.dispose();
    _claimReasonController.dispose();
    super.dispose();
  }

  bool get _isVisit => _type == 'Visite client';
  bool get _isMeeting => _type == 'Réunion';
  bool get _isTask => _type == 'Tâche';
  bool get _isClaim => _type == 'Réclamation client';
  bool get _showsTime => !_isTask;
  bool get _showsDuration => !_isTask && !_isClaim;
  bool get _showsMaps => _isVisit || _isMeeting;

  String get _dateLabel => _isTask ? 'Date limite' : 'Date';

  String get _objectiveLabel {
    return switch (_type) {
      'Appel de suivi' => "Objectif de l'appel",
      'Réunion' => 'Objectif de la réunion',
      'Tâche' => 'Description de la tâche',
      'Réclamation client' => 'Description',
      _ => 'Objectif de la visite',
    };
  }

  String get _objectiveHint {
    return switch (_type) {
      'Appel de suivi' => 'Faire le suivi de la dernière commande.',
      'Réunion' => 'Préparer le planning commercial de la semaine.',
      'Tâche' => 'Décrire la tâche à réaliser.',
      'Réclamation client' =>
        'Décrivez la réclamation et les actions à prévoir.',
      _ =>
        'Présenter les nouveaux produits et recueillir les besoins du client.',
    };
  }

  IconData get _typeIcon {
    return switch (_type) {
      'Appel de suivi' => Icons.call_outlined,
      'Réunion' => Icons.groups_2_outlined,
      'Tâche' => Icons.task_alt_rounded,
      'Réclamation client' => Icons.report_problem_outlined,
      _ => Icons.calendar_month_outlined,
    };
  }

  Color get _priorityColor {
    return switch (_priority) {
      'Urgente' => const Color(0xFFEF4444),
      'Haute' => const Color(0xFFF97316),
      _ => _HomeCommercialState.primaryBlue,
    };
  }

  void _syncClientAddress() {
    final client = _client;
    if (client == null) return;
    final address = client.address.trim().isEmpty
        ? client.city
        : client.address;
    _visitAddress = address.contains(client.city)
        ? address
        : '$address, ${client.city}';
    if (_isMeeting && _placeController.text.trim().isEmpty) {
      _placeController.text = _visitAddress;
    }
  }

  void _changeType(String value) {
    setState(() {
      _type = value;
      if (_client == null && widget.clients.isNotEmpty) {
        _client = widget.clients.first;
      }
      if (!_isClaim) _claimReasonController.clear();
      _syncClientAddress();
    });
  }

  void _changeClient(CommercialClient value) {
    setState(() {
      _client = value;
      _syncClientAddress();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(Duration(days: 1)),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _openMaps() async {
    final address = _isMeeting
        ? _placeController.text.trim()
        : _visitAddress.trim();
    if (address.isEmpty) {
      _showMessage('Adresse indisponible');
      return;
    }
    final query = Uri.encodeComponent(address);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) _showMessage('Google Maps indisponible');
  }

  String? _required(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_client == null) {
      _showMessage('Veuillez sélectionner un client');
      return;
    }
    if (_objectiveController.text.trim().isEmpty) {
      _showMessage('Veuillez renseigner l’objectif ou la description');
      return;
    }

    final created = _CommercialActivityItem(
      id: DateTime.now().millisecondsSinceEpoch,
      title: _type,
      subtitle: _activitySubtitle(),
      location: _activityLocation(),
      time: _showsTime ? _time.format(context) : _activityDateLabel(_date),
      date: DateUtils.dateOnly(_date),
      status: _status == 'Réalisée'
          ? _CommercialActivityStatus.done
          : _CommercialActivityStatus.todo,
      icon: _typeIcon,
      color: _priorityColor,
      client: _client,
      phone: _client?.phone ?? '',
      notes: _activityNotes(),
    );

    await _showMobileOrderSheet<void>(
      context: context,
      child: _OrderInfoSheet(
        icon: Icons.check_circle_rounded,
        iconColor: Color(0xFF22C55E),
        title: 'Activité créée',
        message: 'Nouvelle activité planifiée avec succès.',
        buttonLabel: 'Continuer',
        onPressed: () => Navigator.pop(context),
      ),
    );
    if (!mounted) return;
    Navigator.pop(context, created);
  }

  String _activitySubtitle() {
    if (_isClaim) return _claimReasonController.text.trim();
    return _client?.name ?? '';
  }

  String _activityLocation() {
    if (_isVisit) return _visitAddress;
    if (_isMeeting) return _placeController.text.trim();
    return _client?.city ?? 'Casablanca';
  }

  String _activityNotes() {
    final parts = <String>[
      _objectiveController.text.trim(),
      if (_isClaim && _claimReasonController.text.trim().isNotEmpty)
        'Motif: ${_claimReasonController.text.trim()}',
      if (_result.trim().isNotEmpty) 'Résultat: $_result',
      if (_notesController.text.trim().isNotEmpty) _notesController.text.trim(),
    ];
    return parts.where((part) => part.isNotEmpty).join('\n');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _HomeCommercialState.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 428),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _NewActivityHeader(
                          onBack: () => Navigator.pop(context),
                        ),
                        SizedBox(height: 22),
                        Form(
                          key: _formKey,
                          child: Container(
                            padding: EdgeInsets.all(18),
                            decoration: _premiumCardDecoration(22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _NewActivitySelect<String>(
                                  label: "Type d'activité",
                                  value: _type,
                                  icon: _typeIcon,
                                  items: _activityTypes,
                                  itemLabel: (value) => value,
                                  onChanged: _changeType,
                                ),
                                SizedBox(height: 18),
                                _NewActivitySelect<CommercialClient>(
                                  label: 'Client',
                                  value: _client,
                                  icon: Icons.storefront_outlined,
                                  items: widget.clients,
                                  itemLabel: (client) => client.name,
                                  onChanged: _changeClient,
                                  validator: (_) => _client == null
                                      ? 'Veuillez sélectionner un client'
                                      : null,
                                ),
                                if (_client != null) ...[
                                  SizedBox(height: 4),
                                  _SelectedClientCard(client: _client!),
                                ],
                                if (_isMeeting) ...[
                                  SizedBox(height: 18),
                                  _NewActivityTextField(
                                    label: 'Participants',
                                    controller: _participantsController,
                                    icon: Icons.people_outline_rounded,
                                    hint: 'Équipe commerciale, manager...',
                                  ),
                                ],
                                if (_isClaim) ...[
                                  SizedBox(height: 18),
                                  _NewActivityTextField(
                                    label: 'Motif de réclamation',
                                    controller: _claimReasonController,
                                    icon: Icons.report_problem_outlined,
                                    hint: 'Retard, qualité, livraison...',
                                    validator: (value) => _required(
                                      value,
                                      'Veuillez saisir le motif de réclamation',
                                    ),
                                  ),
                                ],
                                SizedBox(height: 18),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _NewActivityPicker(
                                        label: _dateLabel,
                                        value: _activityDateLabel(_date),
                                        icon: Icons.calendar_today_outlined,
                                        onTap: _pickDate,
                                      ),
                                    ),
                                    if (_showsTime) ...[
                                      SizedBox(width: 14),
                                      Expanded(
                                        child: _NewActivityPicker(
                                          label: 'Heure',
                                          value: _time.format(context),
                                          icon: Icons.schedule_rounded,
                                          onTap: _pickTime,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                SizedBox(height: 18),
                                Row(
                                  children: [
                                    if (_showsDuration) ...[
                                      Expanded(
                                        child: _NewActivitySelect<String>(
                                          label: 'Durée prévue',
                                          value: _duration,
                                          icon: Icons.access_time_rounded,
                                          items: const [
                                            '15 min',
                                            '30 min',
                                            '45 min',
                                            '1 heure',
                                            '2 heures',
                                          ],
                                          itemLabel: (value) => value,
                                          onChanged: (value) =>
                                              setState(() => _duration = value),
                                        ),
                                      ),
                                      SizedBox(width: 14),
                                    ],
                                    Expanded(
                                      child: _NewActivitySelect<String>(
                                        label: 'Priorité',
                                        value: _priority,
                                        icon: Icons.flag_rounded,
                                        iconColor: _priorityColor,
                                        items: const [
                                          'Normale',
                                          'Haute',
                                          'Urgente',
                                        ],
                                        itemLabel: (value) => value,
                                        onChanged: (value) =>
                                            setState(() => _priority = value),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_isVisit) ...[
                                  SizedBox(height: 18),
                                  _NewActivityEditableValue(
                                    label: 'Adresse de visite',
                                    value: _visitAddress,
                                    icon: Icons.location_on_outlined,
                                    onChanged: (value) =>
                                        setState(() => _visitAddress = value),
                                  ),
                                ],
                                if (_isMeeting) ...[
                                  SizedBox(height: 18),
                                  _NewActivityTextField(
                                    label: 'Lieu de réunion',
                                    controller: _placeController,
                                    icon: Icons.location_on_outlined,
                                    hint: 'Salle de réunion ou adresse client',
                                    validator: (value) => _required(
                                      value,
                                      'Veuillez saisir un lieu',
                                    ),
                                  ),
                                ],
                                if (_showsMaps) ...[
                                  SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: _openMaps,
                                      icon: Icon(Icons.map_outlined, size: 18),
                                      label: Text('Ouvrir dans Google Maps'),
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            _HomeCommercialState.primaryBlue,
                                      ),
                                    ),
                                  ),
                                ],
                                SizedBox(height: 18),
                                _NewActivitySelect<String>(
                                  label: 'Rappel',
                                  value: _reminder,
                                  icon: Icons.notifications_none_rounded,
                                  items: const [
                                    'Aucun',
                                    '15 min avant',
                                    '30 min avant',
                                    '1 heure avant',
                                  ],
                                  itemLabel: (value) => value,
                                  onChanged: (value) =>
                                      setState(() => _reminder = value),
                                ),
                                SizedBox(height: 18),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _NewActivitySelect<String>(
                                        label: 'Statut',
                                        value: _status,
                                        icon: Icons.fact_check_outlined,
                                        items: _statuses,
                                        itemLabel: (value) => value,
                                        onChanged: (value) =>
                                            setState(() => _status = value),
                                      ),
                                    ),
                                    SizedBox(width: 14),
                                    Expanded(
                                      child: _NewActivitySelect<String>(
                                        label: 'Résultat',
                                        value: _result,
                                        icon: Icons.check_circle_outline,
                                        items: _results,
                                        itemLabel: (value) => value,
                                        onChanged: (value) =>
                                            setState(() => _result = value),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 18),
                                _NewActivityLongField(
                                  label: _objectiveLabel,
                                  controller: _objectiveController,
                                  icon: Icons.track_changes_rounded,
                                  hint: _objectiveHint,
                                  maxLength: 150,
                                ),
                                SizedBox(height: 18),
                                _NewActivityLongField(
                                  label: 'Notes (optionnel)',
                                  controller: _notesController,
                                  icon: Icons.notes_rounded,
                                  hint: 'Ajoutez des notes supplémentaires...',
                                  maxLength: 300,
                                ),
                                SizedBox(height: 24),
                                SizedBox(
                                  height: 58,
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _submit,
                                    icon: Icon(Icons.add_rounded, size: 28),
                                    label: Text('Créer activité'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          _HomeCommercialState.primaryBlue,
                                      foregroundColor: Colors.white,
                                      elevation: 8,
                                      shadowColor: _HomeCommercialState
                                          .primaryBlue
                                          .withValues(alpha: .25),
                                      textStyle: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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

class _NewActivityHeader extends StatelessWidget {
  _NewActivityHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: Icon(Icons.arrow_back_rounded, size: 30),
          color: _HomeCommercialState.primaryBlue,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(width: 42, height: 42),
        ),
        SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nouvelle activité',
                style: TextStyle(
                  color: _HomeCommercialState.textDark,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Planifiez une nouvelle activité',
                style: TextStyle(
                  color: _HomeCommercialState.textMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NewActivitySelect<T> extends StatelessWidget {
  _NewActivitySelect({
    required this.label,
    required this.value,
    required this.icon,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.validator,
    this.iconColor,
  });

  final String label;
  final T? value;
  final IconData icon;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T> onChanged;
  final FormFieldValidator<T>? validator;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return _NewActivityFieldShell(
      label: label,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        icon: Icon(Icons.keyboard_arrow_down_rounded),
        validator: validator,
        items: items.map((item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Text(
              itemLabel(item),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
        style: TextStyle(
          color: _HomeCommercialState.textDark,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
        decoration: _newActivityDecoration(icon: icon, iconColor: iconColor),
      ),
    );
  }
}

class _NewActivityPicker extends StatelessWidget {
  _NewActivityPicker({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _NewActivityFieldShell(
      label: label,
      child: TextFormField(
        readOnly: true,
        onTap: onTap,
        controller: TextEditingController(text: value),
        style: TextStyle(
          color: _HomeCommercialState.textDark,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
        decoration: _newActivityDecoration(
          icon: icon,
          suffixIcon: Icons.keyboard_arrow_down_rounded,
        ),
      ),
    );
  }
}

class _NewActivityTextField extends StatelessWidget {
  _NewActivityTextField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.hint,
    this.validator,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return _NewActivityFieldShell(
      label: label,
      child: TextFormField(
        controller: controller,
        validator: validator,
        onChanged: onChanged,
        style: TextStyle(
          color: _HomeCommercialState.textDark,
          fontWeight: FontWeight.w700,
        ),
        decoration: _newActivityDecoration(icon: icon, hintText: hint),
      ),
    );
  }
}

class _NewActivityEditableValue extends StatefulWidget {
  _NewActivityEditableValue({
    required this.label,
    required this.value,
    required this.icon,
    required this.onChanged,
  });

  final String label;
  final String value;
  final IconData icon;
  final ValueChanged<String> onChanged;

  @override
  State<_NewActivityEditableValue> createState() =>
      _NewActivityEditableValueState();
}

class _NewActivityEditableValueState extends State<_NewActivityEditableValue> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _NewActivityEditableValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _NewActivityTextField(
      label: widget.label,
      controller: _controller,
      icon: widget.icon,
      hint: '',
      onChanged: widget.onChanged,
      validator: (value) => value == null || value.trim().isEmpty
          ? 'Veuillez saisir une adresse'
          : null,
    );
  }
}

class _NewActivityLongField extends StatefulWidget {
  _NewActivityLongField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.hint,
    required this.maxLength,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final int maxLength;

  @override
  State<_NewActivityLongField> createState() => _NewActivityLongFieldState();
}

class _NewActivityLongFieldState extends State<_NewActivityLongField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return _NewActivityFieldShell(
      label: widget.label,
      child: TextFormField(
        controller: widget.controller,
        maxLength: widget.maxLength,
        minLines: widget.maxLength == 150 ? 3 : 4,
        maxLines: widget.maxLength == 150 ? 4 : 5,
        style: TextStyle(
          color: _HomeCommercialState.textDark,
          fontWeight: FontWeight.w700,
        ),
        decoration:
            _newActivityDecoration(
              icon: widget.icon,
              hintText: widget.hint,
            ).copyWith(
              counterText:
                  '${widget.controller.text.length}/${widget.maxLength}',
              counterStyle: TextStyle(
                color: _HomeCommercialState.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
      ),
    );
  }
}

class _SelectedClientCard extends StatelessWidget {
  _SelectedClientCard({required this.client});

  final CommercialClient client;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _HomeCommercialState.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _activityFieldBorder()),
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: _HomeCommercialState.primaryBlue.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.storefront_outlined,
              color: _HomeCommercialState.primaryBlue,
              size: 42,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _HomeCommercialState.textDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _HomeCommercialState.primaryBlue.withValues(
                      alpha: .08,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    client.status.label,
                    style: TextStyle(
                      color: _HomeCommercialState.textDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                _ClientMiniLine(
                  icon: Icons.location_on_outlined,
                  text: client.city,
                ),
                SizedBox(height: 4),
                _ClientMiniLine(icon: Icons.phone_outlined, text: client.phone),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientMiniLine extends StatelessWidget {
  _ClientMiniLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _HomeCommercialState.textMuted, size: 17),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _HomeCommercialState.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _NewActivityFieldShell extends StatelessWidget {
  _NewActivityFieldShell({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _HomeCommercialState.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 8),
        child,
      ],
    );
  }
}

InputDecoration _newActivityDecoration({
  required IconData icon,
  IconData? suffixIcon,
  String? hintText,
  Color? iconColor,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(
      color: _HomeCommercialState.textMuted.withValues(alpha: .72),
      fontWeight: FontWeight.w600,
    ),
    prefixIcon: Padding(
      padding: EdgeInsets.only(left: 12, right: 10),
      child: Icon(
        icon,
        color: iconColor ?? _HomeCommercialState.textMuted,
        size: 23,
      ),
    ),
    prefixIconConstraints: BoxConstraints(minWidth: 48),
    suffixIcon: suffixIcon == null
        ? null
        : Icon(suffixIcon, color: _HomeCommercialState.textDark),
    filled: true,
    fillColor: _HomeCommercialState.cardBg,
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: _activityOutlineBorder(),
    enabledBorder: _activityOutlineBorder(),
    focusedBorder: _activityOutlineBorder(
      _HomeCommercialState.primaryBlue,
      1.4,
    ),
    errorBorder: _activityOutlineBorder(_HomeCommercialState.error, 1.2),
    focusedErrorBorder: _activityOutlineBorder(_HomeCommercialState.error, 1.4),
  );
}

OutlineInputBorder _activityOutlineBorder([Color? color, double width = 1]) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(
      color: color ?? _activityFieldBorder(),
      width: width,
    ),
  );
}

Color _activityFieldBorder() {
  return ThemeData.estimateBrightnessForColor(_HomeCommercialState.cardBg) ==
          Brightness.dark
      ? const Color(0xFF334155)
      : const Color(0xFFE2E8F0);
}

String _activityDateLabel(DateTime date) {
  const months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class _TourMapCard extends StatelessWidget {
  _TourMapCard({
    required this.visits,
    required this.selectedVisit,
    required this.onVisitSelected,
  });

  final List<TourVisit> visits;
  final TourVisit? selectedVisit;
  final ValueChanged<TourVisit> onVisitSelected;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.38,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF18315E).withValues(alpha: .08),
              blurRadius: 18,
              offset: Offset(0, 9),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  CustomPaint(
                    size: Size.infinite,
                    painter: _TourMapPainter(visits: visits),
                  ),
                  Positioned(
                    left: constraints.maxWidth * .16,
                    top: constraints.maxHeight * .66,
                    child: _CurrentPositionDot(),
                  ),
                  for (final visit in visits)
                    Positioned(
                      left: constraints.maxWidth * visit.mapX - 14,
                      top: constraints.maxHeight * visit.mapY - 18,
                      child: GestureDetector(
                        onTap: () => onVisitSelected(visit),
                        child: _MapVisitPin(
                          number: visit.id,
                          selected: selectedVisit?.id == visit.id,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TourMapPainter extends CustomPainter {
  _TourMapPainter({required this.visits});

  final List<TourVisit> visits;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFFEFF3F8);
    canvas.drawRect(Offset.zero & size, background);

    final parkPaint = Paint()..color = const Color(0xFFD9F2E2);
    canvas.drawCircle(
      Offset(size.width * .12, size.height * .52),
      34,
      parkPaint,
    );
    canvas.drawCircle(
      Offset(size.width * .82, size.height * .08),
      42,
      parkPaint,
    );

    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    for (var i = -3; i < 8; i++) {
      final start = Offset(size.width * (i * .18), 0);
      final end = Offset(size.width * (i * .18 + .62), size.height);
      canvas.drawLine(start, end, roadPaint);
    }
    for (var i = -2; i < 7; i++) {
      final start = Offset(0, size.height * (i * .17));
      final end = Offset(size.width, size.height * (i * .17 + .52));
      canvas.drawLine(start, end, roadPaint);
    }

    if (visits.length > 1) {
      final routePaint = Paint()
        ..color = _HomeCommercialState.primaryBlue
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      for (var i = 0; i < visits.length; i++) {
        final point = Offset(
          size.width * visits[i].mapX,
          size.height * visits[i].mapY,
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(path, routePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TourMapPainter oldDelegate) {
    return oldDelegate.visits != visits;
  }
}

class _CurrentPositionDot extends StatelessWidget {
  _CurrentPositionDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: _HomeCommercialState.primaryBlue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: _HomeCommercialState.primaryBlue.withValues(alpha: .28),
            blurRadius: 10,
          ),
        ],
      ),
    );
  }
}

class _MapVisitPin extends StatelessWidget {
  _MapVisitPin({required this.number, required this.selected});

  final int number;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: Duration(milliseconds: 180),
      scale: selected ? 1.15 : 1,
      child: Container(
        width: 28,
        height: 36,
        alignment: Alignment.topCenter,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: 20,
              child: Icon(
                Icons.location_on_rounded,
                color: _HomeCommercialState.primaryBlue,
                size: 30,
              ),
            ),
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _HomeCommercialState.primaryBlue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                '$number',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
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

class _TourVisitsCard extends StatelessWidget {
  _TourVisitsCard({
    required this.visits,
    required this.selectedVisitId,
    required this.onVisitTap,
  });

  final List<TourVisit> visits;
  final int? selectedVisitId;
  final ValueChanged<TourVisit> onVisitTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      transform: Matrix4.translationValues(0, -12, 0),
      padding: EdgeInsets.fromLTRB(16, 8, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF18315E).withValues(alpha: .08),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < visits.length; i++)
            _TourVisitRow(
              visit: visits[i],
              selected: visits[i].id == selectedVisitId,
              isLast: i == visits.length - 1,
              onTap: () => onVisitTap(visits[i]),
            ),
        ],
      ),
    );
  }
}

class _TourVisitRow extends StatelessWidget {
  _TourVisitRow({
    required this.visit,
    required this.selected,
    required this.isLast,
    required this.onTap,
  });

  final TourVisit visit;
  final bool selected;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? _HomeCommercialState.primaryBlue.withValues(alpha: .05)
              : Colors.transparent,
          border: Border(
            bottom: isLast
                ? BorderSide.none
                : BorderSide(color: Color(0xFFE8EDF5)),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: _HomeCommercialState.primaryBlue,
              child: Text(
                '${visit.id}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                visit.clientName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _HomeCommercialState.textDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            SizedBox(width: 8),
            Text(
              visit.time,
              style: TextStyle(
                color: _HomeCommercialState.textDark,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(width: 12),
            _VisitStatusBadge(status: visit.status),
          ],
        ),
      ),
    );
  }
}

class _VisitStatusBadge extends StatelessWidget {
  _VisitStatusBadge({required this.status});

  final TourVisitStatus status;

  @override
  Widget build(BuildContext context) {
    final isVisited = status == TourVisitStatus.visited;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: isVisited ? Color(0xFFE5FAEF) : Color(0xFFFFF0DF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: isVisited ? Color(0xFF20B875) : Color(0xFFFF8A1F),
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class DetailClient extends StatefulWidget {
  DetailClient({
    super.key,
    required this.client,
    required this.currentEmail,
    required this.currentUserName,
  });

  final CommercialClient? client;
  final String currentEmail;
  final String currentUserName;

  @override
  State<DetailClient> createState() => _DetailClientState();
}

class _DetailClientState extends State<DetailClient> {
  int _selectedTab = 0;
  late CommercialClient? _client;
  final List<_ClientNote> _notes = [];

  @override
  void initState() {
    super.initState();
    _client = widget.client;
  }

  Future<void> _launch(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.globalText(
                'Action indisponible sur cet appareil',
              ),
            ),
          ),
        );
    }
  }

  void _goToCommercialTab(int index) {
    if (index == 1) {
      Navigator.pop(context);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeCommercial(),
        settings: RouteSettings(
          arguments: {
            'email': widget.currentEmail,
            'name': widget.currentUserName,
            'initialIndex': index,
          },
        ),
      ),
    );
  }

  void _openMaps(CommercialClient client) {
    final query = Uri.encodeComponent(client.address);
    _launch(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$query'),
    );
  }

  Future<void> _handleOption(CommercialClient client, String value) async {
    if (value == 'location') {
      _openMaps(client);
      return;
    }

    if (value == 'edit') {
      final updated = await Navigator.push<CommercialClient>(
        context,
        MaterialPageRoute(
          builder: (_) => NouveauClientScreen(
            currentEmail: widget.currentEmail,
            currentUserName: widget.currentUserName,
            existingClients: _runtimeClientsForEmail(widget.currentEmail),
            editingClient: client,
          ),
        ),
      );
      if (updated == null || !mounted) return;
      setState(() => _client = updated);
      _addRuntimeClientForEmail(widget.currentEmail, updated);
      _clientDataRevision.value++;
      return;
    }

    if (value == 'note') {
      final note = await _showMobileOrderSheet<String>(
        context: context,
        child: _ClientNoteSheet(),
      );
      if (note == null || note.trim().isEmpty || !mounted) return;
      setState(() {
        _notes.insert(
          0,
          _ClientNote(text: note.trim(), createdAt: DateTime.now()),
        );
        _selectedTab = 1;
      });
    }
  }

  Future<void> _openNewOrder(CommercialClient client) async {
    if (client.status == ClientStatus.inactive) {
      await _showInactiveClientSheet(context);
      return;
    }

    var orderClient = client;
    if (client.status == ClientStatus.toVisit) {
      final navigator = Navigator.of(context);
      final shouldConvert = await _showMobileOrderSheet<bool>(
        context: context,
        child: _ProspectConversionSheet(
          onCancel: () => navigator.pop(false),
          onConvert: () => navigator.pop(true),
        ),
      );
      if (shouldConvert != true) return;
      orderClient = client.copyWith(status: ClientStatus.visited);
      _convertedOrderClientIds.add(client.id);
      _clientDataRevision.value++;
      if (!mounted) return;
      await _showConvertedClientSheet(context);
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NouvelleCommande(
          client: orderClient,
          selectedClientData: _ClientViewData.fromClient(orderClient),
          currentEmail: widget.currentEmail,
          currentUserName: widget.currentUserName,
        ),
        settings: RouteSettings(arguments: {'clientId': orderClient.id}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final client = _client;

    return Scaffold(
      backgroundColor: _HomeCommercialState.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final phoneWidth = constraints.maxWidth > 390
                ? 390.0
                : constraints.maxWidth;

            return Center(
              child: SizedBox(
                width: phoneWidth,
                height: constraints.maxHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF18315E).withValues(alpha: .08),
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: client == null
                        ? _ClientNotFound(onBack: () => Navigator.pop(context))
                        : Column(
                            children: [
                              Expanded(
                                child: CustomScrollView(
                                  physics: BouncingScrollPhysics(),
                                  slivers: [
                                    SliverPadding(
                                      padding: EdgeInsets.fromLTRB(
                                        18,
                                        14,
                                        18,
                                        18,
                                      ),
                                      sliver: SliverList(
                                        delegate: SliverChildListDelegate([
                                          _DetailTopBar(
                                            onBack: () =>
                                                Navigator.pop(context),
                                            onOptionSelected: (value) =>
                                                _handleOption(client, value),
                                          ),
                                          SizedBox(height: 16),
                                          _ClientIdentity(client: client),
                                          SizedBox(height: 16),
                                          _ClientSummaryCard(client: client),
                                          SizedBox(height: 18),
                                          _DetailTabs(
                                            selectedIndex: _selectedTab,
                                            onChanged: (index) => setState(
                                              () => _selectedTab = index,
                                            ),
                                          ),
                                          SizedBox(height: 18),
                                          AnimatedSwitcher(
                                            duration: Duration(
                                              milliseconds: 220,
                                            ),
                                            child: _DetailTabContent(
                                              key: ValueKey(_selectedTab),
                                              selectedIndex: _selectedTab,
                                              client: client,
                                              orders: _ordersForClient(
                                                widget.currentEmail,
                                                client,
                                              ),
                                              notes: _notes,
                                              onCall: () => _launch(
                                                Uri(
                                                  scheme: 'tel',
                                                  path: client.phone.replaceAll(
                                                    ' ',
                                                    '',
                                                  ),
                                                ),
                                              ),
                                              onEmail: () => _launch(
                                                Uri(
                                                  scheme: 'mailto',
                                                  path: client.email,
                                                ),
                                              ),
                                              onMaps: () => _openMaps(client),
                                            ),
                                          ),
                                          SizedBox(height: 22),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 52,
                                            child: ElevatedButton(
                                              onPressed: () =>
                                                  _openNewOrder(client),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    _HomeCommercialState
                                                        .primaryBlue,
                                                foregroundColor: Colors.white,
                                                elevation: 8,
                                                shadowColor:
                                                    _HomeCommercialState
                                                        .primaryBlue
                                                        .withValues(alpha: .26),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(11),
                                                ),
                                              ),
                                              child: Text(
                                                AppLocalizations.globalText(
                                                  'Nouvelle commande',
                                                ),
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ]),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _CommercialBottomNav(
                                selectedIndex: 1,
                                onChanged: _goToCommercialTab,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class NouvelleCommandeClientSelection extends StatefulWidget {
  NouvelleCommandeClientSelection({
    super.key,
    required this.clients,
    required this.currentEmail,
    required this.currentUserName,
  });

  final List<CommercialClient> clients;
  final String currentEmail;
  final String currentUserName;

  @override
  State<NouvelleCommandeClientSelection> createState() =>
      _NouvelleCommandeClientSelectionState();
}

class _NouvelleCommandeClientSelectionState
    extends State<NouvelleCommandeClientSelection> {
  final _searchController = TextEditingController();
  final Set<int> _convertedClientIds = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_ClientViewData> get _clients {
    final source = widget.clients.isEmpty
        ? _fallbackCommercialClients
        : widget.clients;
    final views = [
      for (var i = 0; i < source.length; i++)
        _ClientViewData.fromClient(
          _convertedClientIds.contains(source[i].id)
              ? source[i].copyWith(status: ClientStatus.visited)
              : source[i],
          index: i,
        ),
    ];
    return views.where((client) {
      return _query.isEmpty ||
          client.name.toLowerCase().contains(_query) ||
          client.type.toLowerCase().contains(_query) ||
          client.client.city.toLowerCase().contains(_query) ||
          client.uiStatus.label.toLowerCase().contains(_query);
    }).toList();
  }

  Future<void> _selectClient(_ClientViewData client) async {
    if (client.uiStatus == _ClientUiStatus.inactive) {
      await _showInactiveClientSheet(context);
      return;
    }

    var selected = client;
    if (client.uiStatus == _ClientUiStatus.prospect) {
      final navigator = Navigator.of(context);
      final shouldConvert = await _showMobileOrderSheet<bool>(
        context: context,
        child: _ProspectConversionSheet(
          onCancel: () => navigator.pop(false),
          onConvert: () => navigator.pop(true),
        ),
      );
      if (shouldConvert != true) return;
      final convertedClient = client.client.copyWith(
        status: ClientStatus.visited,
      );
      _convertedOrderClientIds.add(client.client.id);
      _clientDataRevision.value++;
      selected = _ClientViewData.fromClient(convertedClient);
      setState(() => _convertedClientIds.add(client.client.id));
      if (!mounted) return;
      await _showConvertedClientSheet(context);
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => NouvelleCommande(
          client: selected.client,
          selectedClientData: selected,
          currentEmail: widget.currentEmail,
          currentUserName: widget.currentUserName,
        ),
        settings: RouteSettings(arguments: {'clientId': selected.client.id}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clients = _clients;

    return Scaffold(
      backgroundColor: _HomeCommercialState.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final phoneWidth = constraints.maxWidth > 428
                ? 428.0
                : constraints.maxWidth;

            return Center(
              child: SizedBox(
                width: phoneWidth,
                height: constraints.maxHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF18315E).withValues(alpha: .08),
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: CustomScrollView(
                      physics: BouncingScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(20, 20, 20, 30),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              _NewOrderHeader(
                                onBack: () => Navigator.pop(context),
                                onHistory: () {},
                                subtitle: AppLocalizations.globalText(
                                  'S\u00E9lectionnez un client pour commencer',
                                ),
                              ),
                              SizedBox(height: 20),
                              TextField(
                                controller: _searchController,
                                textInputAction: TextInputAction.search,
                                decoration: InputDecoration(
                                  hintText: AppLocalizations.globalText(
                                    'Rechercher un client...',
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    size: 24,
                                  ),
                                  filled: true,
                                  fillColor: _HomeCommercialState.cardBg,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  enabledBorder: _searchBorder(),
                                  focusedBorder: _searchBorder(
                                    color: _DashboardTab._blue,
                                  ),
                                ),
                              ),
                              SizedBox(height: 18),
                              if (clients.isEmpty)
                                _EmptyClients()
                              else
                                for (final client in clients) ...[
                                  _ClientCard(
                                    data: client,
                                    onTap: () => _selectClient(client),
                                  ),
                                  SizedBox(height: 12),
                                ],
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

Future<T?> _showMobileOrderSheet<T>({
  required BuildContext context,
  required Widget child,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .48),
    builder: (context) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(context),
        child: Padding(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {},
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 430),
                child: child,
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<void> _showInactiveClientSheet(BuildContext context) {
  return _showMobileOrderSheet<void>(
    context: context,
    child: _InactiveClientSheet(onClose: () => Navigator.pop(context)),
  );
}

Future<void> _showConvertedClientSheet(BuildContext context) {
  return _showMobileOrderSheet<void>(
    context: context,
    child: _OrderInfoSheet(
      icon: Icons.check_circle_rounded,
      iconColor: Color(0xFF22C55E),
      title: 'Client converti',
      message:
          'Le prospect a été converti en client actif avec succès. Vous pouvez maintenant créer une commande.',
      buttonLabel: 'Continuer',
      onPressed: () => Navigator.pop(context),
    ),
  );
}

class _ProspectConversionSheet extends StatelessWidget {
  _ProspectConversionSheet({required this.onCancel, required this.onConvert});

  final VoidCallback onCancel;
  final VoidCallback onConvert;

  @override
  Widget build(BuildContext context) {
    return _OrderDecisionSheetShell(
      icon: Icons.person_add_disabled_rounded,
      iconColor: _DashboardTab._blue,
      title: 'Client prospect',
      message:
          'Ce client est encore un prospect. Vous devez le convertir en client actif avant de créer une commande.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cancelButton = _OrderSheetOutlinedButton(
            label: 'Annuler',
            onPressed: onCancel,
          );
          final convertButton = _OrderSheetPrimaryButton(
            label: 'Convertir en client',
            onPressed: onConvert,
          );

          if (constraints.maxWidth < 340) {
            return Column(
              children: [
                SizedBox(width: double.infinity, child: cancelButton),
                SizedBox(height: 10),
                SizedBox(width: double.infinity, child: convertButton),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: cancelButton),
              SizedBox(width: 12),
              Expanded(child: convertButton),
            ],
          );
        },
      ),
    );
  }
}

class _InactiveClientSheet extends StatelessWidget {
  _InactiveClientSheet({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return _OrderDecisionSheetShell(
      icon: Icons.person_off_rounded,
      iconColor: Color(0xFFF59E0B),
      title: 'Client inactif',
      message:
          'Ce client est actuellement inactif. Vous ne pouvez pas créer de commande pour ce client.',
      child: SizedBox(
        width: double.infinity,
        child: _OrderSheetPrimaryButton(label: 'Compris', onPressed: onClose),
      ),
    );
  }
}

class _OrderInfoSheet extends StatelessWidget {
  _OrderInfoSheet({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _OrderDecisionSheetShell(
      icon: icon,
      iconColor: iconColor,
      title: title,
      message: message,
      child: SizedBox(
        width: double.infinity,
        child: _OrderSheetPrimaryButton(
          label: buttonLabel,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _OrderDecisionSheetShell extends StatelessWidget {
  _OrderDecisionSheetShell({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0F172A).withValues(alpha: .16),
            blurRadius: 28,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 27),
            ),
            SizedBox(height: 16),
            Text(
              AppLocalizations.globalText(title),
              style: TextStyle(
                color: _DashboardTab._navy,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 10),
            Text(
              AppLocalizations.globalText(message),
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
            SizedBox(height: 22),
            child,
          ],
        ),
      ),
    );
  }
}

class _OrderSheetOutlinedButton extends StatelessWidget {
  _OrderSheetOutlinedButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _DashboardTab._blue,
        backgroundColor: Colors.white,
        side: BorderSide(color: _DashboardTab._blue, width: 1.3),
        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        AppLocalizations.globalText(label),
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _OrderSheetPrimaryButton extends StatelessWidget {
  _OrderSheetPrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: _DashboardTab._blue,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        AppLocalizations.globalText(label),
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class OrderDraft {
  OrderDraft({
    required this.order,
    required this.quantities,
    required this.remark,
    required this.savedAt,
  });

  final ValidatedOrder order;
  final Map<int, int> quantities;
  final String remark;
  final DateTime savedAt;
}

final List<OrderDraft> _orderDrafts = [];

class NouvelleCommande extends StatefulWidget {
  NouvelleCommande({
    super.key,
    required this.client,
    required this.currentEmail,
    required this.currentUserName,
    this.selectedClientData,
    this.draft,
  });

  final CommercialClient client;
  final String currentEmail;
  final String currentUserName;
  final Object? selectedClientData;
  final OrderDraft? draft;

  @override
  State<NouvelleCommande> createState() => _NouvelleCommandeState();
}

class _NouvelleCommandeState extends State<NouvelleCommande> {
  final _searchController = TextEditingController();
  final _remarkController = TextEditingController();
  final Map<int, int> _quantities = {};
  final Map<int, ValidatedOrderItem> _draftItemsByProductId = {};
  String _query = '';
  late final DateTime _orderDate;
  late DateTime _deliveryDate;
  int _visibleProductCount = 3;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    _orderDate = draft?.order.date ?? DateTime.now();
    _deliveryDate =
        draft?.order.deliveryDate ?? _orderDate.add(Duration(days: 2));
    if (draft != null) {
      _quantities.addAll(draft.quantities);
      for (final item in draft.order.items) {
        _draftItemsByProductId[item.product.id] = item;
      }
      _remarkController.text = draft.remark;
      _visibleProductCount = MockPreSalesData.orderProducts.length;
    }
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  List<OrderProduct> get _filteredProducts {
    return MockPreSalesData.orderProducts.where((product) {
      return _query.isEmpty ||
          _productDisplayName(product).toLowerCase().contains(_query) ||
          _productCategory(product).toLowerCase().contains(_query) ||
          product.reference.toLowerCase().contains(_query);
    }).toList();
  }

  PricingResult _pricingFor(OrderProduct product, int quantity) {
    final draftItem = _draftItemsByProductId[product.id];
    if (draftItem != null && draftItem.quantity == quantity) {
      final appliedUnitPrice =
          draftItem.unitPriceApplied ??
          (quantity == 0 ? 0.0 : draftItem.lineTotal / quantity);
      final grossTotal = draftItem.grossTotal ?? draftItem.lineTotal;
      return PricingResult(
        basePrice: quantity == 0 ? appliedUnitPrice : grossTotal / quantity,
        appliedUnitPrice: appliedUnitPrice,
        tariffLabel: draftItem.tariffLabel,
        discountRate: draftItem.discountRate,
        discountAmount: draftItem.discountAmount,
        grossTotal: grossTotal,
        lineTotal: draftItem.lineTotal,
      );
    }
    return PricingService.calculateLineTotal(product, widget.client, quantity);
  }

  double get _grossSubtotal {
    return MockPreSalesData.orderProducts.fold(0, (total, product) {
      final quantity = _quantities[product.id] ?? 0;
      return total + _pricingFor(product, quantity).grossTotal;
    });
  }

  double get _discountTotal {
    return MockPreSalesData.orderProducts.fold(0, (total, product) {
      final quantity = _quantities[product.id] ?? 0;
      return total + _pricingFor(product, quantity).discountAmount;
    });
  }

  double get _subtotal => _grossSubtotal - _discountTotal;
  double get _total => _subtotal;
  int get _selectedArticles =>
      _quantities.values.where((quantity) => quantity > 0).length;
  int get _totalQuantity =>
      _quantities.values.fold(0, (total, quantity) => total + quantity);

  Future<bool> _changeQuantity(OrderProduct product, int delta) async {
    final current = _quantities[product.id] ?? 0;
    final stock = _productStock(product);
    final next = (current + delta).clamp(0, stock);
    if (delta > 0 && stock == 0) return false;
    if (delta > 0 && current >= stock) {
      await _showOrderWorkflowSheet(
        icon: Icons.inventory_2_outlined,
        iconColor: Color(0xFFF59E0B),
        title: 'Stock maximum atteint',
        message:
            'Vous ne pouvez pas ajouter plus d’unités que le stock disponible.',
        buttonLabel: 'Compris',
      );
      return false;
    }
    setState(() {
      if (next == 0) {
        _quantities.remove(product.id);
      } else {
        _quantities[product.id] = next;
      }
    });
    return true;
  }

  Future<void> _pickDeliveryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deliveryDate,
      firstDate: _orderDate,
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null) setState(() => _deliveryDate = picked);
  }

  Future<void> _openScanner() async {
    final product = await _showMobileOrderSheet<OrderProduct>(
      context: context,
      child: _ScannerSimulationSheet(
        client: widget.client,
        products: MockPreSalesData.orderProducts
            .where((product) => _productStock(product) > 0)
            .toList(),
      ),
    );
    if (product == null) return;
    final added = await _changeQuantity(product, 1);
    if (!added || !mounted) return;
    await _showOrderWorkflowSheet(
      icon: Icons.check_circle_rounded,
      iconColor: Color(0xFF22C55E),
      title: 'Produit ajouté',
      message: 'Produit ajouté à la commande',
      buttonLabel: 'Continuer',
    );
  }

  Future<void> _saveDraft() async {
    if (!_quantities.values.any((quantity) => quantity > 0)) {
      await _showOrderWorkflowSheet(
        icon: Icons.warning_amber_rounded,
        iconColor: Color(0xFFF59E0B),
        title: "Aucun produit ajouté",
        message:
            "Veuillez ajouter au moins un produit avant d\u2019enregistrer la commande en brouillon.",
        buttonLabel: "Compris",
      );
      return;
    }

    final order = _buildOrder("Brouillon");
    _orderDrafts.removeWhere(
      (draft) => draft.order.orderNumber == order.orderNumber,
    );
    _orderDrafts.add(
      OrderDraft(
        order: order,
        quantities: Map<int, int>.from(_quantities),
        remark: _remarkController.text.trim(),
        savedAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmationCommande(
          order: order,
          currentEmail: widget.currentEmail,
          currentUserName: widget.currentUserName,
        ),
        settings: RouteSettings(arguments: {"orderNumber": order.orderNumber}),
      ),
    );
  }

  void _loadMoreProducts() {
    setState(() {
      _visibleProductCount = (_visibleProductCount + 3).clamp(
        0,
        MockPreSalesData.orderProducts.length,
      );
    });
  }

  void _changeClient() {
    final user = MockPreSalesData.userByEmail(widget.currentEmail);
    final clients = MockPreSalesData.clientsForUser(user);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => NouvelleCommandeClientSelection(
          clients: clients,
          currentEmail: widget.currentEmail,
          currentUserName: widget.currentUserName,
        ),
      ),
    );
  }

  void _openDrafts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDraftsPage(
          currentEmail: widget.currentEmail,
          currentUserName: widget.currentUserName,
          initialClient: widget.client,
          selectedClientData: widget.selectedClientData,
        ),
      ),
    );
  }

  Future<void> _sendToManager() async {
    if (!_quantities.values.any((quantity) => quantity > 0)) {
      await _showOrderWorkflowSheet(
        icon: Icons.warning_amber_rounded,
        iconColor: Color(0xFFF59E0B),
        title: "Aucun produit ajouté",
        message:
            "Veuillez ajouter au moins un produit avant d\u2019envoyer la commande au manager.",
        buttonLabel: "Compris",
      );
      return;
    }

    if (_deliveryDate.isBefore(_dateOnly(_orderDate))) {
      await _showOrderWorkflowSheet(
        icon: Icons.event_busy_rounded,
        iconColor: Color(0xFFF59E0B),
        title: "Date invalide",
        message:
            "La date de livraison ne peut pas être antérieure à la date de commande.",
        buttonLabel: "Compris",
      );
      return;
    }

    final order = _buildOrder("En attente");
    final user = MockPreSalesData.userByEmail(widget.currentEmail);
    final commercialOrder = _commercialOrderFromValidated(
      order,
      commercialId: user?.id ?? 0,
    );
    _addRuntimeOrderForEmail(widget.currentEmail, commercialOrder);
    _notifyOrderAction(widget.currentEmail, commercialOrder);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmationCommande(
          order: order,
          currentEmail: widget.currentEmail,
          currentUserName: widget.currentUserName,
        ),
        settings: RouteSettings(arguments: {"orderNumber": order.orderNumber}),
      ),
    );
  }

  ValidatedOrder _buildOrder(String status) {
    final items = MockPreSalesData.orderProducts
        .where((product) => (_quantities[product.id] ?? 0) > 0)
        .map((product) {
          final quantity = _quantities[product.id] ?? 0;
          final pricing = _pricingFor(product, quantity);
          return ValidatedOrderItem(
            product: product,
            quantity: quantity,
            unitPriceApplied: pricing.appliedUnitPrice,
            tariffLabel: pricing.tariffLabel,
            discountRate: pricing.discountRate,
            discountAmount: pricing.discountAmount,
            grossTotal: pricing.grossTotal,
            lineTotal: pricing.lineTotal,
          );
        })
        .toList();

    return ValidatedOrder(
      orderNumber: _orderNumber(_orderDate),
      client: widget.client,
      date: _orderDate,
      deliveryDate: _deliveryDate,
      total: _total,
      status: status,
      items: items,
    );
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  Future<void> _showOrderWorkflowSheet({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String buttonLabel,
  }) {
    return _showMobileOrderSheet<void>(
      context: context,
      child: _OrderInfoSheet(
        icon: icon,
        iconColor: iconColor,
        title: title,
        message: message,
        buttonLabel: buttonLabel,
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  String _orderNumber(DateTime date) {
    final sequence = (date.millisecondsSinceEpoch % 10000).toString();
    return 'CMD-${date.year}-${sequence.padLeft(4, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts.take(_visibleProductCount).toList();
    final canLoadMore = _filteredProducts.length > products.length;
    final selectedClientData = widget.selectedClientData is _ClientViewData
        ? widget.selectedClientData as _ClientViewData
        : _ClientViewData.fromClient(widget.client);

    return Scaffold(
      backgroundColor: _HomeCommercialState.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final phoneWidth = constraints.maxWidth > 428
                ? 428.0
                : constraints.maxWidth;

            return Center(
              child: SizedBox(
                width: phoneWidth,
                height: constraints.maxHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF18315E).withValues(alpha: .08),
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Column(
                      children: [
                        Expanded(
                          child: CustomScrollView(
                            physics: BouncingScrollPhysics(),
                            slivers: [
                              SliverPadding(
                                padding: EdgeInsets.fromLTRB(20, 20, 20, 20),
                                sliver: SliverList(
                                  delegate: SliverChildListDelegate([
                                    _NewOrderHeader(
                                      onBack: () => Navigator.pop(context),
                                      onHistory: _openDrafts,
                                    ),
                                    SizedBox(height: 20),
                                    _SelectedOrderClientCard(
                                      data: selectedClientData,
                                      onTap: _changeClient,
                                    ),
                                    SizedBox(height: 16),
                                    _OrderInfoCard(
                                      orderDate: _orderDate,
                                      deliveryDate: _deliveryDate,
                                      remarkController: _remarkController,
                                      onPickDeliveryDate: _pickDeliveryDate,
                                    ),
                                    SizedBox(height: 16),
                                    _SectionCard(
                                      title: AppLocalizations.globalText(
                                        'Ajouter des produits',
                                      ),
                                      icon: Icons.inventory_2_outlined,
                                      child: Column(
                                        children: [
                                          _ProductSearchBar(
                                            controller: _searchController,
                                            onScan: _openScanner,
                                          ),
                                          SizedBox(height: 14),
                                          if (products.isEmpty)
                                            _EmptyDetailMessage(
                                              text: 'Aucun produit trouv\u00E9',
                                            )
                                          else
                                            for (
                                              var i = 0;
                                              i < products.length;
                                              i++
                                            )
                                              _OrderProductTile(
                                                product: products[i],
                                                client: widget.client,
                                                quantity:
                                                    _quantities[products[i]
                                                        .id] ??
                                                    0,
                                                isLast:
                                                    i == products.length - 1,
                                                onMinus: () => _changeQuantity(
                                                  products[i],
                                                  -1,
                                                ),
                                                onPlus: () => _changeQuantity(
                                                  products[i],
                                                  1,
                                                ),
                                              ),
                                          if (canLoadMore) ...[
                                            SizedBox(height: 10),
                                            TextButton.icon(
                                              onPressed: _loadMoreProducts,
                                              label: Text(
                                                AppLocalizations.globalText(
                                                  'Voir plus de produits',
                                                ),
                                              ),
                                              icon: Icon(
                                                Icons
                                                    .keyboard_arrow_down_rounded,
                                              ),
                                              iconAlignment: IconAlignment.end,
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    _DashboardTab._blue,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    _SectionCard(
                                      title: AppLocalizations.globalText(
                                        'R\u00E9sum\u00E9 de la commande',
                                      ),
                                      icon: Icons.assignment_turned_in_outlined,
                                      child: _OrderTotals(
                                        articles: _selectedArticles,
                                        quantity: _totalQuantity,
                                        grossSubtotal: _grossSubtotal,
                                        discountTotal: _discountTotal,
                                        subtotal: _subtotal,
                                        total: _total,
                                      ),
                                    ),
                                  ]),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
                          child: _NewOrderActions(
                            onDraft: _saveDraft,
                            onSend: _sendToManager,
                          ),
                        ),
                        _CommercialBottomNav(
                          selectedIndex: 2,
                          onChanged: (index) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HomeCommercial(),
                                settings: RouteSettings(
                                  arguments: {
                                    'email': widget.currentEmail,
                                    'name': widget.currentUserName,
                                    'initialIndex': index,
                                  },
                                ),
                              ),
                              (route) => false,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class OrderDraftsPage extends StatefulWidget {
  OrderDraftsPage({
    super.key,
    required this.currentEmail,
    required this.currentUserName,
    required this.initialClient,
    this.selectedClientData,
  });

  final String currentEmail;
  final String currentUserName;
  final CommercialClient initialClient;
  final Object? selectedClientData;

  @override
  State<OrderDraftsPage> createState() => _OrderDraftsPageState();
}

class _OrderDraftsPageState extends State<OrderDraftsPage> {
  List<OrderDraft> get _drafts {
    return [..._orderDrafts]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  void _openDraft(OrderDraft draft) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => NouvelleCommande(
          client: draft.order.client,
          currentEmail: widget.currentEmail,
          currentUserName: widget.currentUserName,
          selectedClientData: _ClientViewData.fromClient(draft.order.client),
          draft: draft,
        ),
      ),
    );
  }

  void _deleteDraft(OrderDraft draft) {
    setState(() {
      _orderDrafts.remove(draft);
    });
  }

  void _sendDraft(OrderDraft draft) {
    _orderDrafts.remove(draft);
    final order = _copyDraftOrderWithStatus(draft, 'En attente');
    final user = MockPreSalesData.userByEmail(widget.currentEmail);
    final commercialOrder = _commercialOrderFromValidated(
      order,
      commercialId: user?.id ?? 0,
    );
    _addRuntimeOrderForEmail(widget.currentEmail, commercialOrder);
    _notifyOrderAction(widget.currentEmail, commercialOrder);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmationCommande(
          order: order,
          currentEmail: widget.currentEmail,
          currentUserName: widget.currentUserName,
        ),
        settings: RouteSettings(arguments: {'orderNumber': order.orderNumber}),
      ),
    );
  }

  void _createOrder() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final drafts = _drafts;
    return Scaffold(
      backgroundColor: _HomeCommercialState.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final phoneWidth = constraints.maxWidth > 428
                ? 428.0
                : constraints.maxWidth;
            return Center(
              child: SizedBox(
                width: phoneWidth,
                height: constraints.maxHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF18315E).withValues(alpha: .08),
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Column(
                      children: [
                        Expanded(
                          child: CustomScrollView(
                            physics: BouncingScrollPhysics(),
                            slivers: [
                              SliverPadding(
                                padding: EdgeInsets.fromLTRB(20, 20, 20, 24),
                                sliver: SliverList(
                                  delegate: SliverChildListDelegate([
                                    _DraftsHeader(
                                      onBack: () => Navigator.pop(context),
                                    ),
                                    SizedBox(height: 20),
                                    if (drafts.isEmpty)
                                      _EmptyDraftsCard(onCreate: _createOrder)
                                    else
                                      for (final draft in drafts) ...[
                                        _OrderDraftCard(
                                          draft: draft,
                                          onOpen: () => _openDraft(draft),
                                          onEdit: () => _openDraft(draft),
                                          onDelete: () => _deleteDraft(draft),
                                          onSend: () => _sendDraft(draft),
                                        ),
                                        SizedBox(height: 12),
                                      ],
                                  ]),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _CommercialBottomNav(
                          selectedIndex: 2,
                          onChanged: (index) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HomeCommercial(),
                                settings: RouteSettings(
                                  arguments: {
                                    'email': widget.currentEmail,
                                    'name': widget.currentUserName,
                                    'initialIndex': index,
                                  },
                                ),
                              ),
                              (route) => false,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

ValidatedOrder _copyDraftOrderWithStatus(OrderDraft draft, String status) {
  final order = draft.order;
  return ValidatedOrder(
    orderNumber: order.orderNumber,
    client: order.client,
    date: order.date,
    deliveryDate: order.deliveryDate,
    total: order.total,
    status: status,
    items: order.items,
  );
}

class _DraftsHeader extends StatelessWidget {
  _DraftsHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: onBack,
          icon: Icon(Icons.arrow_back_rounded),
          color: _DashboardTab._navy,
          style: IconButton.styleFrom(
            backgroundColor: _HomeCommercialState.cardBg,
            shadowColor: Color(0xFF0F172A).withValues(alpha: .08),
            elevation: 5,
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 4),
              Text(
                AppLocalizations.globalText('Mes brouillons'),
                style: TextStyle(
                  color: _DashboardTab._navy,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 5),
              Text(
                AppLocalizations.globalText(
                  'Commandes enregistrées à finaliser',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyDraftsCard extends StatelessWidget {
  _EmptyDraftsCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22, 30, 22, 24),
      decoration: _premiumCardDecoration(22),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _DashboardTab._blue.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.description_outlined,
              color: _DashboardTab._blue,
              size: 34,
            ),
          ),
          SizedBox(height: 18),
          Text(
            AppLocalizations.globalText('Aucun brouillon'),
            style: TextStyle(
              color: _DashboardTab._navy,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            AppLocalizations.globalText(
              "Vous n'avez actuellement aucune commande enregistrée en brouillon.",
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onCreate,
              icon: Icon(Icons.add_rounded),
              label: Text(AppLocalizations.globalText('Créer une commande')),
              style: ElevatedButton.styleFrom(
                backgroundColor: _DashboardTab._blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderDraftCard extends StatelessWidget {
  _OrderDraftCard({
    required this.draft,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onSend,
  });

  final OrderDraft draft;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final order = draft.order;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: _premiumCardDecoration(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _DashboardTab._blue.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      color: _DashboardTab._blue,
                    ),
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
                            color: _DashboardTab._navy,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          order.client.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                ],
              ),
              SizedBox(height: 14),
              _DraftInfoLine(
                icon: Icons.calendar_today_outlined,
                label: 'Date de création',
                value: _dateTime(order.date),
              ),
              _DraftInfoLine(
                icon: Icons.inventory_2_outlined,
                label: 'Articles',
                value: '${order.items.length}',
              ),
              _DraftInfoLine(
                icon: Icons.payments_outlined,
                label: 'Montant total',
                value: _mad(order.total),
              ),
              SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DraftActionButton(
                    label: 'Reprendre',
                    icon: Icons.play_arrow_rounded,
                    onTap: onOpen,
                  ),
                  _DraftActionButton(
                    label: 'Modifier',
                    icon: Icons.edit_outlined,
                    onTap: onEdit,
                  ),
                  _DraftActionButton(
                    label: 'Supprimer',
                    icon: Icons.delete_outline_rounded,
                    destructive: true,
                    onTap: onDelete,
                  ),
                  _DraftActionButton(
                    label: 'Envoyer',
                    icon: Icons.send_rounded,
                    filled: true,
                    onTap: onSend,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DraftInfoLine extends StatelessWidget {
  _DraftInfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Color(0xFF64748B), size: 17),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              AppLocalizations.globalText(label),
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: _DashboardTab._navy,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftActionButton extends StatelessWidget {
  _DraftActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Color(0xFFEF4444) : _DashboardTab._blue;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: filled ? _DashboardTab._blue : color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
          border: filled
              ? null
              : Border.all(color: color.withValues(alpha: .2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: filled ? Colors.white : color),
            SizedBox(width: 5),
            Text(
              AppLocalizations.globalText(label),
              style: TextStyle(
                color: filled ? Colors.white : color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewOrderHeader extends StatelessWidget {
  _NewOrderHeader({
    required this.onBack,
    required this.onHistory,
    this.subtitle = 'Cr\u00E9ez une nouvelle commande pour votre client',
  });

  final VoidCallback onBack;
  final VoidCallback onHistory;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: onBack,
          icon: Icon(Icons.arrow_back_rounded),
          color: _DashboardTab._navy,
          style: IconButton.styleFrom(
            backgroundColor: _HomeCommercialState.cardBg,
            shadowColor: Color(0xFF0F172A).withValues(alpha: .08),
            elevation: 5,
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 4),
              Text(
                AppLocalizations.globalText('Nouvelle commande'),
                style: TextStyle(
                  color: _DashboardTab._navy,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 5),
              Text(
                AppLocalizations.globalText(subtitle),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 12),
        IconButton(
          onPressed: onHistory,
          icon: Icon(Icons.description_outlined),
          color: _DashboardTab._navy,
          style: IconButton.styleFrom(
            backgroundColor: _HomeCommercialState.cardBg,
            shadowColor: Color(0xFF0F172A).withValues(alpha: .08),
            elevation: 5,
          ),
        ),
      ],
    );
  }
}

class _SelectedOrderClientCard extends StatelessWidget {
  _SelectedOrderClientCard({required this.data, required this.onTap});

  final _ClientViewData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: EdgeInsets.fromLTRB(14, 15, 12, 15),
          decoration: _premiumCardDecoration(20),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: data.logoColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(data.logoIcon, color: data.logoColor, size: 34),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.globalText('Client'),
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _DashboardTab._navy,
                              fontSize: 18,
                              height: 1.1,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        _ClientStatusBadge(status: data.uiStatus),
                      ],
                    ),
                    SizedBox(height: 9),
                    Text(
                      AppLocalizations.globalText(data.type),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                        SizedBox(width: 4),
                        Text(
                          data.client.city,
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${data.orderCount} ${AppLocalizations.globalText(data.orderCount > 1 ? 'commandes' : 'commande')}',
                    style: TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${_money(data.revenue)} DH',
                    style: TextStyle(
                      color: _DashboardTab._navy,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    AppLocalizations.globalText('CA total'),
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  TextButton(
                    onPressed: onTap,
                    style: TextButton.styleFrom(
                      foregroundColor: _DashboardTab._blue,
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      AppLocalizations.globalText('Changer client'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B)),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderInfoCard extends StatelessWidget {
  _OrderInfoCard({
    required this.orderDate,
    required this.deliveryDate,
    required this.remarkController,
    required this.onPickDeliveryDate,
  });

  final DateTime orderDate;
  final DateTime deliveryDate;
  final TextEditingController remarkController;
  final VoidCallback onPickDeliveryDate;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: AppLocalizations.globalText('Informations de commande'),
      icon: Icons.calendar_today_rounded,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: AppLocalizations.globalText('Date de commande'),
                  value: _formatOrderDate(orderDate),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _DateField(
                  label: AppLocalizations.globalText(
                    'Date de livraison souhait\u00E9e',
                  ),
                  value: _formatOrderDate(deliveryDate),
                  onTap: onPickDeliveryDate,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          TextField(
            controller: remarkController,
            minLines: 2,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: AppLocalizations.globalText('Remarque (optionnel)'),
              hintText: AppLocalizations.globalText('Ajouter une remarque...'),
              filled: true,
              fillColor: _HomeCommercialState.cardBg,
              enabledBorder: _searchBorder(),
              focusedBorder: _searchBorder(color: _DashboardTab._blue),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  _DateField({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 7),
          Container(
            height: 48,
            padding: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _DashboardTab._navy,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today_outlined,
                  color: Color(0xFF64748B),
                  size: 18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  _SectionCard({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: _premiumCardDecoration(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _DashboardTab._blue, size: 20),
              SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: _DashboardTab._navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

BoxDecoration _premiumCardDecoration(double radius) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: Color(0xFF0F172A).withValues(alpha: .055),
        blurRadius: 22,
        offset: Offset(0, 10),
      ),
    ],
  );
}

class _ProductSearchBar extends StatelessWidget {
  _ProductSearchBar({required this.controller, required this.onScan});

  final TextEditingController controller;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: AppLocalizations.globalText('Rechercher un produit...'),
              prefixIcon: Icon(Icons.search_rounded, size: 21),
              filled: true,
              fillColor: _HomeCommercialState.cardBg,
              contentPadding: EdgeInsets.symmetric(vertical: 13),
              enabledBorder: _searchBorder(),
              focusedBorder: _searchBorder(
                color: _HomeCommercialState.primaryBlue,
              ),
            ),
          ),
        ),
        SizedBox(width: 10),
        SizedBox(
          height: 46,
          child: OutlinedButton.icon(
            onPressed: onScan,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 12),
              foregroundColor: _DashboardTab._blue,
              side: BorderSide(color: Color(0xFFE3E8F2)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: Text(
              AppLocalizations.globalText('Scanner'),
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderProductTile extends StatelessWidget {
  _OrderProductTile({
    required this.product,
    required this.client,
    required this.quantity,
    required this.isLast,
    required this.onMinus,
    required this.onPlus,
  });

  final OrderProduct product;
  final CommercialClient client;
  final int quantity;
  final bool isLast;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final stock = _productStock(product);
    final outOfStock = stock == 0;
    final maxReached = stock > 0 && quantity >= stock;
    final effectiveQuantity = quantity == 0 ? 1 : quantity;
    final pricing = PricingService.calculateLineTotal(
      product,
      client,
      effectiveQuantity,
    );
    final lineTotal = quantity == 0 ? 0.0 : pricing.lineTotal;

    return Opacity(
      opacity: outOfStock ? .55 : 1,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: isLast
                ? BorderSide.none
                : BorderSide(color: Color(0xFFE8EDF5)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProductImage(product: product),
            SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _productDisplayName(product),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _HomeCommercialState.textDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '${product.reference} • ${_productCategory(product)}',
                    style: TextStyle(
                      color: _HomeCommercialState.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (product.weight.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      'Poids : ${product.weight}',
                      style: TextStyle(
                        color: _HomeCommercialState.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  SizedBox(height: 8),
                  Text(
                    'Prix appliqué : ${_dh(pricing.appliedUnitPrice)}',
                    style: TextStyle(
                      color: _DashboardTab._navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tarif : ${pricing.tariffLabel}',
                    style: TextStyle(
                      color: _DashboardTab._blue,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (pricing.discountRate > 0) ...[
                    SizedBox(height: 4),
                    Text(
                      'Remise quantité : -${(pricing.discountRate * 100).toStringAsFixed(0)} %',
                      style: TextStyle(
                        color: _DashboardTab._green,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  SizedBox(height: 4),
                  Text(
                    outOfStock
                        ? AppLocalizations.globalText('Rupture')
                        : 'Stock : $stock unités',
                    style: TextStyle(
                      color: outOfStock
                          ? _HomeCommercialState.error
                          : _HomeCommercialState.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (maxReached) ...[
                    SizedBox(height: 4),
                    Text(
                      AppLocalizations.globalText('Stock maximum atteint'),
                      style: TextStyle(
                        color: _DashboardTab._orange,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _QuantityStepper(
                  quantity: quantity,
                  canMinus: quantity > 0,
                  canPlus: !outOfStock && !maxReached,
                  onMinus: onMinus,
                  onPlus: onPlus,
                ),
                SizedBox(height: 8),
                Text(
                  'Quantité : $quantity',
                  style: TextStyle(
                    color: _HomeCommercialState.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  _dh(lineTotal),
                  style: TextStyle(
                    color: _DashboardTab._navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

class _ProductImage extends StatelessWidget {
  _ProductImage({required this.product});

  final OrderProduct product;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 64,
      decoration: BoxDecoration(
        color: product.imageColor.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: product.image.isEmpty
          ? Center(
              child: Icon(product.icon, color: product.imageColor, size: 30),
            )
          : Image.asset(
              product.image,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Icon(product.icon, color: product.imageColor, size: 30),
              ),
            ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  _QuantityStepper({
    required this.quantity,
    required this.canMinus,
    required this.canPlus,
    required this.onMinus,
    required this.onPlus,
  });

  final int quantity;
  final bool canMinus;
  final bool canPlus;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFE3E8F2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QuantityButton(
            icon: Icons.remove_rounded,
            onTap: canMinus ? onMinus : null,
          ),
          SizedBox(
            width: 34,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _HomeCommercialState.textDark,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _QuantityButton(
            icon: Icons.add_rounded,
            onTap: canPlus ? onPlus : null,
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  _QuantityButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 32,
        height: 34,
        child: Icon(
          icon,
          size: 17,
          color: onTap == null
              ? _HomeCommercialState.textMuted.withValues(alpha: .45)
              : _HomeCommercialState.primaryBlue,
        ),
      ),
    );
  }
}

class _ScannerSimulationSheet extends StatelessWidget {
  _ScannerSimulationSheet({required this.client, required this.products});

  final CommercialClient client;
  final List<OrderProduct> products;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0F172A).withValues(alpha: .16),
            blurRadius: 28,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.globalText(
                  'Simulation de scan de code-barres',
                ),
                style: TextStyle(
                  color: _DashboardTab._navy,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                AppLocalizations.globalText(
                  'Sélectionnez un produit pour simuler un scan.',
                ),
                style: TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                AppLocalizations.globalText(
                  "Cette fonctionnalité simule le comportement d'un lecteur de code-barres avant l'intégration du scan réel.",
                ),
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: BouncingScrollPhysics(),
                  itemCount: products.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 16, color: Color(0xFFE8EEF7)),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _ScannerProductRow(client: client, product: product);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerProductRow extends StatelessWidget {
  _ScannerProductRow({required this.client, required this.product});

  final CommercialClient client;
  final OrderProduct product;

  @override
  Widget build(BuildContext context) {
    final stock = _productStock(product);
    final pricing = PricingService.calculateLineTotal(product, client, 1);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pop(context, product),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              _ProductImage(product: product),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _productDisplayName(product),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _DashboardTab._navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _productCategory(product),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 7),
                    Row(
                      children: [
                        Text(
                          _dh(pricing.appliedUnitPrice),
                          style: TextStyle(
                            color: _DashboardTab._navy,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Tarif : ${pricing.tariffLabel}',
                          style: TextStyle(
                            color: _DashboardTab._blue,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Stock : $stock',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _DashboardTab._blue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.add_rounded, color: Colors.white, size: 23),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderTotals extends StatelessWidget {
  _OrderTotals({
    required this.articles,
    required this.quantity,
    required this.grossSubtotal,
    required this.discountTotal,
    required this.subtotal,
    required this.total,
  });

  final int articles;
  final int quantity;
  final double grossSubtotal;
  final double discountTotal;
  final double subtotal;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _TotalRow(
            label: AppLocalizations.globalText("Nombre d'articles"),
            value: '$articles articles',
          ),
          SizedBox(height: 13),
          _TotalRow(
            label: AppLocalizations.globalText('Total quantit\u00E9'),
            value: '$quantity unit\u00E9s',
          ),
          SizedBox(height: 13),
          _TotalRow(
            label: AppLocalizations.globalText('Sous-total brut'),
            value: _dh(grossSubtotal),
          ),
          SizedBox(height: 13),
          _TotalRow(
            label: AppLocalizations.globalText('Remise quantité'),
            value: discountTotal > 0 ? '-${_dh(discountTotal)}' : _dh(0),
          ),
          if (discountTotal > 0) ...[
            SizedBox(height: 13),
            _TotalRow(
              label: AppLocalizations.globalText('Économie réalisée'),
              value: _dh(discountTotal),
            ),
          ],
          SizedBox(height: 13),
          _TotalRow(
            label: AppLocalizations.globalText('Sous-total net'),
            value: _dh(subtotal),
          ),
          SizedBox(height: 15),
          Divider(color: Color(0xFFE2E8F0)),
          SizedBox(height: 12),
          _TotalRow(
            label: AppLocalizations.globalText('Total TTC'),
            value: _dh(total),
            large: true,
          ),
        ],
      ),
    );
  }
}

class _NewOrderActions extends StatelessWidget {
  _NewOrderActions({required this.onDraft, required this.onSend});

  final VoidCallback onDraft;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 54,
            child: OutlinedButton.icon(
              onPressed: onDraft,
              icon: Icon(Icons.description_outlined),
              label: Text(AppLocalizations.globalText('Enregistrer brouillon')),
              style: OutlinedButton.styleFrom(
                foregroundColor: _DashboardTab._blue,
                side: BorderSide(color: _DashboardTab._blue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                textStyle: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: onSend,
              icon: Icon(Icons.send_outlined),
              label: Text(AppLocalizations.globalText('Envoyer au manager')),
              style: ElevatedButton.styleFrom(
                backgroundColor: _DashboardTab._blue,
                foregroundColor: Colors.white,
                elevation: 10,
                shadowColor: _DashboardTab._blue.withValues(alpha: .25),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                textStyle: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  _TotalRow({required this.label, required this.value, this.large = false});

  final String label;
  final String value;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: large ? _DashboardTab._navy : _HomeCommercialState.textMuted,
            fontSize: large ? 16 : 12,
            fontWeight: large ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Spacer(),
        Text(
          value,
          style: TextStyle(
            color: large ? _DashboardTab._blue : _DashboardTab._navy,
            fontSize: large ? 22 : 12,
            fontWeight: large ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

String _mad(num value) =>
    '${value.toStringAsFixed(2).replaceAll('.', ',')} MAD';
String _dh(num value) => '${value.toStringAsFixed(2).replaceAll('.', ',')} DH';

String _formatOrderDate(DateTime date) {
  final months = [
    'janvier',
    'f\u00E9vrier',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'ao\u00FBt',
    'septembre',
    'octobre',
    'novembre',
    'd\u00E9cembre',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _productDisplayName(OrderProduct product) {
  return product.name;
}

String _productCategory(OrderProduct product) {
  return product.category;
}

int _productStock(OrderProduct product) {
  return product.stock;
}

class ConfirmationCommande extends StatelessWidget {
  ConfirmationCommande({
    super.key,
    required this.order,
    required this.currentEmail,
    required this.currentUserName,
  });

  final ValidatedOrder? order;
  final String currentEmail;
  final String currentUserName;

  void _goToHome(BuildContext context, int initialIndex) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => HomeCommercial(),
        settings: RouteSettings(
          arguments: {
            'email': currentEmail,
            'name': currentUserName,
            'initialIndex': initialIndex,
          },
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentOrder = order;

    return Scaffold(
      backgroundColor: _HomeCommercialState.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final phoneWidth = constraints.maxWidth > 390
                ? 390.0
                : constraints.maxWidth;

            return SizedBox(
              width: double.infinity,
              height: constraints.maxHeight,
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                padding: EdgeInsets.all(14),
                child: Center(
                  child: SizedBox(
                    width: phoneWidth,
                    child: currentOrder == null
                        ? _MissingOrderCard(onHome: () => _goToHome(context, 0))
                        : _ConfirmationCard(
                            order: currentOrder,
                            onOrders: () => _goToHome(context, 2),
                            onHome: () => _goToHome(context, 0),
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ConfirmationCard extends StatelessWidget {
  _ConfirmationCard({
    required this.order,
    required this.onOrders,
    required this.onHome,
  });

  final ValidatedOrder order;
  final VoidCallback onOrders;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(20, 34, 20, 26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF18315E).withValues(alpha: .08),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SuccessBadge(),
            SizedBox(height: 22),
            Text(
              AppLocalizations.globalText(
                order.status == 'Brouillon'
                    ? 'Commande enregistrée en brouillon'
                    : order.status == 'En attente'
                    ? 'Commande envoyée au manager'
                    : 'Commande créée avec succès !',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _HomeCommercialState.textDark,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'N\u00B0 ${order.orderNumber}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _HomeCommercialState.textMuted,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 28),
            Divider(color: Color(0xFFE8EDF5)),
            SizedBox(height: 8),
            _ConfirmationInfoRow(
              label: AppLocalizations.globalText('Client'),
              value: order.client.name,
            ),
            _ConfirmationInfoRow(
              label: AppLocalizations.globalText('Date'),
              value: _dateTime(order.date),
            ),
            _ConfirmationInfoRow(
              label: AppLocalizations.globalText('Montant total'),
              value: _mad(order.total),
            ),
            _ConfirmationInfoRow(
              label: AppLocalizations.globalText('Statut'),
              value: order.status,
            ),
            SizedBox(height: 8),
            Divider(color: Color(0xFFE8EDF5)),
            SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onOrders,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _HomeCommercialState.primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shadowColor: _HomeCommercialState.primaryBlue.withValues(
                    alpha: .24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  AppLocalizations.globalText('Voir les commandes'),
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: onHome,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _HomeCommercialState.textDark,
                  side: BorderSide(color: Color(0xFFD7DEE9)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  AppLocalizations.globalText("Retour \u00E0 l'accueil"),
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessBadge extends StatelessWidget {
  _SuccessBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      height: 118,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _ConfettiDot(left: 12, top: 16, color: Color(0xFF2674F8)),
          _ConfettiDot(left: 38, top: 0, color: Color(0xFFFF2FA0)),
          _ConfettiDot(right: 16, top: 12, color: Color(0xFF2674F8)),
          _ConfettiDot(right: 2, top: 48, color: Color(0xFFFFC24B)),
          _ConfettiDot(left: 4, bottom: 34, color: Color(0xFFFF8A1F)),
          _ConfettiDot(right: 34, bottom: 24, color: Color(0xFFFF2FA0)),
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF31D98C), Color(0xFF16BF70)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF20C47B).withValues(alpha: .26),
                  blurRadius: 22,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Icon(Icons.check_rounded, color: Colors.white, size: 58),
          ),
        ],
      ),
    );
  }
}

class _ConfettiDot extends StatelessWidget {
  _ConfettiDot({
    this.left,
    this.top,
    this.right,
    this.bottom,
    required this.color,
  });

  final double? left;
  final double? top;
  final double? right;
  final double? bottom;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      child: Transform.rotate(
        angle: .65,
        child: Container(
          width: 5,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class _ConfirmationInfoRow extends StatelessWidget {
  _ConfirmationInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: _HomeCommercialState.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: TextStyle(
                color: _HomeCommercialState.textDark,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingOrderCard extends StatelessWidget {
  _MissingOrderCard({required this.onHome});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF18315E).withValues(alpha: .08),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              color: _HomeCommercialState.textMuted,
              size: 54,
            ),
            SizedBox(height: 16),
            Text(
              AppLocalizations.globalText('Aucune commande trouv\u00E9e'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _HomeCommercialState.textDark,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 22),
            ElevatedButton(
              onPressed: onHome,
              child: Text(
                AppLocalizations.globalText("Retour \u00E0 l'accueil"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _dateTime(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} '
      '${two(date.hour)}:${two(date.minute)}';
}

String _dateOnlyLabel(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}

CommercialOrder _commercialOrderFromValidated(
  ValidatedOrder order, {
  required int commercialId,
}) {
  return CommercialOrder(
    commercialId: commercialId,
    id: order.orderNumber.hashCode.abs(),
    orderNumber: order.orderNumber,
    clientName: order.client.name,
    date: _dateOnlyLabel(order.date),
    productsCount: order.items.fold<int>(
      0,
      (total, item) => total + item.quantity,
    ),
    total: order.total,
    status: order.status == 'En attente'
        ? OrderStatus.pending
        : order.status == 'Brouillon'
        ? OrderStatus.pending
        : OrderStatus.synced,
    items: [
      for (final item in order.items)
        OrderLine(
          productName: item.product.name,
          quantity: item.quantity,
          total: item.lineTotal,
        ),
    ],
  );
}

// ignore: unused_element
class _LegacyNouvelleCommande extends StatelessWidget {
  _LegacyNouvelleCommande({required this.client});

  final CommercialClient client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _HomeCommercialState.surface,
      appBar: AppBar(
        backgroundColor: _HomeCommercialState.cardBg,
        elevation: 0,
        foregroundColor: _HomeCommercialState.textDark,
        title: Text(AppLocalizations.globalText('Nouvelle commande')),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nouvelle commande pour ${client.name}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _HomeCommercialState.textDark,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientNotFound extends StatelessWidget {
  _ClientNotFound({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_search_rounded,
              size: 54,
              color: _HomeCommercialState.textMuted,
            ),
            SizedBox(height: 16),
            Text(
              AppLocalizations.globalText('Client introuvable'),
              style: TextStyle(
                color: _HomeCommercialState.textDark,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 18),
            ElevatedButton(
              onPressed: onBack,
              child: Text(AppLocalizations.globalText('Retour aux clients')),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailTopBar extends StatelessWidget {
  _DetailTopBar({required this.onBack, required this.onOptionSelected});

  final VoidCallback onBack;
  final ValueChanged<String> onOptionSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: Icon(Icons.arrow_back_rounded),
          color: _HomeCommercialState.textDark,
        ),
        Spacer(),
        PopupMenuButton<String>(
          onSelected: onOptionSelected,
          color: Colors.white,
          elevation: 12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Text(AppLocalizations.globalText('Modifier client')),
            ),
            PopupMenuItem(
              value: 'note',
              child: Text(AppLocalizations.globalText('Ajouter note')),
            ),
            PopupMenuItem(
              value: 'location',
              child: Text(AppLocalizations.globalText('Voir localisation')),
            ),
          ],
          child: Padding(
            padding: EdgeInsets.all(10),
            child: Icon(
              Icons.more_horiz_rounded,
              color: _HomeCommercialState.textDark,
            ),
          ),
        ),
      ],
    );
  }
}

class _ClientIdentity extends StatelessWidget {
  _ClientIdentity({required this.client});

  final CommercialClient client;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 27,
          backgroundColor: _HomeCommercialState.primaryBlue,
          child: Text(
            client.initials,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                client.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _HomeCommercialState.textDark,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                _clientTypeLabel(client),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _HomeCommercialState.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2),
              Text(
                client.city,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _HomeCommercialState.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClientSummaryCard extends StatelessWidget {
  _ClientSummaryCard({required this.client});

  final CommercialClient client;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Color(0xFFE8EDF5)),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF18315E).withValues(alpha: .05),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          _SummaryItem(
            label: AppLocalizations.globalText('Encours'),
            value: client.balance <= 0
                ? 'À jour'
                : '${_money(client.balance)} MAD',
          ),
          _SummaryDivider(),
          _SummaryItem(
            label: AppLocalizations.globalText('Derni\u00E8re commande'),
            value: client.lastOrderDate,
          ),
          _SummaryDivider(),
          _SummaryItem(
            label: AppLocalizations.globalText('Risque'),
            value: client.risk.label,
            valueColor: _riskColor(client.risk),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  _SummaryItem({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _HomeCommercialState.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: valueColor ?? _HomeCommercialState.textDark,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 42, color: Color(0xFFE8EDF5));
  }
}

class _DetailTabs extends StatelessWidget {
  _DetailTabs({required this.selectedIndex, required this.onChanged});

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static final _labels = ['Informations', 'Historique', 'Documents'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == _labels.length - 1 ? 0 : 8),
              child: InkWell(
                onTap: () => onChanged(i),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 180),
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selectedIndex == i
                        ? _HomeCommercialState.primaryBlue
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selectedIndex == i
                          ? _HomeCommercialState.primaryBlue
                          : Color(0xFFE8EDF5),
                    ),
                    boxShadow: selectedIndex == i
                        ? [
                            BoxShadow(
                              color: _HomeCommercialState.primaryBlue
                                  .withValues(alpha: .18),
                              blurRadius: 12,
                              offset: Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    _labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selectedIndex == i
                          ? Colors.white
                          : _HomeCommercialState.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DetailTabContent extends StatelessWidget {
  _DetailTabContent({
    super.key,
    required this.selectedIndex,
    required this.client,
    required this.orders,
    required this.notes,
    required this.onCall,
    required this.onEmail,
    required this.onMaps,
  });

  final int selectedIndex;
  final CommercialClient client;
  final List<CommercialOrder> orders;
  final List<_ClientNote> notes;
  final VoidCallback onCall;
  final VoidCallback onEmail;
  final VoidCallback onMaps;

  @override
  Widget build(BuildContext context) {
    if (selectedIndex == 1) return _HistoryCard(orders: orders, notes: notes);
    if (selectedIndex == 2)
      return _DocumentsCard(client: client, orders: orders);
    return _InformationCard(
      client: client,
      onCall: onCall,
      onEmail: onEmail,
      onMaps: onMaps,
    );
  }
}

class _InformationCard extends StatelessWidget {
  _InformationCard({
    required this.client,
    required this.onCall,
    required this.onEmail,
    required this.onMaps,
  });

  final CommercialClient client;
  final VoidCallback onCall;
  final VoidCallback onEmail;
  final VoidCallback onMaps;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      child: Column(
        children: [
          _InfoActionRow(
            icon: Icons.phone_outlined,
            label: AppLocalizations.globalText('T\u00E9l\u00E9phone'),
            value: client.phone,
            actionIcon: Icons.phone_rounded,
            onAction: onCall,
          ),
          _InfoActionRow(
            icon: Icons.mail_outline_rounded,
            label: AppLocalizations.globalText('Email'),
            value: client.email,
            actionIcon: Icons.mail_rounded,
            onAction: onEmail,
          ),
          _InfoActionRow(
            icon: Icons.location_on_outlined,
            label: AppLocalizations.globalText('Adresse'),
            value: client.address,
            actionIcon: Icons.place_rounded,
            onAction: onMaps,
          ),
          _InfoValueRow(
            icon: Icons.credit_card_rounded,
            label: AppLocalizations.globalText('Limite de cr\u00E9dit'),
            value: client.creditLimit <= 0
                ? 'Aucune limite définie'
                : '${_money(client.creditLimit)} MAD',
          ),
          _InfoValueRow(
            icon: Icons.percent_rounded,
            label: AppLocalizations.globalText('Tarification'),
            value: 'Selon grille tarifaire',
          ),
          _InfoValueRow(
            icon: Icons.account_balance_wallet_outlined,
            label: AppLocalizations.globalText('Solde'),
            value: client.balance <= 0
                ? 'Aucun encours'
                : '${_money(client.balance)} MAD',
            valueColor: client.balance > 0
                ? Color(0xFFFF4D4D)
                : _HomeCommercialState.textDark,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _InfoActionRow extends StatelessWidget {
  _InfoActionRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.actionIcon,
    required this.onAction,
  });

  final IconData icon;
  final String label;
  final String value;
  final IconData actionIcon;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return _InfoRowShell(
      icon: icon,
      label: label,
      value: value,
      trailing: IconButton(
        onPressed: onAction,
        icon: Icon(actionIcon, size: 18),
        color: _HomeCommercialState.primaryBlue,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(width: 34, height: 34),
      ),
    );
  }
}

class _InfoValueRow extends StatelessWidget {
  _InfoValueRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return _InfoRowShell(
      icon: icon,
      label: label,
      value: value,
      valueColor: valueColor,
      isLast: isLast,
    );
  }
}

class _InfoRowShell extends StatelessWidget {
  _InfoRowShell({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.trailing,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(color: Color(0xFFE8EDF5)),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _HomeCommercialState.textMuted),
          SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: TextStyle(
                color: _HomeCommercialState.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? _HomeCommercialState.textDark,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (trailing != null) ...[SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  _HistoryCard({required this.orders, required this.notes});

  final List<CommercialOrder> orders;
  final List<_ClientNote> notes;

  @override
  Widget build(BuildContext context) {
    final totalOrders = orders.length;
    final revenue = orders.fold<double>(
      0,
      (total, order) => total + order.total,
    );
    final latestOrder = _latestClientOrder(orders);
    final average = totalOrders == 0 ? 0.0 : revenue / totalOrders;

    return _DetailCard(
      child: orders.isEmpty && notes.isEmpty
          ? _EmptyDetailMessage(text: 'Aucune commande trouvée')
          : Column(
              children: [
                if (orders.isNotEmpty) ...[
                  _SimpleDetailRow(
                    icon: Icons.receipt_long_rounded,
                    title: 'Nombre de commandes',
                    subtitle: 'Commandes réellement créées',
                    value: '$totalOrders',
                    isLast: false,
                  ),
                  _SimpleDetailRow(
                    icon: Icons.payments_outlined,
                    title: 'CA généré',
                    subtitle: 'Total des commandes du client',
                    value: '${_money(revenue)} MAD',
                    isLast: false,
                  ),
                  _SimpleDetailRow(
                    icon: Icons.history_rounded,
                    title: 'Dernière commande',
                    subtitle: latestOrder?.date ?? 'Aucune',
                    value: latestOrder?.orderNumber ?? '-',
                    isLast: false,
                  ),
                  _SimpleDetailRow(
                    icon: Icons.analytics_outlined,
                    title: 'Montant moyen par commande',
                    subtitle: 'Calcul automatique',
                    value: '${_money(average)} MAD',
                    isLast: notes.isEmpty,
                  ),
                ],
                for (var i = 0; i < notes.length; i++)
                  _SimpleDetailRow(
                    icon: Icons.sticky_note_2_outlined,
                    title: 'Note client',
                    subtitle: notes[i].text,
                    value: _clientNoteDate(notes[i].createdAt),
                    isLast: i == notes.length - 1,
                  ),
              ],
            ),
    );
  }
}

class _ClientNote {
  _ClientNote({required this.text, required this.createdAt});

  final String text;
  final DateTime createdAt;
}

class _ClientNoteSheet extends StatefulWidget {
  _ClientNoteSheet();

  @override
  State<_ClientNoteSheet> createState() => _ClientNoteSheetState();
}

class _ClientNoteSheetState extends State<_ClientNoteSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ajouter une note',
            style: TextStyle(
              color: _HomeCommercialState.textDark,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Cette note sera ajoutée à l’historique du client.',
            style: TextStyle(
              color: _HomeCommercialState.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: _controller,
            minLines: 4,
            maxLines: 5,
            maxLength: 300,
            decoration: InputDecoration(
              hintText: 'Saisissez votre note...',
              filled: true,
              fillColor: Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: _HomeCommercialState.primaryBlue,
                  width: 1.4,
                ),
              ),
            ),
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _HomeCommercialState.primaryBlue,
                    side: BorderSide(color: _HomeCommercialState.primaryBlue),
                    minimumSize: Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text('Annuler'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final note = _controller.text.trim();
                    if (note.isEmpty) return;
                    Navigator.pop(context, note);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _HomeCommercialState.primaryBlue,
                    foregroundColor: Colors.white,
                    minimumSize: Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text('Enregistrer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _clientNoteDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month $hour:$minute';
}

class _DocumentsCard extends StatelessWidget {
  _DocumentsCard({required this.client, required this.orders});

  final CommercialClient client;
  final List<CommercialOrder> orders;

  @override
  Widget build(BuildContext context) {
    final documents = _documentsForClientOrders(client, orders);

    return _DetailCard(
      child: orders.isEmpty
          ? _EmptyDocumentsState()
          : Column(
              children: [
                for (var i = 0; i < documents.length; i++)
                  _DocumentDetailRow(
                    document: documents[i],
                    isLast: i == documents.length - 1,
                  ),
              ],
            ),
    );
  }
}

class _ClientDocumentView {
  _ClientDocumentView({
    required this.name,
    required this.date,
    required this.type,
  });

  final String name;
  final String date;
  final String type;
}

class _DocumentDetailRow extends StatelessWidget {
  _DocumentDetailRow({required this.document, required this.isLast});

  final _ClientDocumentView document;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(color: Color(0xFFE8EDF5)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.description_outlined,
            size: 19,
            color: _HomeCommercialState.textMuted,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _HomeCommercialState.textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '${document.type} • ${document.date}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _HomeCommercialState.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              foregroundColor: _HomeCommercialState.primaryBlue,
              padding: EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size(44, 34),
            ),
            child: Text(
              'Voir',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDocumentsState extends StatelessWidget {
  _EmptyDocumentsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 26, horizontal: 12),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              Icons.description_outlined,
              color: _HomeCommercialState.primaryBlue,
              size: 34,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Aucun document disponible',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _HomeCommercialState.textDark,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Les documents seront générés automatiquement après la création et la validation des commandes.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _HomeCommercialState.textMuted,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _clientTypeLabel(CommercialClient client) {
  final source = client.businessType.trim().isNotEmpty
      ? client.businessType.trim()
      : client.category.trim();
  return switch (source) {
    'Supermarchés & Grandes Surfaces' => 'Supermarché & Grande Surface',
    'Cafés & Restaurants' => 'Café & Restaurant',
    'Épiceries' => 'Épicerie',
    'Grossistes' => 'Grossiste',
    _ => source.isEmpty ? 'Type non défini' : source,
  };
}

List<CommercialOrder> _ordersForClient(String email, CommercialClient client) {
  final normalizedName = client.name.toLowerCase().trim();
  final orders = _runtimeOrdersForEmail(email).where((order) {
    return order.clientName.toLowerCase().trim() == normalizedName;
  }).toList();
  orders.sort((a, b) {
    final aDate = _parseOrderDate(a.date) ?? DateTime(1900);
    final bDate = _parseOrderDate(b.date) ?? DateTime(1900);
    return bDate.compareTo(aDate);
  });
  return orders;
}

CommercialOrder? _latestClientOrder(List<CommercialOrder> orders) {
  if (orders.isEmpty) return null;
  final sorted = [...orders]
    ..sort((a, b) {
      final aDate = _parseOrderDate(a.date) ?? DateTime(1900);
      final bDate = _parseOrderDate(b.date) ?? DateTime(1900);
      return bDate.compareTo(aDate);
    });
  return sorted.first;
}

List<_ClientDocumentView> _documentsForClientOrders(
  CommercialClient client,
  List<CommercialOrder> orders,
) {
  if (orders.isEmpty) return const [];
  final latest = _latestClientOrder(orders)!;
  final date = latest.date;
  return [
    _ClientDocumentView(
      name: 'Bons de commande',
      date: date,
      type: '${orders.length} commande(s)',
    ),
    _ClientDocumentView(
      name: 'Bons de livraison',
      date: date,
      type: 'Livraison',
    ),
    _ClientDocumentView(name: 'Factures', date: date, type: 'Facturation'),
    _ClientDocumentView(name: 'Relevé client', date: date, type: 'Synthèse'),
    _ClientDocumentView(
      name: 'Fiche client',
      date: date,
      type: _clientTypeLabel(client),
    ),
  ];
}

class _SimpleDetailRow extends StatelessWidget {
  _SimpleDetailRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.isLast,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(color: Color(0xFFE8EDF5)),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: _HomeCommercialState.textMuted),
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
                    color: _HomeCommercialState.textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _HomeCommercialState.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          Text(
            value,
            style: TextStyle(
              color: _HomeCommercialState.textDark,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDetailMessage extends StatelessWidget {
  _EmptyDetailMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 22),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: _HomeCommercialState.textMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  _DetailCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Color(0xFFE8EDF5)),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF18315E).withValues(alpha: .05),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }
}

Color _riskColor(ClientRisk risk) {
  return switch (risk) {
    ClientRisk.low => _HomeCommercialState.success,
    ClientRisk.medium => Color(0xFFFFA12B),
    ClientRisk.high => Color(0xFFFF4D4D),
  };
}

// ignore: unused_element
class _LegacyDetailClient extends StatelessWidget {
  _LegacyDetailClient({required this.client});

  final CommercialClient client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _HomeCommercialState.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(22),
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(maxWidth: 360),
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF18315E).withValues(alpha: .08),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: _HomeCommercialState.primaryBlue
                        .withValues(alpha: .14),
                    child: Text(
                      client.initials,
                      style: TextStyle(
                        color: _HomeCommercialState.primaryBlue,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(height: 18),
                  Text(
                    'D\u00E9tail du client : ${client.name}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _HomeCommercialState.textDark,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_rounded),
                    label: Text(AppLocalizations.globalText('Retour')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientsPremiumHeader extends StatelessWidget {
  _ClientsPremiumHeader({
    required this.onNotificationTap,
    required this.unreadNotificationCount,
  });

  final VoidCallback onNotificationTap;
  final int unreadNotificationCount;

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
                AppLocalizations.globalText('Clients'),
                style: TextStyle(
                  color: _DashboardTab._navy,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                AppLocalizations.globalText(
                  'G\u00E9rez et consultez vos clients',
                ),
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 12),
        _CommercialNotificationButton(
          onTap: onNotificationTap,
          unreadCount: unreadNotificationCount,
        ),
      ],
    );
  }
}

class _ClientsSearchAndFilter extends StatelessWidget {
  _ClientsSearchAndFilter({
    required this.controller,
    required this.onFilterTap,
    required this.activeFilterLabel,
  });

  final TextEditingController controller;
  final VoidCallback onFilterTap;
  final String activeFilterLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final filterWidth = constraints.maxWidth >= 380 ? 190.0 : 158.0;
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: AppLocalizations.globalText(
                    'Rechercher un client...',
                  ),
                  prefixIcon: Icon(Icons.search_rounded, size: 24),
                  filled: true,
                  fillColor: _HomeCommercialState.cardBg,
                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                  enabledBorder: _searchBorder(),
                  focusedBorder: _searchBorder(color: _DashboardTab._blue),
                ),
              ),
            ),
            SizedBox(width: 10),
            SizedBox(
              width: filterWidth,
              height: 54,
              child: OutlinedButton(
                onPressed: onFilterTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _DashboardTab._navy,
                  backgroundColor: _HomeCommercialState.cardBg,
                  side: BorderSide(color: Color(0xFFE2E8F0)),
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Icon(Icons.filter_alt_outlined, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.globalText(activeFilterLabel),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ClientFilterSheet extends StatelessWidget {
  _ClientFilterSheet({
    required this.selectedCategory,
    required this.categories,
    required this.onSelected,
  });

  final String? selectedCategory;
  final List<String?> categories;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0F172A).withValues(alpha: .16),
            blurRadius: 28,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.globalText('Filtrer les clients'),
              style: TextStyle(
                color: _DashboardTab._navy,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              AppLocalizations.globalText(
                'Affichez uniquement les clients correspondant à la catégorie sélectionnée.',
              ),
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16),
            for (final category in categories)
              InkWell(
                onTap: () => onSelected(category),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedCategory == category
                                ? _DashboardTab._blue
                                : Color(0xFFCBD5E1),
                            width: 2,
                          ),
                        ),
                        child: selectedCategory == category
                            ? Center(
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _DashboardTab._blue,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          AppLocalizations.globalText(
                            _clientFilterOptionLabel(category),
                          ),
                          style: TextStyle(
                            color: _DashboardTab._navy,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
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

class _ClientKpiGrid extends StatelessWidget {
  _ClientKpiGrid({required this.clients});

  final List<CommercialClient> clients;

  @override
  Widget build(BuildContext context) {
    final total = clients.length;
    final active = clients
        .where(
          (client) =>
              _clientUiStatusFromStatus(client.status) ==
              _ClientUiStatus.active,
        )
        .length;
    final inactive = clients
        .where(
          (client) =>
              _clientUiStatusFromStatus(client.status) ==
              _ClientUiStatus.inactive,
        )
        .length;
    final prospect = clients
        .where(
          (client) =>
              _clientUiStatusFromStatus(client.status) ==
              _ClientUiStatus.prospect,
        )
        .length;
    final potentialRevenue = clients
        .where((client) {
          final status = _clientUiStatusFromStatus(client.status);
          return status == _ClientUiStatus.active ||
              status == _ClientUiStatus.prospect;
        })
        .fold<double>(
          0,
          (total, client) => total + _ClientViewData.fromClient(client).revenue,
        );
    final items = [
      _ClientKpi(
        Icons.group_add_rounded,
        '$total',
        'Total clients',
        'à jour',
        _DashboardTab._blue,
      ),
      _ClientKpi(
        Icons.event_available_rounded,
        '$active',
        'Clients actifs',
        '$prospect prospects',
        _DashboardTab._green,
      ),
      _ClientKpi(
        Icons.schedule_rounded,
        '$inactive',
        'Inactifs',
        'à suivre',
        _DashboardTab._orange,
      ),
      _ClientKpi(
        Icons.star_rounded,
        _money(potentialRevenue),
        'CA potentiel',
        'actifs + prospects',
        Color(0xFF7C3AED),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 7,
        childAspectRatio: .50,
      ),
      itemBuilder: (context, index) => _ClientKpiCard(data: items[index]),
    );
  }
}

class _ClientKpi {
  _ClientKpi(this.icon, this.value, this.label, this.variation, this.color);

  final IconData icon;
  final String value;
  final String label;
  final String variation;
  final Color color;
}

class _ClientKpiCard extends StatelessWidget {
  _ClientKpiCard({required this.data});

  final _ClientKpi data;

  @override
  Widget build(BuildContext context) {
    final isNegative = data.variation.startsWith('-');
    return Container(
      padding: EdgeInsets.fromLTRB(9, 10, 8, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0F172A).withValues(alpha: .055),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(data.icon, color: data.color, size: 20),
          ),
          SizedBox(height: 9),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              data.label == 'CA potentiel' ? '${data.value} DH' : data.value,
              maxLines: 1,
              style: TextStyle(
                color: _DashboardTab._navy,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: 5),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                AppLocalizations.globalText(data.label),
                style: TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${data.variation} ce mois',
                maxLines: 1,
                style: TextStyle(
                  color: isNegative
                      ? _HomeCommercialState.error
                      : _DashboardTab._green,
                  fontSize: 8.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientTabs extends StatelessWidget {
  _ClientTabs({
    required this.selectedCategory,
    required this.categories,
    required this.countFor,
    required this.onChanged,
  });

  final String? selectedCategory;
  final List<String?> categories;
  final int Function(String?) countFor;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: BouncingScrollPhysics(),
        child: Row(
          children: [
            for (var i = 0; i < categories.length; i++) ...[
              InkWell(
                onTap: () => onChanged(categories[i]),
                borderRadius: BorderRadius.circular(999),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  constraints: BoxConstraints(
                    minWidth: categories[i] == null ? 92 : 118,
                    maxWidth: categories[i] == null ? 120 : 188,
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: selectedCategory == categories[i]
                        ? _DashboardTab._blue
                        : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selectedCategory == categories[i]
                          ? _DashboardTab._blue
                          : Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    _tabLabel(categories[i], countFor(categories[i])),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selectedCategory == categories[i]
                          ? Colors.white
                          : _DashboardTab._navy,
                      fontSize: 12,
                      fontWeight: selectedCategory == categories[i]
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (i != categories.length - 1) SizedBox(width: 10),
            ],
          ],
        ),
      ),
    );
  }

  String _tabLabel(String? category, int count) {
    if (category == null) return 'Tous ($count)';
    return '$category ($count)';
  }
}

class _ClientCard extends StatelessWidget {
  _ClientCard({required this.data, required this.onTap});

  final _ClientViewData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inactive = data.uiStatus == _ClientUiStatus.inactive;
    return Opacity(
      opacity: inactive ? .58 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: EdgeInsets.fromLTRB(14, 15, 12, 15),
            decoration: BoxDecoration(
              color: inactive ? Color(0xFFF8FAFC) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: inactive
                  ? null
                  : [
                      BoxShadow(
                        color: Color(0xFF0F172A).withValues(alpha: .055),
                        blurRadius: 22,
                        offset: Offset(0, 10),
                      ),
                    ],
            ),
            child: Row(
              children: [
                _ClientLogo(data: data),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _DashboardTab._navy,
                          fontSize: 16,
                          height: 1.12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        data.type,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 13,
                          height: 1.12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            color: Color(0xFF64748B),
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            data.client.city,
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      _ClientStatusBadge(status: data.uiStatus),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                SizedBox(
                  width: 105,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data.orderCount} ${data.orderCount == 1 ? 'commande' : 'commandes'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _money(data.revenue),
                            style: TextStyle(
                              color: _DashboardTab._navy,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 4),
                          Padding(
                            padding: EdgeInsets.only(bottom: 2),
                            child: Text(
                              AppLocalizations.globalText('DH'),
                              style: TextStyle(
                                color: _DashboardTab._navy,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        AppLocalizations.globalText('CA total'),
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientLogo extends StatelessWidget {
  _ClientLogo({required this.data});

  final _ClientViewData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: data.logoColor.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: data.logoText != null
            ? Text(
                data.logoText!,
                style: TextStyle(
                  color: data.logoColor,
                  fontSize: data.logoText!.length > 2 ? 18 : 24,
                  fontWeight: FontWeight.w900,
                ),
              )
            : Icon(data.logoIcon, color: data.logoColor, size: 34),
      ),
    );
  }
}

class _ClientStatusBadge extends StatelessWidget {
  _ClientStatusBadge({required this.status});

  final _ClientUiStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyClients extends StatelessWidget {
  _EmptyClients();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        AppLocalizations.globalText('Aucun client trouv\u00E9'),
        style: TextStyle(
          color: _HomeCommercialState.textMuted,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

OutlineInputBorder _searchBorder({Color color = const Color(0xFFE3E8F2)}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color),
  );
}

class _DashboardTab extends StatelessWidget {
  _DashboardTab({
    required this.userName,
    required this.summary,
    required this.objective,
    required this.ranking,
    required this.activities,
    required this.orders,
    required this.visits,
    required this.clients,
    required this.createdActivities,
    required this.currentEmail,
    required this.unreadNotificationCount,
    required this.onClientAdded,
    required this.onActivityCreated,
    required this.onNavigate,
  });

  final String userName;
  final CommercialDashboardSummary summary;
  final CommercialObjective? objective;
  final _CommercialRanking ranking;
  final List<CommercialActivity> activities;
  final List<CommercialOrder> orders;
  final List<TourVisit> visits;
  final List<CommercialClient> clients;
  final List<_CommercialActivityItem> createdActivities;
  final String currentEmail;
  final int unreadNotificationCount;
  final ValueChanged<CommercialClient> onClientAdded;
  final ValueChanged<_CommercialActivityItem> onActivityCreated;
  final ValueChanged<int> onNavigate;

  static const _navy = Color(0xFF0F172A);
  static const _blue = Color(0xFF2563EB);
  static const _green = Color(0xFF22C55E);
  static const _orange = Color(0xFFF59E0B);

  Future<void> _openNotifications(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CommercialNotificationsPage()),
    );
  }

  void _openNewOrder(BuildContext context) {
    if (clients.isEmpty) {
      onNavigate(1);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NouvelleCommandeClientSelection(
          clients: clients,
          currentEmail: currentEmail,
          currentUserName: userName,
        ),
      ),
    );
  }

  Future<void> _openAddClient(BuildContext context) async {
    final client = await Navigator.push<CommercialClient>(
      context,
      MaterialPageRoute(
        builder: (_) => NouveauClientScreen(
          currentEmail: currentEmail,
          currentUserName: userName,
          existingClients: clients,
        ),
      ),
    );
    if (client == null) return;
    onClientAdded(client);
    _clientDataRevision.value++;
  }

  void _openOrder(BuildContext context, CommercialOrder order) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailCommande(order: order)),
    );
  }

  void _openActivityHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ActivityHistoryPage(
          commercialName: userName,
          orders: orders,
          visits: visits,
          clients: clients,
          createdActivities: createdActivities,
        ),
      ),
    );
  }

  Future<void> _openVisitPlanner(BuildContext context) async {
    final created = await Navigator.push<_CommercialActivityItem>(
      context,
      MaterialPageRoute(
        builder: (_) => NewActivityPage(
          clients: clients,
          selectedDate: DateTime.now(),
          initialType: 'Visite client',
        ),
      ),
    );
    if (created != null) onActivityCreated(created);
  }

  void _openRecentActivity(BuildContext context, _ActivityHistoryItem item) {
    switch (item.target) {
      case _ActivityHistoryTarget.order:
        for (final order in orders) {
          if (order.id == item.targetId) {
            _openOrder(context, order);
            return;
          }
        }
        onNavigate(2);
        return;
      case _ActivityHistoryTarget.client:
        for (final client in clients) {
          if (client.id == item.targetId) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetailClient(
                  client: client,
                  currentEmail: currentEmail,
                  currentUserName: userName,
                ),
              ),
            );
            return;
          }
        }
        onNavigate(1);
        return;
      case _ActivityHistoryTarget.visit:
      case _ActivityHistoryTarget.call:
        for (final activity in createdActivities) {
          if (activity.id == item.targetId) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _ActivityVisitDetailPage(activity: activity),
              ),
            );
            return;
          }
        }
        for (final visit in visits) {
          if (visit.id == item.targetId) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _ActivityVisitDetailPage(
                  activity: _CommercialActivityItem.fromVisit(
                    visit: visit,
                    client: _clientById(clients, visit.clientId),
                    date: DateTime.now(),
                  ),
                ),
              ),
            );
            return;
          }
        }
        onNavigate(3);
        return;
      case _ActivityHistoryTarget.report:
        _openDailyReport(context);
    }
  }

  void _openDailyReport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DailyReportPage(
          commercialName: userName,
          currentEmail: currentEmail,
          city: _primaryCity(clients),
          summary: summary,
          orders: orders,
          visits: visits,
          createdActivities: createdActivities,
          clients: clients,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _DashboardMetrics.from(
      summary: summary,
      orders: orders,
      visits: visits,
      createdActivities: createdActivities,
      objective: objective,
      ranking: ranking,
    );
    final recentOrders = _latestDashboardOrders(orders);
    final recentActivities = _buildActivityHistoryItems(
      orders: orders,
      visits: visits,
      clients: clients,
      createdActivities: createdActivities,
      today: DateTime.now(),
    );

    return CustomScrollView(
      physics: BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 22),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _CommercialHomeHeader(
                userName: _firstName(userName),
                onNotificationTap: () => _openNotifications(context),
                unreadNotificationCount: unreadNotificationCount,
                onAvatarTap: () => onNavigate(4),
              ),
              SizedBox(height: 22),
              _DailyObjectiveCard(metrics: metrics),
              SizedBox(height: 18),
              _QuickStatsGrid(metrics: metrics),
              SizedBox(height: 18),
              _SalesEvolutionCard(metrics: metrics),
              SizedBox(height: 22),
              _SectionTitle(
                title: AppLocalizations.globalText('Actions rapides'),
              ),
              SizedBox(height: 12),
              _QuickActionsGrid(
                onNewOrder: () => _openNewOrder(context),
                onNewClient: () => _openAddClient(context),
                onVisit: () => _openVisitPlanner(context),
                onReport: () => _openDailyReport(context),
              ),
              SizedBox(height: 22),
              _SectionTitle(
                title: AppLocalizations.globalText('Derni\u00E8res commandes'),
                action: orders.length > 3
                    ? AppLocalizations.globalText('Voir tout')
                    : null,
                onActionTap: orders.length > 3 ? () => onNavigate(2) : null,
              ),
              SizedBox(height: 12),
              if (recentOrders.isEmpty)
                _DashboardEmptyCard(
                  icon: Icons.receipt_long_outlined,
                  message: 'Aucune commande pour le moment',
                )
              else
                for (final order in recentOrders) ...[
                  _RecentOrderCard(
                    order: order,
                    onTap: () => _openOrder(context, order),
                  ),
                  SizedBox(height: 10),
                ],
              SizedBox(height: 10),
              _SectionTitle(
                title: AppLocalizations.globalText(
                  'Activit\u00E9 r\u00E9cente',
                ),
                action: recentActivities.length > 3
                    ? AppLocalizations.globalText('Voir tout')
                    : null,
                onActionTap: recentActivities.length > 3
                    ? () => _openActivityHistory(context)
                    : null,
              ),
              SizedBox(height: 12),
              _RecentActivityCard(
                items: recentActivities,
                onTap: (item) => _openRecentActivity(context, item),
              ),
              SizedBox(height: 10),
            ]),
          ),
        ),
      ],
    );
  }

  static String _firstName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Youssef';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  static List<CommercialOrder> _latestDashboardOrders(
    List<CommercialOrder> source,
  ) {
    final sorted = [...source]
      ..sort((a, b) {
        final aDate = _parseOrderDate(a.date) ?? DateTime(1900);
        final bDate = _parseOrderDate(b.date) ?? DateTime(1900);
        return bDate.compareTo(aDate);
      });
    return sorted.take(3).toList();
  }
}

enum _ActivityHistoryType { all, orders, clients, visits, calls, reports }

enum _ActivityHistoryStatus { all, completed, pending, refused, validated }

enum _ActivityHistoryPeriod { today, yesterday, week, month }

class _ActivityHistoryPage extends StatefulWidget {
  _ActivityHistoryPage({
    required this.commercialName,
    required this.orders,
    required this.visits,
    required this.clients,
    required this.createdActivities,
  });

  final String commercialName;
  final List<CommercialOrder> orders;
  final List<TourVisit> visits;
  final List<CommercialClient> clients;
  final List<_CommercialActivityItem> createdActivities;

  @override
  State<_ActivityHistoryPage> createState() => _ActivityHistoryPageState();
}

class _ActivityHistoryPageState extends State<_ActivityHistoryPage> {
  final _searchController = TextEditingController();
  _ActivityHistoryType _type = _ActivityHistoryType.all;
  _ActivityHistoryStatus _status = _ActivityHistoryStatus.all;
  _ActivityHistoryPeriod _period = _ActivityHistoryPeriod.week;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTime get _today => _latestOrderDate(widget.orders) ?? DateTime.now();

  List<_ActivityHistoryItem> get _items {
    return _buildActivityHistoryItems(
      orders: widget.orders,
      visits: widget.visits,
      clients: widget.clients,
      createdActivities: widget.createdActivities,
      today: DateUtils.dateOnly(_today),
    ).where(_matchesFilters).toList()..sort((a, b) {
      final dateCompare = b.date.compareTo(a.date);
      if (dateCompare != 0) return dateCompare;
      return b.timeLabel.compareTo(a.timeLabel);
    });
  }

  bool _matchesFilters(_ActivityHistoryItem item) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty && !item.searchText.toLowerCase().contains(query)) {
      return false;
    }
    if (_selectedDate != null &&
        !DateUtils.isSameDay(item.date, _selectedDate)) {
      return false;
    }
    if (_type != _ActivityHistoryType.all && item.type != _type) return false;
    if (_status != _ActivityHistoryStatus.all && item.status != _status) {
      return false;
    }
    if (_selectedDate == null && !_matchesPeriod(item.date)) return false;
    return true;
  }

  bool _matchesPeriod(DateTime date) {
    final today = DateUtils.dateOnly(_today);
    final day = DateUtils.dateOnly(date);
    return switch (_period) {
      _ActivityHistoryPeriod.today => DateUtils.isSameDay(day, today),
      _ActivityHistoryPeriod.yesterday => DateUtils.isSameDay(
        day,
        today.subtract(Duration(days: 1)),
      ),
      _ActivityHistoryPeriod.week =>
        !day.isBefore(today.subtract(Duration(days: 6))) && !day.isAfter(today),
      _ActivityHistoryPeriod.month =>
        day.year == today.year && day.month == today.month,
    };
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? _today,
      firstDate: DateTime.now().subtract(Duration(days: 180)),
      lastDate: DateTime.now().add(Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _selectedDate = DateUtils.dateOnly(picked));
    }
  }

  void _showFilters() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _HomeCommercialState.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HistorySheetHeader(),
                    _HistoryFilterGroup<_ActivityHistoryType>(
                      title: "Type d'activité",
                      value: _type,
                      values: _ActivityHistoryType.values,
                      label: _historyTypeLabel,
                      onChanged: (value) {
                        setSheetState(() => _type = value);
                        setState(() => _type = value);
                      },
                    ),
                    _HistoryFilterGroup<_ActivityHistoryStatus>(
                      title: 'Statut',
                      value: _status,
                      values: _ActivityHistoryStatus.values,
                      label: _historyStatusLabel,
                      onChanged: (value) {
                        setSheetState(() => _status = value);
                        setState(() => _status = value);
                      },
                    ),
                    _HistoryFilterGroup<_ActivityHistoryPeriod>(
                      title: 'Période',
                      value: _period,
                      values: _ActivityHistoryPeriod.values,
                      label: _historyPeriodLabel,
                      onChanged: (value) {
                        setSheetState(() {
                          _period = value;
                          _selectedDate = null;
                        });
                        setState(() {
                          _period = value;
                          _selectedDate = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openItem(_ActivityHistoryItem item) {
    switch (item.target) {
      case _ActivityHistoryTarget.order:
        final order = widget.orders
            .where((order) => order.id == item.targetId)
            .firstOrNull;
        if (order != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DetailCommande(order: order)),
          );
        }
      case _ActivityHistoryTarget.client:
        final client = widget.clients
            .where((client) => client.id == item.targetId)
            .firstOrNull;
        if (client != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetailClient(
                client: client,
                currentEmail: CurrentUserSession.currentUser?.email ?? '',
                currentUserName: widget.commercialName,
              ),
            ),
          );
        }
      case _ActivityHistoryTarget.visit:
      case _ActivityHistoryTarget.call:
        final visit = widget.visits
            .where((visit) => visit.id == item.targetId)
            .firstOrNull;
        if (visit != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _ActivityVisitDetailPage(
                activity: _CommercialActivityItem.fromVisit(
                  visit: visit,
                  client: _clientForVisit(visit, widget.clients),
                  date: item.date,
                ),
              ),
            ),
          );
        }
      case _ActivityHistoryTarget.report:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _DailyReportPage(
              commercialName: widget.commercialName,
              currentEmail: CurrentUserSession.currentUser?.email ?? '',
              city: _primaryCity(widget.clients),
              summary: CommercialDashboardData.empty().summary,
              orders: widget.orders,
              visits: widget.visits,
              createdActivities: widget.createdActivities,
              clients: widget.clients,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupHistoryItems(_items, DateUtils.dateOnly(_today));

    return Scaffold(
      backgroundColor: _HomeCommercialState.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20, 18, 20, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ActivityHistoryHeader(
                          onBack: () => Navigator.pop(context),
                          onFilter: _showFilters,
                        ),
                        SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: _HistorySearchField(
                                controller: _searchController,
                              ),
                            ),
                            SizedBox(width: 12),
                            _HistoryCalendarButton(onTap: _pickDate),
                          ],
                        ),
                        if (_selectedDate != null) ...[
                          SizedBox(height: 10),
                          _HistoryDateFilterChip(
                            label: _historyDateLabel(_selectedDate!),
                            onClear: () => setState(() => _selectedDate = null),
                          ),
                        ],
                        SizedBox(height: 24),
                        if (groups.isEmpty)
                          _EmptyActivityHistory(
                            onHome: () => Navigator.pop(context),
                          )
                        else
                          for (final group in groups) ...[
                            _ActivityHistoryGroupView(
                              group: group,
                              onTap: _openItem,
                            ),
                            SizedBox(height: 26),
                          ],
                      ],
                    ),
                  ),
                ),
                _HistoryBottomNav(
                  onChanged: (index) {
                    if (index == 0) return Navigator.pop(context);
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/home-commercial',
                      (route) => false,
                      arguments: {'initialIndex': index},
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _ActivityHistoryTarget { order, client, visit, call, report }

class _ActivityHistoryItem {
  _ActivityHistoryItem({
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    required this.date,
    required this.icon,
    required this.color,
    required this.type,
    required this.status,
    required this.target,
    required this.targetId,
    this.completedIndicator = false,
  });

  final String title;
  final String subtitle;
  final String timeLabel;
  final DateTime date;
  final IconData icon;
  final Color color;
  final _ActivityHistoryType type;
  final _ActivityHistoryStatus status;
  final _ActivityHistoryTarget target;
  final int targetId;
  final bool completedIndicator;

  String get searchText => '$title $subtitle ${_historyTypeLabel(type)}';
}

class _ActivityHistoryGroup {
  _ActivityHistoryGroup({required this.title, required this.items});

  final String title;
  final List<_ActivityHistoryItem> items;
}

class _ActivityHistoryHeader extends StatelessWidget {
  _ActivityHistoryHeader({required this.onBack, required this.onFilter});

  final VoidCallback onBack;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: Icon(Icons.arrow_back_rounded, size: 30),
          color: _HomeCommercialState.primaryBlue,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(width: 42, height: 42),
        ),
        SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Historique des activités',
                style: TextStyle(
                  color: _HomeCommercialState.textDark,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Toutes vos activités récentes',
                style: TextStyle(
                  color: _HomeCommercialState.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        _ReportIconButton(icon: Icons.tune_rounded, onTap: onFilter),
      ],
    );
  }
}

class _HistorySearchField extends StatelessWidget {
  _HistorySearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: TextStyle(
        color: _HomeCommercialState.textDark,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: 'Rechercher une activité...',
        hintStyle: TextStyle(color: _HomeCommercialState.textMuted),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: _HomeCommercialState.textMuted,
        ),
        filled: true,
        fillColor: _HomeCommercialState.cardBg,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: _historyInputBorder(),
        enabledBorder: _historyInputBorder(),
        focusedBorder: _historyInputBorder(
          _HomeCommercialState.primaryBlue,
          1.4,
        ),
      ),
    );
  }
}

class _HistoryCalendarButton extends StatelessWidget {
  _HistoryCalendarButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 64,
        height: 58,
        decoration: BoxDecoration(
          color: _HomeCommercialState.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _historyBorderColor()),
        ),
        child: Icon(
          Icons.calendar_month_rounded,
          color: _HomeCommercialState.primaryBlue,
        ),
      ),
    );
  }
}

class _HistoryDateFilterChip extends StatelessWidget {
  _HistoryDateFilterChip({required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InputChip(
        label: Text(label),
        onDeleted: onClear,
        backgroundColor: _HomeCommercialState.primaryBlue.withValues(
          alpha: .08,
        ),
        labelStyle: TextStyle(
          color: _HomeCommercialState.primaryBlue,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ActivityHistoryGroupView extends StatelessWidget {
  _ActivityHistoryGroupView({required this.group, required this.onTap});

  final _ActivityHistoryGroup group;
  final ValueChanged<_ActivityHistoryItem> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                group.title,
                style: TextStyle(
                  color: _HomeCommercialState.textDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _HomeCommercialState.primaryBlue.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${group.items.length} activités',
                style: TextStyle(
                  color: _HomeCommercialState.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        _ActivityHistoryCard(
          child: Column(
            children: [
              for (var i = 0; i < group.items.length; i++) ...[
                _ActivityHistoryRow(
                  item: group.items[i],
                  onTap: () => onTap(group.items[i]),
                ),
                if (i != group.items.length - 1) _HistoryDivider(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivityHistoryRow extends StatelessWidget {
  _ActivityHistoryRow({required this.item, required this.onTap});

  final _ActivityHistoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _ReportRoundIcon(icon: item.icon, color: item.color, size: 52),
                if (item.completedIndicator)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: Color(0xFF22C55E),
                      child: Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 14,
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
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _HomeCommercialState.textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _HomeCommercialState.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10),
            Text(
              item.timeLabel,
              style: TextStyle(
                color: _HomeCommercialState.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: _HomeCommercialState.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityHistoryCard extends StatelessWidget {
  _ActivityHistoryCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _HomeCommercialState.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _historyBorderColor()),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HistoryDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: _historyBorderColor(), indent: 84);
  }
}

class _EmptyActivityHistory extends StatelessWidget {
  _EmptyActivityHistory({required this.onHome});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return _ActivityHistoryCard(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            _ReportRoundIcon(
              icon: Icons.history_rounded,
              color: _HomeCommercialState.primaryBlue,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'Aucune activité récente',
              style: TextStyle(
                color: _HomeCommercialState.textDark,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Vos actions apparaîtront ici lorsque vous utiliserez l’application.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _HomeCommercialState.textMuted,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 18),
            ElevatedButton(
              onPressed: onHome,
              style: ElevatedButton.styleFrom(
                backgroundColor: _HomeCommercialState.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: Text('Retour à l’accueil'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryBottomNav extends StatelessWidget {
  _HistoryBottomNav({required this.onChanged});

  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_rounded, 'Accueil'),
      (Icons.groups_rounded, 'Clients'),
      (Icons.receipt_long_rounded, 'Commandes'),
      (Icons.pie_chart_outline_rounded, 'Activités'),
      (Icons.person_outline_rounded, 'Profil'),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _HomeCommercialState.cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 18,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 74,
          child: Row(
            children: List.generate(items.length, (index) {
              final selected = index == 0;
              return Expanded(
                child: InkWell(
                  onTap: () => onChanged(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        items[index].$1,
                        color: selected
                            ? _HomeCommercialState.primaryBlue
                            : _HomeCommercialState.textMuted,
                        size: 27,
                      ),
                      SizedBox(height: 4),
                      Text(
                        items[index].$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? _HomeCommercialState.primaryBlue
                              : _HomeCommercialState.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _HistorySheetHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: _historyBorderColor(),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        SizedBox(height: 18),
        Text(
          'Filtrer l’historique',
          style: TextStyle(
            color: _HomeCommercialState.textDark,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _HistoryFilterGroup<T> extends StatelessWidget {
  _HistoryFilterGroup({
    required this.title,
    required this.value,
    required this.values,
    required this.label,
    required this.onChanged,
  });

  final String title;
  final T value;
  final List<T> values;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: _HomeCommercialState.textDark,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in values)
                ChoiceChip(
                  selected: item == value,
                  label: Text(label(item)),
                  selectedColor: _HomeCommercialState.primaryBlue.withValues(
                    alpha: .14,
                  ),
                  labelStyle: TextStyle(
                    color: item == value
                        ? _HomeCommercialState.primaryBlue
                        : _HomeCommercialState.textMuted,
                    fontWeight: FontWeight.w800,
                  ),
                  onSelected: (_) => onChanged(item),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

List<_ActivityHistoryItem> _buildActivityHistoryItems({
  required List<CommercialOrder> orders,
  required List<TourVisit> visits,
  required List<CommercialClient> clients,
  required List<_CommercialActivityItem> createdActivities,
  required DateTime today,
}) {
  final yesterday = today.subtract(Duration(days: 1));
  final weekDate = today.subtract(Duration(days: 2));
  final items = <_ActivityHistoryItem>[];

  for (final visit in visits) {
    final client = _clientForVisit(visit, clients);
    final date = visit.status == TourVisitStatus.visited ? today : yesterday;
    items.add(
      _ActivityHistoryItem(
        title: visit.status == TourVisitStatus.visited
            ? 'Visite client terminée'
            : 'Activité créée',
        subtitle: '${visit.clientName} • ${client?.city ?? 'Casablanca'}',
        timeLabel: visit.status == TourVisitStatus.visited
            ? visit.time
            : visit.time,
        date: date,
        icon: Icons.storefront_rounded,
        color: visit.status == TourVisitStatus.visited
            ? Color(0xFF22C55E)
            : _HomeCommercialState.primaryBlue,
        type: _ActivityHistoryType.visits,
        status: visit.status == TourVisitStatus.visited
            ? _ActivityHistoryStatus.completed
            : _ActivityHistoryStatus.pending,
        target: _ActivityHistoryTarget.visit,
        targetId: visit.id,
        completedIndicator: visit.status == TourVisitStatus.visited,
      ),
    );
  }

  for (var i = 0; i < orders.length; i++) {
    final order = orders[i];
    final date = _parseOrderDate(order.date) ?? (i < 3 ? today : weekDate);
    final style = _historyOrderStyle(order.status);
    items.add(
      _ActivityHistoryItem(
        title: style.title,
        subtitle: '${order.orderNumber} • ${_reportMoney(order.total)}',
        timeLabel: DateUtils.isSameDay(date, today)
            ? _orderDisplayTime(order)
            : _shortHistoryDate(date, today),
        date: DateUtils.dateOnly(date),
        icon: style.icon,
        color: style.color,
        type: _ActivityHistoryType.orders,
        status: style.status,
        target: _ActivityHistoryTarget.order,
        targetId: order.id,
        completedIndicator: order.status == OrderStatus.delivered,
      ),
    );
  }

  for (final activity in createdActivities) {
    final isVisit = activity.title == 'Visite client';
    final isCall = activity.title == 'Appel de suivi';
    items.add(
      _ActivityHistoryItem(
        title: isVisit
            ? 'Visite client créée'
            : isCall
            ? 'Appel de suivi créé'
            : 'Activité créée',
        subtitle:
            '${activity.subtitle}${activity.location.isNotEmpty ? ' • ${activity.location}' : ''}',
        timeLabel: activity.time,
        date: activity.date,
        icon: activity.icon,
        color: activity.color,
        type: isVisit
            ? _ActivityHistoryType.visits
            : isCall
            ? _ActivityHistoryType.calls
            : _ActivityHistoryType.all,
        status: _ActivityHistoryStatus.pending,
        target: isCall
            ? _ActivityHistoryTarget.call
            : _ActivityHistoryTarget.visit,
        targetId: activity.id,
      ),
    );
  }

  return items;
}

({String title, IconData icon, Color color, _ActivityHistoryStatus status})
_historyOrderStyle(OrderStatus status) {
  return switch (status) {
    OrderStatus.delivered => (
      title: 'Commande validée',
      icon: Icons.assignment_turned_in_rounded,
      color: Color(0xFF22C55E),
      status: _ActivityHistoryStatus.validated,
    ),
    OrderStatus.synced => (
      title: 'Commande envoyée au manager',
      icon: Icons.send_rounded,
      color: _HomeCommercialState.primaryBlue,
      status: _ActivityHistoryStatus.completed,
    ),
    OrderStatus.pending => (
      title: 'Commande en attente',
      icon: Icons.receipt_long_rounded,
      color: Color(0xFFF59E0B),
      status: _ActivityHistoryStatus.pending,
    ),
    OrderStatus.cancelled => (
      title: 'Commande refusée',
      icon: Icons.close_rounded,
      color: Color(0xFFEF4444),
      status: _ActivityHistoryStatus.refused,
    ),
  };
}

List<_ActivityHistoryGroup> _groupHistoryItems(
  List<_ActivityHistoryItem> items,
  DateTime today,
) {
  final yesterday = today.subtract(Duration(days: 1));
  final todayItems = items
      .where((item) => DateUtils.isSameDay(item.date, today))
      .toList();
  final yesterdayItems = items
      .where((item) => DateUtils.isSameDay(item.date, yesterday))
      .toList();
  final weekItems = items.where((item) {
    return !DateUtils.isSameDay(item.date, today) &&
        !DateUtils.isSameDay(item.date, yesterday) &&
        item.date.isAfter(today.subtract(Duration(days: 7)));
  }).toList();

  return [
    if (todayItems.isNotEmpty)
      _ActivityHistoryGroup(
        title: "Aujourd’hui - ${_historyDateLabel(today)}",
        items: todayItems,
      ),
    if (yesterdayItems.isNotEmpty)
      _ActivityHistoryGroup(
        title: 'Hier - ${_historyDateLabel(yesterday)}',
        items: yesterdayItems,
      ),
    if (weekItems.isNotEmpty)
      _ActivityHistoryGroup(title: 'Cette semaine', items: weekItems),
  ];
}

String _historyTypeLabel(_ActivityHistoryType type) {
  return switch (type) {
    _ActivityHistoryType.all => 'Toutes',
    _ActivityHistoryType.orders => 'Commandes',
    _ActivityHistoryType.clients => 'Clients',
    _ActivityHistoryType.visits => 'Visites',
    _ActivityHistoryType.calls => 'Appels',
    _ActivityHistoryType.reports => 'Rapports',
  };
}

String _historyStatusLabel(_ActivityHistoryStatus status) {
  return switch (status) {
    _ActivityHistoryStatus.all => 'Toutes',
    _ActivityHistoryStatus.completed => 'Terminées',
    _ActivityHistoryStatus.pending => 'En attente',
    _ActivityHistoryStatus.refused => 'Refusées',
    _ActivityHistoryStatus.validated => 'Validées',
  };
}

String _historyPeriodLabel(_ActivityHistoryPeriod period) {
  return switch (period) {
    _ActivityHistoryPeriod.today => 'Aujourd’hui',
    _ActivityHistoryPeriod.yesterday => 'Hier',
    _ActivityHistoryPeriod.week => 'Cette semaine',
    _ActivityHistoryPeriod.month => 'Ce mois',
  };
}

String _historyDateLabel(DateTime date) {
  const months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _shortHistoryDate(DateTime date, DateTime today) {
  if (DateUtils.isSameDay(date, today.subtract(Duration(days: 1)))) {
    return 'Hier';
  }
  const months = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];
  return '${date.day} ${months[date.month - 1]}';
}

OutlineInputBorder _historyInputBorder([Color? color, double width = 1]) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: color ?? _historyBorderColor(), width: width),
  );
}

Color _historyBorderColor() {
  return ThemeData.estimateBrightnessForColor(_HomeCommercialState.cardBg) ==
          Brightness.dark
      ? const Color(0xFF334155)
      : const Color(0xFFE2E8F0);
}

class _DailyReportPage extends StatefulWidget {
  _DailyReportPage({
    required this.commercialName,
    required this.currentEmail,
    required this.city,
    required this.summary,
    required this.orders,
    required this.visits,
    required this.createdActivities,
    required this.clients,
  });

  final String commercialName;
  final String currentEmail;
  final String city;
  final CommercialDashboardSummary summary;
  final List<CommercialOrder> orders;
  final List<TourVisit> visits;
  final List<_CommercialActivityItem> createdActivities;
  final List<CommercialClient> clients;

  @override
  State<_DailyReportPage> createState() => _DailyReportPageState();
}

class _DailyReportPageState extends State<_DailyReportPage> {
  late DateTime _reportDate;
  final _commentController = TextEditingController();
  bool _reportSent = false;

  @override
  void initState() {
    super.initState();
    _reportDate = DateUtils.dateOnly(DateTime.now());
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  List<CommercialOrder> get _reportOrders {
    final sameDayOrders = widget.orders.where((order) {
      final date = _parseOrderDate(order.date);
      return date != null && DateUtils.isSameDay(date, _reportDate);
    }).toList();
    return sameDayOrders;
  }

  List<_CommercialActivityItem> get _reportActivities {
    return widget.createdActivities.where((activity) {
      return DateUtils.isSameDay(activity.date, _reportDate);
    }).toList();
  }

  List<_CommercialActivityItem> get _reportVisits {
    return _reportActivities
        .where((activity) => activity.title == 'Visite client')
        .toList();
  }

  bool get _hasReportData =>
      _reportOrders.isNotEmpty || _reportActivities.isNotEmpty;

  int get _visitedCount => _reportVisits
      .where((visit) => visit.status == _CommercialActivityStatus.done)
      .length;

  double get _revenue =>
      _reportOrders.fold(0, (total, order) => total + order.total);

  int get _followUpCalls => _reportActivities
      .where((activity) => activity.title == 'Appel de suivi')
      .length;

  int get _newClients => _runtimeClientsForEmail(widget.currentEmail).length;

  int get _visitTarget => widget.summary.dailyVisitsTotal <= 0
      ? _reportVisits.length
      : widget.summary.dailyVisitsTotal;

  double get _revenueTarget => widget.summary.monthlyTarget <= 0
      ? _revenue
      : widget.summary.monthlyTarget / 20;

  double get _visitProgress =>
      _visitTarget <= 0 ? 0 : (_visitedCount / _visitTarget).clamp(0, 1);

  double get _revenueProgress =>
      _revenueTarget <= 0 ? 0 : (_revenue / _revenueTarget).clamp(0, 1);

  Future<void> _pickReportDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _reportDate,
      firstDate: DateTime.now().subtract(Duration(days: 120)),
      lastDate: DateTime.now(),
    );
    if (picked != null)
      setState(() => _reportDate = DateUtils.dateOnly(picked));
  }

  Future<void> _downloadPdf() async {
    if (!_hasReportData) {
      _showReportUnavailableMessage();
      return;
    }
    final pdf = pw.Document();
    final comment = _commentController.text.trim();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text(
            'Rapport journalier PreSales',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Text('Commercial : ${widget.commercialName}'),
          pw.Text('Ville : ${widget.city}'),
          pw.Text('Date : ${_dailyReportDateLabel(_reportDate)}'),
          pw.SizedBox(height: 18),
          pw.Text(
            "Résumé",
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text("Clients visités : $_visitedCount"),
          pw.Text("Commandes créées : ${_reportOrders.length}"),
          pw.Text("Chiffre d'affaires réalisé : ${_reportMoney(_revenue)}"),
          pw.Text('Appels de suivi : $_followUpCalls'),
          pw.Text('Nouveaux clients : $_newClients'),
          pw.SizedBox(height: 18),
          pw.Text(
            "Détail des visites",
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          ..._reportVisits.map(
            (visit) => pw.Text(
              '${visit.time} - ${visit.subtitle} - ${visit.location}',
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            "Détail des commandes",
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          ..._reportOrders.map(
            (order) => pw.Text(
              '${order.orderNumber} - ${order.clientName} - ${_reportMoney(order.total)} - ${order.status.label}',
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Commentaire',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(comment.isEmpty ? 'Aucun commentaire.' : comment),
        ],
      ),
    );

    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'rapport_journalier_${_reportDate.year}_${_reportDate.month.toString().padLeft(2, '0')}_${_reportDate.day.toString().padLeft(2, '0')}.pdf',
    );
  }

  void _sendToManager() {
    if (!_hasReportData) {
      _showReportUnavailableMessage();
      return;
    }
    setState(() => _reportSent = true);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text("Rapport envoyé avec succès.")));
  }

  void _showReportUnavailableMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            "Ajoutez au moins une activité ou une commande pour générer le rapport.",
          ),
        ),
      );
  }

  void _openVisit(_CommercialActivityItem visit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ActivityVisitDetailPage(activity: visit),
      ),
    );
  }

  void _openOrder(CommercialOrder order) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailCommande(order: order)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final generatedAt = TimeOfDay.now().format(context);
    final hasReportData = _hasReportData;
    return Scaffold(
      backgroundColor: _HomeCommercialState.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20, 18, 20, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DailyReportHeader(
                          onBack: () => Navigator.pop(context),
                          onCalendar: _pickReportDate,
                        ),
                        SizedBox(height: 22),
                        _ReportInfoCard(
                          date: _dailyReportDateLabel(_reportDate),
                          commercialName: widget.commercialName,
                          city: widget.city,
                          generatedAt: hasReportData ? generatedAt : null,
                          hasReportData: hasReportData,
                        ),
                        SizedBox(height: 18),
                        _ReportKpiCard(
                          visitedClients: _visitedCount,
                          ordersCount: _reportOrders.length,
                          revenue: _revenue,
                          followUpCalls: _followUpCalls,
                          newClients: _newClients,
                        ),
                        SizedBox(height: 18),
                        _ReportObjectivesSection(
                          visited: _visitedCount,
                          visitTarget: _visitTarget,
                          revenue: _revenue,
                          revenueTarget: _revenueTarget,
                          visitProgress: _visitProgress,
                          revenueProgress: _revenueProgress,
                        ),
                        SizedBox(height: 18),
                        _ReportVisitsCard(
                          visits: _reportVisits.take(3).toList(),
                          totalCount: _reportVisits.length,
                          onVisitTap: _openVisit,
                        ),
                        SizedBox(height: 18),
                        _ReportOrdersCard(
                          orders: _reportOrders.take(3).toList(),
                          totalCount: _reportOrders.length,
                          onOrderTap: _openOrder,
                        ),
                        SizedBox(height: 18),
                        _ReportCommentCard(
                          controller: _commentController,
                          hasReportData: hasReportData,
                        ),
                        if (!hasReportData) ...[
                          SizedBox(height: 12),
                          _ReportEmptyActionMessage(),
                        ],
                        SizedBox(height: 18),
                      ],
                    ),
                  ),
                ),
                _ReportActionsBar(
                  onDownload: _downloadPdf,
                  onSend: _sendToManager,
                  enabled: hasReportData,
                  reportSent: _reportSent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyReportHeader extends StatelessWidget {
  _DailyReportHeader({required this.onBack, required this.onCalendar});

  final VoidCallback onBack;
  final VoidCallback onCalendar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: Icon(Icons.arrow_back_rounded, size: 30),
          color: _HomeCommercialState.primaryBlue,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(width: 42, height: 42),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rapport journalier',
                style: TextStyle(
                  color: _HomeCommercialState.textDark,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "Compte-rendu de votre journée",
                style: TextStyle(
                  color: _HomeCommercialState.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        _ReportIconButton(
          icon: Icons.calendar_month_rounded,
          onTap: onCalendar,
        ),
      ],
    );
  }
}

class _ReportInfoCard extends StatelessWidget {
  _ReportInfoCard({
    required this.date,
    required this.commercialName,
    required this.city,
    required this.generatedAt,
    required this.hasReportData,
  });

  final String date;
  final String commercialName;
  final String city;
  final String? generatedAt;
  final bool hasReportData;

  @override
  Widget build(BuildContext context) {
    return _ReportCard(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: _HomeCommercialState.primaryBlue.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.request_quote_outlined,
              color: _HomeCommercialState.primaryBlue,
              size: 50,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                _ReportMetaLine(icon: Icons.calendar_month_rounded, text: date),
                SizedBox(height: 10),
                _ReportMetaLine(
                  icon: Icons.person_outline_rounded,
                  text: commercialName,
                ),
                SizedBox(height: 10),
                _ReportMetaLine(icon: Icons.location_on_outlined, text: city),
              ],
            ),
          ),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: hasReportData ? Color(0xFFEAFBF1) : Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasReportData
                          ? Icons.check_rounded
                          : Icons.schedule_rounded,
                      color: hasReportData
                          ? Color(0xFF22C55E)
                          : Color(0xFFF59E0B),
                      size: 18,
                    ),
                    SizedBox(width: 6),
                    Text(
                      hasReportData
                          ? "Journée terminée"
                          : "Aucune activité aujourd'hui",
                      style: TextStyle(
                        color: hasReportData
                            ? Color(0xFF16A34A)
                            : Color(0xFFD97706),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              if (generatedAt != null) ...[
                SizedBox(height: 16),
                Text(
                  "Rapport généré à $generatedAt",
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: _HomeCommercialState.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportKpiCard extends StatelessWidget {
  _ReportKpiCard({
    required this.visitedClients,
    required this.ordersCount,
    required this.revenue,
    required this.followUpCalls,
    required this.newClients,
  });

  final int visitedClients;
  final int ordersCount;
  final double revenue;
  final int followUpCalls;
  final int newClients;

  @override
  Widget build(BuildContext context) {
    final items = [
      _ReportKpiData(
        Icons.groups_rounded,
        Color(0xFF22C55E),
        '$visitedClients',
        "Clients visités",
        "",
      ),
      _ReportKpiData(
        Icons.shopping_cart_rounded,
        _HomeCommercialState.primaryBlue,
        '$ordersCount',
        "Commandes créées",
        "",
      ),
      _ReportKpiData(
        Icons.monetization_on_rounded,
        Color(0xFF8B5CF6),
        _reportMoney(revenue),
        "Chiffre d'affaires réalisé",
        "",
      ),
      _ReportKpiData(
        Icons.phone_rounded,
        Color(0xFFF59E0B),
        '$followUpCalls',
        'Appels de suivi',
        "",
      ),
      _ReportKpiData(
        Icons.person_add_alt_rounded,
        Color(0xFFEF4444),
        '$newClients',
        'Nouveaux clients',
        "",
      ),
    ];

    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReportSectionHeader(title: "Résumé de la journée"),
          SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                Expanded(child: _ReportKpiTile(data: items[i])),
                if (i != items.length - 1)
                  Container(width: 1, height: 98, color: _reportBorderColor()),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportObjectivesSection extends StatelessWidget {
  _ReportObjectivesSection({
    required this.visited,
    required this.visitTarget,
    required this.revenue,
    required this.revenueTarget,
    required this.visitProgress,
    required this.revenueProgress,
  });

  final int visited;
  final int visitTarget;
  final double revenue;
  final double revenueTarget;
  final double visitProgress;
  final double revenueProgress;

  @override
  Widget build(BuildContext context) {
    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReportSectionHeader(title: 'Objectifs du jour'),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ObjectiveMiniCard(
                  icon: Icons.groups_rounded,
                  color: Color(0xFF22C55E),
                  title: 'Objectif visites',
                  value: '$visited / $visitTarget',
                  suffix: "visites réalisées",
                  percent: visitProgress,
                  gap: 'Gap : ${mathMax(visitTarget - visited, 0)} visites',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _ObjectiveMiniCard(
                  icon: Icons.monetization_on_rounded,
                  color: Color(0xFF8B5CF6),
                  title: 'Objectif CA',
                  value:
                      '${_reportMoney(revenue)} / ${_reportMoney(revenueTarget)}',
                  suffix: "chiffre d'affaires réalisé",
                  percent: revenueProgress,
                  gap:
                      'Gap : ${_reportMoney(mathMaxDouble(revenueTarget - revenue, 0))}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportVisitsCard extends StatelessWidget {
  _ReportVisitsCard({
    required this.visits,
    required this.totalCount,
    required this.onVisitTap,
  });

  final List<_CommercialActivityItem> visits;
  final int totalCount;
  final ValueChanged<_CommercialActivityItem> onVisitTap;

  @override
  Widget build(BuildContext context) {
    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReportSectionHeader(
            title: "Détail des visites",
            action: totalCount > 3 ? 'Voir tout' : null,
          ),
          SizedBox(height: 16),
          if (visits.isEmpty)
            _ReportEmptyLine("Aucune visite planifiée.")
          else
            for (var i = 0; i < visits.length; i++)
              _VisitTimelineRow(
                visit: visits[i],
                isLast: i == visits.length - 1,
                onTap: () => onVisitTap(visits[i]),
              ),
        ],
      ),
    );
  }
}

class _ReportOrdersCard extends StatelessWidget {
  _ReportOrdersCard({
    required this.orders,
    required this.totalCount,
    required this.onOrderTap,
  });

  final List<CommercialOrder> orders;
  final int totalCount;
  final ValueChanged<CommercialOrder> onOrderTap;

  @override
  Widget build(BuildContext context) {
    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReportSectionHeader(
            title: "Détail des commandes",
            action: totalCount > 3 ? 'Voir tout' : null,
          ),
          SizedBox(height: 14),
          if (orders.isEmpty)
            _ReportEmptyLine("Aucune commande créée.")
          else
            for (var i = 0; i < orders.length; i++) ...[
              _ReportOrderRow(
                order: orders[i],
                onTap: () => onOrderTap(orders[i]),
              ),
              if (i != orders.length - 1) _ReportDivider(),
            ],
        ],
      ),
    );
  }
}

class _ReportCommentCard extends StatefulWidget {
  _ReportCommentCard({required this.controller, required this.hasReportData});

  final TextEditingController controller;
  final bool hasReportData;

  @override
  State<_ReportCommentCard> createState() => _ReportCommentCardState();
}

class _ReportCommentCardState extends State<_ReportCommentCard> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReportSectionHeader(title: "Commentaires de la journée"),
          SizedBox(height: 14),
          if (!widget.hasReportData)
            _ReportEmptyLine('Aucun commentaire pour le moment')
          else
            TextField(
              controller: widget.controller,
              minLines: 4,
              maxLines: 5,
              maxLength: 300,
              style: TextStyle(
                color: _HomeCommercialState.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: "Ajoutez votre compte-rendu de fin de journée...",
                hintStyle: TextStyle(color: _HomeCommercialState.textMuted),
                prefixIcon: Padding(
                  padding: EdgeInsets.fromLTRB(14, 12, 10, 0),
                  child: Icon(
                    Icons.format_quote_rounded,
                    color: _HomeCommercialState.primaryBlue,
                  ),
                ),
                prefixIconConstraints: BoxConstraints(minWidth: 46),
                alignLabelWithHint: true,
                filled: true,
                fillColor: _HomeCommercialState.cardBg,
                border: _reportInputBorder(),
                enabledBorder: _reportInputBorder(),
                focusedBorder: _reportInputBorder(
                  _HomeCommercialState.primaryBlue,
                  1.4,
                ),
                counterText: '${widget.controller.text.length}/300',
                counterStyle: TextStyle(
                  color: _HomeCommercialState.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportEmptyActionMessage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _ReportCard(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: _HomeCommercialState.primaryBlue,
            size: 22,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Ajoutez au moins une activité ou une commande pour générer le rapport.",
              style: TextStyle(
                color: _HomeCommercialState.textMuted,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportActionsBar extends StatelessWidget {
  _ReportActionsBar({
    required this.onDownload,
    required this.onSend,
    required this.enabled,
    required this.reportSent,
  });

  final VoidCallback onDownload;
  final VoidCallback onSend;
  final bool enabled;
  final bool reportSent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: _HomeCommercialState.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 18,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: enabled ? onDownload : null,
              icon: Icon(Icons.download_rounded),
              label: Text("Télécharger PDF"),
              style: OutlinedButton.styleFrom(
                foregroundColor: _HomeCommercialState.primaryBlue,
                side: BorderSide(color: _HomeCommercialState.primaryBlue),
                minimumSize: Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: enabled ? onSend : null,
              icon: Icon(Icons.send_rounded),
              label: Text(reportSent ? "Rapport envoyé" : "Envoyer au manager"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _HomeCommercialState.primaryBlue,
                foregroundColor: Colors.white,
                minimumSize: Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitTimelineRow extends StatelessWidget {
  _VisitTimelineRow({
    required this.visit,
    required this.isLast,
    required this.onTap,
  });

  final _CommercialActivityItem visit;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final realized = visit.status == _CommercialActivityStatus.done;
    final color = realized ? Color(0xFF22C55E) : Color(0xFFEF4444);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 2,
                      height: 14,
                      color: color.withValues(alpha: .25),
                    ),
                    CircleAvatar(radius: 4, backgroundColor: color),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 54,
                        color: color.withValues(alpha: .25),
                      ),
                  ],
                ),
                SizedBox(width: 12),
                Text(
                  visit.time,
                  style: TextStyle(
                    color: _HomeCommercialState.textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          _ReportRoundIcon(icon: visit.icon, color: color),
          SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visit.subtitle.isEmpty ? visit.title : visit.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _HomeCommercialState.textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    visit.location.isEmpty ? 'Casablanca' : visit.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _HomeCommercialState.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _ReportBadge(
            label: realized ? 'Visite réalisée' : 'Visite planifiée',
            color: color,
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: _HomeCommercialState.textMuted,
          ),
        ],
      ),
    );
  }
}

class _ReportOrderRow extends StatelessWidget {
  _ReportOrderRow({required this.order, required this.onTap});

  final CommercialOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _reportOrderStatusColor(order.status);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            _ReportRoundIcon(icon: Icons.receipt_long_rounded, color: color),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.orderNumber,
                    style: TextStyle(
                      color: _HomeCommercialState.textDark,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    order.clientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _HomeCommercialState.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _orderDisplayTime(order),
              style: TextStyle(
                color: _HomeCommercialState.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(width: 14),
            Text(
              _reportMoney(order.total),
              style: TextStyle(
                color: _HomeCommercialState.textDark,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(width: 10),
            _ReportBadge(label: order.status.label, color: color),
            Icon(
              Icons.chevron_right_rounded,
              color: _HomeCommercialState.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  _ReportCard({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _HomeCommercialState.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _reportBorderColor()),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ReportSectionHeader extends StatelessWidget {
  _ReportSectionHeader({required this.title, this.action});

  final String title;
  final String? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: _HomeCommercialState.textDark,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (action != null)
          Text(
            action!,
            style: TextStyle(
              color: _HomeCommercialState.primaryBlue,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
      ],
    );
  }
}

class _ReportMetaLine extends StatelessWidget {
  _ReportMetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _HomeCommercialState.primaryBlue, size: 20),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _HomeCommercialState.textDark,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportIconButton extends StatelessWidget {
  _ReportIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: _HomeCommercialState.primaryBlue.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: _HomeCommercialState.primaryBlue),
      ),
    );
  }
}

class _ReportKpiData {
  _ReportKpiData(this.icon, this.color, this.value, this.label, this.evolution);

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String evolution;
}

class _ReportKpiTile extends StatelessWidget {
  _ReportKpiTile({required this.data});

  final _ReportKpiData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          _ReportRoundIcon(icon: data.icon, color: data.color),
          SizedBox(height: 10),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _HomeCommercialState.textDark,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            data.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _HomeCommercialState.textMuted,
              fontSize: 11,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (data.evolution.isNotEmpty) ...[
            SizedBox(height: 5),
            Text(
              data.evolution,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF22C55E),
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ObjectiveMiniCard extends StatelessWidget {
  _ObjectiveMiniCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.suffix,
    required this.percent,
    required this.gap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String suffix;
  final double percent;
  final String gap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _HomeCommercialState.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _reportBorderColor()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ReportRoundIcon(icon: icon, color: color, size: 32),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _HomeCommercialState.textDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${(percent * 100).round()}%',
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            suffix,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _HomeCommercialState.textDark,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 9,
              backgroundColor: _reportBorderColor(),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          SizedBox(height: 9),
          Text(
            gap,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _HomeCommercialState.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportRoundIcon extends StatelessWidget {
  _ReportRoundIcon({required this.icon, required this.color, this.size = 40});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: size * .52),
    );
  }
}

class _ReportBadge extends StatelessWidget {
  _ReportBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ReportDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: _reportBorderColor());
  }
}

class _ReportEmptyLine extends StatelessWidget {
  _ReportEmptyLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Text(
        text,
        style: TextStyle(
          color: _HomeCommercialState.textMuted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

OutlineInputBorder _reportInputBorder([Color? color, double width = 1]) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: color ?? _reportBorderColor(), width: width),
  );
}

Color _reportBorderColor() {
  return ThemeData.estimateBrightnessForColor(_HomeCommercialState.cardBg) ==
          Brightness.dark
      ? const Color(0xFF334155)
      : const Color(0xFFE2E8F0);
}

DateTime? _latestOrderDate(List<CommercialOrder> orders) {
  final dates = orders
      .map((order) => _parseOrderDate(order.date))
      .nonNulls
      .toList();
  if (dates.isEmpty) return null;
  dates.sort();
  return dates.last;
}

CommercialClient? _clientForVisit(
  TourVisit visit,
  List<CommercialClient> clients,
) {
  for (final client in clients) {
    if (client.id == visit.clientId) return client;
  }
  return null;
}

String _primaryCity(List<CommercialClient> clients) {
  if (clients.isEmpty) return 'Casablanca';
  final casablanca = clients.where(
    (client) => client.city.toLowerCase().contains('casablanca'),
  );
  return casablanca.isNotEmpty ? casablanca.first.city : clients.first.city;
}

String _dailyReportDateLabel(DateTime date) {
  const days = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];
  const months = [
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
  ];
  return '${days[date.weekday - 1]} ${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
}

String _reportMoney(num value) {
  final rounded = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < rounded.length; i++) {
    final fromEnd = rounded.length - i;
    buffer.write(rounded[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write(' ');
  }
  return '${buffer.toString()} DH';
}

Color _reportOrderStatusColor(OrderStatus status) {
  return switch (status) {
    OrderStatus.delivered => Color(0xFF22C55E),
    OrderStatus.synced => _HomeCommercialState.primaryBlue,
    OrderStatus.pending => Color(0xFFF59E0B),
    OrderStatus.cancelled => Color(0xFFEF4444),
  };
}

String _orderDisplayTime(CommercialOrder order) {
  final seed = order.id % 5;
  return switch (seed) {
    0 => '08:45',
    1 => '09:15',
    2 => '10:30',
    3 => '14:20',
    _ => '16:10',
  };
}

int mathMax(int left, int right) => left > right ? left : right;

double mathMaxDouble(double left, double right) => left > right ? left : right;

class _CommercialHomeHeader extends StatelessWidget {
  _CommercialHomeHeader({
    required this.userName,
    required this.onNotificationTap,
    required this.unreadNotificationCount,
    required this.onAvatarTap,
  });

  final String userName;
  final VoidCallback onNotificationTap;
  final int unreadNotificationCount;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${AppLocalizations.globalText('Bonjour')}, $userName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _DashboardTab._navy,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    AppLocalizations.globalText(
                      'Suivez vos performances commerciales',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10),
            _CommercialNotificationButton(
              onTap: onNotificationTap,
              unreadCount: unreadNotificationCount,
            ),
            SizedBox(width: 10),
            GestureDetector(
              onTap: onAvatarTap,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE2E8F0),
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF0F172A).withValues(alpha: .08),
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: _DashboardTab._navy,
                      size: 31,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: _DashboardTab._green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            _HeaderMetaPill(
              icon: Icons.business_center_outlined,
              label: AppLocalizations.globalText('Commercial Senior'),
            ),
            SizedBox(width: 10),
            _HeaderMetaPill(
              icon: Icons.location_on_outlined,
              label: AppLocalizations.globalText('Casablanca'),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeaderMetaPill extends StatelessWidget {
  _HeaderMetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Color(0xFF64748B), size: 17),
          ),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF475569),
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

class _DashboardMetrics {
  _DashboardMetrics({
    required this.ordersToday,
    required this.pendingOrders,
    required this.visitedClients,
    required this.monthlyRevenue,
    required this.monthlyTarget,
    required this.monthlyOrders,
    required this.orderTarget,
    required this.ordersEvolution,
    required this.revenueEvolution,
    required this.visitsEvolution,
    required this.weeklyRevenue,
    required this.weeklyRevenueByDay,
    required this.previousWeeklyRevenue,
    required this.hasOrders,
    required this.objective,
    required this.ranking,
  });

  factory _DashboardMetrics.from({
    required CommercialDashboardSummary summary,
    required List<CommercialOrder> orders,
    required List<TourVisit> visits,
    required List<_CommercialActivityItem> createdActivities,
    required CommercialObjective? objective,
    required _CommercialRanking ranking,
  }) {
    final today = DateUtils.dateOnly(DateTime.now());
    final monthStart = DateTime(today.year, today.month);
    final nextMonth = today.month == 12
        ? DateTime(today.year + 1)
        : DateTime(today.year, today.month + 1);
    final validatedMonthlyOrders = orders.where((order) {
      final date = _parseOrderDate(order.date);
      return date != null &&
          !date.isBefore(monthStart) &&
          date.isBefore(nextMonth) &&
          _isValidatedStatus(order.status);
    }).toList();
    final ordersToday = orders.where((order) {
      final date = _parseOrderDate(order.date);
      return date != null && DateUtils.isSameDay(date, today);
    }).length;
    final monthlyRevenue = validatedMonthlyOrders.fold<double>(
      0,
      (total, order) => total + order.total,
    );
    final weeklyStart = today.subtract(Duration(days: 6));
    final previousWeeklyStart = today.subtract(Duration(days: 13));
    final weeklyRevenueByDay = List<double>.generate(7, (index) {
      final day = weeklyStart.add(Duration(days: index));
      return orders.fold<double>(0, (total, order) {
        final date = _parseOrderDate(order.date);
        if (date == null || !DateUtils.isSameDay(date, day)) {
          return total;
        }
        return total + order.total;
      });
    });
    final weeklyRevenue = weeklyRevenueByDay.fold<double>(
      0,
      (total, value) => total + value,
    );
    final previousWeeklyRevenue = orders.fold<double>(0, (total, order) {
      final date = _parseOrderDate(order.date);
      if (date == null ||
          date.isBefore(previousWeeklyStart) ||
          !date.isBefore(weeklyStart)) {
        return total;
      }
      return total + order.total;
    });
    final revenueEvolution = _periodEvolution(
      weeklyRevenue,
      previousWeeklyRevenue,
    );

    return _DashboardMetrics(
      ordersToday: ordersToday,
      pendingOrders: orders
          .where((order) => order.status == OrderStatus.pending)
          .length,
      visitedClients:
          visits
              .where((visit) => visit.status == TourVisitStatus.visited)
              .length +
          createdActivities
              .where(
                (activity) =>
                    activity.title == 'Visite client' &&
                    activity.status == _CommercialActivityStatus.done,
              )
              .length,
      monthlyRevenue: monthlyRevenue,
      monthlyTarget: objective?.revenueTarget,
      monthlyOrders: validatedMonthlyOrders.length,
      orderTarget: objective?.orderTarget,
      ordersEvolution: 0,
      revenueEvolution: revenueEvolution,
      visitsEvolution: 0,
      weeklyRevenue: weeklyRevenue,
      weeklyRevenueByDay: weeklyRevenueByDay,
      previousWeeklyRevenue: previousWeeklyRevenue,
      hasOrders: orders.isNotEmpty,
      objective: objective,
      ranking: ranking,
    );
  }

  final int ordersToday;
  final int pendingOrders;
  final int visitedClients;
  final double monthlyRevenue;
  final double? monthlyTarget;
  final int monthlyOrders;
  final int? orderTarget;
  final int ordersEvolution;
  final int revenueEvolution;
  final int visitsEvolution;
  final double weeklyRevenue;
  final List<double> weeklyRevenueByDay;
  final double previousWeeklyRevenue;
  final bool hasOrders;
  final CommercialObjective? objective;
  final _CommercialRanking ranking;

  bool get hasOrderTarget => objective?.hasOrderTarget == true;
  bool get hasRevenueTarget => objective?.hasRevenueTarget == true;
  double get orderProgress =>
      hasOrderTarget ? (monthlyOrders / orderTarget!).clamp(0, 1) : 0;
  double get revenueProgress =>
      hasRevenueTarget ? (monthlyRevenue / monthlyTarget!).clamp(0, 1) : 0;
  int? get orderPercent =>
      hasOrderTarget ? (orderProgress * 100).round() : null;
  int? get revenuePercent =>
      hasRevenueTarget ? (revenueProgress * 100).round() : null;
  bool get rankingAvailable => ranking.hasActivity;
}

int _periodEvolution(double current, double previous) {
  if (previous <= 0) return current > 0 ? 100 : 0;
  return (((current - previous) / previous) * 100).round();
}

CommercialClient? _clientById(List<CommercialClient> clients, int id) {
  for (final client in clients) {
    if (client.id == id) return client;
  }
  return null;
}

String _signedPercent(int value) {
  if (value == 0) return '0%';
  return value > 0 ? '+$value%' : '$value%';
}

class _DailyObjectiveCard extends StatelessWidget {
  _DailyObjectiveCard({required this.metrics});

  final _DashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_DashboardTab._navy, _DashboardTab._blue],
        ),
        boxShadow: [
          BoxShadow(
            color: _DashboardTab._blue.withValues(alpha: .24),
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.globalText('Performance commerciale'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.stacked_line_chart_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ],
                ),
                SizedBox(height: 18),
                Text(
                  AppLocalizations.globalText('Objectif mensuel'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 9),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    metrics.hasOrderTarget
                        ? '${metrics.monthlyOrders} / ${metrics.orderTarget} commandes'
                        : 'Objectif non défini',
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: metrics.hasOrderTarget ? 24 : 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (metrics.hasOrderTarget) ...[
                  SizedBox(height: 5),
                  Text(
                    '${metrics.orderPercent}%',
                    maxLines: 1,
                    style: TextStyle(
                      color: _DashboardTab._green,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
                SizedBox(height: 13),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: metrics.orderProgress),
                  duration: Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: metrics.hasOrderTarget ? value : 0,
                        backgroundColor: _HomeCommercialState.cardBg.withValues(
                          alpha: .24,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _DashboardTab._green,
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                  decoration: BoxDecoration(
                    color: _DashboardTab._green.withValues(alpha: .22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.trending_up_rounded,
                        color: _DashboardTab._green,
                        size: 17,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          AppLocalizations.globalText(
                            metrics.hasOrders
                                ? 'En bonne progression'
                                : metrics.hasOrderTarget
                                ? 'Aucune donnée'
                                : 'Objectif non défini',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                _ObjectiveMiniProgress(
                  title: 'Objectif CA du mois',
                  value: metrics.hasRevenueTarget
                      ? '${_money(metrics.monthlyRevenue)} / ${_money(metrics.monthlyTarget!)} DH'
                      : 'Objectif non défini',
                  percent: metrics.revenuePercent,
                  progress: metrics.revenueProgress,
                  color: Color(0xFFA855F7),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 150,
            margin: EdgeInsets.symmetric(horizontal: 15),
            color: Colors.white.withValues(alpha: .28),
          ),
          Expanded(
            flex: 4,
            child: metrics.rankingAvailable
                ? Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .13),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            AppLocalizations.globalText('\u{1F3C6}'),
                            style: TextStyle(fontSize: 30),
                          ),
                        ),
                      ),
                      SizedBox(height: 9),
                      Text(
                        AppLocalizations.globalText('Rang actuel'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '#${metrics.ranking.rank}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        AppLocalizations.globalText(
                          'sur ${metrics.ranking.totalCommercials} commerciaux',
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFFD9E6FF),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 14),
                      _PerformanceTrendBox(
                        value: _signedPercent(metrics.revenueEvolution),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .13),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.insights_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        AppLocalizations.globalText('Classement indisponible'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        AppLocalizations.globalText(
                          'Aucun commercial n’a encore d’activité validée.',
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFFD9E6FF),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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

class _ObjectiveMiniProgress extends StatelessWidget {
  _ObjectiveMiniProgress({
    required this.title,
    required this.value,
    required this.percent,
    required this.progress,
    required this.color,
  });

  final String title;
  final String value;
  final int? percent;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.globalText(title),
                  softWrap: true,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (percent != null)
                Text(
                  '$percent%',
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: Color(0xFFD9E6FF),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: .22),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceTrendBox extends StatelessWidget {
  _PerformanceTrendBox({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.trending_up_rounded,
            color: _DashboardTab._green,
            size: 27,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  AppLocalizations.globalText('vs semaine précédente'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFFD9E6FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
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

class _QuickStatsGrid extends StatelessWidget {
  _QuickStatsGrid({required this.metrics});

  final _DashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final stats = [
      _QuickStatData(
        Icons.business_center_rounded,
        '${metrics.ordersToday}',
        "Commandes\naujourd'hui",
        _DashboardTab._blue,
      ),
      _QuickStatData(
        Icons.schedule_rounded,
        '${metrics.pendingOrders}',
        'En attente',
        _DashboardTab._orange,
      ),
      _QuickStatData(
        Icons.groups_rounded,
        '${metrics.visitedClients}',
        'Clients visit\u00E9s',
        _DashboardTab._green,
      ),
      _QuickStatData(
        Icons.monetization_on_outlined,
        '${_money(metrics.monthlyRevenue)} DH',
        'CA du mois',
        Color(0xFF7C3AED),
      ),
    ];

    return GridView.builder(
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: stats.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.34,
      ),
      itemBuilder: (context, index) => _QuickStatCard(data: stats[index]),
    );
  }
}

class _QuickStatData {
  _QuickStatData(this.icon, this.value, this.label, this.color);

  final IconData icon;
  final String value;
  final String label;
  final Color color;
}

class _QuickStatCard extends StatelessWidget {
  _QuickStatCard({required this.data});

  final _QuickStatData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(13, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0F172A).withValues(alpha: .06),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(data.icon, color: data.color, size: 19),
              ),
              Spacer(),
            ],
          ),
          SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              data.value,
              maxLines: 1,
              style: TextStyle(
                color: _DashboardTab._navy,
                fontSize: 26,
                height: .95,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: Text(
              AppLocalizations.globalText(data.label),
              maxLines: 2,
              overflow: TextOverflow.clip,
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11.5,
                height: 1.05,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesEvolutionCard extends StatelessWidget {
  _SalesEvolutionCard({required this.metrics});

  final _DashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final weeklyRevenue = metrics.weeklyRevenue;
    final weeklyEvolution = metrics.hasOrders ? metrics.revenueEvolution : 0;
    final title = AppLocalizations.globalText('Évolution des ventes');

    if (!metrics.hasOrders) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(16, 16, 16, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF0F172A).withValues(alpha: .055),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _DashboardTab._navy,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 18),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.show_chart_rounded,
                      color: _DashboardTab._blue,
                      size: 30,
                    ),
                  ),
                  SizedBox(height: 14),
                  Text(
                    AppLocalizations.globalText(
                      'Aucune donnée de vente disponible',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _DashboardTab._navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    AppLocalizations.globalText(
                      'Les statistiques apparaîtront après les premières commandes.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0F172A).withValues(alpha: .055),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _DashboardTab._navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                AppLocalizations.globalText('7 derniers jours'),
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 6,
                child: SizedBox(
                  height: 116,
                  child: _SalesChart(
                    label: '${_money(weeklyRevenue)} DH',
                    values: metrics.weeklyRevenueByDay,
                    hasData: metrics.hasOrders,
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.globalText('CA 7 derniers jours'),
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AppLocalizations.globalText(
                          '${_money(weeklyRevenue)} DH',
                        ),
                        maxLines: 1,
                        style: TextStyle(
                          color: _DashboardTab._navy,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      _signedPercent(weeklyEvolution),
                      style: TextStyle(
                        color: _DashboardTab._green,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      AppLocalizations.globalText('vs 7 jours précédents'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
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

class _SalesChart extends StatelessWidget {
  _SalesChart({
    required this.label,
    required this.values,
    required this.hasData,
  });

  final String label;
  final List<double> values;
  final bool hasData;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SalesChartPainter(
        label: label,
        values: values,
        hasData: hasData,
      ),
      child: SizedBox.expand(),
    );
  }
}

class _SalesChartPainter extends CustomPainter {
  _SalesChartPainter({
    required this.label,
    required this.values,
    required this.hasData,
  });

  final String label;
  final List<double> values;
  final bool hasData;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(28, 8, size.width - 34, size.height - 34);
    final chartValues = hasData && values.isNotEmpty
        ? values
        : List<double>.filled(7, 0);
    final maxValue = _maxChartValue(chartValues);
    final days = ['Ven', 'Sam', 'Dim', 'Lun', 'Mar', 'Mer', 'Jeu'];
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    final labelStyle = TextStyle(
      color: Color(0xFF475569),
      fontSize: 9,
      fontWeight: FontWeight.w500,
    );

    for (var i = 0; i < 4; i++) {
      final y = chart.top + chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }

    for (final entry in {
      '30K': 0.0,
      '20K': .35,
      '10K': .68,
      '0': 1.0,
    }.entries) {
      _drawText(
        canvas,
        entry.key,
        Offset(0, chart.top + chart.height * entry.value - 6),
        labelStyle,
      );
    }

    final points = <Offset>[];
    for (var i = 0; i < chartValues.length; i++) {
      final x = chart.left + chart.width * i / (chartValues.length - 1);
      final y = chart.bottom - chart.height * (chartValues[i] / maxValue);
      points.add(Offset(x, y));
      _drawText(
        canvas,
        days[i % days.length],
        Offset(x - 10, chart.bottom + 10),
        labelStyle,
      );
    }

    final fill = Path()..moveTo(points.first.dx, chart.bottom);
    for (final point in points) {
      fill.lineTo(point.dx, point.dy);
    }
    fill.lineTo(points.last.dx, chart.bottom);
    fill.close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _DashboardTab._blue.withValues(alpha: .20),
            _DashboardTab._blue.withValues(alpha: .02),
          ],
        ).createShader(chart),
    );

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final midX = (previous.dx + current.dx) / 2;
      line.cubicTo(midX, previous.dy, midX, current.dy, current.dx, current.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = _DashboardTab._blue
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    for (final point in points) {
      canvas.drawCircle(point, 5, Paint()..color = Colors.white);
      canvas.drawCircle(
        point,
        5,
        Paint()
          ..color = _DashboardTab._blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    final selected = points[5];
    final bubble = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: selected.translate(0, -18),
        width: 70,
        height: 24,
      ),
      Radius.circular(6),
    );
    canvas.drawRRect(bubble, Paint()..color = _DashboardTab._blue);
    _drawText(
      canvas,
      label,
      selected.translate(-28, -26),
      TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
    );
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _SalesChartPainter oldDelegate) {
    return oldDelegate.label != label ||
        oldDelegate.hasData != hasData ||
        oldDelegate.values != values;
  }
}

double _maxChartValue(List<double> values) {
  var maxValue = 0.0;
  for (final value in values) {
    if (value > maxValue) maxValue = value;
  }
  return maxValue <= 0 ? 1 : maxValue * 1.2;
}

class _QuickActionsGrid extends StatelessWidget {
  _QuickActionsGrid({
    required this.onNewOrder,
    required this.onNewClient,
    required this.onVisit,
    required this.onReport,
  });

  final VoidCallback onNewOrder;
  final VoidCallback onNewClient;
  final VoidCallback onVisit;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 4,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: .62,
      children: [
        _QuickActionCard(
          title: AppLocalizations.globalText('Nouvelle\ncommande'),
          subtitle: AppLocalizations.globalText('Cr\u00E9er une commande'),
          icon: Icons.add_rounded,
          color: _DashboardTab._blue,
          inverted: true,
          onTap: onNewOrder,
        ),
        _QuickActionCard(
          title: AppLocalizations.globalText('Nouveau\nclient'),
          subtitle: AppLocalizations.globalText('Ajouter un client'),
          icon: Icons.person_add_alt_rounded,
          color: _DashboardTab._blue,
          onTap: onNewClient,
        ),
        _QuickActionCard(
          title: AppLocalizations.globalText('Nouvelle\nactivité'),
          subtitle: AppLocalizations.globalText('Planifier une activité'),
          icon: Icons.calendar_month_rounded,
          color: _DashboardTab._green,
          onTap: onVisit,
        ),
        _QuickActionCard(
          title: AppLocalizations.globalText('Rapport\njournalier'),
          subtitle: AppLocalizations.globalText('Voir le rapport'),
          icon: Icons.bar_chart_rounded,
          color: Color(0xFF7C3AED),
          onTap: onReport,
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.inverted = false,
  });

  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: EdgeInsets.fromLTRB(11, 11, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: inverted ? color : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Color(0xFF0F172A).withValues(alpha: .06),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: inverted ? Colors.white : color.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: inverted ? color : color, size: 21),
              ),
              Spacer(),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: inverted ? Colors.white : _DashboardTab._navy,
                  fontSize: 11,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: inverted
                      ? Colors.white.withValues(alpha: .90)
                      : Color(0xFF475569),
                  fontSize: 8.8,
                  height: 1.15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: inverted ? Colors.white : Color(0xFF64748B),
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  _SectionTitle({required this.title, this.action, this.onActionTap});

  final String title;
  final String? action;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: _DashboardTab._navy,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onActionTap,
            style: TextButton.styleFrom(
              foregroundColor: _DashboardTab._blue,
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              AppLocalizations.globalText(action!),
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

class _RecentOrderCard extends StatelessWidget {
  _RecentOrderCard({required this.order, required this.onTap});

  final CommercialOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = _dashboardStatusColor(order.status);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF0F172A).withValues(alpha: .055),
                blurRadius: 18,
                offset: Offset(0, 9),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_orderStatusIcon(order.status), color: statusColor),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderNumber,
                      style: TextStyle(
                        color: _DashboardTab._navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${AppLocalizations.globalText('Client')} : ${order.clientName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${_money(order.total)} DH',
                          style: TextStyle(
                            color: _DashboardTab._navy,
                            fontSize: 13,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Color(0xFFCBD5E1),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${order.productsCount} articles',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _DashboardStatusBadge(status: order.status),
                  SizedBox(height: 14),
                  Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardEmptyCard extends StatelessWidget {
  _DashboardEmptyCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0F172A).withValues(alpha: .055),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _DashboardTab._blue.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _DashboardTab._blue),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.globalText(message),
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardStatusBadge extends StatelessWidget {
  _DashboardStatusBadge({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _dashboardStatusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _dashboardStatusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _dashboardStatusLabel(OrderStatus status) {
  return _commercialOrderStatusLabel(status);
}

Color _dashboardStatusColor(OrderStatus status) {
  return _orderStatusColor(status);
}

class _RecentActivityCard extends StatelessWidget {
  _RecentActivityCard({required this.items, required this.onTap});

  final List<_ActivityHistoryItem> items;
  final ValueChanged<_ActivityHistoryItem> onTap;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final yesterday = today.subtract(Duration(days: 1));
    final visibleItems = [...items]
      ..sort((a, b) {
        final dateCompare = b.date.compareTo(a.date);
        if (dateCompare != 0) return dateCompare;
        return b.timeLabel.compareTo(a.timeLabel);
      });
    final limitedItems = visibleItems.take(3).toList();
    final todayItems = limitedItems
        .where((item) => DateUtils.isSameDay(item.date, today))
        .toList();
    final yesterdayItems = limitedItems
        .where((item) => DateUtils.isSameDay(item.date, yesterday))
        .toList();
    final weekItems = limitedItems
        .where(
          (item) =>
              !DateUtils.isSameDay(item.date, today) &&
              !DateUtils.isSameDay(item.date, yesterday),
        )
        .toList();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0F172A).withValues(alpha: .055),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (limitedItems.isEmpty)
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _DashboardTab._blue.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    color: _DashboardTab._blue,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.globalText('Aucune activité récente'),
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          if (todayItems.isNotEmpty)
            _RecentActivityGroup(
              label: 'Aujourd’hui',
              items: todayItems,
              onTap: onTap,
            ),
          if (todayItems.isNotEmpty &&
              (yesterdayItems.isNotEmpty || weekItems.isNotEmpty))
            SizedBox(height: 12),
          if (yesterdayItems.isNotEmpty)
            _RecentActivityGroup(
              label: 'Hier',
              items: yesterdayItems,
              onTap: onTap,
            ),
          if (yesterdayItems.isNotEmpty && weekItems.isNotEmpty)
            SizedBox(height: 12),
          if (weekItems.isNotEmpty)
            _RecentActivityGroup(
              label: 'Cette semaine',
              items: weekItems,
              onTap: onTap,
            ),
        ],
      ),
    );
  }
}

class _RecentActivityGroup extends StatelessWidget {
  _RecentActivityGroup({
    required this.label,
    required this.items,
    required this.onTap,
  });

  final String label;
  final List<_ActivityHistoryItem> items;
  final ValueChanged<_ActivityHistoryItem> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.globalText(label),
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 8),
        for (var i = 0; i < items.length; i++) ...[
          _ActivityStep(item: items[i], onTap: () => onTap(items[i])),
          if (i != items.length - 1)
            Divider(height: 18, color: Color(0xFFE8EEF7)),
        ],
      ],
    );
  }
}

class _ActivityStep extends StatelessWidget {
  _ActivityStep({required this.item, required this.onTap});

  final _ActivityHistoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  item.timeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(width: 10),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.globalText(item.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _DashboardTab._navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      AppLocalizations.globalText(item.subtitle),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}

final Set<String> _readCommercialNotificationIds = <String>{};
final ValueNotifier<int> _commercialNotificationRevision = ValueNotifier<int>(
  0,
);

class CommercialNotificationsPage extends StatefulWidget {
  CommercialNotificationsPage({super.key});

  @override
  State<CommercialNotificationsPage> createState() =>
      _CommercialNotificationsPageState();
}

class _CommercialNotificationsPageState
    extends State<CommercialNotificationsPage> {
  _NotificationFilter _selectedFilter = _NotificationFilter.all;
  late final String _email;
  late final String _userName;
  late List<_CommercialNotification> _notifications;

  @override
  void initState() {
    super.initState();
    final user = CurrentUserSession.currentUser;
    _email = user?.email ?? '';
    _userName = user?.fullName ?? '';
    _notifications = _buildNotificationsForCurrentUser();
  }

  List<_CommercialNotification> get _visibleNotifications {
    return _notifications.where((notification) {
      return switch (_selectedFilter) {
        _NotificationFilter.all => true,
        _NotificationFilter.unread => !notification.isRead,
        _NotificationFilter.orders =>
          notification.type == _NotificationType.order,
        _NotificationFilter.clients =>
          notification.type == _NotificationType.client,
        _NotificationFilter.system =>
          notification.type == _NotificationType.system,
      };
    }).toList();
  }

  int get _unreadCount =>
      _notifications.where((notification) => !notification.isRead).length;

  void _markAllAsRead() {
    setState(() {
      _readCommercialNotificationIds.addAll(
        _notifications.map((notification) => notification.id),
      );
      _notifications = [
        for (final notification in _notifications)
          notification.copyWith(isRead: true),
      ];
    });
    _commercialNotificationRevision.value++;
  }

  void _openNotification(_CommercialNotification notification) {
    setState(() {
      _readCommercialNotificationIds.add(notification.id);
      _notifications = [
        for (final item in _notifications)
          item.id == notification.id ? item.copyWith(isRead: true) : item,
      ];
    });
    _commercialNotificationRevision.value++;

    final user = MockPreSalesData.userByEmail(_email);
    if (notification.orderId != null) {
      final orders = [
        ...MockPreSalesData.ordersForUser(user),
        ..._runtimeOrdersForEmail(_email),
      ];
      for (final order in orders) {
        if (order.id == notification.orderId) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DetailCommande(order: order)),
          );
          return;
        }
      }
    }

    if (notification.clientId != null) {
      final clients = [
        ...MockPreSalesData.clientsForUser(user),
        ..._runtimeClientsForEmail(_email),
      ];
      for (final client in clients) {
        if (client.id == notification.clientId) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetailClient(
                client: client,
                currentEmail: _email,
                currentUserName: _userName,
              ),
            ),
          );
          return;
        }
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DailyReportNotificationPage(commercialName: _userName),
      ),
    );
  }

  void _navigateFromBottom(int index) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home-commercial',
      (route) => false,
      arguments: {'initialIndex': index},
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _visibleNotifications;

    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final phoneWidth = constraints.maxWidth > 428
                ? 428.0
                : constraints.maxWidth;
            return Center(
              child: SizedBox(
                width: phoneWidth,
                height: constraints.maxHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF18315E).withValues(alpha: .08),
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Column(
                      children: [
                        Expanded(
                          child: CustomScrollView(
                            physics: BouncingScrollPhysics(),
                            slivers: [
                              SliverPadding(
                                padding: EdgeInsets.fromLTRB(20, 24, 20, 20),
                                sliver: SliverList(
                                  delegate: SliverChildListDelegate([
                                    _NotificationsHeader(
                                      unreadCount: _unreadCount,
                                      onBack: () => Navigator.pop(context),
                                      onMarkAllRead: _markAllAsRead,
                                    ),
                                    SizedBox(height: 22),
                                    _NotificationFilterTabs(
                                      selectedFilter: _selectedFilter,
                                      onChanged: (filter) {
                                        setState(
                                          () => _selectedFilter = filter,
                                        );
                                      },
                                    ),
                                    SizedBox(height: 18),
                                    if (notifications.isEmpty)
                                      _EmptyNotifications()
                                    else
                                      _NotificationsCard(
                                        notifications: notifications,
                                        onTap: _openNotification,
                                      ),
                                  ]),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _CommercialBottomNav(
                          selectedIndex: -1,
                          onChanged: _navigateFromBottom,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationsHeader extends StatelessWidget {
  _NotificationsHeader({
    required this.unreadCount,
    required this.onBack,
    required this.onMarkAllRead,
  });

  final int unreadCount;
  final VoidCallback onBack;
  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 42,
          height: 42,
          child: IconButton(
            onPressed: onBack,
            padding: EdgeInsets.zero,
            icon: Icon(Icons.arrow_back_rounded, size: 28),
            color: Color(0xFF0F172A),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            AppLocalizations.globalText('Notifications'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        TextButton(
          onPressed: unreadCount == 0 ? null : onMarkAllRead,
          style: TextButton.styleFrom(
            foregroundColor: Color(0xFF2563EB),
            disabledForegroundColor: Color(0xFF94A3B8),
            padding: EdgeInsets.symmetric(horizontal: 8),
          ),
          child: Text(
            AppLocalizations.globalText('Tout marquer lu'),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _NotificationFilterTabs extends StatelessWidget {
  _NotificationFilterTabs({
    required this.selectedFilter,
    required this.onChanged,
  });

  final _NotificationFilter selectedFilter;
  final ValueChanged<_NotificationFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: BouncingScrollPhysics(),
        itemCount: _NotificationFilter.values.length,
        separatorBuilder: (context, index) => SizedBox(width: 9),
        itemBuilder: (context, index) {
          final filter = _NotificationFilter.values[index];
          final selected = selectedFilter == filter;
          return InkWell(
            onTap: () => onChanged(filter),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 180),
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: 17),
              decoration: BoxDecoration(
                color: selected ? Color(0xFF2563EB) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? Color(0xFF2563EB) : Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  if (selected)
                    BoxShadow(
                      color: Color(0xFF2563EB).withValues(alpha: .18),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                ],
              ),
              child: Text(
                filter.label,
                style: TextStyle(
                  color: selected ? Colors.white : Color(0xFF475569),
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationsCard extends StatelessWidget {
  _NotificationsCard({required this.notifications, required this.onTap});

  final List<_CommercialNotification> notifications;
  final ValueChanged<_CommercialNotification> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFFE8EEF7)),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0F172A).withValues(alpha: .055),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < notifications.length; i++) ...[
            _NotificationRow(
              notification: notifications[i],
              onTap: () => onTap(notifications[i]),
            ),
            if (i != notifications.length - 1)
              Divider(height: 1, color: Color(0xFFE8EEF7)),
          ],
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  _NotificationRow({required this.notification, required this.onTap});

  final _CommercialNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = notification.style;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 11,
                child: notification.isRead
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
              SizedBox(width: 9),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(style.icon, color: style.color, size: 29),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            AppLocalizations.globalText(notification.title),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 15,
                              fontWeight: notification.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          AppLocalizations.globalText(notification.timeLabel),
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 7),
                    Text(
                      AppLocalizations.globalText(notification.message),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 13,
                        height: 1.28,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF64748B),
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, 38, 24, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Color(0xFFE8EEF7)),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0F172A).withValues(alpha: .05),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: Color(0xFF2563EB).withValues(alpha: .08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF2563EB),
              size: 42,
            ),
          ),
          SizedBox(height: 20),
          Text(
            AppLocalizations.globalText('Aucune notification'),
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            AppLocalizations.globalText(
              'Les notifications relatives aux clients, commandes, activités et validations apparaîtront ici.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

enum _NotificationFilter { all, unread, orders, clients, system }

extension _NotificationFilterLabel on _NotificationFilter {
  String get label {
    return switch (this) {
      _NotificationFilter.all => AppLocalizations.globalText('Toutes'),
      _NotificationFilter.unread => AppLocalizations.globalText('Non lues'),
      _NotificationFilter.orders => AppLocalizations.globalText('Commandes'),
      _NotificationFilter.clients => AppLocalizations.globalText('Clients'),
      _NotificationFilter.system => AppLocalizations.globalText('Système'),
    };
  }
}

enum _NotificationType { order, client, system }

class _CommercialNotification {
  _CommercialNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.timeLabel,
    required this.userId,
    required this.isRead,
    this.orderId,
    this.clientId,
    required this.style,
  });

  final String id;
  final String title;
  final String message;
  final _NotificationType type;
  final DateTime createdAt;
  final String timeLabel;
  final int userId;
  final bool isRead;
  final int? orderId;
  final int? clientId;
  final _NotificationStyle style;

  _CommercialNotification copyWith({bool? isRead}) {
    return _CommercialNotification(
      id: id,
      title: title,
      message: message,
      type: type,
      createdAt: createdAt,
      timeLabel: timeLabel,
      userId: userId,
      isRead: isRead ?? this.isRead,
      orderId: orderId,
      clientId: clientId,
      style: style,
    );
  }
}

class _NotificationStyle {
  _NotificationStyle({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

final Map<String, List<_CommercialNotification>>
_runtimeCommercialNotificationsByEmail = {};

String _runtimeNotificationKey(String email) => email.toLowerCase().trim();

List<_CommercialNotification> _runtimeNotificationsForEmail(String email) {
  final notifications =
      _runtimeCommercialNotificationsByEmail[_runtimeNotificationKey(email)] ??
      const <_CommercialNotification>[];
  return [...notifications]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

void _addRuntimeCommercialNotification(
  String email,
  _CommercialNotification notification,
) {
  final key = _runtimeNotificationKey(email);
  final notifications = _runtimeCommercialNotificationsByEmail.putIfAbsent(
    key,
    () => [],
  );
  notifications.removeWhere((item) => item.id == notification.id);
  notifications.insert(0, notification);
  _commercialNotificationRevision.value++;
}

String _notificationTimeLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateUtils.dateOnly(now);
  final notificationDay = DateUtils.dateOnly(date);
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  if (DateUtils.isSameDay(notificationDay, today)) {
    return '$hour:$minute';
  }
  if (DateUtils.isSameDay(notificationDay, today.subtract(Duration(days: 1)))) {
    return 'Hier, $hour:$minute';
  }
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month, $hour:$minute';
}

int _notificationUserId(String email) {
  return MockPreSalesData.userByEmail(email)?.id ??
      CurrentUserSession.currentUser?.id ??
      0;
}

void _notifyClientAdded(String email, CommercialClient client) {
  final now = DateTime.now();
  _addRuntimeCommercialNotification(
    email,
    _CommercialNotification(
      id: 'runtime-client-added-${client.id}',
      title: 'Nouveau client ajouté',
      message: 'Le client "${client.name}" a été ajouté avec succès.',
      type: _NotificationType.client,
      createdAt: now,
      timeLabel: _notificationTimeLabel(now),
      userId: _notificationUserId(email),
      isRead: false,
      clientId: client.id,
      style: _NotificationStyle(
        icon: Icons.person_add_alt_rounded,
        color: Color(0xFF16A34A),
      ),
    ),
  );
}

void _notifyActivityPlanned(String email, _CommercialActivityItem activity) {
  final now = DateTime.now();
  _addRuntimeCommercialNotification(
    email,
    _CommercialNotification(
      id: 'runtime-activity-planned-${activity.id}',
      title: 'Nouvelle activité planifiée',
      message: '${activity.title} - ${activity.subtitle}',
      type: _NotificationType.system,
      createdAt: now,
      timeLabel: _notificationTimeLabel(now),
      userId: _notificationUserId(email),
      isRead: false,
      style: _NotificationStyle(
        icon: Icons.event_available_rounded,
        color: Color(0xFF2563EB),
      ),
    ),
  );
}

void _notifyOrderAction(String email, CommercialOrder order) {
  final now = DateTime.now();
  final statusData = switch (order.status) {
    OrderStatus.delivered => (
      id: 'validated',
      title: 'Commande validée',
      message: 'La commande ${order.orderNumber} a été validée.',
      icon: Icons.check_circle_outline_rounded,
      color: Color(0xFF16A34A),
    ),
    OrderStatus.cancelled => (
      id: 'rejected',
      title: 'Commande refusée',
      message: 'La commande ${order.orderNumber} a été refusée.',
      icon: Icons.cancel_outlined,
      color: Color(0xFFEF4444),
    ),
    OrderStatus.synced => (
      id: 'sent',
      title: 'Commande envoyée',
      message: 'La commande ${order.orderNumber} a été envoyée au manager.',
      icon: Icons.send_rounded,
      color: Color(0xFF2563EB),
    ),
    OrderStatus.pending => (
      id: 'pending',
      title: 'Commande créée',
      message: 'La commande ${order.orderNumber} est en attente de validation.',
      icon: Icons.receipt_long_rounded,
      color: Color(0xFFF59E0B),
    ),
  };
  _addRuntimeCommercialNotification(
    email,
    _CommercialNotification(
      id: 'runtime-order-${statusData.id}-${order.id}',
      title: statusData.title,
      message: statusData.message,
      type: _NotificationType.order,
      createdAt: now,
      timeLabel: _notificationTimeLabel(now),
      userId: _notificationUserId(email),
      isRead: false,
      orderId: order.id,
      style: _NotificationStyle(icon: statusData.icon, color: statusData.color),
    ),
  );
}

List<_CommercialNotification> _buildNotificationsForCurrentUser() {
  final user = CurrentUserSession.currentUser;
  final notifications = _runtimeNotificationsForEmail(user?.email ?? '');
  return [
    for (final notification in notifications)
      _readCommercialNotificationIds.contains(notification.id)
          ? notification.copyWith(isRead: true)
          : notification,
  ];
}

int _commercialUnreadNotificationCount() {
  return _buildNotificationsForCurrentUser()
      .where((notification) => !notification.isRead)
      .length;
}

class _DailyReportNotificationPage extends StatelessWidget {
  _DailyReportNotificationPage({required this.commercialName});

  final String commercialName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final phoneWidth = constraints.maxWidth > 428
                ? 428.0
                : constraints.maxWidth;
            return Center(
              child: SizedBox(
                width: phoneWidth,
                height: constraints.maxHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF18315E).withValues(alpha: .08),
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(22, 24, 22, 22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () => Navigator.pop(context),
                                      icon: Icon(Icons.arrow_back_rounded),
                                      color: Color(0xFF0F172A),
                                    ),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        AppLocalizations.globalText(
                                          'Rapport journalier',
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Color(0xFF0F172A),
                                          fontSize: 23,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 28),
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(22),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: Color(0xFFE8EEF7),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(
                                          0xFF0F172A,
                                        ).withValues(alpha: .055),
                                        blurRadius: 22,
                                        offset: Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          color: Color(
                                            0xFF7C3AED,
                                          ).withValues(alpha: .1),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.bar_chart_rounded,
                                          color: Color(0xFF7C3AED),
                                          size: 34,
                                        ),
                                      ),
                                      SizedBox(height: 18),
                                      Text(
                                        AppLocalizations.globalText(
                                          'Rapport journalier disponible',
                                        ),
                                        style: TextStyle(
                                          color: Color(0xFF0F172A),
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      Text(
                                        commercialName.trim().isEmpty
                                            ? 'Votre rapport journalier du jour est pr\u00EAt.'
                                            : 'Le rapport journalier de $commercialName est pr\u00EAt.',
                                        style: TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 14,
                                          height: 1.45,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _CommercialBottomNav(
                          selectedIndex: -1,
                          onChanged: (index) {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/home-commercial',
                              (route) => false,
                              arguments: {'initialIndex': index},
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CommercialBottomNav extends StatelessWidget {
  _CommercialBottomNav({required this.selectedIndex, required this.onChanged});

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static final _icons = [
    Icons.home_rounded,
    Icons.groups_rounded,
    Icons.receipt_long_rounded,
    Icons.pie_chart_outline_rounded,
    Icons.person_outline_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = [
      l10n.home,
      l10n.clients,
      l10n.orders,
      l10n.activities,
      l10n.profile,
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0xFF18315E).withValues(alpha: .09),
            blurRadius: 20,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: _icons[i],
                    label: labels[i],
                    selected: selectedIndex == i,
                    onTap: () => onChanged(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? _HomeCommercialState.primaryBlue
        : _HomeCommercialState.textMuted;

    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(top: 9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 23),
            SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemporaryTab extends StatelessWidget {
  _TemporaryTab({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _HomeCommercialState.primaryBlue.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                color: _HomeCommercialState.primaryBlue,
                size: 34,
              ),
            ),
            SizedBox(height: 22),
            Text(
              title,
              style: TextStyle(
                color: _HomeCommercialState.textDark,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _HomeCommercialState.textMuted,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NouveauClientScreen extends StatefulWidget {
  NouveauClientScreen({
    super.key,
    required this.currentEmail,
    required this.currentUserName,
    required this.existingClients,
    this.editingClient,
  });

  final String currentEmail;
  final String currentUserName;
  final List<CommercialClient> existingClients;
  final CommercialClient? editingClient;

  @override
  State<NouveauClientScreen> createState() => _NouveauClientScreenState();
}

class _NouveauClientScreenState extends State<NouveauClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _customBusinessTypeController = TextEditingController();
  final _customSectorController = TextEditingController();
  final _customBusinessTypeFocus = FocusNode();
  final _customSectorFocus = FocusNode();
  final _companyController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactRoleController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _notesController = TextEditingController();

  String? _status;
  String? _businessType;
  String? _segment;
  String? _sector;

  static final _statuses = ['Prospect', 'Actif', 'Inactif'];
  static final _businessTypes = [
    'Supermarchés & Grandes Surfaces',
    'Grossistes',
    'Épiceries',
    'Cafés & Restaurants',
  ];
  static final _segments = ['Premium', 'Standard', 'Économique'];
  static final _sectors = [
    'Ain Sebaa',
    'Bouskoura',
    'Derb Sultan',
    'Sidi Maarouf',
    'Hay Hassani',
    'Centre-ville',
    'Autre',
  ];

  @override
  void initState() {
    super.initState();
    final editingClient = widget.editingClient;
    if (editingClient != null) {
      _nameController.text = editingClient.name;
      _phoneController.text = editingClient.phone;
      _emailController.text = editingClient.email;
      _addressController.text = editingClient.address;
      _businessType = editingClient.businessType;
      _status = switch (editingClient.status) {
        ClientStatus.visited => 'Actif',
        ClientStatus.inactive => 'Inactif',
        ClientStatus.toVisit => 'Prospect',
      };
      _segment = 'Standard';
      _sector = _sectorFromAddress(editingClient.address);
      _contactNameController.text = editingClient.contactName;
    }
    _customBusinessTypeFocus.addListener(() {
      if (!_customBusinessTypeFocus.hasFocus) _commitCustomBusinessType();
    });
    _customSectorFocus.addListener(() {
      if (!_customSectorFocus.hasFocus) _commitCustomSector();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _customBusinessTypeController.dispose();
    _customSectorController.dispose();
    _customBusinessTypeFocus.dispose();
    _customSectorFocus.dispose();
    _companyController.dispose();
    _contactNameController.dispose();
    _contactRoleController.dispose();
    _contactPhoneController.dispose();
    _contactEmailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _requiredText(String? value, String message) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.globalText(message);
    }
    return null;
  }

  String? _phoneValidator(String? value, {bool required = false}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return required ? AppLocalizations.globalText('Champ obligatoire') : null;
    }
    final compact = text.replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^(0[67]\d{8}|\+212[67]\d{8})$').hasMatch(compact)) {
      return AppLocalizations.globalText('Numéro de téléphone invalide');
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
      return AppLocalizations.globalText('Adresse e-mail invalide');
    }
    return null;
  }

  List<String> get _businessTypeOptions {
    final custom = _businessType;
    if (custom == null || _businessTypes.contains(custom)) {
      return _businessTypes;
    }
    return [..._businessTypes, custom];
  }

  List<String> get _sectorOptions {
    final custom = _sector;
    if (custom == null || _sectors.contains(custom)) return _sectors;
    return [..._sectors, custom];
  }

  void _commitCustomBusinessType() {
    final value = _customBusinessTypeController.text.trim();
    if (_businessType != 'Autre' || value.isEmpty) return;
    setState(() {
      _businessType = value;
      _customBusinessTypeController.clear();
    });
  }

  void _commitCustomSector() {
    final value = _customSectorController.text.trim();
    if (_sector != 'Autre' || value.isEmpty) return;
    setState(() {
      _sector = value;
      _customSectorController.clear();
    });
  }

  String get _createdAtLabel {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/${now.year}';
  }

  String? _sectorFromAddress(String address) {
    for (final sector in _sectors) {
      if (sector != 'Autre' &&
          address.toLowerCase().contains(sector.toLowerCase())) {
        return sector;
      }
    }
    return null;
  }

  bool get _hasChanges {
    return _nameController.text.trim().isNotEmpty ||
        _phoneController.text.trim().isNotEmpty ||
        _emailController.text.trim().isNotEmpty ||
        _addressController.text.trim().isNotEmpty ||
        _customBusinessTypeController.text.trim().isNotEmpty ||
        _customSectorController.text.trim().isNotEmpty ||
        _companyController.text.trim().isNotEmpty ||
        _contactNameController.text.trim().isNotEmpty ||
        _contactRoleController.text.trim().isNotEmpty ||
        _contactPhoneController.text.trim().isNotEmpty ||
        _contactEmailController.text.trim().isNotEmpty ||
        _notesController.text.trim().isNotEmpty ||
        _status != null ||
        _businessType != null ||
        _segment != null ||
        _sector != null;
  }

  bool _clientNameExists(String name) {
    final normalized = name.trim().toLowerCase();
    return widget.existingClients.any(
      (client) =>
          client.id != widget.editingClient?.id &&
          client.name.trim().toLowerCase() == normalized,
    );
  }

  Future<void> _showNewClientInfoSheet({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String buttonLabel,
  }) {
    return _showMobileOrderSheet<void>(
      context: context,
      child: _OrderInfoSheet(
        icon: icon,
        iconColor: iconColor,
        title: title,
        message: message,
        buttonLabel: buttonLabel,
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _cancel() async {
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }
    final quit = await _showMobileOrderSheet<bool>(
      context: context,
      child: _NewClientCancelSheet(),
    );
    if (quit == true && mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_clientNameExists(_nameController.text)) {
      await _showNewClientInfoSheet(
        icon: Icons.person_off_outlined,
        iconColor: Color(0xFFF59E0B),
        title: 'Client déjà existant',
        message: 'Un client avec ce nom existe déjà.',
        buttonLabel: 'Compris',
      );
      return;
    }

    final resolvedBusinessType = _businessType == 'Autre'
        ? _customBusinessTypeController.text.trim()
        : _businessType!;
    final resolvedSector = _sector == 'Autre'
        ? _customSectorController.text.trim()
        : _sector;

    final editingClient = widget.editingClient;
    final id = editingClient?.id ?? DateTime.now().millisecondsSinceEpoch;
    final status = switch (_status) {
      'Actif' => ClientStatus.visited,
      'Inactif' => ClientStatus.inactive,
      _ => ClientStatus.toVisit,
    };
    final uiStatus = switch (_status) {
      'Actif' => _ClientUiStatus.active,
      'Inactif' => _ClientUiStatus.inactive,
      _ => _ClientUiStatus.prospect,
    };
    final baseClient =
        editingClient ??
        CommercialClient(
          id: id,
          clientCode: 'CL$id',
          name: '',
          city: 'Casablanca',
          status: ClientStatus.toVisit,
          initials: '',
          phone: '',
          email: '',
          address: '',
          creditLimit: 0,
          discount: 0,
          balance: 0,
          lastOrderDate: 'Nouveau',
          risk: ClientRisk.low,
          orders: [],
          documents: [],
        );
    final client = baseClient.copyWith(
      name: _nameController.text.trim(),
      city: 'Casablanca',
      businessType: resolvedBusinessType,
      category: resolvedBusinessType,
      contactName: _contactNameController.text.trim(),
      latitude: 33.5731,
      longitude: -7.5898,
      status: status,
      initials: _initials(_nameController.text.trim()),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? [resolvedSector, 'Casablanca'].whereType<String>().join(', ')
          : _addressController.text.trim(),
    );
    _createdClientPresets[id] = _ClientPreset(
      name: client.name,
      type: resolvedBusinessType,
      status: uiStatus,
      orders: 0,
      revenue: 0,
      rank: id,
      icon: Icons.storefront_rounded,
      color: _DashboardTab._blue,
    );

    _clientDataRevision.value++;
    await _showNewClientInfoSheet(
      icon: Icons.check_circle_rounded,
      iconColor: Color(0xFF22C55E),
      title: editingClient == null ? 'Client ajouté' : 'Client modifié',
      message: editingClient == null
          ? 'Client ajouté avec succès'
          : 'Client modifié avec succès',
      buttonLabel: 'Continuer',
    );
    if (!mounted) return;
    Navigator.pop(context, client);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _HomeCommercialState.surface,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _cancel();
        },
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final phoneWidth = constraints.maxWidth > 428
                  ? 428.0
                  : constraints.maxWidth;
              return Center(
                child: SizedBox(
                  width: phoneWidth,
                  height: constraints.maxHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF18315E).withValues(alpha: .08),
                          blurRadius: 28,
                          offset: Offset(0, 14),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Expanded(
                              child: CustomScrollView(
                                physics: BouncingScrollPhysics(),
                                slivers: [
                                  SliverPadding(
                                    padding: EdgeInsets.fromLTRB(
                                      20,
                                      20,
                                      20,
                                      128,
                                    ),
                                    sliver: SliverList(
                                      delegate: SliverChildListDelegate([
                                        _NewClientHeader(
                                          onBack: _cancel,
                                          isEditing:
                                              widget.editingClient != null,
                                        ),
                                        SizedBox(height: 20),
                                        _NewClientSection(
                                          icon: Icons.person_outline_rounded,
                                          title: AppLocalizations.globalText(
                                            'Informations g\u00E9n\u00E9rales',
                                          ),
                                          children: [
                                            _NewClientTextField(
                                              controller: _nameController,
                                              label:
                                                  AppLocalizations.globalText(
                                                    'Nom du client *',
                                                  ),
                                              hint: AppLocalizations.globalText(
                                                'Ex : Marjane Californie',
                                              ),
                                              icon:
                                                  Icons.person_outline_rounded,
                                              validator: (v) => _requiredText(
                                                v,
                                                'Le nom du client est obligatoire',
                                              ),
                                            ),
                                            _NewClientTwoColumns(
                                              left: _NewClientDropdown(
                                                label:
                                                    AppLocalizations.globalText(
                                                      'Type de commerce *',
                                                    ),
                                                icon: Icons.storefront_outlined,
                                                value: _businessType,
                                                items: _businessTypeOptions,
                                                sheetTitle: 'Type de commerce',
                                                onChanged: (v) => setState(() {
                                                  _businessType = v;
                                                  if (v != 'Autre') {
                                                    _customBusinessTypeController
                                                        .clear();
                                                  }
                                                }),
                                              ),
                                              right: _NewClientDropdown(
                                                label:
                                                    AppLocalizations.globalText(
                                                      'Statut *',
                                                    ),
                                                icon: Icons.flag_outlined,
                                                value: _status,
                                                items: _statuses,
                                                sheetTitle: 'Statut',
                                                onChanged: (v) =>
                                                    setState(() => _status = v),
                                              ),
                                            ),
                                            _NewClientConditionalField(
                                              visible: _businessType == 'Autre',
                                              child: _NewClientTextField(
                                                controller:
                                                    _customBusinessTypeController,
                                                focusNode:
                                                    _customBusinessTypeFocus,
                                                onEditingComplete:
                                                    _commitCustomBusinessType,
                                                label: AppLocalizations.globalText(
                                                  'Précisez le type de commerce',
                                                ),
                                                hint:
                                                    AppLocalizations.globalText(
                                                      'Ex : Parapharmacie',
                                                    ),
                                                icon: Icons.edit_outlined,
                                                validator: (v) =>
                                                    _businessType == 'Autre'
                                                    ? _requiredText(
                                                        v,
                                                        'Veuillez préciser votre choix',
                                                      )
                                                    : null,
                                              ),
                                            ),
                                            _NewClientTwoColumns(
                                              left: _NewClientTextField(
                                                controller: _phoneController,
                                                label:
                                                    AppLocalizations.globalText(
                                                      'T\u00E9l\u00E9phone *',
                                                    ),
                                                hint:
                                                    AppLocalizations.globalText(
                                                      'Ex : 06 XX XX XX XX',
                                                    ),
                                                icon: Icons.phone_outlined,
                                                keyboardType:
                                                    TextInputType.phone,
                                                validator: (v) =>
                                                    _phoneValidator(
                                                      v,
                                                      required: true,
                                                    ),
                                              ),
                                              right: _NewClientTextField(
                                                controller: _emailController,
                                                label:
                                                    AppLocalizations.globalText(
                                                      'Email',
                                                    ),
                                                hint:
                                                    AppLocalizations.globalText(
                                                      'Ex : contact@example.com',
                                                    ),
                                                icon:
                                                    Icons.mail_outline_rounded,
                                                keyboardType:
                                                    TextInputType.emailAddress,
                                                validator: _emailValidator,
                                              ),
                                            ),
                                            _NewClientTextField(
                                              controller: _addressController,
                                              label:
                                                  AppLocalizations.globalText(
                                                    'Adresse',
                                                  ),
                                              hint: AppLocalizations.globalText(
                                                'Ex : 123 Boulevard Mohammed V',
                                              ),
                                              icon: Icons.map_outlined,
                                            ),
                                            _NewClientLockedField(
                                              label:
                                                  AppLocalizations.globalText(
                                                    'Ville *',
                                                  ),
                                              value: 'Casablanca',
                                              icon: Icons.location_on_outlined,
                                            ),
                                            _NewClientDropdown(
                                              label:
                                                  AppLocalizations.globalText(
                                                    'Secteur',
                                                  ),
                                              icon: Icons.explore_outlined,
                                              value: _sector,
                                              items: _sectorOptions,
                                              sheetTitle: 'Secteur',
                                              onChanged: (v) => setState(() {
                                                _sector = v;
                                                if (v != 'Autre') {
                                                  _customSectorController
                                                      .clear();
                                                }
                                              }),
                                            ),
                                            _NewClientConditionalField(
                                              visible: _sector == 'Autre',
                                              child: _NewClientTextField(
                                                controller:
                                                    _customSectorController,
                                                focusNode: _customSectorFocus,
                                                onEditingComplete:
                                                    _commitCustomSector,
                                                label:
                                                    AppLocalizations.globalText(
                                                      'Précisez le secteur',
                                                    ),
                                                hint:
                                                    AppLocalizations.globalText(
                                                      'Ex : Bourgogne',
                                                    ),
                                                icon: Icons.edit_outlined,
                                                validator: (v) =>
                                                    _sector == 'Autre'
                                                    ? _requiredText(
                                                        v,
                                                        'Veuillez préciser votre choix',
                                                      )
                                                    : null,
                                              ),
                                            ),
                                            _NewClientTwoColumns(
                                              left: _NewClientLockedField(
                                                label:
                                                    AppLocalizations.globalText(
                                                      'Date de création',
                                                    ),
                                                value: _createdAtLabel,
                                                icon: Icons
                                                    .calendar_today_outlined,
                                              ),
                                              right: _NewClientLockedField(
                                                label:
                                                    AppLocalizations.globalText(
                                                      'Commercial responsable',
                                                    ),
                                                value: widget.currentUserName,
                                                icon: Icons.badge_outlined,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 14),
                                        _NewClientSection(
                                          icon: Icons.apartment_rounded,
                                          title: AppLocalizations.globalText(
                                            'Informations commerciales',
                                          ),
                                          children: [
                                            _NewClientTwoColumns(
                                              left: _NewClientDropdown(
                                                label:
                                                    AppLocalizations.globalText(
                                                      'Segment',
                                                    ),
                                                icon: Icons
                                                    .pie_chart_outline_rounded,
                                                value: _segment,
                                                items: _segments,
                                                sheetTitle: 'Segment',
                                                onChanged: (v) => setState(
                                                  () => _segment = v,
                                                ),
                                              ),
                                              right: _NewClientTextField(
                                                controller: _companyController,
                                                label:
                                                    AppLocalizations.globalText(
                                                      'Raison sociale',
                                                    ),
                                                hint: AppLocalizations.globalText(
                                                  'Ex : Société Marjane Holding',
                                                ),
                                                icon:
                                                    Icons.description_outlined,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 14),
                                        _NewClientSection(
                                          icon: Icons.person_outline_rounded,
                                          title: AppLocalizations.globalText(
                                            'Contact principal',
                                          ),
                                          children: [
                                            _NewClientTwoColumns(
                                              left: _NewClientTextField(
                                                controller:
                                                    _contactNameController,
                                                label:
                                                    AppLocalizations.globalText(
                                                      'Nom complet',
                                                    ),
                                                hint:
                                                    AppLocalizations.globalText(
                                                      'Ex : Ahmed Benali',
                                                    ),
                                                icon: Icons
                                                    .person_outline_rounded,
                                              ),
                                              right: _NewClientTextField(
                                                controller:
                                                    _contactRoleController,
                                                label:
                                                    AppLocalizations.globalText(
                                                      'Fonction',
                                                    ),
                                                hint:
                                                    AppLocalizations.globalText(
                                                      'Ex : G\u00E9rant',
                                                    ),
                                                icon: Icons
                                                    .business_center_outlined,
                                              ),
                                            ),
                                            _NewClientTwoColumns(
                                              left: _NewClientTextField(
                                                controller:
                                                    _contactPhoneController,
                                                label:
                                                    AppLocalizations.globalText(
                                                      'T\u00E9l\u00E9phone',
                                                    ),
                                                hint:
                                                    AppLocalizations.globalText(
                                                      'Ex : 06 XX XX XX XX',
                                                    ),
                                                icon: Icons.phone_outlined,
                                                keyboardType:
                                                    TextInputType.phone,
                                                validator: _phoneValidator,
                                              ),
                                              right: _NewClientTextField(
                                                controller:
                                                    _contactEmailController,
                                                label:
                                                    AppLocalizations.globalText(
                                                      'Email',
                                                    ),
                                                hint:
                                                    AppLocalizations.globalText(
                                                      'Ex : ahmed@example.com',
                                                    ),
                                                icon:
                                                    Icons.mail_outline_rounded,
                                                keyboardType:
                                                    TextInputType.emailAddress,
                                                validator: _emailValidator,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 14),
                                        _NewClientSection(
                                          icon: Icons.notes_rounded,
                                          title: AppLocalizations.globalText(
                                            'Notes',
                                          ),
                                          children: [
                                            _NewClientTextField(
                                              controller: _notesController,
                                              label:
                                                  AppLocalizations.globalText(
                                                    'Remarques',
                                                  ),
                                              hint: AppLocalizations.globalText(
                                                'Ajouter des notes sur ce client...',
                                              ),
                                              icon: Icons.edit_outlined,
                                              minLines: 3,
                                            ),
                                          ],
                                        ),
                                      ]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _NewClientActionButton(
                                      label: AppLocalizations.globalText(
                                        'Annuler',
                                      ),
                                      icon: Icons.close_rounded,
                                      outlined: true,
                                      onTap: _cancel,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: _NewClientActionButton(
                                      label: AppLocalizations.globalText(
                                        'Enregistrer',
                                      ),
                                      icon: Icons.save_outlined,
                                      onTap: _save,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _CommercialBottomNav(
                              selectedIndex: 1,
                              onChanged: (index) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => HomeCommercial(),
                                    settings: RouteSettings(
                                      arguments: {
                                        'email': widget.currentEmail,
                                        'name': widget.currentUserName,
                                        'initialIndex': index,
                                      },
                                    ),
                                  ),
                                  (route) => false,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NewClientHeader extends StatelessWidget {
  _NewClientHeader({required this.onBack, this.isEditing = false});

  final VoidCallback onBack;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: onBack,
          icon: Icon(Icons.arrow_back_rounded),
          color: _DashboardTab._navy,
          style: IconButton.styleFrom(
            backgroundColor: _HomeCommercialState.cardBg,
            shadowColor: Color(0xFF0F172A).withValues(alpha: .08),
            elevation: 5,
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 4),
              Text(
                AppLocalizations.globalText(
                  isEditing ? 'Modifier client' : 'Nouveau client',
                ),
                style: TextStyle(
                  color: _DashboardTab._navy,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 5),
              Text(
                AppLocalizations.globalText(
                  isEditing
                      ? 'Mettez à jour les informations du client'
                      : 'Ajoutez un nouveau client \u00E0 votre portefeuille',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NewClientSection extends StatelessWidget {
  _NewClientSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: _premiumCardDecoration(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _DashboardTab._blue, size: 22),
              SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: _DashboardTab._navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 18),
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) SizedBox(height: 15),
          ],
        ],
      ),
    );
  }
}

class _NewClientTwoColumns extends StatelessWidget {
  _NewClientTwoColumns({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 330) {
          return Column(children: [left, SizedBox(height: 15), right]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            SizedBox(width: 14),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _NewClientConditionalField extends StatelessWidget {
  _NewClientConditionalField({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1,
            child: child,
          ),
        );
      },
      child: visible
          ? KeyedSubtree(
              key: ValueKey('visible-new-client-extra-field'),
              child: child,
            )
          : SizedBox(key: ValueKey('hidden-new-client-extra-field'), height: 0),
    );
  }
}

class _NewClientFieldShell extends StatelessWidget {
  _NewClientFieldShell({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_NewClientLabel(label), SizedBox(height: 8), child],
    );
  }
}

class _NewClientLabel extends StatelessWidget {
  _NewClientLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final required = label.trim().endsWith('*');
    final cleanLabel = required
        ? label.substring(0, label.lastIndexOf('*')).trimRight()
        : label;

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        text: cleanLabel,
        style: TextStyle(
          color: Color(0xFF64748B),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        children: [
          if (required)
            TextSpan(
              text: ' *',
              style: TextStyle(color: _HomeCommercialState.error),
            ),
        ],
      ),
    );
  }
}

class _NewClientTextField extends StatelessWidget {
  _NewClientTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.focusNode,
    this.onEditingComplete,
    this.minLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final FocusNode? focusNode;
  final VoidCallback? onEditingComplete;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    if (minLines > 1) {
      return _NewClientFieldShell(
        label: label,
        child: Container(
          constraints: BoxConstraints(minHeight: 88),
          padding: EdgeInsets.fromLTRB(14, 13, 14, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Color(0xFFE2E8F0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(icon, color: Color(0xFF64748B), size: 21),
              ),
              SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  validator: validator,
                  onEditingComplete: onEditingComplete,
                  keyboardType: keyboardType,
                  minLines: minLines,
                  maxLines: 4,
                  style: TextStyle(
                    color: _DashboardTab._navy,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                    isCollapsed: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _NewClientFieldShell(
      label: label,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        validator: validator,
        onEditingComplete: onEditingComplete,
        keyboardType: keyboardType,
        minLines: minLines,
        maxLines: minLines == 1 ? 1 : 4,
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(
          color: _DashboardTab._navy,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
        decoration: _newClientDecoration(hint, icon),
      ),
    );
  }
}

class _NewClientLockedField extends StatelessWidget {
  _NewClientLockedField({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _NewClientFieldShell(
      label: label,
      child: TextFormField(
        initialValue: value,
        enabled: false,
        style: TextStyle(
          color: _DashboardTab._navy,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
        decoration: _newClientDecoration(value, icon),
      ),
    );
  }
}

class _NewClientDropdown extends StatelessWidget {
  _NewClientDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.sheetTitle,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final String? value;
  final List<String> items;
  final String sheetTitle;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return _NewClientFieldShell(
      label: label,
      child: FormField<String>(
        key: ValueKey('$label-$value'),
        initialValue: value,
        validator: (_) => label.contains('*') && value == null
            ? AppLocalizations.globalText('Champ obligatoire')
            : null,
        builder: (field) {
          Future<void> openSheet() async {
            final selected = await _showMobileOrderSheet<String>(
              context: context,
              child: _NewClientOptionSheet(
                title: sheetTitle,
                options: items,
                selectedValue: value,
              ),
            );
            if (selected == null) return;
            field.didChange(selected);
            onChanged(selected);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: openSheet,
                borderRadius: BorderRadius.circular(13),
                child: Container(
                  height: 50,
                  padding: EdgeInsets.only(left: 0, right: 12),
                  decoration: BoxDecoration(
                    color: _HomeCommercialState.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: field.hasError
                          ? _HomeCommercialState.error
                          : Color(0xFFE3E8F2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 42,
                        child: Center(
                          child: Icon(icon, color: Color(0xFF64748B), size: 21),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          AppLocalizations.globalText(
                            value ?? _newClientDropdownHint(label),
                          ),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.fade,
                          style: TextStyle(
                            color: value == null
                                ? Color(0xFF64748B)
                                : _DashboardTab._navy,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF64748B),
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
              if (field.hasError) ...[
                SizedBox(height: 6),
                Text(
                  field.errorText!,
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    color: _HomeCommercialState.error,
                    fontSize: 11.5,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _NewClientOptionSheet extends StatelessWidget {
  _NewClientOptionSheet({
    required this.title,
    required this.options,
    required this.selectedValue,
  });

  final String title;
  final List<String> options;
  final String? selectedValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0F172A).withValues(alpha: .16),
            blurRadius: 28,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.globalText(title),
              style: TextStyle(
                color: _DashboardTab._navy,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              AppLocalizations.globalText('Sélectionnez une option.'),
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 14),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (context, index) =>
                    Divider(height: 1, color: Color(0xFFE2E8F0)),
                itemBuilder: (context, index) {
                  final option = options[index];
                  final selected = option == selectedValue;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(context, option),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? Color(0xFFEFF6FF) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: selected
                                    ? _DashboardTab._blue.withValues(alpha: .12)
                                    : Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _newClientOptionIcon(title),
                                color: selected
                                    ? _DashboardTab._blue
                                    : Color(0xFF64748B),
                                size: 18,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                AppLocalizations.globalText(option),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (selected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: _DashboardTab._blue,
                                size: 21,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewClientCancelSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _OrderDecisionSheetShell(
      icon: Icons.warning_amber_rounded,
      iconColor: Color(0xFFF59E0B),
      title: 'Annuler la création ?',
      message: 'Les informations saisies seront perdues.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 330;
          final continueButton = _OrderSheetOutlinedButton(
            label: 'Continuer la saisie',
            onPressed: () => Navigator.pop(context, false),
          );
          final quitButton = _OrderSheetPrimaryButton(
            label: 'Quitter',
            onPressed: () => Navigator.pop(context, true),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [continueButton, SizedBox(height: 10), quitButton],
            );
          }

          return Row(
            children: [
              Expanded(child: continueButton),
              SizedBox(width: 12),
              Expanded(child: quitButton),
            ],
          );
        },
      ),
    );
  }
}

String _newClientDropdownHint(String label) {
  final normalized = label.replaceAll('*', '').trim().toLowerCase();
  if (normalized == 'statut') return 'Choisir un statut';
  if (normalized == 'type de commerce') return 'Choisir un type';
  if (normalized == 'segment') return 'Choisir un segment';
  if (normalized == 'secteur') return 'Choisir un secteur';
  return 'Choisir';
}

IconData _newClientOptionIcon(String title) {
  final normalized = title.toLowerCase();
  if (normalized.contains('commerce')) return Icons.storefront_outlined;
  if (normalized.contains('statut')) return Icons.flag_outlined;
  if (normalized.contains('secteur')) return Icons.explore_outlined;
  if (normalized.contains('segment')) return Icons.pie_chart_outline_rounded;
  return Icons.check_circle_outline_rounded;
}

class _NewClientActionButton extends StatelessWidget {
  _NewClientActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(13),
    );
    if (outlined) {
      return SizedBox(
        height: 54,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: _DashboardTab._blue,
            side: BorderSide(color: _DashboardTab._blue),
            shape: shape,
            textStyle: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: _DashboardTab._blue,
          foregroundColor: Colors.white,
          elevation: 10,
          shadowColor: _DashboardTab._blue.withValues(alpha: .24),
          shape: shape,
          textStyle: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

InputDecoration _newClientDecoration(
  String hint,
  IconData icon, {
  bool alignIconTop = false,
}) {
  return InputDecoration(
    hintText: hint,
    prefixIcon: Padding(
      padding: EdgeInsets.only(top: alignIconTop ? 13 : 0),
      child: Align(
        widthFactor: 1,
        heightFactor: 1,
        alignment: alignIconTop ? Alignment.topCenter : Alignment.center,
        child: Icon(icon, color: Color(0xFF64748B), size: 21),
      ),
    ),
    prefixIconConstraints: BoxConstraints(minWidth: 42, minHeight: 0),
    filled: true,
    fillColor: _HomeCommercialState.cardBg,
    hintStyle: TextStyle(
      color: Color(0xFF64748B),
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    enabledBorder: _searchBorder(),
    disabledBorder: _searchBorder(),
    focusedBorder: _searchBorder(color: _DashboardTab._blue),
    errorBorder: _searchBorder(color: _HomeCommercialState.error),
    focusedErrorBorder: _searchBorder(color: _HomeCommercialState.error),
    errorMaxLines: 2,
    errorStyle: TextStyle(
      fontSize: 11.5,
      height: 1.15,
      fontWeight: FontWeight.w600,
    ),
  );
}

// ignore: unused_element
class _TemporaryScreen extends StatelessWidget {
  _TemporaryScreen({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _HomeCommercialState.surface,
      appBar: AppBar(
        backgroundColor: _HomeCommercialState.cardBg,
        foregroundColor: _DashboardTab._navy,
        elevation: 0,
        title: Text(title),
      ),
      body: Center(
        child: _TemporaryTab(
          title: title,
          subtitle: AppLocalizations.globalText(
            'Écran à connecter prochainement.',
          ),
          icon: icon,
        ),
      ),
    );
  }
}

String _money(num value) {
  final text = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final position = text.length - i;
    buffer.write(text[i]);
    if (position > 1 && position % 3 == 1) buffer.write(' ');
  }
  return buffer.toString();
}
