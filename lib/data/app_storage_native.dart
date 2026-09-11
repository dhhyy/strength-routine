import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'app_storage.dart';
import 'file_text_store_io.dart';

Future<AppStorage> openNativeAppStorage() async {
  final directory = await getApplicationSupportDirectory();
  final path = directory.path;
  return AppStorage(
    training: FileTextStore(File('$path/training-state.json')),
    settings: FileTextStore(File('$path/app-settings.json')),
    workingMax: FileTextStore(File('$path/working-max.json')),
    deferred: FileTextStore(File('$path/deferred-exercises.json')),
    authBypass: FileTextStore(File('$path/auth-bypass-session.json')),
    habits: FileTextStore(File('$path/habits-state.json')),
    trial: FileTextStore(File('$path/local-trial-started.txt')),
  );
}
