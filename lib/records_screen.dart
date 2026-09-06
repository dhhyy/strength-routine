import 'package:flutter/material.dart';
import 'tokens.dart';
import 'widgets.dart';
import 'components.dart';

/// 기록 — 달력 + e1RM 추세 + 날짜별 상세.
class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: '기록',
      trailing: Row(
        children: [
          const RoundNavButton(Icons.chevron_left),
          const SizedBox(width: 8),
          Text('2026.09', style: mono(size: 12, color: AppColors.muted)),
          const SizedBox(width: 8),
          const RoundNavButton(Icons.chevron_right),
        ],
      ),
      children: [
        const GlassPanel(
          child: CalendarPanel(
            year: 2026,
            month: 9,
            today: 5,
            marks: {
              1: AppColors.good,
              3: AppColors.good,
              5: AppColors.accent,
              8: AppColors.good,
              10: AppColors.good,
            },
          ),
        ),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                children: const [
                  PillChip('스쿼트', selected: true),
                  PillChip('벤치'),
                  PillChip('데드'),
                  PillChip('OHP'),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ShaderMask(
                    shaderCallback: (r) => AppGradients.numberInk.createShader(r),
                    child: Text('117', style: mono(size: 30, weight: FontWeight.w600, color: Colors.white)),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text('kg · 추정 e1RM', style: mono(size: 13, color: AppColors.muted)),
                  ),
                  const Spacer(),
                  Text('▲ 4.5', style: mono(size: 12, color: AppColors.good)),
                ],
              ),
              const SizedBox(height: 8),
              const TrendChart([108, 109, 108.5, 112, 113, 115, 116.5, 117]),
            ],
          ),
        ),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('9월 5일 (금) · 컨디션 보통', style: mono(size: 11, color: AppColors.muted, spacing: .4)),
              const SizedBox(height: 4),
              const _DetailRow('백스쿼트', '4세트 × 5회 · RIR 2', '100kg'),
              const _DetailRow('레그 프레스', '3세트 × 10회', '×10', top: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String name, meta, value;
  final bool top;
  const _DetailRow(this.name, this.meta, this.value, {this.top = false});

  @override
  Widget build(BuildContext context) => Container(
        decoration: top ? const BoxDecoration(border: Border(top: BorderSide(color: AppColors.hair))) : null,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: kr(size: 14, weight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(meta, style: mono(size: 11.5, color: AppColors.muted)),
                ],
              ),
            ),
            Text(value, style: mono(size: 13)),
          ],
        ),
      );
}
