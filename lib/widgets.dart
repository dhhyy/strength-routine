import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'tokens.dart';
import 'models.dart';
import 'components.dart';

/// 깊이·은은함의 기본 단위 — 글래스 패널 (그라디언트 표면 + 소프트 섀도우 + 블러).
/// 섀도우는 클립 밖(바깥 Container)에, 블러/그라디언트는 클립 안에 둔다.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final List<BoxShadow> glow;
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.glow = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.panel),
        boxShadow: [...AppShadow.card, ...glow],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.panel),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: AppGradients.glass,
              border: Border.all(color: AppColors.hair),
              borderRadius: BorderRadius.circular(AppRadius.panel),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 상단 날짜 / 네비
class ConsoleTopBar extends StatelessWidget {
  final Session s;
  const ConsoleTopBar(this.s, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text.rich(TextSpan(children: [
          TextSpan(text: s.dateLabel, style: kr(size: 15, weight: FontWeight.w600)),
          TextSpan(text: '  ${s.dateSub}', style: mono(size: 12.5, color: AppColors.muted)),
        ])),
        const Spacer(),
        const RoundNavButton(Icons.chevron_left),
        const SizedBox(width: 8),
        const RoundNavButton(Icons.chevron_right),
      ],
    );
  }
}

/// 상태 밴드 (블록/국면 + 게이지 2)
class StatusBand extends StatelessWidget {
  final Session s;
  const StatusBand(this.s, {super.key});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(s.phaseLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kr(size: 12, weight: FontWeight.w600, color: AppColors.accent, spacing: .2)),
              ),
              const SizedBox(width: 10),
              Text(s.focus, style: kr(size: 12, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GaugeBar(
                  label: '회복 여력',
                  value: '${(s.neuralLoad * 100).round()}%',
                  frac: s.neuralLoad,
                  gradient: AppGradients.accent,
                  glow: AppColors.accentGlow,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GaugeBar(
                  label: '주간 볼륨',
                  value: '${s.weekVolDone}/${s.weekVolTarget}',
                  frac: s.weekFrac,
                  gradient: AppGradients.good,
                  glow: AppColors.goodGlow,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 가로 게이지 (그라디언트 + 글로우)
class GaugeBar extends StatelessWidget {
  final String label, value;
  final double frac;
  final Gradient gradient;
  final Color glow;
  const GaugeBar({
    super.key,
    required this.label,
    required this.value,
    required this.frac,
    required this.gradient,
    required this.glow,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: kr(size: 11, color: AppColors.muted)),
            Text(value, style: mono(size: 11, weight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.bar),
          child: Container(
            height: 8,
            color: AppColors.fill,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: frac.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(AppRadius.bar),
                  boxShadow: AppShadow.glow(glow, blur: 12, spread: 0),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 명언
class QuoteLine extends StatelessWidget {
  final Session s;
  const QuoteLine(this.s, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('“${s.quote}”', style: kr(size: 13, color: AppColors.inkDim, style: FontStyle.italic)),
          const SizedBox(height: 6),
          Text('— ${s.quoteBy}', style: mono(size: 11, color: AppColors.accent)),
        ],
      ),
    );
  }
}

/// 운동 역할 칩
class RoleChip extends StatelessWidget {
  final ExRole role;
  const RoleChip(this.role, {super.key});

  @override
  Widget build(BuildContext context) {
    switch (role) {
      case ExRole.mainVolume:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            gradient: AppGradients.accent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: AppShadow.glow(AppColors.ctaGlow, blur: 14, spread: -4),
          ),
          child: Text('메인 볼륨', style: kr(size: 10.5, weight: FontWeight.w600, color: AppColors.chipInk, spacing: .3)),
        );
      case ExRole.techMaintain:
        return _outline('기술 유지', AppColors.warn, AppColors.warnBorder);
      case ExRole.accessory:
        return _outline('보조', AppColors.muted, AppColors.hairStrong);
    }
  }

  Widget _outline(String label, Color fg, Color border) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(label, style: kr(size: 10.5, weight: FontWeight.w600, color: fg)),
      );
}

/// 메인 리프트 — 히어로 카드 (큰 그라디언트 숫자 + 점진 노출 세트 + 글로우 CTA)
class HeroCard extends StatelessWidget {
  final Exercise ex;
  const HeroCard(this.ex, {super.key});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(ex.name, style: kr(size: 17, weight: FontWeight.w600))),
              RoleChip(ex.role),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ShaderMask(
                shaderCallback: (r) => AppGradients.numberInk.createShader(r),
                child: Text(ex.weight ?? '',
                    style: mono(size: 52, weight: FontWeight.w600, color: Colors.white).copyWith(height: 1)),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(ex.unit ?? '', style: mono(size: 17, color: AppColors.muted)),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text.rich(TextSpan(children: [
                    TextSpan(text: '세트 ${ex.current}', style: mono(size: 12, weight: FontWeight.w500, color: AppColors.ink)),
                    TextSpan(text: ' / ${ex.total}', style: mono(size: 12, color: AppColors.muted)),
                  ])),
                  const SizedBox(height: 3),
                  Text(ex.subtitle, style: mono(size: 12, color: AppColors.muted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(children: [
            for (final st in ex.sets)
              Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: _dot(st.status))),
          ]),
          const SizedBox(height: 18),
          _cta('세트 ${ex.current} 기록하기'),
        ],
      ),
    );
  }

  Widget _dot(SetStatus s) {
    final (Gradient? grad, Color? glow) = switch (s) {
      SetStatus.done => (AppGradients.good, AppColors.goodGlow),
      SetStatus.now => (AppGradients.accent, AppColors.accentGlow),
      SetStatus.pending => (null, null),
    };
    return Container(
      height: 6,
      decoration: BoxDecoration(
        gradient: grad,
        color: grad == null ? AppColors.fill : null,
        borderRadius: BorderRadius.circular(AppRadius.bar),
        boxShadow: glow == null ? null : AppShadow.glow(glow, blur: 10, spread: 0),
      ),
    );
  }

  Widget _cta(String label) => Container(
        decoration: BoxDecoration(
          gradient: AppGradients.accent,
          borderRadius: BorderRadius.circular(AppRadius.ctrl),
          boxShadow: AppShadow.glow(AppColors.ctaGlow, blur: 26, spread: -8),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.ctrl),
            onTap: () {},
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Text(label, style: mono(size: 15, weight: FontWeight.w600, color: AppColors.ctaInk, spacing: .2)),
            ),
          ),
        ),
      );
}

/// 보조/기술유지 운동 — 접힌 행 (요약 + 규칙 이유 + 미니 점)
class CollapsedRow extends StatelessWidget {
  final Exercise ex;
  const CollapsedRow(this.ex, {super.key});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ex.name, style: kr(size: 15, weight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(ex.subtitle, style: mono(size: 11.5, color: AppColors.muted)),
                if (ex.ruleNote != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 13, color: AppColors.warn),
                      const SizedBox(width: 6),
                      Flexible(child: Text(ex.ruleNote!, style: kr(size: 11, color: AppColors.muted))),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              RoleChip(ex.role),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final st in ex.sets)
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.only(left: 5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: st.status == SetStatus.done ? AppColors.good : AppColors.hairStrong,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
