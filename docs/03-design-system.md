# 디자인 시스템 — Console v2 (깊이·은은함)

> 상태: v0.2 · 기준일: 2026-09-05
> 위계: `05-design-philosophy.md`(왜/불변) → **이 문서(어떻게/토큰·가변)** → `../CLAUDE.md`·`design` 스킬(강제)
> 관련: `01-requirements.md`, `02-engine-logic.md`
> 코드 SSOT: `../lib/tokens.dart`, `theme.dart`, `widgets.dart`

---

## 0. 목적과 사용법

**모든 화면이 일관되게 유지되도록 하는 단일 기준.** 두 SSOT(이 문서 ↔ 코드 토큰)는 항상 일치.

**절대 규칙 3가지**
1. 여기 없는 **색·간격·폰트를 새로 만들지 않는다.** 토큰에서만.
2. 새 UI는 **먼저 조립**을 시도. 없을 때만 새 컴포넌트를 `widgets.dart` + §7에 등록.
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
| `WorkoutSetRow` / `SetEditor` | `workout_screen.dart` | 목표/실제 분리, kg/lb·초안/완료/제외, 입력·오류·재시도, 저장 후 다음 미기록 세트·닫기 재시도 |
| `SearchScreen` / 운동 구성 상세 | `search_screen.dart` | 실제 프로그램·진행/보관 계획 검색, 출처별 읽기 전용 세트 구성 |
| `SavedRecordsScreen` | `training_screens.dart` | 실제 기록·활성 계획 날짜 탐색, 미래/보관 기록 읽기 전용 |

설계 근거와 렌더 검증은 [DESIGN.md](../DESIGN.md), [9/7 작업 기록](2026-09-07-work-log.md)에 남긴다.

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
- v0.3 (2026-09-07): 프로그램 선택→결과 확인→실제 세트 기록 구성 요소와 로컬 폰트 등록.
- v0.2 (2026-09-05): Console v2 — 그라디언트·글래스·은은한 깊이·점진적 노출 반영. `05` 철학 연결.
- v0.1: 최초 (플랫 Console).
