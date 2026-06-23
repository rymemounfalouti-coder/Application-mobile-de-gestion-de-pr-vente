import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/current_user_session.dart';
import '../../data/mock_presales_data.dart';

class HomeCommercial extends StatefulWidget {
  HomeCommercial({super.key});

  @override
  State<HomeCommercial> createState() => _HomeCommercialState();
}

class _HomeCommercialState extends State<HomeCommercial> {
  int _selectedIndex = 0;
  bool _initialIndexApplied = false;

  static const primaryBlue = Color(0xFF2674F8);
  static const textDark = Color(0xFF14204A);
  static const textMuted = Color(0xFF6F7A90);
  static const surface = Color(0xFFF7F9FD);
  static const success = Color(0xFF20C47B);

  void _redirectAfterBuild(BuildContext context, String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
    });
  }

  @override
  Widget build(BuildContext context) {
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
    final dashboard = MockPreSalesData.dashboardForUser(user);
    final clients = MockPreSalesData.clientsForUser(user);
    final tourVisits = MockPreSalesData.tourVisitsForUser(user);
    final orders = MockPreSalesData.ordersForUser(user);
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
                          child: IndexedStack(
                            index: _selectedIndex,
                            children: [
                              _DashboardTab(
                                userName: userName,
                                summary:
                                    dashboard?.summary ??
                                    CommercialDashboardData.empty().summary,
                                activities: dashboard?.activities ?? [],
                                orders: orders,
                                clients: clients,
                                currentEmail: email,
                                onNavigate: (index) {
                                  setState(() => _selectedIndex = index);
                                },
                              ),
                              ClientsCommercial(
                                clients: clients,
                                currentEmail: email,
                                currentUserName: userName,
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
                              ),
                              if (_selectedIndex == -2)
                                _TemporaryTab(
                                  title: AppLocalizations.globalText('Profil'),
                                  subtitle: AppLocalizations.globalText(
                                    'Informations commercial et paramètres.',
                                  ),
                                  icon: Icons.person_outline_rounded,
                                ),
                              ProfileCommercial(
                                user: user,
                                fallbackName: userName,
                                fallbackEmail: email,
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
  });

  final List<CommercialClient> clients;
  final String currentEmail;
  final String currentUserName;

  @override
  State<ClientsCommercial> createState() => _ClientsCommercialState();
}

class _ClientsCommercialState extends State<ClientsCommercial> {
  final _searchController = TextEditingController();
  ClientStatus? _selectedStatus;
  ClientStatus? _modalStatus;
  String? _selectedCity;
  String _query = '';

  static final _tabs = <ClientStatus?>[
    null,
    ClientStatus.toVisit,
    ClientStatus.visited,
    ClientStatus.inactive,
  ];

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

  List<CommercialClient> get _filteredClients {
    return widget.clients.where((client) {
      final matchesSearch =
          _query.isEmpty ||
          client.name.toLowerCase().contains(_query) ||
          client.city.toLowerCase().contains(_query);
      final matchesTab =
          _selectedStatus == null || client.status == _selectedStatus;
      final matchesCity = _selectedCity == null || client.city == _selectedCity;
      final matchesModalStatus =
          _modalStatus == null || client.status == _modalStatus;
      return matchesSearch && matchesTab && matchesCity && matchesModalStatus;
    }).toList();
  }

  List<String> get _cities {
    final cities = widget.clients.map((client) => client.city).toSet().toList();
    cities.sort();
    return cities;
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

  Future<void> _openFilterSheet() async {
    var draftCity = _selectedCity;
    var draftStatus = _modalStatus;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(22, 18, 22, 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.globalText('Filtrer les clients'),
                    style: TextStyle(
                      color: _HomeCommercialState.textDark,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 18),
                  _FilterLabel(text: 'Ville'),
                  SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    initialValue: draftCity,
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          AppLocalizations.globalText('Toutes les villes'),
                        ),
                      ),
                      for (final city in _cities)
                        DropdownMenuItem<String?>(
                          value: city,
                          child: Text(city),
                        ),
                    ],
                    onChanged: (value) {
                      setModalState(() => draftCity = value);
                    },
                    decoration: _sheetDecoration(),
                  ),
                  SizedBox(height: 16),
                  _FilterLabel(text: 'Statut'),
                  SizedBox(height: 8),
                  DropdownButtonFormField<ClientStatus?>(
                    initialValue: draftStatus,
                    items: [
                      DropdownMenuItem<ClientStatus?>(
                        value: null,
                        child: Text(
                          AppLocalizations.globalText('Tous les statuts'),
                        ),
                      ),
                      for (final status in ClientStatus.values)
                        DropdownMenuItem<ClientStatus?>(
                          value: status,
                          child: Text(status.label),
                        ),
                    ],
                    onChanged: (value) {
                      setModalState(() => draftStatus = value);
                    },
                    decoration: _sheetDecoration(),
                  ),
                  SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedCity = null;
                              _modalStatus = null;
                            });
                            Navigator.pop(context);
                          },
                          child: Text(
                            AppLocalizations.globalText('Réinitialiser'),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedCity = draftCity;
                              _modalStatus = draftStatus;
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _HomeCommercialState.primaryBlue,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(AppLocalizations.globalText('Appliquer')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final clients = _filteredClients;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(18, 22, 18, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.globalText(
                      'Rechercher un client...',
                    ),
                    prefixIcon: Icon(Icons.search_rounded, size: 21),
                    filled: true,
                    fillColor: Colors.white,
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
                width: 46,
                height: 46,
                child: OutlinedButton(
                  onPressed: _openFilterSheet,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    side: BorderSide(color: Color(0xFFE3E8F2)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Icon(
                    Icons.filter_alt_outlined,
                    color: _HomeCommercialState.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 18),
        _ClientTabs(
          selectedStatus: _selectedStatus,
          statuses: _tabs,
          onChanged: (status) => setState(() => _selectedStatus = status),
        ),
        SizedBox(height: 10),
        Expanded(
          child: clients.isEmpty
              ? _EmptyClients()
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(18, 0, 18, 16),
                  physics: BouncingScrollPhysics(),
                  itemCount: clients.length,
                  separatorBuilder: (context, index) => SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final client = clients[index];
                    return _ClientCard(
                      client: client,
                      onTap: () => _openClientDetails(client),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class OrdersCommercial extends StatefulWidget {
  OrdersCommercial({super.key, required this.orders, required this.onNavigate});

  final List<CommercialOrder> orders;
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(22, 18, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.globalText('Filtres commandes'),
                style: TextStyle(
                  color: _HomeCommercialState.textDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 16),
              for (final filter in _OrderQuickFilter.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_orderQuickFilterLabel(filter)),
                  trailing: _selectedFilter == filter
                      ? Icon(
                          Icons.check_rounded,
                          color: _HomeCommercialState.primaryBlue,
                        )
                      : null,
                  onTap: () {
                    setState(() => _selectedFilter = filter);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CommercialNotificationsPage()),
    );
  }

  void _createOrder() {
    widget.onNavigate(1);
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
              padding: EdgeInsets.fromLTRB(20, 24, 20, 92),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _OrdersHeader(onNotificationsTap: _openNotifications),
                  SizedBox(height: 24),
                  _OrdersKpiGrid(
                    totalOrders: widget.orders.length,
                    pendingOrders: _pendingCount,
                    validatedOrders: _validatedCount,
                    rejectedOrders: _rejectedCount,
                  ),
                  SizedBox(height: 20),
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
                  SizedBox(height: 22),
                  if (widget.orders.isEmpty)
                    _EmptyOrdersState(onCreate: _createOrder)
                  else if (orders.isEmpty)
                    _EmptyDetailMessage(text: 'Aucune commande trouvée')
                  else
                    for (final order in orders) ...[
                      _OrderCard(order: order, onTap: () => _openOrder(order)),
                      SizedBox(height: 14),
                    ],
                ]),
              ),
            ),
          ],
        ),
        Positioned(
          right: 22,
          bottom: 18,
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

class _OrdersHeader extends StatelessWidget {
  _OrdersHeader({required this.onNotificationsTap});

  final VoidCallback onNotificationsTap;

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
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 6),
              Text(
                AppLocalizations.globalText('Suivez et gérez vos commandes'),
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: 46,
              height: 46,
              child: IconButton(
                onPressed: onNotificationsTap,
                icon: Icon(Icons.notifications_none_rounded, size: 28),
                color: Color(0xFF0F172A),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  shadowColor: Color(0xFF0F172A).withValues(alpha: .12),
                  elevation: 8,
                ),
              ),
            ),
            Positioned(
              right: 3,
              top: 0,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Color(0xFFFF3B30),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '3',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
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
              hintText: AppLocalizations.globalText(
                'Rechercher une commande...',
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: Color(0xFF64748B),
                size: 27,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(vertical: 17),
              enabledBorder: _searchBorder(),
              focusedBorder: _searchBorder(
                color: _HomeCommercialState.primaryBlue,
              ),
            ),
          ),
        ),
        SizedBox(width: 10),
        SizedBox(
          width: 58,
          height: 58,
          child: OutlinedButton(
            onPressed: onFilterTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: Color(0xFF475569),
              backgroundColor: Colors.white,
              side: BorderSide(color: Color(0xFFE3E8F2)),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Icon(Icons.filter_alt_outlined, size: 25),
          ),
        ),
      ],
    );
  }
}

class _OrdersKpiGrid extends StatelessWidget {
  _OrdersKpiGrid({
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
    final cards = [
      _OrderKpiData(
        title: AppLocalizations.globalText('Total commandes'),
        value: totalOrders,
        icon: Icons.shopping_bag_outlined,
        color: Color(0xFF2563EB),
      ),
      _OrderKpiData(
        title: AppLocalizations.globalText('En attente'),
        value: pendingOrders,
        icon: Icons.schedule_rounded,
        color: Color(0xFFE58A00),
      ),
      _OrderKpiData(
        title: AppLocalizations.globalText('Valid\u00E9es'),
        value: validatedOrders,
        icon: Icons.assignment_turned_in_outlined,
        color: Color(0xFF16A34A),
      ),
      _OrderKpiData(
        title: AppLocalizations.globalText('Refus\u00E9es'),
        value: rejectedOrders,
        icon: Icons.cancel_outlined,
        color: Color(0xFFDC2626),
      ),
    ];

    return GridView.builder(
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.62,
      ),
      itemBuilder: (context, index) => _OrderKpiCard(data: cards[index]),
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

class _OrderKpiCard extends StatelessWidget {
  _OrderKpiCard({required this.data});

  final _OrderKpiData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(14, 14, 12, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Color(0xFFE8EEF7)),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0F172A).withValues(alpha: .065),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: data.color,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  '${data.value}',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(data.icon, color: data.color, size: 27),
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
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: BouncingScrollPhysics(),
        itemCount: _OrderQuickFilter.values.length,
        separatorBuilder: (context, index) => SizedBox(width: 10),
        itemBuilder: (context, index) {
          final filter = _OrderQuickFilter.values[index];
          final selected = selectedFilter == filter;
          return InkWell(
            onTap: () => onChanged(filter),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(horizontal: 17),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Color(0xFF2563EB) : Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF0F172A).withValues(alpha: .055),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Container(
            constraints: BoxConstraints(minHeight: 100),
            padding: EdgeInsets.fromLTRB(14, 15, 14, 15),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Color(0xFF2563EB).withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.description_outlined,
                    color: Color(0xFF2563EB),
                    size: 28,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        order.clientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 10),
                      _OrderStatusBadge(status: order.status),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatOrderDate(order.date),
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 18),
                    Text(
                      '${_money(order.total)} DH',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 10),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF64748B),
                  size: 30,
                ),
              ],
            ),
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
          fontWeight: FontWeight.w900,
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
            label: Text(AppLocalizations.globalText('Créer une commande')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _HomeCommercialState.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _HomeCommercialState.textDark,
        elevation: 0,
        title: Text(order.orderNumber),
      ),
      body: ListView(
        padding: EdgeInsets.all(20),
        children: [
          _ProfileCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ConfirmationInfoRow(
                  label: AppLocalizations.globalText('Commande'),
                  value: order.orderNumber,
                ),
                _ConfirmationInfoRow(
                  label: AppLocalizations.globalText('Client'),
                  value: order.clientName,
                ),
                _ConfirmationInfoRow(
                  label: AppLocalizations.globalText('Date'),
                  value: order.date,
                ),
                _ConfirmationInfoRow(
                  label: AppLocalizations.globalText('Statut'),
                  value: _commercialOrderStatusLabel(order.status),
                ),
                _ConfirmationInfoRow(
                  label: AppLocalizations.globalText('Total'),
                  value: '${_money(order.total)} DH',
                ),
                if (order.status == OrderStatus.cancelled)
                  _ConfirmationInfoRow(
                    label: AppLocalizations.globalText('Motif du refus'),
                    value: 'Commande refusée par le manager.',
                  ),
                Divider(color: Color(0xFFE8EDF5)),
                for (final item in order.items)
                  _ConfirmationInfoRow(
                    label: item.productName,
                    value: '${item.quantity} x - ${_money(item.total)} DH',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _OrderQuickFilter { all, pending, validated, rejected, today, week }

String _orderQuickFilterLabel(_OrderQuickFilter filter) {
  return switch (filter) {
    _OrderQuickFilter.all => AppLocalizations.globalText('Toutes'),
    _OrderQuickFilter.pending => AppLocalizations.globalText('En attente'),
    _OrderQuickFilter.validated => AppLocalizations.globalText('Validées'),
    _OrderQuickFilter.rejected => AppLocalizations.globalText('Refusées'),
    _OrderQuickFilter.today => AppLocalizations.globalText("Aujourd'hui"),
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

String _formatOrderDate(String value) {
  final date = _parseOrderDate(value);
  if (date == null) return value;
  final months = [
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
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: () {},
              icon: Icon(Icons.notifications_none_rounded),
              color: _HomeCommercialState.textDark,
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Color(0xFFFF3B30),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
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
        backgroundColor: Colors.white,
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
  });

  final List<TourVisit> visits;
  final List<CommercialClient> clients;
  final String currentEmail;
  final String currentUserName;

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

  void _handleOption(CommercialClient client, String value) {
    if (value == 'location') {
      _openMaps(client);
      return;
    }

    final labels = {
      'edit': 'Modifier client',
      'note': 'Ajouter note',
      'remove': 'Supprimer de la tournée',
    };

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(labels[value] ?? 'Action'),
          content: Text('${client.name} sera géré ici prochainement.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.globalText('OK')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openNewOrder(CommercialClient client) async {
    if (client.status == ClientStatus.inactive) {
      _showMessage('Ce client est inactif. Impossible de créer une commande.');
      return;
    }

    var orderClient = client;
    if (client.status == ClientStatus.toVisit) {
      final shouldConvert = await _confirmProspectConversion();
      if (shouldConvert != true) return;
      orderClient = client.copyWith(status: ClientStatus.visited);
      _showMessage('Client converti avec succès');
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NouvelleCommande(
          client: orderClient,
          currentEmail: widget.currentEmail,
          currentUserName: widget.currentUserName,
        ),
        settings: RouteSettings(arguments: {'clientId': orderClient.id}),
      ),
    );
  }

  Future<bool?> _confirmProspectConversion() {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _ProspectConversionSheet(
        onCancel: () => Navigator.pop(context, false),
        onConvert: () => Navigator.pop(context, true),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(AppLocalizations.globalText(message))),
      );
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;

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

class SelectionClientCommande extends StatefulWidget {
  SelectionClientCommande({
    super.key,
    required this.clients,
    required this.currentEmail,
    required this.currentUserName,
  });

  final List<CommercialClient> clients;
  final String currentEmail;
  final String currentUserName;

  @override
  State<SelectionClientCommande> createState() =>
      _SelectionClientCommandeState();
}

class _SelectionClientCommandeState extends State<SelectionClientCommande> {
  final _searchController = TextEditingController();
  final Set<int> _convertedProspects = {};
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

  List<CommercialClient> get _clients {
    return widget.clients.map(_visibleClient).where((client) {
      final statusLabel = _orderClientStatusLabel(client.status).toLowerCase();
      return _query.isEmpty ||
          client.name.toLowerCase().contains(_query) ||
          client.businessType.toLowerCase().contains(_query) ||
          client.city.toLowerCase().contains(_query) ||
          statusLabel.contains(_query);
    }).toList();
  }

  CommercialClient _visibleClient(CommercialClient client) {
    if (!_convertedProspects.contains(client.id)) return client;
    return client.copyWith(status: ClientStatus.visited);
  }

  Future<void> _selectClient(CommercialClient client) async {
    if (client.status == ClientStatus.inactive) {
      _showMessage('Ce client est inactif. Impossible de créer une commande.');
      return;
    }

    var orderClient = client;
    if (client.status == ClientStatus.toVisit) {
      final shouldConvert = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => _ProspectConversionSheet(
          onCancel: () => Navigator.pop(context, false),
          onConvert: () => Navigator.pop(context, true),
        ),
      );
      if (shouldConvert != true) return;
      setState(() => _convertedProspects.add(client.id));
      orderClient = client.copyWith(status: ClientStatus.visited);
      _showMessage('Client converti avec succès');
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NouvelleCommande(
          client: orderClient,
          currentEmail: widget.currentEmail,
          currentUserName: widget.currentUserName,
        ),
        settings: RouteSettings(arguments: {'clientId': orderClient.id}),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(AppLocalizations.globalText(message))),
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
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(8, 10, 18, 0),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: Icon(Icons.arrow_back_rounded),
                                color: _HomeCommercialState.textDark,
                              ),
                              Expanded(
                                child: Text(
                                  AppLocalizations.globalText(
                                    'Choisir un client',
                                  ),
                                  style: TextStyle(
                                    color: _HomeCommercialState.textDark,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(18, 14, 18, 0),
                          child: TextField(
                            controller: _searchController,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: AppLocalizations.globalText(
                                'Rechercher nom, commerce, ville, statut...',
                              ),
                              prefixIcon: Icon(Icons.search_rounded, size: 21),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 13,
                              ),
                              enabledBorder: _searchBorder(),
                              focusedBorder: _searchBorder(
                                color: _HomeCommercialState.primaryBlue,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 14),
                        Expanded(
                          child: clients.isEmpty
                              ? _EmptyClients()
                              : ListView.separated(
                                  padding: EdgeInsets.fromLTRB(18, 0, 18, 18),
                                  physics: BouncingScrollPhysics(),
                                  itemCount: clients.length,
                                  separatorBuilder: (context, index) =>
                                      SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final client = clients[index];
                                    return _OrderClientCard(
                                      client: client,
                                      onTap: () => _selectClient(client),
                                    );
                                  },
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

class _ProspectConversionSheet extends StatelessWidget {
  _ProspectConversionSheet({required this.onCancel, required this.onConvert});

  final VoidCallback onCancel;
  final VoidCallback onConvert;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 22, 22, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.globalText('Client prospect'),
            style: TextStyle(
              color: _HomeCommercialState.textDark,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 12),
          Text(
            AppLocalizations.globalText(
              'Ce client est encore un prospect. Vous devez le convertir en client actif avant de créer une commande.',
            ),
            style: TextStyle(
              color: _HomeCommercialState.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  child: Text(AppLocalizations.globalText('Annuler')),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onConvert,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _HomeCommercialState.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    AppLocalizations.globalText('Convertir en client'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _OrderClientCard extends StatelessWidget {
  _OrderClientCard({required this.client, required this.onTap});

  final CommercialClient client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inactive = client.status == ClientStatus.inactive;
    final revenue = client.orders.fold<double>(
      0,
      (total, order) => total + order.amount,
    );

    return Opacity(
      opacity: inactive ? .56 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: inactive ? Color(0xFFF8FAFC) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Color(0xFFE8EDF5)),
            boxShadow: inactive
                ? null
                : [
                    BoxShadow(
                      color: Color(0xFF18315E).withValues(alpha: .05),
                      blurRadius: 14,
                      offset: Offset(0, 7),
                    ),
                  ],
          ),
          child: Row(
            children: [
              _ClientAvatar(client: client),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _HomeCommercialState.textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${client.businessType} - ${client.city}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _HomeCommercialState.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        _TinyMetric('${client.orders.length} commandes'),
                        SizedBox(width: 8),
                        _TinyMetric('CA ${_money(revenue)}'),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(status: client.status),
                  SizedBox(height: 10),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: _HomeCommercialState.textMuted,
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

class _TinyMetric extends StatelessWidget {
  _TinyMetric(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: _HomeCommercialState.textDark,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class NouvelleCommande extends StatefulWidget {
  NouvelleCommande({
    super.key,
    required this.client,
    required this.currentEmail,
    required this.currentUserName,
  });

  final CommercialClient client;
  final String currentEmail;
  final String currentUserName;

  @override
  State<NouvelleCommande> createState() => _NouvelleCommandeState();
}

class _NouvelleCommandeState extends State<NouvelleCommande> {
  final _searchController = TextEditingController();
  final Map<int, int> _quantities = {};
  String _query = '';
  late DateTime _orderDate;
  late DateTime _deliveryDate;

  @override
  void initState() {
    super.initState();
    _orderDate = DateTime.now();
    _deliveryDate = _orderDate.add(Duration(days: 1));
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<OrderProduct> get _filteredProducts {
    return MockPreSalesData.orderProducts.where((product) {
      return _query.isEmpty ||
          product.name.toLowerCase().contains(_query) ||
          product.category.toLowerCase().contains(_query) ||
          product.reference.toLowerCase().contains(_query);
    }).toList();
  }

  double get _subtotal {
    return MockPreSalesData.orderProducts.fold(0, (total, product) {
      return total + (product.unitPrice * (_quantities[product.id] ?? 0));
    });
  }

  int get _distinctItems =>
      _quantities.values.where((quantity) => quantity > 0).length;

  int get _totalQuantity {
    return _quantities.values.fold(0, (total, quantity) => total + quantity);
  }

  double get _total => _subtotal;

  void _changeQuantity(OrderProduct product, int delta) {
    final current = _quantities[product.id] ?? 0;
    final next = (current + delta).clamp(0, product.stock);
    if (delta > 0 && product.stock == 0) return;
    if (delta > 0 && current >= product.stock) {
      _showMessage('Stock maximum atteint');
      return;
    }
    setState(() {
      if (next == 0) {
        _quantities.remove(product.id);
      } else {
        _quantities[product.id] = next;
      }
    });
  }

  Future<void> _clearCart() async {
    if (!_quantities.values.any((quantity) => quantity > 0)) return;

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.globalText('Vider le panier')),
          content: Text(
            AppLocalizations.globalText(
              'Voulez-vous supprimer tous les produits ?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.globalText('Annuler')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppLocalizations.globalText('Confirmer')),
            ),
          ],
        );
      },
    );

    if (shouldClear == true) setState(_quantities.clear);
  }

  Future<void> _pickDeliveryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deliveryDate,
      firstDate: DateTime(_orderDate.year, _orderDate.month, _orderDate.day),
      lastDate: _orderDate.add(Duration(days: 90)),
    );
    if (picked != null) setState(() => _deliveryDate = picked);
  }

  Future<void> _openScanner() async {
    final product = await showModalBottomSheet<OrderProduct>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _ScannerSimulationSheet(
        products: MockPreSalesData.orderProducts
            .where((product) => product.stock > 0)
            .toList(),
      ),
    );
    if (product == null) return;
    _changeQuantity(product, 1);
    _showMessage('Produit ajouté par scan');
  }

  Future<void> _saveDraft() async {
    final order = _buildOrder('Brouillon');
    _showMessage('Commande enregistrée en brouillon');
    await Future<void>.delayed(Duration(milliseconds: 500));
    if (!mounted) return;
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

  Future<void> _sendToManager() async {
    if (!_quantities.values.any((quantity) => quantity > 0)) {
      _showMessage('Veuillez ajouter au moins un produit à la commande.');
      return;
    }

    if (_deliveryDate.isBefore(_dateOnly(_orderDate))) {
      _showMessage(
        'La date de livraison ne peut pas être antérieure à la date de commande.',
      );
      return;
    }

    final order = _buildOrder('En attente');
    _showMessage('Commande envoyée au manager avec succès');
    await Future<void>.delayed(Duration(milliseconds: 650));
    if (!mounted) return;
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

  ValidatedOrder _buildOrder(String status) {
    final items = MockPreSalesData.orderProducts
        .where((product) => (_quantities[product.id] ?? 0) > 0)
        .map((product) {
          final quantity = _quantities[product.id] ?? 0;
          return ValidatedOrderItem(
            product: product,
            quantity: quantity,
            lineTotal: product.unitPrice * quantity,
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(AppLocalizations.globalText(message))),
      );
  }

  String _orderNumber(DateTime date) {
    final sequence = (date.millisecondsSinceEpoch % 10000).toString();
    return 'CMD-${date.year}-${sequence.padLeft(4, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;

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
                    child: Column(
                      children: [
                        Expanded(
                          child: CustomScrollView(
                            physics: BouncingScrollPhysics(),
                            slivers: [
                              SliverPadding(
                                padding: EdgeInsets.fromLTRB(18, 16, 18, 18),
                                sliver: SliverList(
                                  delegate: SliverChildListDelegate([
                                    _NewOrderHeader(
                                      client: widget.client,
                                      onBack: () => Navigator.pop(context),
                                      onClear: _clearCart,
                                      onChangeClient: () =>
                                          Navigator.pop(context),
                                    ),
                                    SizedBox(height: 14),
                                    _OrderDatesCard(
                                      orderDate: _orderDate,
                                      deliveryDate: _deliveryDate,
                                      onPickDeliveryDate: _pickDeliveryDate,
                                    ),
                                    SizedBox(height: 18),
                                    _ProductSearchBar(
                                      controller: _searchController,
                                      onScan: _openScanner,
                                    ),
                                    SizedBox(height: 18),
                                    if (products.isEmpty)
                                      _EmptyDetailMessage(
                                        text: 'Aucun produit trouvé',
                                      )
                                    else
                                      for (var i = 0; i < products.length; i++)
                                        _OrderProductTile(
                                          product: products[i],
                                          quantity:
                                              _quantities[products[i].id] ?? 0,
                                          isLast: i == products.length - 1,
                                          onMinus: () =>
                                              _changeQuantity(products[i], -1),
                                          onPlus: () =>
                                              _changeQuantity(products[i], 1),
                                        ),
                                    SizedBox(height: 14),
                                    _OrderTotals(
                                      distinctItems: _distinctItems,
                                      totalQuantity: _totalQuantity,
                                      subtotal: _subtotal,
                                      total: _total,
                                    ),
                                  ]),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(18, 10, 18, 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: OutlinedButton(
                                  onPressed: _saveDraft,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        _HomeCommercialState.textDark,
                                    side: BorderSide(color: Color(0xFFD7DEE9)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                  ),
                                  child: Text(
                                    AppLocalizations.globalText(
                                      'Enregistrer brouillon',
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: _sendToManager,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        _HomeCommercialState.primaryBlue,
                                    foregroundColor: Colors.white,
                                    elevation: 8,
                                    shadowColor: _HomeCommercialState
                                        .primaryBlue
                                        .withValues(alpha: .24),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                  ),
                                  child: Text(
                                    AppLocalizations.globalText(
                                      'Envoyer au manager',
                                    ),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
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
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NewOrderHeader extends StatelessWidget {
  _NewOrderHeader({
    required this.client,
    required this.onBack,
    required this.onClear,
    required this.onChangeClient,
  });

  final CommercialClient client;
  final VoidCallback onBack;
  final VoidCallback onClear;
  final VoidCallback onChangeClient;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: Icon(Icons.arrow_back_rounded),
              color: _HomeCommercialState.textDark,
            ),
            Spacer(),
            IconButton(
              onPressed: onClear,
              icon: Icon(Icons.delete_outline_rounded),
              color: Color(0xFFFF2F45),
            ),
          ],
        ),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Color(0xFFE8EDF5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ClientAvatar(client: client),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _HomeCommercialState.textDark,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          '${client.businessType} - ${client.city}',
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
                  SizedBox(width: 8),
                  _StatusBadge(status: client.status),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  _TinyMetric('${client.orders.length} commandes'),
                  SizedBox(width: 10),
                  _TinyMetric(
                    'CA ${_money(client.orders.fold<double>(0, (total, order) => total + order.amount))}',
                  ),
                  Spacer(),
                  TextButton(
                    onPressed: onChangeClient,
                    child: Text(AppLocalizations.globalText('Changer client')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrderDatesCard extends StatelessWidget {
  _OrderDatesCard({
    required this.orderDate,
    required this.deliveryDate,
    required this.onPickDeliveryDate,
  });

  final DateTime orderDate;
  final DateTime deliveryDate;
  final VoidCallback onPickDeliveryDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(0xFFE8EDF5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _DateInfo(
              label: 'Date commande',
              value: _shortDate(orderDate),
              icon: Icons.event_note_rounded,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onPickDeliveryDate,
              borderRadius: BorderRadius.circular(10),
              child: _DateInfo(
                label: 'Livraison',
                value: _shortDate(deliveryDate),
                icon: Icons.local_shipping_outlined,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateInfo extends StatelessWidget {
  _DateInfo({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _HomeCommercialState.primaryBlue, size: 18),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.globalText(label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _HomeCommercialState.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _HomeCommercialState.textDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
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
              fillColor: Colors.white,
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
          width: 46,
          height: 46,
          child: OutlinedButton(
            onPressed: onScan,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: BorderSide(color: Color(0xFFE3E8F2)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Icon(
              Icons.qr_code_scanner_rounded,
              color: _HomeCommercialState.textDark,
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
    required this.quantity,
    required this.isLast,
    required this.onMinus,
    required this.onPlus,
  });

  final OrderProduct product;
  final int quantity;
  final bool isLast;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final lineTotal = product.unitPrice * quantity;
    final outOfStock = product.stock == 0;
    final maxReached = product.stock > 0 && quantity >= product.stock;

    return Opacity(
      opacity: outOfStock ? .52 : 1,
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
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _HomeCommercialState.textDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    product.category,
                    style: TextStyle(
                      color: _HomeCommercialState.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Prix : ${_mad(product.unitPrice)}',
                    style: TextStyle(
                      color: _HomeCommercialState.textDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    outOfStock
                        ? AppLocalizations.globalText('Rupture')
                        : 'Stock : ${product.stock} unités',
                    style: TextStyle(
                      color: outOfStock
                          ? Color(0xFFFF3B30)
                          : _HomeCommercialState.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (maxReached) ...[
                    SizedBox(height: 4),
                    Text(
                      AppLocalizations.globalText('Stock maximum atteint'),
                      style: TextStyle(
                        color: Color(0xFFFF8A1F),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
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
                SizedBox(height: 7),
                Text(
                  'Quantité : $quantity',
                  style: TextStyle(
                    color: _HomeCommercialState.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  _mad(lineTotal),
                  style: TextStyle(
                    color: _HomeCommercialState.textDark,
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
                fontWeight: FontWeight.w900,
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
  _ScannerSimulationSheet({required this.products});

  final List<OrderProduct> products;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 22, 22, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.globalText('Simulation scan code-barres'),
            style: TextStyle(
              color: _HomeCommercialState.textDark,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 14),
          for (final product in products.take(4))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _ProductImage(product: product),
              title: Text(
                product.name,
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text('${product.category} · Stock ${product.stock}'),
              trailing: Icon(
                Icons.add_circle_rounded,
                color: _HomeCommercialState.primaryBlue,
              ),
              onTap: () => Navigator.pop(context, product),
            ),
        ],
      ),
    );
  }
}

class _OrderTotals extends StatelessWidget {
  _OrderTotals({
    required this.distinctItems,
    required this.totalQuantity,
    required this.subtotal,
    required this.total,
  });

  final int distinctItems;
  final int totalQuantity;
  final double subtotal;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(0xFFE8EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.globalText('Résumé de la commande'),
            style: TextStyle(
              color: _HomeCommercialState.textDark,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 14),
          _TotalRow(
            label: AppLocalizations.globalText("Nombre d'articles"),
            value: '$distinctItems articles',
          ),
          SizedBox(height: 10),
          _TotalRow(
            label: AppLocalizations.globalText('Total quantité'),
            value: '$totalQuantity unités',
          ),
          SizedBox(height: 10),
          _TotalRow(
            label: AppLocalizations.globalText('Sous-total net'),
            value: _mad(subtotal),
          ),
          SizedBox(height: 14),
          _TotalRow(
            label: AppLocalizations.globalText('Total TTC'),
            value: _mad(total),
            large: true,
          ),
        ],
      ),
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
            color: large
                ? _HomeCommercialState.textDark
                : _HomeCommercialState.textMuted,
            fontSize: large ? 16 : 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        Spacer(),
        Text(
          value,
          style: TextStyle(
            color: _HomeCommercialState.textDark,
            fontSize: large ? 17 : 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

String _mad(num value) =>
    '${value.toStringAsFixed(2).replaceAll('.', ',')} MAD';

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
              AppLocalizations.globalText('Commande créée avec succès !'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _HomeCommercialState.textDark,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'N° ${order.orderNumber}',
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
              label: AppLocalizations.globalText('Livraison'),
              value: _shortDate(order.deliveryDate ?? order.date),
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
                  AppLocalizations.globalText("Retour à l'accueil"),
                  style: TextStyle(fontWeight: FontWeight.w900),
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
              AppLocalizations.globalText('Aucune commande trouvée'),
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
              child: Text(AppLocalizations.globalText("Retour à l'accueil")),
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

String _shortDate(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
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
        backgroundColor: Colors.white,
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
            PopupMenuItem(
              value: 'remove',
              child: Text(
                AppLocalizations.globalText('Supprimer de la tournée'),
              ),
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
                client.city,
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
            value: '${_money(client.balance)} MAD',
          ),
          _SummaryDivider(),
          _SummaryItem(
            label: AppLocalizations.globalText('Dernière commande'),
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
    required this.onCall,
    required this.onEmail,
    required this.onMaps,
  });

  final int selectedIndex;
  final CommercialClient client;
  final VoidCallback onCall;
  final VoidCallback onEmail;
  final VoidCallback onMaps;

  @override
  Widget build(BuildContext context) {
    if (selectedIndex == 1) return _HistoryCard(orders: client.orders);
    if (selectedIndex == 2) return _DocumentsCard(documents: client.documents);
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
            label: AppLocalizations.globalText('Téléphone'),
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
            label: AppLocalizations.globalText('Limite de crédit'),
            value: '${_money(client.creditLimit)} MAD',
          ),
          _InfoValueRow(
            icon: Icons.percent_rounded,
            label: AppLocalizations.globalText('Remise autorisée'),
            value: '${client.discount.round()}%',
          ),
          _InfoValueRow(
            icon: Icons.account_balance_wallet_outlined,
            label: AppLocalizations.globalText('Solde'),
            value: '${_money(client.balance)} MAD',
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
  _HistoryCard({required this.orders});

  final List<ClientOrder> orders;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      child: orders.isEmpty
          ? _EmptyDetailMessage(text: 'Aucune commande enregistrée')
          : Column(
              children: [
                for (var i = 0; i < orders.length; i++)
                  _SimpleDetailRow(
                    icon: Icons.receipt_long_rounded,
                    title: orders[i].reference,
                    subtitle: orders[i].date,
                    value: '${_money(orders[i].amount)} MAD',
                    isLast: i == orders.length - 1,
                  ),
              ],
            ),
    );
  }
}

class _DocumentsCard extends StatelessWidget {
  _DocumentsCard({required this.documents});

  final List<ClientDocument> documents;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      child: documents.isEmpty
          ? _EmptyDetailMessage(text: 'Aucun document disponible')
          : Column(
              children: [
                for (var i = 0; i < documents.length; i++)
                  _SimpleDetailRow(
                    icon: Icons.description_outlined,
                    title: documents[i].type,
                    subtitle: documents[i].reference,
                    value: documents[i].date,
                    isLast: i == documents.length - 1,
                  ),
              ],
            ),
    );
  }
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
                    'Détail du client : ${client.name}',
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

class _ClientTabs extends StatelessWidget {
  _ClientTabs({
    required this.selectedStatus,
    required this.statuses,
    required this.onChanged,
  });

  final ClientStatus? selectedStatus;
  final List<ClientStatus?> statuses;
  final ValueChanged<ClientStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Row(
        children: [
          for (final status in statuses)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(status),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _tabLabel(status),
                      style: TextStyle(
                        color: selectedStatus == status
                            ? _HomeCommercialState.primaryBlue
                            : _HomeCommercialState.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 8),
                    AnimatedContainer(
                      duration: Duration(milliseconds: 180),
                      width: selectedStatus == status ? 28 : 0,
                      height: 2,
                      decoration: BoxDecoration(
                        color: _HomeCommercialState.primaryBlue,
                        borderRadius: BorderRadius.circular(999),
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

  String _tabLabel(ClientStatus? status) {
    if (status == null) return 'Tous';
    if (status == ClientStatus.toVisit) return 'A visiter';
    if (status == ClientStatus.visited) return 'Visités';
    return 'Inactifs';
  }
}

class _ClientCard extends StatelessWidget {
  _ClientCard({required this.client, required this.onTap});

  final CommercialClient client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
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
            _ClientAvatar(client: client),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    client.city,
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
            _StatusBadge(status: client.status),
          ],
        ),
      ),
    );
  }
}

class _ClientAvatar extends StatelessWidget {
  _ClientAvatar({required this.client});

  final CommercialClient client;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: _avatarColor(client.id),
      child: Text(
        client.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Color _avatarColor(int id) {
    final colors = [
      Color(0xFF78AFFF),
      Color(0xFFFF8A76),
      Color(0xFF8FDFAE),
      Color(0xFFA88AF4),
      Color(0xFFFFA16B),
    ];
    return colors[id % colors.length];
  }
}

class _StatusBadge extends StatelessWidget {
  _StatusBadge({required this.status});

  final ClientStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = _badgeColors(status);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _orderClientStatusLabel(status),
        style: TextStyle(
          color: colors.$2,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  (Color, Color) _badgeColors(ClientStatus status) {
    return switch (status) {
      ClientStatus.toVisit => (Color(0xFFE5FAEF), Color(0xFF20B875)),
      ClientStatus.visited => (Color(0xFFE5FAEF), Color(0xFF20B875)),
      ClientStatus.inactive => (Color(0xFFFFECEA), Color(0xFFFF6B57)),
    };
  }
}

String _orderClientStatusLabel(ClientStatus status) {
  return switch (status) {
    ClientStatus.toVisit => 'Prospect',
    ClientStatus.visited => 'Actif',
    ClientStatus.inactive => 'Inactif',
  };
}

class _EmptyClients extends StatelessWidget {
  _EmptyClients();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        AppLocalizations.globalText('Aucun client trouvé'),
        style: TextStyle(
          color: _HomeCommercialState.textMuted,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FilterLabel extends StatelessWidget {
  _FilterLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: _HomeCommercialState.textDark,
        fontSize: 13,
        fontWeight: FontWeight.w900,
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

InputDecoration _sheetDecoration() {
  return InputDecoration(
    filled: true,
    fillColor: Color(0xFFF7F9FD),
    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    enabledBorder: _searchBorder(),
    focusedBorder: _searchBorder(color: _HomeCommercialState.primaryBlue),
  );
}

class _DashboardTab extends StatelessWidget {
  _DashboardTab({
    required this.userName,
    required this.summary,
    required this.activities,
    required this.orders,
    required this.clients,
    required this.currentEmail,
    required this.onNavigate,
  });

  final String userName;
  final CommercialDashboardSummary summary;
  final List<CommercialActivity> activities;
  final List<CommercialOrder> orders;
  final List<CommercialClient> clients;
  final String currentEmail;
  final ValueChanged<int> onNavigate;

  static const _navy = Color(0xFF0F172A);
  static const _blue = Color(0xFF2563EB);
  static const _green = Color(0xFF22C55E);
  static const _orange = Color(0xFFF59E0B);

  void _openNotifications(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CommercialNotificationsPage()),
    );
  }

  void _openNewOrder(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectionClientCommande(
          clients: clients,
          currentEmail: currentEmail,
          currentUserName: userName,
        ),
      ),
    );
  }

  void _openOrder(BuildContext context, CommercialOrder order) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailCommande(order: order)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recentOrders = _dashboardOrders;

    return CustomScrollView(
      physics: BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(22, 24, 22, 22),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _CommercialHomeHeader(
                userName: _firstName(userName),
                onNotificationTap: () => _openNotifications(context),
                onAvatarTap: () => onNavigate(4),
              ),
              SizedBox(height: 22),
              _DailyObjectiveCard(),
              SizedBox(height: 18),
              _QuickStatsGrid(),
              SizedBox(height: 18),
              _NewOrderAction(onTap: () => _openNewOrder(context)),
              SizedBox(height: 22),
              _SectionTitle(
                title: AppLocalizations.globalText('Dernières commandes'),
                action: 'Voir tout',
                onActionTap: () => onNavigate(2),
              ),
              SizedBox(height: 12),
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
              ),
              SizedBox(height: 12),
              _RecentActivityCard(),
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

  static List<CommercialOrder> get _dashboardOrders {
    return [
      CommercialOrder(
        id: 1024,
        orderNumber: 'CMD-1024',
        clientName: 'Marjane Californie',
        date: '02/06/2026',
        productsCount: 6,
        total: 4850,
        status: OrderStatus.pending,
        items: [
          OrderLine(
            productName: 'Assortiment boissons',
            quantity: 12,
            total: 1850,
          ),
          OrderLine(productName: 'Snacking premium', quantity: 8, total: 3000),
        ],
      ),
      CommercialOrder(
        id: 1023,
        orderNumber: 'CMD-1023',
        clientName: 'Café Atlas',
        date: '02/06/2026',
        productsCount: 4,
        total: 2300,
        status: OrderStatus.delivered,
        items: [
          OrderLine(productName: 'Pack café & jus', quantity: 10, total: 2300),
        ],
      ),
      CommercialOrder(
        id: 1022,
        orderNumber: 'CMD-1022',
        clientName: 'Superette Amal',
        date: '01/06/2026',
        productsCount: 3,
        total: 1780,
        status: OrderStatus.cancelled,
        items: [
          OrderLine(productName: 'Commande mixte', quantity: 7, total: 1780),
        ],
      ),
    ];
  }
}

class _CommercialHomeHeader extends StatelessWidget {
  _CommercialHomeHeader({
    required this.userName,
    required this.onNotificationTap,
    required this.onAvatarTap,
  });

  final String userName;
  final VoidCallback onNotificationTap;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour, $userName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _DashboardTab._navy,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              SizedBox(height: 6),
              Text(
                AppLocalizations.globalText(
                  "Suivez vos performances commerciales",
                ),
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: onNotificationTap,
              icon: Icon(Icons.notifications_none_rounded),
              color: _DashboardTab._navy,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                shadowColor: Color(0xFF0F172A).withValues(alpha: .10),
                elevation: 4,
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: Color(0xFFFF4D5D),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        SizedBox(width: 10),
        GestureDetector(
          onTap: onAvatarTap,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_DashboardTab._blue, Color(0xFF38BDF8)],
              ),
              boxShadow: [
                BoxShadow(
                  color: _DashboardTab._blue.withValues(alpha: .22),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Text(
                AppLocalizations.globalText('YC'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DailyObjectiveCard extends StatelessWidget {
  _DailyObjectiveCard();

  @override
  Widget build(BuildContext context) {
    final progress = .68;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.globalText('Objectif du jour'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  AppLocalizations.globalText('En bonne progression'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 18),
          Text(
            '68%',
            style: TextStyle(
              color: Colors.white,
              fontSize: 40,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            AppLocalizations.globalText('17 commandes / 25 objectif'),
            style: TextStyle(
              color: Color(0xFFD9E6FF),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 9,
                  value: value,
                  backgroundColor: Colors.white.withValues(alpha: .22),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _DashboardTab._green,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickStatsGrid extends StatelessWidget {
  _QuickStatsGrid();

  @override
  Widget build(BuildContext context) {
    final stats = [
      _QuickStatData(
        Icons.shopping_bag_outlined,
        '12',
        "Commandes aujourd'hui",
      ),
      _QuickStatData(Icons.hourglass_top_rounded, '5', 'Commandes en attente'),
      _QuickStatData(Icons.storefront_rounded, '8', 'Clients visités'),
      _QuickStatData(Icons.payments_outlined, '24 500 DH', 'CA du mois'),
    ];

    return GridView.builder(
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: stats.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) => _QuickStatCard(data: stats[index]),
    );
  }
}

class _QuickStatData {
  _QuickStatData(this.icon, this.value, this.label);

  final IconData icon;
  final String value;
  final String label;
}

class _QuickStatCard extends StatelessWidget {
  _QuickStatCard({required this.data});

  final _QuickStatData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(15),
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
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _DashboardTab._blue.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: _DashboardTab._blue, size: 21),
          ),
          Spacer(),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _DashboardTab._navy,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 4),
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            AppLocalizations.globalText(''),
            style: TextStyle(
              color: _DashboardTab._green,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewOrderAction extends StatelessWidget {
  _NewOrderAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: _DashboardTab._blue,
            boxShadow: [
              BoxShadow(
                color: _DashboardTab._blue.withValues(alpha: .28),
                blurRadius: 22,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.add_rounded, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.globalText('Nouvelle commande'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: Colors.white),
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
              fontWeight: FontWeight.w900,
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
            child: Text(action!, style: TextStyle(fontWeight: FontWeight.w900)),
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
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Client : ${order.clientName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${_money(order.total)} DH',
                      style: TextStyle(
                        color: _DashboardTab._navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
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
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  _RecentActivityCard();

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.check_circle_outline_rounded,
        'Visite client terminée',
        _DashboardTab._green,
      ),
      (Icons.send_rounded, 'Commande envoyée au manager', _DashboardTab._blue),
      (
        Icons.person_add_alt_rounded,
        'Nouveau client ajouté',
        _DashboardTab._orange,
      ),
    ];

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
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: items[i].$3.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(items[i].$1, color: items[i].$3, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    items[i].$2,
                    style: TextStyle(
                      color: _DashboardTab._navy,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  AppLocalizations.globalText("Aujourd'hui"),
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            if (i != items.length - 1)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: Color(0xFFE2E8F0)),
              ),
          ],
        ],
      ),
    );
  }
}

class CommercialNotificationsPage extends StatelessWidget {
  CommercialNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _HomeCommercialState.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _DashboardTab._navy,
        elevation: 0,
        title: Text(AppLocalizations.globalText('Notifications')),
      ),
      body: ListView(
        padding: EdgeInsets.all(20),
        children: [
          _NotificationTile(
            icon: Icons.schedule_rounded,
            title: AppLocalizations.globalText('Commande en attente'),
            subtitle: AppLocalizations.globalText(
              'CMD-1024 attend la validation du manager.',
            ),
          ),
          _NotificationTile(
            icon: Icons.check_circle_outline_rounded,
            title: AppLocalizations.globalText('Objectif du jour'),
            subtitle: AppLocalizations.globalText(
              'Vous êtes à 68% de votre objectif quotidien.',
            ),
          ),
          _NotificationTile(
            icon: Icons.storefront_rounded,
            title: AppLocalizations.globalText('Visite terminée'),
            subtitle: AppLocalizations.globalText(
              'La visite client Marjane Californie est enregistrée.',
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  _NotificationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0F172A).withValues(alpha: .06),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: _DashboardTab._blue),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _DashboardTab._navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Color(0xFF64748B),
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

String _dashboardStatusLabel(OrderStatus status) {
  return switch (status) {
    OrderStatus.pending => AppLocalizations.globalText('En attente'),
    OrderStatus.synced => AppLocalizations.globalText('Validée'),
    OrderStatus.delivered => AppLocalizations.globalText('Validée'),
    OrderStatus.cancelled => AppLocalizations.globalText('Refusée'),
  };
}

Color _dashboardStatusColor(OrderStatus status) {
  return switch (status) {
    OrderStatus.pending => _DashboardTab._orange,
    OrderStatus.synced => _DashboardTab._green,
    OrderStatus.delivered => _DashboardTab._green,
    OrderStatus.cancelled => Color(0xFFEF4444),
  };
}

class _CommercialBottomNav extends StatelessWidget {
  _CommercialBottomNav({required this.selectedIndex, required this.onChanged});

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static final _items = [
    (Icons.home_rounded, 'Accueil'),
    (Icons.groups_rounded, 'Clients'),
    (Icons.receipt_long_rounded, 'Commandes'),
    (Icons.event_available_rounded, 'Activit\u00E9s'),
    (Icons.person_outline_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
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
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: _items[i].$1,
                    label: _items[i].$2,
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
