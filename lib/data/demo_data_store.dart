/// Mutable, process-local data used by presentation builds.
///
/// The store deliberately accepts and returns JSON-shaped values because it
/// stands in for the API boundary. Every value returned to callers is copied so
/// widgets cannot accidentally mutate the shared demo state.
class DemoDataStore {
  DemoDataStore({
    required Map<String, dynamic> company,
    required List<Map<String, dynamic>> clients,
    required List<Map<String, dynamic>> recentActivities,
    required List<Map<String, dynamic>> orders,
    required List<Map<String, dynamic>> notifications,
    required List<Map<String, dynamic>> users,
    required Map<int, String> userPasswords,
    required List<Map<String, dynamic>> reports,
    required List<Map<String, dynamic>> products,
  }) : _company = _copyMap(company),
       _clients = _copyRows(clients),
       _recentActivities = _copyRows(recentActivities),
       _orders = _copyRows(orders),
       _notifications = _copyRows(notifications),
       _users = _copyRows(users),
       _userPasswords = Map<int, String>.from(userPasswords),
       _reports = _copyRows(reports),
       _products = _copyRows(products) {
    _nextClientId = _nextId(_clients, const ['id', 'client_id']);
    _nextRecentActivityId = _nextId(_recentActivities, const ['id']);
    _nextOrderId = _nextId(_orders, const ['id', 'commande_id', 'facture_id']);
    _nextNotificationId = _nextId(_notifications, const ['id']);
    _nextUserId = _nextId(_users, const ['id', 'user_id']);
    _nextReportId = _nextId(_reports, const ['id', 'rapport_id']);
    _nextProductId = _nextId(_products, const ['id', 'produit_id']);
  }

  Map<String, dynamic> _company;
  final List<Map<String, dynamic>> _clients;
  final List<Map<String, dynamic>> _recentActivities;
  final List<Map<String, dynamic>> _orders;
  final List<Map<String, dynamic>> _notifications;
  final List<Map<String, dynamic>> _users;
  final Map<int, String> _userPasswords;
  final List<Map<String, dynamic>> _reports;
  final List<Map<String, dynamic>> _products;
  late int _nextClientId;
  late int _nextRecentActivityId;
  late int _nextOrderId;
  late int _nextNotificationId;
  late int _nextUserId;
  late int _nextReportId;
  late int _nextProductId;

  Map<String, dynamic> get company => _copyMap(_company);

  Map<String, dynamic> updateCompany(Map<String, dynamic> changes) {
    _company = <String, dynamic>{..._company, ..._copyMap(changes)};
    return company;
  }

  int? commercialIdForEmail(String? email) {
    final expected = email?.trim().toLowerCase();
    if (expected == null || expected.isEmpty) return null;
    for (final user in _users) {
      if (user['email']?.toString().trim().toLowerCase() == expected) {
        return _asInt(user['id'] ?? user['user_id']);
      }
    }
    return null;
  }

  List<Map<String, dynamic>> clients({int? commercialId}) {
    return _copyRows(
      commercialId == null
          ? _clients
          : _clients.where(
              (row) =>
                  _asInt(row['commercial_id'] ?? row['id_commercial']) ==
                  commercialId,
            ),
    );
  }

  Map<String, dynamic> createClient(Map<String, dynamic> data) {
    final id = _nextClientId++;
    final row = _normalizeClient(<String, dynamic>{...data, 'id': id});
    _clients.add(row);
    return _copyMap(row);
  }

  Map<String, dynamic> updateClient(int clientId, Map<String, dynamic> data) {
    final index = _indexById(_clients, clientId, const ['id', 'client_id']);
    final merged = <String, dynamic>{
      ..._clients[index],
      ...data,
      'id': clientId,
    };
    _preferAliases(merged, data, const ['name', 'nom', 'nom_client']);
    _preferAliases(merged, data, const ['phone', 'telephone']);
    _preferAliases(merged, data, const ['city', 'ville']);
    _preferAliases(merged, data, const ['address', 'adresse']);
    _preferAliases(merged, data, const ['category', 'categorie']);
    _preferAliases(merged, data, const ['contact_name', 'responsable']);
    _preferAliases(merged, data, const ['commercial_id', 'id_commercial']);
    _preferAliases(merged, data, const ['status', 'statut', 'computed_status']);
    final row = _normalizeClient(merged);
    _clients[index] = row;
    return _copyMap(row);
  }

  Map<String, dynamic> deleteClient(int clientId) {
    _removeById(_clients, clientId, const ['id', 'client_id']);
    return {'id': clientId, 'client_id': clientId, 'deleted': true};
  }

  List<Map<String, dynamic>> recentActivities({int? commercialId}) {
    return _copyRows(
      commercialId == null
          ? _recentActivities
          : _recentActivities.where(
              (row) => _asInt(row['commercial_id']) == commercialId,
            ),
    );
  }

  Map<String, dynamic> createRecentActivity(Map<String, dynamic> data) {
    final id = _nextRecentActivityId++;
    final now = DateTime.now().toIso8601String();
    final title = _firstText(data, const ['title', 'titre']);
    final description = _firstText(data, const ['description', 'message']);
    final row = <String, dynamic>{
      ..._copyMap(data),
      'id': id,
      'title': title,
      'titre': title,
      'description': description,
      'message': description,
      'created_at': data['created_at'] ?? now,
      'date': data['date'] ?? data['created_at'] ?? now,
    };
    _recentActivities.insert(0, row);
    return _copyMap(row);
  }

  List<Map<String, dynamic>> orders({
    int? commercialId,
    int? managerId,
    String? status,
  }) {
    Iterable<Map<String, dynamic>> rows = _orders;
    if (commercialId != null) {
      rows = rows.where(
        (row) =>
            _asInt(row['commercial_id'] ?? row['id_commercial']) ==
            commercialId,
      );
    }
    if (managerId != null) {
      rows = rows.where((row) {
        final owner = _asInt(row['manager_id']);
        final rowStatus = _normalizedOrderStatus(
          row['status'] ?? row['statut'],
        );
        return owner == null || owner == managerId || rowStatus == 'pending';
      });
    }
    final expectedStatus = _normalizedOrderStatus(status);
    if (expectedStatus != null) {
      rows = rows.where(
        (row) =>
            _normalizedOrderStatus(row['status'] ?? row['statut']) ==
            expectedStatus,
      );
    }
    return _copyRows(rows);
  }

  Map<String, dynamic> order(int orderId) {
    final index = _indexById(_orders, orderId, const [
      'id',
      'commande_id',
      'facture_id',
    ]);
    return _copyMap(_orders[index]);
  }

  Map<String, dynamic> createOrder(Map<String, dynamic> data) {
    final id = _nextOrderId++;
    final row = _normalizeOrder(<String, dynamic>{...data, 'id': id});
    _orders.insert(0, row);
    _recomputeClientAggregates(row);
    return _copyMap(row);
  }

  Map<String, dynamic> updateOrderStatus(
    int orderId,
    String status, {
    String? refusalReason,
    int? managerId,
  }) {
    final index = _indexById(_orders, orderId, const [
      'id',
      'commande_id',
      'facture_id',
    ]);
    final normalized = _normalizedOrderStatus(status) ?? status;
    final history = _copyList(_orders[index]['history'] as List? ?? const []);
    history.add({
      'status': normalized,
      'manager_id': managerId,
      'created_at': DateTime.now().toIso8601String(),
    });
    final row = <String, dynamic>{
      ..._orders[index],
      'status': normalized,
      'statut': normalized,
      'history': history,
    };
    if (refusalReason != null) {
      row['refusal_reason'] = refusalReason;
      row['motif_refus'] = refusalReason;
    }
    if (managerId != null) row['manager_id'] = managerId;
    _orders[index] = row;
    _recomputeClientAggregates(row);
    return _copyMap(row);
  }

  Map<String, dynamic> addOrderComment(
    int orderId,
    String comment, {
    int? managerId,
  }) {
    final index = _indexById(_orders, orderId, const [
      'id',
      'commande_id',
      'facture_id',
    ]);
    final comments = _copyList(
      _orders[index]['manager_comments'] as List? ?? const [],
    );
    final entry = <String, dynamic>{
      'id': comments.length + 1,
      'comment': comment,
      'manager_id': managerId,
      'created_at': DateTime.now().toIso8601String(),
    };
    comments.add(entry);
    _orders[index] = <String, dynamic>{
      ..._orders[index],
      'manager_comments': comments,
      'comments_manager': comments,
      'manager_comment': comment,
    };
    return _copyMap(entry);
  }

  Map<String, dynamic> requestOrderCancellation(int orderId) {
    final index = _indexById(_orders, orderId, const [
      'id',
      'commande_id',
      'facture_id',
    ]);
    final order = _orders[index];
    if (_normalizedOrderStatus(order['status'] ?? order['statut']) !=
        'pending') {
      throw StateError('Seule une commande en attente peut etre annulee.');
    }
    final notificationId = _nextNotificationId++;
    final number = _firstText(order, const [
      'order_number',
      'numero',
      'reference',
    ]);
    final notification = <String, dynamic>{
      'id': notificationId,
      'type': 'commandes',
      'title': 'Demande d’annulation',
      'titre': 'Demande d’annulation',
      'message':
          'Annulation demandée pour ${number.isEmpty ? 'la commande #$orderId' : number}.',
      'description':
          'Annulation demandée pour ${number.isEmpty ? 'la commande #$orderId' : number}.',
      'created_at': DateTime.now().toIso8601String(),
      'read': false,
      'is_read': false,
      'commande_id': orderId,
      'commercial_id': order['commercial_id'] ?? order['id_commercial'],
      if (order['manager_id'] != null) 'manager_id': order['manager_id'],
    };
    _notifications.insert(0, notification);
    return {
      'success': true,
      'commande_id': orderId,
      'notification': _copyMap(notification),
    };
  }

  List<Map<String, dynamic>> notifications({int? managerId}) {
    // Seed notifications are intentionally global. Manager-owned notifications
    // are filtered, while global ones remain visible to every demo manager.
    return _copyRows(
      managerId == null
          ? _notifications
          : _notifications.where((row) {
              final owner = _asInt(row['manager_id']);
              return owner == null || owner == managerId;
            }),
    );
  }

  Map<String, dynamic> markNotificationRead(int notificationId) {
    final index = _indexById(_notifications, notificationId, const ['id']);
    _notifications[index] = <String, dynamic>{
      ..._notifications[index],
      'read': true,
      'is_read': true,
      'lu': true,
    };
    return _copyMap(_notifications[index]);
  }

  List<Map<String, dynamic>> markAllNotificationsRead({int? managerId}) {
    for (var index = 0; index < _notifications.length; index++) {
      final owner = _asInt(_notifications[index]['manager_id']);
      if (managerId != null && owner != null && owner != managerId) continue;
      _notifications[index] = <String, dynamic>{
        ..._notifications[index],
        'read': true,
        'is_read': true,
        'lu': true,
      };
    }
    return notifications(managerId: managerId);
  }

  Map<String, dynamic> deleteNotification(int notificationId) {
    _removeById(_notifications, notificationId, const ['id']);
    return {'id': notificationId, 'deleted': true};
  }

  List<Map<String, dynamic>> get users => _copyRows(_users);

  Map<String, dynamic> createUser(Map<String, dynamic> data) {
    final id = _nextUserId++;
    final row = _normalizeUser(<String, dynamic>{...data, 'id': id});
    final password = data['password']?.toString();
    if (password != null && password.isNotEmpty) _userPasswords[id] = password;
    _users.add(row);
    return _copyMap(row);
  }

  Map<String, dynamic> updateUser(int userId, Map<String, dynamic> data) {
    final index = _indexById(_users, userId, const ['id', 'user_id']);
    final merged = <String, dynamic>{..._users[index], ...data, 'id': userId};
    _preferAliases(merged, data, const ['name', 'full_name']);
    _preferAliases(merged, data, const ['phone', 'telephone']);
    _preferAliases(merged, data, const ['role', 'type']);
    _preferAliases(merged, data, const ['is_active', 'active', 'actif']);
    final row = _normalizeUser(merged);
    final password = data['password']?.toString();
    if (password != null && password.isNotEmpty) {
      _userPasswords[userId] = password;
    }
    _users[index] = row;
    return _copyMap(row);
  }

  Map<String, dynamic> deleteUser(int userId) {
    _removeById(_users, userId, const ['id', 'user_id']);
    _userPasswords.remove(userId);
    return {'id': userId, 'user_id': userId, 'deleted': true};
  }

  Map<String, dynamic> changePassword(
    int userId,
    String currentPassword,
    String newPassword,
  ) {
    _indexById(_users, userId, const ['id', 'user_id']);
    final existing = _userPasswords[userId];
    if (existing != null && existing != currentPassword) {
      throw StateError('Mot de passe actuel incorrect');
    }
    _userPasswords[userId] = newPassword;
    return {'id': userId, 'user_id': userId, 'password_changed': true};
  }

  Map<String, dynamic> updateUserPreferences(
    int userId,
    Map<String, dynamic> preferences,
  ) {
    final index = _indexById(_users, userId, const ['id', 'user_id']);
    final previous = _users[index]['preferences'];
    final merged = <String, dynamic>{
      if (previous is Map) ...previous.cast<String, dynamic>(),
      ..._copyMap(preferences),
    };
    _users[index] = <String, dynamic>{
      ..._users[index],
      ..._copyMap(preferences),
      'preferences': merged,
    };
    return _copyMap(_users[index]);
  }

  Map<String, dynamic>? authenticate(String email, String password) {
    final expected = email.trim().toLowerCase();
    for (final user in _users) {
      if (user['email']?.toString().trim().toLowerCase() != expected) continue;
      final id = _asInt(user['id'] ?? user['user_id']);
      final active = _asBool(
        user['is_active'] ?? user['active'] ?? user['actif'],
      );
      if (!active || id == null || _userPasswords[id] != password) return null;
      return _copyMap(user);
    }
    return null;
  }

  List<Map<String, dynamic>> get reports => _copyRows(_reports);

  Map<String, dynamic> createReport(Map<String, dynamic> data) {
    final id = _nextReportId++;
    final now = DateTime.now().toIso8601String();
    final row = <String, dynamic>{
      ..._copyMap(data),
      'id': id,
      'rapport_id': id,
      'created_by': data['created_by'] ?? data['commercial_id'],
      'commercial': data['commercial'] ?? data['commercial_name'],
      'date': data['date'] ?? data['report_date'] ?? now,
      'created_at': data['created_at'] ?? now,
      'sent_at': data['sent_at'] ?? now,
      'is_read': false,
      'read': false,
      'activities_count': data['activities_count'] ?? data['activites'] ?? 0,
      'activites': data['activites'] ?? data['activities_count'] ?? 0,
      'clients_count': data['clients_count'] ?? data['clients_visited'] ?? 0,
      'orders_count': data['orders_count'] ?? data['commandes'] ?? 0,
      'commandes': data['commandes'] ?? data['orders_count'] ?? 0,
      'manager_comment': data['manager_comment'] ?? '',
    };
    _reports.insert(0, row);
    return _copyMap(row);
  }

  Map<String, dynamic> markReportRead(int reportId) {
    final index = _indexById(_reports, reportId, const ['id', 'rapport_id']);
    _reports[index] = <String, dynamic>{
      ..._reports[index],
      'is_read': true,
      'read': true,
      'lu': true,
    };
    return _copyMap(_reports[index]);
  }

  Map<String, dynamic> addReportComment(
    int reportId,
    String comment, {
    int? managerId,
  }) {
    final index = _indexById(_reports, reportId, const ['id', 'rapport_id']);
    final comments = _copyList(
      _reports[index]['manager_comments'] as List? ?? const [],
    );
    final entry = <String, dynamic>{
      'id': comments.length + 1,
      'comment': comment,
      'manager_id': managerId,
      'created_at': DateTime.now().toIso8601String(),
    };
    comments.add(entry);
    _reports[index] = <String, dynamic>{
      ..._reports[index],
      'manager_comment': comment,
      'commentaire_manager': comment,
      'manager_comments': comments,
    };
    return _copyMap(entry);
  }

  List<Map<String, dynamic>> get products => _copyRows(_products);

  Map<String, dynamic> createProduct(Map<String, dynamic> data) {
    final id = _nextProductId++;
    final row = _normalizeProduct(<String, dynamic>{...data, 'id': id});
    _products.add(row);
    return _copyMap(row);
  }

  Map<String, dynamic> updateProduct(int productId, Map<String, dynamic> data) {
    final index = _indexById(_products, productId, const ['id', 'produit_id']);
    final merged = <String, dynamic>{
      ..._products[index],
      ...data,
      'id': productId,
    };
    _preferAliases(merged, data, const ['name', 'nom_produit', 'nom']);
    _preferAliases(merged, data, const ['category', 'categorie']);
    _preferAliases(merged, data, const ['image', 'photo']);
    _preferAliases(merged, data, const [
      'price',
      'prix',
      'prix_vente',
      'unit_price',
    ]);
    _preferAliases(merged, data, const ['stock', 'quantite_stock']);
    _preferAliases(merged, data, const ['status', 'statut']);
    final row = _normalizeProduct(merged);
    _products[index] = row;
    return _copyMap(row);
  }

  Map<String, dynamic> deleteProduct(int productId) {
    _removeById(_products, productId, const ['id', 'produit_id']);
    return {'id': productId, 'produit_id': productId, 'deleted': true};
  }

  void _recomputeClientAggregates(Map<String, dynamic> changedOrder) {
    final changedClientId = _asInt(changedOrder['client_id']);
    final changedClientName = _firstText(changedOrder, const [
      'client_name',
      'client',
    ]).trim().toLowerCase();
    final clientIndex = _clients.indexWhere((client) {
      final clientId = _asInt(client['id'] ?? client['client_id']);
      if (changedClientId != null && clientId != null) {
        return clientId == changedClientId;
      }
      final name = _firstText(client, const [
        'name',
        'nom',
      ]).trim().toLowerCase();
      return changedClientName.isNotEmpty && name == changedClientName;
    });
    if (clientIndex < 0) return;

    final client = _clients[clientIndex];
    final clientId = _asInt(client['id'] ?? client['client_id']);
    final clientName = _firstText(client, const [
      'name',
      'nom',
    ]).trim().toLowerCase();
    final relatedOrders = _orders.where((order) {
      final orderClientId = _asInt(order['client_id']);
      if (clientId != null && orderClientId != null) {
        return clientId == orderClientId;
      }
      final orderClientName = _firstText(order, const [
        'client_name',
        'client',
      ]).trim().toLowerCase();
      return clientName.isNotEmpty && orderClientName == clientName;
    }).toList();
    final validatedOrders = relatedOrders.where(
      (order) =>
          _normalizedOrderStatus(order['status'] ?? order['statut']) ==
          'validated',
    );
    final validatedRevenue = validatedOrders.fold<double>(
      0,
      (sum, order) =>
          sum +
          _asDouble(
            order['total'] ?? order['total_amount'] ?? order['montant_total'],
          ),
    );
    String latestDate = '-';
    DateTime? latest;
    for (final order in relatedOrders) {
      final raw = order['date'] ?? order['created_at'];
      final parsed = DateTime.tryParse(raw?.toString() ?? '');
      if (parsed != null && (latest == null || parsed.isAfter(latest))) {
        latest = parsed;
        latestDate = raw.toString();
      } else if (latest == null && raw != null) {
        latestDate = raw.toString();
      }
    }
    final explicitStatus = _firstText(client, const [
      'status',
      'statut',
    ]).trim().toLowerCase();
    final inactive =
        explicitStatus.contains('inact') ||
        explicitStatus.contains('desactiv') ||
        explicitStatus == 'disabled';
    _clients[clientIndex] = <String, dynamic>{
      ...client,
      'orders_count': relatedOrders.length,
      'validated_orders_count': validatedOrders.length,
      'ca_total': validatedRevenue,
      'computed_last_order_date': latestDate,
      'computed_status': inactive
          ? 'inactive'
          : validatedOrders.isNotEmpty
          ? 'visited'
          : 'toVisit',
    };
  }

  static void _preferAliases(
    Map<String, dynamic> merged,
    Map<String, dynamic> patch,
    List<String> aliases,
  ) {
    for (final alias in aliases) {
      if (!patch.containsKey(alias)) continue;
      final value = patch[alias];
      for (final target in aliases) {
        merged[target] = value;
      }
      return;
    }
  }

  static Map<String, dynamic> _normalizeClient(Map<String, dynamic> data) {
    final row = _copyMap(data);
    final id = _asInt(row['id'] ?? row['client_id'])!;
    final name = _firstText(row, const ['name', 'nom', 'nom_client']);
    final phone = _firstText(row, const ['phone', 'telephone']);
    final city = _firstText(row, const ['city', 'ville']);
    final address = _firstText(row, const ['address', 'adresse']);
    final category = _firstText(row, const [
      'category',
      'categorie',
      'business_type',
    ]);
    final businessType = _firstText(row, const [
      'business_type',
      'category',
      'categorie',
    ]);
    final contact = _firstText(row, const ['contact_name', 'responsable']);
    final commercialId = _asInt(row['commercial_id'] ?? row['id_commercial']);
    final status = _firstText(row, const [
      'status',
      'statut',
      'computed_status',
    ]);
    return <String, dynamic>{
      ...row,
      'id': id,
      'client_id': id,
      'name': name,
      'nom': name,
      'phone': phone,
      'telephone': phone,
      'city': city,
      'ville': city,
      'address': address,
      'adresse': address,
      'category': category,
      'categorie': category,
      'business_type': businessType,
      'contact_name': contact,
      'responsable': contact,
      'commercial_id': commercialId,
      'id_commercial': commercialId,
      'status': status.isEmpty ? 'toVisit' : status,
      'statut': status.isEmpty ? 'toVisit' : status,
      'computed_status': status.isEmpty ? 'toVisit' : status,
      'orders_count': row['orders_count'] ?? 0,
      'ca_total': row['ca_total'] ?? 0,
      'computed_last_order_date': row['computed_last_order_date'] ?? '-',
    };
  }

  static Map<String, dynamic> _normalizeOrder(Map<String, dynamic> data) {
    final row = _copyMap(data);
    final id = _asInt(row['id'] ?? row['commande_id'] ?? row['facture_id'])!;
    final status =
        _normalizedOrderStatus(row['status'] ?? row['statut']) ?? 'pending';
    final rawItems = row['items'] ?? row['lines'] ?? row['lignes'] ?? const [];
    final items = rawItems is List ? _copyList(rawItems) : <dynamic>[];
    final total =
        row['total'] ?? row['total_amount'] ?? row['montant_total'] ?? 0;
    final number = _firstText(row, const [
      'order_number',
      'numero',
      'reference',
    ]);
    final client = _firstText(row, const ['client_name', 'client']);
    return <String, dynamic>{
      ...row,
      'id': id,
      'commande_id': id,
      'facture_id': id,
      'order_number': number.isEmpty ? 'CMD-DEMO-$id' : number,
      'numero': number.isEmpty ? 'CMD-DEMO-$id' : number,
      'reference': number.isEmpty ? 'CMD-DEMO-$id' : number,
      'client_name': client,
      'client': client,
      'id_commercial': row['commercial_id'] ?? row['id_commercial'],
      'status': status,
      'statut': status,
      'total': total,
      'total_amount': total,
      'montant_total': total,
      'amount': total,
      'items': items,
      'lines': items,
      'products_count': row['products_count'] ?? items.length,
      'items_count': row['items_count'] ?? items.length,
      'created_at':
          row['created_at'] ?? row['date'] ?? DateTime.now().toIso8601String(),
      'date':
          row['date'] ?? row['created_at'] ?? DateTime.now().toIso8601String(),
    };
  }

  static Map<String, dynamic> _normalizeUser(Map<String, dynamic> data) {
    final row = _copyMap(data)..remove('password');
    final id = _asInt(row['id'] ?? row['user_id'])!;
    var name = _firstText(row, const ['name', 'full_name']);
    if (name.isEmpty) {
      name = '${row['prenom'] ?? ''} ${row['nom'] ?? ''}'.trim();
    }
    final phone = _firstText(row, const ['phone', 'telephone']);
    final role = _firstText(row, const ['role', 'type']);
    final active = _asBool(row['is_active'] ?? row['active'] ?? row['actif']);
    return <String, dynamic>{
      ...row,
      'id': id,
      'user_id': id,
      'name': name,
      'full_name': name,
      'phone': phone,
      'telephone': phone,
      'role': role,
      'type': role,
      'is_active': active,
      'status': active ? 'active' : 'inactive',
    };
  }

  static Map<String, dynamic> _normalizeProduct(Map<String, dynamic> data) {
    final row = _copyMap(data);
    final id = _asInt(row['id'] ?? row['produit_id'])!;
    final name = _firstText(row, const ['name', 'nom_produit', 'nom']);
    final category = _firstText(row, const ['category', 'categorie']);
    final image = _firstText(row, const ['image', 'photo']);
    final price =
        row['price'] ??
        row['prix'] ??
        row['prix_vente'] ??
        row['unit_price'] ??
        0;
    final stock = row['stock'] ?? row['quantite_stock'] ?? 0;
    return <String, dynamic>{
      ...row,
      'id': id,
      'produit_id': id,
      'name': name,
      'nom_produit': name,
      'category': category,
      'categorie': category,
      'image': image,
      'photo': image,
      'price': price,
      'prix': price,
      'prix_vente': price,
      'unit_price': price,
      'stock': stock,
      'quantite_stock': stock,
      'status': row['status'] ?? row['statut'] ?? 'actif',
      'statut': row['statut'] ?? row['status'] ?? 'actif',
    };
  }

  static String? _normalizedOrderStatus(Object? raw) {
    if (raw == null) return null;
    final value = raw.toString().trim().toLowerCase();
    if (value.isEmpty || value == 'all') return null;
    if (value.contains('valid') ||
        value.contains('livr') ||
        value == 'synced') {
      return 'validated';
    }
    if (value.contains('refus') ||
        value.contains('reject') ||
        value.contains('annul') ||
        value.contains('cancel')) {
      return 'refused';
    }
    if (value.contains('attente') || value.contains('pending'))
      return 'pending';
    return value;
  }

  static int _nextId(Iterable<Map<String, dynamic>> rows, List<String> keys) {
    var maximum = 0;
    for (final row in rows) {
      for (final key in keys) {
        final id = _asInt(row[key]);
        if (id != null && id > maximum) maximum = id;
      }
    }
    return maximum + 1;
  }

  static int _indexById(
    List<Map<String, dynamic>> rows,
    int id,
    List<String> keys,
  ) {
    final index = rows.indexWhere(
      (row) => keys.any((key) => _asInt(row[key]) == id),
    );
    if (index < 0) throw StateError('Demo record $id not found');
    return index;
  }

  static void _removeById(
    List<Map<String, dynamic>> rows,
    int id,
    List<String> keys,
  ) {
    final index = _indexById(rows, id, keys);
    rows.removeAt(index);
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _asBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return true;
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'active' ||
        normalized == 'actif';
  }

  static String _firstText(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return '';
  }

  static List<Map<String, dynamic>> _copyRows(
    Iterable<Map<String, dynamic>> rows,
  ) => rows.map(_copyMap).toList();

  static Map<String, dynamic> _copyMap(Map<String, dynamic> source) {
    return source.map((key, value) => MapEntry(key, _copyValue(value)));
  }

  static List<dynamic> _copyList(List<dynamic> source) =>
      source.map(_copyValue).toList();

  static dynamic _copyValue(dynamic value) {
    if (value is Map<String, dynamic>) return _copyMap(value);
    if (value is Map) {
      return value.map(
        (key, nested) => MapEntry(key.toString(), _copyValue(nested)),
      );
    }
    if (value is List) return _copyList(value);
    return value;
  }
}
