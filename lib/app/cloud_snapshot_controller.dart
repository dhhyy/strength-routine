import 'package:flutter/foundation.dart';

import '../auth/auth_config.dart';
import '../auth/auth_controller.dart';
import '../data/cloud_snapshot_store.dart';
import '../data/local_training_store.dart';
import '../domain/working_max.dart';
import 'training_controller.dart';
import 'working_max_controller.dart';

/// 기기 상태 ↔ 서버 스냅샷 수동 동기화.
final class CloudSnapshotController extends ChangeNotifier {
  final AuthController auth;
  final TrainingController training;
  final WorkingMaxController workingMax;
  final CloudSnapshotStore store;

  bool busy = false;
  String? message;
  String? error;
  DateTime? lastUploadedAt;
  DateTime? lastDownloadedAt;

  CloudSnapshotController({
    required this.auth,
    required this.training,
    required this.workingMax,
    required this.store,
  });

  bool get canSync => cloudSyncAllowed(
    isSignedIn: auth.isSignedIn,
    userId: auth.session?.userId,
    bypassSession: auth.isBypassSession,
  );

  String get blockedReason {
    if (!AuthConfig.isConfigured) {
      return '서버 키가 없어요. 스테이징 빌드(SUPABASE_URL 등)로 실행해 주세요.';
    }
    if (auth.session?.userId == 'bypass-local') {
      return '테스트 로그인에서는 서버 저장을 쓰지 않아요. 카카오로 로그인해 주세요.';
    }
    if (!auth.isSignedIn) return '카카오 로그인 후 서버 저장을 쓸 수 있어요.';
    return '지금은 서버 동기화를 쓸 수 없어요.';
  }

  Future<void> upload() async {
    if (busy) return;
    if (!canSync) {
      error = blockedReason;
      message = null;
      notifyListeners();
      return;
    }
    busy = true;
    error = null;
    message = null;
    notifyListeners();
    try {
      final userId = auth.session!.userId;
      final envelope = training.exportEnvelope();
      await store.upsertTrainingEnvelope(userId: userId, envelope: envelope);
      await store.upsertWorkingMax(
        userId: userId,
        payload: workingMax.state.toJson(),
      );
      lastUploadedAt = DateTime.now();
      message = '서버에 저장했어요.';
    } catch (e, st) {
      debugPrint('CloudSnapshotController.upload: $e\n$st');
      error = '서버에 저장하지 못했어요. 네트워크·로그인을 확인해 주세요.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> download() async {
    if (busy) return;
    if (!canSync) {
      error = blockedReason;
      message = null;
      notifyListeners();
      return;
    }
    busy = true;
    error = null;
    message = null;
    notifyListeners();
    try {
      final userId = auth.session!.userId;
      final envelope = await store.fetchTrainingEnvelope(userId);
      if (envelope == null) {
        error = '서버에 저장된 기록이 아직 없어요. 먼저 「서버에 저장」을 해 주세요.';
        return;
      }
      // Validate before writing local files.
      LocalTrainingStore.decodeEnvelope(envelope);
      final wmRaw = await store.fetchWorkingMax(userId);
      final saved = await training.importEnvelope(envelope);
      if (!saved) {
        error =
            training.sessionActionError ??
            training.saveError ??
            '기기에 불러오지 못했어요.';
        return;
      }
      if (wmRaw != null) {
        await workingMax.replaceState(WorkingMaxState.fromJson(wmRaw));
      }
      lastDownloadedAt = DateTime.now();
      message = '서버 기록을 기기에 넣었어요.';
    } catch (e, st) {
      debugPrint('CloudSnapshotController.download: $e\n$st');
      error = '불러오기에 실패했어요. 서버 데이터 형식을 확인해 주세요.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
