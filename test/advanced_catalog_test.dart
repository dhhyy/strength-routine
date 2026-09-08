import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/app/training_controller.dart';
import 'package:strength_routine/domain/training_program.dart';

import 'advanced_prescription_test.dart' show advancedProgram, deepJson;
import 'training_program_fixtures.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const asset = 'assets/programs.json';
  var reads = 0;

  void mockCatalog(Object catalog) {
    rootBundle.evict(asset);
    binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (
      message,
    ) async {
      expect(
        utf8.decode(
          message!.buffer.asUint8List(
            message.offsetInBytes,
            message.lengthInBytes,
          ),
        ),
        asset,
      );
      reads++;
      return ByteData.sublistView(
        Uint8List.fromList(utf8.encode(jsonEncode(catalog))),
      );
    });
  }

  setUp(() => reads = 0);
  tearDown(() {
    rootBundle.evict(asset);
    binding.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      null,
    );
  });

  test('실제 번들 리더는 카탈로그 v2의 고급 처방을 소비자 프로그램으로 읽는다', () async {
    final original = advancedProgram();
    mockCatalog({
      'schemaVersion': 2,
      'programs': [original.toJson()],
    });
    final programs = await loadBundledPrograms();
    expect(reads, 1);
    expect(programs.single.toJson(), original.toJson());
    expect(programs.single.hasAdvancedPrescriptions, isTrue);
    expect(() => programs.clear(), throwsUnsupportedError);
    final plan = createActivePlan(
      id: 'catalog-v2',
      program: programs.single,
      startDate: DateTime.utc(2026, 9, 7),
      weekdays: [1],
      incrementKg: 2.5,
    );
    expect(
      plan.sessions.first.executionSets.map(
        (entry) => '${entry.exercise.name}:${entry.number}',
      ),
      ['before:1', 'a:1', 'b:1', 'a:2', 'b:2', 'b:3', 'after:1'],
    );
  });

  test('실제 번들 리더는 기존 v1 프로그램과 고급 값 없는 v2를 그대로 읽는다', () async {
    final original = fixtureProgram();
    for (final version in [1, 2]) {
      mockCatalog({
        'schemaVersion': version,
        'programs': [original.toJson()],
      });
      expect((await loadBundledPrograms()).single.toJson(), original.toJson());
    }
    expect(reads, 2);
  });

  test('v1에 고급 필드가 있으면 false·null 기본값이어도 소비자 로딩을 거부한다', () async {
    for (final field in ['restSeconds', 'tempo', 'isAmrap', 'supersetGroup']) {
      final program = deepJson(fixtureProgram().toJson());
      final exercise = program['sessions'][0]['exercises'][0] as Map;
      final target = field == 'supersetGroup'
          ? exercise
          : (exercise['sets'] as List).first as Map;
      target[field] = field == 'isAmrap' ? false : null;
      mockCatalog({
        'schemaVersion': 1,
        'programs': [program],
      });
      await expectLater(loadBundledPrograms(), throwsFormatException);
    }
  });

  test('번들 v2는 잘못된 처방·슈퍼세트·중복 프로그램을 거부한다', () async {
    final original = advancedProgram().toJson();
    final invalidRest = deepJson(original);
    invalidRest['sessions'][0]['exercises'][0]['sets'][0]['restSeconds'] = 3601;
    final invalidGroup = deepJson(original);
    invalidGroup['sessions'][0]['exercises'][2].remove('supersetGroup');
    final invalidType = deepJson(original);
    invalidType['sessions'][0]['exercises'][0]['sets'][0]['isAmrap'] = 'true';
    for (final invalid in [invalidRest, invalidGroup]) {
      mockCatalog({
        'schemaVersion': 2,
        'programs': [invalid],
      });
      await expectLater(loadBundledPrograms(), throwsFormatException);
    }
    mockCatalog({
      'schemaVersion': 2,
      'programs': [invalidType],
    });
    await expectLater(loadBundledPrograms(), throwsA(isA<TypeError>()));
    mockCatalog({
      'schemaVersion': 2,
      'programs': [original, original],
    });
    await expectLater(loadBundledPrograms(), throwsFormatException);
  });

  test('지원하지 않는 카탈로그 버전과 잘못된 루트 구조를 거부한다', () async {
    for (final version in [0, 3, '2', null]) {
      mockCatalog({'schemaVersion': version, 'programs': []});
      await expectLater(loadBundledPrograms(), throwsFormatException);
    }
    mockCatalog({'schemaVersion': 2, 'programs': {}});
    await expectLater(loadBundledPrograms(), throwsA(isA<TypeError>()));
  });
}
