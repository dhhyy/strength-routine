# 9/8 · SF04 공용 여백 토큰 연결 검증

변경: `lib/widgets.dart`의 GlassPanel 기본 padding16을 `AppSpace.x4`, HeroCard padding20을 `AppSpace.x5`로 연결했다. 기존 화면 값과 계층은 유지하고 토큰 참조 누락을 수정한다. 의미 없는 새 단위 시험을 만들지 않고 실제 공용 패널을 사용하는 기존 백업 화면 시험·렌더를 실행했다.

**[macOS zsh · 앱 루트]**

```sh
flutter test test/backup_screen_test.dart --no-pub --name 'corrupt import|review and recovery' --dart-define=BACKUP_RENDER_DIR=research/2026-09-08/review-fixes/tokens --reporter expanded
```

결과: **2개 통과,14초**, [원문 로그](render-test.txt). 합성 자료·임시 파일·주입된 파일 선택 gateway, 실제 번들 KR/Mono 폰트를 사용했다. 새 기기/Simulator는 실행하지 않았다.

- [실패 상태](backup-error.png): 375×900, 기본 글자. 원인·파일 저장/가져오기·복구본 동작을 읽을 수 있고 패널/버튼/본문이 겹치지 않는다.
- [복원 검토](backup-review-large.png): 375×900,1.8배 글자. 현재/후보 개수와 전체 교체 설명, 명시 복원/취소가 구별된다. 하단은 본문 스크롤로 접근한다.
- [큰 글자 기본 화면](backup-large.png): 같은 큰 글자 시험의 시작 화면 증거다.

수정 후 실패 상태와 검토 이미지를 직접 열어 계층·정렬·여백을 확인했다. 현재값을 유지하는 참조 수정이므로 시각 개선/새 기능을 주장하지 않는다. HeroCard 별도 화면 렌더, 실제 Files 공급자·OS키보드·스크린리더는 이 표본검증 범위가 아니다. 전체 회귀와 분석은 최종 안정화 보고서에서 별도 기록한다.
