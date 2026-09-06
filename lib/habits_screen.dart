import 'package:flutter/material.dart';
import 'tokens.dart';
import 'widgets.dart';
import 'components.dart';

/// 생활습관 — 완료 링 + 체크리스트 + 추가.
class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: '생활습관',
      trailing: Text('09.05 금', style: mono(size: 12, color: AppColors.muted)),
      children: [
        GlassPanel(
          child: Row(
            children: [
              const ProgressRing(done: 3, total: 4),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('거의 다 왔어요', style: kr(size: 15, weight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text('하나만 더 하면 오늘 완료예요.', style: kr(size: 12.5, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        GlassPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: const [
              HabitTile(name: '물 2L 마시기', done: true),
              HabitTile(name: '단백질 120g', done: true, divider: true),
              HabitTile(name: '11시 전에 자기', done: true, divider: true),
              HabitTile(name: '오후 3시 이후 카페인 줄이기', done: false, divider: true),
            ],
          ),
        ),
        const AddButton('습관 추가'),
      ],
    );
  }
}
