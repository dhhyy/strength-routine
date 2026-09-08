import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_program.dart';

// 추세·감량 검증용 합성 데이터이며 사용자 프로그램이 아니다.
final insightsToday = DateTime.utc(2026, 8, 17);

ActiveTrainingPlan insightsPlan({
  String id = 'insights-plan',
  double target = 100,
  double increment = 2.5,
  bool renameThird = false,
}) => createActivePlan(
  id: id,
  program: TrainingProgram(
    id: 'insights-fixture',
    version: 'test-v1',
    title: '검증용 프로그램',
    trainerName: '테스트',
    description: '합성 데이터',
    weeks: 6,
    sessions: [
      for (var week = 1; week <= 6; week++)
        ProgramSession(
          id: 'week-$week',
          week: week,
          dayOrder: 1,
          title: '$week주차',
          exercises: [
            ProgramExercise(
              id: 'back-squat',
              name: renameThird && week == 3 ? '다른 스쿼트' : '바벨 백스쿼트',
              mainLift: MainLift.squat,
              sets: [
                for (var set = 1; set <= 2; set++)
                  ProgramSet(
                    id: 'set-$set',
                    repetitions: 5,
                    rir: 2,
                    load: LoadPrescription.fixedKg(target),
                  ),
                ProgramSet(
                  id: 'manual',
                  repetitions: 5,
                  rir: 2,
                  isRequired: false,
                  load: const LoadPrescription.manual(),
                ),
              ],
            ),
          ],
        ),
    ],
  ),
  startDate: DateTime.utc(2026, 8, 3),
  weekdays: [1],
  incrementKg: increment,
);

TrainingAppState insightsState({
  ActiveTrainingPlan? plan,
  int completedSessions = 3,
}) {
  final active = plan ?? insightsPlan();
  var state = TrainingAppState(onboarded: true, activePlan: active);
  for (final session in active.sessions.take(completedSessions)) {
    for (final set in session.exercises.single.sets.where(
      (s) => s.isRequired,
    )) {
      state = state.withSetActual(
        set.id,
        SetActual.completed(
          weight: set.targetKg!,
          unit: WeightUnit.kg,
          repetitions: 5,
          rir: 1,
        ),
      );
    }
  }
  return state;
}
