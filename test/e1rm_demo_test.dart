import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/demo/e1rm_demo.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_program.dart';

void main() {
  test('스테이징 웹이고 계획이 없거나 데모면 시드', () {
    expect(
      shouldSeedStagingE1rmDemo(
        isStaging: true,
        isWeb: true,
        activePlan: null,
      ),
      isTrue,
    );
    expect(
      shouldSeedStagingE1rmDemo(
        isStaging: true,
        isWeb: false,
        activePlan: null,
      ),
      isFalse,
    );
    final demoPlan = buildE1rmDemo(now: DateTime(2026, 9, 17)).state.activePlan;
    expect(
      shouldSeedStagingE1rmDemo(
        isStaging: true,
        isWeb: true,
        activePlan: demoPlan,
      ),
      isTrue,
    );
  });

  test('가상 데모는 6주 12세션을 모두 기록하고 마감한다', () {
    final now = DateTime(2026, 9, 17);
    final demo = buildE1rmDemo(now: now);
    final plan = demo.state.activePlan!;
    expect(plan.program.weeks, 6);
    expect(plan.sessions, hasLength(12));
    expect(plan.sessions.map((s) => s.week).toSet(), {1, 2, 3, 4, 5, 6});
    expect(demo.workingMax[MainLift.benchPress]?.kilograms, 100);

    for (final session in plan.sessions) {
      expect(demo.state.isSessionClosed(session.id), isTrue);
      for (final exercise in session.exercises) {
        for (final set in exercise.sets.where((s) => s.isRequired)) {
          expect(demo.state.setActuals[set.id]?.status, SetActualStatus.completed);
          expect(demo.state.setActuals[set.id]?.rir, 1);
          expect(demo.state.setActuals[set.id]?.performedDate, session.date);
          expect(demo.state.effectiveTargetKg(set), isNotNull);
        }
      }
    }
  });
}
