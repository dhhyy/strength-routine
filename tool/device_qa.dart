// Internal device verification only. No production data is read or overwritten.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:strength_routine/app/training_controller.dart';
import 'package:strength_routine/data/local_habit_store.dart';
import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/main.dart';
import 'device_qa_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final directory = await getApplicationSupportDirectory();
  final file = File('${directory.path}/device-qa-v1-training.json');
  final store = LocalTrainingStore(file);
  // Seed once. Never recreate records on a later launch or overwrite corrupt data.
  if (await FileSystemEntity.type(file.path) == FileSystemEntityType.notFound) {
    await store.save(createDeviceQaState(DateTime.now()));
  }
  runApp(
    StrengthApp(
      controller: TrainingController(store: store),
      habitStore: LocalHabitStore(
        File('${directory.path}/device-qa-v1-habits.json'),
      ),
    ),
  );
}
