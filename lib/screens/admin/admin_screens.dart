import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../data/mock_presales_data.dart';

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

String _roleToDb(MockUserRole role) => role.name.toLowerCase();

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

String _jsonString(Map<dynamic, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString().trim();
    }
  }
  return '';
}

int _jsonInt(Map<dynamic, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return 0;
}

double _jsonDouble(Map<dynamic, dynamic> json, List<String> keys) {
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

bool _jsonBool(
  Map<dynamic, dynamic> json,
  List<String> keys, {
  bool fallback = true,
}) {
  for (final key in keys) {
    final value = json[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase();
    if (text == 'true' || text == '1' || text == 'actif') return true;
    if (text == 'false' || text == '0' || text == 'inactif') return false;
  }
  return fallback;
}

extension _AdminStringFallback on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
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
                      textAlign: onBack != null
                          ? TextAlign.center
                          : TextAlign.left,
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
    return IconButton(
      onPressed: onTap,
      icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
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
                  const Center(
                    child: Icon(Icons.tune_rounded, color: Colors.white),
                  ),
                  if (filterActive)
                    const Positioned(
                      right: 8,
                      top: 8,
                      child: CircleAvatar(
                        radius: 4,
                        backgroundColor: Colors.white,
                      ),
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
            Text(
              title,
              style: const TextStyle(
                color: kInk,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            for (final o in options)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  o.$1,
                  style: const TextStyle(
                    color: kInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: o.$2 == current
                    ? const Icon(Icons.check_rounded, color: kGreen)
                    : null,
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
  AdminUserStore();

  final List<MockUserProfile> _users = [];

  List<MockUserProfile> get all => List.unmodifiable(_users);

  Future<void> load() async {
    final rows = await ApiService.getUsers();
    _users
      ..clear()
      ..addAll(rows.whereType<Map>().map((row) => userFromApi(row)));
  }

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

MockUserProfile userFromApi(Map<dynamic, dynamic> row) {
  final email = _jsonString(row, ['email']);
  final first = _jsonString(row, ['prenom', 'first_name']);
  final last = _jsonString(row, ['nom', 'last_name']);
  final fullName = _jsonString(row, ['name', 'full_name']).isNotEmpty
      ? _jsonString(row, ['name', 'full_name'])
      : '$first $last'.trim();
  return MockUserProfile(
    id: _jsonInt(row, ['id', 'user_id']),
    name: fullName.isEmpty ? email : fullName,
    email: email,
    phone: _jsonString(row, ['phone', 'telephone']),
    password: _jsonString(row, ['password']),
    role: roleFromDb(_jsonString(row, ['role', 'type'])),
    isActive: _jsonBool(row, ['is_active', 'active', 'actif']),
  );
}

Map<String, dynamic> userToApi(MockUserProfile u) {
  final (prenom, nom) = splitName(u.name);
  return {
    'name': u.name,
    'prenom': prenom,
    'nom': nom,
    'email': u.email,
    'phone': u.phone,
    'password': u.password,
    'role': _roleToDb(u.role),
    'is_active': u.isActive,
  };
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

Future<int> dbInsertUser(MockUserProfile u) async {
  final row = await ApiService.createUser(userToApi(u));
  return _jsonInt(row, ['id', 'user_id']);
}

Future<void> dbUpdateUser(int storeId, MockUserProfile u) async {
  await ApiService.updateUser(storeId, userToApi(u));
}

Future<void> dbDeleteUser(int storeId) async {
  await ApiService.deleteUser(storeId);
}

Future<void> dbSetUserPassword(int storeId, String password) async {
  await ApiService.updateUser(storeId, {'password': password});
}

// ---------------------------------------------------------------------------
// PostgreSQL order view model.
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

(String, Color) orderStatusStyle(String status) => switch (status) {
  'validated' => ('Validée', kGreen),
  'refused' => ('Refusée', kRed),
  _ => ('En attente', kOrange),
};

// ---------------------------------------------------------------------------
// Product store (PostgreSQL-backed through Flask API).
// ---------------------------------------------------------------------------

class ProductStore {
  final List<OrderProduct> _items = [];

  List<OrderProduct> get all => List.unmodifiable(_items);
  List<String> get categories => _items.map((p) => p.category).toSet().toList();

  Future<void> load() async {
    final rows = await ApiService.getProduits();
    _items
      ..clear()
      ..addAll(rows.whereType<Map>().map(_fromRow));
  }

  Map<String, dynamic> _toRow(OrderProduct p) => {
    'nom_produit': p.name,
    'name': p.name,
    'reference': p.reference,
    'categorie': p.category,
    'category': p.category,
    'prix': p.unitPrice,
    'price': p.unitPrice,
    'prix_vente': p.unitPrice,
    'unit_price': p.unitPrice,
    'stock': p.stock,
    'quantite_stock': p.stock,
    'image': p.image,
    'photo': p.image,
    'description': p.description,
    'status': 'actif',
    'statut': 'actif',
  };

  OrderProduct _fromRow(Map<dynamic, dynamic> r) => OrderProduct(
    id: _jsonInt(r, ['id', 'produit_id']),
    name: _jsonString(r, ['nom_produit', 'name', 'nom']).ifEmpty('Produit'),
    reference: _jsonString(r, ['reference', 'ref']),
    category: _jsonString(r, [
      'categorie',
      'category',
      'nom_cat',
    ]).ifEmpty('Divers'),
    description: _jsonString(r, ['description']),
    image: _jsonString(r, ['image', 'photo', 'product_image']),
    unitPrice: _jsonDouble(r, ['prix', 'price', 'unit_price', 'prix_vente']),
    stock: _jsonInt(r, ['stock', 'quantite_stock', 'quantity']),
    icon: Icons.local_cafe_rounded,
    imageColor: kGreen,
  );

  OrderProduct build({
    int? id,
    required String name,
    required String reference,
    required String category,
    String description = '',
    String image = '',
    required double price,
    required int stock,
  }) => OrderProduct(
    id: id ?? 0,
    name: name,
    reference: reference,
    category: category.isEmpty ? 'Divers' : category,
    description: description,
    image: image,
    unitPrice: price,
    stock: stock,
    icon: Icons.local_cafe_rounded,
    imageColor: kGreen,
  );

  Future<void> add(OrderProduct p) async {
    final row = await ApiService.createProduit(_toRow(p));
    _items.add(_fromRow(row));
  }

  Future<void> update(OrderProduct p) async {
    final row = await ApiService.updateProduit(p.id, _toRow(p));
    final i = _items.indexWhere((x) => x.id == p.id);
    if (i >= 0) _items[i] = _fromRow(row);
  }

  Future<void> remove(int id) async {
    await ApiService.deleteProduit(id);
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
// Client store (PostgreSQL-backed through Flask API).
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
    final rows = await ApiService.getClients();
    _items
      ..clear()
      ..addAll(rows.whereType<Map>().map(_fromRow));
  }

  Map<String, dynamic> _toRow(CommercialClient c) => {
    'name': c.name,
    'nom': c.name,
    'email': c.email,
    'city': c.city,
    'ville': c.city,
    'category': c.businessType,
    'business_type': c.businessType,
    'contact_name': c.contactName,
    'quartier': c.quartier,
    'notes': c.notes,
    'latitude': c.latitude,
    'longitude': c.longitude,
    'commercial_id': c.commercialId == 0 ? null : c.commercialId,
    'status': c.status.name,
    'address': c.address,
    'phone': c.phone,
  };

  CommercialClient _fromRow(Map<dynamic, dynamic> r) {
    final name = _jsonString(r, [
      'name',
      'nom',
      'nom_client',
    ]).ifEmpty('Client');
    return CommercialClient(
      id: _jsonInt(r, ['id', 'client_id']),
      name: name,
      city: _jsonString(r, ['city', 'ville']),
      commercialId: _jsonInt(r, [
        'commercial_id',
        'id_commercial',
        'user_id',
        'created_by',
      ]),
      businessType: _jsonString(r, [
        'business_type',
        'category',
        'categorie',
      ]).ifEmpty('Autre'),
      category: _jsonString(r, [
        'category',
        'business_type',
        'categorie',
      ]).ifEmpty('Commerce general'),
      status: _statusFromName(
        _jsonString(r, ['computed_status', 'status', 'statut']),
      ),
      initials: initials(name),
      phone: _jsonString(r, ['phone', 'telephone']),
      email: _jsonString(r, ['email']),
      address: _jsonString(r, ['address', 'adresse']),
      contactName: _jsonString(r, ['contact_name', 'responsable']),
      quartier: _jsonString(r, ['quartier', 'district']),
      notes: _jsonString(r, ['notes', 'commentaire', 'comments']),
      latitude: _jsonDouble(r, ['latitude', 'lat']),
      longitude: _jsonDouble(r, ['longitude', 'lng']),
      creditLimit: 0,
      discount: 0,
      balance: 0,
      lastOrderDate: _jsonString(r, [
        'computed_last_order_date',
        'last_order_date',
      ]).ifEmpty('-'),
      risk: ClientRisk.low,
      orders: _clientOrdersFromStats(r),
      documents: const [],
    );
  }

  ClientStatus _statusFromName(String s) => ClientStatus.values.firstWhere(
    (v) => v.name == s,
    orElse: () => ClientStatus.visited,
  );

  CommercialClient build({
    int? id,
    required String name,
    required String city,
    required String category,
    required ClientStatus status,
    int commercialId = 0,
    String businessType = 'Autre',
    String address = '',
    String phone = '',
    String email = '',
    String contactName = '',
    String quartier = '',
    String notes = '',
    double latitude = 33.5731,
    double longitude = -7.5898,
  }) {
    return CommercialClient(
      id: id ?? 0,
      commercialId: commercialId,
      name: name,
      city: city,
      businessType: businessType,
      category: category.isEmpty ? 'Commerce general' : category,
      status: status,
      initials: initials(name),
      phone: phone,
      email: email,
      address: address,
      contactName: contactName,
      quartier: quartier,
      notes: notes,
      latitude: latitude,
      longitude: longitude,
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
    final row = await ApiService.createClient(_toRow(c));
    _items.add(_fromRow(row));
  }

  Future<void> update(CommercialClient c) async {
    final row = await ApiService.updateClient(c.id, _toRow(c));
    final i = _items.indexWhere((x) => x.id == c.id);
    if (i >= 0) _items[i] = _fromRow(row);
  }

  Future<void> remove(int id) async {
    await ApiService.deleteClient(id);
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

List<ClientOrder> _clientOrdersFromStats(Map<dynamic, dynamic> row) {
  final count = _jsonInt(row, ['orders_count', 'commandes_count']);
  if (count <= 0) return const [];
  final revenue = _jsonDouble(row, ['ca_total', 'revenue', 'total_ca']);
  final date = _jsonString(row, [
    'computed_last_order_date',
    'last_order_date',
  ]).ifEmpty('-');
  return List<ClientOrder>.generate(
    count,
    (index) => ClientOrder(
      reference: 'CMD-${index + 1}',
      date: date,
      amount: index == 0 ? revenue : 0,
    ),
  );
}
