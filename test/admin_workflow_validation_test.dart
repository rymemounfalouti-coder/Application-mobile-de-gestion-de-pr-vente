import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_prevente/screens/admin/admin_screens.dart';
import 'package:gestion_prevente/screens/admin/home_admin.dart';

void main() {
  void useLargeTestSurface(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  testWidgets('user creation rejects passwords shorter than eight characters', (
    tester,
  ) async {
    useLargeTestSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: UserFormScreen()));

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(5));
    await tester.enterText(fields.at(0), 'Aya');
    await tester.enterText(fields.at(1), 'Bennani');
    await tester.enterText(fields.at(3), 'aya@example.com');
    await tester.enterText(fields.at(4), '1234567');
    await tester.tap(find.text('Créer'));
    await tester.pump();

    expect(
      find.text('Le mot de passe doit contenir au moins 8 caractères.'),
      findsOneWidget,
    );
    expect(find.byType(UserFormScreen), findsOneWidget);
  });

  testWidgets('product form requires a positive price and non-negative stock', (
    tester,
  ) async {
    useLargeTestSurface(tester);
    await tester.pumpWidget(
      MaterialApp(home: ProductFormScreen(store: ProductStore())),
    );

    // Nom, Référence, Description, Prix, Stock. Catégorie is a dropdown and
    // "Image produit" is a picker, so neither is a TextField.
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(5));
    await tester.enterText(fields.at(0), 'Thé test');
    await tester.enterText(fields.at(1), 'TEST-001');
    await tester.enterText(fields.at(3), '0');
    await tester.enterText(fields.at(4), '10');
    await tester.tap(find.text('Ajouter'));
    await tester.pump();

    expect(find.text('Le prix doit être strictement positif.'), findsOneWidget);

    await tester.enterText(fields.at(3), '25');
    await tester.enterText(fields.at(4), '-1');
    await tester.tap(find.text('Ajouter'));
    await tester.pump();

    expect(find.text('Le stock ne peut pas être négatif.'), findsOneWidget);
    expect(find.byType(ProductFormScreen), findsOneWidget);
  });
}
