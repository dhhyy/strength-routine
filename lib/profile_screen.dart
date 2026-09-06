import 'package:flutter/material.dart';
import 'tokens.dart';
import 'widgets.dart';
import 'components.dart';

/// 프로필 — 앱 철학 + 체험 상태 + 설정.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: '프로필',
      children: [
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('이 앱의 작동 방식', style: kr(size: 10.5, weight: FontWeight.w700, color: AppColors.accent, spacing: .1)),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: kr(size: 13, color: AppColors.inkDim).copyWith(height: 1.55),
                  children: [
                    const TextSpan(text: '계획을 '),
                    TextSpan(text: '유지', style: kr(size: 13, weight: FontWeight.w600, color: AppColors.ink)),
                    const TextSpan(text: '하면서, 당신의 기록에 따라 '),
                    TextSpan(text: '제한적으로만', style: kr(size: 13, weight: FontWeight.w600, color: AppColors.ink)),
                    const TextSpan(text: ' 조절하는 도구예요. 매일 무엇을 할지 정해주고, 무리하면 살짝 낮춰줍니다.'),
                  ],
                ),
              ),
            ],
          ),
        ),
        GlassPanel(
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: AppGradients.accent),
                child: Center(child: Text('현', style: kr(size: 17, weight: FontWeight.w600, color: AppColors.chipInk))),
              ),
              const SizedBox(width: 13),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('유동현', style: kr(size: 15, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('근비대 · 주 4일', style: kr(size: 12, color: AppColors.muted)),
                ],
              ),
              const Spacer(),
              const PillChip('체험 D-5', selected: true),
            ],
          ),
        ),
        GlassPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: const [
              SettingTile(icon: Icons.gps_fixed, label: '목표 · 루틴 설정', value: '근비대 8주'),
              SettingTile(icon: Icons.fitness_center, label: '우선순위 리프트', value: '스쿼트 외 2', divider: true),
              SettingTile(icon: Icons.event_repeat, label: '훈련 요일', value: '월·화·목·금', divider: true),
              SettingTile(icon: Icons.help_outline, label: '도움말 · Q&A', divider: true),
              SettingTile(icon: Icons.credit_card, label: '구독 관리', divider: true),
            ],
          ),
        ),
      ],
    );
  }
}
