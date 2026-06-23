import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../auth/current_user_session.dart';
import '../../data/mock_presales_data.dart';

class OrdersScreen extends StatefulWidget {
  OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _searchController = TextEditingController();
  OrderStatus? _selectedStatus;
  String _query = '';

  static const primaryBlue = Color(0xFF2563EB);
  static const textDark = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const surface = Color(0xFFF8FAFC);
  static const success = Color(0xFF22C55E);
  static const pending = Color(0xFFFB923C);
  static const rejected = Color(0xFFEF4444);

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

  @override
  Widget build(BuildContext context) {
    final sessionUser = CurrentUserSession.currentUser;
    final user = sessionUser?.isCommercial == true
        ? MockPreSalesData.userByEmail(sessionUser!.email)
        : null;

    if (sessionUser == null || user == null) {
      return Scaffold(
        backgroundColor: surface,
        body: Center(
          child: Text(
            AppLocalizations.globalText('Utilisateur non authentifié'),
          ),
        ),
      );
    }

    final orders = MockPreSalesData.ordersForUser(user);
    return Scaffold(
      backgroundColor: surface,
      body: SafeArea(
        child: _OrdersContent(
          orders: orders,
          searchController: _searchController,
          selectedStatus: _selectedStatus,
          query: _query,
          onStatusChanged: (status) => setState(() => _selectedStatus = status),
        ),
      ),
    );
  }
}

class _OrdersContent extends StatefulWidget {
  _OrdersContent({
    required this.orders,
    required this.searchController,
    required this.selectedStatus,
    required this.query,
    required this.onStatusChanged,
  });

  final List<CommercialOrder> orders;
  final TextEditingController searchController;
  final OrderStatus? selectedStatus;
  final String query;
  final ValueChanged<OrderStatus?> onStatusChanged;

  @override
  State<_OrdersContent> createState() => _OrdersContentState();
}

class _OrdersContentState extends State<_OrdersContent> {
  List<CommercialOrder> get _filteredOrders {
    return widget.orders.where((order) {
      final matchesSearch =
          widget.query.isEmpty ||
          order.orderNumber.toLowerCase().contains(widget.query) ||
          order.clientName.toLowerCase().contains(widget.query);
      final matchesStatus =
          widget.selectedStatus == null ||
          order.status == widget.selectedStatus;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  int get _validatedCount =>
      widget.orders.where((o) => o.status == OrderStatus.synced).length;
  int get _rejectedCount =>
      widget.orders.where((o) => o.status == OrderStatus.cancelled).length;
  int get _pendingCount =>
      widget.orders.where((o) => o.status == OrderStatus.pending).length;

  void _openFilterSheet() {
    _showMobileOrdersSheet<void>(
      context: context,
      child: _OrderStatusFilterSheet(
        selectedStatus: widget.selectedStatus,
        statuses: const [
          null,
          OrderStatus.pending,
          OrderStatus.synced,
          OrderStatus.cancelled,
        ],
        onSelected: (status) {
          widget.onStatusChanged(status);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredOrders = _filteredOrders;

    return CustomScrollView(
      physics: BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.globalText('Commandes'),
                          style: TextStyle(
                            color: _OrdersScreenState.textDark,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          AppLocalizations.globalText(
                            'Suivez et gérez vos commandes',
                          ),
                          style: TextStyle(
                            color: _OrdersScreenState.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
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
                        color: _OrdersScreenState.textDark,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          shadowColor: Color(0xFF0F172A).withValues(alpha: .10),
                          elevation: 4,
                        ),
                      ),
                      Positioned(
                        right: 5,
                        top: 2,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Color(0xFFFF2F45),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '3',
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
                  ),
                ],
              ),
              SizedBox(height: 22),

              // KPI Cards
              Row(
                children: [
                  Expanded(
                    child: _KpiCard(
                      icon: Icons.receipt_long_rounded,
                      label: AppLocalizations.globalText('Total commandes'),
                      value: '${widget.orders.length}',
                      iconColor: _OrdersScreenState.primaryBlue,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _KpiCard(
                      icon: Icons.schedule_rounded,
                      label: AppLocalizations.globalText('En attente'),
                      value: '$_pendingCount',
                      iconColor: _OrdersScreenState.pending,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _KpiCard(
                      icon: Icons.check_circle_outline_rounded,
                      label: AppLocalizations.globalText('Valid\u00E9es'),
                      value: '$_validatedCount',
                      iconColor: _OrdersScreenState.success,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _KpiCard(
                      icon: Icons.cancel_outlined,
                      label: AppLocalizations.globalText('Refus\u00E9es'),
                      value: '$_rejectedCount',
                      iconColor: _OrdersScreenState.rejected,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18),

              // Search + Filter
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.searchController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.globalText(
                          'Rechercher une commande...',
                        ),
                        prefixIcon: Icon(Icons.search_rounded, size: 24),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                        enabledBorder: _searchBorder(),
                        focusedBorder: _searchBorder(
                          color: _OrdersScreenState.primaryBlue,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  SizedBox(
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: _openFilterSheet,
                      icon: Icon(Icons.filter_alt_outlined, size: 20),
                      label: Text(AppLocalizations.globalText('Filtrer')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _OrdersScreenState.textDark,
                        backgroundColor: Colors.white,
                        side: BorderSide(color: Color(0xFFE2E8F0)),
                        padding: EdgeInsets.symmetric(horizontal: 14),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18),

              // Quick Filter Chips
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: BouncingScrollPhysics(),
                  children: [
                    _FilterChip(
                      label: AppLocalizations.globalText('Toutes'),
                      selected: widget.selectedStatus == null,
                      onPressed: () => widget.onStatusChanged(null),
                    ),
                    SizedBox(width: 8),
                    _FilterChip(
                      label: AppLocalizations.globalText('En attente'),
                      selected: widget.selectedStatus == OrderStatus.pending,
                      onPressed: () =>
                          widget.onStatusChanged(OrderStatus.pending),
                    ),
                    SizedBox(width: 8),
                    _FilterChip(
                      label: AppLocalizations.globalText('Valid\u00E9es'),
                      selected: widget.selectedStatus == OrderStatus.synced,
                      onPressed: () =>
                          widget.onStatusChanged(OrderStatus.synced),
                    ),
                    SizedBox(width: 8),
                    _FilterChip(
                      label: AppLocalizations.globalText('Refus\u00E9es'),
                      selected: widget.selectedStatus == OrderStatus.cancelled,
                      onPressed: () =>
                          widget.onStatusChanged(OrderStatus.cancelled),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 18),

              // Orders List
              if (filteredOrders.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      AppLocalizations.globalText('Aucune commande disponible'),
                      style: TextStyle(
                        color: _OrdersScreenState.textMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                )
              else
                for (int i = 0; i < filteredOrders.length; i++) ...[
                  _OrderCard(order: filteredOrders[i]),
                  if (i < filteredOrders.length - 1) SizedBox(height: 12),
                ],
              SizedBox(height: 100),
            ]),
          ),
        ),
      ],
    );
  }
}

Future<T?> _showMobileOrdersSheet<T>({
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

class _OrderStatusFilterSheet extends StatelessWidget {
  const _OrderStatusFilterSheet({
    required this.selectedStatus,
    required this.statuses,
    required this.onSelected,
  });

  final OrderStatus? selectedStatus;
  final List<OrderStatus?> statuses;
  final ValueChanged<OrderStatus?> onSelected;

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
                  color: _OrdersScreenState.textDark,
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
              for (final status in statuses)
                InkWell(
                  onTap: () => onSelected(status),
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
                              color: selectedStatus == status
                                  ? _OrdersScreenState.primaryBlue
                                  : Color(0xFFCBD5E1),
                              width: 2,
                            ),
                          ),
                          child: selectedStatus == status
                              ? Center(
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _OrdersScreenState.primaryBlue,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _orderStatusLabel(status),
                            softWrap: true,
                            style: TextStyle(
                              color: _OrdersScreenState.textDark,
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

class _KpiCard extends StatelessWidget {
  _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0F172A).withValues(alpha: .06),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _OrdersScreenState.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _OrdersScreenState.textDark,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  _FilterChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _OrdersScreenState.primaryBlue : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? _OrdersScreenState.primaryBlue
                  : Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : _OrdersScreenState.textDark,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  _OrderCard({required this.order});

  final CommercialOrder order;

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(order.status);
    final statusLabel = _orderStatusLabel(order.status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0F172A).withValues(alpha: .07),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(14),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Order Number + Client Name + Date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            order.orderNumber,
                            style: TextStyle(
                              color: _OrdersScreenState.textDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            order.clientName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _OrdersScreenState.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            order.date,
                            style: TextStyle(
                              color: _OrdersScreenState.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 10),
                    // Amount + Status
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _formatAmount(order.total),
                          style: TextStyle(
                            color: _OrdersScreenState.textDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 6),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: _OrdersScreenState.textMuted,
                      size: 20,
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

  Color _getStatusColor(OrderStatus status) {
    return switch (status) {
      OrderStatus.pending => _OrdersScreenState.pending,
      OrderStatus.synced => _OrdersScreenState.success,
      OrderStatus.delivered => _OrdersScreenState.success,
      OrderStatus.cancelled => _OrdersScreenState.rejected,
    };
  }

  String _formatAmount(double amount) {
    return '${amount.toStringAsFixed(0)} DH';
  }
}

String _orderStatusLabel(OrderStatus? status) {
  if (status == null) return AppLocalizations.globalText('Toutes');
  return switch (status) {
    OrderStatus.pending => AppLocalizations.globalText('En attente'),
    OrderStatus.synced => AppLocalizations.globalText('Valid\u00E9e'),
    OrderStatus.delivered => AppLocalizations.globalText('Livr\u00E9e'),
    OrderStatus.cancelled => AppLocalizations.globalText('Refus\u00E9e'),
  };
}

InputBorder _searchBorder({Color? color}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color ?? Color(0xFFE2E8F0), width: 1.5),
  );
}
