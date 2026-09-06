import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'tokens.dart';

/// 화면 공통 골격 — 앰비언트 그라디언트 + 배경광 + 제목바 + 스크롤 본문.
/// 모든 탭 화면이 이걸로 조립된다(일관성).
class ScreenScaffold extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final List<Widget> children;
  const ScreenScaffold({super.key, required this.title, this.trailing, required this.children});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(const SizedBox(height: 13));
      items.add(children[i]);
    }
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppGradients.screen),
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.glow),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 16, 8),
                child: Row(
                  children: [
                    Text(title, style: kr(size: 20, weight: FontWeight.w700, spacing: -0.3)),
                    const Spacer(),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                  children: items,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 원형 네비 버튼 (이전/다음) — 글래스 질감 + 은은한 깊이 + 탭 리플.
class RoundNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const RoundNavButton(this.icon, {super.key, this.onTap});
  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppGradients.glass,
          border: Border.all(color: AppColors.hairStrong),
          boxShadow: AppShadow.control,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap ?? () {},
            child: Center(child: Icon(icon, size: 17, color: AppColors.ink)),
          ),
        ),
      );
}

/// 선택 가능한 필터 칩 (부위·종목 등)
class PillChip extends StatelessWidget {
  final String label;
  final bool selected;
  const PillChip(this.label, {super.key, this.selected = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: selected
            ? BoxDecoration(
                gradient: AppGradients.accent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: AppShadow.glow(AppColors.ctaGlow, blur: 12, spread: -4),
              )
            : BoxDecoration(
                border: Border.all(color: AppColors.hairStrong),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
        child: Text(label,
            style: selected
                ? kr(size: 11, weight: FontWeight.w600, color: AppColors.chipInk)
                : kr(size: 11, color: AppColors.muted)),
      );
}

/// 완료 링 (done/total)
class ProgressRing extends StatelessWidget {
  final int done, total;
  final double size;
  const ProgressRing({super.key, required this.done, required this.total, this.size = 60});
  @override
  Widget build(BuildContext context) {
    final frac = total == 0 ? 0.0 : done / total;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: Size(size, size), painter: _RingPainter(frac)),
          Text('$done/$total', style: mono(size: 14, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double frac;
  _RingPainter(this.frac);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 3;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(c, r, Paint()
      ..color = AppColors.fill
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * frac, false, Paint()
      ..shader = AppGradients.good.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.frac != frac;
}

/// e1RM 추세 라인 차트 (그라디언트 라인 + 면 + 끝점)
class TrendChart extends StatelessWidget {
  final List<double> points;
  const TrendChart(this.points, {super.key});
  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 64, width: double.infinity, child: CustomPaint(painter: _TrendPainter(points)));
}

class _TrendPainter extends CustomPainter {
  final List<double> pts;
  _TrendPainter(this.pts);
  @override
  void paint(Canvas canvas, Size size) {
    if (pts.length < 2) return;
    final maxv = pts.reduce((a, b) => math.max(a, b));
    final minv = pts.reduce((a, b) => math.min(a, b));
    final range = (maxv - minv).abs() < 1e-9 ? 1.0 : (maxv - minv);
    final dx = size.width / (pts.length - 1);
    double yAt(int i) => size.height - ((pts[i] - minv) / range) * (size.height - 12) - 6;

    final line = Path();
    for (var i = 0; i < pts.length; i++) {
      final x = dx * i, y = yAt(i);
      if (i == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final rect = Offset.zero & size;
    canvas.drawPath(area, Paint()..shader = AppGradients.chartArea.createShader(rect));
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = AppGradients.accent.createShader(rect),
    );
    canvas.drawCircle(
        Offset(dx * (pts.length - 1), yAt(pts.length - 1)), 3.5, Paint()..color = AppColors.accentA);
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.pts != pts;
}

/// 달력 패널 (운동일 점 표시)
class CalendarPanel extends StatelessWidget {
  final int year, month, today;
  final Map<int, Color> marks;
  const CalendarPanel({
    super.key,
    required this.year,
    required this.month,
    required this.today,
    this.marks = const {},
  });

  static const _wd = ['일', '월', '화', '수', '목', '금', '토'];

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final lead = DateTime(year, month, 1).weekday % 7; // Sun=0
    final cells = <Widget>[];
    for (var i = 0; i < lead; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add(_day(d));
    }
    return Column(
      children: [
        Row(children: _wd.map((w) => Expanded(child: Center(child: Text(w, style: mono(size: 10, color: AppColors.muted))))).toList()),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 3,
          crossAxisSpacing: 3,
          children: cells,
        ),
      ],
    );
  }

  Widget _day(int d) {
    final isToday = d == today;
    final mark = marks[d];
    return Container(
      decoration: isToday
          ? BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppColors.accentBorder),
            )
          : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$d', style: mono(size: 12, color: isToday ? AppColors.ink : AppColors.inkDim)),
          const SizedBox(height: 3),
          SizedBox(
            height: 4,
            child: mark == null
                ? null
                : Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: mark)),
          ),
        ],
      ),
    );
  }
}

/// 운동 검색 리스트 타일
class ExerciseTile extends StatelessWidget {
  final String name, part;
  final bool divider;
  const ExerciseTile({super.key, required this.name, required this.part, this.divider = false});
  @override
  Widget build(BuildContext context) => Container(
        decoration: divider ? const BoxDecoration(border: Border(top: BorderSide(color: AppColors.hair))) : null,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                gradient: AppGradients.thumb,
                border: Border.all(color: AppColors.accentBorder),
              ),
              child: const Icon(Icons.fitness_center, size: 17, color: AppColors.accent),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: kr(size: 14.5, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(part, style: kr(size: 11.5, color: AppColors.muted)),
                ],
              ),
            ),
            const Icon(Icons.play_circle_outline, size: 24, color: AppColors.muted),
          ],
        ),
      );
}

/// 생활습관 체크 타일
class HabitTile extends StatelessWidget {
  final String name;
  final bool done;
  final bool divider;
  const HabitTile({super.key, required this.name, required this.done, this.divider = false});
  @override
  Widget build(BuildContext context) => Container(
        decoration: divider ? const BoxDecoration(border: Border(top: BorderSide(color: AppColors.hair))) : null,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        child: Row(
          children: [
            done
                ? Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: AppGradients.good,
                      boxShadow: AppShadow.glow(AppColors.goodGlow, blur: 12, spread: -3),
                    ),
                    child: const Icon(Icons.check, size: 15, color: AppColors.ctaInk),
                  )
                : Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.hairStrong, width: 1.5),
                    ),
                  ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(name, style: kr(size: 14, weight: FontWeight.w500, color: done ? AppColors.inkDim : AppColors.ink)),
            ),
            Text(done ? '✓' : '○', style: mono(size: 11, color: AppColors.muted)),
          ],
        ),
      );
}

/// 습관/항목 추가 버튼
class AddButton extends StatelessWidget {
  final String label;
  const AddButton(this.label, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.ctrl),
          border: Border.all(color: AppColors.hairStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 15, color: AppColors.muted),
            const SizedBox(width: 8),
            Text(label, style: kr(size: 13, color: AppColors.muted)),
          ],
        ),
      );
}

/// 프로필 설정 행
class SettingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final bool divider;
  const SettingTile({super.key, required this.icon, required this.label, this.value, this.divider = false});
  @override
  Widget build(BuildContext context) => Container(
        decoration: divider ? const BoxDecoration(border: Border(top: BorderSide(color: AppColors.hair))) : null,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.accent),
            const SizedBox(width: 12),
            Text(label, style: kr(size: 14)),
            const Spacer(),
            if (value != null) Text(value!, style: mono(size: 12, color: AppColors.muted)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 16, color: AppColors.muted),
          ],
        ),
      );
}
