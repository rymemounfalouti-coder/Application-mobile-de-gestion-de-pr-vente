import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_prevente/screens/admin/home_admin.dart';

void main() {
  const defaults = <String, bool>{
    'new_orders': true,
    'new_clients': true,
    'sent_reports': true,
    'system_errors': false,
    'sounds': true,
  };

  SwitchListTile notificationTile(WidgetTester tester, String label) {
    return tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, label),
    );
  }

  testWidgets('notification choices are loaded and survive reopening', (
    tester,
  ) async {
    var stored = {...defaults};

    Future<Map<String, bool>> load(int userId) async {
      expect(userId, 801);
      return {...stored};
    }

    Future<void> save(int userId, Map<String, bool> values) async {
      expect(userId, 801);
      stored = {...values};
    }

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsSettingsScreen(
          key: const ValueKey('first-open'),
          userId: 801,
          loadPreferences: load,
          savePreferences: save,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Nouvelles commandes'),
    );
    await tester.pumpAndSettle();
    expect(stored['new_orders'], false);

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsSettingsScreen(
          key: const ValueKey('second-open'),
          userId: 801,
          loadPreferences: load,
          savePreferences: save,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(notificationTile(tester, 'Nouvelles commandes').value, isFalse);
  });

  testWidgets('failed notification save rolls the switch back and reports it', (
    tester,
  ) async {
    Future<Map<String, bool>> load(int _) async => {...defaults};
    Future<void> failSave(int _, Map<String, bool> values) async {
      throw Exception('Serveur indisponible.');
    }

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsSettingsScreen(
          userId: 802,
          loadPreferences: load,
          savePreferences: failSave,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Nouvelles commandes'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(notificationTile(tester, 'Nouvelles commandes').value, isTrue);
    expect(find.text('Serveur indisponible.'), findsOneWidget);
  });
}
