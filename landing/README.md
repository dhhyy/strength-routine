# Strength 웹 랜딩 · 9/8

**최신 디자인 시안:** [Three.js 인터랙티브 랜딩 5개](concepts/README.md) · [로컬 비교](http://127.0.0.1:4175/landing/concepts/). 아래 문서는 기존 3단계 랜딩의 계약이며 새 시안의 저장 키·조작과 구분한다.

개발 중인 앱의 **구성 확인 → 일정 선택 → 세트 기록**을 체험하는 독립 정적 페이지다. 9/8 후속 작업으로 앱 카탈로그에 기본 프로그램 5개를 등록했으며, 이 웹 체험은 1주·주 1회·2세트의 합성 예시다. 표시된 반복·RIR은 화면 예시이고 실제 훈련 처방이 아니다.

Flutter 앱과 연결되지 않는다. 웹 입력은 앱의 운동·습관 파일을 변경하지 않으며 외부로 전송하지 않는다. 백엔드·신청 접수·다운로드·배포 기능은 없다. 로컬 HTTP 서버는 정적 파일을 제공하는 용도다.

## 로컬 실행

**[macOS zsh · 앱 루트]** Python 3로 실행한다.

```sh
cd /Users/yudongheon/Documents/vibe-design/apps/strength_routine
python3 -m http.server 4175 --bind 127.0.0.1
```

[http://127.0.0.1:4175/landing/](http://127.0.0.1:4175/landing/)에 접속한다. 종료는 서버를 실행한 터미널에서 `Ctrl+C`를 누른다. JavaScript 모듈을 사용하므로 `index.html`을 파일로 직접 여는 방식은 사용하지 않는다.

`tokens.css`는 `../assets/fonts/`를 참조한다. 서버 기준 디렉터리는 `landing/`이 아니라 **앱 루트**여야 한다. 나중에 정적 호스팅을 준비할 때도 `landing/`과 형제 경로의 `assets/fonts/` 및 OFL 파일을 함께 포함해야 한다. 이 안내는 배포 실행을 뜻하지 않는다.

## 체험과 저장 범위

- 처음에는 실제 중량·반복·RIR이 빈 세트 2개로 시작한다. 시작일과 요일을 고르면 시작일을 포함해 처음 만나는 해당 요일을 표시한다.
- 중량·반복·선택 RIR을 직접 입력하고 완료 또는 제외한다. 수행·제외·작성 중은 따로 집계한다. 완료/제외한 세트는 ‘수정하기’로 다시 편집한다.
- 완료 또는 제외된 세트가 있으면 일정 입력을 잠근다. 이것은 웹 체험의 동작이며 앱의 일정 변경 기능을 구현한 것이 아니다.
- `localStorage`의 **`strength-landing-demo-v1`** 키 하나에 단계·시작일·요일·세트 초안과 상태를 보관한다. 같은 브라우저·같은 출처(프로토콜/호스트/포트)에서 저장 성공분을 복원한다. 저장소 삭제·차단 환경까지 복원을 보장하지 않는다.
- 저장 실패는 화면에서 알리고 현재 화면의 입력을 유지한다. 손상된 기존 값은 확인 후 초기화하기 전까지 덮어쓰지 않는다.
- 초기화 대화상자의 취소/Escape는 유지한다. ‘다시 시작’은 이 체험 키만 먼저 삭제한 뒤 새 빈 상태를 저장한다. 삭제가 실패하면 화면만 초기화하고 다시 열 때 이전 기록이 나타날 수 있음을 알린다. 삭제 성공 뒤 새 상태 쓰기가 실패해도 이전 체험 기록은 남기지 않는다. 앱 기록이나 다른 브라우저 저장 키는 지우지 않는다.

## 파일과 디자인 기준

| 파일 | 역할 |
|---|---|
| [index.html](index.html) | 설명·체험 패널·FAQ·초기화 대화상자 |
| [tokens.css](tokens.css) | Console v2 색·폰트·간격·웹 크기 역할 토큰 |
| [styles.css](styles.css) | 반응형 배치·컴포넌트 상태·키보드 초점·감소된 모션 |
| [main.js](main.js) | 단계 이동·폼 입력·일정 잠금·브라우저 저장·초기화 |
| [demo-state.mjs](demo-state.mjs) | 날짜 계산·입력/저장값 검증·상태 집계 |
| [demo-state.test.mjs](demo-state.test.mjs) | 위 상태 함수의 자동 테스트 |
| [browser-check.cjs](browser-check.cjs) | 별도 Chromium 환경의 조작·저장 오류·반응형 확인과 캡처 |

디자인 의도는 [DESIGN.md의 9/8 기록](../DESIGN.md), 토큰·컴포넌트는 [디자인 시스템](../docs/03-design-system.md)을 따른다. 한글은 IBM Plex Sans KR, 수치·라틴 역할은 IBM Plex Mono를 사용한다. 웹에서 로드하는 파일은 KR 400/600/700, Mono 400/500/700이며 [공식 폰트 출처와 라이선스](../research/2026-09-07/fonts.md)를 유지한다.

## 검증 방법과 현재 기록 범위

**[macOS zsh · 앱 루트, Node.js 필요]**

```sh
node --test landing/demo-state.test.mjs
```

브라우저 자동 확인은 위 정적 서버를 실행한 상태에서 별도 터미널로 실행한다. 로컬에 Playwright와 Chromium 런타임이 필요하며 앱의 의존성에는 추가하지 않는다.

```sh
node landing/browser-check.cjs
```

Playwright가 기본 모듈 경로에 없으면 `STRENGTH_PLAYWRIGHT` 환경 변수에 설치된 Playwright 모듈의 절대 경로를 지정한다. `STRENGTH_LANDING_URL`로 대상 URL을 바꿀 수 있으며 기본값은 위 로컬 `/landing/` 주소다. 스크립트는 별도 브라우저 컨텍스트를 사용하고 `research/2026-09-08/landing/`에 캡처와 `browser-check.json`을 쓴다.

상태 함수 테스트와 브라우저 조작·렌더 확인은 구별한다. 9/8 실행 결과는 상태 모델 **11개 테스트의 기본/DST 환경 통과**, `flutter analyze` 문제 없음이다. 상세 로그와 재개 지점은 [9/8 작업 기록](../docs/2026-09-08-work-log.md)을 따른다.

[브라우저 검사 로그](../research/2026-09-08/landing/browser-check.json)는 headless Chromium **151.0.7922.34**, **35개 검사 통과**를 기록한다. 1440×1000, 390×844, 320px 폭에서 단계 이동·잘못된 입력·완료/제외·새로고침 복원·초기화 취소/실패·FAQ·키보드·감소된 모션을 다룬다. [데스크톱 캡처](../research/2026-09-08/landing/desktop-final.png), [모바일 캡처](../research/2026-09-08/landing/mobile-final.png)와 나머지 증거는 `research/2026-09-08/landing/`에 있다. 이 결과를 Safari·Firefox·실제 모바일 기기·모든 보조 기술의 검증으로 확대하지 않는다.
