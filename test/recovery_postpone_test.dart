import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/domain/postpone.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/recovery_block.dart';
import 'package:strength_routine/domain/training_program.dart';

TrainingProgram _sampleProgram({int weeks = 6}) => TrainingProgram(
  id: 'sample',
  version: 'v1',
  title: '샘플',
  trainerName: 't',
  description: '',
  weeks: weeks,
  sessions: [
    for (var week = 1; week <= weeks; week++)
      ProgramSession(
        id: 'w$week',
        week: week,
        dayOrder: 1,
        title: '$week주',
        exercises: [
          ProgramExercise(
            id: 'squat',
            name: '스쿼트',
            mainLift: MainLift.squat,
            sets: [
              ProgramSet(
                id: 's1',
                repetitions: 5,
                load: LoadPrescription.fixedKg(100),
              ),
            ],
          ),
          ProgramExercise(
            id: 'leg-curl',
            name: '레그컬',
            sets: [
              ProgramSet(
                id: 'a1',
                repetitions: 10,
                load: const LoadPrescription.manual(),
              ),
              ProgramSet(
                id: 'a2',
                repetitions: 10,
                load: const LoadPrescription.manual(),
              ),
              ProgramSet(
                id: 'a3',
                repetitions: 10,
                load: const LoadPrescription.manual(),
              ),
            ],
          ),
        ],
      ),
  ],
);

void main() {
  test('악세 회복 상한은 메인 리프트를 건드리지 않고 끝 세트를 비필수로 만든다', () {
    final capped = applyAccessorySetCap(_sampleProgram(), dropCount: 2);
    final accessory = capped.sessions.first.exercises
        .firstWhere((e) => e.id == 'leg-curl');
    expect(accessory.sets.where((s) => s.isRequired).length, 1);
    expect(
      capped.sessions.first.exercises.firstWhere((e) => e.id == 'squat').sets,
      hasLength(1),
    );
  });

  test('블록 프리셋은 앞 N주만 남긴다', () {
    final cut = takeFirstWeeks(_sampleProgram(weeks: 6), 4);
    expect(cut.weeks, 4);
    expect(cut.sessions, hasLength(4));
  });

  test('기록이 없는 오늘 세션은 다음 훈련일로 미룰 수 있다', () {
    final plan = createActivePlan(
      id: 'p1',
      program: _sampleProgram(weeks: 2),
      startDate: DateTime.utc(2026, 9, 7), // Mon
      weekdays: const [1],
      incrementKg: 2.5,
    );
    final asOf = DateTime.utc(2026, 9, 7);
    final state = TrainingAppState(onboarded: true, activePlan: plan);
    final first = plan.sessions.first;
    expect(first.date, DateTime.utc(2026, 9, 7));
    final next = state.withPostponedSession(first.id, asOf: asOf);
    expect(next.activePlan!.sessions.first.date, DateTime.utc(2026, 9, 14));
    expect(
      next.activePlan!.sessions.last.date.isAfter(
        next.activePlan!.sessions.first.date,
      ),
      isTrue,
    );
  });
}
