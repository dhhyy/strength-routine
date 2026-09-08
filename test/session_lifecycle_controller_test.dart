import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/app/training_controller.dart';
import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/domain/training_program.dart';

import 'training_program_fixtures.dart';

void main() {
  late Directory directory;
  late File file;
  late TrainingController controller;
  final now = DateTime.utc(2026, 9, 10, 12);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('session-controller-');
    file = File('${directory.path}/state.json');
    controller = TrainingController(
      store: LocalTrainingStore(file),
      now: () => now,
      loadPrograms: () async => [],
    )..loading = false;
    var state = TrainingAppState(activePlan: fixturePlan());
    for (final set in state.activePlan!.sessions.first.exercises.single.sets) {
      state = state.withSetActual(set.id, const SetActual.skipped());
    }
    controller.state = state;
  });

  tearDown(() async {
    controller.dispose();
    await directory.delete(recursive: true);
  });

  test('마감 실패는 메모리 원본을 유지하고 같은 동작 재시도는 사건 하나만 저장한다', () async {
    final sessionId = controller.state.activePlan!.sessions.first.id;
    final original = controller.state.toJson();
    await Directory(file.path).create();
    expect(
      await controller.closeSession(sessionId, eventId: 'close', at: now),
      isFalse,
    );
    expect(controller.state.toJson(), original);
    expect(controller.sessionActionError, isNotNull);
    expect(controller.sessionActionPending, isFalse);
    expect(controller.saveError, isNull);
    await Directory(file.path).delete();
    expect(
      await controller.closeSession(sessionId, eventId: 'close', at: now),
      isTrue,
    );
    expect(controller.sessionActionError, isNull);
    expect(controller.state.sessionEvents, hasLength(1));
    expect(controller.state.isSessionClosed(sessionId), isTrue);
    expect(
      await controller.closeSession(sessionId, eventId: 'close', at: now),
      isTrue,
    );
    expect(controller.state.sessionEvents, hasLength(1));
    expect(
      (await LocalTrainingStore(file).load()).toJson(),
      controller.state.toJson(),
    );
  });

  test('마감 저장 중 새 입력과 중복 마감을 막고 저장 성공 뒤에만 상태를 확정한다', () async {
    final sessionId = controller.state.activePlan!.sessions.first.id;
    final closing = controller.closeSession(sessionId, eventId: 'close');
    expect(controller.sessionActionPending, isTrue);
    expect(controller.state.isSessionClosed(sessionId), isFalse);
    var transformed = false;
    expect(
      await controller.update((state) {
        transformed = true;
        return state;
      }),
      isFalse,
    );
    expect(transformed, isFalse);
    expect(
      await controller.closeSession(sessionId, eventId: 'duplicate'),
      isFalse,
    );
    expect(await closing, isTrue);
    expect(controller.state.sessionEvents.single.id, 'close');
    expect(controller.state.sessionEvents.single.at, now);
    expect(controller.sessionActionPending, isFalse);
  });

  test('진행 중 입력 저장과 실패한 입력 저장을 먼저 해결해야 마감할 수 있다', () async {
    final sessionId = controller.state.activePlan!.sessions.first.id;
    final update = controller.update(
      (state) => state.withSessionNote(sessionId, '보존할 메모'),
    );
    expect(controller.saving, isTrue);
    expect(await controller.closeSession(sessionId, eventId: 'early'), isFalse);
    expect(controller.state.sessionEvents, isEmpty);
    expect(await update, isTrue);
    await file.delete();
    await Directory(file.path).create();
    expect(
      await controller.update(
        (state) => state.withSessionNote(sessionId, '미저장 메모'),
      ),
      isFalse,
    );
    expect(
      await controller.closeSession(sessionId, eventId: 'failed-input'),
      isFalse,
    );
    expect(controller.state.sessionNotes[sessionId], '미저장 메모');
    expect(controller.state.sessionEvents, isEmpty);
    await Directory(file.path).delete();
    expect(await controller.retrySave(), isTrue);
    expect(await controller.closeSession(sessionId, eventId: 'saved'), isTrue);
    expect(controller.state.sessionEvents.single.id, 'saved');
  });

  test('재개 저장 실패는 기존 마감을 보존하고 재시도·새 컨트롤러 복원이 일치한다', () async {
    final sessionId = controller.state.activePlan!.sessions.first.id;
    expect(await controller.closeSession(sessionId, eventId: 'close'), isTrue);
    final closed = controller.state.toJson();
    await file.delete();
    await Directory(file.path).create();
    final reopenedAt = now.add(const Duration(minutes: 5));
    expect(
      await controller.reopenSession(
        sessionId,
        eventId: 'open',
        at: reopenedAt,
      ),
      isFalse,
    );
    expect(controller.state.toJson(), closed);
    await Directory(file.path).delete();
    expect(
      await controller.reopenSession(
        sessionId,
        eventId: 'open',
        at: reopenedAt,
      ),
      isTrue,
    );
    final restored = TrainingController(
      store: LocalTrainingStore(file),
      loadPrograms: () async => [],
    );
    addTearDown(restored.dispose);
    await restored.initialize();
    expect(restored.state.toJson(), controller.state.toJson());
    expect(restored.state.isSessionClosed(sessionId), isFalse);
    expect(restored.state.sessionEvents.map((e) => e.kind), [
      SessionLifecycleKind.closed,
      SessionLifecycleKind.reopened,
    ]);
  });

  test('마감 검증 실패는 파일과 상태를 수정하지 않는다', () async {
    controller.state = TrainingAppState(activePlan: fixturePlan());
    await controller.store.save(controller.state);
    final before = await file.readAsString();
    final sessionId = controller.state.activePlan!.sessions.first.id;
    expect(
      await controller.closeSession(sessionId, eventId: 'invalid'),
      isFalse,
    );
    expect(controller.sessionActionError, contains('필수'));
    expect(await file.readAsString(), before);
    expect(controller.state.sessionEvents, isEmpty);
  });
}
