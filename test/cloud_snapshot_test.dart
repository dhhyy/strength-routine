import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/app/training_controller.dart';
import 'package:strength_routine/app/working_max_controller.dart';
import 'package:strength_routine/data/cloud_snapshot_store.dart';
import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/data/local_working_max_store.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_program.dart';
import 'package:strength_routine/domain/working_max.dart';

void main() {
  test('우회·미로그인은 서버 동기화 금지', () {
    expect(
      cloudSyncAllowed(
        isSignedIn: true,
        userId: 'bypass-local',
        bypassSession: true,
      ),
      isFalse,
    );
    expect(
      cloudSyncAllowed(
        isSignedIn: false,
        userId: null,
        bypassSession: false,
      ),
      isFalse,
    );
  });

  test('메모리 스토어로 업로드 후 다른 로컬 상태에 다운로드', () async {
    final dir = await Directory.systemTemp.createTemp('cloud-snap-');
    final training = TrainingController(
      store: LocalTrainingStore(File('${dir.path}/t.json')),
      loadPrograms: () async => [],
    );
    await training.initialize();
    await training.update((_) => TrainingAppState(onboarded: true));

    final workingMax = WorkingMaxController(
      store: LocalWorkingMaxStore(File('${dir.path}/w.json')),
    );
    await workingMax.initialize();
    await workingMax.adoptEstimated(
      lift: MainLift.squat,
      estimatedKg: 100,
      now: DateTime.utc(2026, 9, 11),
    );

    final memory = MemoryCloudSnapshotStore();
    await memory.upsertTrainingEnvelope(
      userId: 'user-1',
      envelope: training.exportEnvelope(),
    );
    await memory.upsertWorkingMax(
      userId: 'user-1',
      payload: workingMax.state.toJson(),
    );

    final otherTraining = TrainingController(
      store: LocalTrainingStore(File('${dir.path}/t2.json')),
      loadPrograms: () async => [],
    );
    await otherTraining.initialize();
    final otherWm = WorkingMaxController(
      store: LocalWorkingMaxStore(File('${dir.path}/w2.json')),
    );
    await otherWm.initialize();

    final envelope = await memory.fetchTrainingEnvelope('user-1');
    expect(envelope, isNotNull);
    expect(await otherTraining.importEnvelope(envelope!), isTrue);
    expect(otherTraining.state.onboarded, isTrue);

    final wm = await memory.fetchWorkingMax('user-1');
    expect(wm, isNotNull);
    await otherWm.replaceState(WorkingMaxState.fromJson(wm!));
    expect(otherWm.state[MainLift.squat]?.kilograms, 100);

    await dir.delete(recursive: true);
  });
}
