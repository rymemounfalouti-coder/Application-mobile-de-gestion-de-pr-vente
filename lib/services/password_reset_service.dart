import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api_service.dart';

class PasswordResetException implements Exception {
  const PasswordResetException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PasswordResetService {
  const PasswordResetService._();

  static Future<void> forgotPassword(String email) async {
    await _post('/auth/forgot-password', {'email': email});
  }

  static Future<void> verifyResetCode({
    required String email,
    required String code,
  }) async {
    await _post('/auth/verify-reset-code', {'email': email, 'code': code});
  }

  static Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (newPassword.length < 8) {
      throw const PasswordResetException('Mot de passe trop court.');
    }
    await _post('/auth/reset-password', {
      'email': email,
      'code': code,
      'new_password': newPassword,
    });
  }

  static Future<void> _post(String path, Map<String, String> body) async {
    final http.Response response;
    try {
      response = await http.post(
        Uri.parse('${ApiService.baseUrl}$path'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } catch (_) {
      throw const PasswordResetException(
        'Connexion au serveur impossible. Verifiez votre connexion.',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return;

    String message = 'Une erreur est survenue.';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] is String) {
        message = decoded['message'] as String;
      }
    } catch (_) {
      // Non-JSON error body: keep the generic message.
    }
    throw PasswordResetException(message);
  }
}
