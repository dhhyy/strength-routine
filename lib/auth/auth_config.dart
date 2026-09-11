import 'package:flutter/foundation.dart';

/// Compile-time auth config. Pass with --dart-define.
abstract final class AuthConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  /// true면 카카오/Supabase 없이 로컬 테스트 세션으로 진입한다.
  static const bypassAuth = bool.fromEnvironment('AUTH_BYPASS', defaultValue: false);
  static const redirectScheme = String.fromEnvironment(
    'AUTH_REDIRECT_SCHEME',
    defaultValue: 'tech.vibe.strengthroutine',
  );
  static const redirectHost = String.fromEnvironment(
    'AUTH_REDIRECT_HOST',
    defaultValue: 'login-callback',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// 키가 없거나 명시적 우회일 때 테스트 로그인 UI/경로를 연다.
  static bool get allowBypass => bypassAuth || !isConfigured;

  /// 네이티브는 딥링크, 웹은 현재 origin(+ path)으로 돌아온다.
  static String get redirectTo {
    if (kIsWeb) {
      final base = Uri.base;
      return Uri(
        scheme: base.scheme,
        host: base.host,
        port: base.hasPort ? base.port : null,
        path: base.path.endsWith('/') ? base.path : '${base.path}/',
      ).toString();
    }
    return '$redirectScheme://$redirectHost';
  }
}
