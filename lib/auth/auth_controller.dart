import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_config.dart';
import 'auth_session.dart';
import 'local_bypass_auth_store.dart';

/// Kakao-only auth via Supabase. Persists session so cold start skips login.
/// 키가 없거나 AUTH_BYPASS면 로컬 테스트 세션으로 홈 진입 가능.
final class AuthController extends ChangeNotifier {
  AuthSession? _session;
  String? _error;
  bool _busy = false;
  bool _ready = false;
  bool _initialized = false;
  bool _bypassSession = false;
  LocalBypassAuthStore? _bypassStore;

  AuthController();

  /// 위젯/통합 테스트용. Supabase 없이 세션 상태를 주입한다.
  AuthController.preview({AuthSession? session})
    : _session = session,
      _ready = true,
      _initialized = true,
      _bypassSession = session != null;

  AuthSession? get session => _session;
  bool get isSignedIn => _session?.isSignedIn ?? false;
  bool get ready => _ready;
  bool get busy => _busy;
  String? get error => _error;
  bool get canBypass => AuthConfig.allowBypass;
  bool get isBypassSession => _bypassSession;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (AuthConfig.allowBypass) {
      final directory = await getApplicationSupportDirectory();
      _bypassStore = LocalBypassAuthStore(
        File('${directory.path}/auth-bypass-session.json'),
      );
      final saved = await _bypassStore!.load();
      if (saved != null) {
        _session = saved;
        _bypassSession = true;
      } else if (AuthConfig.bypassAuth) {
        await signInBypass(displayName: '테스트');
      }
      _ready = true;
      notifyListeners();
      if (!AuthConfig.isConfigured) return;
    }

    if (!AuthConfig.isConfigured) {
      _ready = true;
      notifyListeners();
      return;
    }

    try {
      await Supabase.initialize(
        url: AuthConfig.supabaseUrl,
        publishableKey: AuthConfig.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (_bypassSession) return;
        _applySupabaseSession(data.session);
      });
      if (!_bypassSession) {
        _applySupabaseSession(Supabase.instance.client.auth.currentSession);
      }
    } catch (error) {
      _error = '인증 서비스를 열지 못했어요.';
      debugPrint('AuthController.initialize: $error');
    }
    _ready = true;
    notifyListeners();
  }

  void _applySupabaseSession(Session? session) {
    if (session == null) {
      _session = null;
    } else {
      final user = session.user;
      _session = AuthSession(
        userId: user.id,
        displayName:
            user.userMetadata?['full_name'] as String? ??
            user.userMetadata?['name'] as String? ??
            user.email,
        signedInAt: DateTime.now(),
      );
      _bypassSession = false;
    }
    _error = null;
    notifyListeners();
  }

  /// 카카오 없이 로컬 세션 발급(개발·QA). 기기에 저장되어 다음 실행에도 유지.
  Future<void> signInBypass({String displayName = '테스트'}) async {
    _busy = true;
    _error = null;
    notifyListeners();
    _session = AuthSession(
      userId: 'bypass-local',
      displayName: displayName,
      signedInAt: DateTime.now(),
    );
    _bypassSession = true;
    _bypassStore ??= LocalBypassAuthStore(
      File(
        '${(await getApplicationSupportDirectory()).path}/auth-bypass-session.json',
      ),
    );
    await _bypassStore!.save(_session!);
    _busy = false;
    notifyListeners();
  }

  Future<void> signInWithKakao() async {
    if (_busy) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      if (!AuthConfig.isConfigured) {
        throw StateError(
          'Supabase/카카오 키가 없어요. 지금은 「테스트로 시작」으로 들어갈 수 있어요.',
        );
      }
      final ok = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.kakao,
        redirectTo: AuthConfig.redirectTo,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      if (!ok) {
        throw StateError('카카오 로그인을 시작하지 못했어요.');
      }
    } catch (error) {
      _error = error is StateError ? error.message : '로그인에 실패했어요. 다시 시도해 주세요.';
      debugPrint('signInWithKakao: $error');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (_bypassSession || !AuthConfig.isConfigured) {
      _session = null;
      _bypassSession = false;
      await _bypassStore?.clear();
      notifyListeners();
      return;
    }
    await Supabase.instance.client.auth.signOut();
    _session = null;
    notifyListeners();
  }
}
