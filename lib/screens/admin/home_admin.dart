import 'package:flutter/material.dart';

import '../../auth/current_user_session.dart';
import '../../data/mock_presales_data.dart';
import '../../l10n/app_locale_controller.dart';
import '../../settings/app_appearance_controller.dart';
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

void _snack(BuildContext c, String msg) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg)));

/// Keeps pushed pages at phone width (centered on desktop, full-width on phone).
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: kBg,
    child: Center(
      child: SizedBox(width: 430, height: double.infinity, child: child),
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
  int _index = 0;

  void _go(int i) {
    _scaffoldKey.currentState?.closeDrawer();
    setState(() => _index = i);
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
    final args = ModalRoute.of(context)?.settings.arguments;
    final routeEmail = args is Map ? args['email']?.toString() ?? '' : '';
    final user = session?.isAdmin == true
        ? MockPreSalesData.userByEmail(session!.email)
        : MockPreSalesData.userByEmail(routeEmail);

    if (session == null && user == null) {
      _redirect('/login');
      return const Scaffold(backgroundColor: kBg);
    }
    if (session?.isCommercial == true || user?.role == MockUserRole.commercial) {
      _redirect('/home-commercial');
      return const Scaffold(backgroundColor: kBg);
    }
    if (session?.isManager == true || user?.role == MockUserRole.manager) {
      _redirect('/home-manager');
      return const Scaffold(backgroundColor: kBg);
    }

    final name = user?.name ?? session?.fullName ?? 'Administrateur';
    final email = user?.email ?? session?.email ?? 'admin@presales.ma';
    final phone = user?.phone ?? '';

    final pages = [
      AccueilPage(onMenu: _menu, onBell: _bell, name: name),
      UtilisateursPage(onMenu: _menu, onBell: _bell),
      ProduitsPage(onMenu: _menu, onBell: _bell),
      CommandesPage(onMenu: _menu, onBell: _bell),
      ProfilPage(onMenu: _menu, onBell: _bell, name: name, email: email, phone: phone),
      ClientsPage(onMenu: _menu, onBell: _bell),
    ];

    // Phone frame wraps the Scaffold itself, so the drawer + sheets stay
    // inside the 430px panel instead of spanning the desktop window.
    return ColoredBox(
      color: kBg,
      child: Center(
        child: SizedBox(
          width: 430,
          height: double.infinity,
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
                Expanded(child: IndexedStack(index: _index, children: pages)),
                AdminBottomNav(
                  selectedIndex: _index <= 4 ? _index : -1,
                  onChanged: (i) => setState(() => _index = i),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _menu() => _scaffoldKey.currentState?.openDrawer();
  void _bell() => Navigator.push(context, phoneRoute(const NotificationsPage()));
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
                    decoration: BoxDecoration(color: kGreen.withValues(alpha: .14), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.verified_user_rounded, color: kGreen),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Administrateur', style: TextStyle(color: kInk, fontSize: 16, fontWeight: FontWeight.w900)),
                        Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kMuted, fontSize: 12)),
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
            _DrawerItem(Icons.dashboard_rounded, 'Dashboard', selectedIndex == 0, () => onSelect(0)),
            _DrawerItem(Icons.groups_rounded, 'Utilisateurs', selectedIndex == 1, () => onSelect(1)),
            _DrawerItem(Icons.inventory_2_rounded, 'Produits', selectedIndex == 2, () => onSelect(2)),
            _DrawerItem(Icons.storefront_rounded, 'Clients', selectedIndex == 5, () => onSelect(5)),
            _DrawerItem(Icons.receipt_long_rounded, 'Commandes', selectedIndex == 3, () => onSelect(3)),
            _DrawerItem(Icons.history_rounded, 'Journal d\'activité', false, () => onPush(const JournalPage())),
            _DrawerItem(Icons.settings_rounded, 'Paramètres', false, () => onPush(const ParametresPage())),
            const _DrawerLabel('AUTRES'),
            _DrawerItem(Icons.notifications_none_rounded, 'Notifications', false, () => onPush(const NotificationsPage()), badge: '8'),
            _DrawerItem(Icons.logout_rounded, 'Déconnexion', false, () {
              CurrentUserSession.signOut();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
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
    child: Text(text, style: const TextStyle(color: kMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .5)),
  );
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem(this.icon, this.label, this.selected, this.onTap, {this.badge, this.danger = false});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;
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
                Icon(icon, color: danger ? kRed : (selected ? kGreen : kMuted), size: 22),
                const SizedBox(width: 14),
                Expanded(child: Text(label, style: TextStyle(color: color, fontSize: 14.5, fontWeight: selected ? FontWeight.w900 : FontWeight.w700))),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.all(5),
                    constraints: const BoxConstraints(minWidth: 22),
                    decoration: const BoxDecoration(color: kRed, shape: BoxShape.circle),
                    child: Text(badge!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
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
  const AdminBottomNav({super.key, required this.selectedIndex, required this.onChanged});
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static const _items = [
    (Icons.home_rounded, 'Accueil'),
    (Icons.groups_rounded, 'Utilisateurs'),
    (Icons.inventory_2_rounded, 'Produits'),
    (Icons.receipt_long_rounded, 'Commandes'),
    (Icons.person_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: kBorder)),
        boxShadow: [BoxShadow(color: kInk.withValues(alpha: .05), blurRadius: 16, offset: const Offset(0, -6))],
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
                        Icon(_items[i].$1, size: 23, color: selectedIndex == i ? kGreen : kMuted),
                        const SizedBox(height: 3),
                        Text(_items[i].$2, style: TextStyle(color: selectedIndex == i ? kGreen : kMuted, fontSize: 10.5, fontWeight: selectedIndex == i ? FontWeight.w900 : FontWeight.w700)),
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

class AccueilPage extends StatelessWidget {
  const AccueilPage({super.key, required this.onMenu, required this.onBell, required this.name});
  final VoidCallback onMenu;
  final VoidCallback onBell;
  final String name;

  @override
  Widget build(BuildContext context) {
    final users = MockPreSalesData.users.values;
    final commerciaux = users.where((u) => u.role == MockUserRole.commercial).length;
    final managers = users.where((u) => u.role == MockUserRole.manager).length;
    final clients = MockPreSalesData.teaSudClients.length;
    final produits = MockPreSalesData.orderProducts.length;
    final pending = sampleOrders.where((o) => o.status == 'pending').length;
    final validated = sampleOrders.where((o) => o.status == 'validated').length;
    final refused = sampleOrders.where((o) => o.status == 'refused').length;
    final ca = sampleOrders.where((o) => o.status == 'validated').fold<double>(0, (s, o) => s + o.total);

    return Column(
      children: [
        AdminHeader(title: '', onMenu: onMenu, onBell: onBell, greeting: 'Bonjour, Administrateur 👋', subtitle: 'Mardi 03 Décembre 2024'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            children: [
              const _SectionTitle('Aperçu global'),
              const SizedBox(height: 12),
              _kpiRow([
                _Kpi('Commerciaux', '$commerciaux', Icons.badge_rounded, kGreen),
                _Kpi('Managers', '$managers', Icons.shield_rounded, kBlue),
                _Kpi('Clients', '$clients', Icons.storefront_rounded, kGreen),
                _Kpi('Produits', '$produits', Icons.inventory_2_rounded, kOrange),
              ]),
              const SizedBox(height: 12),
              _kpiRow([
                _Kpi('Commandes', '${sampleOrders.length}', Icons.receipt_long_rounded, kBlue),
                _Kpi('En attente', '$pending', Icons.schedule_rounded, kOrange),
                _Kpi('Validées', '$validated', Icons.check_circle_rounded, kGreen),
                _Kpi('Refusées', '$refused', Icons.cancel_rounded, kRed),
              ]),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: cardBox(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Chiffre d\'affaires global', style: TextStyle(color: kInk, fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${_money(ca)} ', style: const TextStyle(color: kInk, fontSize: 26, fontWeight: FontWeight.w900)),
                        const Padding(padding: EdgeInsets.only(bottom: 4), child: Text('MAD', style: TextStyle(color: kMuted, fontWeight: FontWeight.w800))),
                        const Spacer(),
                        const StatusBadge(label: '+12.5%', color: kGreen),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const SizedBox(height: 70, child: _LineChart([12, 18, 15, 22, 19, 28], labels: [])),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: cardBox(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(children: [
                      Text('Évolution des ventes ', style: TextStyle(color: kInk, fontSize: 14, fontWeight: FontWeight.w800)),
                      Text('(6 derniers mois)', style: TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                    SizedBox(height: 16),
                    SizedBox(height: 130, child: _LineChart([20, 35, 30, 40, 38, 52], labels: ['Juil', 'Août', 'Sept', 'Oct', 'Nov', 'Déc'])),
                  ],
                ),
              ),
            ],
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(color: kInk, fontSize: 16, fontWeight: FontWeight.w900));
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
            decoration: BoxDecoration(color: kpi.color.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
            child: Icon(kpi.icon, color: kpi.color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(kpi.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kMuted, fontSize: 10.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(kpi.value, style: const TextStyle(color: kInk, fontSize: 19, fontWeight: FontWeight.w900)),
          const Text('Total', style: TextStyle(color: kMuted, fontSize: 9.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
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
    final maxV = values.reduce((a, b) => a > b ? a : b) * 1.15;
    final chartH = labels.isEmpty ? size.height : size.height - 18;
    final dx = size.width / (values.length - 1);
    Offset pt(int i) => Offset(i * dx, chartH - (values[i] / maxV) * chartH);

    final line = Paint()..color = kGreen..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final fill = Paint()..color = kGreen.withValues(alpha: .10);
    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }
    final area = Path.from(path)..lineTo(size.width, chartH)..lineTo(0, chartH)..close();
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
        text: TextSpan(text: labels[i], style: const TextStyle(color: kMuted, fontSize: 10, fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(i * dx - tp.width / 2, size.height - 14));
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.values != values;
}

// ---------------------------------------------------------------------------
// Utilisateurs
// ---------------------------------------------------------------------------

class UtilisateursPage extends StatefulWidget {
  const UtilisateursPage({super.key, required this.onMenu, required this.onBell});
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
    loadDbUsers(_store).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final users = _store.filter(query: _search.text, role: _role, active: _active);
    return Column(
      children: [
        AdminHeader(title: 'Utilisateurs', onMenu: widget.onMenu, onBell: widget.onBell),
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
                _UserCard(user: u, onTap: () => _openDetail(u), onAction: (a) => _action(a, u)),
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
    child: Center(child: Text(t, style: const TextStyle(color: kMuted, fontWeight: FontWeight.w700))),
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
          decoration: BoxDecoration(color: selected ? kGreen : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: selected ? kGreen : kBorder)),
          child: Text(label, style: TextStyle(color: selected ? Colors.white : kInk, fontSize: 13, fontWeight: FontWeight.w800)),
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
    final result = await Navigator.push<MockUserProfile>(context, phoneRoute<MockUserProfile>(const UserFormScreen()));
    if (result == null || !mounted) return;
    final dbId = await dbInsertUser(result);
    if (!mounted) return;
    _store.upsert(copyUser(result, id: AdminUserStore.dbBase + dbId));
    setState(() {});
    _snack(context, 'Utilisateur créé — il peut se connecter');
  }

  Future<void> _openDetail(MockUserProfile u) async {
    final action = await Navigator.push<String>(context, phoneRoute<String>(UserDetailScreen(user: u)));
    if (action == null || !mounted) return;
    await _action(action, u);
  }

  Future<void> _action(String a, MockUserProfile u) async {
    switch (a) {
      case 'edit':
        final result = await Navigator.push<MockUserProfile>(context, phoneRoute<MockUserProfile>(UserFormScreen(user: u)));
        if (result == null || !mounted) return;
        if (AdminUserStore.isDbUser(u.id)) {
          await dbUpdateUser(u.id, result);
          if (!mounted) return;
        }
        _store.upsert(result);
        setState(() {});
      case 'reset':
        _store.resetPassword(u.id);
        if (AdminUserStore.isDbUser(u.id)) {
          await dbSetUserPassword(u.id, '123456');
          if (!mounted) return;
        }
        setState(() {});
        _snack(context, 'Mot de passe réinitialisé (123456)');
      case 'toggle':
        _store.setActive(u.id, !u.isActive);
        setState(() {});
      case 'delete':
        if (AdminUserStore.isDbUser(u.id)) {
          await dbDeleteUser(u.id);
          if (!mounted) return;
        }
        _store.remove(u.id);
        setState(() {});
    }
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.onTap, required this.onAction});
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
            CircleAvatar(radius: 24, backgroundColor: kGreen.withValues(alpha: .14), child: Text(initials(user.name), style: const TextStyle(color: kGreen, fontWeight: FontWeight.w900))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kInk, fontSize: 15, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(roleLabel(user.role), style: const TextStyle(color: kMuted, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kMuted, fontSize: 12)),
                ],
              ),
            ),
            Column(
              children: [
                StatusBadge(label: user.isActive ? 'Actif' : 'Désactivé', color: user.isActive ? kGreen : kRed),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: kMuted),
                  onSelected: onAction,
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                    const PopupMenuItem(value: 'reset', child: Text('Réinitialiser mot de passe')),
                    PopupMenuItem(value: 'toggle', child: Text(user.isActive ? 'Désactiver' : 'Activer')),
                    const PopupMenuItem(value: 'delete', child: Text('Supprimer', style: TextStyle(color: kRed))),
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
            AdminHeader(title: 'Détail utilisateur', onBack: () => Navigator.pop(context)),
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
                        CircleAvatar(radius: 36, backgroundColor: kGreen.withValues(alpha: .14), child: Text(initials(user.name), style: const TextStyle(color: kGreen, fontSize: 24, fontWeight: FontWeight.w900))),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Flexible(child: Text(user.name, style: const TextStyle(color: kInk, fontSize: 18, fontWeight: FontWeight.w900))),
                                const SizedBox(width: 8),
                                StatusBadge(label: user.isActive ? 'Actif' : 'Désactivé', color: user.isActive ? kGreen : kRed),
                              ]),
                              const SizedBox(height: 4),
                              Text(roleLabel(user.role), style: const TextStyle(color: kMuted, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(user.email, style: const TextStyle(color: kMuted, fontSize: 13)),
                              Text(user.phone.isEmpty ? 'Non renseigné' : user.phone, style: const TextStyle(color: kMuted, fontSize: 13)),
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
                          labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                          tabs: [Tab(text: 'Informations'), Tab(text: 'Performances'), Tab(text: 'Activités'), Tab(text: 'Rapports')],
                        ),
                        SizedBox(
                          height: 300,
                          child: TabBarView(children: [
                            _infoTab(),
                            const _EmptyTab('Aucune performance disponible'),
                            const _EmptyTab('Aucune activité enregistrée'),
                            const _EmptyTab('Aucun rapport envoyé'),
                          ]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: _btn('Modifier', kGreen, Icons.edit_rounded, () => Navigator.pop(context, 'edit'))),
                    const SizedBox(width: 8),
                    Expanded(child: _btn('Réinitialiser', kOrange, Icons.lock_reset_rounded, () => Navigator.pop(context, 'reset'))),
                    const SizedBox(width: 8),
                    Expanded(child: _btn(user.isActive ? 'Désactiver' : 'Activer', kRed, Icons.block_rounded, () => Navigator.pop(context, 'toggle'))),
                  ]),
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
            child: Row(children: [
              Expanded(child: Text(r.$1, style: const TextStyle(color: kMuted, fontWeight: FontWeight.w600))),
              Flexible(child: Text(r.$2, textAlign: TextAlign.right, style: const TextStyle(color: kInk, fontWeight: FontWeight.w800))),
            ]),
          ),
      ],
    );
  }

  Widget _btn(String label, Color color, IconData icon, VoidCallback onTap) => ElevatedButton(
    onPressed: onTap,
    style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
  );
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Center(child: Text(text, style: const TextStyle(color: kMuted, fontWeight: FontWeight.w700)));
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
            AdminHeader(title: widget.user == null ? 'Nouvel utilisateur' : 'Modifier', onBack: () => Navigator.pop(context)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FormSection('Informations personnelles', Icons.person_rounded, [
                    Row(children: [
                      Expanded(child: _input(_prenom, 'Prénom *')),
                      const SizedBox(width: 10),
                      Expanded(child: _input(_nom, 'Nom *')),
                    ]),
                    const SizedBox(height: 12),
                    _input(_phone, 'Téléphone'),
                    const SizedBox(height: 12),
                    _input(_email, 'Email *'),
                  ]),
                  FormSection('Informations du compte', Icons.lock_rounded, [
                    DropdownButtonFormField<MockUserRole>(
                      initialValue: _role,
                      decoration: const InputDecoration(labelText: 'Rôle *'),
                      items: [for (final r in MockUserRole.values) DropdownMenuItem(value: r, child: Text(roleLabel(r)))],
                      onChanged: (r) => setState(() => _role = r ?? _role),
                    ),
                    SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Compte actif'), value: _active, activeThumbColor: kGreen, onChanged: (v) => setState(() => _active = v)),
                    _input(_password, widget.user == null ? 'Mot de passe temporaire *' : 'Nouveau mot de passe (optionnel)'),
                  ]),
                  if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_error!, style: const TextStyle(color: kRed, fontWeight: FontWeight.w700))),
                  FormButtons(submitLabel: widget.user == null ? 'Créer' : 'Enregistrer', onSubmit: _submit),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(TextEditingController c, String label) => TextField(controller: c, decoration: InputDecoration(labelText: label));

  void _submit() {
    final name = '${_prenom.text.trim()} ${_nom.text.trim()}'.trim();
    final email = _email.text.trim();
    if (name.isEmpty || email.isEmpty) {
      setState(() => _error = 'Nom, prénom et email sont obligatoires.');
      return;
    }
    if (widget.user == null && _password.text.trim().isEmpty) {
      setState(() => _error = 'Le mot de passe est obligatoire.');
      return;
    }
    Navigator.pop(
      context,
      MockUserProfile(
        id: widget.user?.id ?? 0,
        name: name,
        email: email,
        phone: _phone.text.trim(),
        password: _password.text.trim().isEmpty ? (widget.user?.password ?? '123456') : _password.text.trim(),
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
          Row(children: [Icon(icon, color: kGreen, size: 18), const SizedBox(width: 8), Text(title, style: const TextStyle(color: kInk, fontSize: 14, fontWeight: FontWeight.w900))]),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class FormButtons extends StatelessWidget {
  const FormButtons({super.key, required this.submitLabel, required this.onSubmit});
  final String submitLabel;
  final VoidCallback onSubmit;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: const BorderSide(color: kBorder)),
          child: const Text('Annuler', style: TextStyle(color: kInk, fontWeight: FontWeight.w800)),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: ElevatedButton(
          onPressed: onSubmit,
          style: ElevatedButton.styleFrom(backgroundColor: kGreen, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14)),
          child: Text(submitLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
    ]);
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
    _store.load().then((_) {
      if (mounted) setState(() {});
    });
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
        AdminHeader(title: 'Produits', onMenu: widget.onMenu, onBell: widget.onBell),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            children: [
              AdminSearchRow(controller: _search, hint: 'Rechercher un produit...', onChanged: (_) => setState(() {}), filterActive: _category != null, onFilter: _filter),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: StatTile(label: 'Total produits', value: '${all.length}', color: kGreen)),
                const SizedBox(width: 10),
                Expanded(child: StatTile(label: 'En stock', value: '$inStock', color: kGreen)),
                const SizedBox(width: 10),
                Expanded(child: StatTile(label: 'Stock faible', value: '$low', color: kOrange)),
                const SizedBox(width: 10),
                Expanded(child: StatTile(label: 'Rupture', value: '$out', color: kRed)),
              ]),
              const SizedBox(height: 14),
              GreenButton(label: 'Nouveau produit', onPressed: _create),
              const SizedBox(height: 14),
              for (final p in products) ...[
                InkWell(onTap: () => _edit(p), borderRadius: BorderRadius.circular(16), child: _productCard(p)),
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
    final p = await Navigator.push<OrderProduct>(context, phoneRoute<OrderProduct>(ProductFormScreen(store: _store)));
    if (p == null || !mounted) return;
    await _store.add(p);
    if (!mounted) return;
    setState(() {});
    _snack(context, 'Produit ajouté');
  }

  Future<void> _edit(OrderProduct product) async {
    final result = await Navigator.push<ProductFormResult>(context, phoneRoute<ProductFormResult>(ProductFormScreen(store: _store, product: product)));
    if (result == null || !mounted) return;
    if (result.deleted) {
      await _store.remove(product.id);
    } else if (result.product != null) {
      await _store.update(result.product!);
    }
    if (!mounted) return;
    setState(() {});
  }

  Widget _productCard(OrderProduct p) {
    final low = p.stock <= 60;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: cardBox(),
      child: Row(
        children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: p.imageColor.withValues(alpha: .14), borderRadius: BorderRadius.circular(14)), child: Icon(p.icon, color: p.imageColor, size: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kInk, fontSize: 14.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(p.reference, style: const TextStyle(color: kMuted, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${p.unitPrice.toStringAsFixed(2)} MAD', style: const TextStyle(color: kInk, fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Row(children: [Icon(Icons.circle, size: 8, color: low ? kOrange : kGreen), const SizedBox(width: 4), Text('Stock: ${p.stock}', style: const TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w700))]),
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

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, required this.store, this.product});
  final ProductStore store;
  final OrderProduct? product;
  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _ref = TextEditingController(text: widget.product?.reference ?? '');
  late final _category = TextEditingController(text: widget.product?.category ?? '');
  late final _price = TextEditingController(text: widget.product?.unitPrice.toStringAsFixed(2) ?? '');
  late final _stock = TextEditingController(text: widget.product?.stock.toString() ?? '');
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _ref, _category, _price, _stock]) {
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
            AdminHeader(title: editing ? 'Modifier le produit' : 'Nouveau produit', onBack: () => Navigator.pop(context)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FormSection('Informations générales', Icons.inventory_2_rounded, [
                    TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nom du produit *')),
                    const SizedBox(height: 12),
                    TextField(controller: _ref, decoration: const InputDecoration(labelText: 'Référence *')),
                    const SizedBox(height: 12),
                    TextField(controller: _category, decoration: const InputDecoration(labelText: 'Catégorie')),
                  ]),
                  FormSection('Tarification & stock', Icons.payments_rounded, [
                    TextField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix de vente (MAD) *')),
                    const SizedBox(height: 12),
                    TextField(controller: _stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock disponible *')),
                  ]),
                  if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_error!, style: const TextStyle(color: kRed, fontWeight: FontWeight.w700))),
                  FormButtons(submitLabel: editing ? 'Enregistrer' : 'Ajouter', onSubmit: _submit),
                  if (editing)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextButton.icon(
                        onPressed: () => Navigator.pop(context, ProductFormResult(deleted: true)),
                        icon: const Icon(Icons.delete_outline_rounded, color: kRed),
                        label: const Text('Supprimer le produit', style: TextStyle(color: kRed, fontWeight: FontWeight.w800)),
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
    if (name.isEmpty || _ref.text.trim().isEmpty || price == null || stock == null) {
      setState(() => _error = 'Nom, référence, prix et stock (numériques) sont obligatoires.');
      return;
    }
    final built = widget.store.build(id: widget.product?.id, name: name, reference: _ref.text.trim(), category: _category.text.trim(), price: price, stock: stock);
    Navigator.pop(context, widget.product == null ? built : ProductFormResult(product: built));
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
    _store.load().then((_) {
      if (mounted) setState(() {});
    });
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
        AdminHeader(title: 'Clients', onMenu: widget.onMenu, onBell: widget.onBell),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            children: [
              AdminSearchRow(controller: _search, hint: 'Rechercher un client...', onChanged: (_) => setState(() {}), filterActive: _status != null, onFilter: _filter),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: StatTile(label: 'Total clients', value: '${_store.all.length}', color: kGreen)),
                const SizedBox(width: 10),
                Expanded(child: StatTile(label: 'Actifs', value: '${_store.count(ClientStatus.visited)}', color: kGreen)),
                const SizedBox(width: 10),
                Expanded(child: StatTile(label: 'Inactifs', value: '${_store.count(ClientStatus.inactive)}', color: kRed)),
                const SizedBox(width: 10),
                Expanded(child: StatTile(label: 'Prospects', value: '${_store.count(ClientStatus.toVisit)}', color: kOrange)),
              ]),
              const SizedBox(height: 14),
              GreenButton(label: 'Nouveau client', onPressed: _create),
              const SizedBox(height: 14),
              for (final c in clients) ...[
                InkWell(onTap: () => _edit(c), borderRadius: BorderRadius.circular(16), child: _clientCard(c)),
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
      options: const [('Tous', null), ('Actifs', ClientStatus.visited), ('Inactifs', ClientStatus.inactive), ('Prospects', ClientStatus.toVisit)],
    );
    setState(() => _status = v);
  }

  Future<void> _create() async {
    final c = await Navigator.push<CommercialClient>(context, phoneRoute<CommercialClient>(ClientFormScreen(store: _store)));
    if (c == null || !mounted) return;
    await _store.add(c);
    if (!mounted) return;
    setState(() {});
    _snack(context, 'Client ajouté');
  }

  Future<void> _edit(CommercialClient client) async {
    final result = await Navigator.push<ClientFormResult>(context, phoneRoute<ClientFormResult>(ClientFormScreen(store: _store, client: client)));
    if (result == null || !mounted) return;
    if (result.deleted) {
      await _store.remove(client.id);
    } else if (result.client != null) {
      await _store.update(result.client!);
    }
    if (!mounted) return;
    setState(() {});
  }

  Widget _clientCard(CommercialClient c) {
    final (label, color) = clientStatusStyle(c.status);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: cardBox(),
      child: Row(
        children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: kGreen.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.storefront_rounded, color: kGreen, size: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kInk, fontSize: 14.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(c.city, style: const TextStyle(color: kMuted, fontSize: 12.5, fontWeight: FontWeight.w700)),
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
  late final _category = TextEditingController(text: widget.client?.category ?? '');
  late final _address = TextEditingController(text: widget.client?.address ?? '');
  late final _phone = TextEditingController(text: widget.client?.phone ?? '');
  late final _email = TextEditingController(text: widget.client?.email ?? '');
  late ClientStatus _status = widget.client?.status ?? ClientStatus.visited;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _city, _category, _address, _phone, _email]) {
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
            AdminHeader(title: editing ? 'Modifier le client' : 'Nouveau client', onBack: () => Navigator.pop(context)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FormSection('Informations générales', Icons.storefront_rounded, [
                    TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nom / Raison sociale *')),
                    const SizedBox(height: 12),
                    TextField(controller: _city, decoration: const InputDecoration(labelText: 'Ville *')),
                    const SizedBox(height: 12),
                    TextField(controller: _category, decoration: const InputDecoration(labelText: 'Catégorie')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ClientStatus>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Statut'),
                      items: [for (final s in ClientStatus.values) DropdownMenuItem(value: s, child: Text(clientStatusStyle(s).$1))],
                      onChanged: (s) => setState(() => _status = s ?? _status),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _address, decoration: const InputDecoration(labelText: 'Adresse')),
                  ]),
                  FormSection('Contact', Icons.contact_phone_rounded, [
                    TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Téléphone')),
                    const SizedBox(height: 12),
                    TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
                  ]),
                  if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_error!, style: const TextStyle(color: kRed, fontWeight: FontWeight.w700))),
                  FormButtons(submitLabel: editing ? 'Enregistrer' : 'Ajouter', onSubmit: _submit),
                  if (editing)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextButton.icon(
                        onPressed: () => Navigator.pop(context, ClientFormResult(deleted: true)),
                        icon: const Icon(Icons.delete_outline_rounded, color: kRed),
                        label: const Text('Supprimer le client', style: TextStyle(color: kRed, fontWeight: FontWeight.w800)),
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
    if (name.isEmpty || city.isEmpty) {
      setState(() => _error = 'Nom et ville sont obligatoires.');
      return;
    }
    final built = widget.store.build(
      id: widget.client?.id,
      name: name,
      city: city,
      category: _category.text.trim(),
      status: _status,
      address: _address.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
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

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final orders = sampleOrders.where((o) {
      if (_status != null && o.status != _status) return false;
      return q.isEmpty || o.number.toLowerCase().contains(q) || o.client.toLowerCase().contains(q);
    }).toList();
    final pending = sampleOrders.where((o) => o.status == 'pending').length;
    final validated = sampleOrders.where((o) => o.status == 'validated').length;
    final refused = sampleOrders.where((o) => o.status == 'refused').length;

    return Column(
      children: [
        AdminHeader(title: 'Commandes', onMenu: widget.onMenu, onBell: widget.onBell),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            children: [
              AdminSearchRow(controller: _search, hint: 'Rechercher une commande...', onChanged: (_) => setState(() {}), filterActive: _status != null, onFilter: _filter),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: StatTile(label: 'Total', value: '${sampleOrders.length}', color: kInk)),
                const SizedBox(width: 10),
                Expanded(child: StatTile(label: 'En attente', value: '$pending', color: kOrange)),
                const SizedBox(width: 10),
                Expanded(child: StatTile(label: 'Validées', value: '$validated', color: kGreen)),
                const SizedBox(width: 10),
                Expanded(child: StatTile(label: 'Refusées', value: '$refused', color: kRed)),
              ]),
              const SizedBox(height: 14),
              if (orders.isEmpty)
                const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: Text('Aucune commande', style: TextStyle(color: kMuted, fontWeight: FontWeight.w700)))),
              for (final o in orders) ...[_orderCard(context, o), const SizedBox(height: 12)],
            ],
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
      options: const [('Toutes', null), ('En attente', 'pending'), ('Validées', 'validated'), ('Refusées', 'refused')],
    );
    setState(() => _status = v);
  }

  Widget _orderCard(BuildContext context, AdminOrder o) {
    final (label, color) = orderStatusStyle(o.status);
    return InkWell(
      onTap: () => Navigator.push(context, phoneRoute(CommandeDetailScreen(order: o))),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: cardBox(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(o.number, style: const TextStyle(color: kInk, fontSize: 14.5, fontWeight: FontWeight.w900))),
              Text(o.date, style: const TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            Text(o.client, style: const TextStyle(color: kMuted, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(children: [
              Text('${_money(o.total)} MAD', style: const TextStyle(color: kInk, fontSize: 15, fontWeight: FontWeight.w900)),
              const Spacer(),
              StatusBadge(label: label, color: color),
            ]),
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
          AdminHeader(title: 'Détail commande', onBack: () => Navigator.pop(context)),
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
                      Row(children: [Expanded(child: Text(order.number, style: const TextStyle(color: kInk, fontSize: 17, fontWeight: FontWeight.w900))), StatusBadge(label: label, color: color)]),
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
                      const Text('Produits', style: TextStyle(color: kInk, fontSize: 14, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      const Row(children: [
                        Expanded(flex: 4, child: Text('Produit', style: TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w700))),
                        Expanded(child: Text('Qté', textAlign: TextAlign.center, style: TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w700))),
                        Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w700))),
                      ]),
                      const Divider(height: 18, color: kBorder),
                      for (final it in order.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(children: [
                            Expanded(flex: 4, child: Text(it.name, style: const TextStyle(color: kInk, fontSize: 13, fontWeight: FontWeight.w600))),
                            Expanded(child: Text('${it.qty}', textAlign: TextAlign.center, style: const TextStyle(color: kInk, fontSize: 13))),
                            Expanded(flex: 2, child: Text(_money(it.total), textAlign: TextAlign.right, style: const TextStyle(color: kInk, fontSize: 13, fontWeight: FontWeight.w700))),
                          ]),
                        ),
                      const Divider(height: 20, color: kBorder),
                      _kv('Sous-total', '${_money(order.subtotal)} MAD'),
                      if (order.discount > 0) _kv('Remise', '-${_money(order.discount)} MAD'),
                      const SizedBox(height: 6),
                      Row(children: [const Text('Total', style: TextStyle(color: kInk, fontSize: 15, fontWeight: FontWeight.w900)), const Spacer(), Text('${_money(order.total)} MAD', style: const TextStyle(color: kGreen, fontSize: 17, fontWeight: FontWeight.w900))]),
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
                      const Text('Historique', style: TextStyle(color: kInk, fontSize: 14, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Padding(padding: EdgeInsets.only(top: 4), child: Icon(Icons.circle, size: 10, color: kGreen)),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${order.date} 10:30', style: const TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('Commande créée par ${order.commercial}', style: const TextStyle(color: kInk, fontSize: 13, fontWeight: FontWeight.w700)),
                        ])),
                      ]),
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
    child: Row(children: [SizedBox(width: 92, child: Text(k, style: const TextStyle(color: kMuted, fontWeight: FontWeight.w600))), Expanded(child: Text(v, style: const TextStyle(color: kInk, fontWeight: FontWeight.w800)))]),
  );
}

// ---------------------------------------------------------------------------
// Profil
// ---------------------------------------------------------------------------

class ProfilPage extends StatelessWidget {
  const ProfilPage({super.key, required this.onMenu, required this.onBell, required this.name, required this.email, required this.phone});
  final VoidCallback onMenu;
  final VoidCallback onBell;
  final String name;
  final String email;
  final String phone;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([AppLocaleController.instance, AppAppearanceController.instance]),
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
                    child: Row(children: [
                      CircleAvatar(radius: 34, backgroundColor: kGreen.withValues(alpha: .14), child: Text(initials(name), style: const TextStyle(color: kGreen, fontSize: 22, fontWeight: FontWeight.w900))),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kInk, fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kMuted, fontSize: 13)),
                        const SizedBox(height: 4),
                        Row(children: const [Icon(Icons.circle, size: 9, color: kGreen), SizedBox(width: 5), Text('En ligne', style: TextStyle(color: kGreen, fontSize: 12, fontWeight: FontWeight.w800))]),
                      ])),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: cardBox(),
                    child: Column(children: [
                      _row(context, Icons.person_outline_rounded, 'Informations personnelles', onTap: () => Navigator.push(context, phoneRoute(PersonalInfoScreen(name: name, email: email, phone: phone)))),
                      _row(context, Icons.edit_outlined, 'Modifier profil', onTap: () => Navigator.push(context, phoneRoute(EditProfileScreen(name: name, phone: phone)))),
                      _row(context, Icons.lock_outline_rounded, 'Changer le mot de passe', onTap: () => _changePassword(context)),
                      _row(context, Icons.notifications_none_rounded, 'Notifications', onTap: () => Navigator.push(context, phoneRoute(const NotificationsSettingsScreen()))),
                      _row(context, Icons.language_rounded, 'Langue', trailing: _langName(), onTap: () => Navigator.push(context, phoneRoute(const LanguageScreen()))),
                      _row(context, Icons.dark_mode_outlined, 'Thème', trailing: _themeName(), onTap: () => Navigator.push(context, phoneRoute(const ThemeScreen()))),
                      _row(context, Icons.info_outline_rounded, 'À propos de l\'application', trailing: 'Version 1.0.0', onTap: () => Navigator.push(context, phoneRoute(const AboutScreen())), isLast: true),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: cardBox(),
                    child: _row(context, Icons.logout_rounded, 'Se déconnecter', color: kRed, isLast: true, onTap: () {
                      CurrentUserSession.signOut();
                      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
                    }),
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
    'en' => 'English',
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => Theme(data: adminInputTheme, child: const ChangePasswordSheet()),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, {String? trailing, Color color = kInk, bool isLast = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(border: Border(bottom: isLast ? BorderSide.none : const BorderSide(color: kBorder))),
        child: Row(children: [
          Icon(icon, color: color == kRed ? kRed : kInk, size: 22),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: TextStyle(color: color, fontSize: 14.5, fontWeight: FontWeight.w700))),
          if (trailing != null) Text(trailing, style: const TextStyle(color: kMuted, fontSize: 13, fontWeight: FontWeight.w600)),
          if (color != kRed) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.chevron_right_rounded, color: kMuted)),
        ]),
      ),
    );
  }
}

class PersonalInfoScreen extends StatelessWidget {
  const PersonalInfoScreen({super.key, required this.name, required this.email, required this.phone});
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
      body: Column(children: [
        AdminHeader(title: 'Informations personnelles', onBack: () => Navigator.pop(context)),
        Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
          Container(padding: const EdgeInsets.all(16), decoration: cardBox(), child: Column(children: [
            for (final r in rows) Padding(padding: const EdgeInsets.symmetric(vertical: 11), child: Row(children: [
              Expanded(child: Text(r.$1, style: const TextStyle(color: kMuted, fontWeight: FontWeight.w600))),
              Flexible(child: Text(r.$2, textAlign: TextAlign.right, style: const TextStyle(color: kInk, fontWeight: FontWeight.w800))),
            ])),
          ])),
        ])),
      ]),
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
        body: Column(children: [
          AdminHeader(title: 'Modifier profil', onBack: () => Navigator.pop(context)),
          Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
            FormSection('Profil', Icons.person_rounded, [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nom complet')),
              const SizedBox(height: 12),
              TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Téléphone')),
            ]),
            FormButtons(submitLabel: 'Enregistrer', onSubmit: () {
              Navigator.pop(context);
              _snack(context, 'Profil mis à jour');
            }),
          ])),
        ]),
      ),
    );
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
      padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Changer le mot de passe', style: TextStyle(color: kInk, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          TextField(controller: _current, obscureText: true, decoration: const InputDecoration(labelText: 'Mot de passe actuel')),
          const SizedBox(height: 12),
          TextField(controller: _new, obscureText: true, decoration: const InputDecoration(labelText: 'Nouveau mot de passe')),
          const SizedBox(height: 12),
          TextField(controller: _confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Confirmer')),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: kRed, fontWeight: FontWeight.w700))),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kGreen, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () {
                if (_new.text.length < 4) {
                  setState(() => _error = 'Le nouveau mot de passe est trop court.');
                  return;
                }
                if (_new.text != _confirm.text) {
                  setState(() => _error = 'Les mots de passe ne correspondent pas.');
                  return;
                }
                Navigator.pop(context);
                _snack(context, 'Mot de passe changé');
              },
              child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final options = [('Français', 'fr'), ('العربية', 'ar'), ('English', 'en')];
    return AnimatedBuilder(
      animation: AppLocaleController.instance,
      builder: (context, _) {
        final current = AppLocaleController.instance.languageCode;
        return Scaffold(
          backgroundColor: kBg,
          body: Column(children: [
            AdminHeader(title: 'Langue', onBack: () => Navigator.pop(context)),
            Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
              Container(decoration: cardBox(), child: Column(children: [
                for (var i = 0; i < options.length; i++)
                  _choice(options[i].$1, options[i].$2 == current, i == options.length - 1, () => AppLocaleController.instance.setLocale(Locale(options[i].$2))),
              ])),
            ])),
          ]),
        );
      },
    );
  }

  Widget _choice(String label, bool selected, bool isLast, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(border: Border(bottom: isLast ? BorderSide.none : const BorderSide(color: kBorder))),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(color: kInk, fontSize: 15, fontWeight: FontWeight.w700))),
        if (selected) const Icon(Icons.check_circle_rounded, color: kGreen),
      ]),
    ),
  );
}

class ThemeScreen extends StatelessWidget {
  const ThemeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final options = [('Clair', AppThemePreference.light), ('Sombre', AppThemePreference.dark), ('Automatique', AppThemePreference.system)];
    return AnimatedBuilder(
      animation: AppAppearanceController.instance,
      builder: (context, _) {
        final current = AppAppearanceController.instance.theme;
        return Scaffold(
          backgroundColor: kBg,
          body: Column(children: [
            AdminHeader(title: 'Thème', onBack: () => Navigator.pop(context)),
            Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
              Container(decoration: cardBox(), child: Column(children: [
                for (var i = 0; i < options.length; i++)
                  InkWell(
                    onTap: () => AppAppearanceController.instance.setTheme(options[i].$2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(border: Border(bottom: i == options.length - 1 ? BorderSide.none : const BorderSide(color: kBorder))),
                      child: Row(children: [
                        Expanded(child: Text(options[i].$1, style: const TextStyle(color: kInk, fontSize: 15, fontWeight: FontWeight.w700))),
                        if (options[i].$2 == current) const Icon(Icons.check_circle_rounded, color: kGreen),
                      ]),
                    ),
                  ),
              ])),
            ])),
          ]),
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
      body: Column(children: [
        AdminHeader(title: 'À propos', onBack: () => Navigator.pop(context)),
        Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
          Container(padding: const EdgeInsets.all(20), decoration: cardBox(), child: Column(children: [
            Container(width: 64, height: 64, decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 34)),
            const SizedBox(height: 14),
            const Text('PreSales', style: TextStyle(color: kInk, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('Version 1.0.0', style: TextStyle(color: kMuted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            const Text('Application de gestion de prévente — Ryme Distribution.', textAlign: TextAlign.center, style: TextStyle(color: kMuted, fontSize: 13, height: 1.4)),
          ])),
        ])),
      ]),
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
      (Icons.business_rounded, kBlue, 'Informations entreprise', 'Gérez les informations générales', const CompanyInfoScreen()),
      (Icons.groups_rounded, kGreen, 'Catégories clients', 'Gérez les catégories de clients', const CategoryManagerScreen(title: 'Catégories clients', kind: 'client')),
      (Icons.folder_rounded, kOrange, 'Catégories produits', 'Gérez les catégories de produits', const CategoryManagerScreen(title: 'Catégories produits', kind: 'product')),
      (Icons.notifications_rounded, kBlue, 'Notifications', 'Paramétrez les notifications', const NotificationsSettingsScreen()),
      (Icons.lock_rounded, kGreen, 'Sécurité', 'Paramètres de sécurité et accès', const SecurityScreen()),
      (Icons.receipt_long_rounded, kOrange, 'Journal d\'activité', 'Consultez les actions effectuées', const JournalPage()),
    ];
    return Scaffold(
      backgroundColor: kBg,
      body: Column(children: [
        AdminHeader(title: 'Paramètres', onBack: () => Navigator.pop(context)),
        Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
          for (final it in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => Navigator.push(context, phoneRoute(it.$5)),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: cardBox(),
                  child: Row(children: [
                    Container(width: 44, height: 44, decoration: BoxDecoration(color: it.$2.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)), child: Icon(it.$1, color: it.$2)),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(it.$3, style: const TextStyle(color: kInk, fontSize: 14.5, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(it.$4, style: const TextStyle(color: kMuted, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ])),
                    const Icon(Icons.chevron_right_rounded, color: kMuted),
                  ]),
                ),
              ),
            ),
        ])),
      ]),
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
        body: Column(children: [
          AdminHeader(title: 'Informations entreprise', onBack: () => Navigator.pop(context)),
          Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
            FormSection('Entreprise', Icons.business_rounded, [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nom de la société')),
              const SizedBox(height: 12),
              TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Téléphone')),
              const SizedBox(height: 12),
              TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 12),
              TextField(controller: _address, decoration: const InputDecoration(labelText: 'Adresse')),
            ]),
            FormButtons(submitLabel: 'Enregistrer', onSubmit: () {
              Navigator.pop(context);
              _snack(context, 'Informations enregistrées');
            }),
          ])),
        ]),
      ),
    );
  }
}

class CategoryManagerScreen extends StatefulWidget {
  const CategoryManagerScreen({super.key, required this.title, required this.kind});
  final String title;
  final String kind; // 'client' | 'product'
  @override
  State<CategoryManagerScreen> createState() => _CategoryManagerScreenState();
}

class _CategoryManagerScreenState extends State<CategoryManagerScreen> {
  late final List<String> _cats = widget.kind == 'product'
      ? MockPreSalesData.orderProducts.map((p) => p.category).toSet().toList()
      : MockPreSalesData.teaSudClients.map((c) => c.category).toSet().toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Column(children: [
        AdminHeader(title: widget.title, onBack: () => Navigator.pop(context)),
        Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
          GreenButton(label: 'Ajouter une catégorie', onPressed: _add),
          const SizedBox(height: 14),
          for (final c in _cats)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              decoration: cardBox(),
              child: Row(children: [
                Expanded(child: Text(c, style: const TextStyle(color: kInk, fontWeight: FontWeight.w700))),
                IconButton(onPressed: () => setState(() => _cats.remove(c)), icon: const Icon(Icons.delete_outline_rounded, color: kRed)),
              ]),
            ),
        ])),
      ]),
    );
  }

  Future<void> _add() async {
    final controller = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (_) => Theme(
        data: adminInputTheme,
        child: AlertDialog(
          title: const Text('Nouvelle catégorie'),
          content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Nom')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Ajouter')),
          ],
        ),
      ),
    );
    if (v != null && v.isNotEmpty) setState(() => _cats.add(v));
  }
}

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});
  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  final _values = {'Nouvelles commandes': true, 'Nouveaux clients': true, 'Rapports envoyés': true, 'Erreurs système': false, 'Sons': true};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Column(children: [
        AdminHeader(title: 'Notifications', onBack: () => Navigator.pop(context)),
        Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8), decoration: cardBox(), child: Column(children: [
            for (final k in _values.keys)
              SwitchListTile(
                title: Text(k, style: const TextStyle(color: kInk, fontWeight: FontWeight.w700)),
                value: _values[k]!,
                activeThumbColor: kGreen,
                onChanged: (v) => setState(() => _values[k] = v),
              ),
          ])),
        ])),
      ]),
    );
  }
}

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});
  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _biometric = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Column(children: [
        AdminHeader(title: 'Sécurité', onBack: () => Navigator.pop(context)),
        Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
          Container(decoration: cardBox(), child: Column(children: [
            InkWell(
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.white,
                constraints: const BoxConstraints(maxWidth: 430),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
                builder: (_) => Theme(data: adminInputTheme, child: const ChangePasswordSheet()),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
                child: Row(children: const [
                  Icon(Icons.lock_outline_rounded, color: kInk),
                  SizedBox(width: 14),
                  Expanded(child: Text('Changer le mot de passe', style: TextStyle(color: kInk, fontSize: 14.5, fontWeight: FontWeight.w700))),
                  Icon(Icons.chevron_right_rounded, color: kMuted),
                ]),
              ),
            ),
            SwitchListTile(
              title: const Text('Authentification biométrique', style: TextStyle(color: kInk, fontWeight: FontWeight.w700)),
              value: _biometric,
              activeThumbColor: kGreen,
              onChanged: (v) => setState(() => _biometric = v),
            ),
          ])),
        ])),
      ]),
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

  static const _entries = [
    (Icons.receipt_long_rounded, kBlue, '03/12/2024 10:30', 'Ahmed Benali a créé une commande', 'CMD-2024-1856'),
    (Icons.check_circle_rounded, kGreen, '03/12/2024 09:15', 'Sara El Amrani a validé la commande', 'CMD-2024-1855'),
    (Icons.storefront_rounded, kGreen, '03/12/2024 08:45', 'Nouveau client ajouté', 'Épicerie Les Oliviers'),
    (Icons.edit_rounded, kOrange, '02/12/2024 16:20', 'Youssef Essoussi a modifié un produit', 'Thé Vert 500g'),
    (Icons.login_rounded, kBlue, '02/12/2024 14:10', 'Connexion de l\'utilisateur', 'fatima.zahra@entreprise.com'),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final entries = _entries.where((e) => q.isEmpty || e.$4.toLowerCase().contains(q) || e.$5.toLowerCase().contains(q)).toList();
    return Scaffold(
      backgroundColor: kBg,
      body: Column(children: [
        AdminHeader(title: 'Journal d\'activité', onBack: () => Navigator.pop(context)),
        Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
          AdminSearchRow(controller: _search, hint: 'Rechercher dans le journal...', onChanged: (_) => setState(() {})),
          const SizedBox(height: 14),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: cardBox(),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 40, height: 40, decoration: BoxDecoration(color: e.$2.withValues(alpha: .12), borderRadius: BorderRadius.circular(11)), child: Icon(e.$1, color: e.$2, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.$3, style: const TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(e.$4, style: const TextStyle(color: kInk, fontSize: 13.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(e.$5, style: const TextStyle(color: kGreen, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ])),
                ]),
              ),
            ),
        ])),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.receipt_long_rounded, kBlue, 'Nouvelle commande', 'CMD-2024-1856 créée par Ahmed Benali', 'Il y a 5 min'),
      (Icons.storefront_rounded, kGreen, 'Nouveau client', 'Épicerie Les Oliviers ajouté', 'Il y a 1 h'),
      (Icons.warning_amber_rounded, kOrange, 'Stock faible', 'Thé Vert Premium 250g (15 restants)', 'Il y a 2 h'),
      (Icons.error_outline_rounded, kRed, 'Commande refusée', 'CMD-2024-1854 refusée', 'Hier'),
    ];
    return Scaffold(
      backgroundColor: kBg,
      body: Column(children: [
        AdminHeader(title: 'Notifications', onBack: () => Navigator.pop(context)),
        Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
          for (final n in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: cardBox(),
                child: Row(children: [
                  Container(width: 44, height: 44, decoration: BoxDecoration(color: n.$2.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)), child: Icon(n.$1, color: n.$2)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(n.$3, style: const TextStyle(color: kInk, fontSize: 14, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(n.$4, style: const TextStyle(color: kMuted, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ])),
                  Text(n.$5, style: const TextStyle(color: kMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
        ])),
      ]),
    );
  }
}
