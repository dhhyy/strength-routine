/// Compile-time environment. Pass with --dart-define=APP_ENV=staging
enum AppEnvironment {
  local,
  staging,
  production;

  static AppEnvironment get current {
    const raw = String.fromEnvironment('APP_ENV', defaultValue: 'local');
    return switch (raw) {
      'staging' => AppEnvironment.staging,
      'production' => AppEnvironment.production,
      _ => AppEnvironment.local,
    };
  }

  bool get isLocal => this == AppEnvironment.local;
  bool get isStaging => this == AppEnvironment.staging;
  bool get isProduction => this == AppEnvironment.production;

  /// 스테이징/프로덕션에서는 실인증 구성을 기대한다.
  bool get expectsRemoteAuth => !isLocal;
}

/// Staging banner / support copy.
String get appEnvironmentLabel => switch (AppEnvironment.current) {
  AppEnvironment.local => '로컬',
  AppEnvironment.staging => '스테이징 (미리보기)',
  AppEnvironment.production => '정식',
};
