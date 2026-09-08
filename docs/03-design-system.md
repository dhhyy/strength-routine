# 디자인 시스템 — Console v2 (깊이·은은함)

> 상태: v0.4 · 기준일: 2026-09-08
> 위계: `05-design-philosophy.md`(왜/불변) → **이 문서(어떻게/토큰·가변)** → `../CLAUDE.md`·`design` 스킬(강제)
> 관련: `01-requirements.md`, `02-engine-logic.md`
> 코드 SSOT: `../lib/tokens.dart`, `theme.dart`, `widgets.dart`
> 웹 랜딩 SSOT: [`../landing/tokens.css`](../landing/tokens.css), [`../landing/styles.css`](../landing/styles.css) · 앱과 별개 체험

---

## 0. 목적과 사용법

**모든 화면이 일관되게 유지되도록 하는 단일 기준.** 두 SSOT(이 문서 ↔ 코드 토큰)는 항상 일치.

**절대 규칙 3가지**
1. 여기 없는 **색·간격·폰트를 새로 만들지 않는다.** 토큰에서만.
2. 새 UI는 **먼저 조립**을 시도. 없을 때만 새 컴포넌트를 등록한다. Flutter는 `widgets.dart` + §7, 웹 랜딩은 `landing/styles.css` + §7의 웹 카탈로그를 따른다.
3. 새 화면은 **`design` 스킬 절차 + §10 체크리스트**를 통과.

> **스타일은 이 문서(토큰)에서만 바뀐다.** 스타일 변경 = 토큰 교체. 컴포넌트·레이아웃·프로세스는 불변(`05`).

---

## 1. 디자인 원칙 (요약 — 전체는 `05`)
- 일관성 > 개별 화려함
- **은은한 깊이** (그라디언트·소프트 섀도우·글래스·배경광 — 화려함 아님)
- **은은함** (낮은 대비, 딱딱한 경계선 최소화, 색 절제)
- **대담함은 한 곳에만**
- **낮은 밀도·점진적 노출** (여백은 콘텐츠)
- 상태는 형태로 인코딩 · AI 기본룩 회피

---

## 2. 컨셉 / 방향
**Console v2 — 블루프린트 다크 + 시안, 은은한 깊이.** 데이터 감각(모노 수치)은 유지하되, 평면을 **그라디언트 표면·글래스·소프트 섀도우**로 입체화하고, 정보는 **점진적 노출**로 덜어낸다.

---

## 3. 색 토큰 (`AppColors`)

| 토큰 | HEX | 용도 |
|---|---|---|
| `bg` / `bgLift` / `bgDeep` | `#0A0C11` / `#182129` / `#0A0C11` | 바탕 앰비언트 그라디언트 양끝 |
| `ink` / `inkDim` / `muted` | `#DCE3EB` / `#AEB7C1` / `#8A95A1` | 텍스트 3단계 |
| `accent` (`accentA`~`accentB`) | `#5CD0EC` (`#63D3EE`→`#3AA6C9`) | 브랜드 액센트 + 그라디언트 |
| `good`/`warn`/`danger` | `#5AD19A` / `#E6B45A` / `#E5766B` | 의미색 (good엔 `goodA/goodB` 그라디언트) |
| `hair` / `hairStrong` | `#12FFFFFF` / `#1FFFFFFF` | **반투명 소프트 경계** (딱딱한 선 대체) |
| `glassTop` / `glassBot` | `#B81E2732` / `#A8131921` | 글래스 패널 그라디언트 |
| `fill` | `#14FFFFFF` | 게이지 트랙 |
| `ctaInk` / `chipInk` | `#06232B` / `#0A2A33` | 액센트 위 텍스트 |
| `accentGlow`/`goodGlow`/`ctaGlow` | 알파 프리셋 | 글로우 그림자 |

**규칙**: 텍스트·배경·경계·글로우 전부 토큰에서. 경계는 이제 **하드 라인이 아니라 `hair`(반투명)**. 단일 다크 커밋.

## 3-1. 그라디언트·그림자 (`AppGradients` / `AppShadow`) — 깊이의 재료
- `AppGradients.glass` — 글래스 패널 표면 · `.screen` — 화면 앰비언트 · `.glow` — 은은한 액센트 배경광
- `AppGradients.accent` / `.good` — 게이지·칩·CTA 채움 · `.numberInk` — 큰 숫자 ShaderMask
- `AppShadow.card` — 패널 소프트 드롭섀도우 · `AppShadow.glow(color)` — 액센트 글로우

---

## 4. 타이포 (`mono()` / `kr()`)
| 역할 | 폰트 | 헬퍼 |
|---|---|---|
| 수치·데이터·라틴 | IBM Plex Mono | `mono()` |
| 한글·본문 | IBM Plex Sans KR | `kr()` |

2026-09-07: 두 폰트의 400·500·600·700 TTF를 `assets/fonts/`에 포함해 첫 실행에도 네트워크 없이 렌더한다. OFL은 앱 라이선스 화면에 등록한다. 출처·해시는 [폰트 기록](../research/2026-09-07/fonts.md)을 따른다.

`AppType` 역할 토큰: title 24/700, heading 18/600, body 14/400, caption 12/400(muted), action 14/600, number 18/600(mono). 숫자 입력은 number, 한글 라벨은 caption을 사용한다.

**⚠️ IBM Plex Mono엔 한글 글리프가 없다.** 한글은 반드시 `kr()`. 숫자 정렬 열은 `mono`(tabular). 큰 숫자는 `AppGradients.numberInk` + `ShaderMask`.

---

## 5. 간격 · 형태 · 깊이
- **간격** `AppSpace` `4·8·12·16·20·24`. 마진 흩뿌리지 말 것.
- **크기** `AppSize`: touch 48(최소 주요 터치 높이), icon 24, emptyIcon 40.
- **모서리** `AppRadius`: `panel 20` · `ctrl 14` · `pill` · `bar 6`. (v2는 v1보다 부드럽게)
- **경계**: `hair`(반투명). 하드 라인 지양.
- **깊이**: 글래스(`AppGradients.glass` + `BackdropFilter` blur) + `AppShadow.card` + 액센트 글로우. **"모든 게 카드가 아니다"** — 깊이는 은은하게, 한 곳에 몰지 않게 균형.

### 9/8 웹 랜딩 토큰

색·폰트·곡률은 Console v2를 유지하고 웹의 폭·제목·간격 역할을 추가한다. 구현 정본은 [tokens.css](../landing/tokens.css)다. CSS 색의 알파는 `#RRGGBBAA` 순서이므로 Flutter의 `#AARRGGBB`와 혼동하지 않는다.

| 역할 / CSS 토큰 | 값·사용 기준 |
|---|---|
| 바탕·글자 `--bg`, `--bg-lift`, `--ink`, `--ink-dim`, `--muted` | §3과 동일한 기본 색. 단계별 텍스트 대비 유지 |
| 의미색 `--accent`, `--good`, `--warn`, `--danger` | 시안 액션, 초록 실제 수행, 저장 경고, 입력 오류. 색과 상태 문구를 함께 표시 |
| 경계·표면 `--hair`, `--hair-strong`, `--hair-faint`, `--fill`, `--glass` | 흰색 알파 `12/1f/05/14`, 기존 글래스 양끝의 150° 그라디언트 |
| 폰트 `--font-kr`, `--font-mono` | 한글 IBM Plex Sans KR, `.mono` 및 수치 입력 IBM Plex Mono + tabular 숫자. 웹 로드: KR 400/600/700, Mono 400/500/700 |
| 본문 `--text-xs/sm/base/lg/xl` | `.75/.875/1/1.125/1.5rem`. 필드 라벨·본문·구성 제목 역할 |
| 큰 제목 `--text-section`, `--text-display`, `--text-stat` | `clamp(1.75rem,3vw,2.5rem)`, `clamp(2.5rem,4.45vw,4rem)`, `2rem`. 본문보다 히어로 한 곳을 강조 |
| 반응형 제목 `--text-display-compact`, `--text-display-mobile` | `clamp(2.5rem,4.25vw,3.25rem)`, `clamp(2rem,10.25vw,2.5rem)`. 좁은 2열과 420px 이하 제목 역할 |
| 줄 높이·굵기 | `--line-tight/heading/body`: 1.2/1.4/1.8. `--weight-regular/medium/semibold/bold`: 400/500/600/700 |
| 간격 `--s1`~`--s32` | 4·8·12·16·20·24·32·40·48·64·80·96·128px. 명명 숫자×4, 정의된 단계만 사용 |
| 형태 `--radius-panel/control/bar/pill` | 20/14/6/999px. 체험 패널·버튼·입력·태그 역할 |
| 폭·높이 `--content-width`, `--text-width`, `--demo-width/height` | 1200/520/500/510px. 체험 폭은 최대값, 패널 높이는 최소값 |
| 조작·초점 `--touch`, `--icon`, `--nav-height`, `--focus` | 최소 조작 48px, 아이콘 20px, 탐색 높이 80px, 초점선 2px. 기본 CTA는 56px 높이 |
| 깊이·움직임 `--shadow-panel/control`, `--duration-fast/duration/slow`, `--ease` | 소프트 패널/조작 그림자, 160/260/600ms. `prefers-reduced-motion`에서는 전환·애니메이션·부드러운 스크롤 해제 |

웹 크기 전환은 [styles.css](../landing/styles.css)의 1100/820/420px 경계를 따른다. 820px 이하에서 설명→체험의 한 열로 쌓고, 420px 이하에서는 탐색 높이 72px·좌우 간격 20px로 줄인다. 작은 화면의 탐색 높이·제목 토큰 재정의는 `tokens.css`에 둔다. 중량·반복·RIR은 작은 화면에서도 `minmax(0,1fr)` 세 열을 유지한다. 이는 코드의 배치 계약이며 모든 폭의 렌더 통과를 뜻하지 않는다.

---

## 6. 레이아웃 — Fluid / Fixed / Hybrid
- **Fixed**: 상단 날짜/네비, 하단 탭바
- **Fluid**: 스크롤되는 운동 리스트
- **Hybrid**: 상태 밴드·히어로 카드(고정 형태 + 가변 내용)
- **스크롤은 Fluid만.** 하단 탭 5개 고정(오늘·기록·검색·습관·프로필), **6번째 금지**.
- **점진적 노출**: 메인 리프트만 히어로로 크게, 보조는 접힌 행으로. 상세는 필요 시 펼침.

---

## 7. 컴포넌트 카탈로그 (`widgets.dart`)

| 컴포넌트 | 용도 | 변형 |
|---|---|---|
| `GlassPanel` | 깊이의 기본 단위(그라디언트+블러+섀도우) | glow 추가 가능 |
| `ConsoleTopBar` | 날짜 + 이전/다음 | — |
| `StatusBand` | 국면 + 게이지 2 | — |
| `GaugeBar` | 가로 게이지(그라디언트+글로우) | accent/good |
| `QuoteLine` | 명언 | — |
| `RoleChip` | 역할 태그 | mainVolume(그라디언트) / techMaintain / accessory |
| `HeroCard` | 메인 리프트(큰 그라디언트 숫자·점진 노출·글로우 CTA) | — |
| `CollapsedRow` | 보조/기술유지(요약+규칙이유+미니점) | — |
| `NavigationBar`(테마) | 하단 5탭 | — |

**규칙**: 컴포넌트는 격리·재사용. 화면 전용 스타일을 하드코딩하지 말고 토큰/파라미터로.

> **화면 조립 공통 컴포넌트** (`components.dart`): `ScreenScaffold`(화면 골격) · `PillChip`(필터 칩) · `CalendarPanel` · `TrendChart` · `ProgressRing` · `ExerciseTile` · `HabitTile` · `SettingTile` · `AddButton` · `RoundNavButton`.

### 9/7 프로그램·기록 구성 요소

화면 전용 흐름은 별도 파일로 격리하고 기존 GlassPanel 및 토큰을 공유한다.

| 구성 요소 | 위치 | 상태·역할 |
|---|---|---|
| `FlowPage` | `flow_components.dart` | 앱바·안전 영역·키보드 대응 스크롤 골격 |
| `StatePanel` | `flow_components.dart` | 빈 목록/실패/완료의 아이콘·설명·다음 행동 |
| `PrimaryAction` | `flow_components.dart` | 48 최소 높이, 진행 중 중복 입력 차단 |
| `ConsoleField` | `flow_components.dart` | 숫자/메모 입력, 오류 메시지, 비활성 상태 |
| `ProgramScreen` / `ProgramDetailScreen` | `program_screen.dart` | 목록·검색·작성자·기간·주차별 운동 구성 |
| `ProgramSetupScreen` / `RecentRecordEditor` | `program_screen.dart` | 최근 기록·시작일·운동요일·중량 단위·명시 기준값 |
| `PlanReviewScreen` | `program_screen.dart` | 실제 날짜와 목표를 확인한 뒤 최종 저장 |
| `WorkoutDraftPreview` | `workout_screen.dart` | 보관 초안 원문 열람, 읽기 전용·미완료 표시, 닫기만 제공 |
| `WorkoutSetRow` / `SetEditor` | `workout_screen.dart` | 목표/실제 분리, kg/lb·초안/완료/제외, 입력·오류·재시도, 저장 후 다음 미기록 세트·닫기 재시도 |
| `HabitsScreen` | `habits_screen.dart` | 사용자 습관 추가·날짜별 체크·보관/활성화, 실제 완료 수와 저장 실패 재시도 |
| `SearchScreen` / 운동 구성 상세 | `search_screen.dart` | 실제 프로그램·진행/보관 계획 검색, 출처별 읽기 전용 세트 구성 |
| `SavedRecordsScreen` | `training_screens.dart` | 실제 기록·활성 계획 날짜 탐색, 미래/보관 기록 읽기 전용 |

설계 근거와 렌더 검증은 [DESIGN.md](../DESIGN.md), [9/7 작업 기록](2026-09-07-work-log.md)에 남긴다.

### 9/8 웹 랜딩 구성 요소

[landing/index.html](../landing/index.html)의 의미 있는 HTML과 [styles.css](../landing/styles.css)의 클래스를 조립한다. Flutter의 화면·5탭·저장 파일을 대체하지 않는다. 실행·데이터 범위는 [랜딩 README](../landing/README.md)를 따른다.

| 구성 요소 / 선택자 | 역할·상태 |
|---|---|
| `.site-header`, `.nav`, `.brand`, `.skip-link` | sticky 탐색·인라인 로고·키보드의 체험 바로가기. 모바일에서 보조 탐색 접음 |
| `.hero`, `.hero-copy`, `.experience-wrap` | 설명과 실제 체험의 2열 → 1열 배치. 개발 중·체험용 예시를 가까이 표시 |
| `.button-primary/outline`, `.button-small/full`, `.text-link` | 주요/보조 행동, hover·focus-visible·disabled. 서버 신청이나 다운로드로 연결하지 않음 |
| `.demo`, `.step-tabs`, `.demo-panel` | 글래스 패널과 구성/일정/기록 3단계. tab/tabpanel, 선택 상태·roving tabindex, 좌우/Home/End 키 |
| `.program-meta`, `.program-outline`, `.target-row` | 합성 예시 1주·주 1회·2세트의 원래 구성을 표시. 실제 프로그램 목록이 아님 |
| `.date-input`, `.weekdays`, `.next-workout` | 시작일·요일 한 개·계산 날짜. 잘못된 날짜의 오류와 완료/제외 후 일정 잠금 |
| `.set-editor`, `.set-fields`, `.set-actions`, `.field-error` | 빈 입력/작성 중/수행 완료/제외. 필드 오류·첫 오류 초점·수정하기·다음 미기록 초점. 실제값을 목표로 자동 채우지 않음 |
| `.completion-count`, `.progress-track`, `.workout-summary` | 수행 수만 진행 막대에 반영. 제외·작성 중은 별도 문구, live region과 progressbar 속성 |
| `.demo-footer`, `#save-status`, `.reset-button`, `#reset-dialog` | 저장 성공/차단/손상·초기화 실패 안내. native dialog의 확인 후 체험 키 삭제→새 상태 저장, 취소/Escape는 유지 |
| `.feature-row`, `.scope-lines`, `.faq-list`, `.rir-help` | 기능 설명·현재 범위·native details/summary. 외부 설명 영상이나 모집 폼 없음 |
| `.closing`, `.site-footer`, `.notice` | 기록 체험 이동·로컬 폰트 라이선스·JavaScript 비활성 안내 |

초기 상태는 값 없는 두 세트다. 저장은 동기식 `localStorage`이며 원격 로딩 화면은 없다. 읽기 손상 시 기존 저장값을 덮어쓰지 않고, 쓰기 차단 시 현재 화면에서만 유지됨을 알린다. 초기화의 키 삭제가 실패하면 화면만 초기화하고 재접속 시 이전 기록이 나타날 수 있다는 경고를 남긴다. 이 웹 체험의 상태 계약을 Flutter 앱 전체의 저장·일정 정책으로 확대하지 않는다. 브라우저 검증 결과는 코드 등록과 구별해 담당자의 실제 확인 후 기록한다.

9/8 담당 실행 결과: headless Chromium의 35개 브라우저 검사 통과. 정확한 버전·검사 항목은 [검증 로그](../research/2026-09-08/landing/browser-check.json), 렌더 증거와 실행 범위는 [랜딩 README](../landing/README.md)를 따른다. 다른 브라우저·실제 모바일 기기의 통과를 뜻하지 않는다.

---

## 8. 상태 디자인 (필수) — `01` 연동
| 상태 | 표현 |
|---|---|
| 완료 / 진행 / 대기 | `good`+점 / accent 글로우 / muted |
| 빈 상태 | 비난 없는 안내 + 다음 행동 |
| 저장/생성 실패 | 입력 유지 + 재시도 + 원인(사과 금지), 임의 데이터 금지 |

자동 조정: **한 줄 이유 + 되돌리기** (의료 표현 금지).

---

## 9. 카피
사용자 언어 · 능동태(동작=결과 일치) · 에러는 원인+해결 · 담백.

---

## 10. ⭐ 새 화면 체크리스트
- [ ] 단 하나의 목적을 적었는가
- [ ] Fluid/Fixed/Hybrid로 나눴는가
- [ ] 색·간격·폰트·그라디언트를 토큰에서만 가져왔는가 (하드코딩 0)
- [ ] 기존 컴포넌트 조립 / 새 컴포넌트 등록했는가
- [ ] 깊이는 은은한가, 대담함은 한 곳인가, 밀도는 낮은가
- [ ] 상태(빈/실패/완료)를 설계했는가
- [ ] 숫자 `mono` · 한글 `kr` 인가
- [ ] 렌더를 캡처해 검토했는가 · AI 기본룩을 피했는가

---

## 11. 강제 장치
- `design` 스킬(절차) · `CLAUDE.md`(가드레일) · hooks(기계적 검사: 하드코딩 색 검출·`flutter analyze`).
- 이 문서(토큰)와 코드는 항상 일치.

## 변경 이력
- v0.4 (2026-09-08): 독립 웹 랜딩의 Console v2 토큰 매핑·반응형 계약·HTML/CSS 컴포넌트와 상태 등록. 렌더 검증 결과와 구별.
- v0.3 (2026-09-07): 프로그램 선택→결과 확인→실제 세트 기록 구성 요소와 로컬 폰트 등록.
- v0.2 (2026-09-05): Console v2 — 그라디언트·글래스·은은한 깊이·점진적 노출 반영. `05` 철학 연결.
- v0.1: 최초 (플랫 Console).


## 9/8 앱 기능 확장 컴포넌트

| 구성 요소 | 코드·조립·상태 |
|---|---|
| 관리자 편집/검토 | `admin/admin_screen.dart`: FlowPage·GlassPanel·역할별 폼·날짜 없는 주간세션; 빈 초안/오류/저장실패/내보내기/교체 확인. ID·숫자 mono, 한글 body, 입력 enabled hairStrong/focused accent |
| 기록 추세/제안 | `training_insights_screen.dart`: 계획 선택·수행 막대/수치·제안 이유·날짜별 before→after 모달·이력. bgLift 모달, accent/good 상태, 없음/누락/실패/undo 제한 |
| 운동 목표 표시 | `workout_screen.dart`: 원래 목표를 보존하며 적용된 kg가 있으면 `조정 목표`로 표시, 세트/반복/RIR은 보존 |
| 앱 설정 | `settings_screen.dart`: 기본 kg/lb SegmentedButton·제안 표시 Switch, 저장 전 선택/실패/성공 구분. 기존 accentSoft/fill/hairStrong 토큰 |
| 도움말/구독 준비 | `support_screen.dart`, `subscription_screen.dart`: 실제 로컬 FAQ ExpansionTile과 준비 상태. 미연결 구매·문의 버튼 없음 |

하단 5탭을 유지한다. 기록 탭은 추세·조정으로, 프로필은 설정·도움말·구독 안내로 연결한다. 관리자 도구는 소비자 탭에 넣지 않는다. 토큰 수치를 새로 만들지 않고 기존 AppSpace/AppSize/AppType/AppColors로 조립했다. [렌더와 테스트](2026-09-08-feature-verification.md)에 최초 문제·수정·재검증을 남긴다.

## 9/8 Three.js 랜딩 시안 구성 요소

`landing/concepts/`의 정적 웹 구성 요소다. 앱 토큰을 매핑한 기존 `landing/tokens.css`를 상속하고 `concepts/tokens.css`에 제목·수치·본문 폭·장면 높이·겹침 역할을 선언한다. 3D 재질은 CSS의 `bg`, `bg-lift`, `ink`, `muted`, `accent`, `good`, `hair-strong`, `cta-ink`를 읽는다. 캔버스 내 지오메트리 좌표·조명 강도는 CSS 여백 토큰과 구분한다.

`Strength Latin`은 별도 폰트가 아니라 번들 IBM Plex Mono의 ASCII 글자·숫자 범위 별칭이다. 한글·공백·문장부호는 IBM Plex Sans KR, 수치 전용 output/mono 클래스는 IBM Plex Mono를 사용한다. 1440/390/320px의 실제 렌더에서 혼합 문장의 줄바꿈을 확인한다.

| 구성 요소 / 선택자 | 역할·상태 |
|---|---|
| `.topbar`, `.wrap`, `.btn`, `.feature-strip`, `.footer` | 공유 탐색·본문 폭·주/보조 행동·제품 흐름·체험 고지; 반응형·초점·비활성 |
| `.concept-link`, `.concept-thumbnail` | 비교용 목차; 실제 렌더 이미지와 각 독립 시안 링크 |
| `.scene`, `.scene-status`, `.scene-controls` | 3D 호스트·로딩·실패·복구; 캔버스 대신 읽을 설명, 회전·시점 초기화 버튼 |
| `.load-hero`, `.load-readout`, `.load-controls` | 바벨 무대·총중량·슬라이더/±·초기화; 20/120kg 경계 |
| `.catalog-layout`, `.program-choice`, `.catalog-detail` | 실제 프로그램 목록·선택 공간·기간/빈도/운동 상세; 로딩·실패·재시도·페이지 순환 |
| `.calendar-stage`, `.weekdays`, `.calendar-console`, `.schedule-table` | 주간 패턴·요일 버튼·시작일·전체 일정; 선택 수 오류·날짜 오류·닫기 |
| `.session-visual`, `.session-counter`, `.record-set`, `.record-fields` | 실제 입력·세트별 완료 표시·집계; 검증 오류·읽기 전용·수정·다음 초점 |
| `#record-status`, `#record-reset-dialog` | 저장 성공/차단/손상/삭제 실패; 취소·Escape 보존, 해당 체험 키만 초기화 |
| `.insights-stage`, `.chart-legend`, `.chart-readout`, `.change-row` | 과거/오늘/미래 그래프와 숫자 비교; 미래만 적용·되돌림·범례 동기화 |
| `#adjust-dialog`, `#adjust-history` | 적용 전후 검토·취소·적용 결과·되돌리기 안내 |

전체 장면은 자동 반복 회전하지 않고 입력 후에만 필요한 프레임을 렌더한다. 클릭/탭 대안과 키보드 접근을 제공하며 감소된 모션에서는 보간을 끈다. 로딩 실패 때도 DOM 입력을 유지한다. 캔버스는 보조 표현이고 의미 있는 수치·선택·오류는 HTML에 둔다. 구체적인 조작 계약과 렌더 수정·검증 범위는 [시안 보고서](2026-09-08-interactive-landing-concepts.md)를 따른다.

## 9/8 실제 수행일·기록 마감 구성 요소

기존 Flutter Console v2를 확장한다. 새 색·간격·폰트 토큰은 추가하지 않았고, FlowPage·GlassPanel·ConsoleField·PrimaryAction을 화면 안에서 조립한다. 아래 사적 위젯은 해당 화면의 조립 단위이며 공용 스타일 정본을 새로 만들지 않는다.

| 구성 요소 | 코드·상태·상호작용 |
|---|---|
| 수행일 선택 | `SetEditor`, 키 `set-performed-date-picker`: 확인 가능한 실제 날짜, 변경/날짜 지정, 날짜 선택 취소, 과거 미상, 잘못된 원문, 미래 날짜 차단. 날짜는 mono, 설명은 KR |
| 날짜 초안 미리보기 | `WorkoutDraftPreview`: 보관 초안의 `performedDate` 원문을 기존 중량/반복/RIR/메모와 함께 조회; 저장·정정 행동 없음 |
| 기록 요약 | `_SessionSummaryView`: 실제 수행·제외·미기록·초안·필수 미기록·실제 날짜 목록·미상 수를 구분; 초안 수를 수행량에 더하지 않음 |
| 마감·재개 | `WorkoutScreen`, 키 `session-lifecycle-action`: ‘기록 마감’/‘기록 다시 열기’, 조건 부족·미저장·진행 중 비활성, 마감 뒤 세트 잠금 |
| 확인창 | `_SessionLifecycleDialog`: bgLift·기존 action 토큰·스크롤 가능한 요약, 취소/저장 중/실패/동일 동작 재시도. 마감 시각과 운동 종료 시각의 의미를 구별 |
| 기록 기준 선택 | `SavedRecordsScreen`, 키 `record-date-basis`: 예정일/수행일 SegmentedButton. accentSoft·fill·hairStrong으로 선택/비선택 구별 |
| 날짜 셀 | 기존 7열 달력, 날짜와 기록 표시를 세로 배치. 셀 높이는 `MediaQuery.textScalerOf(context).scale(AppSize.touch)`로 큰 글자에 대응; 글자를 잘라내거나 축소하지 않음 |
| 날짜별 세션 카드 | `_SessionCard`: 원래 예정일·세션 전체 수·선택한 날 실제 수행 수·마감/재개/과거 미상. 같은 세션의 여러 실제 날짜에서도 동일 ID로 상세 조회 |
| 과거 세션 메모 | `WorkoutScreen`의 GlassPanel: 저장된 비어 있지 않은 세션 메모의 원문·줄바꿈 유지. 보관 메모만 있는 세션도 달력에서 접근 |

375×812·1.5배 글자·300px 키보드 inset 조건에서 실제 번들 폰트로 렌더한다. 초기에 정사각 날짜 셀에서 두 줄이 7.9px 넘친 것을 확인해 셀 높이 계산을 수정했다. 최종 이미지·시험 범위는 [수행일·마감 검증](2026-09-08-session-lifecycle-verification.md)을 따른다. 해당 이미지는 실제 기기 캡처가 아닌 headless 위젯 렌더다.

## 9/8 관리자 정밀 편집 구성 요소

기존 Console v2와 FlowPage·GlassPanel·PrimaryAction으로 구성하며 새 브랜드 토큰을 만들지 않았다. 운영자용 편집기에는 실제 ID·버전·기준 리프트를 표시해 프로그램 식별과 변경 범위를 판단할 수 있게 한다. 일반 사용자 탭에는 추가하지 않는다.

| 구성 요소 | 역할·상태 |
|---|---|
| 카탈로그 프로그램 카드 | `AdminScreen`: 기존 프로그램 정밀 편집·복제, 저장 중 잠금. 미저장 초안 교체는 확인 후 파일 저장이 성공해야 진입 |
| 프로그램 정보 | `DetailedRoutineScreen`: 접을 수 있는 메타데이터 폼, 원래 ID·버전·작성자·설명 원문, 새 버전 검증 |
| 주차/세션 선택 | 현재 범위를 표시하는 ChoiceChip·주차 복사/삭제·세션 조작. 선택색 accentSoft/accent, 원래 구조와 분리된 새 초안에만 적용 |
| 운동/세트 편집 | 운동 ExpansionTile 아래 독립 세트 행. 반복·RIR·중량 방식·고정/비율 값·기준 리프트·필수 여부·ID·이동·삭제 |
| 반응형 세트 행 | 넓은 화면은 관련 입력 3열, 좁은 화면은 세로 배치. 글자를 줄이거나 수치를 생략하지 않고 스크롤로 접근 |
| 되돌리기/재실행 | 이력이 있을 때만 활성, 필드 연속 입력 묶음과 구조 동작별 최대 50단계, 되돌린 원문도 자동 저장 |
| 복사/삭제 확인창 | 적용할 원본/대상 주차와 범위 확인, 취소 시 원문 동일, 기존 대상 세션 수 차이를 설명 |
| 변경 검토 | 전체 프로그램과 세트 처방 전후, 추가/변경/삭제 수. 순서·이름·메타데이터는 별도로 전체 구성에서 확인 |
| 저장 실패 | 초안 실패와 카탈로그 확정 실패 구별, 같은 검토 후보 재시도. 부모 메뉴의 작업 실패는 상단에서 같은 작업 재선택 안내 |
| 빈 구성 복구 | 정밀 초안에 주차/세션이 없을 때 명시적으로 추가. 저장 진행/실패 시 이탈 보호는 일반 편집과 동일 |

첫 데스크톱 렌더에서 수직으로 긴 입력을 3열로 바꾸고 ChoiceChip·Switch의 기본 색을 Console 토큰으로 통일했다. 1200px·375px·1.5배 글자·키보드 인셋의 최종 렌더와 동작 검증은 [정밀 편집 문서 §13](2026-09-08-admin-precise-editor.md#13-구현검증커밋-기록)을 따른다.
