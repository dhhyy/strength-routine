import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prefs_text_store.dart';
import 'text_store.dart';
import 'app_storage_native.dart'
    if (dart.library.html) 'app_storage_native_stub.dart';

/// Opens the app's local JSON blob roots (native files or web prefs).
final class AppStorage {
  final TextStore training;
  final TextStore settings;
  final TextStore workingMax;
  final TextStore deferred;
  final TextStore authBypass;
  final TextStore habits;
  final TextStore trial;

  const AppStorage({
    required this.training,
    required this.settings,
    required this.workingMax,
    required this.deferred,
    required this.authBypass,
    required this.habits,
    required this.trial,
  });

  TextStore get restTimer => training.sibling('.rest-timer.json');

  static Future<AppStorage> open() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      const root = 'strength_routine/';
      return AppStorage(
        training: PrefsTextStore(prefs, '${root}training-state.json'),
        settings: PrefsTextStore(prefs, '${root}app-settings.json'),
        workingMax: PrefsTextStore(prefs, '${root}working-max.json'),
        deferred: PrefsTextStore(prefs, '${root}deferred-exercises.json'),
        authBypass: PrefsTextStore(prefs, '${root}auth-bypass-session.json'),
        habits: PrefsTextStore(prefs, '${root}habits-state.json'),
        trial: PrefsTextStore(prefs, '${root}local-trial-started.txt'),
      );
    }
    return openNativeAppStorage();
  }
}
