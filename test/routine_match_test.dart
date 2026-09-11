import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/routine_match.dart';
import 'package:strength_routine/domain/training_program.dart';

TrainingProgram _program(String id, {int sessionsPerWeek = 3}) =>
    TrainingProgram(
      id: id,
      version: 'test',
      title: id,
      trainerName: 't',
      description: '',
      weeks: 1,
      sessions: [
        for (var d = 1; d <= sessionsPerWeek; d++)
          ProgramSession(
            id: 'd$d',
            week: 1,
            dayOrder: d,
            title: 's$d',
            exercises: [
              ProgramExercise(
                id: 'ex',
                name: '스쿼트',
                mainLift: MainLift.squat,
                sets: [
                  ProgramSet(
                    id: '1',
                    repetitions: 5,
                    load: LoadPrescription.percentOfBaseline(
                      MainLift.squat,
                      70,
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );

void main() {
  test('목표×일수 매칭은 표에 있는 템플릿만 고른다', () {
    final programs = [
      _program('strength-barbell-basics-3d'),
      _program('strength-full-body-2d', sessionsPerWeek: 2),
      _program('missing-id'),
    ];
    expect(
      matchProgram(
        goal: RoutineGoal.strength,
        daysPerWeek: 3,
        programs: programs,
      )?.id,
      'strength-barbell-basics-3d',
    );
    expect(
      matchProgram(
        goal: RoutineGoal.habit,
        daysPerWeek: 4,
        programs: [
          _program('strength-upper-lower-4d', sessionsPerWeek: 4),
        ],
      )?.id,
      'strength-upper-lower-4d',
    );
    expect(
      matchProgram(
        goal: RoutineGoal.strength,
        daysPerWeek: 3,
        programs: [_program('other')],
      ),
      isNull,
      reason: '표의 id가 카탈로그에 없으면 생성 불가',
    );
  });

  test('기준 중량 맵은 누락·비양수를 거부한다', () {
    expect(
      () => baselinesForGenerator(
        lifts: {MainLift.squat},
        kilograms: const {},
      ),
      throwsFormatException,
    );
    final map = baselinesForGenerator(
      lifts: {MainLift.squat},
      kilograms: {MainLift.squat: 100},
    );
    expect(map[MainLift.squat]!.source, BaselineSource.workingMax);
    expect(map[MainLift.squat]!.kilograms, 100);
  });
}
