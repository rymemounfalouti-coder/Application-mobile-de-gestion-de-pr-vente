import 'dart:convert';
import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;

import 'data/demo_data_store.dart';
import 'data/mock_presales_data.dart';

/// Thrown by [ApiService.login] when the server rejects the credentials (401),
/// as distinct from a network/server failure. Lets the UI show "wrong password"
/// instead of a generic connection error.
class InvalidCredentialsException implements Exception {
  const InvalidCredentialsException();
}

class ApiService {
  // 127.0.0.1 works for web and iOS simulators, but the Android emulator only
  // reaches the host machine's loopback via 10.0.2.2. For a physical device,
  // pass --dart-define=API_BASE_URL=http://<your-PC-LAN-IP>:5000.
  static final String baseUrl = _resolveBaseUrl();

  static String _resolveBaseUrl() {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000';
    }
    return 'http://127.0.0.1:5000';
  }

  static const bool demoModeEnabled = bool.fromEnvironment(
    'DEMO_MODE',
    defaultValue: false,
  );
  static String? _accessToken;
  static void Function()? _onUnauthorized;

  static bool get hasAuthenticatedSession =>
      _accessToken != null && _accessToken!.isNotEmpty;

  static void setUnauthorizedHandler(void Function()? handler) {
    _onUnauthorized = handler;
  }

  static void clearAccessToken() {
    _accessToken = null;
  }

  static Map<String, String> _authorizedHeaders(Map<String, String>? headers) {
    final merged = <String, String>{...?headers};
    final token = _accessToken;
    if (token != null && token.isNotEmpty) {
      merged['Authorization'] = 'Bearer $token';
    }
    return merged;
  }

  static Future<http.Response> _handleResponse(
    Future<http.Response> request,
  ) async {
    final response = await request;
    if (response.statusCode == 401 && _accessToken != null) {
      _accessToken = null;
      _onUnauthorized?.call();
    }
    return response;
  }

  static Future<http.Response> _get(Uri url, {Map<String, String>? headers}) =>
      _handleResponse(http.get(url, headers: _authorizedHeaders(headers)));

  static Future<http.Response> _post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => _handleResponse(
    http.post(
      url,
      headers: _authorizedHeaders(headers),
      body: body,
      encoding: encoding,
    ),
  );

  static Future<http.Response> _put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => _handleResponse(
    http.put(
      url,
      headers: _authorizedHeaders(headers),
      body: body,
      encoding: encoding,
    ),
  );

  static Future<http.Response> _patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => _handleResponse(
    http.patch(
      url,
      headers: _authorizedHeaders(headers),
      body: body,
      encoding: encoding,
    ),
  );

  static Future<http.Response> _delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => _handleResponse(
    http.delete(
      url,
      headers: _authorizedHeaders(headers),
      body: body,
      encoding: encoding,
    ),
  );
  // Demo data is intentionally opt-in. Production and normal development builds
  // must authenticate against the JWT-protected backend.
  static bool get _useMockData => demoModeEnabled;

  static DemoDataStore? _demoData;

  static DemoDataStore get _demoStore => _demoData ??= DemoDataStore(
    company: _mockCompanyInfo(),
    clients: _mockClients(),
    recentActivities: _mockRecentActivities(),
    orders: _mockOrders(),
    notifications: _mockNotifications(),
    users: _mockUsers(),
    userPasswords: {
      for (final user in MockPreSalesData.users.values) user.id: user.password,
    },
    reports: _mockReports(),
    products: _mockProducts(),
  );

  /// Clears mutations between focused tests. Presentation builds never call it.
  static void resetDemoDataForTesting() {
    _demoData = null;
    clearAccessToken();
  }

  static int? _demoCommercialId(int? id, String? email) {
    if (id != null && id > 0) return id;
    if (email == null || email.trim().isEmpty) return null;
    // Demo IDs are positive. A non-null sentinel preserves the distinction
    // between "no filter" and "an unknown commercial email".
    return _demoStore.commercialIdForEmail(email) ?? -1;
  }

  static void _requireDemoFallback(String resource) {
    if (!_useMockData) {
      throw StateError('Backend request failed for $resource.');
    }
  }

  static Future<Map<String, dynamic>> getCompanyInfo() async {
    if (_useMockData) return _demoStore.company;

    try {
      final response = await _get(Uri.parse('$baseUrl/company-info'));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      }
    } catch (_) {
      if (!_useMockData) rethrow;
    }
    _requireDemoFallback('company information');
    return _mockCompanyInfo();
  }

  static Future<Map<String, dynamic>> updateCompanyInfo(
    Map<String, dynamic> data,
  ) async {
    if (_useMockData) return _demoStore.updateCompany(data);

    final response = await _put(
      Uri.parse('$baseUrl/company-info'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(data),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    }
    final body = utf8.decode(response.bodyBytes);
    final decoded = body.isEmpty ? null : jsonDecode(body);
    if (decoded is Map && decoded['error'] != null) {
      throw Exception(decoded['error'].toString());
    }
    throw Exception(
      body.isEmpty
          ? 'Impossible de mettre à jour les informations entreprise.'
          : body,
    );
  }

  static Future<List<dynamic>> getClients({
    int? commercialId,
    String? commercialEmail,
  }) async {
    if (_useMockData) {
      return _demoStore.clients(
        commercialId: _demoCommercialId(commercialId, commercialEmail),
      );
    }

    try {
      final query = <String, String>{};
      if (commercialId != null && commercialId > 0) {
        query['commercial_id'] = '$commercialId';
      }
      if (commercialEmail != null && commercialEmail.isNotEmpty) {
        query['commercial_email'] = commercialEmail;
      }
      final uri = Uri.parse(
        '$baseUrl/clients',
      ).replace(queryParameters: query.isEmpty ? null : query);
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final rows = decoded is List
            ? decoded
            : decoded['data'] as List<dynamic>? ?? [];
        debugPrint(
          '[COMMERCIAL][CLIENTS][GET] commercial_id=$commercialId '
          'email=$commercialEmail count=${rows.length}',
        );
        return rows;
      }
    } catch (_) {
      // Fall through to demo data below.
    }
    _requireDemoFallback('clients');
    return _mockClients(
      commercialId: commercialId,
      commercialEmail: commercialEmail,
    );
  }

  static Future<Map<String, dynamic>> createClient(
    Map<String, dynamic> data,
  ) async {
    debugPrint(
      '[COMMERCIAL][CLIENTS][POST] name=${data['name']} '
      'commercial_id=${data['commercial_id']} status=${data['status']}',
    );
    if (_useMockData) return _demoStore.createClient(data);

    final response = await _post(
      Uri.parse('$baseUrl/clients'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(data),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }
    throw Exception(
      'Erreur création client: ${utf8.decode(response.bodyBytes)}',
    );
  }

  static Future<List<dynamic>> getCommercialRecentActivities({
    int? commercialId,
    String? commercialEmail,
  }) async {
    if (_useMockData) {
      return _demoStore.recentActivities(
        commercialId: _demoCommercialId(commercialId, commercialEmail),
      );
    }

    try {
      final query = <String, String>{};
      if (commercialId != null && commercialId > 0) {
        query['commercial_id'] = '$commercialId';
      }
      if (commercialEmail != null && commercialEmail.isNotEmpty) {
        query['commercial_email'] = commercialEmail;
      }
      final uri = Uri.parse(
        '$baseUrl/commercial/activites-recentes',
      ).replace(queryParameters: query.isEmpty ? null : query);
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final rows = decoded is List
            ? decoded
            : decoded['data'] as List<dynamic>? ?? [];
        debugPrint(
          '[COMMERCIAL][ACTIVITES_RECENTES][GET] commercial_id=$commercialId '
          'email=$commercialEmail count=${rows.length}',
        );
        return rows;
      }
    } catch (_) {
      // Fall through to demo data below.
    }
    _requireDemoFallback('recent activities');
    return _mockRecentActivities(
      commercialId: commercialId,
      commercialEmail: commercialEmail,
    );
  }

  static Future<Map<String, dynamic>> createCommercialRecentActivity(
    Map<String, dynamic> data,
  ) async {
    if (_useMockData) return _demoStore.createRecentActivity(data);

    final response = await _post(
      Uri.parse('$baseUrl/commercial/activites-recentes'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }
    throw Exception('Erreur creation activite recente: ${response.body}');
  }

  static Future<List<dynamic>> getFactures() async {
    if (_useMockData) return _demoStore.orders();

    try {
      final response = await _get(Uri.parse('$baseUrl/factures'));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded is List
            ? decoded
            : decoded['data'] as List<dynamic>? ?? [];
      }
    } catch (_) {
      // Fall through to demo data below.
    }
    _requireDemoFallback('orders');
    return _mockOrders();
  }

  static Future<Map<String, dynamic>> createCommande(
    Map<String, dynamic> data,
  ) async {
    debugPrint(
      '[COMMANDES][POST] payload status=${data['status']} '
      'commercial_id=${data['commercial_id']} manager_id=${data['manager_id']}',
    );
    if (_useMockData) return _demoStore.createOrder(data);

    final response = await _post(
      Uri.parse('$baseUrl/commandes'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        debugPrint(
          '[COMMANDES][POST] created id=${decoded['id']} '
          'status=${decoded['status'] ?? decoded['statut']} '
          'commercial_id=${decoded['commercial_id'] ?? decoded['id_commercial']} '
          'manager_id=${decoded['manager_id']}',
        );
      }
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }
    throw Exception('Erreur creation commande: ${response.body}');
  }

  static Future<List<dynamic>> getManagerCommandes({
    int? managerId,
    String? status,
  }) async {
    if (_useMockData) {
      return _demoStore.orders(managerId: managerId, status: status);
    }

    try {
      final query = <String, String>{};
      if (managerId != null) query['manager_id'] = '$managerId';
      if (status != null && status.isNotEmpty) query['status'] = status;
      final uri = Uri.parse(
        '$baseUrl/manager/commandes',
      ).replace(queryParameters: query.isEmpty ? null : query);
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final rows = decoded is List
            ? decoded
            : decoded['data'] as List<dynamic>? ?? [];
        debugPrint(
          '[MANAGER][COMMANDES][GET] manager_id=$managerId status=$status '
          'count=${rows.length}',
        );
        return rows;
      }
    } catch (_) {
      // Fall through to demo data below.
    }
    _requireDemoFallback('manager orders');
    return _mockOrdersByStatus(status);
  }

  static Future<List<dynamic>> getCommercialCommandes({
    int? commercialId,
    String? commercialEmail,
  }) async {
    if (_useMockData) {
      return _demoStore.orders(
        commercialId: _demoCommercialId(commercialId, commercialEmail),
      );
    }

    try {
      final query = <String, String>{};
      if (commercialId != null && commercialId > 0) {
        query['commercial_id'] = '$commercialId';
      }
      if (commercialEmail != null && commercialEmail.isNotEmpty) {
        query['commercial_email'] = commercialEmail;
      }
      final uri = Uri.parse(
        '$baseUrl/commandes',
      ).replace(queryParameters: query.isEmpty ? null : query);
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final rows = decoded is List
            ? decoded
            : decoded['data'] as List<dynamic>? ?? [];
        debugPrint(
          '[COMMERCIAL][COMMANDES][GET] commercial_id=$commercialId '
          'email=$commercialEmail count=${rows.length}',
        );
        return rows;
      }
    } catch (_) {
      // Fall through to demo data below.
    }
    _requireDemoFallback('commercial orders');
    return _mockOrders(
      commercialId: commercialId,
      commercialEmail: commercialEmail,
    );
  }

  static Future<List<dynamic>> getNotifications({int? managerId}) async {
    if (_useMockData) {
      return _demoStore.notifications(managerId: managerId);
    }

    try {
      final uri = managerId == null
          ? Uri.parse('$baseUrl/notifications')
          : Uri.parse('$baseUrl/notifications?manager_id=$managerId');
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final rows = decoded is List
            ? decoded
            : decoded['data'] as List<dynamic>? ?? [];
        debugPrint(
          '[MANAGER][NOTIFICATIONS][GET] manager_id=$managerId count=${rows.length}',
        );
        return rows;
      }
    } catch (_) {
      // Fall through to demo data below.
    }
    _requireDemoFallback('notifications');
    return _mockNotifications();
  }

  static Future<Map<String, dynamic>> markNotificationRead(
    int notificationId,
  ) async {
    if (_useMockData) {
      return _demoStore.markNotificationRead(notificationId);
    }

    final response = await _patch(
      Uri.parse('$baseUrl/notifications/$notificationId/read'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }
    throw Exception('Erreur lecture notification');
  }

  static Future<List<dynamic>> markAllNotificationsRead({
    int? managerId,
  }) async {
    if (_useMockData) {
      return _demoStore.markAllNotificationsRead(managerId: managerId);
    }

    final uri = managerId == null
        ? Uri.parse('$baseUrl/notifications/read-all')
        : Uri.parse('$baseUrl/notifications/read-all?manager_id=$managerId');
    final response = await _patch(
      uri,
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      return decoded is List
          ? decoded
          : decoded['data'] as List<dynamic>? ?? [];
    }
    throw Exception('Erreur lecture notifications');
  }

  static Future<Map<String, dynamic>> deleteNotification(
    int notificationId,
  ) async {
    if (_useMockData) return _demoStore.deleteNotification(notificationId);

    final response = await _delete(
      Uri.parse('$baseUrl/notifications/$notificationId'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }
    throw Exception('Erreur suppression notification');
  }

  static Future<Map<String, dynamic>> getCommande(int commandeId) async {
    if (_useMockData) return _demoStore.order(commandeId);

    try {
      final commandeResponse = await _get(
        Uri.parse('$baseUrl/commandes/$commandeId'),
      );
      if (commandeResponse.statusCode == 200) {
        final decoded = jsonDecode(commandeResponse.body);
        if (decoded is Map<String, dynamic>) {
          return decoded['data'] is Map<String, dynamic>
              ? decoded['data'] as Map<String, dynamic>
              : decoded;
        }
        return {'data': decoded};
      }

      final factureResponse = await _get(
        Uri.parse('$baseUrl/factures/$commandeId'),
      );
      if (factureResponse.statusCode == 200) {
        final decoded = jsonDecode(factureResponse.body);
        if (decoded is Map<String, dynamic>) {
          return decoded['data'] is Map<String, dynamic>
              ? decoded['data'] as Map<String, dynamic>
              : decoded;
        }
        return {'data': decoded};
      }
    } catch (_) {
      // Fall through to demo data below.
    }
    _requireDemoFallback('order details');
    return _mockCommandeById(commandeId);
  }

  static Future<Map<String, dynamic>> updateCommandeStatus(
    int commandeId,
    String status, {
    String? refusalReason,
    int? managerId,
  }) async {
    if (_useMockData) {
      return _demoStore.updateOrderStatus(
        commandeId,
        status,
        refusalReason: refusalReason,
        managerId: managerId,
      );
    }

    final body = <String, dynamic>{'status': status};
    if (refusalReason != null) body['refusal_reason'] = refusalReason;
    if (managerId != null) body['manager_id'] = managerId;

    final response = await _patch(
      Uri.parse('$baseUrl/commandes/$commandeId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }

    return updateFactureStatus(
      commandeId,
      status,
      refusalReason: refusalReason,
      managerId: managerId,
    );
  }

  static Future<Map<String, dynamic>> addCommandeComment(
    int commandeId,
    String comment, {
    int? managerId,
  }) async {
    if (_useMockData) {
      return _demoStore.addOrderComment(
        commandeId,
        comment,
        managerId: managerId,
      );
    }

    final body = <String, dynamic>{'comment': comment};
    if (managerId != null) body['manager_id'] = managerId;

    final response = await _post(
      Uri.parse('$baseUrl/commandes/$commandeId/comments'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }
    throw Exception('Erreur commentaire commande');
  }

  static Future<Map<String, dynamic>> requestCommandeCancellation(
    int commandeId,
  ) async {
    if (_useMockData) {
      return _demoStore.requestOrderCancellation(commandeId);
    }

    final response = await _post(
      Uri.parse('$baseUrl/commandes/$commandeId/cancel-request'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.bodyBytes.isEmpty) {
        return {'success': true, 'commande_id': commandeId};
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic>
          ? decoded
          : {'data': decoded, 'commande_id': commandeId};
    }
    throw Exception(
      'Erreur demande annulation commande: ${utf8.decode(response.bodyBytes)}',
    );
  }

  static Future<Map<String, dynamic>> updateFactureStatus(
    int factureId,
    String status, {
    String? refusalReason,
    int? managerId,
  }) async {
    if (_useMockData) {
      return _demoStore.updateOrderStatus(
        factureId,
        status,
        refusalReason: refusalReason,
        managerId: managerId,
      );
    }

    final body = <String, dynamic>{'status': status};
    if (refusalReason != null) body['refusal_reason'] = refusalReason;
    if (managerId != null) body['manager_id'] = managerId;

    final response = await _patch(
      Uri.parse('$baseUrl/factures/$factureId/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }
    throw Exception('Erreur mise a jour statut facture');
  }

  static Future<List<dynamic>> getUsers() async {
    if (_useMockData) return _demoStore.users;

    try {
      final response = await _get(Uri.parse('$baseUrl/users'));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return decoded is List
            ? decoded
            : decoded['data'] as List<dynamic>? ?? [];
      }
    } catch (_) {
      // Fall through to demo data below.
    }
    _requireDemoFallback('users');
    return _mockUsers();
  }

  static Future<Map<String, dynamic>> createUser(
    Map<String, dynamic> data,
  ) async {
    if (_useMockData) return _demoStore.createUser(data);

    final response = await _post(
      Uri.parse('$baseUrl/users'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(data),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }
    throw Exception(
      'Erreur création utilisateur: ${utf8.decode(response.bodyBytes)}',
    );
  }

  static Future<Map<String, dynamic>> updateUser(
    int userId,
    Map<String, dynamic> data,
  ) async {
    if (_useMockData) return _demoStore.updateUser(userId, data);

    final response = await _patch(
      Uri.parse('$baseUrl/users/$userId'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(data),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }
    throw Exception(
      'Erreur mise à jour utilisateur: ${utf8.decode(response.bodyBytes)}',
    );
  }

  static Future<Map<String, dynamic>> deleteUser(int userId) async {
    if (_useMockData) return _demoStore.deleteUser(userId);

    final response = await _delete(
      Uri.parse('$baseUrl/users/$userId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }
    throw Exception('Erreur suppression utilisateur');
  }

  static Future<Map<String, dynamic>> changePassword(
    int userId,
    String currentPassword,
    String newPassword,
  ) async {
    if (_useMockData) {
      return _demoStore.changePassword(userId, currentPassword, newPassword);
    }

    final response = await _post(
      Uri.parse('$baseUrl/users/$userId/change-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }
    throw Exception('Erreur modification mot de passe');
  }

  static Future<Map<String, dynamic>> updateUserPreferences(
    int userId,
    Map<String, dynamic> preferences,
  ) async {
    if (_useMockData) {
      return _demoStore.updateUserPreferences(userId, preferences);
    }

    final response = await _patch(
      Uri.parse('$baseUrl/users/$userId/preferences'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(preferences),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }
    throw Exception('Erreur mise a jour preferences');
  }

  static Future<List<dynamic>> getRapports() async {
    if (_useMockData) return _demoStore.reports;

    try {
      final response = await _get(Uri.parse('$baseUrl/rapports'));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded is List
            ? decoded
            : decoded['data'] as List<dynamic>? ?? [];
      }
    } catch (_) {
      // Fall through to demo data below.
    }
    _requireDemoFallback('reports');
    return _mockReports();
  }

  static Future<Map<String, dynamic>> createRapport(
    Map<String, dynamic> data,
  ) async {
    if (_useMockData) return _demoStore.createReport(data);

    final response = await _post(
      Uri.parse('$baseUrl/rapports'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }
    throw Exception('Erreur envoi rapport: ${response.body}');
  }

  static Future<Map<String, dynamic>> markRapportRead(int rapportId) async {
    if (_useMockData) return _demoStore.markReportRead(rapportId);

    final response = await _patch(
      Uri.parse('$baseUrl/rapports/$rapportId/read'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }
    throw Exception('Erreur lecture rapport');
  }

  static Future<Map<String, dynamic>> addRapportComment(
    int rapportId,
    String comment, {
    int? managerId,
  }) async {
    if (_useMockData) {
      return _demoStore.addReportComment(
        rapportId,
        comment,
        managerId: managerId,
      );
    }

    final body = <String, dynamic>{'comment': comment};
    if (managerId != null) body['manager_id'] = managerId;
    final response = await _post(
      Uri.parse('$baseUrl/rapports/$rapportId/comments'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }
    throw Exception('Erreur commentaire rapport');
  }

  static Future<List<dynamic>> getProduits() async {
    if (_useMockData) return _demoStore.products;

    try {
      final response = await _get(Uri.parse('$baseUrl/produits'));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return decoded is List
            ? decoded
            : decoded['data'] as List<dynamic>? ?? [];
      }
    } catch (_) {
      // Fall through to demo data below.
    }
    _requireDemoFallback('products');
    return _mockProducts();
  }

  static Future<Map<String, dynamic>> createProduit(
    Map<String, dynamic> data,
  ) async {
    if (_useMockData) return _demoStore.createProduct(data);

    final response = await _post(
      Uri.parse('$baseUrl/produits'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(data),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }
    throw Exception(
      'Erreur création produit: ${utf8.decode(response.bodyBytes)}',
    );
  }

  static Future<Map<String, dynamic>> updateProduit(
    int produitId,
    Map<String, dynamic> data,
  ) async {
    if (_useMockData) return _demoStore.updateProduct(produitId, data);

    final response = await _patch(
      Uri.parse('$baseUrl/produits/$produitId'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(data),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }
    throw Exception(
      'Erreur mise à jour produit: ${utf8.decode(response.bodyBytes)}',
    );
  }

  static Future<Map<String, dynamic>> deleteProduit(int produitId) async {
    if (_useMockData) return _demoStore.deleteProduct(produitId);

    final response = await _delete(
      Uri.parse('$baseUrl/produits/$produitId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }
    throw Exception('Erreur suppression produit');
  }

  static Future<Map<String, dynamic>> updateClient(
    int clientId,
    Map<String, dynamic> data,
  ) async {
    if (_useMockData) return _demoStore.updateClient(clientId, data);

    final response = await _patch(
      Uri.parse('$baseUrl/clients/$clientId'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(data),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }
    throw Exception(
      'Erreur mise à jour client: ${utf8.decode(response.bodyBytes)}',
    );
  }

  static Future<Map<String, dynamic>> deleteClient(int clientId) async {
    if (_useMockData) return _demoStore.deleteClient(clientId);

    final response = await _delete(
      Uri.parse('$baseUrl/clients/$clientId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }
    throw Exception('Erreur suppression client');
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    clearAccessToken();
    if (_useMockData) {
      final user = _demoStore.authenticate(email, password);
      if (user != null) return user;
      throw Exception('Email ou mot de passe incorrect');
    }

    final response = await _post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Réponse d’authentification invalide');
      }
      final token = decoded['access_token']?.toString() ?? '';
      if (token.isEmpty) {
        throw Exception('Jeton d’authentification manquant');
      }
      _accessToken = token;
      return decoded;
    } else if (response.statusCode == 401) {
      throw const InvalidCredentialsException();
    } else {
      throw Exception(
        'Connexion au serveur impossible (${response.statusCode})',
      );
    }
  }

  static Map<String, dynamic> _mockCompanyInfo() {
    return {
      'name': 'TeaSud',
      'raison_sociale': 'TeaSud Distribution',
      'email': 'contact@teasud.ma',
      'phone': '0522 00 00 00',
      'address': 'Casablanca, Maroc',
      'ice': '002345678000045',
    };
  }

  static List<Map<String, dynamic>> _mockUsers() {
    return MockPreSalesData.users.values.map((user) {
      final city = user.role == MockUserRole.manager
          ? 'Casablanca'
          : user.role == MockUserRole.admin
          ? 'Siege'
          : 'Casablanca';
      return {
        'id': user.id,
        'user_id': user.id,
        'name': user.name,
        'full_name': user.name,
        'email': user.email,
        'phone': user.phone,
        'telephone': user.phone,
        'role': user.role.name,
        'type': user.role.name,
        'is_active': user.isActive,
        'status': user.isActive ? 'active' : 'inactive',
        'city': city,
        'ville': city,
        'address': 'Casablanca',
        'matricule': user.role == MockUserRole.commercial
            ? 'COM-${user.id.toString().padLeft(3, '0')}'
            : 'USR-${user.id.toString().padLeft(3, '0')}',
        'created_at': _isoDaysAgo(user.id),
      };
    }).toList();
  }

  static List<Map<String, dynamic>> _mockClients({
    int? commercialId,
    String? commercialEmail,
  }) {
    final id = _commercialIdFor(commercialId, commercialEmail);
    final clients = id == null
        ? MockPreSalesData.commercialClients.values.expand((rows) => rows)
        : MockPreSalesData.commercialClients[id] ?? const <CommercialClient>[];
    final unique = <int, CommercialClient>{};
    for (final client in clients) {
      unique[client.id] = client;
    }
    return unique.values.map((client) {
      final orders = MockPreSalesData.commercialOrders.values
          .expand((rows) => rows)
          .where((order) => order.clientName == client.name)
          .toList();
      return {
        'id': client.id,
        'client_id': client.id,
        'name': client.name,
        'nom': client.name,
        'client_code': client.clientCode,
        'code_client': client.clientCode,
        'email': client.email,
        'phone': client.phone,
        'telephone': client.phone,
        'city': client.city,
        'ville': client.city,
        'address': client.address,
        'adresse': client.address,
        'business_type': client.businessType,
        'category': client.category,
        'categorie': client.category,
        'contact_name': client.contactName,
        'responsable': client.contactName,
        'commercial_id': client.commercialId,
        'id_commercial': client.commercialId,
        'status': client.status.name,
        'statut': client.status.name,
        'computed_status': client.status.name,
        'latitude': client.latitude,
        'longitude': client.longitude,
        'orders_count': orders.length,
        'ca_total': orders.fold<double>(0, (sum, order) => sum + order.total),
        'computed_last_order_date': orders.isEmpty ? '-' : orders.first.date,
      };
    }).toList();
  }

  static List<Map<String, dynamic>> _mockProducts() {
    return MockPreSalesData.orderProducts.map((product) {
      return {
        'id': product.id,
        'produit_id': product.id,
        'name': product.name,
        'nom_produit': product.name,
        'reference': product.reference,
        'category': product.category,
        'categorie': product.category,
        'description': product.description,
        'image': product.image,
        'photo': product.image,
        'price': product.unitPrice,
        'prix': product.unitPrice,
        'prix_vente': product.unitPrice,
        'unit_price': product.unitPrice,
        'stock': product.stock,
        'quantite_stock': product.stock,
        'status': 'actif',
      };
    }).toList();
  }

  static List<Map<String, dynamic>> _mockOrders({
    int? commercialId,
    String? commercialEmail,
  }) {
    final id = _commercialIdFor(commercialId, commercialEmail);
    final orders = id == null
        ? MockPreSalesData.commercialOrders.values.expand((rows) => rows)
        : MockPreSalesData.commercialOrders[id] ?? const <CommercialOrder>[];
    return orders.map(_mockOrderRow).toList();
  }

  static List<Map<String, dynamic>> _mockOrdersByStatus(String? status) {
    final rows = _mockOrders();
    if (status == null || status.isEmpty) return rows;
    final expected = status.toLowerCase();
    return rows
        .where((row) => row['status']?.toString().toLowerCase() == expected)
        .toList();
  }

  static Map<String, dynamic> _mockCommandeById(int commandeId) {
    return _mockOrders().cast<Map<String, dynamic>>().firstWhere(
      (row) => row['id'] == commandeId || row['commande_id'] == commandeId,
      orElse: () => <String, dynamic>{},
    );
  }

  static List<Map<String, dynamic>> _mockReports() {
    var index = 0;
    return MockPreSalesData.commercialUsers(includeInactive: true).map((user) {
      index++;
      final dashboard = MockPreSalesData.dashboardForUser(user);
      final orders = MockPreSalesData.ordersForUser(user);
      final clients = MockPreSalesData.clientsForUser(user);
      final visits = MockPreSalesData.tourVisitsForUser(user);
      return {
        'id': 7000 + user.id,
        'rapport_id': 7000 + user.id,
        'commercial_id': user.id,
        'created_by': user.id,
        'commercial_name': user.name,
        'commercial': user.name,
        'email': user.email,
        'phone': user.phone,
        'city': 'Casablanca',
        'ville': 'Casablanca',
        'matricule': 'COM-${user.id.toString().padLeft(3, '0')}',
        'date': _isoDaysAgo(index - 1),
        'created_at': _isoDaysAgo(index - 1),
        'sent_at': _isoDaysAgo(index - 1),
        'is_read': index.isEven,
        'read': index.isEven,
        'summary':
            'Synthese journaliere: visites terrain, commandes creees et suivi clients.',
        'activities_count': dashboard?.activities.length ?? visits.length,
        'activites': dashboard?.activities.length ?? visits.length,
        'clients_count': clients.length,
        'clients_visited': visits
            .where((visit) => visit.status == TourVisitStatus.visited)
            .length,
        'calls': 4 + index,
        'meetings': 1 + index,
        'tasks': 3 + index,
        'claims': index == 2 ? 1 : 0,
        'orders_count': orders.length,
        'commandes': orders.length,
        'manager_comment': index.isEven
            ? 'Bon suivi, continuer la relance des prospects chauds.'
            : '',
      };
    }).toList();
  }

  static List<Map<String, dynamic>> _mockRecentActivities({
    int? commercialId,
    String? commercialEmail,
  }) {
    final id = _commercialIdFor(commercialId, commercialEmail);
    final dashboards = id == null
        ? MockPreSalesData.commercialDashboards.entries
        : MockPreSalesData.commercialDashboards.entries.where(
            (entry) => entry.key == id,
          );
    final rows = <Map<String, dynamic>>[];
    var rowId = 1;
    for (final entry in dashboards) {
      final user = MockPreSalesData.users.values
          .where((candidate) => candidate.id == entry.key)
          .firstOrNull;
      for (final activity in entry.value.activities) {
        rows.add({
          'id': rowId++,
          'commercial_id': entry.key,
          'commercial_email': user?.email ?? '',
          'type_action': 'activite_creee',
          'titre': 'Visite planifiee - ${activity.client}',
          'title': 'Visite planifiee - ${activity.client}',
          'description': '${activity.time} - ${activity.city}',
          'message': '${activity.time} - ${activity.city}',
          'created_at': _isoDaysAgo(rowId % 4),
          'date': _isoDaysAgo(rowId % 4),
        });
      }
    }
    for (final report in _mockReports()) {
      if (id != null && report['commercial_id'] != id) continue;
      rows.add({
        'id': rowId++,
        'commercial_id': report['commercial_id'],
        'type_action': 'rapport_journalier',
        'titre': 'Rapport journalier envoye',
        'title': 'Rapport journalier envoye',
        'description': report['summary'],
        'message': report['summary'],
        'created_at': report['created_at'],
        'date': report['date'],
      });
    }
    return rows;
  }

  static List<Map<String, dynamic>> _mockNotifications() {
    return [
      {
        'id': 1,
        'type': 'rapports',
        'title': 'Rapport journalier disponible',
        'message': 'Ahmed Benali a envoye son rapport du jour.',
        'created_at': _isoDaysAgo(0),
        'read': false,
        'is_read': false,
      },
      {
        'id': 2,
        'type': 'commandes',
        'title': 'Commande en attente',
        'message': 'CMD-2026-002 attend une validation manager.',
        'created_at': _isoDaysAgo(0),
        'read': false,
        'is_read': false,
      },
      {
        'id': 3,
        'type': 'objectifs',
        'title': 'Objectif mensuel',
        'message': 'L equipe commerciale atteint 63% de son objectif.',
        'created_at': _isoDaysAgo(1),
        'read': true,
        'is_read': true,
      },
    ];
  }

  static Map<String, dynamic> _mockOrderRow(CommercialOrder order) {
    final user = MockPreSalesData.users.values
        .where((candidate) => candidate.id == order.commercialId)
        .firstOrNull;
    final client = MockPreSalesData.commercialClients[order.commercialId]
        ?.where((candidate) => candidate.name == order.clientName)
        .firstOrNull;
    final status = switch (order.status) {
      OrderStatus.pending => 'pending',
      OrderStatus.synced || OrderStatus.delivered => 'validated',
      OrderStatus.cancelled => 'refused',
    };
    return {
      'id': order.id,
      'commande_id': order.id,
      'facture_id': order.id,
      'order_number': order.orderNumber,
      'numero': order.orderNumber,
      'reference': order.orderNumber,
      'client_id': client?.id,
      'client_name': order.clientName,
      'client': order.clientName,
      'client_phone': client?.phone ?? '',
      'client_city': client?.city ?? '',
      'client_category': client?.category ?? '',
      'client_address': client?.address ?? '',
      'client_code': client?.clientCode ?? '',
      'client_status': client?.status.name ?? '',
      'commercial_id': order.commercialId,
      'id_commercial': order.commercialId,
      'commercial_name': user?.name ?? 'Commercial',
      'commercial': user?.name ?? 'Commercial',
      'commercial_phone': user?.phone ?? '',
      'commercial_city': 'Casablanca',
      'commercial_matricule':
          'COM-${order.commercialId.toString().padLeft(3, '0')}',
      'date': _isoFromFrenchDate(order.date),
      'created_at': _isoFromFrenchDate(order.date),
      'date_facture': _isoFromFrenchDate(order.date),
      'status': status,
      'statut': status,
      'total': order.total,
      'total_amount': order.total,
      'montant_total': order.total,
      'amount': order.total,
      'subtotal': order.total,
      'products_count': order.productsCount,
      'items_count': order.productsCount,
      'items': order.items
          .map(
            (item) => {
              'product_name': item.productName,
              'name': item.productName,
              'quantity': item.quantity,
              'quantite': item.quantity,
              'unit_price': item.quantity == 0 ? 0 : item.total / item.quantity,
              'total': item.total,
              'total_ligne': item.total,
            },
          )
          .toList(),
    };
  }

  static int? _commercialIdFor(int? commercialId, String? commercialEmail) {
    if (commercialId != null && commercialId > 0) return commercialId;
    if (commercialEmail != null && commercialEmail.trim().isNotEmpty) {
      return MockPreSalesData.userByEmail(commercialEmail)?.id;
    }
    return null;
  }

  static String _isoDaysAgo(int days) {
    final date = DateTime.now().subtract(Duration(days: days));
    return DateTime(date.year, date.month, date.day, 10, 30).toIso8601String();
  }

  static String _isoFromFrenchDate(String value) {
    final parts = value.split('/');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day, 10, 30).toIso8601String();
      }
    }
    return DateTime.now().toIso8601String();
  }
}
