# UI 효과 참고 자료 — Libraries.dev (수집본)

> 상태: **참고 자료 · 현재 미사용** · 기준일: 2026-09-05
> 관련: `03-design-system.md` (채택 시 반드시 이 규칙 경유)
> 성격: 아이디어 보관용 카탈로그 — **쇼핑 목록이 아니라 참고 라이브러리**

---

## 0. 먼저 읽기 (경고 3가지)

1. **지금 쓰지 않는다.** 나중을 위한 보관용이다.
2. **직접 이식 불가.** 전부 **React** 대상(일부만 SwiftUI/RN). **Flutter판 없음** → 우리 앱에 쓰려면 `npm install`이 아니라 **Flutter로 재구현**해야 한다.
3. **대부분 장식적** → 우리 방향 **Console(절제·엔지니어링)**과 상충. 다 넣으면 `03` 일관성이 깨진다. 여기 모으는 건 **아이디어**이지 채택 결정이 아니다.

---

## 1. 출처

- **Libraries.dev** — "High-crafted UI libraries for AI agents" (모던/AI 앱용 UI 효과).
- 제작: **Jakub Antalik** (Orbs: Alexandr Brinza, Metal: Martin Petercak 도움).
- 발견 경로: X 게시물 **@xin_pai88825 (Paidax)**, 2026-09-04 — 컴포넌트 라이브러리로 추천.
- 신뢰도 참고: Vercel·Intercom·Stripe 관계자 추천 문구 게재.
- 배포 모델 특이점: **"효과를 프롬프트로 배포"** — 프롬프트를 복사해 코딩 에이전트(Claude Code/Cursor/Codex)에 붙이면 설치·연결. Playground 제공, Pro는 Studio에서 심화 커스터마이즈/설정 export.
- 라이선스·기술: **MIT, npm 무료 · React 18+** (Image만 `three` 필요) · 5개 합 ~83KB gzip. **Beam·Orb는 SwiftUI/React Native 버전도 존재**, 나머지는 React 전용(확장 예정). **Flutter 미지원.**

---

## 2. 효과 카탈로그

| 효과 | npm 패키지 | 한 줄 설명 | 우리 앱 후보 위치 | Console 적합도 | Flutter 재현 난이도 |
|---|---|---|---|---|---|
| **Border beam** | `border-beam` | 테두리를 도는 글로우(무지개) | '지금 칠 세트(now)' 미세 강조 | △ (톤다운·시안 단색 조건부) | 쉬움~보통 (`AnimationController`+`CustomPainter` 그라디언트 테두리) |
| **Thinking orbs** | `thinking-orbs` | AI용 '생각하는 구슬' 로딩 | **루틴 생성 3초 진행 화면**(`01` 생성 경험) | ○ (가장 유망, 시안 단색으로) | 보통 (파티클/글로우 애니) |
| **Gooey** | `liquid-gooey` | 액체처럼 뭉치고 변형되는 UI | 없음 | ✕ (장식 과다) | 어려움 (프래그먼트 셰이더/필터) |
| **Liquid Metal** | `metal-fx` | 버튼/아이콘 실시간 크롬 링 | 없음 | ✕ (Console과 이질) | 어려움 (셰이더) |
| **Image generation** | `img-fx` | WebGL 이미지 생성 로더 | 없음(이미지 생성 기능 없음) | ✕ | 매우 어려움 (WebGL/`three` 성격) |

> 적합도: ○ 유망 · △ 조건부 · ✕ 보류

---

## 3. 만약 나중에 채택한다면 (필수 절차)

`03-design-system.md`를 벗어나지 않도록:

1. **재구현**한다 (import 아님). Flutter 위젯으로.
2. **토큰 경유** — 색은 `AppColors`(무지개·크롬 금지, 시안/의미색만), 간격은 `AppSpace`.
3. **Console 톤으로 절제** — 원본의 화려함을 그대로 쓰지 않고 낮춘다.
4. **"대담함은 한 곳에만"** 원칙 유지 — 한 화면에 효과 하나 이상 넣지 않는다.
5. `widgets.dart`에 컴포넌트로 추가 + `03 §7 카탈로그`에 등록(격리·재사용).
6. 시뮬레이터 렌더로 계층·성능(애니/셰이더 프레임) 검토.

---

## 4. 현재 판단 (스냅샷 · 2026-09-05)

- **보관**: 5개 전부 (아이디어로).
- **후보**(나중에 검토): `Thinking orbs`(생성 진행 화면), `Border beam`(now 세트 미세 강조).
- **보류**: `Gooey`, `Liquid Metal`, `Image generation` — Console 방향과 불일치 + 재현 비용 큼.

---

## 링크

- 사이트: https://libraries.dev
- 출처 게시물: https://x.com/xin_pai88825/status/2095717635333726601
- npm: `border-beam` · `thinking-orbs` · `liquid-gooey` · `metal-fx` · `img-fx`
