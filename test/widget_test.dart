import 'package:flutter_test/flutter_test.dart';

import 'package:gestion_prevente/l10n/app_locale_controller.dart';
import 'package:gestion_prevente/main.dart';
import 'package:gestion_prevente/settings/app_appearance_controller.dart';

void main() {
  testWidgets('app starts on login screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      MyApp(
        localeController: AppLocaleController.instance,
        appearanceController: AppAppearanceController.instance,
      ),
    );

    expect(find.text('Bienvenue !'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
  });
}
