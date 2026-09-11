import 'dart:convert';
import 'dart:io';

import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_program.dart';

/// Simulator에 바벨 프로그램 + 오늘 세션 완료 기록을 심는다.
Future<void> main() async {
  final support = Directory(
    '/Users/yudongheon/Library/Developer/CoreSimulator/Devices/'
    'E0F071B5-1CF2-4010-9C76-E0A9F0AFFA4F/data/Containers/Data/Application/'
    'D16F2BC1-2209-4CCD-9530-2A57462CDC3C/Library/Application Support',
  );
  final file = File('${support.path}/training-state.json');

  final catalog =
      jsonDecode(await File('assets/programs.json').readAsString())
          as Map<String, dynamic>;
  final programs = (catalog['programs'] as List)
      .map((v) => TrainingProgram.fromJson(v as Map<String, dynamic>))
      .toList();
  final program = programs.firstWhere(
    (p) => p.id == 'strength-barbell-basics-3d',
  );

  final today = DateTime.utc(2026, 9, 10);
  final plan = createActivePlan(
    id: 'seed-barbell-${today.millisecondsSinceEpoch}',
    program: program,
    startDate: today,
    weekdays: const [2, 4, 6], // 화·목·토 → 오늘(목)에 세션
    incrementKg: 2.5,
    baselines: {
      MainLift.squat: LiftBaseline(
        lift: MainLift.squat,
        kilograms: 100,
        source: BaselineSource.userEntered,
      ),
      MainLift.benchPress: LiftBaseline(
        lift: MainLift.benchPress,
        kilograms: 70,
        source: BaselineSource.userEntered,
      ),
    },
  );

  var state = TrainingAppState(onboarded: true, activePlan: plan);
  final session = plan.sessions.firstWhere((s) => s.date == today);
  final authored = program.orderedSessions.first;

  for (var e = 0; e < session.exercises.length; e++) {
    final lift = authored.exercises[e].mainLift;
    for (final set in session.exercises[e].sets.where((s) => s.isRequired)) {
      final target = state.effectiveTargetKg(set);
      final weight = target ??
          (lift == MainLift.squat
              ? 100.0
              : lift == MainLift.benchPress
              ? 70.0
              : 50.0);
      state = state.withSetActual(
        set.id,
        SetActual.completed(
          weight: weight,
          unit: WeightUnit.kg,
          repetitions: 5,
          rir: 2,
        ),
      );
    }
  }

  await LocalTrainingStore(file).save(state);

  stdout.writeln('plan=${plan.program.title}');
  stdout.writeln('session=${session.title} ${session.date}');
  stdout.writeln('completed=${state.setActuals.length}');
  for (var e = 0; e < session.exercises.length; e++) {
    stdout.writeln(
      '  ${session.exercises[e].name} mainLift=${authored.exercises[e].mainLift?.key}',
    );
  }
}
