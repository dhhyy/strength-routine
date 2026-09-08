import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_program.dart';

/// Synthetic acceptance data. Dates are fixed only at the first QA installation.
TrainingAppState createDeviceQaState(DateTime today) {
  final date = calendarDate(today);
  final program = TrainingProgram(
    id: 'device-qa',
    version: 'qa-2026-09-08',
    title: '기기 검증 전용 프로그램',
    trainerName: '합성 검증 데이터',
    description: '기록·복원·조정 기능을 시험하는 데이터입니다. 실제 운동 처방이 아닙니다.',
    weeks: 6,
    sessions: [
      for (var week = 1; week <= 6; week++)
        ProgramSession(
          id: 'week-$week',
          week: week,
          dayOrder: 1,
          title: '저장·복원 검증 $week',
          exercises: [
            ProgramExercise(
              id: 'qa-squat',
              name: '스쿼트 · QA',
              mainLift: MainLift.squat,
              sets: [
                for (var set = 1; set <= 2; set++)
                  ProgramSet(
                    id: 'set-$set',
                    repetitions: 5,
                    rir: 3,
                    load: LoadPrescription.fixedKg(60),
                  ),
              ],
            ),
          ],
        ),
    ],
  );
  final plan = createActivePlan(
    id: 'device-qa-plan',
    program: program,
    startDate: date.subtract(const Duration(days: 21)),
    weekdays: [date.weekday],
    incrementKg: 2.5,
  );
  var state = TrainingAppState(onboarded: true).withActivePlan(plan);
  for (final session in plan.sessions.take(3)) {
    for (final set in session.exercises.single.sets) {
      state = state.withSetActual(
        set.id,
        SetActual.completed(
          weight: 60,
          unit: WeightUnit.kg,
          repetitions: 5,
          rir: 1,
        ),
      );
    }
  }
  return state;
}
