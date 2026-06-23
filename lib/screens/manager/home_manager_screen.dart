import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

import '../../auth/current_user_session.dart';
import '../../data/mock_presales_data.dart';
import '../../mockData/manager_dashboard.dart';
import '../../mockData/manager_orders.dart';
import '../../mockData/manager_reports.dart';
import '../../services/commercial_objectives_service.dart';

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

class CommerciauxManager extends StatefulWidget {
  CommerciauxManager({super.key});

  @override
  State<CommerciauxManager> createState() => _CommerciauxManagerState();
}

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
  State<OrdersManagerScreen> createState() => _OrdersManagerScreenState();
}

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
  State<ReportsManagerScreen> createState() => _ReportsManagerScreenState();
}

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
  ManagerDashboardPeriod _selectedPeriod = ManagerDashboardPeriod.today;

  static const _primaryBlue = Color(0xFF2674F8);
  static const _deepBlue = Color(0xFF155EE8);
  static const _success = Color(0xFF28C77B);
  static const _textDark = Color(0xFF14204A);
  static const _textMuted = Color(0xFF6D7790);
  static const _surface = Color(0xFFF7F9FD);
  static const _border = Color(0xFFE7ECF5);

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

    final data = ManagerDashboardMockData.byPeriod(_selectedPeriod);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _surface,
      drawer: _ManagerDrawer(),
      body: _ManagerMobileShell(
        selectedTab: _ManagerTab.dashboard,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                title: AppLocalizations.globalText('Tableau de bord'),
                onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
                onNotificationsPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NotificationsScreen()),
                  );
                },
              ),
              SizedBox(height: 28),
              Align(
                alignment: Alignment.centerRight,
                child: _PeriodSelector(
                  selectedPeriod: _selectedPeriod,
                  onChanged: (period) {
                    setState(() => _selectedPeriod = period);
                  },
                ),
              ),
              SizedBox(height: 28),
              _StatsGrid(data: data),
              SizedBox(height: 16),
              _SalesByCommercialChart(
                items: data.salesByCommercial,
                onSelected: (commercial) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetailCommercialScreen(
                        commercialId: commercial.commercialId,
                        commercialName: commercial.name,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
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
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: onNotificationsPressed,
              icon: Icon(Icons.notifications_none_rounded),
              color: _DashboardManagerState._textDark,
              tooltip: 'Notifications',
            ),
            if (showNotificationBadge)
              Positioned(
                right: 11,
                top: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _DashboardManagerState._primaryBlue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.4),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

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
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: onNotificationsPressed,
              icon: Icon(Icons.notifications_none_rounded),
              color: _DashboardManagerState._textDark,
              tooltip: 'Notifications',
            ),
            if (badgeCount > 0)
              Positioned(
                right: 7,
                top: 5,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _DashboardManagerState._primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badgeCount > 9 ? '9' : badgeCount.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
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

enum _ManagerTab { dashboard, commerciaux, commandes, rapports, parametres }

class _ManagerMobileShell extends StatelessWidget {
  _ManagerMobileShell({required this.selectedTab, required this.child});

  final _ManagerTab selectedTab;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final phoneWidth = constraints.maxWidth > 430
              ? 430.0
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
                      color: Color(0xFF1C4B92).withValues(alpha: .08),
                      blurRadius: 28,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
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
      ),
    );
  }
}

class _ManagerBottomNavigation extends StatelessWidget {
  _ManagerBottomNavigation({required this.selectedTab});

  final _ManagerTab selectedTab;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.dashboard_rounded,
        'Dashboard',
        _ManagerTab.dashboard,
        '/home-manager',
      ),
      (
        Icons.groups_rounded,
        'Commerciaux',
        _ManagerTab.commerciaux,
        '/manager-commerciaux',
      ),
      (
        Icons.receipt_long_rounded,
        'Commandes',
        _ManagerTab.commandes,
        '/manager-commandes',
      ),
      (
        Icons.bar_chart_rounded,
        'Rapports',
        _ManagerTab.rapports,
        '/manager-rapports',
      ),
      (Icons.settings_rounded, 'Parametres', _ManagerTab.parametres, null),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0xFF1C4B92).withValues(alpha: .08),
            blurRadius: 20,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
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
        ? _DashboardManagerState._primaryBlue
        : _DashboardManagerState._textMuted;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 21),
              SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
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

class DetailCommandeScreen extends StatefulWidget {
  DetailCommandeScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<DetailCommandeScreen> createState() => _DetailCommandeScreenState();
}

class _DetailCommandeScreenState extends State<DetailCommandeScreen> {
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
    final sessionUser = CurrentUserSession.currentUser;
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

class NotificationsScreen extends StatelessWidget {
  NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _TemporaryManagerPage(
      title: AppLocalizations.globalText('Notifications'),
      subtitle: AppLocalizations.globalText('Centre de notifications manager'),
      icon: Icons.notifications_none_rounded,
    );
  }
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
