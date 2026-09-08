# Strength · 인터랙티브 랜딩 5개 시안

**[5개 시안 비교하기](http://127.0.0.1:4175/landing/concepts/)** · [설계·검증·인수인계](../../docs/2026-09-08-interactive-landing-concepts.md)

Three.js로 만든 실제 브라우저 체험이다. 조작 대상과 화면 구성을 다르게 설계했으며 기존 Flutter 앱과 독립적으로 실행한다.

| 시안 | 직접 해볼 동작 |
|---|---|
| [01 중량을 직접 조절하는 무대](01-load.html) | 슬라이더·±로 중량을 바꾸고 바벨 원판 확인; 드래그·회전 버튼·초기 시점 |
| [02 프로그램을 고르는 공간](02-atlas.html) | 목록 또는 3D 패널 선택; 실제 프로그램의 기간·빈도·첫 운동 비교 |
| [03 요일로 만드는 훈련 일정](03-schedule.html) | 요일 또는 3D 블록 선택; 시작일 입력 후 전체 세션의 예정일 확인 |
| [04 한 세트씩 완성하는 기록](04-session.html) | 두 세트의 중량·반복·선택 RIR 입력, 완료·수정·새로고침 복원 |
| [05 변경 전후가 보이는 조절](05-insights.html) | 합성 예시의 변경 내용 검토·적용·되돌리기 |

## 실행

**[macOS zsh · 앱 루트]**

```sh
cd /Users/yudongheon/Documents/vibe-design/apps/strength_routine
python3 -m http.server 4175 --bind 127.0.0.1
```

이미 이 포트에 앱 루트 서버가 실행 중이면 그대로 접속한다. `file://`로 열면 모듈·카탈로그 읽기가 작동하지 않는다. 공유 호스팅이나 외부 배포는 수행하지 않았다.

## 파일과 데이터

| 파일 | 역할 |
|---|---|
| `index.html`, `01-load.html` ~ `05-insights.html` | 비교 목차와 독립 진입점 |
| `app.mjs` | 실제 HTML 조작·프로그램 읽기·요일 계산·세트 저장·감량 체험 |
| `scenes.mjs` | 바벨·전시 선반·주간 격자·기록 패널·그래프의 직접 작성 지오메트리 |
| `tokens.css`, `styles.css` | Console v2 역할 토큰, 공통 구성 요소와 시안별 반응형 배치 |
| `previews/` | 실제 최종 데스크톱 렌더를 사용한 비교 목차 이미지 |
| `vendor/` | 공식 npm Three.js **0.185.1**의 core/module, MIT 라이선스·출처·해시 |
| `browser-check.cjs` | 입력·실패·복원·접근 조작·좁은 화면 자동 검사 |
| `scene-picking-check.cjs` | 실제 3D 패널·달력 블록 포인터 선택 검사 |
| `capture.cjs` | 1440/390/320px 렌더, 조작 전후와 목차 이미지 생성 |

02·03은 앱의 [programs.json](../../assets/programs.json)을 읽는다. 프로그램 설명·주차·주간 횟수·첫 세션은 이 자료가 정본이다. 세션을 시작일 이후 선택 요일에 순서대로 배정하지만 앱 계획을 생성하거나 저장하지 않는다. 3D 달력은 선택한 요일의 4주 패턴이며, 실제 예정일은 아래 미리보기에서 확인한다.

04는 [기존 웹 상태 모델](../demo-state.mjs)의 검증·JSON 함수를 재사용한다. `strength-concept-session-v1` 키 하나에 체험의 입력 원문과 완료 상태를 저장한다. 기존 랜딩의 `strength-landing-demo-v1`과 앱 파일은 수정하지 않는다. 저장 차단 시 현재 화면에서 이어가고, 손상된 원본은 확인 후 초기화하기 전까지 보존한다. 초기화 삭제가 실패하면 현재 입력을 유지한다.

05의 60→57.5kg는 [앱 QA 합성 데이터](../../tool/device_qa_state.dart)를 참고한 화면 체험이다. 과거·오늘은 보존하고 미래 2회×2세트만 바꾸며 되돌릴 수 있다. 실제 기록 분석 엔진·개인별 처방·유료 기능·앱 저장 연결은 없다.

## 3D와 대체 조작

외부 CDN·모델·이미지 로딩 없이 로컬 고정 버전으로 실행한다. 배포를 별도로 준비한다면 상위 `assets/programs.json`, `assets/fonts/`와 폰트 OFL·Three MIT 라이선스도 유지해야 한다.

WebGL2를 사용할 수 없거나 모듈 로딩이 실패하면 이유를 표시하고 HTML 버튼·입력·수치로 체험을 이어간다. 모든 장면은 드래그 외에 회전·초기 시점 버튼이 있고, 선택 가능한 오브젝트는 같은 기능의 이름 있는 HTML 버튼이 있다. `prefers-reduced-motion`에서는 보간 애니메이션 없이 결과를 즉시 반영한다. DPR은 최대 1.5이고, 입력에 반응하는 동안만 필요한 프레임을 그리며 보이지 않는 장면·탭에서는 정지한다.

## 검증 재실행

**[macOS zsh · 앱 루트, Node.js·Playwright·Chromium 필요]** 정적 서버를 켠 상태에서 실행한다.

```sh
node --test landing/demo-state.test.mjs
node landing/concepts/browser-check.cjs
node landing/concepts/scene-picking-check.cjs
node landing/concepts/capture.cjs
```

기본 모듈 경로에 Playwright가 없으면 `PLAYWRIGHT_MODULE`에 설치된 모듈 디렉터리의 절대 경로를 지정한다. `STRENGTH_CHECK_BASE_URL`로 위 로컬 주소를 바꿀 수 있다. 브라우저 검사의 JSON 경로는 `STRENGTH_CHECK_OUTPUT`으로 바꿀 수 있으며 기본 결과·캡처 위치는 [research/2026-09-08/concepts](../../research/2026-09-08/concepts/)다. 캡처는 목차용 `previews/`도 갱신한다.

렌더 결과는 직접 열어 제목 줄바꿈, 장면 잘림, 버튼 접근, 변경 전후를 확인해야 한다. DOM 상태 검사 통과만으로 3D 픽셀이 정상이라고 판단하지 않는다. 최종 결과와 미검증 범위는 [9/8 시안 문서](../../docs/2026-09-08-interactive-landing-concepts.md)를 따른다.
