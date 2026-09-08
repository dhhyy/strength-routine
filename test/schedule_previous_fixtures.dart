import 'package:strength_routine/domain/training_program.dart';

ActiveTrainingPlan scheduleFixture({
  String id = 'active',
  String programId = 'fixture',
  String version = '1',
  bool ambiguous = false,
}) => createActivePlan(
  id: id,
  program: TrainingProgram(
    id: programId,
    version: version,
    title: '일정 검증 프로그램',
    trainerName: '검증',
    description: '테스트 전용',
    weeks: 2,
    sessions: [
      for (var i = 0; i < 4; i++)
        ProgramSession(
          id: 'day-$i',
          week: i ~/ 2 + 1,
          dayOrder: i % 2 + 1,
          title: '검증 운동 ${i + 1}',
          exercises: [
            ProgramExercise(
              id: 'row',
              name: ambiguous && i == 0 ? '다른 장비 로우' : '시티드 케이블 로우',
              sets: [
                for (var n = 0; n < 2; n++)
                  ProgramSet(
                    id: 'work-$n',
                    repetitions: 8,
                    load: LoadPrescription.fixedKg(20),
                  ),
              ],
            ),
          ],
        ),
    ],
  ),
  startDate: DateTime.utc(2026, 9, 7),
  weekdays: [1, 4],
  incrementKg: 1,
);
