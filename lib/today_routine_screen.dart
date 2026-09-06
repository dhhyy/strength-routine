import 'package:flutter/material.dart';
import 'tokens.dart';
import 'models.dart';
import 'widgets.dart';

/// '오늘 루틴' 화면 — 위젯을 '조립'만 한다.
/// 바탕: 앰비언트 그라디언트 + 은은한 액센트 배경광 (깊이감).
class TodayRoutineScreen extends StatelessWidget {
  const TodayRoutineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const s = demoSession;
    final main = s.exercises.firstWhere((e) => e.hero, orElse: () => s.exercises.first);
    final rest = s.exercises.where((e) => !e.hero).toList();

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppGradients.screen),
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.glow),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: ConsoleTopBar(s),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 20),
                  children: [
                    StatusBand(s),
                    const SizedBox(height: 14),
                    QuoteLine(s),
                    const SizedBox(height: 14),
                    HeroCard(main),
                    for (final ex in rest) ...[
                      const SizedBox(height: 14),
                      CollapsedRow(ex),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
