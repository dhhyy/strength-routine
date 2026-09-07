// Simulator-only interaction fixture. Never part of assets/programs.json.
// Run: flutter run -d DEVICE_ID -t tool/qa_preview.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:strength_routine/app/training_controller.dart';
import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/domain/recent_lift_record.dart';
import 'package:strength_routine/domain/training_program.dart';
import 'package:strength_routine/main.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final directory = await getApplicationSupportDirectory();
  final controller = TrainingController(
    store: LocalTrainingStore(File('${directory.path}/qa-training-state.json')),
    loadPrograms: () async => [
      TrainingProgram(
        id: 'qa-only',
        version: 'qa-1',
        title: '동작 검증 프로그램',
        trainerName: '개발 검증 데이터',
        description: '화면·저장 동작을 확인하는 합성 데이터입니다. 실제 훈련 프로그램이 아닙니다.',
        weeks: 1,
        sessions: [
          ProgramSession(
            id: 'qa-day',
            week: 1,
            dayOrder: 1,
            title: '운동 기록 검증',
            exercises: [
              ProgramExercise(
                id: 'qa-squat',
                name: '스쿼트 · 검증용',
                mainLift: MainLift.squat,
                sets: [
                  ProgramSet(
                    id: 'qa-set-1',
                    repetitions: 5,
                    rir: 2,
                    load: const LoadPrescription.manual(),
                  ),
                  ProgramSet(
                    id: 'qa-set-2',
                    repetitions: 5,
                    rir: 2,
                    load: const LoadPrescription.manual(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  runApp(StrengthApp(controller: controller));
}
