import 'dart:io';

import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/data/local_working_max_store.dart';
import 'package:strength_routine/demo/e1rm_demo.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_program.dart';

/// iPhone 16 시뮬레이터에 가상 e1RM·% 루틴·3주 기록을 심는다.
/// 웹 스테이징은 앱이 빈 저장소일 때 같은 데모를 넣는다.
const _deviceId = '2A9EBE8E-1D16-472B-8BE8-9A69C89B48D6';
const _bundleId = 'tech.vibe.strengthRoutine';

Future<void> main() async {
  final data = (await Process.run('xcrun', [
    'simctl',
    'get_app_container',
    _deviceId,
    _bundleId,
    'data',
  ])).stdout.toString().trim();
  if (data.isEmpty || data.contains('error')) {
    stderr.writeln('iPhone 16에 앱이 없습니다. 먼저 시뮬레이터로 한 번 실행하세요.');
    exitCode = 1;
    return;
  }
  final support = Directory('$data/Library/Application Support');
  await support.create(recursive: true);

  final today = calendarDate(DateTime.now());
  final demo = buildE1rmDemo(now: today);

  await LocalTrainingStore(
    File('${support.path}/training-state.json'),
  ).save(demo.state);
  await LocalWorkingMaxStore(
    File('${support.path}/working-max.json'),
  ).save(demo.workingMax);

  final plan = demo.state.activePlan!;
  stdout.writeln('support=${support.path}');
  stdout.writeln('today=${isoDate(today)}');
  stdout.writeln(
    'working-max squat=${kDemoWorkingMaxKg[MainLift.squat]} '
    'bench=${kDemoWorkingMaxKg[MainLift.benchPress]} '
    'dead=${kDemoWorkingMaxKg[MainLift.deadlift]} '
    'ohp=${kDemoWorkingMaxKg[MainLift.overheadPress]}',
  );
  for (final session in plan.sessions) {
    final mark = session.date.isBefore(today)
        ? 'done'
        : session.date == today
        ? 'TODAY'
        : 'future';
    stdout.writeln('${isoDate(session.date)} $mark ${session.title}');
    if (session.date == today) {
      for (final exercise in session.exercises) {
        for (final set in exercise.sets) {
          stdout.writeln(
            '  ${exercise.name} → ${demo.state.effectiveTargetKg(set)}kg',
          );
        }
      }
    }
  }
}
