import '../auth/auth_config.dart';

/// 서버에 올리는 기기 상태 복사본(스냅샷) 저장소.
abstract interface class CloudSnapshotStore {
  Future<void> upsertTrainingEnvelope({
    required String userId,
    required Map<String, dynamic> envelope,
  });

  Future<Map<String, dynamic>?> fetchTrainingEnvelope(String userId);

  Future<void> upsertWorkingMax({
    required String userId,
    required Map<String, dynamic> payload,
  });

  Future<Map<String, dynamic>?> fetchWorkingMax(String userId);
}

/// 단위 시험·오프라인용. 메모리에만 보관한다.
final class MemoryCloudSnapshotStore implements CloudSnapshotStore {
  final training = <String, Map<String, dynamic>>{};
  final workingMax = <String, Map<String, dynamic>>{};

  @override
  Future<void> upsertTrainingEnvelope({
    required String userId,
    required Map<String, dynamic> envelope,
  }) async {
    training[userId] = Map<String, dynamic>.from(envelope);
  }

  @override
  Future<Map<String, dynamic>?> fetchTrainingEnvelope(String userId) async =>
      training[userId] == null
      ? null
      : Map<String, dynamic>.from(training[userId]!);

  @override
  Future<void> upsertWorkingMax({
    required String userId,
    required Map<String, dynamic> payload,
  }) async {
    workingMax[userId] = Map<String, dynamic>.from(payload);
  }

  @override
  Future<Map<String, dynamic>?> fetchWorkingMax(String userId) async =>
      workingMax[userId] == null
      ? null
      : Map<String, dynamic>.from(workingMax[userId]!);
}

/// 우회 세션·미설정 환경에서는 서버 동기화를 막는다.
bool cloudSyncAllowed({
  required bool isSignedIn,
  required String? userId,
  required bool bypassSession,
}) {
  if (!AuthConfig.isConfigured) return false;
  if (bypassSession) return false;
  if (!isSignedIn || userId == null || userId.isEmpty) return false;
  if (userId == 'bypass-local') return false;
  return true;
}
