import 'package:flutter/material.dart';

import '../../data/mock_presales_data.dart';
import '../../database/database_helper.dart';

// Admin design kit — colors + shared widgets matching the reference mockup
// (emerald green primary, dark navy rounded headers, white cards).

const kGreen = Color(0xFF1B7F4B);
const kHeader = Color(0xFF0E1B2A);
const kBg = Color(0xFFF4F6F9);
const kInk = Color(0xFF0F172A);
const kMuted = Color(0xFF7A8699);
const kBorder = Color(0xFFE9EEF4);
const kOrange = Color(0xFFF59E0B);
const kRed = Color(0xFFEF4444);
const kBlue = Color(0xFF2563EB);

// App is light-only; force light theme on inputs so dark-mode OS doesn't hide text.
final ThemeData adminInputTheme = ThemeData(
  useMaterial3: false,
  brightness: Brightness.light,
  fontFamily: 'Roboto',
  primaryColor: kGreen,
  scaffoldBackgroundColor: kBg,
  colorScheme: const ColorScheme.light(primary: kGreen),
);

BoxDecoration cardBox() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: kBorder),
  boxShadow: [
    BoxShadow(
      color: kInk.withValues(alpha: .04),
      blurRadius: 14,
      offset: const Offset(0, 6),
    ),
  ],
);

String roleLabel(MockUserRole role) => switch (role) {
  MockUserRole.commercial => 'Commercial',
  MockUserRole.manager => 'Manager',
  MockUserRole.admin => 'Administrateur',
};

String _roleToDb(MockUserRole role) => role.name.toUpperCase();

MockUserRole roleFromDb(String? value) => switch (value?.toUpperCase()) {
  'ADMIN' => MockUserRole.admin,
  'MANAGER' => MockUserRole.manager,
  _ => MockUserRole.commercial,
};

(String, String) splitName(String full) {
  final parts = full.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return ('', '');
  return (parts.first, parts.skip(1).join(' '));
}

String initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

/// Dark navy header with rounded bottom corners (hamburger · title · bell).
class AdminHeader extends StatelessWidget {
  const AdminHeader({
    super.key,
    required this.title,
    this.onMenu,
    this.onBack,
    this.onBell,
    this.greeting,
    this.subtitle,
  });

  final String title;
  final VoidCallback? onMenu;
  final VoidCallback? onBack;
  final VoidCallback? onBell;
  final String? greeting;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kHeader,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 20),
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (onBack != null)
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              )
            else if (onMenu != null)
              IconButton(
                onPressed: onMenu,
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
              )
            else
              const SizedBox(width: 12),
            Expanded(
              child: greeting != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .75),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    )
                  : Text(
                      title,
                      textAlign: onBack != null ? TextAlign.center : TextAlign.left,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            _BellButton(onTap: onBell),
          ],
        ),
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onTap,
          icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
        ),
        Positioned(
          right: 6,
          top: 6,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: kRed, shape: BoxShape.circle),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            child: const Text(
              '8',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Search field + green filter button row.
class AdminSearchRow extends StatelessWidget {
  const AdminSearchRow({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.onFilter,
    this.filterActive = false,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onFilter;
  final bool filterActive;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: const TextStyle(color: kInk, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: kMuted),
              prefixIcon: const Icon(Icons.search_rounded, color: kMuted),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kGreen),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: kGreen,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onFilter,
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 50,
              height: 50,
              child: Stack(
                children: [
                  const Center(child: Icon(Icons.tune_rounded, color: Colors.white)),
                  if (filterActive)
                    const Positioned(
                      right: 8,
                      top: 8,
                      child: CircleAvatar(radius: 4, backgroundColor: Colors.white),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Generic bottom-sheet single-choice filter. Returns the chosen value (or
/// null to clear). Used by the green filter button on list pages.
Future<T?> showFilterSheet<T>(
  BuildContext context, {
  required String title,
  required List<(String, T?)> options,
  required T? current,
}) {
  return showModalBottomSheet<T?>(
    context: context,
    backgroundColor: Colors.white,
    constraints: const BoxConstraints(maxWidth: 430),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: kInk, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            for (final o in options)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(o.$1, style: const TextStyle(color: kInk, fontWeight: FontWeight.w700)),
                trailing: o.$2 == current ? const Icon(Icons.check_rounded, color: kGreen) : null,
                onTap: () => Navigator.pop(context, o.$2),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Small KPI tile: label on top, big colored value.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: cardBox(),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// Full-width green action button "+ label".
class GreenButton extends StatelessWidget {
  const GreenButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.add_rounded,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: kGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// User store (in-memory list + sqflite persistence for created accounts)
// ---------------------------------------------------------------------------

class AdminUserStore {
  AdminUserStore() : _users = [...MockPreSalesData.users.values];

  final List<MockUserProfile> _users;

  static const int dbBase = 100000;
  static bool isDbUser(int id) => id >= dbBase;

  List<MockUserProfile> get all => List.unmodifiable(_users);

  void upsert(MockUserProfile user) {
    final i = _users.indexWhere((u) => u.id == user.id);
    if (i >= 0) {
      _users[i] = user;
    } else {
      _users.add(user);
    }
  }

  void remove(int id) => _users.removeWhere((u) => u.id == id);

  void setActive(int id, bool active) {
    final i = _users.indexWhere((u) => u.id == id);
    if (i >= 0) _users[i] = copyUser(_users[i], isActive: active);
  }

  void resetPassword(int id) {
    final i = _users.indexWhere((u) => u.id == id);
    if (i >= 0) _users[i] = copyUser(_users[i], password: '123456');
  }

  List<MockUserProfile> filter({
    String query = '',
    MockUserRole? role,
    bool? active,
  }) {
    final q = query.trim().toLowerCase();
    return _users.where((u) {
      if (role != null && u.role != role) return false;
      if (active != null && u.isActive != active) return false;
      if (q.isEmpty) return true;
      return u.name.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q);
    }).toList();
  }
}

MockUserProfile copyUser(
  MockUserProfile u, {
  int? id,
  String? name,
  String? email,
  String? phone,
  MockUserRole? role,
  String? password,
  bool? isActive,
}) {
  return MockUserProfile(
    id: id ?? u.id,
    name: name ?? u.name,
    email: email ?? u.email,
    phone: phone ?? u.phone,
    password: password ?? u.password,
    role: role ?? u.role,
    isActive: isActive ?? u.isActive,
  );
}

/// Shared async DB helpers for the Utilisateurs CRUD (used by HomeAdmin).
Future<void> loadDbUsers(AdminUserStore store) async {
  final rows = await DatabaseHelper.instance.getAll('users');
  final mockEmails = MockPreSalesData.users.keys.toSet();
  for (final r in rows) {
    final email = (r['email'] ?? '').toString();
    if (mockEmails.contains(email.toLowerCase())) continue;
    final rawId = r['id'];
    final id = rawId is int ? rawId : int.tryParse('$rawId') ?? 0;
    final name = '${r['prenom'] ?? ''} ${r['nom'] ?? ''}'.trim();
    store.upsert(
      MockUserProfile(
        id: AdminUserStore.dbBase + id,
        name: name.isEmpty ? email : name,
        email: email,
        phone: '',
        password: (r['password'] ?? '').toString(),
        role: roleFromDb(r['role']?.toString()),
      ),
    );
  }
}

Future<int> dbInsertUser(MockUserProfile u) async {
  final (prenom, nom) = splitName(u.name);
  return DatabaseHelper.instance.insert('users', {
    'nom': nom,
    'prenom': prenom,
    'email': u.email,
    'password': u.password,
    'role': _roleToDb(u.role),
  });
}

Future<void> dbUpdateUser(int storeId, MockUserProfile u) async {
  final (prenom, nom) = splitName(u.name);
  final db = await DatabaseHelper.instance.database;
  await db.update(
    'users',
    {
      'nom': nom,
      'prenom': prenom,
      'email': u.email,
      'password': u.password,
      'role': _roleToDb(u.role),
    },
    where: 'id = ?',
    whereArgs: [storeId - AdminUserStore.dbBase],
  );
}

Future<void> dbDeleteUser(int storeId) async {
  final db = await DatabaseHelper.instance.database;
  await db.delete(
    'users',
    where: 'id = ?',
    whereArgs: [storeId - AdminUserStore.dbBase],
  );
}

Future<void> dbSetUserPassword(int storeId, String password) async {
  final db = await DatabaseHelper.instance.database;
  await db.update(
    'users',
    {'password': password},
    where: 'id = ?',
    whereArgs: [storeId - AdminUserStore.dbBase],
  );
}

// ---------------------------------------------------------------------------
// Sample orders (mock orders table is empty — seed a few for display)
// ponytail: display-only seed; swap for real orders when the DB has them.
// ---------------------------------------------------------------------------

class AdminOrder {
  const AdminOrder({
    required this.number,
    required this.client,
    required this.commercial,
    required this.date,
    required this.total,
    required this.subtotal,
    required this.discount,
    required this.status,
    required this.items,
  });

  final String number;
  final String client;
  final String commercial;
  final String date;
  final double total;
  final double subtotal;
  final double discount;
  final String status; // pending | validated | refused
  final List<AdminOrderItem> items;
}

class AdminOrderItem {
  const AdminOrderItem(this.name, this.qty, this.unit, this.total);
  final String name;
  final int qty;
  final double unit;
  final double total;
}

const sampleOrders = <AdminOrder>[
  AdminOrder(
    number: 'CMD-2024-1856',
    client: 'Épicerie Al Amal',
    commercial: 'Ahmed Benali',
    date: '03/12/2024',
    total: 1250,
    subtotal: 1400,
    discount: 150,
    status: 'pending',
    items: [
      AdminOrderItem('Thé Vert 250g', 10, 25, 250),
      AdminOrderItem('Thé Vert 500g', 20, 40, 800),
      AdminOrderItem('Thé Vert 1kg', 5, 70, 350),
    ],
  ),
  AdminOrder(
    number: 'CMD-2024-1855',
    client: 'Supermarché Marjane',
    commercial: 'Sara El Amrani',
    date: '03/12/2024',
    total: 3450,
    subtotal: 3450,
    discount: 0,
    status: 'validated',
    items: [AdminOrderItem('Thé Vert Premium 250g', 115, 30, 3450)],
  ),
  AdminOrder(
    number: 'CMD-2024-1854',
    client: 'Bazar du Centre',
    commercial: 'Mehdi Alaoui',
    date: '02/12/2024',
    total: 850,
    subtotal: 850,
    discount: 0,
    status: 'refused',
    items: [AdminOrderItem('Thé Vert 500g', 21, 40, 840)],
  ),
  AdminOrder(
    number: 'CMD-2024-1853',
    client: 'Épicerie Les Oliviers',
    commercial: 'Ahmed Benali',
    date: '02/12/2024',
    total: 1780,
    subtotal: 1780,
    discount: 0,
    status: 'validated',
    items: [AdminOrderItem('Thé Vert 1kg', 25, 70, 1750)],
  ),
];

(String, Color) orderStatusStyle(String status) => switch (status) {
  'validated' => ('Validée', kGreen),
  'refused' => ('Refusée', kRed),
  _ => ('En attente', kOrange),
};

// ---------------------------------------------------------------------------
// Product store (sqflite-backed; seeded once from the mock catalogue)
// ponytail: icon/color aren't persisted — every product uses the tea default.
// ---------------------------------------------------------------------------

class ProductStore {
  final List<OrderProduct> _items = [];

  List<OrderProduct> get all => List.unmodifiable(_items);
  List<String> get categories => _items.map((p) => p.category).toSet().toList();

  Future<void> load() async {
    final db = await DatabaseHelper.instance.database;
    var rows = await db.query('produits');
    if (rows.isEmpty) {
      for (final p in MockPreSalesData.orderProducts) {
        await db.insert('produits', _toRow(p));
      }
      rows = await db.query('produits');
    }
    _items
      ..clear()
      ..addAll(rows.map(_fromRow));
  }

  Map<String, Object?> _toRow(OrderProduct p) => {
    'nom_produit': p.name,
    'reference': p.reference,
    'categorie': p.category,
    'prix': p.unitPrice,
    'stock': p.stock,
  };

  OrderProduct _fromRow(Map<String, Object?> r) => OrderProduct(
    id: (r['id'] as num).toInt(),
    name: (r['nom_produit'] ?? '').toString(),
    reference: (r['reference'] ?? '').toString(),
    category: (r['categorie'] ?? 'Divers').toString(),
    unitPrice: (r['prix'] as num?)?.toDouble() ?? 0,
    stock: (r['stock'] as num?)?.toInt() ?? 0,
    icon: Icons.local_cafe_rounded,
    imageColor: kGreen,
  );

  OrderProduct build({
    int? id,
    required String name,
    required String reference,
    required String category,
    required double price,
    required int stock,
  }) => OrderProduct(
    id: id ?? 0,
    name: name,
    reference: reference,
    category: category.isEmpty ? 'Divers' : category,
    unitPrice: price,
    stock: stock,
    icon: Icons.local_cafe_rounded,
    imageColor: kGreen,
  );

  Future<void> add(OrderProduct p) async {
    final db = await DatabaseHelper.instance.database;
    final id = await db.insert('produits', _toRow(p));
    _items.add(_fromRow({..._toRow(p), 'id': id}));
  }

  Future<void> update(OrderProduct p) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('produits', _toRow(p), where: 'id = ?', whereArgs: [p.id]);
    final i = _items.indexWhere((x) => x.id == p.id);
    if (i >= 0) _items[i] = p;
  }

  Future<void> remove(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('produits', where: 'id = ?', whereArgs: [id]);
    _items.removeWhere((p) => p.id == id);
  }

  List<OrderProduct> filter({String query = '', String? category}) {
    final q = query.trim().toLowerCase();
    return _items.where((p) {
      if (category != null && p.category != category) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.reference.toLowerCase().contains(q);
    }).toList();
  }
}

// ---------------------------------------------------------------------------
// Client store (mutable in-memory; seeded from mock clients)
// ---------------------------------------------------------------------------

(String, Color) clientStatusStyle(ClientStatus s) => switch (s) {
  ClientStatus.visited => ('Actif', kGreen),
  ClientStatus.toVisit => ('Prospect', kOrange),
  ClientStatus.inactive => ('Inactif', kRed),
};

class ClientStore {
  final List<CommercialClient> _items = [];

  List<CommercialClient> get all => List.unmodifiable(_items);
  int count(ClientStatus s) => _items.where((c) => c.status == s).length;

  Future<void> load() async {
    final db = await DatabaseHelper.instance.database;
    var rows = await db.query('clients');
    if (rows.isEmpty) {
      for (final c in MockPreSalesData.teaSudClients) {
        await db.insert('clients', _toRow(c));
      }
      rows = await db.query('clients');
    }
    _items
      ..clear()
      ..addAll(rows.map(_fromRow));
  }

  Map<String, Object?> _toRow(CommercialClient c) => {
    'nom_client': c.name,
    'email': c.email,
    'ville': c.city,
    'categorie': c.category,
    'statut': c.status.name,
    'adresse': c.address,
    'telephone': c.phone,
  };

  CommercialClient _fromRow(Map<String, Object?> r) {
    final name = (r['nom_client'] ?? '').toString();
    return CommercialClient(
      id: (r['id'] as num).toInt(),
      name: name,
      city: (r['ville'] ?? '').toString(),
      category: (r['categorie'] ?? 'Commerce général').toString(),
      status: _statusFromName((r['statut'] ?? '').toString()),
      initials: initials(name),
      phone: (r['telephone'] ?? '').toString(),
      email: (r['email'] ?? '').toString(),
      address: (r['adresse'] ?? '').toString(),
      creditLimit: 0,
      discount: 0,
      balance: 0,
      lastOrderDate: '-',
      risk: ClientRisk.low,
      orders: const [],
      documents: const [],
    );
  }

  ClientStatus _statusFromName(String s) => ClientStatus.values
      .firstWhere((v) => v.name == s, orElse: () => ClientStatus.visited);

  CommercialClient build({
    int? id,
    required String name,
    required String city,
    required String category,
    required ClientStatus status,
    String address = '',
    String phone = '',
    String email = '',
  }) {
    return CommercialClient(
      id: id ?? 0,
      name: name,
      city: city,
      category: category.isEmpty ? 'Commerce général' : category,
      status: status,
      initials: initials(name),
      phone: phone,
      email: email,
      address: address,
      creditLimit: 0,
      discount: 0,
      balance: 0,
      lastOrderDate: '-',
      risk: ClientRisk.low,
      orders: const [],
      documents: const [],
    );
  }

  Future<void> add(CommercialClient c) async {
    final db = await DatabaseHelper.instance.database;
    final id = await db.insert('clients', _toRow(c));
    _items.add(_fromRow({..._toRow(c), 'id': id}));
  }

  Future<void> update(CommercialClient c) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('clients', _toRow(c), where: 'id = ?', whereArgs: [c.id]);
    final i = _items.indexWhere((x) => x.id == c.id);
    if (i >= 0) _items[i] = c;
  }

  Future<void> remove(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('clients', where: 'id = ?', whereArgs: [id]);
    _items.removeWhere((c) => c.id == id);
  }

  List<CommercialClient> filter({String query = '', ClientStatus? status}) {
    final q = query.trim().toLowerCase();
    return _items.where((c) {
      if (status != null && c.status != status) return false;
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          c.city.toLowerCase().contains(q);
    }).toList();
  }
}
