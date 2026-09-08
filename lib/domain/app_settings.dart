import 'recent_lift_record.dart';

/// 사용자 입력의 기본값만 보관한다. 구매 권한이나 실제 수행값이 아니다.
final class AppSettings {
  final WeightUnit defaultWeightUnit;
  final bool showLoadSuggestions;
  const AppSettings({
    this.defaultWeightUnit = WeightUnit.kg,
    this.showLoadSuggestions = true,
  });

  AppSettings copyWith({
    WeightUnit? defaultWeightUnit,
    bool? showLoadSuggestions,
  }) => AppSettings(
    defaultWeightUnit: defaultWeightUnit ?? this.defaultWeightUnit,
    showLoadSuggestions: showLoadSuggestions ?? this.showLoadSuggestions,
  );

  Map<String, Object?> toJson() => {
    'defaultWeightUnit': defaultWeightUnit.name,
    'showLoadSuggestions': showLoadSuggestions,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final unit = switch (json['defaultWeightUnit']) {
      'kg' => WeightUnit.kg,
      'lb' => WeightUnit.lb,
      _ => throw const FormatException('Unknown default weight unit'),
    };
    if (json['showLoadSuggestions'] is! bool) {
      throw const FormatException('Invalid suggestion setting');
    }
    return AppSettings(
      defaultWeightUnit: unit,
      showLoadSuggestions: json['showLoadSuggestions'] as bool,
    );
  }
}
