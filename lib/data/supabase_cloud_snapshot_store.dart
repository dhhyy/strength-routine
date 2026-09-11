import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_snapshot_store.dart';

/// Supabase `training_snapshots` / `working_max_snapshots` 테이블에 거울로 저장.
final class SupabaseCloudSnapshotStore implements CloudSnapshotStore {
  final SupabaseClient client;
  SupabaseCloudSnapshotStore([SupabaseClient? client])
    : client = client ?? Supabase.instance.client;

  @override
  Future<void> upsertTrainingEnvelope({
    required String userId,
    required Map<String, dynamic> envelope,
  }) async {
    final version = envelope['schemaVersion'];
    await client.from('training_snapshots').upsert({
      'user_id': userId,
      'schema_hint': 'envelope-$version',
      'payload': envelope,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<Map<String, dynamic>?> fetchTrainingEnvelope(String userId) async {
    final row = await client
        .from('training_snapshots')
        .select('payload')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    final payload = row['payload'];
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) return Map<String, dynamic>.from(payload);
    return null;
  }

  @override
  Future<void> upsertWorkingMax({
    required String userId,
    required Map<String, dynamic> payload,
  }) async {
    await client.from('working_max_snapshots').upsert({
      'user_id': userId,
      'payload': payload,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<Map<String, dynamic>?> fetchWorkingMax(String userId) async {
    final row = await client
        .from('working_max_snapshots')
        .select('payload')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    final payload = row['payload'];
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) return Map<String, dynamic>.from(payload);
    return null;
  }
}
