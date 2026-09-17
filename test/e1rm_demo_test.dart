import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/demo/e1rm_demo.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_program.dart';

void main() {
  test('스테이징 웹이고 계획이 없을 때만 시드', () {
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
    expect(
      shouldSeedStagingE1rmDemo(
        isStaging: false,
        isWeb: true,
        activePlan: null,
      ),
      isFalse,
    );
  });

  test('가상 데모는 오늘 세션을 비우고 과거는 완료한다', () {
    final now = DateTime(2026, 9, 17);
    final demo = buildE1rmDemo(now: now);
    final plan = demo.state.activePlan!;
    expect(plan.program.id, 'e1rm-demo-virtual');
    expect(demo.workingMax[MainLift.benchPress]?.kilograms, 100);

    final today = calendarDate(now);
    final todaySessions = plan.sessions.where((s) => s.date == today);
    expect(todaySessions, isNotEmpty);
    for (final session in todaySessions) {
      for (final exercise in session.exercises) {
        for (final set in exercise.sets.where((s) => s.isRequired)) {
          expect(demo.state.setActuals[set.id], isNull);
          expect(demo.state.effectiveTargetKg(set), isNotNull);
        }
      }
    }

    final pastRequired = plan.sessions
        .where((s) => s.date.isBefore(today))
        .expand((s) => s.exercises)
        .expand((e) => e.sets.where((s) => s.isRequired));
    expect(pastRequired, isNotEmpty);
    for (final set in pastRequired) {
      expect(demo.state.setActuals[set.id]?.status, SetActualStatus.completed);
      expect(demo.state.setActuals[set.id]?.rir, 1);
    }
  });
}
