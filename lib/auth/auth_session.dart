/// App-facing session snapshot. Source of truth is Supabase Auth when configured.
final class AuthSession {
  final String userId;
  final String? displayName;
  final DateTime signedInAt;

  const AuthSession({
    required this.userId,
    required this.signedInAt,
    this.displayName,
  });

  bool get isSignedIn => userId.isNotEmpty;
}
