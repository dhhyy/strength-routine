import 'package:flutter/foundation.dart';

import '../data/rest_timer_store.dart';
import '../domain/rest_timer.dart';

final class RestTimerController extends ChangeNotifier {
  final RestTimerStore store;
  final DateTime Function() now;
  final bool Function(RestTimerSnapshot) isEligible;
  RestTimerSnapshot? snapshot;
  RestTimerSnapshot? _candidate;
  bool loading = true, saving = false, _hasCandidate = false;
  bool _disposed = false;
  String? loadError, saveError;
  RestTimerController({
    required this.store,
    required this.now,
    required this.isEligible,
  });

  RestTimerSnapshot? get available =>
      snapshot != null && isEligible(snapshot!) ? snapshot : null;
  bool get busy => loading || saving;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    if (saving) return;
    loading = true;
    loadError = null;
    _emit();
    try {
      snapshot = await store.load();
    } catch (_) {
      loadError = '휴식 타이머를 읽지 못했어요. 운동 기록은 계속할 수 있어요.';
    }
    loading = false;
    _emit();
  }

  Future<bool> start(RestTimerSnapshot timer, {bool replace = false}) async {
    if (busy || loadError != null || saveError != null || !isEligible(timer)) {
      return false;
    }
    final current = available;
    if (current != null &&
        current.remainingMilliseconds(now()) > 0 &&
        !replace) {
      return false;
    }
    return _commit(timer);
  }

  Future<bool> pause() async {
    final current = available;
    final at = now();
    if (busy ||
        saveError != null ||
        current == null ||
        current.isPaused ||
        current.remainingMilliseconds(at) == 0) {
      return false;
    }
    return _commit(current.pause(at));
  }

  Future<bool> resume() async {
    final current = available;
    if (busy || saveError != null || current == null || !current.isPaused) {
      return false;
    }
    return _commit(current.resume(now()));
  }

  Future<bool> stop() async {
    if (busy || loadError != null || saveError != null) return false;
    return _commit(null);
  }

  Future<bool> retrySave() async {
    if (busy || !_hasCandidate) return false;
    if (_candidate != null && !isEligible(_candidate!)) {
      _candidate = null;
      _hasCandidate = false;
      saveError = null;
      _emit();
      return false;
    }
    return _commit(_candidate);
  }

  /// Only a durable candidate becomes visible. Retrying keeps the original
  /// deadline, rather than granting another full interval after a failed save.
  Future<bool> _commit(RestTimerSnapshot? candidate) async {
    saving = true;
    _candidate = candidate;
    _hasCandidate = true;
    saveError = null;
    _emit();
    try {
      await store.save(candidate);
      snapshot = candidate;
      _hasCandidate = false;
      return true;
    } catch (_) {
      saveError = '타이머 변경을 저장하지 못했어요. 이전 타이머와 운동 기록은 유지돼요.';
      return false;
    } finally {
      saving = false;
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
