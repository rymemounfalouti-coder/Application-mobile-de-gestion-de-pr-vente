import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_prevente/api_service.dart';
import 'package:gestion_prevente/auth/remembered_login_store.dart';

void main() {
  test('demo authentication is disabled in a normal build', () {
    expect(ApiService.demoModeEnabled, isFalse);
  });

  test('legacy remembered passwords are removed during migration', () async {
    String? rewritten;
    final sessions = await RememberedLoginStore.loadAll(
      reader: (_) async => jsonEncode({
        'sessions': [
          {
            'email': 'Manager@Presales.ma',
            'password': 'plaintext-secret',
            'rememberMe': true,
          },
        ],
      }),
      writer: (_, contents) async {
        rewritten = contents;
      },
    );

    expect(sessions, hasLength(1));
    expect(sessions.single.email, 'manager@presales.ma');
    expect(rewritten, isNotNull);
    expect(rewritten, isNot(contains('plaintext-secret')));
    expect(rewritten, isNot(contains('password')));
  });

  test('remembered-login merge stores only one normalized email', () {
    final merged = RememberedLoginStore.merge(const [
      RememberedLogin(email: 'manager@presales.ma'),
      RememberedLogin(email: 'admin@presales.ma'),
    ], const RememberedLogin(email: 'MANAGER@PRESALES.MA'));

    expect(merged, hasLength(2));
    expect(merged.first.email, 'MANAGER@PRESALES.MA');
    expect(merged.last.email, 'admin@presales.ma');
  });
}
