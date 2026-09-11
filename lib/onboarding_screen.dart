import 'package:flutter/material.dart';
import 'tokens.dart';

/// 첫 실행 소개 5장. 마지막에서 가입/로그인.
/// 스테이징·로컬은 [onBypass]로 가입 없이 홈 진입 가능.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onSignup;
  final VoidCallback onLogin;
  final VoidCallback? onBypass;
  const OnboardingScreen({
    super.key,
    required this.onSignup,
    required this.onLogin,
    this.onBypass,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  static const _count = 5;
  int _page = 0;
  bool get _isLast => _page == _count - 1;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _next() {
    _pc.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  void _jumpToAuthHub() {
    _pc.animateToPage(
      _count - 1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.screen),
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppGradients.glow),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 4),
                  child: Row(
                    children: [
                      AnimatedOpacity(
                        opacity: _isLast ? 0 : 1,
                        duration: const Duration(milliseconds: 200),
                        child: GestureDetector(
                          onTap: _isLast ? null : _jumpToAuthHub,
                          child: Text('건너뛰기', style: kr(size: 12, color: AppColors.muted)),
                        ),
                      ),
                      const Spacer(),
                      _Dots(count: _count, active: _page),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pc,
                    onPageChanged: (i) => setState(() => _page = i),
                    children: [_slide1(), _slide2(), _slide3(), _slide4(), _slide5()],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 22),
                  child: Column(
                    children: [
                      if (_isLast) ...[
                        _cta('간단하게 가입하기', widget.onSignup),
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: widget.onLogin,
                          child: Text('로그인하기', style: kr(size: 13, color: AppColors.muted)),
                        ),
                        if (widget.onBypass != null) ...[
                          const SizedBox(height: 14),
                          GestureDetector(
                            onTap: widget.onBypass,
                            child: Text(
                              '가입 없이 둘러보기',
                              style: kr(size: 13, color: AppColors.accent),
                            ),
                          ),
                        ],
                      ] else
                        _cta('다음', _next),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _slide1() => _pad(Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STRENGTH · 근비대 · 파워빌딩', style: mono(size: 11, color: AppColors.accent, spacing: 1.4)),
          const SizedBox(height: 12),
          Text('코치 박민재의 훈련 원칙을,\n앱 하나에 담았어요.',
              style: kr(size: 26, weight: FontWeight.w700, spacing: -0.4).copyWith(height: 1.3)),
          const SizedBox(height: 14),
          Text('그의 방식이 이 앱의 루틴 로직에 그대로 녹아 있어요. 화려한 약속 대신, 검증된 규칙으로.',
              style: kr(size: 14, color: AppColors.inkDim).copyWith(height: 1.6)),
          const SizedBox(height: 22),
          _coachChip(),
        ],
      ));

  Widget _slide2() => _centerSlide(
        badge: Icons.architecture,
        title: '적은 기록으로,\n오늘 뭘 할지 정해드려요.',
        sub: '생성형 AI가 아니라 규칙과 계산으로 짭니다. 그래서 왜 이렇게 하는지 이유가 늘 분명해요.',
      );

  Widget _slide3() => _pad(Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ShaderMask(
                shaderCallback: (r) => AppGradients.numberInk.createShader(r),
                child: Text('100', style: mono(size: 76, weight: FontWeight.w600, color: Colors.white).copyWith(height: 1)),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('kg', style: mono(size: 26, color: AppColors.muted)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _titleSub('헬스장에선\n한 손으로 빠르게.', '중량·반복·RIR만 툭툭. 오늘 할 운동이 언제나 첫 화면에 있어요.'),
        ],
      ));

  Widget _slide4() => _pad(Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _adjBar(),
          const SizedBox(height: 28),
          _titleSub('무리하면,\n안전한 범위에서 조절해요.', '무리하지 않고 지속하는 것 — 박민재 방식의 핵심이에요. 바뀔 땐 이유도 함께 알려드려요.'),
        ],
      ));

  Widget _slide5() => _pad(Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _miniTabs(),
          const SizedBox(height: 24),
          _titleSub('기록·추세·습관까지,\n한곳에서.', '이미 계정이 있으면 로그인하고, 없으면 간단한 가입으로 시작해요.'),
        ],
      ));

  Widget _pad(Widget child) => Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: child);

  Widget _centerSlide({required IconData badge, required String title, required String sub}) => _pad(Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [_badge(badge), const SizedBox(height: 26), _titleSub(title, sub)],
      ));

  Widget _titleSub(String t, String s) => Column(
        children: [
          Text(t, textAlign: TextAlign.center, style: kr(size: 26, weight: FontWeight.w700, spacing: -0.4).copyWith(height: 1.3)),
          const SizedBox(height: 14),
          Text(s, textAlign: TextAlign.center, style: kr(size: 14, color: AppColors.inkDim).copyWith(height: 1.6)),
        ],
      );

  Widget _badge(IconData icon) => Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: AppGradients.glass,
          border: Border.all(color: AppColors.hairStrong),
          boxShadow: AppShadow.glow(AppColors.accentGlow, blur: 30, spread: -10),
        ),
        child: Icon(icon, size: 34, color: AppColors.accent),
      );

  Widget _coachChip() => Container(
        padding: const EdgeInsets.fromLTRB(7, 7, 12, 7),
        decoration: BoxDecoration(
          color: AppColors.fill,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.hairStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppGradients.accent),
              child: Center(child: Text('박', style: kr(size: 12, weight: FontWeight.w700, color: AppColors.chipInk))),
            ),
            const SizedBox(width: 9),
            Text.rich(TextSpan(children: [
              TextSpan(text: '코치 박민재', style: kr(size: 12, weight: FontWeight.w600, color: AppColors.ink)),
              TextSpan(text: ' · 훈련 설계', style: kr(size: 12, color: AppColors.inkDim)),
            ])),
          ],
        ),
      );

  Widget _adjBar() => SizedBox(
        width: 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('기준 중량', style: mono(size: 11, color: AppColors.muted)),
                Text('−2.5kg', style: mono(size: 11, color: AppColors.muted)),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Container(
                height: 8,
                color: AppColors.fill,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.64,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppGradients.accent,
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: AppShadow.glow(AppColors.accentGlow, blur: 12, spread: 0),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('“무겁게 가고 있어요 — 오늘은 조금 낮출게요.”',
                textAlign: TextAlign.center,
                style: kr(size: 12, color: AppColors.accent, style: FontStyle.italic)),
          ],
        ),
      );

  Widget _miniTabs() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _mt(Icons.monitor_heart, '오늘', true),
          const SizedBox(width: 16),
          _mt(Icons.calendar_month, '기록', false),
          const SizedBox(width: 16),
          _mt(Icons.search, '검색', false),
          const SizedBox(width: 16),
          _mt(Icons.water_drop, '습관', false),
          const SizedBox(width: 16),
          _mt(Icons.person, '프로필', false),
        ],
      );

  Widget _mt(IconData icon, String label, bool on) => Column(
        children: [
          Icon(icon, size: 20, color: on ? AppColors.accent : AppColors.muted),
          const SizedBox(height: 5),
          Text(label, style: kr(size: 8.5, color: on ? AppColors.accent : AppColors.muted)),
        ],
      );

  Widget _cta(String label, VoidCallback onTap) => Container(
        decoration: BoxDecoration(
          gradient: AppGradients.accent,
          borderRadius: BorderRadius.circular(AppRadius.ctrl),
          boxShadow: AppShadow.glow(AppColors.ctaGlow, blur: 26, spread: -8),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.ctrl),
            onTap: onTap,
            child: Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Text(label, style: mono(size: 15, weight: FontWeight.w600, color: AppColors.ctaInk, spacing: 0.2)),
            ),
          ),
        ),
      );
}

class _Dots extends StatelessWidget {
  final int count, active;
  const _Dots({required this.count, required this.active});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: i == active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: i == active ? AppGradients.accent : null,
                  color: i == active ? null : AppColors.hairStrong,
                ),
              ),
            ),
        ],
      );
}
