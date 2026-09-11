import 'package:flutter/foundation.dart';

import '../data/local_deferred_exercise_store.dart';

final class DeferredExerciseController extends ChangeNotifier {
  final LocalDeferredExerciseStore store;
  DeferredExerciseState state = const DeferredExerciseState();
  bool loading = true;
  String? error;

  DeferredExerciseController({required this.store});

  Future<void> initialize() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      state = await store.load();
    } catch (_) {
      error = '이월 종목을 불러오지 못했어요.';
    }
    loading = false;
    notifyListeners();
  }

  Future<void> defer(DeferredExercise value) async {
    final next = state.defer(value);
    await store.save(next);
    state = next;
    notifyListeners();
  }

  Future<void> clearExercise(String exerciseId) async {
    final next = state.clearExercise(exerciseId);
    await store.save(next);
    state = next;
    notifyListeners();
  }
}
