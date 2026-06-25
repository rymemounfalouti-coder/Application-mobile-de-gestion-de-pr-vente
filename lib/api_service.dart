import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:5000';

  static Future<List<dynamic>> getClients() async {
    final response = await http.get(Uri.parse('$baseUrl/clients'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur chargement clients');
    }
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
    final response = await http.post(
      Uri.parse('$baseUrl/commandes'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }
    throw Exception('Erreur creation commande: ${response.body}');
  }

  static Future<List<dynamic>> getNotifications({int? managerId}) async {
    final uri = managerId == null
        ? Uri.parse('$baseUrl/notifications')
        : Uri.parse('$baseUrl/notifications?manager_id=$managerId');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded is List
          ? decoded
          : decoded['data'] as List<dynamic>? ?? [];
    }
    throw Exception('Erreur chargement notifications');
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
      final decoded = jsonDecode(response.body);
      return decoded is List
          ? decoded
          : decoded['data'] as List<dynamic>? ?? [];
    } else {
      throw Exception('Erreur chargement utilisateurs');
    }
  }

  static Future<Map<String, dynamic>> updateUser(
    int userId,
    Map<String, dynamic> data,
  ) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/users/$userId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }
    throw Exception('Erreur mise a jour utilisateur');
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
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur chargement produits');
    }
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
