import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:5000';

  static Future<Map<String, dynamic>> getCompanyInfo() async {
    final response = await http.get(Uri.parse('$baseUrl/company-info'));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    }
    throw Exception('Erreur chargement informations entreprise');
  }

  static Future<Map<String, dynamic>> updateCompanyInfo(
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
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
    final response = await http.get(uri);

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
    } else {
      throw Exception('Erreur chargement clients');
    }
  }

  static Future<Map<String, dynamic>> createClient(
    Map<String, dynamic> data,
  ) async {
    debugPrint(
      '[COMMERCIAL][CLIENTS][POST] name=${data['name']} '
      'commercial_id=${data['commercial_id']} status=${data['status']}',
    );
    final response = await http.post(
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
    final response = await http.get(uri);

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
    throw Exception('Erreur chargement activites recentes');
  }

  static Future<Map<String, dynamic>> createCommercialRecentActivity(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
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
    final response = await http.get(Uri.parse('$baseUrl/factures'));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded is List
          ? decoded
          : decoded['data'] as List<dynamic>? ?? [];
    } else {
      throw Exception('Erreur chargement factures');
    }
  }

  static Future<Map<String, dynamic>> createCommande(
    Map<String, dynamic> data,
  ) async {
    debugPrint(
      '[COMMANDES][POST] payload status=${data['status']} '
      'commercial_id=${data['commercial_id']} manager_id=${data['manager_id']}',
    );
    final response = await http.post(
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
    final query = <String, String>{};
    if (managerId != null) query['manager_id'] = '$managerId';
    if (status != null && status.isNotEmpty) query['status'] = status;
    final uri = Uri.parse(
      '$baseUrl/manager/commandes',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri);

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
    throw Exception('Erreur chargement commandes manager');
  }

  static Future<List<dynamic>> getCommercialCommandes({
    int? commercialId,
    String? commercialEmail,
  }) async {
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
    final response = await http.get(uri);

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
    throw Exception('Erreur chargement commandes commercial');
  }

  static Future<List<dynamic>> getNotifications({int? managerId}) async {
    final uri = managerId == null
        ? Uri.parse('$baseUrl/notifications')
        : Uri.parse('$baseUrl/notifications?manager_id=$managerId');
    final response = await http.get(uri);

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
    throw Exception('Erreur chargement notifications');
  }

  static Future<Map<String, dynamic>> markNotificationRead(
    int notificationId,
  ) async {
    final response = await http.patch(
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
    final uri = managerId == null
        ? Uri.parse('$baseUrl/notifications/read-all')
        : Uri.parse('$baseUrl/notifications/read-all?manager_id=$managerId');
    final response = await http.patch(
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
    final response = await http.delete(
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
    final commandeResponse = await http.get(
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

    final factureResponse = await http.get(
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

    throw Exception('Erreur chargement commande');
  }

  static Future<Map<String, dynamic>> updateCommandeStatus(
    int commandeId,
    String status, {
    String? refusalReason,
    int? managerId,
  }) async {
    final body = <String, dynamic>{'status': status};
    if (refusalReason != null) body['refusal_reason'] = refusalReason;
    if (managerId != null) body['manager_id'] = managerId;

    final response = await http.patch(
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
    final body = <String, dynamic>{'comment': comment};
    if (managerId != null) body['manager_id'] = managerId;

    final response = await http.post(
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

  static Future<Map<String, dynamic>> updateFactureStatus(
    int factureId,
    String status, {
    String? refusalReason,
    int? managerId,
  }) async {
    final body = <String, dynamic>{'status': status};
    if (refusalReason != null) body['refusal_reason'] = refusalReason;
    if (managerId != null) body['manager_id'] = managerId;

    final response = await http.patch(
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
    final response = await http.get(Uri.parse('$baseUrl/users'));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is List
          ? decoded
          : decoded['data'] as List<dynamic>? ?? [];
    } else {
      throw Exception('Erreur chargement utilisateurs');
    }
  }

  static Future<Map<String, dynamic>> createUser(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
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
    final response = await http.patch(
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
    final response = await http.delete(
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
    final response = await http.post(
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
    final response = await http.patch(
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
    final response = await http.get(Uri.parse('$baseUrl/rapports'));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded is List
          ? decoded
          : decoded['data'] as List<dynamic>? ?? [];
    } else {
      throw Exception('Erreur chargement rapports');
    }
  }

  static Future<Map<String, dynamic>> createRapport(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
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
    final response = await http.patch(
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
    final body = <String, dynamic>{'comment': comment};
    if (managerId != null) body['manager_id'] = managerId;
    final response = await http.post(
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
    final response = await http.get(Uri.parse('$baseUrl/produits'));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is List
          ? decoded
          : decoded['data'] as List<dynamic>? ?? [];
    } else {
      throw Exception('Erreur chargement produits');
    }
  }

  static Future<Map<String, dynamic>> createProduit(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
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
    final response = await http.patch(
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
    final response = await http.delete(
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
    final response = await http.patch(
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
    final response = await http.delete(
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
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Email ou mot de passe incorrect');
    }
  }
}
