import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../data/local_training_store.dart';
import '../data/rest_timer_store.dart';
import '../domain/rest_timer.dart';
import '../domain/training_program.dart';
import 'rest_timer_controller.dart';

typedef ProgramLoader = Future<List<TrainingProgram>> Function();

Future<List<TrainingProgram>> loadBundledPrograms() async {
  final json =
      jsonDecode(await rootBundle.loadString('assets/programs.json'))
          as Map<String, dynamic>;
  if (![1, 2].contains(json['schemaVersion']) ||
      (json['schemaVersion'] == 1 &&
          containsAdvancedPrescriptionFields(json))) {
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
  final DateTime Function() now;
  late final RestTimerController restTimer;
  TrainingAppState state = TrainingAppState();
  List<TrainingProgram> programs = const [];
  bool loading = true, catalogLoading = false, saving = false;
  String? loadError, catalogError, saveError;
  bool sessionActionPending = false;
  String? sessionActionError;
  int _revision = 0;
  bool _disposed = false;
  TrainingController({
    required this.store,
    ProgramLoader? loadPrograms,
    DateTime Function()? now,
  }) : loadPrograms = loadPrograms ?? loadBundledPrograms,
       now = now ?? DateTime.now {
    restTimer = RestTimerController(
      store: RestTimerStore(File('${store.file.path}.rest-timer.json')),
      now: this.now,
      isEligible: _isRestEligible,
    );
  }

  String restSourceStamp(String sessionId, String setId) => jsonEncode([
    state.setActuals[setId]?.toJson(),
    state.sessionEvents.where((e) => e.sessionId == sessionId).length,
  ]);

  bool _isRestEligible(RestTimerSnapshot timer) {
    final plan = state.activePlan;
    if (plan?.id != timer.planId || state.isSessionClosed(timer.sessionId)) {
      return false;
    }
    final session = plan!.sessions
        .where((s) => s.id == timer.sessionId)
        .firstOrNull;
    final entry = session?.executionSets
        .where((e) => e.set.id == timer.setId)
        .firstOrNull;
    return entry != null &&
        entry.set.restSeconds == timer.durationSeconds &&
        entry.exercise.name == timer.exerciseName &&
        entry.number == timer.setNumber &&
        state.setActuals[timer.setId]?.status == SetActualStatus.completed &&
        !state.setDrafts.containsKey(timer.setId) &&
        restSourceStamp(timer.sessionId, timer.setId) == timer.sourceStamp;
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    if (sessionActionPending) return;
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
    if (loadError == null) {
      await restTimer.initialize();
      await refreshPrograms();
    }
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
    if (loading || loadError != null || sessionActionPending) return false;
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

  /// 마감/재개는 저장이 성공한 뒤에만 화면 상태를 바꾼다.
  /// 실패 시 기존 세트/초안/마감을 보존하고 호출자가 같은 동작 ID로 재시도한다.
  Future<bool> closeSession(
    String sessionId, {
    required String eventId,
    DateTime? at,
  }) => _commitSessionAction(
    (current) => current.closeSession(
      sessionId,
      eventId: eventId,
      at: (at ?? now()).toUtc(),
    ),
  );

  Future<bool> reopenSession(
    String sessionId, {
    required String eventId,
    DateTime? at,
  }) => _commitSessionAction(
    (current) => current.reopenSession(
      sessionId,
      eventId: eventId,
      at: (at ?? now()).toUtc(),
    ),
  );

  Future<bool> _commitSessionAction(
    TrainingAppState Function(TrainingAppState) transform,
  ) async {
    if (sessionActionPending) return false;
    if (loading || loadError != null || saving || saveError != null) {
      sessionActionError = '기록을 불러오고 입력 저장을 마친 뒤 다시 시도해 주세요.';
      _emit();
      return false;
    }
    sessionActionPending = true;
    sessionActionError = null;
    _emit();
    try {
      final candidate = transform(state);
      await store.save(candidate);
      state = candidate;
      _revision++;
      return true;
    } on FormatException catch (error) {
      sessionActionError = '기록 상태를 다시 확인해 주세요. ${error.message}';
      return false;
    } catch (_) {
      sessionActionError = '변경을 저장하지 못했어요. 기존 기록은 유지됩니다. 다시 시도해 주세요.';
      return false;
    } finally {
      sessionActionPending = false;
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    restTimer.dispose();
    super.dispose();
  }
}
