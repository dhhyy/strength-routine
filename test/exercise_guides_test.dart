import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/domain/exercise_guides.dart';

void main() {
  test(
    'every actual bundled exercise has one complete offline guide',
    () async {
      final json =
          jsonDecode(await File('assets/programs.json').readAsString()) as Map;
      final names = <String>{};
      for (final program in json['programs']) {
        for (final session in program['sessions']) {
          for (final exercise in session['exercises']) {
            names.add(exercise['name'] as String);
          }
        }
      }
      expect(names, hasLength(24));
      expect(exerciseGuides, hasLength(24));
      for (final name in names) {
        final guide = guideForExercise(name);
        expect(guide, isNotNull, reason: name);
        for (final text in [
          guide!.setup,
          guide.movement,
          guide.check,
          guide.equipment,
        ]) {
          expect(text, isNotEmpty);
        }
      }
    },
  );
  test(
    'aliases are explicit unambiguous and never fuzzy exercise identity',
    () {
      final aliases = <String>{};
      for (final guide in exerciseGuides) {
        for (final name in [guide.name, ...guide.aliases]) {
          expect(aliases.add(name.toLowerCase()), isTrue, reason: name);
          expect(guideForExercise(' $name '), same(guide));
        }
      }
      expect(guideForExercise('랫풀다운')!.id, 'lat-pulldown');
      expect(guideForExercise('스쿼트'), isNull);
      expect(guideForExercise('머신 스쿼트'), isNull);
      expect(guideForExercise('덤벨 벤치프레스 변형'), isNull);
    },
  );
  test(
    'search filters names aliases and equipment without inventing results',
    () {
      expect(searchExerciseGuides('Romanian'), hasLength(2));
      expect(searchExerciseGuides('평벤치').single.id, 'dumbbell-bench');
      expect(searchExerciseGuides('미등록 운동'), isEmpty);
      expect(searchExerciseGuides(''), hasLength(24));
    },
  );
  test(
    'source links use reviewed primary publishers and glossary covers app meanings',
    () {
      const hosts = {
        'www.acefitness.org',
        'www.nasm.org',
        'www.muscleandstrength.com',
        'repfitness.com',
        'www.strengthlog.com',
      };
      for (final guide in exerciseGuides) {
        final uri = Uri.parse(guide.sourceUrl);
        expect(uri.scheme, 'https');
        expect(hosts, contains(uri.host));
        expect(uri.path.length, greaterThan(1));
      }
      expect(trainingGlossary, hasLength(9));
      expect(
        trainingGlossary.firstWhere((e) => e.term == 'AMRAP').description,
        contains('최소 합격선이 아니'),
      );
      expect(
        trainingGlossary.firstWhere((e) => e.term == '반복 범위').description,
        contains('하한'),
      );
    },
  );
}
