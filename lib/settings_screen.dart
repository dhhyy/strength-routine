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
            Text('설정은 저장에 성공한 뒤 적용돼요.', style: AppType.caption),
          ],
        ],
      );
    },
  );
}
