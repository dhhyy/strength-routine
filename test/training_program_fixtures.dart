import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_program.dart';

// 산술·저장 검증용 합성 데이터. 사용자용 프로그램 카탈로그가 아니다.
TrainingProgram fixtureProgram({String version = 'test-v1'}) => TrainingProgram(
  id: 'fixture',
  version: version,
  title: 'Test fixture',
  trainerName: 'Test',
  description: 'Synthetic test data only',
  weeks: 2,
  sessions: [
    for (var week = 1; week <= 2; week++)
      for (var order = 1; order <= 2; order++)
        ProgramSession(
          id: 'w${week}d$order',
          week: week,
          dayOrder: order,
          title: 'Session $week/$order',
          exercises: [
            ProgramExercise(
              id: 'exercise',
              name: 'Fixture movement',
              mainLift: MainLift.squat,
              sets: [
                ProgramSet(
                  id: 'fixed',
                  repetitions: 5,
                  rir: 2,
                  load: LoadPrescription.fixedKg(101),
                ),
                ProgramSet(
                  id: 'percent',
                  repetitions: 3,
                  load: LoadPrescription.percentOfBaseline(MainLift.squat, 77),
                ),
                ProgramSet(
                  id: 'manual',
                  repetitions: 8,
                  isRequired: false,
                  load: const LoadPrescription.manual(),
                ),
              ],
            ),
          ],
        ),
  ],
);

ActiveTrainingPlan fixturePlan({String id = 'plan-1'}) => createActivePlan(
  id: id,
  program: fixtureProgram(),
  startDate: DateTime.utc(2026, 9, 9),
  weekdays: [3, 1],
  incrementKg: 2.5,
  baselines: {
    MainLift.squat: LiftBaseline(
      lift: MainLift.squat,
      kilograms: 120,
      source: BaselineSource.userEntered,
    ),
  },
);
