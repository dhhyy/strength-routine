import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 디자인 토큰 — 앱의 모든 스타일은 여기서만 온다. (가변 레이어 / 단일 진실 공급원)
/// 스타일을 바꾸려면 이 파일만 교체한다. 나머지 코드는 그대로 상속받는다.
/// 현재: Console v2 — 블루프린트 다크 + 시안, 그라데이션·글래스·은은한 깊이.
class AppColors {
  // 바탕 (그라디언트 양끝)
  static const bg = Color(0xFF0A0C11);
  static const bgLift = Color(0xFF182129);
  static const bgDeep = Color(0xFF0A0C11);
  // 텍스트
  static const ink = Color(0xFFDCE3EB);
  static const inkDim = Color(0xFFAEB7C1);
  static const muted = Color(0xFF8A95A1);
  // 액센트 (단색 + 그라디언트 양끝)
  static const accent = Color(0xFF5CD0EC);
  static const accentA = Color(0xFF63D3EE);
  static const accentB = Color(0xFF3AA6C9);
  // 의미색
  static const good = Color(0xFF5AD19A);
  static const goodA = Color(0xFF6FE0B0);
  static const goodB = Color(0xFF3FBF8B);
  static const warn = Color(0xFFE6B45A);
  static const danger = Color(0xFFE5766B);
  // 표면·선 (은은하게 = 반투명)
  static const hair = Color(0x12FFFFFF); // ~7% 흰색: 부드러운 경계
  static const hairStrong = Color(0x1FFFFFFF); // ~12%
  static const glassTop = Color(0xB81E2732); // 글래스 패널 위
  static const glassBot = Color(0xA8131921); // 글래스 패널 아래
  static const fill = Color(0x14FFFFFF); // ~8%: 게이지 트랙
  static const hairFaint = Color(0x05FFFFFF); // ~2%: 미세 하이라이트
  // 액센트 위 텍스트
  static const ctaInk = Color(0xFF06232B);
  static const chipInk = Color(0xFF0A2A33);
  // 글로우 (그림자용, 미리 계산한 알파)
  static const accentGlow = Color(0x8C5CD0EC);
  static const goodGlow = Color(0x8C5AD19A);
  static const ctaGlow = Color(0x995CD0EC);
  static const warnBorder = Color(0x66E6B45A);
  static const accentBorder = Color(0x335CD0EC);
  static const accentSoft = Color(0x245CD0EC); // 오늘 셀 배경 등
  // 하단 탭바
  static const navBg = Color(0xF20B0E13);
  static const navIndicator = Color(0x1F5CD0EC);
}

/// 간격 스케일 — 마진을 흩뿌리지 않고 규칙적으로.
class AppSpace {
  static const x1 = 4.0, x2 = 8.0, x3 = 12.0, x4 = 16.0, x5 = 20.0, x6 = 24.0;
}

/// 모서리 스케일.
class AppRadius {
  static const panel = 20.0, ctrl = 14.0, pill = 999.0, bar = 6.0;
}

/// 그라디언트 — 깊이감의 재료.
class AppGradients {
  static const accent = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [AppColors.accentA, AppColors.accentB],
  );
  static const good = LinearGradient(
    begin: Alignment.centerLeft, end: Alignment.centerRight,
    colors: [AppColors.goodA, AppColors.goodB],
  );
  static const glass = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [AppColors.glassTop, AppColors.glassBot],
  );
  static const numberInk = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [Color(0xFFF2F6F9), Color(0xFFAEB9C4)],
  );
  static const chartArea = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [Color(0x405CD0EC), Color(0x005CD0EC)],
  );
  static const thumb = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0x285CD0EC), Color(0x143AA6C9)],
  );
  static const screen = RadialGradient(
    center: Alignment(0.0, -1.0), radius: 1.2,
    colors: [AppColors.bgLift, AppColors.bgDeep], stops: [0.0, 0.55],
  );
  static const glow = RadialGradient(
    center: Alignment(0.35, -0.92), radius: 0.7,
    colors: [Color(0x1A5CD0EC), Color(0x005CD0EC)],
  );
}

/// 그림자 — 은은한 입체감.
class AppShadow {
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x99000000), blurRadius: 30, spreadRadius: -16, offset: Offset(0, 12)),
  ];
  static const List<BoxShadow> control = [
    BoxShadow(color: Color(0x59000000), blurRadius: 10, spreadRadius: -3, offset: Offset(0, 3)),
  ];
  static List<BoxShadow> glow(Color color, {double blur = 16, double spread = -4}) =>
      [BoxShadow(color: color, blurRadius: blur, spreadRadius: spread)];
}

/// 수치용 모노스페이스 (tabular 정렬). Latin/숫자 전용.
TextStyle mono({
  double size = 12,
  FontWeight weight = FontWeight.w500,
  Color color = AppColors.ink,
  double spacing = 0,
}) =>
    GoogleFonts.getFont('IBM Plex Mono',
            fontSize: size, fontWeight: weight, color: color, letterSpacing: spacing)
        .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

/// 한글/본문용 (IBM Plex Sans KR).
TextStyle kr({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.ink,
  double spacing = 0,
  FontStyle style = FontStyle.normal,
}) =>
    GoogleFonts.getFont('IBM Plex Sans KR',
        fontSize: size, fontWeight: weight, color: color, letterSpacing: spacing, fontStyle: style);
