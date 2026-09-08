import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/domain/training_program.dart';
import 'training_program_fixtures.dart';

void main() {
  test('기존 v1을 이행하고 v3로 저장하여 구버전 덮어쓰기를 막는다', () async {
    final directory = await Directory.systemTemp.createTemp('strength-schema-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/state.json');
    final old = TrainingAppState(onboarded: true).withActivePlan(fixturePlan());
    final legacyJson = old.toJson()
      ..remove('loadAdjustments')
      ..remove('sessionEvents')
      ..remove('legacySessionIds');
    await file.writeAsString(
      jsonEncode({'schemaVersion': 1, 'state': legacyJson}),
    );
    final store = LocalTrainingStore(file);
    final restored = await store.load();
    expect(restored.loadAdjustments, isEmpty);
    expect(restored.activePlan!.toJson(), old.activePlan!.toJson());
    await store.save(restored);
    final envelope = jsonDecode(await file.readAsString()) as Map;
    expect(envelope['schemaVersion'], 3);
    expect((await LocalTrainingStore(file).load()).toJson(), restored.toJson());
    final future = jsonEncode({'schemaVersion': 5, 'state': restored.toJson()});
    await file.writeAsString(future);
    await expectLater(
      store.load(),
      throwsA(isA<LocalTrainingStoreException>()),
    );
    expect(await file.readAsString(), future);
  });
}
