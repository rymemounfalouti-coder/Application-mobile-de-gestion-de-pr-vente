import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_prevente/services/commercial_objectives_service.dart';

void main() {
  test('web objectives seed defaults only when storage is absent', () async {
    String? stored;
    var writes = 0;
    final service = CommercialObjectivesService.forWebTesting(
      readStore: (name) async {
        expect(name, 'commercial_objectives_v1.json');
        return stored;
      },
      writeStore: (name, contents) async {
        expect(name, 'commercial_objectives_v1.json');
        writes++;
        stored = contents;
      },
    );

    final objective = await service.getObjective(1);

    expect(objective, isNotNull);
    expect(objective!.orderTarget, 14);
    expect(objective.revenueTarget, 95000);
    expect(writes, 1);
    expect(jsonDecode(stored!)['objectives'], isA<List<dynamic>>());
  });

  test('saved web objective survives a new service instance', () async {
    String? stored;

    CommercialObjectivesService service() =>
        CommercialObjectivesService.forWebTesting(
          readStore: (_) async => stored,
          writeStore: (_, contents) async => stored = contents,
        );

    final firstInstance = service();
    await firstInstance.getObjective(1);
    await firstInstance.saveObjective(
      CommercialObjective(
        commercialId: 42,
        orderTarget: 18,
        revenueTarget: 125000,
      ),
    );

    final reloadedInstance = service();
    final reloaded = await reloadedInstance.getObjective(42);

    expect(reloaded, isNotNull);
    expect(reloaded!.orderTarget, 18);
    expect(reloaded.revenueTarget, 125000);
  });

  test('an existing empty store does not reintroduce seed defaults', () async {
    final stored = jsonEncode({
      'version': 1,
      'objectives': <Map<String, Object?>>[],
    });
    var writes = 0;
    final service = CommercialObjectivesService.forWebTesting(
      readStore: (_) async => stored,
      writeStore: (_, _) async => writes++,
    );

    expect(await service.getObjective(1), isNull);
    expect(writes, 0);
  });

  test(
    'corrupt web storage is ignored and repaired by the next save',
    () async {
      var stored = '{not valid json';
      var writes = 0;
      final service = CommercialObjectivesService.forWebTesting(
        readStore: (_) async => stored,
        writeStore: (_, contents) async {
          writes++;
          stored = contents;
        },
      );

      expect(await service.getObjective(1), isNull);
      expect(
        writes,
        0,
        reason: 'corrupt data must not trigger default seeding',
      );

      await service.saveObjective(
        CommercialObjective(
          commercialId: 9,
          orderTarget: 7,
          revenueTarget: 64000,
        ),
      );

      expect(writes, 1);
      expect(jsonDecode(stored), isA<Map<String, dynamic>>());
      final reloaded = CommercialObjectivesService.forWebTesting(
        readStore: (_) async => stored,
        writeStore: (_, _) async {},
      );
      expect((await reloaded.getObjective(9))?.revenueTarget, 64000);
    },
  );

  test('failed web save rolls the in-memory objective back', () async {
    final stored = jsonEncode({
      'version': 1,
      'objectives': [
        {'commercial_id': 7, 'order_target': 3, 'revenue_target': 10000},
      ],
    });
    final service = CommercialObjectivesService.forWebTesting(
      readStore: (_) async => stored,
      writeStore: (_, _) async => throw Exception('Quota dépassé.'),
    );

    expect((await service.getObjective(7))?.orderTarget, 3);
    await expectLater(
      service.saveObjective(
        CommercialObjective(
          commercialId: 7,
          orderTarget: 99,
          revenueTarget: 999999,
        ),
      ),
      throwsA(isA<Exception>()),
    );
    expect((await service.getObjective(7))?.orderTarget, 3);
  });
}
