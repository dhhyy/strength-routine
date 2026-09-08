import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/admin/admin_program_store.dart';
import 'package:strength_routine/admin/detailed_routine.dart';
import 'package:strength_routine/admin/detailed_routine_screen.dart';
import 'package:strength_routine/admin/routine_builder.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_program.dart';
import 'package:strength_routine/theme.dart';

import 'training_program_fixtures.dart';

void main() {
  const renderDir = String.fromEnvironment('DETAILED_ADMIN_RENDER_DIR');
  var fontsLoaded = false;
  Future<void> pump(
    WidgetTester tester, {
    DetailedRoutineDraft? draft,
    List<TrainingProgram>? catalog,
    List<TrainingProgram> versionHistory = const [],
    Future<bool> Function(DetailedRoutineDraft)? onDraft,
    Future<bool> Function(TrainingProgram, DetailedRoutineDraft)? onProgram,
    double width = 375,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    if (renderDir.isNotEmpty && !fontsLoaded) {
      await tester.runAsync(() async {
        for (final family in ['IBM Plex Sans KR', 'IBM Plex Mono']) {
          final stem = family == 'IBM Plex Sans KR'
              ? 'IBMPlexSansKR'
              : 'IBMPlexMono';
          final loader = FontLoader(family);
          for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
            loader.addFont(rootBundle.load('assets/fonts/$stem-$weight.ttf'));
          }
          await loader.load();
        }
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
      fontsLoaded = true;
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: buildConsoleTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(
            key: const ValueKey('detailed-capture'),
            child: child!,
          ),
        ),
        home: DetailedRoutineScreen(
          initialDraft:
              draft ?? DetailedRoutineDraft.fromProgram(fixtureProgram()),
          catalog: catalog ?? [],
          versionHistory: versionHistory,
          onDraftChanged: onDraft ?? (_) async => true,
          onSaveProgram: onProgram ?? (_, _) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String suffix) => find.byWidgetPredicate(
    (widget) =>
        widget is TextFormField && widget.key.toString().contains('$suffix\''),
  );

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    scrollable.position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 100,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await reveal(tester, finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String suffix, String value) async {
    await reveal(tester, field(suffix));
    await tester.enterText(field(suffix), value);
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (renderDir.isEmpty) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('detailed-capture')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(renderDir).create(recursive: true);
      await File(
        '$renderDir/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('기존 혼합 처방에서 2주차 2세트만 바꾸고 전체 검토 후 저장한다', (tester) async {
    final old = fixtureProgram();
    final original = jsonEncode(old.toJson());
    TrainingProgram? saved;
    DetailedRoutineDraft? savedDraft;
    await pump(
      tester,
      catalog: [old],
      onProgram: (program, draft) async {
        saved = program;
        savedDraft = draft;
        return true;
      },
    );
    await tap(tester, find.text('프로그램 정보'));
    await enter(tester, 'version', 'test-v2');
    await tap(tester, find.byKey(const ValueKey('detail-week-1')));
    await enter(tester, 'w1-s0-e0-t1-reps', '9');
    await tap(tester, find.text('변경 검토'));
    expect(find.text('프로그램 변경 검토'), findsOneWidget);
    expect(find.text('세트 추가 0 · 변경 1 · 삭제 0'), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('review-session-w2d1')));
    expect(find.textContaining('2세트 · 9회'), findsOneWidget);
    expect(find.textContaining('기존 · 3회'), findsOneWidget);
    await capture(tester, 'review-mobile');
    await tap(tester, find.text('검토한 프로그램 저장'));
    expect(saved!.sessions[2].exercises.single.sets[1].repetitions, 9);
    expect(saved!.sessions[0].toJson(), old.sessions[0].toJson());
    expect(saved!.sessions[2].exercises.single.sets[2].isRequired, false);
    expect(
      savedDraft!.weeks[1].sessions[0].exercises.single.sets[1].repetitions,
      '9',
    );
    expect(jsonEncode(old.toJson()), original);
    expect(tester.takeException(), isNull);
  });

  testWidgets('주차 덮어쓰기 취소는 입력을 보존하고 복사 뒤 되돌리기와 다시 실행이 독립적이다', (tester) async {
    final draft = DetailedRoutineDraft.fromProgram(fixtureProgram());
    draft.weeks[1].sessions[0].exercises[0].sets[1].repetitions = '12';
    DetailedRoutineDraft? persisted;
    var saves = 0;
    await pump(
      tester,
      draft: draft,
      onDraft: (value) async {
        persisted = value.copy();
        saves++;
        return true;
      },
    );
    await tap(tester, find.text('다른 주차에 덮어쓰기'));
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(saves, 0);
    await tap(tester, find.text('다른 주차에 덮어쓰기'));
    await tester.tap(find.text('덮어쓰기'));
    await tester.pumpAndSettle();
    expect(persisted!.weeks[1].sessions[0].id, 'w2d1');
    expect(
      persisted!.weeks[1].sessions[0].exercises[0].sets[1].repetitions,
      '3',
    );
    await tap(tester, find.byTooltip('되돌리기'));
    expect(
      persisted!.weeks[1].sessions[0].exercises[0].sets[1].repetitions,
      '12',
    );
    await tap(tester, find.byTooltip('다시 실행'));
    expect(
      persisted!.weeks[1].sessions[0].exercises[0].sets[1].repetitions,
      '3',
    );
    await tap(tester, find.byKey(const ValueKey('detail-week-1')));
    await enter(tester, 'w1-s0-e0-t1-reps', '7');
    expect(
      persisted!.weeks[0].sessions[0].exercises[0].sets[1].repetitions,
      '3',
    );
    expect(draft.weeks[1].sessions[0].exercises[0].sets[1].repetitions, '12');
    expect(tester.takeException(), isNull);
  });

  testWidgets('잘못된 원문과 저장 실패를 보존하고 재시도 후 경로 오류를 안내한다', (tester) async {
    var fail = true;
    DetailedRoutineDraft? latest;
    await pump(
      tester,
      onDraft: (value) async {
        latest = value.copy();
        return !fail;
      },
    );
    await enter(tester, 'w0-s0-e0-t0-reps', ' 3.. ');
    expect(
      latest!.weeks[0].sessions[0].exercises[0].sets[0].repetitions,
      ' 3.. ',
    );
    await reveal(tester, find.text('초안 저장 실패'));
    expect(find.text('초안 저장 실패'), findsOneWidget);
    fail = false;
    await tap(tester, find.text('저장 재시도'));
    await tap(tester, find.text('변경 검토'));
    expect(find.textContaining('반복'), findsWidgets);
    expect(find.text('프로그램 변경 검토'), findsNothing);
    expect(
      latest!.weeks[0].sessions[0].exercises[0].sets[0].repetitions,
      ' 3.. ',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('같은 ID와 버전은 카탈로그 교체 전에 차단한다', (tester) async {
    var saves = 0;
    await pump(
      tester,
      catalog: [fixtureProgram()],
      onProgram: (_, _) async {
        saves++;
        return true;
      },
    );
    await tap(tester, find.text('변경 검토'));
    expect(find.textContaining('같은 ID·버전은 저장할 수 없습니다.'), findsOneWidget);
    expect(saves, 0);
    expect(find.text('프로그램 변경 검토'), findsNothing);
  });

  testWidgets('카탈로그 저장 실패는 동일 검토본으로 재시도하고 성공 뒤 편집기로 돌아온다', (tester) async {
    final attempts = <String>[];
    await pump(
      tester,
      onProgram: (value, _) async {
        attempts.add(jsonEncode(value.toJson()));
        return attempts.length > 1;
      },
    );
    await tap(tester, find.text('변경 검토'));
    await tap(tester, find.text('검토한 프로그램 저장'));
    expect(find.text('프로그램 변경 검토'), findsOneWidget);
    expect(find.textContaining('카탈로그에 저장하지 못했습니다.'), findsOneWidget);
    await capture(tester, 'save-failure-mobile');
    await tap(tester, find.text('카탈로그 저장 재시도'));
    expect(attempts, hasLength(2));
    expect(attempts[0], attempts[1]);
    expect(find.text('주차·세트 정밀 편집'), findsOneWidget);
  });

  for (final hasHistory in [false, true]) {
    testWidgets('초기 이력 $hasHistory: 연속 저장 뒤 원래·중간 버전을 검토 전에 차단한다', (
      tester,
    ) async {
      final original = fixtureProgram(version: '1');
      var workspace = AdminWorkspace(
        draft: RoutineBlueprint(),
        programs: [original],
      );
      if (hasHistory) {
        workspace = workspace.withProgram(fixtureProgram(version: '2'), null);
      }
      final originals = workspace
          .versionsFor(original.id)
          .map((program) => jsonEncode(program.toJson()))
          .toList();
      final firstVersion = hasHistory ? 3 : 2;
      var saveCalls = 0;
      DetailedRoutineDraft? lastDraft;
      await pump(
        tester,
        draft: DetailedRoutineDraft.fromProgram(workspace.programs.single)
          ..version = '$firstVersion',
        catalog: workspace.programs,
        versionHistory: workspace.versionHistory,
        width: 1200,
        onDraft: (draft) async {
          lastDraft = draft.copy();
          return true;
        },
        onProgram: (program, draft) async {
          saveCalls++;
          workspace = workspace.withProgram(program, draft);
          return true;
        },
      );
      await tap(tester, find.text('변경 검토'));
      await tap(tester, find.text('검토한 프로그램 저장'));
      Future<void> editMetadata(String key, String value) async {
        await reveal(tester, find.text('프로그램 정보'));
        final input = find.descendant(
          of: find.byKey(const ValueKey('detail-metadata')),
          matching: field(key),
        );
        if (input.evaluate().isEmpty) {
          await tap(tester, find.text('프로그램 정보'));
        }
        await reveal(tester, input);
        await tester.enterText(input, value);
        await tester.pumpAndSettle();
      }

      for (
        var version = firstVersion + 1;
        version <= firstVersion + 2;
        version++
      ) {
        await editMetadata('version', '$version');
        await tap(tester, find.text('변경 검토'));
        await tap(tester, find.text('검토한 프로그램 저장'));
      }
      expect(saveCalls, 3);
      final savedWorkspace = jsonEncode(workspace.toJson());
      for (final version in ['1', '$firstVersion', '${firstVersion + 1}']) {
        await editMetadata('version', version);
        await tap(tester, find.text('변경 검토'));
        expect(find.text('프로그램 변경 검토'), findsNothing);
        expect(find.textContaining('같은 ID·버전은 저장할 수 없습니다.'), findsOneWidget);
        expect(lastDraft!.version, version);
        expect(saveCalls, 3);
        expect(jsonEncode(workspace.toJson()), savedWorkspace);
      }
      expect(
        workspace
            .versionsFor(original.id)
            .take(originals.length)
            .map((program) => jsonEncode(program.toJson())),
        originals,
      );
      // 버전 문자열은 프로그램 ID별로 관리한다.
      await editMetadata('id', 'independent-program');
      await tap(tester, find.text('변경 검토'));
      expect(find.text('프로그램 변경 검토'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('검토 뒤 사용 버전 충돌은 저장 재시도 대신 원문 편집으로 돌아간다', (tester) async {
    var saveCalls = 0;
    await pump(
      tester,
      onProgram: (_, _) async {
        saveCalls++;
        throw const FormatException('이미 사용한 버전입니다. 새 버전을 입력해 주세요.');
      },
    );
    await tap(tester, find.text('변경 검토'));
    await tap(tester, find.text('검토한 프로그램 저장'));
    expect(find.text('이미 사용한 버전입니다. 새 버전을 입력해 주세요.'), findsOneWidget);
    expect(find.text('카탈로그 저장 재시도'), findsNothing);
    await reveal(tester, find.text('편집으로 돌아가기'));
    await capture(tester, 'version-conflict-mobile');
    await tap(tester, find.text('편집으로 돌아가기'));
    expect(find.text('주차·세트 정밀 편집'), findsOneWidget);
    await tap(tester, find.text('프로그램 정보'));
    expect(
      tester.widget<TextFormField>(field('version')).initialValue,
      'test-v1',
    );
    expect(saveCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('연속 입력 저장은 순서대로 진행하며 최신 초안 저장 전 검토를 막는다', (tester) async {
    final first = Completer<bool>();
    final saved = <String>[];
    await pump(
      tester,
      onDraft: (value) async {
        saved.add(value.weeks[0].sessions[0].exercises[0].sets[0].repetitions);
        return saved.length == 1 ? first.future : true;
      },
    );
    await reveal(tester, field('w0-s0-e0-t0-reps'));
    await tester.enterText(field('w0-s0-e0-t0-reps'), '6');
    await tester.pump();
    await tester.enterText(field('w0-s0-e0-t0-reps'), '7');
    await tester.pump();
    expect(saved, ['6']);
    first.complete(true);
    await tester.pumpAndSettle();
    expect(saved, ['6', '7']);
    await tap(tester, find.byTooltip('되돌리기'));
    expect(saved.last, '5');
    await tap(tester, find.byTooltip('다시 실행'));
    expect(saved.last, '7');
  });

  testWidgets('375 너비 큰 글자와 키보드에서도 세트 입력과 검토가 동작한다', (tester) async {
    await pump(tester, scale: 1.5);
    await capture(tester, 'editor-mobile-large');
    await enter(tester, 'w0-s0-e0-t1-reps', '8');
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();
    await tester.ensureVisible(field('w0-s0-e0-t1-reps'));
    await tester.pumpAndSettle();
    await capture(tester, 'set-keyboard-mobile-large');
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await tap(tester, find.text('변경 검토'));
    await capture(tester, 'review-mobile-large');
    expect(find.text('프로그램 변경 검토'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('1200 너비에서 세트 필수 여부와 순서를 바꾸어 검토한다', (tester) async {
    DetailedRoutineDraft? latest;
    await pump(
      tester,
      width: 1200,
      onDraft: (value) async {
        latest = value;
        return true;
      },
    );
    await capture(tester, 'editor-desktop');
    await tap(tester, find.byKey(const ValueKey('w0-s0-e0-t0-required')));
    expect(latest!.weeks[0].sessions[0].exercises[0].sets[0].isRequired, false);
    await tap(tester, find.byTooltip('세트 1 아래로 이동'));
    expect(latest!.weeks[0].sessions[0].exercises[0].sets[1].id, 'fixed');
    await reveal(tester, field('w0-s0-e0-t1-reps'));
    await capture(tester, 'sets-desktop');
    await tap(tester, find.text('변경 검토'));
    expect(find.text('세트 추가 12 · 변경 0 · 삭제 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('세트의 중량 기준은 운동 기록 종목과 독립적으로 바꾼다', (tester) async {
    DetailedRoutineDraft? latest;
    await pump(
      tester,
      onDraft: (value) async {
        latest = value;
        return true;
      },
    );
    final loadLift = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<String> &&
          widget.key.toString().contains('w0-s0-e0-t1-load-lift'),
    );
    await tap(tester, loadLift);
    await tester.tap(find.text('데드리프트').last);
    await tester.pumpAndSettle();
    final exercise = latest!.weeks[0].sessions[0].exercises[0];
    expect(exercise.mainLift, MainLift.squat);
    expect(exercise.sets[1].loadLift, MainLift.deadlift);
    expect(
      latest!.weeks[1].sessions[0].exercises[0].sets[1].loadLift,
      MainLift.squat,
    );
    await tap(tester, find.text('변경 검토'));
    await tap(tester, find.byKey(const ValueKey('review-session-w1d1')));
    expect(find.textContaining('데드리프트 기준 77%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('구분자가 포함된 ID도 검토의 세트 수와 기존 처방을 충돌시키지 않는다', (tester) async {
    final json =
        jsonDecode(jsonEncode(fixtureProgram().toJson()))
            as Map<String, dynamic>;
    json['sessions'][0]['id'] = 'a/b';
    json['sessions'][0]['exercises'][0]['id'] = 'c';
    json['sessions'][1]['id'] = 'a';
    json['sessions'][1]['exercises'][0]['id'] = 'b/c';
    final old = TrainingProgram.fromJson(json);
    final draft = DetailedRoutineDraft.fromProgram(old)..version = 'next';
    draft.weeks[0].sessions[0].exercises[0].sets[0].repetitions = '6';
    await pump(tester, draft: draft, catalog: [old]);
    await tap(tester, find.text('변경 검토'));
    expect(find.text('세트 추가 0 · 변경 1 · 삭제 0'), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('review-session-a/b')));
    expect(find.textContaining('1세트 · 6회'), findsOneWidget);
    expect(find.textContaining('기존 · 5회'), findsOneWidget);
  });

  testWidgets('빈 주차 초안은 원문을 덮어쓰지 않고 명시적으로 첫 구성을 추가한다', (tester) async {
    final draft = DetailedRoutineDraft(weeks: []);
    DetailedRoutineDraft? saved;
    await pump(
      tester,
      draft: draft,
      onDraft: (value) async {
        saved = value;
        return true;
      },
    );
    expect(find.text('주차가 비어 있어요'), findsOneWidget);
    expect(saved, isNull);
    await tap(tester, find.text('첫 주차 추가'));
    expect(draft.weeks, isEmpty);
    expect(saved!.weeks.single.sessions.single.id, 'session-1');
    expect(
      saved!.weeks.single.sessions.single.exercises.single.sets.single.id,
      'set-1',
    );
    expect(find.text('프로그램 정보'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
