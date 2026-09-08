import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_routine/app/settings_controller.dart';
import 'package:strength_routine/data/local_settings_store.dart';
import 'package:strength_routine/domain/app_settings.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';

void main() {
  late Directory directory;
  late File file;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('settings-store-test-');
    file = File('${directory.path}/app-settings.json');
  });
  tearDown(() async => directory.delete(recursive: true));

  test('missing settings use defaults without creating a file', () async {
    final settings = await LocalSettingsStore(file).load();
    expect(settings.defaultWeightUnit, WeightUnit.kg);
    expect(settings.showLoadSuggestions, isTrue);
    expect(await file.exists(), isFalse);
  });

  test(
    'ordered saves restore both preferences without leftover temporary files',
    () async {
      final store = LocalSettingsStore(file);
      final writes = [
        store.save(const AppSettings(defaultWeightUnit: WeightUnit.lb)),
        store.save(const AppSettings(showLoadSuggestions: false)),
      ];
      final read = store.load();
      await Future.wait(writes);
      expect(
        (await read).toJson(),
        const AppSettings(showLoadSuggestions: false).toJson(),
      );
      expect(
        (await LocalSettingsStore(file).load()).toJson(),
        (await read).toJson(),
      );
      expect(await directory.list().toList(), hasLength(1));
    },
  );

  test(
    'corrupt or unknown settings preserve original bytes and block updates',
    () async {
      final samples = [
        '{broken',
        jsonEncode({'schemaVersion': 9, 'state': const AppSettings().toJson()}),
        jsonEncode({
          'schemaVersion': 1,
          'state': {'defaultWeightUnit': 'stone', 'showLoadSuggestions': true},
        }),
        jsonEncode({
          'schemaVersion': 1,
          'state': {'defaultWeightUnit': 'kg', 'showLoadSuggestions': 'true'},
        }),
        jsonEncode({'schemaVersion': 1, 'state': {}}),
      ];
      for (final sample in samples) {
        await file.writeAsString(sample);
        final controller = SettingsController(store: LocalSettingsStore(file));
        await controller.initialize();
        expect(controller.loadError, isNotNull);
        expect(
          await controller.update(
            const AppSettings(defaultWeightUnit: WeightUnit.lb),
          ),
          isFalse,
        );
        expect(await file.readAsString(), sample);
        controller.dispose();
      }
    },
  );

  test(
    'failed settings remain pending and affect new inputs only after retry succeeds',
    () async {
      final controller = SettingsController(store: LocalSettingsStore(file));
      addTearDown(controller.dispose);
      await controller.initialize();
      await Directory(file.path).create();
      const next = AppSettings(
        defaultWeightUnit: WeightUnit.lb,
        showLoadSuggestions: false,
      );
      expect(await controller.update(next), isFalse);
      expect(controller.settings.defaultWeightUnit, WeightUnit.kg);
      expect(controller.settings.showLoadSuggestions, isTrue);
      expect(controller.displayedSettings.toJson(), next.toJson());
      expect(controller.saveError, isNotNull);
      await Directory(file.path).delete();
      expect(await controller.retrySave(), isTrue);
      expect(controller.settings.toJson(), next.toJson());
      expect(controller.saveError, isNull);
      final reopened = SettingsController(store: LocalSettingsStore(file));
      addTearDown(reopened.dispose);
      await reopened.initialize();
      expect(reopened.settings.toJson(), next.toJson());
    },
  );

  test(
    'duplicate update while saving cannot replace the in-flight selection',
    () async {
      final controller = SettingsController(store: LocalSettingsStore(file));
      addTearDown(controller.dispose);
      await controller.initialize();
      const next = AppSettings(defaultWeightUnit: WeightUnit.lb);
      final first = controller.update(next);
      expect(controller.saving, isTrue);
      expect(
        await controller.update(const AppSettings(showLoadSuggestions: false)),
        isFalse,
      );
      expect(await first, isTrue);
      expect(controller.settings.toJson(), next.toJson());
      expect((await LocalSettingsStore(file).load()).toJson(), next.toJson());
    },
  );
}
