import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/domain/deferrable_exercise.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';

void main() {
  test('mainLift가 있으면 이름과 무관하게 이월 가능', () {
    expect(
      isDeferrableExercise(name: '레그 프레스', lift: MainLift.squat),
      isTrue,
    );
  });

  test('빅4·풀업·딥스 이름만 이월 가능하고 보조·RDL은 불가', () {
    const allowed = [
      '스쿼트',
      '고블렛 스쿼트',
      '벤치프레스',
      '덤벨 벤치프레스',
      '데드리프트',
      '컨벤셔널 데드리프트',
      '오버헤드프레스',
      'OHP',
      '풀업',
      '턱걸이',
      '딥스',
    ];
    const blocked = [
      '레그 프레스',
      '머신 체스트 프레스',
      '시티드 케이블 로우',
      '덤벨 루마니안 데드리프트',
      '랫 풀다운',
      '크런치 (맨몸)',
      '시티드 레그 컬',
    ];
    for (final name in allowed) {
      expect(isDeferrableExercise(name: name), isTrue, reason: name);
    }
    for (final name in blocked) {
      expect(isDeferrableExercise(name: name), isFalse, reason: name);
    }
  });
}
