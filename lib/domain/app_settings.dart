import 'recent_lift_record.dart';

/// 사용자 입력의 기본값만 보관한다. 구매 권한이나 실제 수행값이 아니다.
final class AppSettings {
  final WeightUnit defaultWeightUnit;
  final bool showLoadSuggestions;
  final int? defaultRestSeconds;
  final bool autoStartRestTimer;
  /// 기본 끔. 켜면 working max 제안을 묻지 않고 적용하고, 스낵바로 되돌릴 수 있다.
  final bool autoApplyWorkingMax;
  const AppSettings({
    this.defaultWeightUnit = WeightUnit.kg,
    this.showLoadSuggestions = true,
    this.defaultRestSeconds,
    this.autoStartRestTimer = false,
    this.autoApplyWorkingMax = false,
  });

  AppSettings copyWith({
    WeightUnit? defaultWeightUnit,
    bool? showLoadSuggestions,
    int? defaultRestSeconds,
    bool clearDefaultRest = false,
    bool? autoStartRestTimer,
    bool? autoApplyWorkingMax,
  }) => AppSettings(
    defaultWeightUnit: defaultWeightUnit ?? this.defaultWeightUnit,
    showLoadSuggestions: showLoadSuggestions ?? this.showLoadSuggestions,
    defaultRestSeconds: clearDefaultRest
        ? null
        : defaultRestSeconds ?? this.defaultRestSeconds,
    autoStartRestTimer: autoStartRestTimer ?? this.autoStartRestTimer,
    autoApplyWorkingMax: autoApplyWorkingMax ?? this.autoApplyWorkingMax,
  );

  Map<String, Object?> toJson() => {
    'defaultWeightUnit': defaultWeightUnit.name,
    'showLoadSuggestions': showLoadSuggestions,
    'defaultRestSeconds': defaultRestSeconds,
    'autoStartRestTimer': autoStartRestTimer,
    'autoApplyWorkingMax': autoApplyWorkingMax,
  };

  void validate() {
    if (defaultRestSeconds != null &&
        (defaultRestSeconds! < 1 || defaultRestSeconds! > 3600)) {
      throw const FormatException('Rest seconds must be 1 to 3600');
    }
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final unit = switch (json['defaultWeightUnit']) {
      'kg' => WeightUnit.kg,
      'lb' => WeightUnit.lb,
      _ => throw const FormatException('Unknown default weight unit'),
    };
    if (json['showLoadSuggestions'] is! bool) {
      throw const FormatException('Invalid suggestion setting');
    }
    if ((json.containsKey('autoStartRestTimer') &&
            json['autoStartRestTimer'] is! bool) ||
        (json.containsKey('autoApplyWorkingMax') &&
            json['autoApplyWorkingMax'] is! bool) ||
        (json['defaultRestSeconds'] != null &&
            json['defaultRestSeconds'] is! int)) {
      throw const FormatException('Invalid rest preference');
    }
    final settings = AppSettings(
      defaultWeightUnit: unit,
      showLoadSuggestions: json['showLoadSuggestions'] as bool,
      defaultRestSeconds: json['defaultRestSeconds'] as int?,
      autoStartRestTimer: json['autoStartRestTimer'] as bool? ?? false,
      autoApplyWorkingMax: json['autoApplyWorkingMax'] as bool? ?? false,
    );
    settings.validate();
    return settings;
  }
}
