import 'package:flutter/widgets.dart';
import '../data/local_settings_store.dart';
import '../domain/app_settings.dart';

class SettingsController extends ChangeNotifier {
  final LocalSettingsStore store;
  AppSettings settings = const AppSettings();
  AppSettings? _pendingSettings;
  bool loading = true, saving = false;
  String? loadError, saveError;
  bool _disposed = false;

  SettingsController({required this.store});

  /// 저장 전 선택은 설정 화면에서만 표시한다. 다른 화면은 settings를 쓴다.
  AppSettings get displayedSettings => _pendingSettings ?? settings;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    if (saving) return;
    loading = true;
    loadError = null;
    _emit();
    try {
      settings = await store.load();
      _pendingSettings = null;
      saveError = null;
    } catch (_) {
      loadError = '저장된 설정을 읽지 못했어요. 원본을 유지하고 있어요.';
    }
    loading = false;
    _emit();
  }

  Future<bool> update(AppSettings next) async {
    if (loading || loadError != null || saving) return false;
    try {
      next.validate();
    } catch (_) {
      saveError = '휴식 시간은 1~3600초의 정수로 입력해 주세요.';
      _emit();
      return false;
    }
    _pendingSettings = next;
    saving = true;
    saveError = null;
    _emit();
    try {
      await store.save(next);
      settings = next;
      _pendingSettings = null;
      saving = false;
      _emit();
      return true;
    } catch (_) {
      saving = false;
      saveError = '선택은 유지했어요. 저장에 성공하면 새 입력부터 적용돼요.';
      _emit();
      return false;
    }
  }

  Future<bool> retrySave() => update(displayedSettings);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class SettingsScope extends InheritedNotifier<SettingsController> {
  const SettingsScope({
    super.key,
    required SettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  static SettingsController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()?.notifier;
}
