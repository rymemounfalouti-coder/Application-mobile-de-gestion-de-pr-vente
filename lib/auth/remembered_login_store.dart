import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/local_json_store.dart';

class RememberedLogin {
  const RememberedLogin({required this.email, this.password = ''});

  final String email;
  final String password;
}

class RememberedLoginStore {
  const RememberedLoginStore._();

  static const fileName = 'presales_session.json';
  static const _secureStorage = FlutterSecureStorage();

  static String _passwordKey(String email) => 'remembered_password_$email';

  /// Secure storage can be unavailable (locked keystore, unsupported
  /// platform, plugin not registered). The remembered email lives in plain
  /// JSON and must survive that, so a failure here costs the prefilled
  /// password — never the whole remembered-login list.
  static Future<String> _readPassword(String email) async {
    try {
      return await _secureStorage.read(key: _passwordKey(email)) ?? '';
    } catch (error) {
      debugPrint('Mot de passe mémorisé illisible: $error');
      return '';
    }
  }

  static List<RememberedLogin> merge(
    List<RememberedLogin> sessions,
    RememberedLogin next,
  ) {
    final normalizedEmail = next.email.trim().toLowerCase();
    return <RememberedLogin>[
      next,
      for (final session in sessions)
        if (session.email.trim().toLowerCase() != normalizedEmail) session,
    ];
  }

  static Future<void> save({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final sessions = merge(
      await loadAll(),
      RememberedLogin(email: normalizedEmail, password: password),
    );
    await _persist(sessions, writeLocalJson);
    await _secureStorage.write(
      key: _passwordKey(normalizedEmail),
      value: password,
    );
  }

  static Future<void> forget(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    final sessions = (await loadAll())
        .where(
          (session) => session.email.trim().toLowerCase() != normalizedEmail,
        )
        .toList();
    await _persist(sessions, writeLocalJson);
    await _secureStorage.delete(key: _passwordKey(normalizedEmail));
  }

  static Future<List<RememberedLogin>> loadAll({
    Future<String?> Function(String name)? reader,
    Future<void> Function(String name, String contents)? writer,
  }) async {
    final read = reader ?? readLocalJson;
    final write = writer ?? writeLocalJson;
    try {
      final contents = await read(fileName);
      if (contents == null) return const [];

      final payload = jsonDecode(contents);
      if (payload is! Map<String, dynamic>) return const [];

      final emails = <String>[];
      final sessionsPayload = payload['sessions'];
      if (sessionsPayload is List) {
        for (final item in sessionsPayload) {
          if (item is! Map) continue;
          final email = item['email']?.toString().trim().toLowerCase() ?? '';
          final remembered = item['rememberMe'] != false;
          if (remembered && email.isNotEmpty) {
            emails.add(email);
          }
        }
      } else {
        final email = payload['email']?.toString().trim().toLowerCase() ?? '';
        if (payload['rememberMe'] == true && email.isNotEmpty) {
          emails.add(email);
        }
      }

      final sessions = <RememberedLogin>[
        for (final email in emails)
          RememberedLogin(email: email, password: await _readPassword(email)),
      ];

      // Older versions stored passwords in this JSON file. Rewrite legacy
      // data immediately so an application upgrade removes it from disk;
      // passwords now live in the platform's secure storage instead.
      if (contents.contains('"password"')) {
        await _persist(sessions, write);
      }
      return sessions;
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _persist(
    List<RememberedLogin> sessions,
    Future<void> Function(String name, String contents) writer,
  ) {
    return writer(
      fileName,
      jsonEncode({
        'sessions': [
          for (final session in sessions)
            {'email': session.email, 'rememberMe': true},
        ],
      }),
    );
  }
}
