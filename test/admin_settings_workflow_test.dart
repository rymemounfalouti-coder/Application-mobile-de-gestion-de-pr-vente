import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_prevente/screens/admin/admin_screens.dart';
import 'package:gestion_prevente/screens/admin/home_admin.dart';

void main() {
  testWidgets('search row hides the filter when no filter action exists', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminSearchRow(
            controller: controller,
            hint: 'Rechercher',
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.tune_rounded), findsNothing);
  });

  testWidgets('categories are seeded once and persist add and delete actions', (
    tester,
  ) async {
    String? stored;
    var seedLoads = 0;
    final storeNames = <String>[];

    Future<List<dynamic>> loadRows() async {
      seedLoads++;
      return [
        {'categorie': 'Alpha'},
        {'categorie': 'Beta'},
        {'categorie': 'alpha'},
      ];
    }

    Future<String?> readStore(String name) async {
      storeNames.add(name);
      return stored;
    }

    Future<void> writeStore(String name, String contents) async {
      storeNames.add(name);
      stored = contents;
    }

    Widget screen(Key key) => MaterialApp(
      home: CategoryManagerScreen(
        key: key,
        title: 'Catégories produits',
        kind: 'product',
        loadRows: loadRows,
        readStore: readStore,
        writeStore: writeStore,
      ),
    );

    await tester.pumpWidget(screen(const ValueKey('first-open')));
    await tester.pumpAndSettle();

    expect(seedLoads, 1);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(
      storeNames.every((name) => name == 'admin_categories_product_v1.json'),
      isTrue,
    );

    await tester.tap(find.text('Ajouter une catégorie'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Gamma');
    await tester.tap(find.widgetWithText(TextButton, 'Ajouter'));
    await tester.pumpAndSettle();

    expect(find.text('Gamma'), findsOneWidget);
    expect(
      (jsonDecode(stored!)['categories'] as List<dynamic>),
      containsAll(<String>['Alpha', 'Beta', 'Gamma']),
    );

    await tester.pumpWidget(screen(const ValueKey('second-open')));
    await tester.pumpAndSettle();
    expect(seedLoads, 1, reason: 'the saved list must be authoritative');
    expect(find.text('Gamma'), findsOneWidget);

    await tester.tap(find.byTooltip('Supprimer Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsNothing);
    expect(
      (jsonDecode(stored!)['categories'] as List<dynamic>),
      isNot(contains('Alpha')),
    );

    await tester.pumpWidget(screen(const ValueKey('third-open')));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsNothing);
    expect(find.text('Gamma'), findsOneWidget);
  });

  testWidgets('category validation rejects blank and duplicate names', (
    tester,
  ) async {
    var stored = jsonEncode({
      'version': 1,
      'kind': 'client',
      'categories': ['Prospect'],
    });
    var writes = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CategoryManagerScreen(
          title: 'Catégories clients',
          kind: 'client',
          loadRows: () async => const [],
          readStore: (_) async => stored,
          writeStore: (_, contents) async {
            writes++;
            stored = contents;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The version-1 store above is healed to version 2 during load, which is
    // a legitimate write; what must not write is a *rejected* add below.
    final writesAfterLoad = writes;

    await tester.tap(find.text('Ajouter une catégorie'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '   ');
    await tester.tap(find.widgetWithText(TextButton, 'Ajouter'));
    await tester.pumpAndSettle();
    expect(
      find.text('Le nom de la catégorie est obligatoire.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ajouter une catégorie'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, ' prospect ');
    await tester.tap(find.widgetWithText(TextButton, 'Ajouter'));
    await tester.pumpAndSettle();
    expect(find.text('Cette catégorie existe déjà.'), findsOneWidget);
    expect(writes, writesAfterLoad);
  });

  testWidgets('a pre-v2 store regains the built-in default categories', (
    tester,
  ) async {
    // Reproduces the real failure: a device seeded when only one type was
    // actually in use kept that single option forever, hiding the standard
    // ones from every client form.
    var stored = jsonEncode({
      'version': 1,
      'kind': 'commerce',
      'categories': ['Restaurant'],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: CategoryManagerScreen(
          title: 'Types de commerce',
          kind: 'commerce',
          loadRows: () async => const [],
          readStore: (_) async => stored,
          writeStore: (_, contents) async => stored = contents,
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final category in ['Épicerie', 'Supermarché', 'Grossiste', 'Café']) {
      expect(find.text(category), findsOneWidget, reason: '$category restored');
    }
    expect(find.text('Restaurant'), findsOneWidget);

    // Healed in place, so the repair does not run again on the next open.
    final decoded = jsonDecode(stored) as Map<String, dynamic>;
    expect(decoded['version'], 3);
    expect(
      (decoded['categories'] as List<dynamic>),
      containsAll(<String>['Café', 'Épicerie', 'Restaurant']),
    );
  });

  testWidgets('the client store sheds commerce types but keeps custom ones', (
    tester,
  ) async {
    // Pre-v3 the 'client' store doubled as the commerce-type list. Splitting
    // them must not throw away a category the admin added by hand.
    var stored = jsonEncode({
      'version': 2,
      'kind': 'client',
      'categories': ['blacklist', 'Café', 'Restaurant'],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: CategoryManagerScreen(
          title: 'Catégories clients',
          kind: 'client',
          loadRows: () async => const [],
          readStore: (_) async => stored,
          writeStore: (_, contents) async => stored = contents,
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final category in ['Prospect', 'Actif', 'Inactif', 'blacklist']) {
      expect(find.text(category), findsOneWidget, reason: '$category kept');
    }
    expect(find.text('Café'), findsNothing);
    expect(find.text('Restaurant'), findsNothing);
    expect((jsonDecode(stored) as Map<String, dynamic>)['version'], 3);
  });

  testWidgets('a healed store keeps deletions instead of resurrecting them', (
    tester,
  ) async {
    var stored = jsonEncode({
      'version': 3,
      'kind': 'commerce',
      'categories': ['Café', 'Restaurant'],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: CategoryManagerScreen(
          title: 'Types de commerce',
          kind: 'commerce',
          loadRows: () async => const [],
          readStore: (_) async => stored,
          writeStore: (_, contents) async => stored = contents,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Supprimer Café'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();

    expect(find.text('Café'), findsNothing);
    expect(
      (jsonDecode(stored)['categories'] as List<dynamic>),
      isNot(contains('Café')),
    );
  });

  testWidgets(
    'failed category save is reported and leaves the list unchanged',
    (tester) async {
      final stored = jsonEncode({
        'version': 1,
        'kind': 'product',
        'categories': ['Alpha'],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: CategoryManagerScreen(
            title: 'Catégories produits',
            kind: 'product',
            loadRows: () async => const [],
            readStore: (_) async => stored,
            writeStore: (_, _) async =>
                throw Exception('Stockage indisponible.'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ajouter une catégorie'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Beta');
      await tester.tap(find.widgetWithText(TextButton, 'Ajouter'));
      await tester.pumpAndSettle();

      expect(find.text('Beta'), findsNothing);
      expect(find.text('Stockage indisponible.'), findsOneWidget);
    },
  );

  testWidgets('category load errors are visible and retryable', (tester) async {
    var attempts = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CategoryManagerScreen(
          title: 'Catégories clients',
          kind: 'client',
          loadRows: () async => const [],
          readStore: (_) async {
            attempts++;
            throw Exception('Lecture impossible.');
          },
          writeStore: (_, _) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lecture impossible.'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });

  testWidgets('security screen does not advertise unsupported biometrics', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SecurityScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Changer le mot de passe'), findsOneWidget);
    expect(find.text('Authentification biométrique'), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
  });
}
