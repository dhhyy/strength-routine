import 'dart:convert';

import '../data/file_text_store.dart';
import '../data/text_store.dart';
import 'auth_session.dart';

/// 테스트(우회) 세션만 기기에 보관. Supabase 세션과 섞지 않는다.
final class LocalBypassAuthStore {
  final TextStore blobs;

  LocalBypassAuthStore(Object file) : blobs = FileTextStore(file);
  LocalBypassAuthStore.blobs(this.blobs);

  Future<AuthSession?> load() async {
    if (!await blobs.exists()) return null;
    try {
      final map = jsonDecode(await blobs.read()) as Map;
      final id = map['userId'] as String?;
      if (id == null || id.isEmpty) return null;
      return AuthSession(
        userId: id,
        displayName: map['displayName'] as String?,
        signedInAt: DateTime.tryParse(map['signedInAt'] as String? ?? '') ??
            DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(AuthSession session) async {
    await blobs.write(
      jsonEncode({
        'userId': session.userId,
        'displayName': session.displayName,
        'signedInAt': session.signedInAt.toIso8601String(),
      }),
    );
  }

  Future<void> clear() async {
    await blobs.delete();
  }
}
