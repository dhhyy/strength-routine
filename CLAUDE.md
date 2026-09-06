# strength_routine — 작업 규칙 (자동 로드)

**UI/디자인 작업을 시작하기 전에 반드시 `design` 스킬을 먼저 사용한다.**
벗어나야 할 이유가 있으면 먼저 사용자에게 확인한다.

## 정본(SSOT) — 항상 일치시킨다
- **왜(불변)**: `docs/05-design-philosophy.md`
- **어떻게(토큰/가변)**: `docs/03-design-system.md` (요구사항 `docs/01-requirements.md`, 엔진 `docs/02-engine-logic.md`)
- **코드**: `lib/tokens.dart`·`theme.dart`·`widgets.dart`
- 코드 토큰/위젯을 바꾸면 `docs/03-design-system.md`도 갱신한다.

## 방향 & 스타일
**Direction C · Console v2** — 블루프린트 다크 + 시안, **그라디언트·글래스·은은한 깊이·낮은 밀도**. 모든 시각 결정은 이 컨셉과 `05` 철학에서 파생한다. (단일 다크 테마)

## 불변 vs 가변
- **스타일은 `tokens.dart`에서만** 바뀐다. 스타일 변경 = 새 토큰 세트만. 컴포넌트·레이아웃·프로세스는 그대로.

## 절대 규칙 3가지
1. **토큰 밖 금지.** 색·간격·폰트를 새로 만들지 말고 `AppColors`·`AppSpace`·`AppRadius`·`AppGradients`·`AppShadow`·`mono()`/`kr()`에서 가져온다. (`Color(0x…)`·매직 간격 하드코딩 금지 — `tokens.dart` 예외)
2. **조립 우선.** 새 UI는 먼저 `widgets.dart`의 기존 컴포넌트로 조립. 없을 때만 새 컴포넌트를 만들고 `widgets.dart` + `03 §컴포넌트`에 등록.
3. **새 화면은 `design` 스킬 절차 + `03 §체크리스트`를 통과시킨다.**

## 자주 틀리는 함정
- **한글은 `kr()`, 숫자/라틴은 `mono()`** (IBM Plex Mono엔 한글 글리프 없음 → 깨짐).
- 숫자가 세로로 정렬되는 곳은 `mono`(tabular).
- **깊이는 그라디언트+소프트 섀도우+글래스로.** 카드/보더/그림자·큰 radius 남발 금지.
- **하단 탭 5개 고정**(오늘·기록·검색·습관·프로필). 6번째 금지.
- **의미색**(good/warn/danger)은 상태 전용, 브랜드 액센트와 섞지 않는다.

## 아키텍처
- **엔진(순수 함수) ↔ UI 분리.** 위젯은 엔진이 준 값을 렌더만. 로직 규칙은 격리 단위로 추가(`02 §5`).

## 검증
- 변경 후 `flutter analyze` 통과. UI 변경은 렌더로 계층·대비·정렬·밀도 확인.

## 진행 관리
- 마일스톤(문서·기능 완료) 시 `docs/00-overview.md`의 진행 상태를 갱신한다.
