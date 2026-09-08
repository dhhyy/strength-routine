import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/admin/admin_program_store.dart';
import 'package:strength_routine/admin/admin_screen.dart';
import 'package:strength_routine/admin/detailed_routine.dart';
import 'package:strength_routine/admin/detailed_routine_screen.dart';
import 'package:strength_routine/admin/routine_builder.dart';
import 'package:strength_routine/domain/training_program.dart';
import 'package:strength_routine/theme.dart';

import 'admin_routine_test.dart' show validBlueprint;

void main() {
  late Directory directory;
  late AdminProgramStore store;
  late TrainingProgram program;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('precise-admin-flow-');
    store = AdminProgramStore(File('${directory.path}/workspace.json'));
    program = generateRoutine(validBlueprint());
  });
  tearDown(() async => directory.delete(recursive: true));

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 35; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> showAdmin(
    WidgetTester tester, {
    DetailedRoutineDraft? draft,
    RoutineBlueprint? basicDraft,
  }) async {
    await tester.runAsync(
      () => store.save(
        AdminWorkspace(
          draft: basicDraft ?? validBlueprint(),
          programs: [program],
          detailedDraft: draft,
        ),
      ),
    );
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildConsoleTheme(),
        home: AdminScreen(store: store, seedPrograms: () async => []),
      ),
    );
    await settle(tester);
  }

  Future<void> reveal(
    WidgetTester tester,
    Finder finder, {
    double delta = 450,
  }) async {
    await tester.scrollUntilVisible(
      finder,
      delta,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(
    WidgetTester tester,
    Finder finder, {
    double delta = 450,
  }) async {
    await reveal(tester, finder, delta: delta);
    await tester.tap(finder);
    await settle(tester);
  }

  Finder fieldWithSuffix(String suffix) => find.byWidgetPredicate(
    (widget) =>
        widget is TextFormField &&
        (widget.key as ValueKey?)?.value.toString().endsWith(suffix) == true,
  );

  testWidgets('목록에서 기존 프로그램의 한 세트를 편집해 새 버전 저장·내보내기·재로딩한다', (tester) async {
    await showAdmin(tester);
    await tap(tester, find.byKey(ValueKey('precise-edit-${program.id}')));
    expect(find.byType(DetailedRoutineScreen), findsOneWidget);
    final opened = (await tester.runAsync(store.load))!;
    expect(
      generateDetailedRoutine(opened.detailedDraft!).toJson(),
      program.toJson(),
    );

    await tap(tester, find.text('프로그램 정보'));
    final version = fieldWithSuffix('-version');
    await reveal(tester, version);
    await tester.enterText(version, '2');
    await settle(tester);
    await tap(tester, find.text('프로그램 정보'), delta: -450);
    await tap(tester, find.byKey(const ValueKey('detail-week-1')), delta: -450);
    final reps = fieldWithSuffix('w1-s0-e0-t1-reps');
    await reveal(tester, reps);
    await tester.enterText(reps, '8');
    await settle(tester);
    expect(
      (await tester.runAsync(store.load))!.programs.single.toJson(),
      program.toJson(),
    );
    await tap(tester, find.text('변경 검토'));
    expect(find.text('프로그램 변경 검토'), findsOneWidget);
    await tap(tester, find.text('검토한 프로그램 저장'));

    final restored = (await tester.runAsync(
      () => AdminProgramStore(store.file).load(),
    ))!;
    final next = restored.programs.single;
    expect(next.version, '2');
    expect(next.sessions.first.exercises.first.sets[1].repetitions, 5);
    expect(next.sessions[2].exercises.first.sets[1].repetitions, 8);
    expect(next.sessions[2].id, program.sessions[2].id);
    expect(restored.draft.toJson(), validBlueprint().toJson());
    await tester.pageBack();
    await settle(tester);
    await tap(tester, find.text('카탈로그 내보내기'));
    final export = await tester.runAsync(
      () => File('${directory.path}/admin-export/programs.json').readAsString(),
    );
    final payload = jsonDecode(export!) as Map;
    expect(payload['schemaVersion'], 1);
    expect((payload['programs'] as List).single, next.toJson());
    expect(tester.takeException(), isNull);
  });

  testWidgets('기본 생성의 카탈로그 확정 중 늦은 입력은 새 프로그램을 되돌려 쓰지 않는다', (tester) async {
    final revised = validBlueprint()..version = '2';
    await showAdmin(tester, basicDraft: revised);
    final title = find.byKey(const ValueKey('1-title'));
    await reveal(tester, title);
    final lateInput = tester.widget<TextFormField>(title).onChanged!;
    await tap(tester, find.text('생성 결과 확인'));
    await reveal(tester, find.text('관리자 카탈로그에 저장'));
    await tester.tap(find.text('관리자 카탈로그에 저장'));
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is AbsorbPointer && widget.absorbing,
      ),
      findsWidgets,
    );
    lateInput('확정 도중 뒤늦게 들어온 입력');
    await settle(tester);
    final saved = (await tester.runAsync(
      () => AdminProgramStore(store.file).load(),
    ))!;
    expect(saved.programs.single.version, '2');
    expect(saved.draft.title, revised.title);
    expect(tester.takeException(), isNull);
  });

  testWidgets('정밀 초안 교체 저장 실패는 이전 초안을 유지하고 상단에 실패를 알린다', (tester) async {
    final unfinished = DetailedRoutineDraft.fromProgram(program);
    unfinished.weeks[1].sessions.first.exercises.first.sets.first.repetitions =
        '7.';
    await showAdmin(tester, draft: unfinished);
    final original = File('${directory.path}/original.json');
    await tester.runAsync(() async {
      await store.file.rename(original.path);
      await Directory(store.file.path).create();
    });
    await tap(tester, find.byKey(ValueKey('precise-clone-${program.id}')));
    await tester.tap(find.text('초안 바꾸기'));
    await settle(tester);
    expect(find.text('변경 저장 실패').hitTestable(), findsOneWidget);
    expect(find.byType(DetailedRoutineScreen), findsNothing);
    await tester.runAsync(() async {
      await Directory(store.file.path).delete();
      await original.rename(store.file.path);
    });
    await tap(tester, find.text('정밀 초안 이어서'));
    final screen = tester.widget<DetailedRoutineScreen>(
      find.byType(DetailedRoutineScreen),
    );
    expect(screen.initialDraft.toJson(), unfinished.toJson());
    expect(tester.takeException(), isNull);
  });

  testWidgets('초안 교체 취소는 파일을 보존하고 프로그램 복제는 새 ID를 요구한다', (tester) async {
    final unfinished = DetailedRoutineDraft.fromProgram(program);
    unfinished.weeks[1].sessions.first.exercises.first.sets.first.repetitions =
        '7.';
    await showAdmin(tester, draft: unfinished);
    final before = await tester.runAsync(store.file.readAsString);
    await tap(tester, find.byKey(ValueKey('precise-clone-${program.id}')));
    expect(find.text('정밀 초안을 바꿀까요?'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await settle(tester);
    expect(await tester.runAsync(store.file.readAsString), before);
    expect(find.byType(DetailedRoutineScreen), findsNothing);
    await tap(tester, find.byKey(ValueKey('precise-clone-${program.id}')));
    await tester.tap(find.text('초안 바꾸기'));
    await settle(tester);
    final after = (await tester.runAsync(store.load))!;
    expect(after.detailedDraft!.id, isEmpty);
    expect(after.detailedDraft!.version, '1');
    expect(after.programs.single.toJson(), program.toJson());
    await tap(tester, find.text('변경 검토'));
    expect(find.text('프로그램 변경 검토'), findsNothing);
    expect(find.byType(DetailedRoutineScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
