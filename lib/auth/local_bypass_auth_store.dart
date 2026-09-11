import 'dart:convert';
import 'dart:io';
import 'auth_session.dart';

/// 테스트(우회) 세션만 기기에 보관. Supabase 세션과 섞지 않는다.
final class LocalBypassAuthStore {
  final File file;
  LocalBypassAuthStore(this.file);

  Future<AuthSession?> load() async {
    if (!await file.exists()) return null;
    try {
      final map = jsonDecode(await file.readAsString()) as Map;
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
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'userId': session.userId,
        'displayName': session.displayName,
        'signedInAt': session.signedInAt.toIso8601String(),
      }),
    );
  }

  Future<void> clear() async {
    if (await file.exists()) await file.delete();
  }
}
