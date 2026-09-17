import '../domain/e1rm.dart';
import '../domain/recent_lift_record.dart';
import '../domain/training_program.dart';
import '../domain/working_max.dart';
import '../engine/engine.dart';

const kDemoWorkingMaxKg = <MainLift, double>{
  MainLift.squat: 140,
  MainLift.benchPress: 100,
  MainLift.deadlift: 180,
  MainLift.overheadPress: 62.5,
};

final class E1rmDemoBundle {
  const E1rmDemoBundle({required this.state, required this.workingMax});
  final TrainingAppState state;
  final WorkingMaxState workingMax;
}

/// 스테이징 웹에만 빈 저장소일 때 심는다. 이미 계획이 있으면 덮지 않는다.
bool shouldSeedStagingE1rmDemo({
  required bool isStaging,
  required bool isWeb,
  required ActiveTrainingPlan? activePlan,
}) => isStaging && isWeb && activePlan == null;

/// 오늘 세션은 비워 두고, 지난 세션은 RIR 1로 채워 처방 kg와 D5 제안을 보여 준다.
E1rmDemoBundle buildE1rmDemo({required DateTime now}) {
  final today = calendarDate(now);
  final monday = _lastWeekday(today, DateTime.monday);
  final start = monday.subtract(const Duration(days: 14));

  final started = strengthEngine.run(
    StartPlanCommand(
      id: 'e1rm-demo',
      program: demoE1rmProgram(),
      startDate: start,
      weekdays: const [DateTime.monday, DateTime.thursday],
      incrementKg: 2.5,
      baselines: {
        for (final lift in MainLift.values)
          lift: LiftBaseline(
            lift: lift,
            kilograms: kDemoWorkingMaxKg[lift]!,
            source: BaselineSource.workingMax,
          ),
      },
    ),
  );
  if (started is! EngineSuccess || started.plan == null) {
    throw StateError(
      started is EngineFailure ? started.message : 'e1RM 데모 계획을 만들지 못했어요.',
    );
  }
  final plan = started.plan!;

  var state = TrainingAppState(
    onboarded: true,
    recentRecords: [
      for (final lift in MainLift.values)
        RecentLiftRecord(
          lift: lift,
          weight: _sourceWeight(kDemoWorkingMaxKg[lift]!),
          unit: WeightUnit.kg,
          repetitions: 5,
          date: monday,
          rir: 1,
        ),
    ],
    activePlan: plan,
  );

  for (final session in plan.sessions) {
    if (!session.date.isBefore(today)) continue;
    for (final exercise in session.exercises) {
      for (final set in exercise.sets.where((s) => s.isRequired)) {
        final kg = state.effectiveTargetKg(set);
        if (kg == null) continue;
        state = state.withSetActual(
          set.id,
          SetActual.completed(
            weight: kg,
            unit: WeightUnit.kg,
            repetitions: set.repetitions,
            rir: 1,
          ),
        );
      }
    }
  }

  final adopted = DateTime.utc(today.year, today.month, today.day);
  var working = const WorkingMaxState();
  for (final lift in MainLift.values) {
    working = working.adopt(
      WorkingMax(
        lift: lift,
        kilograms: kDemoWorkingMaxKg[lift]!,
        adoptedAt: adopted,
        policyId: e1rmPolicyId,
        sourceWeightKg: _sourceWeight(kDemoWorkingMaxKg[lift]!),
        sourceRepetitions: 5,
        sourceNote: '가상 데모',
      ),
    );
  }
  return E1rmDemoBundle(state: state, workingMax: working);
}

TrainingProgram demoE1rmProgram() {
  ProgramSet work(String id, MainLift lift, double percent) => ProgramSet(
    id: id,
    repetitions: 5,
    rir: 2,
    load: LoadPrescription.percentOfBaseline(lift, percent),
  );

  ProgramSession session({
    required int week,
    required int dayOrder,
    required String title,
    required List<ProgramExercise> exercises,
  }) => ProgramSession(
    id: 'w${week}d$dayOrder',
    week: week,
    dayOrder: dayOrder,
    title: title,
    exercises: exercises,
  );

  return TrainingProgram(
    id: 'e1rm-demo-virtual',
    version: 'demo-v1',
    title: '가상 e1RM 처방 데모',
    trainerName: '데모',
    description:
        '스테이징 확인용. 스쿼트 140·벤치 100·데드 180·OHP 62.5kg working max의 '
        '70/75/80%가 세트 목표다. 지난 3주는 RIR 1로 기록해 D5 감량 제안이 난다.',
    weeks: 6,
    sessions: [
      for (var week = 1; week <= 6; week++) ...[
        session(
          week: week,
          dayOrder: 1,
          title: '$week주차 · 하체',
          exercises: [
            ProgramExercise(
              id: 'squat',
              name: '바벨 백스쿼트',
              mainLift: MainLift.squat,
              sets: [
                work('s70', MainLift.squat, 70),
                work('s75', MainLift.squat, 75),
                work('s80', MainLift.squat, 80),
              ],
            ),
            ProgramExercise(
              id: 'deadlift',
              name: '바벨 데드리프트',
              mainLift: MainLift.deadlift,
              sets: [
                work('d70', MainLift.deadlift, 70),
                work('d75', MainLift.deadlift, 75),
              ],
            ),
          ],
        ),
        session(
          week: week,
          dayOrder: 2,
          title: '$week주차 · 상체',
          exercises: [
            ProgramExercise(
              id: 'bench',
              name: '바벨 벤치프레스',
              mainLift: MainLift.benchPress,
              sets: [
                work('b70', MainLift.benchPress, 70),
                work('b75', MainLift.benchPress, 75),
                work('b80', MainLift.benchPress, 80),
              ],
            ),
            ProgramExercise(
              id: 'ohp',
              name: '오버헤드 프레스',
              mainLift: MainLift.overheadPress,
              sets: [
                work('o70', MainLift.overheadPress, 70),
                work('o75', MainLift.overheadPress, 75),
              ],
            ),
          ],
        ),
      ],
    ],
  );
}

DateTime _lastWeekday(DateTime day, int weekday) {
  var cursor = calendarDate(day);
  while (cursor.weekday != weekday) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return cursor;
}

double _sourceWeight(double e1rm) => roundE1rmKg(e1rm / (1 + 5 / 30));
