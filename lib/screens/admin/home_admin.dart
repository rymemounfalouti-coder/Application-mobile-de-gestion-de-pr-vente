import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../auth/current_user_session.dart';
import '../../data/mock_presales_data.dart';
import '../../data/product_image_assets.dart';
import '../../l10n/app_locale_controller.dart';
import '../../settings/app_appearance_controller.dart';
import '../../services/local_json_store.dart';
import '../manager/home_manager_screen.dart' show ManagerCommercialsCache;
import 'admin_screens.dart';

String _money(num v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final fromEnd = s.length - i;
    b.write(s[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) b.write(' ');
  }
  return b.toString();
}

/// Rounds up to a "nice" axis ceiling (1/2/5 × 10ⁿ) so the Y scale reads
/// cleanly, e.g. 87 900 -> 100000.
double _niceCeil(double v) {
  if (v <= 0) return 1;
  final mag = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
  final n = v / mag;
  final step = n <= 1
      ? 1.0
      : n <= 2
      ? 2.0
      : n <= 5
      ? 5.0
      : 10.0;
  return step * mag;
}

/// Short axis labels: 100000 -> "100k", 1500000 -> "1.5M".
String _compactAmount(double v) {
  if (v >= 1000000) {
    final m = v / 1000000;
    return '${m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toStringAsFixed(1)}M';
  }
  if (v >= 1000) {
    final k = v / 1000;
    return '${k == k.roundToDouble() ? k.toStringAsFixed(0) : k.toStringAsFixed(1)}k';
  }
  return v.toStringAsFixed(0);
}

const List<String> _teaProductCategories = [
  'Thé Vert Premium',
  'Thé Vert Classique',
];

List<String> _normalizeCategories(Iterable<String> values) {
  final result = <String>[];
  final seen = <String>{};
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || !seen.add(trimmed.toLowerCase())) continue;
    result.add(trimmed);
  }
  result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return result;
}

String _categoryStoreName(String kind) => 'admin_categories_${kind}_v1.json';

/// The admin-configured category list for [kind] ('client' | 'product'),
/// read from the same local store [CategoryManagerScreen] edits. Falls back
/// to [fallback] if that screen has never been opened (no store yet) or the
/// stored file can't be read.
Future<List<String>> _loadCategoryOptions(
  String kind,
  List<String> fallback,
) async {
  try {
    final stored = await readLocalJson(_categoryStoreName(kind));
    if (stored != null) {
      final decoded = jsonDecode(stored);
      final raw = decoded is Map ? decoded['categories'] : decoded;
      if (raw is List) {
        final categories = _normalizeCategories(
          raw.map((value) => value.toString()),
        );
        if (categories.isNotEmpty) return categories;
      }
    }
  } catch (_) {
    // Fall through to the default list below.
  }
  return fallback;
}

const String _adminTemporaryPassword = 'Temp@1234';

Future<bool> _confirmDestructiveAction(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kRed),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

Future<void> _showTemporaryPassword(BuildContext context, String password) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mot de passe réinitialisé'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Communiquez ce mot de passe temporaire à l’utilisateur :',
            ),
            const SizedBox(height: 12),
            SelectableText(
              password,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Compris'),
          ),
        ],
      ),
    );

void _snack(BuildContext c, String msg, {bool success = true}) {
  final color = success ? kGreen : kRed;
  final icon = success ? Icons.check_circle_rounded : Icons.error_rounded;
  ScaffoldMessenger.of(c).showSnackBar(
    SnackBar(
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

String _createdUserMessage(MockUserRole role) => switch (role) {
  MockUserRole.commercial => 'Commercial créé avec succès.',
  MockUserRole.manager => 'Manager créé avec succès.',
  MockUserRole.admin => 'Administrateur créé avec succès.',
};

String _adminString(Map<dynamic, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString().trim();
    }
  }
  return '';
}

int _adminInt(Map<dynamic, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return 0;
}

double _adminDouble(Map<dynamic, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is double) return value;
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(
      (value?.toString() ?? '').replaceAll(',', '.'),
    );
    if (parsed != null) return parsed;
  }
  return 0;
}

String _adminStatus(String value) {
  final status = value.toLowerCase().trim();
  if (['validee', 'validée', 'validated', 'valide'].contains(status)) {
    return 'validated';
  }
  if (['refusee', 'refusée', 'refused', 'refuse'].contains(status)) {
    return 'refused';
  }
  return 'pending';
}

String _adminDateLabel(Map<dynamic, dynamic> json) {
  final raw = _adminString(json, ['created_at', 'date', 'date_commande']);
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw.isEmpty ? '-' : raw;
  return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
}

AdminOrder adminOrderFromJson(Map<dynamic, dynamic> json) {
  final id = _adminInt(json, ['id', 'commande_id']);
  final total = _adminDouble(json, ['total', 'montant_total', 'amount']);
  final itemsRaw =
      json['details'] ?? json['items'] ?? json['lignes'] ?? json['produits'];
  final items = itemsRaw is List
      ? itemsRaw.whereType<Map>().map((item) {
          final qty = _adminInt(item, ['quantity', 'quantite', 'qty', 'qte']);
          final unit = _adminDouble(item, [
            'unit_price',
            'prix_unitaire',
            'prix',
          ]);
          return AdminOrderItem(
            _adminString(item, [
              'product_name',
              'nom_produit',
              'name',
            ]).ifEmpty('Produit'),
            qty,
            unit,
            _adminDouble(item, ['total', 'total_ligne']).nonZero(qty * unit),
          );
        }).toList()
      : <AdminOrderItem>[];
  return AdminOrder(
    number: _adminString(json, [
      'numero',
      'order_number',
      'reference',
    ]).ifEmpty('CMD-$id'),
    client: _adminString(json, [
      'client_name',
      'client',
      'nom_client',
    ]).ifEmpty('Client'),
    commercial: _adminString(json, [
      'commercial_name',
      'commercial',
      'vendeur',
    ]).ifEmpty('Commercial'),
    date: _adminDateLabel(json),
    total: total,
    subtotal: _adminDouble(json, ['subtotal', 'sous_total']).nonZero(total),
    discount: _adminDouble(json, ['discount', 'remise']),
    status: _adminStatus(_adminString(json, ['status', 'statut'])),
    items: items,
  );
}

int _adminGlobalClientCount({required List<dynamic> clients}) {
  final keys = <String>{};
  void addClient({Object? id, String name = ''}) {
    final normalizedName = _adminNormalizeKey(name);
    if (normalizedName.isNotEmpty) {
      keys.add('name:$normalizedName');
      return;
    }
    final parsedId = id is int
        ? id
        : id is num
        ? id.toInt()
        : int.tryParse(id?.toString() ?? '') ?? 0;
    if (parsedId > 0) keys.add('id:$parsedId');
  }

  for (final item in clients.whereType<Map>()) {
    addClient(
      id: _adminInt(item, ['id', 'client_id', 'id_client']),
      name: _adminString(item, ['name', 'nom', 'nom_client', 'client_name']),
    );
  }
  return keys.length;
}

String _adminNormalizeKey(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

extension _AdminHomeStringFallback on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}

extension _AdminHomeNumFallback on num {
  double nonZero(num fallback) => this == 0 ? fallback.toDouble() : toDouble();
}

/// Keeps pushed pages at phone width (centered on desktop, full-width on phone).
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: kBg,
    child: LayoutBuilder(
      builder: (context, constraints) {
        // Phones fill the screen; only wide (desktop) viewports get the
        // centered 430px phone-shaped panel.
        final width = constraints.maxWidth > 600 ? 430.0 : constraints.maxWidth;
        return Center(
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: child,
          ),
        );
      },
    ),
  );
}

Route<T> phoneRoute<T>(Widget page) =>
    MaterialPageRoute<T>(builder: (_) => PhoneFrame(child: page));

// ---------------------------------------------------------------------------
// Shell
// ---------------------------------------------------------------------------

class HomeAdmin extends StatefulWidget {
  const HomeAdmin({super.key});
  @override
  State<HomeAdmin> createState() => _HomeAdminState();
}

class _HomeAdminState extends State<HomeAdmin> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _accueilKey = GlobalKey<_AccueilPageState>();
  final _utilisateursKey = GlobalKey<_UtilisateursPageState>();
  final _produitsKey = GlobalKey<_ProduitsPageState>();
  final _clientsKey = GlobalKey<_ClientsPageState>();
  final _commandesKey = GlobalKey<_CommandesPageState>();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    syncAdminUnreadNotifications();
  }

  void _go(int i) {
    _scaffoldKey.currentState?.closeDrawer();
    setState(() => _index = i);
    // IndexedStack keeps every tab alive, so none of them reload on their
    // own. Refresh whichever tab we're switching to (e.g. after adding a
    // user, client, product, or order from elsewhere in the app).
    switch (i) {
      case 0:
        _accueilKey.currentState?._refresh();
      case 1:
        _utilisateursKey.currentState?._refresh();
      case 2:
        _produitsKey.currentState?._refresh();
      case 3:
        _clientsKey.currentState?._refresh();
      case 4:
        _commandesKey.currentState?._refresh();
    }
  }

  void _redirect(String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = CurrentUserSession.currentUser;

    if (session == null) {
      _redirect('/login');
      return const Scaffold(backgroundColor: kBg);
    }
    if (session.isCommercial) {
      _redirect('/home-commercial');
      return const Scaffold(backgroundColor: kBg);
    }
    if (session.isManager) {
      _redirect('/home-manager');
      return const Scaffold(backgroundColor: kBg);
    }

    final name = session.fullName;
    final email = session.email;
    final phone = session.phone;

    final pages = [
      AccueilPage(key: _accueilKey, onMenu: _menu, onBell: _bell, name: name),
      UtilisateursPage(key: _utilisateursKey, onMenu: _menu, onBell: _bell),
      ProduitsPage(key: _produitsKey, onMenu: _menu, onBell: _bell),
      ClientsPage(key: _clientsKey, onMenu: _menu, onBell: _bell),
      CommandesPage(key: _commandesKey, onMenu: _menu, onBell: _bell),
      ProfilPage(
        onMenu: _menu,
        onBell: _bell,
        onProfileChanged: () => setState(() {}),
        name: name,
        email: email,
        phone: phone,
      ),
    ];

    // Phone frame wraps the Scaffold itself, so the drawer + sheets stay
    // inside the phone panel on desktop instead of spanning the window.
    return PhoneFrame(
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: kBg,
        drawer: AdminDrawer(
          email: email,
          selectedIndex: _index,
          onSelect: _go,
          onPush: (page) {
            _scaffoldKey.currentState?.closeDrawer();
            Navigator.push(context, phoneRoute(page));
          },
        ),
        body: Column(
          children: [
            Expanded(
              child: IndexedStack(index: _index, children: pages),
            ),
            AdminBottomNav(selectedIndex: _index, onChanged: _go),
          ],
        ),
      ),
    );
  }

  void _menu() => _scaffoldKey.currentState?.openDrawer();
  void _bell() =>
      Navigator.push(context, phoneRoute(const NotificationsPage()));
}

// ---------------------------------------------------------------------------
// Drawer
// ---------------------------------------------------------------------------

class AdminDrawer extends StatelessWidget {
  const AdminDrawer({
    super.key,
    required this.email,
    required this.selectedIndex,
    required this.onSelect,
    required this.onPush,
  });

  final String email;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<Widget> onPush;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 8),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: kGreen.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: kGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Administrateur',
                          style: TextStyle(
                            color: kInk,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: kMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Builder(
                    builder: (context) => IconButton(
                      onPressed: () => Scaffold.of(context).closeDrawer(),
                      icon: const Icon(Icons.close_rounded, color: kMuted),
                    ),
                  ),
                ],
              ),
            ),
            const _DrawerLabel('MENU PRINCIPAL'),
            _DrawerItem(
              Icons.dashboard_rounded,
              'Tableau de bord',
              selectedIndex == 0,
              () => onSelect(0),
            ),
            _DrawerItem(
              Icons.groups_rounded,
              'Utilisateurs',
              selectedIndex == 1,
              () => onSelect(1),
            ),
            _DrawerItem(
              Icons.inventory_2_rounded,
              'Produits',
              selectedIndex == 2,
              () => onSelect(2),
            ),
            _DrawerItem(
              Icons.storefront_rounded,
              'Clients',
              selectedIndex == 3,
              () => onSelect(3),
            ),
            _DrawerItem(
              Icons.receipt_long_rounded,
              'Commandes',
              selectedIndex == 4,
              () => onSelect(4),
            ),
            _DrawerItem(
              Icons.history_rounded,
              'Journal d\'activité',
              false,
              () => onPush(const JournalPage()),
            ),
            _DrawerItem(
              Icons.settings_rounded,
              'Paramètres',
              false,
              () => onPush(const ParametresPage()),
            ),
            const _DrawerLabel('AUTRES'),
            _DrawerItem(
              Icons.notifications_none_rounded,
              'Notifications',
              false,
              () => onPush(const NotificationsPage()),
            ),
            _DrawerItem(Icons.logout_rounded, 'Déconnexion', false, () {
              CurrentUserSession.signOut();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (r) => false,
              );
            }, danger: true),
          ],
        ),
      ),
    );
  }
}

class _DrawerLabel extends StatelessWidget {
  const _DrawerLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: Text(
      text,
      style: const TextStyle(
        color: kMuted,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: .5,
      ),
    ),
  );
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem(
    this.icon,
    this.label,
    this.selected,
    this.onTap, {
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? kRed : (selected ? kGreen : kInk);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: selected ? kGreen.withValues(alpha: .10) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: danger ? kRed : (selected ? kGreen : kMuted),
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 14.5,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
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

// ---------------------------------------------------------------------------
// Bottom nav
// ---------------------------------------------------------------------------

class AdminBottomNav extends StatelessWidget {
  const AdminBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static const _items = [
    (Icons.home_rounded, 'Accueil'),
    (Icons.groups_rounded, 'Utilisateurs'),
    (Icons.inventory_2_rounded, 'Produits'),
    (Icons.storefront_rounded, 'Clients'),
    (Icons.receipt_long_rounded, 'Commandes'),
    (Icons.person_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: kBorder)),
        boxShadow: [
          BoxShadow(
            color: kInk.withValues(alpha: .05),
            blurRadius: 16,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onChanged(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _items[i].$1,
                          size: 23,
                          color: selectedIndex == i ? kGreen : kMuted,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _items[i].$2,
                          style: TextStyle(
                            color: selectedIndex == i ? kGreen : kMuted,
                            fontSize: 10.5,
                            fontWeight: selectedIndex == i
                                ? FontWeight.w900
                                : FontWeight.w700,
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

// ---------------------------------------------------------------------------
// Accueil (dashboard)
// ---------------------------------------------------------------------------

class AccueilPage extends StatefulWidget {
  const AccueilPage({
    super.key,
    required this.onMenu,
    required this.onBell,
    required this.name,
  });
  final VoidCallback onMenu;
  final VoidCallback onBell;
  final String name;

  @override
  State<AccueilPage> createState() => _AccueilPageState();
}

class _AccueilPageState extends State<AccueilPage> {
  late Future<_AdminDashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AdminDashboardData> _load() async {
    final results = await Future.wait<List<dynamic>>([
      ApiService.getUsers(),
      ApiService.getClients(),
      ApiService.getProduits(),
      ApiService.getFactures(),
    ]);
    final orders = results[3].whereType<Map>().map(adminOrderFromJson).toList();
    return _AdminDashboardData(
      users: results[0].whereType<Map>().map(userFromApi).toList(),
      clientsCount: _adminGlobalClientCount(clients: results[1]),
      productsCount: results[2].length,
      orders: orders,
    );
  }

  Future<void> _refresh() async {
    // Block body: an arrow `() => _future = _load()` returns the assigned
    // Future, which setState rejects (and then skips the rebuild).
    setState(() {
      _future = _load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.name.trim().isEmpty
        ? 'Admin'
        : widget.name.trim();
    return Column(
      children: [
        AdminHeader(
          title: '',
          onMenu: widget.onMenu,
          onBell: widget.onBell,
          greeting: 'Bonjour, $displayName',
          subtitle: 'Tableau de bord',
        ),
        Expanded(
          child: FutureBuilder<_AdminDashboardData>(
            future: _future,
            builder: (context, snapshot) {
              final data = snapshot.data ?? _AdminDashboardData.empty();
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  children: [
                    _AdminHeroCard(
                      ca: data.ca,
                      orders: data.orders.length,
                      validated: data.validated,
                    ),
                    const SizedBox(height: 18),
                    const _SectionTitle('Aperçu global'),
                    const SizedBox(height: 12),
                    _kpiRow([
                      _Kpi(
                        'Commerciaux',
                        '${data.commerciaux}',
                        Icons.badge_rounded,
                        kGreen,
                      ),
                      _Kpi(
                        'Managers',
                        '${data.managers}',
                        Icons.shield_rounded,
                        kAccent,
                      ),
                      _Kpi(
                        'Clients',
                        '${data.clientsCount}',
                        Icons.storefront_rounded,
                        kGreen,
                      ),
                      _Kpi(
                        'Produits',
                        '${data.productsCount}',
                        Icons.inventory_2_rounded,
                        kOrange,
                      ),
                    ]),
                    const SizedBox(height: 12),
                    _kpiRow([
                      _Kpi(
                        'Commandes',
                        '${data.orders.length}',
                        Icons.receipt_long_rounded,
                        kAccent,
                      ),
                      _Kpi(
                        'En attente',
                        '${data.pending}',
                        Icons.schedule_rounded,
                        kOrange,
                      ),
                      _Kpi(
                        'Validees',
                        '${data.validated}',
                        Icons.check_circle_rounded,
                        kGreen,
                      ),
                      _Kpi(
                        'Refusees',
                        '${data.refused}',
                        Icons.cancel_rounded,
                        kRed,
                      ),
                    ]),
                    const SizedBox(height: 18),
                    const _SectionTitle('Évolution du chiffre d\'affaires'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      decoration: cardBox(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Chiffre d\'affaires mensuel',
                                  style: TextStyle(
                                    color: kInk,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: kBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: kBorder),
                                ),
                                child: const Text(
                                  '6 mois',
                                  style: TextStyle(
                                    color: kMuted,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 150,
                            child: data.orders.isEmpty
                                ? const _EmptyChart()
                                : _LineChart(
                                    data.revenueByMonth
                                        .map((p) => p.amount)
                                        .toList(),
                                    labels: data.revenueByMonth
                                        .map((p) => p.label)
                                        .toList(),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _kpiRow(List<_Kpi> kpis) => Row(
    children: [
      for (var i = 0; i < kpis.length; i++) ...[
        Expanded(child: _KpiCard(kpi: kpis[i])),
        if (i != kpis.length - 1) const SizedBox(width: 10),
      ],
    ],
  );
}

const List<String> _frMonthsShort = [
  'Jan',
  'Fév',
  'Mar',
  'Avr',
  'Mai',
  'Juin',
  'Juil',
  'Août',
  'Sep',
  'Oct',
  'Nov',
  'Déc',
];

DateTime? _parseAdminDate(String raw) {
  final s = raw.trim();
  if (s.isEmpty || s == '-') return null;
  final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(s);
  if (m != null) {
    return DateTime(
      int.parse(m.group(3)!),
      int.parse(m.group(2)!),
      int.parse(m.group(1)!),
    );
  }
  return DateTime.tryParse(s);
}

/// Buckets order revenue into the last 6 calendar months (oldest -> newest),
/// labelled by short French month name. Undated / out-of-window orders drop
/// off the chart; they still count toward the CA total shown in the hero.
List<({String label, double amount})> adminRevenueByMonth(
  List<AdminOrder> orders, {
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final keys = <String>[];
  final totals = <String, double>{};
  for (var i = 5; i >= 0; i--) {
    final m = DateTime(ref.year, ref.month - i, 1);
    final key = '${m.year}-${m.month}';
    keys.add(key);
    totals[key] = 0;
  }
  for (final order in orders) {
    final d = _parseAdminDate(order.date);
    if (d == null) continue;
    final key = '${d.year}-${d.month}';
    if (totals.containsKey(key)) totals[key] = totals[key]! + order.total;
  }
  return [
    for (final key in keys)
      (
        label: _frMonthsShort[int.parse(key.split('-')[1]) - 1],
        amount: totals[key]!,
      ),
  ];
}

class _AdminDashboardData {
  _AdminDashboardData({
    required this.users,
    required this.clientsCount,
    required this.productsCount,
    required this.orders,
  });

  final List<MockUserProfile> users;
  final int clientsCount;
  final int productsCount;
  final List<AdminOrder> orders;

  factory _AdminDashboardData.empty() => _AdminDashboardData(
    users: const [],
    clientsCount: 0,
    productsCount: 0,
    orders: const [],
  );

  int get commerciaux =>
      users.where((u) => u.role == MockUserRole.commercial).length;
  int get managers => users.where((u) => u.role == MockUserRole.manager).length;
  int get pending => orders.where((o) => o.status == 'pending').length;
  int get validated => orders.where((o) => o.status == 'validated').length;
  int get refused => orders.where((o) => o.status == 'refused').length;
  double get ca => orders.fold<double>(0, (sum, order) => sum + order.total);
  List<({String label, double amount})> get revenueByMonth =>
      adminRevenueByMonth(orders);
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) => const Center(
    child: Text(
      'Aucune donnée disponible',
      style: TextStyle(color: kMuted, fontWeight: FontWeight.w700),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: kInk,
      fontSize: 16,
      fontWeight: FontWeight.w900,
    ),
  );
}

class _Kpi {
  _Kpi(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.kpi});
  final _Kpi kpi;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: cardBox(),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: kpi.color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(kpi.icon, color: kpi.color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            kpi.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            kpi.value,
            style: const TextStyle(
              color: kInk,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            'Total',
            style: TextStyle(
              color: kMuted,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminHeroCard extends StatelessWidget {
  const _AdminHeroCard({
    required this.ca,
    required this.orders,
    required this.validated,
  });
  final double ca;
  final int orders;
  final int validated;

  @override
  Widget build(BuildContext context) {
    final rate = orders == 0 ? 0 : (validated / orders * 100).round();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kHeader, Color(0xFF14532D)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kGreen.withValues(alpha: .28),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Chiffre d\'affaires global',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .85),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Global',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _money(ca),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 5),
                child: Text(
                  'MAD',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .7),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _heroStat('Commandes', '$orders'),
              _heroDivider(),
              _heroStat('Validées', '$validated'),
              _heroDivider(),
              _heroStat('Taux validation', '$rate%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .7),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _heroDivider() => Container(
    width: 1,
    height: 30,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: Colors.white.withValues(alpha: .18),
  );
}

class _LineChart extends StatelessWidget {
  const _LineChart(this.values, {required this.labels});
  final List<num> values;
  final List<String> labels;
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.infinite,
    painter: _LinePainter(values.map((e) => e.toDouble()).toList(), labels),
  );
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.values, this.labels);
  final List<double> values;
  final List<String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final rawMax = values.reduce((a, b) => a > b ? a : b);
    final maxV = rawMax <= 0 ? 1.0 : _niceCeil(rawMax);
    const leftPad = 36.0;
    final chartW = size.width - leftPad;
    final chartH = labels.isEmpty ? size.height : size.height - 18;
    final dx = values.length > 1 ? chartW / (values.length - 1) : 0.0;
    Offset pt(int i) =>
        Offset(leftPad + i * dx, chartH - (values[i] / maxV) * chartH);

    // Horizontal gridlines + Y-axis value labels give the line a real scale.
    void axisLabel(String text, double y) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: kMuted,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final ly = y.clamp(tp.height / 2, chartH) - tp.height / 2;
      tp.paint(canvas, Offset(leftPad - 6 - tp.width, ly));
    }

    final grid = Paint()
      ..color = kMuted.withValues(alpha: .16)
      ..strokeWidth = 1;
    for (final f in const [0.0, 0.5, 1.0]) {
      final y = chartH - f * chartH;
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), grid);
      axisLabel(_compactAmount(maxV * f), y);
    }

    final line = Paint()
      ..color = kGreen
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = kGreen.withValues(alpha: .10);
    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }
    final area = Path.from(path)
      ..lineTo(size.width, chartH)
      ..lineTo(leftPad, chartH)
      ..close();
    canvas.drawPath(area, fill);
    canvas.drawPath(path, line);

    final dot = Paint()..color = kGreen;
    final dotInner = Paint()..color = Colors.white;
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(pt(i), 4, dot);
      canvas.drawCircle(pt(i), 1.8, dotInner);
    }
    for (var i = 0; i < labels.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            color: kMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pt(i).dx - tp.width / 2, size.height - 14));
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.values != values;
}

// ---------------------------------------------------------------------------
// Utilisateurs
// ---------------------------------------------------------------------------

class UtilisateursPage extends StatefulWidget {
  const UtilisateursPage({
    super.key,
    required this.onMenu,
    required this.onBell,
  });
  final VoidCallback onMenu;
  final VoidCallback onBell;
  @override
  State<UtilisateursPage> createState() => _UtilisateursPageState();
}

class _UtilisateursPageState extends State<UtilisateursPage> {
  final _store = AdminUserStore();
  final _search = TextEditingController();
  MockUserRole? _role;
  bool? _active;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await _store.load();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final users = _store.filter(
      query: _search.text,
      role: _role,
      active: _active,
    );
    return Column(
      children: [
        AdminHeader(
          title: 'Utilisateurs',
          onMenu: widget.onMenu,
          onBell: widget.onBell,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            children: [
              AdminSearchRow(
                controller: _search,
                hint: 'Rechercher un utilisateur...',
                onChanged: (_) => setState(() {}),
                filterActive: _active != null,
                onFilter: _filter,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _roleChip('Tous', null),
                    _roleChip('Commerciaux', MockUserRole.commercial),
                    _roleChip('Managers', MockUserRole.manager),
                    _roleChip('Administrateurs', MockUserRole.admin),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GreenButton(label: 'Nouvel utilisateur', onPressed: _create),
              const SizedBox(height: 14),
              if (users.isEmpty) _empty('Aucun utilisateur'),
              for (final u in users) ...[
                _UserCard(
                  user: u,
                  onTap: () => _openDetail(u),
                  onAction: (a) => _action(a, u),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _empty(String t) => Padding(
    padding: const EdgeInsets.only(top: 40),
    child: Center(
      child: Text(
        t,
        style: const TextStyle(color: kMuted, fontWeight: FontWeight.w700),
      ),
    ),
  );

  Widget _roleChip(String label, MockUserRole? role) {
    final selected = _role == role;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _role = role),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? kGreen : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? kGreen : kBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : kInk,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _filter() async {
    final v = await showFilterSheet<bool>(
      context,
      title: 'Filtrer par statut',
      current: _active,
      options: const [('Tous', null), ('Actifs', true), ('Inactifs', false)],
    );
    setState(() => _active = v);
  }

  Future<void> _create() async {
    final result = await Navigator.push<MockUserProfile>(
      context,
      phoneRoute<MockUserProfile>(const UserFormScreen()),
    );
    if (result == null || !mounted) return;
    try {
      await dbInsertUser(result);
      await _store.load();
      if (!mounted) return;
      setState(() {});
      _snack(context, _createdUserMessage(result.role));
    } catch (e) {
      if (!mounted) return;
      _snack(
        context,
        e
            .toString()
            .replaceFirst('Exception: ', '')
            .ifEmpty("Impossible de créer l'utilisateur."),
        success: false,
      );
    }
  }

  Future<void> _openDetail(MockUserProfile u) async {
    final action = await Navigator.push<String>(
      context,
      phoneRoute<String>(UserDetailScreen(user: u)),
    );
    if (action == null || !mounted) return;
    await _action(action, u);
  }

  Future<void> _action(String a, MockUserProfile u) async {
    switch (a) {
      case 'edit':
        final result = await Navigator.push<MockUserProfile>(
          context,
          phoneRoute<MockUserProfile>(UserFormScreen(user: u)),
        );
        if (result == null || !mounted) return;
        try {
          final payload = userToApi(result);
          if (result.password.isEmpty) payload.remove('password');
          await ApiService.updateUser(u.id, payload);
          await _store.load();
          if (!mounted) return;
          final cached = ManagerCommercialsCache.byId(u.id);
          if (cached != null) {
            ManagerCommercialsCache.put(
              cached.copyWith(
                name: result.name,
                email: result.email,
                phone: result.phone,
              ),
            );
          }
          setState(() {});
          _snack(context, 'Utilisateur modifié.');
        } catch (e) {
          if (!mounted) return;
          _snack(
            context,
            e
                .toString()
                .replaceFirst('Exception: ', '')
                .ifEmpty("Impossible de modifier l'utilisateur."),
            success: false,
          );
        }
      case 'reset':
        try {
          await dbSetUserPassword(u.id, _adminTemporaryPassword);
          await _store.load();
          if (!mounted) return;
          setState(() {});
          _snack(context, u.isActive ? 'Compte désactivé.' : 'Compte activé.');
          await _showTemporaryPassword(context, _adminTemporaryPassword);
        } catch (e) {
          if (!mounted) return;
          _snack(
            context,
            e
                .toString()
                .replaceFirst('Exception: ', '')
                .ifEmpty('Impossible de réinitialiser le mot de passe.'),
            success: false,
          );
        }
      case 'toggle':
        try {
          await ApiService.updateUser(u.id, {'is_active': !u.isActive});
          await _store.load();
          if (!mounted) return;
          setState(() {});
        } catch (e) {
          if (!mounted) return;
          _snack(
            context,
            e
                .toString()
                .replaceFirst('Exception: ', '')
                .ifEmpty('Impossible de modifier le statut du compte.'),
            success: false,
          );
        }
      case 'delete':
        final confirmed = await _confirmDestructiveAction(
          context,
          title: "Supprimer l'utilisateur ?",
          message:
              'Cette action supprimera définitivement ${u.name} et ne peut pas être annulée.',
        );
        if (!confirmed || !mounted) return;
        try {
          await dbDeleteUser(u.id);
          if (!mounted) return;
          _store.remove(u.id);
          setState(() {});
          _snack(context, 'Utilisateur supprimé.');
        } catch (e) {
          if (!mounted) return;
          _snack(
            context,
            e
                .toString()
                .replaceFirst('Exception: ', '')
                .ifEmpty("Impossible de supprimer l'utilisateur."),
            success: false,
          );
        }
    }
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onTap,
    required this.onAction,
  });
  final MockUserProfile user;
  final VoidCallback onTap;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        decoration: cardBox(),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: kGreen.withValues(alpha: .14),
              child: Text(
                initials(user.name),
                style: const TextStyle(
                  color: kGreen,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kInk,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    roleLabel(user.role),
                    style: const TextStyle(
                      color: kMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                StatusBadge(
                  label: user.isActive ? 'Actif' : 'Désactivé',
                  color: user.isActive ? kGreen : kRed,
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: kMuted),
                  onSelected: onAction,
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                    const PopupMenuItem(
                      value: 'reset',
                      child: Text('Réinitialiser mot de passe'),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(user.isActive ? 'Désactiver' : 'Activer'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Supprimer', style: TextStyle(color: kRed)),
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
}

class UserDetailScreen extends StatelessWidget {
  const UserDetailScreen({super.key, required this.user});
  final MockUserProfile user;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: kBg,
        body: Column(
          children: [
            AdminHeader(
              title: 'Détail utilisateur',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: cardBox(),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: kGreen.withValues(alpha: .14),
                          child: Text(
                            initials(user.name),
                            style: const TextStyle(
                              color: kGreen,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      user.name,
                                      style: const TextStyle(
                                        color: kInk,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  StatusBadge(
                                    label: user.isActive
                                        ? 'Actif'
                                        : 'Désactivé',
                                    color: user.isActive ? kGreen : kRed,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                roleLabel(user.role),
                                style: const TextStyle(
                                  color: kMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.email,
                                style: const TextStyle(
                                  color: kMuted,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                user.phone.isEmpty
                                    ? 'Non renseigné'
                                    : user.phone,
                                style: const TextStyle(
                                  color: kMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: cardBox(),
                    child: Column(
                      children: [
                        const TabBar(
                          labelColor: kGreen,
                          unselectedLabelColor: kMuted,
                          indicatorColor: kGreen,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                          tabs: [
                            Tab(text: 'Informations'),
                            Tab(text: 'Performances'),
                            Tab(text: 'Activités'),
                            Tab(text: 'Rapports'),
                          ],
                        ),
                        SizedBox(
                          height: 300,
                          child: TabBarView(
                            children: [
                              _infoTab(),
                              const _EmptyTab('Aucune performance disponible'),
                              const _EmptyTab('Aucune activité enregistrée'),
                              const _EmptyTab('Aucun rapport envoyé'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _btn(
                          'Modifier',
                          kGreen,
                          Icons.edit_rounded,
                          () => Navigator.pop(context, 'edit'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _btn(
                          'Réinitialiser',
                          kOrange,
                          Icons.lock_reset_rounded,
                          () => Navigator.pop(context, 'reset'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _btn(
                          user.isActive ? 'Désactiver' : 'Activer',
                          kRed,
                          Icons.block_rounded,
                          () => Navigator.pop(context, 'toggle'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTab() {
    final rows = [
      ('Rôle', roleLabel(user.role)),
      ('Email', user.email),
      ('Téléphone', user.phone.isEmpty ? 'Non renseigné' : user.phone),
      ('Statut', user.isActive ? 'Actif' : 'Désactivé'),
    ];
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    r.$1,
                    style: const TextStyle(
                      color: kMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    r.$2,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: kInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _btn(String label, Color color, IconData icon, VoidCallback onTap) =>
      ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      );
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      text,
      style: const TextStyle(color: kMuted, fontWeight: FontWeight.w700),
    ),
  );
}

class UserFormScreen extends StatefulWidget {
  const UserFormScreen({super.key, this.user});
  final MockUserProfile? user;
  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  late final _nom = TextEditingController();
  late final _prenom = TextEditingController();
  late final _phone = TextEditingController(text: widget.user?.phone ?? '');
  late final _email = TextEditingController(text: widget.user?.email ?? '');
  late final _password = TextEditingController();
  late MockUserRole _role = widget.user?.role ?? MockUserRole.commercial;
  late bool _active = widget.user?.isActive ?? true;
  String? _error;
  String? _emailError;

  static final _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      final (p, n) = splitName(widget.user!.name);
      _prenom.text = p;
      _nom.text = n;
    }
  }

  @override
  void dispose() {
    for (final c in [_nom, _prenom, _phone, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: adminInputTheme,
      child: Scaffold(
        backgroundColor: kBg,
        body: Column(
          children: [
            AdminHeader(
              title: widget.user == null ? 'Nouvel utilisateur' : 'Modifier',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FormSection(
                    'Informations personnelles',
                    Icons.person_rounded,
                    [
                      Row(
                        children: [
                          Expanded(child: _input(_prenom, 'Prénom *')),
                          const SizedBox(width: 10),
                          Expanded(child: _input(_nom, 'Nom *')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _input(_phone, 'Téléphone'),
                      const SizedBox(height: 12),
                      _input(
                        _email,
                        'Email *',
                        keyboardType: TextInputType.emailAddress,
                        errorText: _emailError,
                        onChanged: (_) {
                          if (_emailError != null) {
                            setState(() {
                              _emailError = null;
                              _error = null;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  FormSection('Informations du compte', Icons.lock_rounded, [
                    DropdownButtonFormField<MockUserRole>(
                      initialValue: _role,
                      decoration: const InputDecoration(labelText: 'Rôle *'),
                      items: [
                        for (final r in MockUserRole.values)
                          DropdownMenuItem(value: r, child: Text(roleLabel(r))),
                      ],
                      onChanged: (r) => setState(() => _role = r ?? _role),
                    ),
                    Material(
                      type: MaterialType.transparency,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Compte actif'),
                        value: _active,
                        activeThumbColor: kGreen,
                        onChanged: (v) => setState(() => _active = v),
                      ),
                    ),
                    _input(
                      _password,
                      widget.user == null
                          ? 'Mot de passe temporaire *'
                          : 'Nouveau mot de passe (optionnel)',
                    ),
                  ]),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: kRed,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  FormButtons(
                    submitLabel: widget.user == null ? 'Créer' : 'Enregistrer',
                    onSubmit: _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController c,
    String label, {
    TextInputType? keyboardType,
    String? errorText,
    ValueChanged<String>? onChanged,
  }) => TextField(
    controller: c,
    keyboardType: keyboardType,
    onChanged: onChanged,
    decoration: InputDecoration(labelText: label, errorText: errorText),
  );

  void _submit() {
    final name = '${_prenom.text.trim()} ${_nom.text.trim()}'.trim();
    final email = _email.text.trim();
    final password = _password.text.trim();
    if (name.isEmpty || email.isEmpty) {
      setState(() {
        _error = 'Nom, prénom et email sont obligatoires.';
        _emailError = email.isEmpty ? 'Email invalide' : null;
      });
      return;
    }
    if (!_emailRegex.hasMatch(email)) {
      setState(() {
        _error = null;
        _emailError = 'Email invalide';
      });
      return;
    }
    if (widget.user == null && password.isEmpty) {
      setState(() => _error = 'Le mot de passe est obligatoire.');
      return;
    }
    if (password.isNotEmpty && password.length < 8) {
      setState(
        () => _error = 'Le mot de passe doit contenir au moins 8 caractères.',
      );
      return;
    }
    Navigator.pop(
      context,
      MockUserProfile(
        id: widget.user?.id ?? 0,
        name: name,
        email: email,
        phone: _phone.text.trim(),
        password: password,
        role: _role,
        isActive: _active,
      ),
    );
  }
}

// Shared form chrome
class FormSection extends StatelessWidget {
  const FormSection(this.title, this.icon, this.children, {super.key});
  final String title;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: cardBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: kGreen, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: kInk,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class FormButtons extends StatelessWidget {
  const FormButtons({
    super.key,
    required this.submitLabel,
    required this.onSubmit,
  });
  final String submitLabel;
  final VoidCallback onSubmit;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: kBorder),
            ),
            child: const Text(
              'Annuler',
              style: TextStyle(color: kInk, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: kGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              submitLabel,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Produits
// ---------------------------------------------------------------------------

class ProduitsPage extends StatefulWidget {
  const ProduitsPage({super.key, required this.onMenu, required this.onBell});
  final VoidCallback onMenu;
  final VoidCallback onBell;
  @override
  State<ProduitsPage> createState() => _ProduitsPageState();
}

class _ProduitsPageState extends State<ProduitsPage> {
  final _store = ProductStore();
  final _search = TextEditingController();
  String? _category;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await _store.load();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = _store.all;
    final products = _store.filter(query: _search.text, category: _category);
    final inStock = all.where((p) => p.stock > 60).length;
    final low = all.where((p) => p.stock > 0 && p.stock <= 60).length;
    final out = all.where((p) => p.stock == 0).length;

    return Column(
      children: [
        AdminHeader(
          title: 'Produits',
          onMenu: widget.onMenu,
          onBell: widget.onBell,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            children: [
              AdminSearchRow(
                controller: _search,
                hint: 'Rechercher un produit...',
                onChanged: (_) => setState(() {}),
                filterActive: _category != null,
                onFilter: _filter,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Total produits',
                      value: '${all.length}',
                      color: kGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      label: 'En stock',
                      value: '$inStock',
                      color: kGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      label: 'Stock faible',
                      value: '$low',
                      color: kOrange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      label: 'Rupture',
                      value: '$out',
                      color: kRed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GreenButton(label: 'Nouveau produit', onPressed: _create),
              const SizedBox(height: 14),
              if (products.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(
                      'Aucune donnée disponible',
                      style: TextStyle(
                        color: kMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              for (final p in products) ...[
                InkWell(
                  onTap: () => _edit(p),
                  borderRadius: BorderRadius.circular(16),
                  child: _productCard(p),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _filter() async {
    final v = await showFilterSheet<String>(
      context,
      title: 'Filtrer par catégorie',
      current: _category,
      options: [('Toutes', null), for (final c in _store.categories) (c, c)],
    );
    setState(() => _category = v);
  }

  Future<void> _create() async {
    final p = await Navigator.push<OrderProduct>(
      context,
      phoneRoute<OrderProduct>(ProductFormScreen(store: _store)),
    );
    if (p == null || !mounted) return;
    try {
      await _store.add(p);
      await _store.load();
      if (!mounted) return;
      setState(() {});
      _snack(context, 'Produit créé avec succès.');
    } catch (e) {
      if (!mounted) return;
      _snack(
        context,
        e
            .toString()
            .replaceFirst('Exception: ', '')
            .ifEmpty('Impossible de créer le produit.'),
        success: false,
      );
    }
  }

  Future<void> _edit(OrderProduct product) async {
    final result = await Navigator.push<ProductFormResult>(
      context,
      phoneRoute<ProductFormResult>(
        ProductFormScreen(store: _store, product: product),
      ),
    );
    if (result == null || !mounted) return;
    if (result.deleted) {
      final confirmed = await _confirmDestructiveAction(
        context,
        title: 'Supprimer le produit ?',
        message:
            'Cette action supprimera définitivement ${product.name} et ne peut pas être annulée.',
      );
      if (!confirmed || !mounted) return;
    }
    try {
      if (result.deleted) {
        await _store.remove(product.id);
      } else if (result.product != null) {
        await _store.update(result.product!);
      }
      await _store.load();
      if (!mounted) return;
      setState(() {});
      if (result.deleted) _snack(context, 'Produit supprimé.');
    } catch (e) {
      if (!mounted) return;
      _snack(
        context,
        e
            .toString()
            .replaceFirst('Exception: ', '')
            .ifEmpty(
              result.deleted
                  ? 'Impossible de supprimer le produit.'
                  : 'Impossible de modifier le produit.',
            ),
        success: false,
      );
    }
  }

  Widget _productCard(OrderProduct p) {
    final low = p.stock <= 60;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: cardBox(),
      child: Row(
        children: [
          _AdminProductImage(product: p),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kInk,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  p.reference,
                  style: const TextStyle(
                    color: kMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${p.unitPrice.toStringAsFixed(2)} MAD',
                style: const TextStyle(
                  color: kInk,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.circle, size: 8, color: low ? kOrange : kGreen),
                  const SizedBox(width: 4),
                  Text(
                    'Stock: ${p.stock}',
                    style: const TextStyle(
                      color: kMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProductFormResult {
  ProductFormResult({this.product, this.deleted = false});
  final OrderProduct? product;
  final bool deleted;
}

class _AdminProductImage extends StatelessWidget {
  const _AdminProductImage({required this.product});

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

class _ProductImagePickerDialog extends StatelessWidget {
  const _ProductImagePickerDialog({required this.current});

  final String current;

  @override
  Widget build(BuildContext context) {
    final resolvedCurrent = current.isEmpty
        ? ''
        : resolveProductImageAsset(image: current);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Choisir une image',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (current.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context, ''),
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      label: const Text('Aucune'),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: .72,
                ),
                itemCount: productImageAssetPaths.length,
                itemBuilder: (context, index) {
                  final path = productImageAssetPaths[index];
                  final selected = path == resolvedCurrent;
                  return InkWell(
                    onTap: () => Navigator.pop(context, path),
                    borderRadius: BorderRadius.circular(10),
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? kGreen
                                    : const Color(0xFFE2E8F0),
                                width: selected ? 2 : 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(
                              path,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Center(
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Colors.black38,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          productImageLabel(path),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10, height: 1.1),
                        ),
                      ],
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

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, required this.store, this.product});
  final ProductStore store;
  final OrderProduct? product;
  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _ref = TextEditingController(
    text: widget.product?.reference ?? '',
  );
  late final _category = TextEditingController(
    text: widget.product?.category ?? '',
  );
  late final _description = TextEditingController(
    text: widget.product?.description ?? '',
  );
  late final _image = TextEditingController(text: widget.product?.image ?? '');
  late final _price = TextEditingController(
    text: widget.product?.unitPrice.toStringAsFixed(2) ?? '',
  );
  late final _stock = TextEditingController(
    text: widget.product?.stock.toString() ?? '',
  );
  String? _error;
  List<String> _categoryOptions = _teaProductCategories;
  // Bumped once the real category list loads, so the dropdown gets a new
  // key below — DropdownButtonFormField only reads initialValue when its
  // field state is first created, so a plain setState alone wouldn't move
  // the visible selection once the async-loaded list replaces the fallback.
  bool _categoriesLoaded = false;

  @override
  void initState() {
    super.initState();
    if (!_categoryOptions.contains(_category.text.trim())) {
      _category.text = _categoryOptions.first;
    }
    _loadCategoryOptions('product', _teaProductCategories).then((options) {
      if (!mounted) return;
      final current = widget.product?.category.trim() ?? '';
      setState(() {
        _categoryOptions = current.isNotEmpty && !options.contains(current)
            ? [current, ...options]
            : options;
        _categoriesLoaded = true;
        if (!_categoryOptions.contains(_category.text.trim())) {
          _category.text = _categoryOptions.first;
        }
      });
    });
  }

  Future<void> _pickProductImage() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (_) => _ProductImagePickerDialog(current: _image.text.trim()),
    );
    if (selected == null) return; // dismissed without choosing
    setState(() => _image.text = selected); // '' clears the image
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _ref,
      _category,
      _description,
      _image,
      _price,
      _stock,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.product != null;
    return Theme(
      data: adminInputTheme,
      child: Scaffold(
        backgroundColor: kBg,
        body: Column(
          children: [
            AdminHeader(
              title: editing ? 'Modifier le produit' : 'Nouveau produit',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FormSection(
                    'Informations générales',
                    Icons.inventory_2_rounded,
                    [
                      TextField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Nom du produit *',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ref,
                        decoration: const InputDecoration(
                          labelText: 'Référence *',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey(_categoriesLoaded),
                        initialValue:
                            _categoryOptions.contains(_category.text.trim())
                            ? _category.text.trim()
                            : _categoryOptions.first,
                        decoration: const InputDecoration(
                          labelText: 'Catégorie *',
                        ),
                        items: [
                          for (final category in _categoryOptions)
                            DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _category.text = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _description,
                        minLines: 2,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _pickProductImage,
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Image produit',
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40,
                                height: 40,
                                child: _image.text.trim().isEmpty
                                    ? const Icon(
                                        Icons.image_outlined,
                                        color: Colors.black38,
                                      )
                                    : ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.asset(
                                          resolveProductImageAsset(
                                            image: _image.text.trim(),
                                          ),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => const Icon(
                                            Icons.broken_image_outlined,
                                            color: Colors.black38,
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _image.text.trim().isEmpty
                                      ? 'Choisir une image'
                                      : productImageLabel(_image.text.trim()),
                                  style: TextStyle(
                                    color: _image.text.trim().isEmpty
                                        ? Colors.black45
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.photo_library_rounded,
                                color: kGreen,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  FormSection('Tarification & stock', Icons.payments_rounded, [
                    TextField(
                      controller: _price,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Prix de vente (MAD) *',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _stock,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Stock disponible *',
                      ),
                    ),
                  ]),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: kRed,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  FormButtons(
                    submitLabel: editing ? 'Enregistrer' : 'Ajouter',
                    onSubmit: _submit,
                  ),
                  if (editing)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextButton.icon(
                        onPressed: () => Navigator.pop(
                          context,
                          ProductFormResult(deleted: true),
                        ),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: kRed,
                        ),
                        label: const Text(
                          'Supprimer le produit',
                          style: TextStyle(
                            color: kRed,
                            fontWeight: FontWeight.w800,
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

  void _submit() {
    final name = _name.text.trim();
    final price = double.tryParse(_price.text.trim().replaceAll(',', '.'));
    final stock = int.tryParse(_stock.text.trim());
    if (name.isEmpty ||
        _ref.text.trim().isEmpty ||
        price == null ||
        stock == null) {
      setState(
        () => _error =
            'Nom, référence, prix et stock numériques sont obligatoires.',
      );
      return;
    }
    if (price <= 0) {
      setState(() => _error = 'Le prix doit être strictement positif.');
      return;
    }
    if (stock < 0) {
      setState(() => _error = 'Le stock ne peut pas être négatif.');
      return;
    }
    final built = widget.store.build(
      id: widget.product?.id,
      name: name,
      reference: _ref.text.trim(),
      category: _category.text.trim(),
      description: _description.text.trim(),
      image: _image.text.trim(),
      price: price,
      stock: stock,
    );
    Navigator.pop(
      context,
      widget.product == null ? built : ProductFormResult(product: built),
    );
  }
}

// ---------------------------------------------------------------------------
// Clients
// ---------------------------------------------------------------------------

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key, required this.onMenu, required this.onBell});
  final VoidCallback onMenu;
  final VoidCallback onBell;
  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  final _store = ClientStore();
  final _search = TextEditingController();
  ClientStatus? _status;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await _store.load();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clients = _store.filter(query: _search.text, status: _status);
    return Column(
      children: [
        AdminHeader(
          title: 'Clients',
          onMenu: widget.onMenu,
          onBell: widget.onBell,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            children: [
              AdminSearchRow(
                controller: _search,
                hint: 'Rechercher un client...',
                onChanged: (_) => setState(() {}),
                filterActive: _status != null,
                onFilter: _filter,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Total clients',
                      value: '${_store.all.length}',
                      color: kGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      label: 'Actifs',
                      value: '${_store.count(ClientStatus.visited)}',
                      color: kGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      label: 'Inactifs',
                      value: '${_store.count(ClientStatus.inactive)}',
                      color: kRed,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      label: 'Prospects',
                      value: '${_store.count(ClientStatus.toVisit)}',
                      color: kOrange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GreenButton(label: 'Nouveau client', onPressed: _create),
              const SizedBox(height: 14),
              if (clients.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(
                      'Aucune donnée disponible',
                      style: TextStyle(
                        color: kMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              for (final c in clients) ...[
                InkWell(
                  onTap: () => _edit(c),
                  borderRadius: BorderRadius.circular(16),
                  child: _clientCard(c),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _filter() async {
    final v = await showFilterSheet<ClientStatus>(
      context,
      title: 'Filtrer par statut',
      current: _status,
      options: const [
        ('Tous', null),
        ('Actifs', ClientStatus.visited),
        ('Inactifs', ClientStatus.inactive),
        ('Prospects', ClientStatus.toVisit),
      ],
    );
    setState(() => _status = v);
  }

  Future<void> _create() async {
    final c = await Navigator.push<CommercialClient>(
      context,
      phoneRoute<CommercialClient>(ClientFormScreen(store: _store)),
    );
    if (c == null || !mounted) return;
    try {
      await _store.add(c);
      await _store.load();
      if (!mounted) return;
      setState(() {});
      _snack(context, 'Client créé avec succès.');
    } catch (e) {
      if (!mounted) return;
      _snack(
        context,
        e
            .toString()
            .replaceFirst('Exception: ', '')
            .ifEmpty('Impossible de créer le client.'),
        success: false,
      );
    }
  }

  Future<void> _edit(CommercialClient client) async {
    final result = await Navigator.push<ClientFormResult>(
      context,
      phoneRoute<ClientFormResult>(
        ClientFormScreen(store: _store, client: client),
      ),
    );
    if (result == null || !mounted) return;
    if (result.deleted) {
      final confirmed = await _confirmDestructiveAction(
        context,
        title: 'Supprimer le client ?',
        message:
            'Cette action supprimera définitivement ${client.name} et ne peut pas être annulée.',
      );
      if (!confirmed || !mounted) return;
    }
    try {
      if (result.deleted) {
        await _store.remove(client.id);
      } else if (result.client != null) {
        await _store.update(result.client!);
      }
      await _store.load();
      if (!mounted) return;
      setState(() {});
      if (result.deleted) _snack(context, 'Client supprimé.');
    } catch (e) {
      if (!mounted) return;
      _snack(
        context,
        e
            .toString()
            .replaceFirst('Exception: ', '')
            .ifEmpty(
              result.deleted
                  ? 'Impossible de supprimer le client.'
                  : 'Impossible de modifier le client.',
            ),
        success: false,
      );
    }
  }

  Widget _clientCard(CommercialClient c) {
    final (label, color) = clientStatusStyle(c.status);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: cardBox(),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: kGreen.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: kGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kInk,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  c.city,
                  style: const TextStyle(
                    color: kMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(label: label, color: color),
        ],
      ),
    );
  }
}

class ClientFormResult {
  ClientFormResult({this.client, this.deleted = false});
  final CommercialClient? client;
  final bool deleted;
}

class ClientFormScreen extends StatefulWidget {
  const ClientFormScreen({super.key, required this.store, this.client});
  final ClientStore store;
  final CommercialClient? client;
  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  late final _name = TextEditingController(text: widget.client?.name ?? '');
  late final _city = TextEditingController(text: widget.client?.city ?? '');
  late final _address = TextEditingController(
    text: widget.client?.address ?? '',
  );
  late final _phone = TextEditingController(text: widget.client?.phone ?? '');
  late final _email = TextEditingController(text: widget.client?.email ?? '');
  late final _contactName = TextEditingController(
    text: widget.client?.contactName ?? '',
  );
  late final _quartier = TextEditingController(
    text: widget.client?.quartier ?? '',
  );
  late final _latitude = TextEditingController(
    text: widget.client == null ? '' : widget.client!.latitude.toString(),
  );
  late final _longitude = TextEditingController(
    text: widget.client == null ? '' : widget.client!.longitude.toString(),
  );
  late final _notes = TextEditingController(text: widget.client?.notes ?? '');
  late String _businessType = _resolveBusinessType();
  late final _businessTypeOther = TextEditingController(
    text: _businessType == 'Autre' ? (widget.client?.businessType ?? '') : '',
  );
  late ClientStatus _status = widget.client?.status ?? ClientStatus.toVisit;
  int? _commercialId;
  List<MockUserProfile> _commercials = [];
  String? _error;
  String? _emailError;
  List<String> _businessTypeOptions = _commerceTypes;
  // Bumped once the real category list loads — see the matching comment on
  // _ProductFormScreenState._categoriesLoaded for why the dropdown needs a
  // new key rather than just a setState to pick up the change.
  bool _businessTypesLoaded = false;

  static const _commerceTypes = [
    'Épicerie',
    'Supermarché',
    'Grossiste',
    'Café',
    'Restaurant',
    'Autre',
  ];

  static final _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  String _resolveBusinessType() {
    final existing = widget.client?.businessType;
    if (existing == null || existing.isEmpty) {
      return _businessTypeOptions.first;
    }
    if (_businessTypeOptions.contains(existing)) return existing;
    return 'Autre';
  }

  @override
  void initState() {
    super.initState();
    _commercialId = widget.client?.commercialId == 0
        ? null
        : widget.client?.commercialId;
    _loadCommercials();
    _loadCategoryOptions('client', _commerceTypes).then((options) {
      if (!mounted) return;
      setState(() {
        _businessTypeOptions = [
          for (final option in options)
            if (option != 'Autre') option,
          'Autre',
        ];
        _businessTypesLoaded = true;
        if (_businessType != 'Autre' &&
            !_businessTypeOptions.contains(_businessType)) {
          _businessType = _businessTypeOptions.first;
        }
      });
    });
  }

  Future<void> _loadCommercials() async {
    try {
      final rows = await ApiService.getUsers();
      final commercials = rows
          .whereType<Map>()
          .map(userFromApi)
          .where(
            (user) => user.role == MockUserRole.commercial && user.isActive,
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _commercials = commercials;
        _commercialId ??= commercials.isEmpty ? null : commercials.first.id;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Impossible de charger les commerciaux actifs.');
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _city,
      _address,
      _phone,
      _email,
      _contactName,
      _quartier,
      _latitude,
      _longitude,
      _notes,
      _businessTypeOther,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.client != null;
    return Theme(
      data: adminInputTheme,
      child: Scaffold(
        backgroundColor: kBg,
        body: Column(
          children: [
            AdminHeader(
              title: editing ? 'Modifier le client' : 'Nouveau client',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FormSection(
                    'Informations générales',
                    Icons.storefront_rounded,
                    [
                      TextField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Nom / Raison sociale *',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _city,
                        decoration: const InputDecoration(labelText: 'Ville *'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey(_businessTypesLoaded),
                        initialValue: _businessType,
                        decoration: const InputDecoration(
                          labelText: 'Type de commerce *',
                        ),
                        items: [
                          for (final type in _businessTypeOptions)
                            DropdownMenuItem(value: type, child: Text(type)),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _businessType = value);
                        },
                      ),
                      if (_businessType == 'Autre') ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _businessTypeOther,
                          autofocus: true,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Précisez le type de commerce *',
                          ),
                          onSubmitted: (_) =>
                              FocusScope.of(context).unfocus(),
                        ),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ClientStatus>(
                        initialValue: _status,
                        decoration: const InputDecoration(
                          labelText: 'Catégorie du client *',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: ClientStatus.toVisit,
                            child: Text('Prospect'),
                          ),
                          DropdownMenuItem(
                            value: ClientStatus.visited,
                            child: Text('Actif'),
                          ),
                          DropdownMenuItem(
                            value: ClientStatus.inactive,
                            child: Text('Inactif'),
                          ),
                        ],
                        onChanged: (s) =>
                            setState(() => _status = s ?? _status),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _commercialId,
                        decoration: const InputDecoration(
                          labelText: 'Commercial affecté *',
                        ),
                        items: [
                          for (final commercial in _commercials)
                            DropdownMenuItem(
                              value: commercial.id,
                              child: Text(commercial.name),
                            ),
                        ],
                        onChanged: (value) {
                          setState(() => _commercialId = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _address,
                        decoration: const InputDecoration(
                          labelText: 'Adresse *',
                        ),
                      ),
                    ],
                  ),
                  FormSection('Contact', Icons.contact_phone_rounded, [
                    TextField(
                      controller: _phone,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone *',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _contactName,
                      decoration: const InputDecoration(
                        labelText: 'Nom du responsable',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) {
                        if (_emailError != null) {
                          setState(() => _emailError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Email',
                        errorText: _emailError,
                      ),
                    ),
                  ]),
                  FormSection('Détails facultatifs', Icons.place_rounded, [
                    TextField(
                      controller: _quartier,
                      decoration: const InputDecoration(labelText: 'Quartier'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _latitude,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Latitude',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _longitude,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Longitude',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notes,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Notes / Commentaires',
                      ),
                    ),
                  ]),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: kRed,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  FormButtons(
                    submitLabel: editing ? 'Enregistrer' : 'Ajouter',
                    onSubmit: _submit,
                  ),
                  if (editing)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextButton.icon(
                        onPressed: () => Navigator.pop(
                          context,
                          ClientFormResult(deleted: true),
                        ),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: kRed,
                        ),
                        label: const Text(
                          'Supprimer le client',
                          style: TextStyle(
                            color: kRed,
                            fontWeight: FontWeight.w800,
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

  void _submit() {
    final name = _name.text.trim();
    final city = _city.text.trim();
    final phone = _phone.text.trim();
    final address = _address.text.trim();
    final email = _email.text.trim();
    final businessType = _businessType == 'Autre'
        ? _businessTypeOther.text.trim()
        : _businessType;
    if (name.isEmpty ||
        phone.isEmpty ||
        address.isEmpty ||
        city.isEmpty ||
        businessType.isEmpty ||
        _commercialId == null) {
      setState(() {
        _error = 'Tous les champs obligatoires doivent être renseignés.';
      });
      return;
    }
    if (email.isNotEmpty && !_emailRegex.hasMatch(email)) {
      setState(() {
        _error = null;
        _emailError = 'Email invalide';
      });
      return;
    }
    final built = widget.store.build(
      id: widget.client?.id,
      name: name,
      city: city,
      category: businessType,
      status: _status,
      commercialId: _commercialId ?? 0,
      businessType: businessType,
      address: address,
      phone: phone,
      email: email,
      contactName: _contactName.text.trim(),
      quartier: _quartier.text.trim(),
      notes: _notes.text.trim(),
      latitude:
          double.tryParse(_latitude.text.trim().replaceAll(',', '.')) ??
          33.5731,
      longitude:
          double.tryParse(_longitude.text.trim().replaceAll(',', '.')) ??
          -7.5898,
    );
    Navigator.pop(
      context,
      widget.client == null ? built : ClientFormResult(client: built),
    );
  }
}

// ---------------------------------------------------------------------------
// Commandes
// ---------------------------------------------------------------------------

class CommandesPage extends StatefulWidget {
  const CommandesPage({super.key, required this.onMenu, required this.onBell});
  final VoidCallback onMenu;
  final VoidCallback onBell;
  @override
  State<CommandesPage> createState() => _CommandesPageState();
}

class _CommandesPageState extends State<CommandesPage> {
  final _search = TextEditingController();
  String? _status;
  late Future<List<AdminOrder>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AdminOrder>> _load() async {
    final rows = await ApiService.getFactures();
    return rows.whereType<Map>().map(adminOrderFromJson).toList();
  }

  Future<void> _refresh() async {
    // Block body: an arrow `() => _future = _load()` returns the assigned
    // Future, which setState rejects (and then skips the rebuild).
    setState(() {
      _future = _load();
    });
    await _future;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AdminHeader(
          title: 'Commandes',
          onMenu: widget.onMenu,
          onBell: widget.onBell,
        ),
        Expanded(
          child: FutureBuilder<List<AdminOrder>>(
            future: _future,
            builder: (context, snapshot) {
              final all = snapshot.data ?? const <AdminOrder>[];
              final q = _search.text.trim().toLowerCase();
              final orders = all.where((o) {
                if (_status != null && o.status != _status) return false;
                return q.isEmpty ||
                    o.number.toLowerCase().contains(q) ||
                    o.client.toLowerCase().contains(q);
              }).toList();
              final pending = all.where((o) => o.status == 'pending').length;
              final validated = all
                  .where((o) => o.status == 'validated')
                  .length;
              final refused = all.where((o) => o.status == 'refused').length;
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  children: [
                    AdminSearchRow(
                      controller: _search,
                      hint: 'Rechercher une commande...',
                      onChanged: (_) => setState(() {}),
                      filterActive: _status != null,
                      onFilter: _filter,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            label: 'Total',
                            value: '${all.length}',
                            color: kInk,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatTile(
                            label: 'En attente',
                            value: '$pending',
                            color: kOrange,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatTile(
                            label: 'Validees',
                            value: '$validated',
                            color: kGreen,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatTile(
                            label: 'Refusees',
                            value: '$refused',
                            color: kRed,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (orders.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text(
                            'Aucune commande',
                            style: TextStyle(
                              color: kMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    for (final o in orders) ...[
                      _orderCard(context, o),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _filter() async {
    final v = await showFilterSheet<String>(
      context,
      title: 'Filtrer par statut',
      current: _status,
      options: const [
        ('Toutes', null),
        ('En attente', 'pending'),
        ('Validées', 'validated'),
        ('Refusées', 'refused'),
      ],
    );
    setState(() => _status = v);
  }

  Widget _orderCard(BuildContext context, AdminOrder o) {
    final (label, color) = orderStatusStyle(o.status);
    return InkWell(
      onTap: () =>
          Navigator.push(context, phoneRoute(CommandeDetailScreen(order: o))),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: cardBox(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    o.number,
                    style: const TextStyle(
                      color: kInk,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  o.date,
                  style: const TextStyle(
                    color: kMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              o.client,
              style: const TextStyle(
                color: kMuted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '${_money(o.total)} MAD',
                  style: const TextStyle(
                    color: kInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                StatusBadge(label: label, color: color),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CommandeDetailScreen extends StatelessWidget {
  const CommandeDetailScreen({super.key, required this.order});
  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    final (label, color) = orderStatusStyle(order.status);
    return Scaffold(
      backgroundColor: kBg,
      body: Column(
        children: [
          AdminHeader(
            title: 'Détail commande',
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: cardBox(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              order.number,
                              style: const TextStyle(
                                color: kInk,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          StatusBadge(label: label, color: color),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _kv('Date', order.date),
                      _kv('Commercial', order.commercial),
                      _kv('Client', order.client),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: cardBox(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Produits',
                        style: TextStyle(
                          color: kInk,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Text(
                              'Produit',
                              style: TextStyle(
                                color: kMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Qté',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: kMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Total',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: kMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 18, color: kBorder),
                      for (final it in order.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  it.name,
                                  style: const TextStyle(
                                    color: kInk,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '${it.qty}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: kInk,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  _money(it.total),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: kInk,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Divider(height: 20, color: kBorder),
                      _kv('Sous-total', '${_money(order.subtotal)} MAD'),
                      if (order.discount > 0)
                        _kv('Remise', '-${_money(order.discount)} MAD'),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              color: kInk,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_money(order.total)} MAD',
                            style: const TextStyle(
                              color: kGreen,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: cardBox(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Historique',
                        style: TextStyle(
                          color: kInk,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Icon(Icons.circle, size: 10, color: kGreen),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${order.date} 10:30',
                                  style: const TextStyle(
                                    color: kMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Commande créée par ${order.commercial}',
                                  style: const TextStyle(
                                    color: kInk,
                                    fontSize: 13,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            k,
            style: const TextStyle(color: kMuted, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(color: kInk, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Profil
// ---------------------------------------------------------------------------

class ProfilPage extends StatelessWidget {
  const ProfilPage({
    super.key,
    required this.onMenu,
    required this.onBell,
    required this.onProfileChanged,
    required this.name,
    required this.email,
    required this.phone,
  });
  final VoidCallback onMenu;
  final VoidCallback onBell;
  final VoidCallback onProfileChanged;
  final String name;
  final String email;
  final String phone;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        AppLocaleController.instance,
        AppAppearanceController.instance,
      ]),
      builder: (context, _) {
        return Column(
          children: [
            AdminHeader(title: 'Profil', onMenu: onMenu, onBell: onBell),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: cardBox(),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: kGreen.withValues(alpha: .14),
                          child: Text(
                            initials(name),
                            style: const TextStyle(
                              color: kGreen,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: kInk,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: kMuted,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: const [
                                  Icon(Icons.circle, size: 9, color: kGreen),
                                  SizedBox(width: 5),
                                  Text(
                                    'En ligne',
                                    style: TextStyle(
                                      color: kGreen,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: cardBox(),
                    child: Column(
                      children: [
                        _row(
                          context,
                          Icons.person_outline_rounded,
                          'Informations personnelles',
                          onTap: () => Navigator.push(
                            context,
                            phoneRoute(
                              PersonalInfoScreen(
                                name: name,
                                email: email,
                                phone: phone,
                              ),
                            ),
                          ),
                        ),
                        _row(
                          context,
                          Icons.edit_outlined,
                          'Modifier profil',
                          onTap: () async {
                            final changed = await Navigator.push<bool>(
                              context,
                              phoneRoute(
                                EditProfileScreen(name: name, phone: phone),
                              ),
                            );
                            if (changed == true) onProfileChanged();
                          },
                        ),
                        _row(
                          context,
                          Icons.lock_outline_rounded,
                          'Changer le mot de passe',
                          onTap: () => _changePassword(context),
                        ),
                        _row(
                          context,
                          Icons.notifications_none_rounded,
                          'Notifications',
                          onTap: () => Navigator.push(
                            context,
                            phoneRoute(const NotificationsSettingsScreen()),
                          ),
                        ),
                        _row(
                          context,
                          Icons.language_rounded,
                          'Langue',
                          trailing: _langName(),
                          onTap: () => Navigator.push(
                            context,
                            phoneRoute(const LanguageScreen()),
                          ),
                        ),
                        _row(
                          context,
                          Icons.dark_mode_outlined,
                          'Thème',
                          trailing: _themeName(),
                          onTap: () => Navigator.push(
                            context,
                            phoneRoute(const ThemeScreen()),
                          ),
                        ),
                        _row(
                          context,
                          Icons.info_outline_rounded,
                          'À propos de l\'application',
                          trailing: 'Version 1.0.0',
                          onTap: () => Navigator.push(
                            context,
                            phoneRoute(const AboutScreen()),
                          ),
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: cardBox(),
                    child: _row(
                      context,
                      Icons.logout_rounded,
                      'Se déconnecter',
                      color: kRed,
                      isLast: true,
                      onTap: () {
                        CurrentUserSession.signOut();
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/login',
                          (r) => false,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _langName() => switch (AppLocaleController.instance.languageCode) {
    'ar' => 'العربية',
    _ => 'Français',
  };

  String _themeName() => switch (AppAppearanceController.instance.theme) {
    AppThemePreference.dark => 'Sombre',
    AppThemePreference.system => 'Automatique',
    _ => 'Clair',
  };

  Future<void> _changePassword(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 430),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) =>
          Theme(data: adminInputTheme, child: const ChangePasswordSheet()),
    );
  }

  Widget _row(
    BuildContext context,
    IconData icon,
    String label, {
    String? trailing,
    Color color = kInk,
    bool isLast = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          border: Border(
            bottom: isLast ? BorderSide.none : const BorderSide(color: kBorder),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color == kRed ? kRed : kInk, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                style: const TextStyle(
                  color: kMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (color != kRed)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.chevron_right_rounded, color: kMuted),
              ),
          ],
        ),
      ),
    );
  }
}

class PersonalInfoScreen extends StatelessWidget {
  const PersonalInfoScreen({
    super.key,
    required this.name,
    required this.email,
    required this.phone,
  });
  final String name;
  final String email;
  final String phone;
  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Nom complet', name),
      ('Email', email),
      ('Téléphone', phone.isEmpty ? 'Non renseigné' : phone),
      ('Rôle', 'Administrateur'),
      ('Société', 'Ryme Distribution'),
    ];
    return Scaffold(
      backgroundColor: kBg,
      body: Column(
        children: [
          AdminHeader(
            title: 'Informations personnelles',
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: cardBox(),
                  child: Column(
                    children: [
                      for (final r in rows)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.$1,
                                  style: const TextStyle(
                                    color: kMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  r.$2,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: kInk,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
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

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.name, required this.phone});
  final String name;
  final String phone;
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final _name = TextEditingController(text: widget.name);
  late final _phone = TextEditingController(text: widget.phone);
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: adminInputTheme,
      child: Scaffold(
        backgroundColor: kBg,
        body: Column(
          children: [
            AdminHeader(
              title: 'Modifier profil',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FormSection('Profil', Icons.person_rounded, [
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Nom complet',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phone,
                      decoration: const InputDecoration(labelText: 'Téléphone'),
                    ),
                  ]),
                  FormButtons(
                    submitLabel: _saving ? 'Enregistrement...' : 'Enregistrer',
                    onSubmit: _saving ? () {} : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    if (name.isEmpty) {
      _snack(context, 'Le nom complet est obligatoire.', success: false);
      return;
    }

    final session = CurrentUserSession.currentUser;
    if (session == null || session.id <= 0) {
      _snack(
        context,
        'Impossible d\u2019identifier le compte à mettre à jour.',
        success: false,
      );
      return;
    }

    final (firstName, lastName) = splitName(name);
    setState(() => _saving = true);
    try {
      await ApiService.updateUser(session.id, {
        'name': name,
        'prenom': firstName,
        'nom': lastName,
        'phone': phone,
      });
      CurrentUserSession.signIn(
        AuthenticatedUser(
          id: session.id,
          fullName: name,
          email: session.email,
          role: session.role,
          phone: phone,
          theme: session.theme,
          textSize: session.textSize,
          autoBrightness: session.autoBrightness,
          powerSavingMode: session.powerSavingMode,
        ),
      );
      if (!mounted) return;
      _snack(context, 'Profil mis à jour');
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      final message = error.toString().replaceFirst('Exception: ', '').trim();
      _snack(
        context,
        message.isEmpty ? 'Impossible de mettre à jour le profil.' : message,
        success: false,
      );
    }
  }
}

class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});
  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Changer le mot de passe',
            style: TextStyle(
              color: kInk,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _current,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mot de passe actuel'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _new,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Nouveau mot de passe',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirm,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirmer'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: kRed,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Enregistrer',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final current = _current.text.trim();
    final next = _new.text.trim();
    if (current.isEmpty) {
      setState(() => _error = 'Le mot de passe actuel est obligatoire.');
      return;
    }
    if (next.length < 8) {
      setState(() => _error = 'Le nouveau mot de passe est trop court.');
      return;
    }
    if (next != _confirm.text.trim()) {
      setState(() => _error = 'Les mots de passe ne correspondent pas.');
      return;
    }

    final userId = CurrentUserSession.currentUser?.id ?? 0;
    if (userId <= 0) {
      setState(
        () =>
            _error = 'Impossible d\u2019identifier le compte à mettre à jour.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiService.changePassword(userId, current, next);
      if (!mounted) return;
      _snack(context, 'Mot de passe changé');
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '').trim();
      setState(() {
        _saving = false;
        _error = message.isEmpty
            ? 'Impossible de changer le mot de passe.'
            : message;
      });
    }
  }
}

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final options = [('Français', 'fr'), ('العربية', 'ar')];
    return AnimatedBuilder(
      animation: AppLocaleController.instance,
      builder: (context, _) {
        final current = AppLocaleController.instance.languageCode;
        return Scaffold(
          backgroundColor: kBg,
          body: Column(
            children: [
              AdminHeader(
                title: 'Langue',
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      decoration: cardBox(),
                      child: Column(
                        children: [
                          for (var i = 0; i < options.length; i++)
                            _choice(
                              options[i].$1,
                              options[i].$2 == current,
                              i == options.length - 1,
                              () => AppLocaleController.instance.setLocale(
                                Locale(options[i].$2),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _choice(
    String label,
    bool selected,
    bool isLast,
    VoidCallback onTap,
  ) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast ? BorderSide.none : const BorderSide(color: kBorder),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: kInk,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (selected) const Icon(Icons.check_circle_rounded, color: kGreen),
        ],
      ),
    ),
  );
}

class ThemeScreen extends StatelessWidget {
  const ThemeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final options = [
      ('Clair', AppThemePreference.light),
      ('Sombre', AppThemePreference.dark),
      ('Automatique', AppThemePreference.system),
    ];
    return AnimatedBuilder(
      animation: AppAppearanceController.instance,
      builder: (context, _) {
        final current = AppAppearanceController.instance.theme;
        return Scaffold(
          backgroundColor: kBg,
          body: Column(
            children: [
              AdminHeader(title: 'Thème', onBack: () => Navigator.pop(context)),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      decoration: cardBox(),
                      child: Column(
                        children: [
                          for (var i = 0; i < options.length; i++)
                            InkWell(
                              onTap: () => AppAppearanceController.instance
                                  .setTheme(options[i].$2),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: i == options.length - 1
                                        ? BorderSide.none
                                        : const BorderSide(color: kBorder),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        options[i].$1,
                                        style: const TextStyle(
                                          color: kInk,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (options[i].$2 == current)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: kGreen,
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
              ),
            ],
          ),
        );
      },
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Column(
        children: [
          AdminHeader(title: 'À propos', onBack: () => Navigator.pop(context)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: cardBox(),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: kGreen,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.shopping_cart_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'PreSales',
                        style: TextStyle(
                          color: kInk,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Version 1.0.0',
                        style: TextStyle(
                          color: kMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Application de gestion de prévente — Ryme Distribution.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: kMuted,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
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

// ---------------------------------------------------------------------------
// Paramètres
// ---------------------------------------------------------------------------

class ParametresPage extends StatelessWidget {
  const ParametresPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, Color, String, String, Widget)>[
      (
        Icons.business_rounded,
        kAccent,
        'Informations entreprise',
        'Gérez les informations générales',
        const CompanyInfoDbScreen(),
      ),
      (
        Icons.groups_rounded,
        kGreen,
        'Catégories clients',
        'Gérez les catégories de clients',
        const CategoryManagerScreen(
          title: 'Catégories clients',
          kind: 'client',
        ),
      ),
      (
        Icons.folder_rounded,
        kOrange,
        'Catégories produits',
        'Gérez les catégories de produits',
        const CategoryManagerScreen(
          title: 'Catégories produits',
          kind: 'product',
        ),
      ),
      (
        Icons.notifications_rounded,
        kAccent,
        'Notifications',
        'Paramétrez les notifications',
        const NotificationsSettingsScreen(),
      ),
      (
        Icons.lock_rounded,
        kGreen,
        'Sécurité',
        'Paramètres de sécurité et accès',
        const SecurityScreen(),
      ),
      (
        Icons.receipt_long_rounded,
        kOrange,
        'Journal d\'activité',
        'Consultez les actions effectuées',
        const JournalPage(),
      ),
    ];
    return Scaffold(
      backgroundColor: kBg,
      body: Column(
        children: [
          AdminHeader(
            title: 'Paramètres',
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final it in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => Navigator.push(context, phoneRoute(it.$5)),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: cardBox(),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: it.$2.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(it.$1, color: it.$2),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    it.$3,
                                    style: const TextStyle(
                                      color: kInk,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    it.$4,
                                    style: const TextStyle(
                                      color: kMuted,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: kMuted,
                            ),
                          ],
                        ),
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

class CompanyInfoScreen extends StatefulWidget {
  const CompanyInfoScreen({super.key});
  @override
  State<CompanyInfoScreen> createState() => _CompanyInfoScreenState();
}

class _CompanyInfoScreenState extends State<CompanyInfoScreen> {
  final _name = TextEditingController(text: 'Ryme Distribution');
  final _phone = TextEditingController(text: '0522 00 00 00');
  final _email = TextEditingController(text: 'contact@ryme.ma');
  final _address = TextEditingController(text: 'Casablanca, Maroc');

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: adminInputTheme,
      child: Scaffold(
        backgroundColor: kBg,
        body: Column(
          children: [
            AdminHeader(
              title: 'Informations entreprise',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FormSection('Entreprise', Icons.business_rounded, [
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Nom de la société',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phone,
                      decoration: const InputDecoration(labelText: 'Téléphone'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _email,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _address,
                      decoration: const InputDecoration(labelText: 'Adresse'),
                    ),
                  ]),
                  FormButtons(
                    submitLabel: 'Enregistrer',
                    onSubmit: () {
                      Navigator.pop(context);
                      _snack(context, 'Informations enregistrées');
                    },
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

class CompanyInfoDbScreen extends StatefulWidget {
  const CompanyInfoDbScreen({super.key});

  @override
  State<CompanyInfoDbScreen> createState() => _CompanyInfoDbScreenState();
}

class _CompanyInfoDbScreenState extends State<CompanyInfoDbScreen> {
  final _name = TextEditingController();
  final _logo = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _website = TextEditingController();
  final _currency = TextEditingController(text: 'DH');
  final _taxInfo = TextEditingController();
  final _legalInfo = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getCompanyInfo();
      if (!mounted) return;
      setState(() {
        _apply(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        success: false,
      );
    }
  }

  void _apply(Map<String, dynamic> data) {
    _name.text = _companyString(data, ['name', 'nom']);
    _logo.text = _companyString(data, ['logo']);
    _address.text = _companyString(data, ['address', 'adresse']);
    _phone.text = _companyString(data, ['phone', 'telephone']);
    _email.text = _companyString(data, ['email']);
    _website.text = _companyString(data, ['website', 'site_web']);
    _currency.text = _companyString(data, ['currency', 'devise']).ifEmpty('DH');
    _taxInfo.text = _companyString(data, ['tax_info', 'fiscal_info']);
    _legalInfo.text = _companyString(data, [
      'legal_info',
      'informations_legales',
    ]);
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _logo,
      _address,
      _phone,
      _email,
      _website,
      _currency,
      _taxInfo,
      _legalInfo,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_name.text.trim().isEmpty) {
      _snack(
        context,
        "Le nom de l'entreprise est obligatoire.",
        success: false,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final data = await ApiService.updateCompanyInfo({
        'name': _name.text.trim(),
        'logo': _logo.text.trim(),
        'address': _address.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'website': _website.text.trim(),
        'currency': _currency.text.trim().isEmpty
            ? 'DH'
            : _currency.text.trim(),
        'tax_info': _taxInfo.text.trim(),
        'legal_info': _legalInfo.text.trim(),
      });
      if (!mounted) return;
      setState(() {
        _apply(data);
        _saving = false;
      });
      _snack(context, "Informations de l'entreprise mises à jour avec succès.");
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(
        context,
        e
            .toString()
            .replaceFirst('Exception: ', '')
            .ifEmpty(
              "Impossible de mettre à jour les informations entreprise.",
            ),
        success: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: adminInputTheme,
      child: Scaffold(
        backgroundColor: kBg,
        body: Column(
          children: [
            AdminHeader(
              title: 'Informations entreprise',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        FormSection('Entreprise', Icons.business_rounded, [
                          _companyField(_name, "Nom de l'entreprise"),
                          _companyField(_logo, 'Logo / URL image'),
                          _companyField(_address, 'Adresse'),
                          _companyField(_phone, 'Téléphone'),
                          _companyField(
                            _email,
                            'Email',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          _companyField(_website, 'Site web'),
                          _companyField(_currency, 'Devise'),
                          _companyField(
                            _taxInfo,
                            'Informations fiscales',
                            maxLines: 2,
                          ),
                          _companyField(
                            _legalInfo,
                            'Informations légales',
                            maxLines: 2,
                          ),
                        ]),
                        FormButtons(
                          submitLabel: _saving
                              ? 'Enregistrement...'
                              : 'Enregistrer',
                          onSubmit: _save,
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

Widget _companyField(
  TextEditingController controller,
  String label, {
  TextInputType? keyboardType,
  int maxLines = 1,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
    ),
  );
}

String _companyString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString().trim();
    }
  }
  return '';
}

typedef AdminCategoryRowsLoader = Future<List<dynamic>> Function();
typedef AdminCategoryStoreReader = Future<String?> Function(String name);
typedef AdminCategoryStoreWriter =
    Future<void> Function(String name, String contents);

class CategoryManagerScreen extends StatefulWidget {
  const CategoryManagerScreen({
    super.key,
    required this.title,
    required this.kind,
    this.loadRows,
    this.readStore,
    this.writeStore,
  }) : assert(kind == 'client' || kind == 'product');
  final String title;
  final String kind; // 'client' | 'product'
  final AdminCategoryRowsLoader? loadRows;
  final AdminCategoryStoreReader? readStore;
  final AdminCategoryStoreWriter? writeStore;

  @override
  State<CategoryManagerScreen> createState() => _CategoryManagerScreenState();
}

class _CategoryManagerScreenState extends State<CategoryManagerScreen> {
  final List<String> _cats = [];
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  String get _storeName => _categoryStoreName(widget.kind);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final stored = await (widget.readStore ?? readLocalJson)(_storeName);
      late final List<String> categories;
      if (stored != null) {
        categories = _decodeCategories(stored);
      } else {
        final rows = await (widget.loadRows ?? _loadSeedRows)();
        categories = _categoriesFromRows(rows);
        await _writeCategories(categories);
      }
      if (!mounted) return;
      setState(() {
        _cats
          ..clear()
          ..addAll(categories);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = _adminSettingsError(
          error,
          'Impossible de charger les catégories.',
        );
      });
    }
  }

  Future<List<dynamic>> _loadSeedRows() => widget.kind == 'product'
      ? ApiService.getProduits()
      : ApiService.getClients();

  List<String> _categoriesFromRows(List<dynamic> rows) => _normalizeCategories(
    rows.whereType<Map>().map(
      (row) => widget.kind == 'product'
          ? _adminString(row, ['categorie', 'category', 'nom_cat'])
          : _adminString(row, ['category', 'business_type', 'categorie']),
    ),
  );

  List<String> _decodeCategories(String stored) {
    final decoded = jsonDecode(stored);
    final rawCategories = decoded is Map ? decoded['categories'] : decoded;
    if (rawCategories is! List) {
      throw const FormatException('Le fichier des catégories est invalide.');
    }
    return _normalizeCategories(rawCategories.map((value) => value.toString()));
  }

  Future<void> _writeCategories(List<String> values) =>
      (widget.writeStore ?? writeLocalJson)(
        _storeName,
        jsonEncode({'version': 1, 'kind': widget.kind, 'categories': values}),
      );

  Future<void> _delete(String category) async {
    if (_saving) return;
    final confirmed = await _confirmDestructiveAction(
      context,
      title: 'Supprimer la catégorie ?',
      message:
          'La catégorie « $category » sera retirée de cette liste de configuration.',
    );
    if (!confirmed || !mounted) return;

    final next = _cats.where((value) => value != category).toList();
    setState(() => _saving = true);
    try {
      await _writeCategories(next);
      if (!mounted) return;
      setState(() {
        _cats
          ..clear()
          ..addAll(next);
        _saving = false;
      });
      _snack(context, 'Catégorie supprimée.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(
        context,
        _adminSettingsError(error, 'Impossible de sauvegarder les catégories.'),
        success: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Column(
        children: [
          AdminHeader(
            title: widget.title,
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kGreen))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_loadError != null) ...[
                        _AdminSettingsErrorCard(
                          message: _loadError!,
                          onRetry: _load,
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (_loadError == null) ...[
                        GreenButton(
                          label: _saving
                              ? 'Enregistrement...'
                              : 'Ajouter une catégorie',
                          onPressed: _saving ? () {} : _add,
                        ),
                        if (_saving) ...[
                          const SizedBox(height: 8),
                          const LinearProgressIndicator(color: kGreen),
                        ],
                        const SizedBox(height: 14),
                        if (_cats.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Center(
                              child: Text(
                                'Aucune catégorie configurée.',
                                style: TextStyle(
                                  color: kMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        for (final c in _cats)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                            decoration: cardBox(),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    c,
                                    style: const TextStyle(
                                      color: kInk,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Supprimer $c',
                                  onPressed: _saving ? null : () => _delete(c),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: kRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _add() async {
    final v = await showDialog<String>(
      context: context,
      builder: (_) => const _AdminNewCategoryDialog(),
    );
    if (v == null || !mounted) return;
    final category = v.trim();
    if (category.isEmpty) {
      _snack(
        context,
        'Le nom de la catégorie est obligatoire.',
        success: false,
      );
      return;
    }
    if (_cats.any(
      (existing) => existing.toLowerCase() == category.toLowerCase(),
    )) {
      _snack(context, 'Cette catégorie existe déjà.', success: false);
      return;
    }

    final next = _normalizeCategories([..._cats, category]);
    setState(() => _saving = true);
    try {
      await _writeCategories(next);
      if (!mounted) return;
      setState(() {
        _cats
          ..clear()
          ..addAll(next);
        _saving = false;
      });
      _snack(context, 'Catégorie ajoutée.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(
        context,
        _adminSettingsError(error, 'Impossible de sauvegarder les catégories.'),
        success: false,
      );
    }
  }
}

/// Owns its [TextEditingController] via the widget lifecycle instead of a
/// manually-timed dispose call in the caller — disposing right after
/// `showDialog` returns can race the dialog's own close animation (it's
/// still mounted while animating out), which crashes with
/// "TextEditingController was used after being disposed".
class _AdminNewCategoryDialog extends StatefulWidget {
  const _AdminNewCategoryDialog();

  @override
  State<_AdminNewCategoryDialog> createState() =>
      _AdminNewCategoryDialogState();
}

class _AdminNewCategoryDialogState extends State<_AdminNewCategoryDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: adminInputTheme,
      child: AlertDialog(
        title: const Text('Nouvelle catégorie'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nom'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _controller.text.trim()),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }
}

String _adminSettingsError(Object error, String fallback) {
  final message = error.toString().replaceFirst('Exception: ', '').trim();
  return message.isEmpty ? fallback : message;
}

class _AdminSettingsErrorCard extends StatelessWidget {
  const _AdminSettingsErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kRed.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kRed.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: kRed),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: kRed, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}

typedef AdminNotificationPreferencesLoader =
    Future<Map<String, bool>> Function(int userId);
typedef AdminNotificationPreferencesSaver =
    Future<void> Function(int userId, Map<String, bool> values);

const Map<String, bool> _adminNotificationDefaults = {
  'new_orders': true,
  'new_clients': true,
  'sent_reports': true,
  'system_errors': false,
  'sounds': true,
};

const Map<String, String> _adminNotificationLabels = {
  'new_orders': 'Nouvelles commandes',
  'new_clients': 'Nouveaux clients',
  'sent_reports': 'Rapports envoyés',
  'system_errors': 'Erreurs système',
  'sounds': 'Sons',
};

final Map<int, Map<String, bool>> _adminNotificationPreferenceCache = {};

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({
    super.key,
    this.userId,
    this.loadPreferences,
    this.savePreferences,
  });

  final int? userId;
  final AdminNotificationPreferencesLoader? loadPreferences;
  final AdminNotificationPreferencesSaver? savePreferences;

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  late final int _userId;
  Map<String, bool> _values = {..._adminNotificationDefaults};
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _userId = widget.userId ?? CurrentUserSession.currentUser?.id ?? 0;
    _load();
  }

  Future<void> _load() async {
    if (_userId <= 0) {
      setState(() {
        _loading = false;
        _loadError = 'Impossible d’identifier le compte administrateur.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final loaded =
          await (widget.loadPreferences ?? _loadAdminNotificationPreferences)(
            _userId,
          );
      if (!mounted) return;
      setState(() {
        _values = {
          for (final entry in _adminNotificationDefaults.entries)
            entry.key: loaded[entry.key] ?? entry.value,
        };
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '').trim();
      setState(() {
        _loading = false;
        _loadError = message.isEmpty
            ? 'Impossible de charger les préférences.'
            : message;
      });
    }
  }

  Future<void> _update(String key, bool value) async {
    if (_saving || _loading || _userId <= 0) return;
    final previous = _values[key] ?? false;
    final next = {..._values, key: value};
    setState(() {
      _values = next;
      _saving = true;
    });

    try {
      await (widget.savePreferences ?? _saveAdminNotificationPreferences)(
        _userId,
        Map<String, bool>.unmodifiable(next),
      );
      _adminNotificationPreferenceCache[_userId] = {...next};
      if (!mounted) return;
      setState(() => _saving = false);
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '').trim();
      setState(() {
        _values = {..._values, key: previous};
        _saving = false;
      });
      _snack(
        context,
        message.isEmpty ? 'Impossible de sauvegarder la préférence.' : message,
        success: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Column(
        children: [
          AdminHeader(
            title: 'Notifications',
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kGreen))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_loadError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: kRed.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: kRed.withValues(alpha: .25),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: kRed),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _loadError!,
                                  style: const TextStyle(
                                    color: kRed,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _load,
                                child: const Text('Réessayer'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_saving)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: LinearProgressIndicator(color: kGreen),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: cardBox(),
                        child: Column(
                          children: [
                            for (final entry
                                in _adminNotificationLabels.entries)
                              Material(
                                type: MaterialType.transparency,
                                child: SwitchListTile(
                                  title: Text(
                                    entry.value,
                                    style: const TextStyle(
                                      color: kInk,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  value:
                                      _values[entry.key] ??
                                      _adminNotificationDefaults[entry.key]!,
                                  activeThumbColor: kGreen,
                                  onChanged: _saving
                                      ? null
                                      : (value) => _update(entry.key, value),
                                ),
                              ),
                          ],
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

Future<Map<String, bool>> _loadAdminNotificationPreferences(int userId) async {
  final cached = _adminNotificationPreferenceCache[userId];
  try {
    final rows = await ApiService.getUsers();
    Map<dynamic, dynamic>? user;
    for (final row in rows.whereType<Map>()) {
      if (_adminInt(row, ['id', 'user_id']) == userId) {
        user = row;
        break;
      }
    }

    final rawPreferences = user?['preferences'];
    final preferences = rawPreferences is Map
        ? rawPreferences
        : const <String, dynamic>{};
    final rawNotificationPreferences =
        preferences['notification_preferences'] ??
        user?['notification_preferences'];
    final notificationPreferences = rawNotificationPreferences is Map
        ? rawNotificationPreferences
        : const <String, dynamic>{};

    final loaded = {..._adminNotificationDefaults};
    var hasGranularPreference = false;
    for (final key in _adminNotificationDefaults.keys) {
      final value = _adminPreferenceBool(notificationPreferences[key]);
      if (value == null) continue;
      loaded[key] = value;
      hasGranularPreference = true;
    }

    if (!hasGranularPreference) {
      final master = _adminPreferenceBool(
        preferences['notifications_enabled'] ?? user?['notifications_enabled'],
      );
      if (master != null) {
        for (final key in loaded.keys) {
          loaded[key] = master;
        }
      } else if (cached != null) {
        loaded.addAll(cached);
      }
    }

    _adminNotificationPreferenceCache[userId] = {...loaded};
    return loaded;
  } catch (_) {
    if (cached != null) return {...cached};
    rethrow;
  }
}

Future<void> _saveAdminNotificationPreferences(
  int userId,
  Map<String, bool> values,
) async {
  final notificationsEnabled = values.entries
      .where((entry) => entry.key != 'sounds')
      .any((entry) => entry.value);
  await ApiService.updateUserPreferences(userId, {
    'notifications_enabled': notificationsEnabled,
    // The demo store retains the granular map. The live API currently accepts
    // the master flag and safely ignores this forward-compatible field.
    'notification_preferences': values,
  });
}

bool? _adminPreferenceBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1') return true;
  if (normalized == 'false' || normalized == '0') return false;
  return null;
}

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Column(
        children: [
          AdminHeader(title: 'Sécurité', onBack: () => Navigator.pop(context)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  decoration: cardBox(),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.white,
                          constraints: const BoxConstraints(maxWidth: 430),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(22),
                            ),
                          ),
                          builder: (_) => Theme(
                            data: adminInputTheme,
                            child: const ChangePasswordSheet(),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.lock_outline_rounded, color: kInk),
                              SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Changer le mot de passe',
                                  style: TextStyle(
                                    color: kInk,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, color: kMuted),
                            ],
                          ),
                        ),
                      ),
                    ],
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

// ---------------------------------------------------------------------------
// Journal d'activité
// ---------------------------------------------------------------------------

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});
  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  final _search = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await ApiService.getCommercialRecentActivities();
    return rows
        .whereType<Map>()
        .map((row) => row.cast<String, dynamic>())
        .toList();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Column(
        children: [
          AdminHeader(
            title: 'Journal d\'activite',
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                final q = _search.text.trim().toLowerCase();
                final entries =
                    (snapshot.data ?? const <Map<String, dynamic>>[]).where((
                      e,
                    ) {
                      final title = _adminString(e, ['titre', 'title']);
                      final description = _adminString(e, [
                        'description',
                        'message',
                      ]);
                      return q.isEmpty ||
                          title.toLowerCase().contains(q) ||
                          description.toLowerCase().contains(q);
                    }).toList();
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    AdminSearchRow(
                      controller: _search,
                      hint: 'Rechercher dans le journal...',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),
                    if (entries.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text(
                            'Aucune donnée disponible',
                            style: TextStyle(
                              color: kMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    for (final e in entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: cardBox(),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: kAccent.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: const Icon(
                                  Icons.history_rounded,
                                  color: kAccent,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _adminString(e, [
                                        'created_at',
                                        'date',
                                      ]).ifEmpty('-'),
                                      style: const TextStyle(
                                        color: kMuted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _adminString(e, [
                                        'titre',
                                        'title',
                                      ]).ifEmpty('Activite'),
                                      style: const TextStyle(
                                        color: kInk,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _adminString(e, [
                                        'description',
                                        'message',
                                      ]).ifEmpty('-'),
                                      style: const TextStyle(
                                        color: kGreen,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

Future<List<dynamic>> _loadAndMarkAdminNotificationsRead() async {
  final rows = await ApiService.getNotifications();
  try {
    await ApiService.markAllNotificationsRead();
  } catch (error) {
    debugPrint('[ADMIN][NOTIFICATIONS][MARK_READ][ERROR] $error');
  }
  await syncAdminUnreadNotifications();
  return rows;
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Column(
        children: [
          AdminHeader(
            title: 'Notifications',
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _loadAndMarkAdminNotificationsRead(),
              builder: (context, snapshot) {
                final items =
                    snapshot.data?.whereType<Map>().toList() ?? const <Map>[];
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text(
                            'Aucune donnée disponible',
                            style: TextStyle(
                              color: kMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    for (final n in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: cardBox(),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: kAccent.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.notifications_none_rounded,
                                  color: kAccent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _adminString(n, [
                                        'titre',
                                        'title',
                                      ]).ifEmpty('Notification'),
                                      style: const TextStyle(
                                        color: kInk,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _adminString(n, [
                                        'description',
                                        'message',
                                      ]).ifEmpty('-'),
                                      style: const TextStyle(
                                        color: kMuted,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _adminString(n, [
                                  'created_at',
                                  'date',
                                ]).ifEmpty('-'),
                                style: const TextStyle(
                                  color: kMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
