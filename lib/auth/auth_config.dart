import 'package:flutter/foundation.dart';
import '../app/app_environment.dart';

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

  /// 로컬·스테이징 미리보기, 또는 키 없음/명시 우회일 때 가입 없이 홈 진입.
  /// 프로덕션(APP_ENV=production)에서는 키가 있을 때 우회 불가.
  static bool get allowBypass =>
      bypassAuth ||
      !isConfigured ||
      !AppEnvironment.current.isProduction;

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
