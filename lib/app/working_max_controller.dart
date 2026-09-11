import 'package:flutter/foundation.dart';
import '../data/local_working_max_store.dart';
import '../domain/e1rm.dart';
import '../domain/recent_lift_record.dart';
import '../domain/working_max.dart';

/// Phase 1: e1RM 표시·수동 채택. 운동 스키마와 분리된 저장소를 쓴다.
final class WorkingMaxController extends ChangeNotifier {
  final LocalWorkingMaxStore store;
  WorkingMaxState state = const WorkingMaxState();
  bool loading = true;
  String? error;

  WorkingMaxController({required this.store});

  Future<void> initialize() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      state = await store.load();
    } catch (_) {
      error = 'working max를 불러오지 못했어요.';
    }
    loading = false;
    notifyListeners();
  }

  Future<void> adopt({
    required MainLift lift,
    required double weightKg,
    required int repetitions,
    String? note,
    DateTime? now,
  }) async {
    if (!e1rmFeatureFlag) return;
    final estimated = roundE1rmKg(
      estimateE1rmKg(weightKg: weightKg, repetitions: repetitions),
    );
    final next = state.adopt(
      WorkingMax(
        lift: lift,
        kilograms: estimated,
        adoptedAt: now ?? DateTime.now().toUtc(),
        sourceWeightKg: weightKg,
        sourceRepetitions: repetitions,
        sourceNote: note,
      ),
    );
    await store.save(next);
    state = next;
    notifyListeners();
  }

  Future<void> adoptEstimated({
    required MainLift lift,
    required double estimatedKg,
    double? sourceWeightKg,
    int? sourceRepetitions,
    String? note,
    DateTime? now,
  }) async {
    if (!e1rmFeatureFlag) return;
    final next = state.adopt(
      WorkingMax(
        lift: lift,
        kilograms: roundE1rmKg(estimatedKg),
        adoptedAt: now ?? DateTime.now().toUtc(),
        sourceWeightKg: sourceWeightKg,
        sourceRepetitions: sourceRepetitions,
        sourceNote: note,
      ),
    );
    await store.save(next);
    state = next;
    notifyListeners();
  }

  /// Phase 3 되돌리기: 해당 리프트를 직전 WorkingMax(없으면 삭제)로 복구.
  Future<void> restoreLift(MainLift lift, WorkingMax? previous) async {
    if (!e1rmFeatureFlag) return;
    final next = previous == null ? state.clear(lift) : state.adopt(previous);
    await store.save(next);
    state = next;
    notifyListeners();
  }

  /// 서버 스냅샷으로 전체 working max를 교체한다.
  Future<void> replaceState(WorkingMaxState next) async {
    await store.save(next);
    state = next;
    error = null;
    notifyListeners();
  }
}
