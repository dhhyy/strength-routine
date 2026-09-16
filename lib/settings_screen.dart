import 'package:flutter/material.dart';
import 'app/settings_controller.dart';
import 'domain/recent_lift_record.dart';
import 'flow_components.dart';
import 'tokens.dart';
import 'widgets.dart';

/// 목적: 새 입력에 적용할 기본값을 기기에 저장한다.
class SettingsScreen extends StatelessWidget {
  final SettingsController controller;
  const SettingsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final value = controller.displayedSettings;
      final enabled = !controller.saving;
      return FlowPage(
        title: '앱 설정',
        children: [
          if (controller.loading) ...[
            const LinearProgressIndicator(),
            Text('저장된 설정을 불러오고 있어요.', style: AppType.body),
          ] else if (controller.loadError != null)
            StatePanel(
              title: '설정을 불러오지 못했어요',
              message: controller.loadError!,
              icon: Icons.error_outline,
              action: PrimaryAction(
                label: '다시 불러오기',
                onPressed: controller.initialize,
              ),
            )
          else ...[
            if (controller.saving) ...[
              const LinearProgressIndicator(),
              Text('설정을 저장하고 있어요.', style: AppType.caption),
            ],
            if (controller.saveError != null)
              StatePanel(
                title: '아직 적용되지 않은 설정이 있어요',
                message: controller.saveError!,
                icon: Icons.save_outlined,
                action: PrimaryAction(
                  label: '설정 저장 다시 시도',
                  onPressed: enabled ? controller.retrySave : null,
                ),
              ),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('기본 중량 단위', style: AppType.heading),
                  const SizedBox(height: AppSpace.x2),
                  Text('새 세트와 최근 기록의 첫 입력에 사용해요.', style: AppType.body),
                  const SizedBox(height: AppSpace.x4),
                  SegmentedButton<WeightUnit>(
                    style: ButtonStyle(
                      minimumSize: const WidgetStatePropertyAll(
                        Size(AppSize.touch, AppSize.touch),
                      ),
                      textStyle: WidgetStatePropertyAll(AppType.number),
                      side: const WidgetStatePropertyAll(
                        BorderSide(color: AppColors.hairStrong),
                      ),
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? AppColors.accentSoft
                            : AppColors.fill,
                      ),
                      foregroundColor: const WidgetStatePropertyAll(
                        AppColors.ink,
                      ),
                    ),
                    segments: [
                      for (final unit in WeightUnit.values)
                        ButtonSegment(value: unit, label: Text(unit.name)),
                    ],
                    selected: {value.defaultWeightUnit},
                    onSelectionChanged: enabled
                        ? (units) => controller.update(
                            value.copyWith(defaultWeightUnit: units.single),
                          )
                        : null,
                  ),
                  const SizedBox(height: AppSpace.x4),
                  Text(
                    '작성 중인 입력과 저장한 기록의 단위·숫자는 바뀌지 않아요.',
                    style: AppType.caption,
                  ),
                ],
              ),
            ),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile.adaptive(
                    key: const ValueKey('show-load-suggestions'),
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.accent,
                    title: Text('중량 조정 제안 표시', style: AppType.heading),
                    value: value.showLoadSuggestions,
                    onChanged: enabled
                        ? (show) => controller.update(
                            value.copyWith(showLoadSuggestions: show),
                          )
                        : null,
                  ),
                  Text(
                    '기록에 따른 제안을 보여줘요. 중량이 저절로 바뀌지는 않아요.',
                    style: AppType.body,
                  ),
                  const SizedBox(height: AppSpace.x2),
                  Text(
                    '꺼도 적용한 조정 이력과 되돌리기는 계속 확인할 수 있어요.',
                    style: AppType.caption,
                  ),
                ],
              ),
            ),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile.adaptive(
                    key: const ValueKey('auto-apply-working-max'),
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.accent,
                    title: Text('추정 무게 자동 적용', style: AppType.heading),
                    value: value.autoApplyWorkingMax,
                    onChanged: enabled
                        ? (apply) => controller.update(
                            value.copyWith(autoApplyWorkingMax: apply),
                          )
                        : null,
                  ),
                  Text(
                    '켜면 추정 제안을 묻지 않고 바로 적용해요. 적용 직후 되돌리기는 한 번 할 수 있어요.',
                    style: AppType.body,
                  ),
                  const SizedBox(height: AppSpace.x2),
                  Text(
                    '기본은 꺼져 있어요. 감량(D5)이 살아 있으면 자동 적용도 하지 않아요.',
                    style: AppType.caption,
                  ),
                ],
              ),
            ),
            RestSettingsPanel(controller: controller),
            Text('설정은 저장에 성공한 뒤 적용돼요.', style: AppType.caption),
          ],
        ],
      );
    },
  );
}

/// Raw input stays editable until an explicit save; unrelated settings never
/// rewrite the user's unfinished duration text.
class RestSettingsPanel extends StatefulWidget {
  final SettingsController controller;
  const RestSettingsPanel({super.key, required this.controller});
  @override
  State<RestSettingsPanel> createState() => _RestSettingsPanelState();
}

class _RestSettingsPanelState extends State<RestSettingsPanel> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _seconds;
  @override
  void initState() {
    super.initState();
    _seconds = TextEditingController(
      text:
          widget.controller.displayedSettings.defaultRestSeconds?.toString() ??
          '',
    );
  }

  @override
  void dispose() {
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final value = controller.displayedSettings;
    final enabled = !controller.saving;
    return GlassPanel(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('휴식 타이머', style: AppType.heading),
            const SizedBox(height: AppSpace.x2),
            Text('세트에 휴식 처방이 없을 때 사용할 시간을 정해요.', style: AppType.body),
            const SizedBox(height: AppSpace.x4),
            ConsoleField(
              key: const ValueKey('default-rest-seconds'),
              controller: _seconds,
              label: '기본 휴식 시간 · 초',
              hint: '미지정',
              enabled: enabled,
              validator: (raw) {
                final text = raw?.trim() ?? '';
                if (text.isEmpty) return null;
                final seconds = int.tryParse(text);
                if (seconds == null || seconds < 1 || seconds > 3600) {
                  return '1~3600초의 정수를 입력하거나 비워 주세요.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpace.x3),
            PrimaryAction(
              label: '기본 휴식 시간 저장',
              busy: controller.saving,
              onPressed: enabled
                  ? () async {
                      if (!_form.currentState!.validate()) return;
                      final raw = _seconds.text.trim();
                      final saved = await controller.update(
                        value.copyWith(
                          defaultRestSeconds: int.tryParse(raw),
                          clearDefaultRest: raw.isEmpty,
                        ),
                      );
                      if (saved && context.mounted) {
                        FocusScope.of(context).unfocus();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              raw.isEmpty
                                  ? '기본 휴식 시간을 해제했어요.'
                                  : '기본 휴식 시간을 저장했어요.',
                              style: AppType.body,
                            ),
                          ),
                        );
                      }
                    }
                  : null,
            ),
            const SizedBox(height: AppSpace.x3),
            Text(
              '비워서 저장하면 기본값을 해제해요. 처방이 0초인 세트는 휴식 없이 진행해요.',
              style: AppType.caption,
            ),
            const SizedBox(height: AppSpace.x4),
            SwitchListTile.adaptive(
              key: const ValueKey('auto-start-rest-timer'),
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.accent,
              title: Text('완료 후 자동 시작', style: AppType.body),
              value: value.autoStartRestTimer,
              onChanged: enabled
                  ? (automatic) => controller.update(
                      value.copyWith(autoStartRestTimer: automatic),
                    )
                  : null,
            ),
            Text(
              '완료 기록이 저장되면 시작해요. 진행 중인 휴식은 확인 후 바꿔요.',
              style: AppType.caption,
            ),
            const SizedBox(height: AppSpace.x2),
            Text(
              '설정 변경은 진행 중인 시간에 영향을 주지 않아요. 앱 밖 알림은 제공하지 않아요.',
              style: AppType.caption,
            ),
          ],
        ),
      ),
    );
  }
}
