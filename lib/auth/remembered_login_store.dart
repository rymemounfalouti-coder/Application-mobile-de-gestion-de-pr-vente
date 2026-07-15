import 'dart:convert';

import '../services/local_json_store.dart';

class RememberedLogin {
  const RememberedLogin({required this.email});

  final String email;
}

class RememberedLoginStore {
  const RememberedLoginStore._();

  static const fileName = 'presales_session.json';

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

  static Future<void> save({required String email}) async {
    final sessions = merge(
      await loadAll(),
      RememberedLogin(email: email.trim().toLowerCase()),
    );
    await _persist(sessions, writeLocalJson);
  }

  static Future<void> forget(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    final sessions = (await loadAll())
        .where(
          (session) => session.email.trim().toLowerCase() != normalizedEmail,
        )
        .toList();
    await _persist(sessions, writeLocalJson);
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

      final sessions = <RememberedLogin>[];
      final sessionsPayload = payload['sessions'];
      if (sessionsPayload is List) {
        for (final item in sessionsPayload) {
          if (item is! Map) continue;
          final email = item['email']?.toString().trim().toLowerCase() ?? '';
          final remembered = item['rememberMe'] != false;
          if (remembered && email.isNotEmpty) {
            sessions.add(RememberedLogin(email: email));
          }
        }
      } else {
        final email = payload['email']?.toString().trim().toLowerCase() ?? '';
        if (payload['rememberMe'] == true && email.isNotEmpty) {
          sessions.add(RememberedLogin(email: email));
        }
      }

      // Older versions stored passwords here. Rewrite legacy data immediately
      // so an application upgrade removes the credential from disk.
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
