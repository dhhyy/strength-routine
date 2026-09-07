import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../data/local_training_store.dart';
import '../domain/training_program.dart';

typedef ProgramLoader = Future<List<TrainingProgram>> Function();

Future<List<TrainingProgram>> loadBundledPrograms() async {
  final json =
      jsonDecode(await rootBundle.loadString('assets/programs.json'))
          as Map<String, dynamic>;
  if (json['schemaVersion'] != 1) {
    throw const FormatException('Unsupported program catalog');
  }
  final programs = (json['programs'] as List)
      .map((value) => TrainingProgram.fromJson(value as Map<String, dynamic>))
      .toList();
  if (programs.map((p) => p.id).toSet().length != programs.length) {
    throw const FormatException('Duplicate program');
  }
  return List.unmodifiable(programs);
}

class TrainingController extends ChangeNotifier {
  final LocalTrainingStore store;
  final ProgramLoader loadPrograms;
  TrainingAppState state = TrainingAppState();
  List<TrainingProgram> programs = const [];
  bool loading = true, catalogLoading = false, saving = false;
  String? loadError, catalogError, saveError;
  int _revision = 0;
  bool _disposed = false;
  TrainingController({required this.store, ProgramLoader? loadPrograms})
    : loadPrograms = loadPrograms ?? loadBundledPrograms;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    loading = true;
    loadError = null;
    _emit();
    try {
      state = await store.load();
    } catch (_) {
      loadError = '저장된 기록을 읽지 못했어요. 다시 시도해 주세요.';
    }
    loading = false;
    _emit();
    if (loadError == null) await refreshPrograms();
  }

  Future<void> refreshPrograms() async {
    catalogLoading = true;
    catalogError = null;
    _emit();
    try {
      programs = List.unmodifiable(await loadPrograms());
    } catch (_) {
      catalogError = '프로그램을 불러오지 못했어요.';
    }
    catalogLoading = false;
    _emit();
  }

  /// UI는 즉시 최신 입력을 보유한다. 실패해도 되돌리거나 지우지 않는다.
  Future<bool> update(
    TrainingAppState Function(TrainingAppState) transform,
  ) async {
    if (loading || loadError != null) return false;
    state = transform(state);
    final revision = ++_revision;
    final snapshot = state;
    saving = true;
    saveError = null;
    _emit();
    try {
      await store.save(snapshot);
      if (revision == _revision) {
        saving = false;
        saveError = null;
        _emit();
      }
      return true;
    } catch (_) {
      if (revision == _revision) {
        saving = false;
        saveError = '아직 기기에 저장되지 않았어요. 입력을 유지하고 있어요.';
        _emit();
      }
      return false;
    }
  }

  Future<bool> retrySave() => update((state) => state);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
