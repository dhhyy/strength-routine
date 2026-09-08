# 9/8 · 미래 일정 편집과 이전 기록 복사

작성: 2026-09-08. 상위 명세: [독립 구현 전체](2026-09-08-local-completion.md). 이 문서는 LC02/03 구현 전에 계약을 기록하며, 완료 증거는 마지막 절에 추가한다.

## 1. 일정 편집 계약

오늘 루틴의 ‘남은 일정 편집’에서 활성 계획의 미래 세션별 날짜를 선택한다. 훈련 요일은 프로그램 시작 시 선택한 요일 그대로다. 요일 변경/세션 삽입/운동 재생성은 이 편집의 기능이 아니다. 날짜 선택은 내일부터 가능하지만 선택한 요일, 시작일, 프로그램 세션 순서를 모두 만족해야 검토할 수 있다. 날짜 입력을 바꾸면 이전 검토를 폐기한다.

오늘과 과거 날짜는 고정한다. 미래 세션도 실제 완료/제외/초안/메모/마감·재개 이력/이전 마감 미상 표식/완료 알림 표식이 있으면 보호한다. 목표 중량, 프로그램 스냅샷, 계획 ID, 최근 리프트, 보관 계획, 수행일 미상, D5 이력은 변경하지 않는다. 전체 TrainingAppState JSON에서 활성 계획의 날짜 스냅샷만 교체하므로 다른 신규 메타데이터도 보존한다.

변경 전후 목록에서 명시적으로 적용한다. 검토한 revision과 현재 revision이 다르거나 활성 계획이 바뀌면 다시 불러오도록 안내한다. 저장 중/저장 실패 중에는 적용하지 않는다. 저장 실패 시 실제 일정은 이전 상태이고 입력 후보는 그대로 남는다. 성공한 저장 이후에만 일정 화면에 반영한다. 적용 직전 오늘 날짜를 다시 확인하여 자정 경계를 넘으면 과거가 된 일정을 이동하지 않는다.

놓친 운동은 ‘놓친 운동 모두 보기’에서 모든 미마감 세션에 접근한다. 날짜는 원래 예정일을 그대로 표시하고, 실제 수행일은 세트 입력 화면의 기존 별도 필드로 작성한다. 미래 날짜를 오늘로 자동 이동하지 않는다.

## 2. 이전 실제 기록의 동일성

세트 입력 안의 ‘이전 기록 가져오기’는 활성/보관 계획 중 같은 프로그램 ID·버전·동일 프로그램 내용에 속한 기록만 조사한다. 명시적인 운동 ID·이름·메인 리프트, 세트 ID·순번·세트 종류를 확인한다. 같은 운동 ID가 다른 이름/메인 리프트로 재사용되면 모호한 종목으로 보고 후보를 만들지 않는다. 이름만 같은 다른 프로그램, 다른 버전은 자동 연결하지 않는다.

확인된 수행일이 현재 입력한 수행일보다 앞선 완료 기록만 후보로 제공한다. 현재 수행일 미상, 날짜 미상 기록, 미래 수행일, 제외, 작성 중 초안, 현재 세트는 제외한다. 같은 날 안의 선후는 추측하지 않는다. 가장 최근 날짜 순으로 최대 10개 출처를 보여주며 프로그램/세션/세트/수행일/원래 중량 단위를 확인하고 선택한다. 출처가 검토 후 달라지면 다시 선택한다.

복사하는 필드는 중량·원래 단위·반복이다. RIR·메모·현재 수행일은 입력 원문 그대로 유지하며 완료를 자동 체크하지 않는다. 기존 중량 또는 반복이 비어 있지 않으면 덮어쓰기 확인을 한 번 더 받는다. 취소는 현재 초안과 원본을 변경하지 않는다. 복사 후 자동 저장 실패는 입력을 보존하고 기존 저장 재시도를 제공한다. 원본 실제 기록과 목표 처방은 바뀌지 않는다.

## 3. 디자인과 상태

기존 Console v2와 관찰된 기록 행 참조를 재사용한다. Fixed 앱바·Fluid 날짜 선택 목록·Hybrid 전후 검토로 구성한다. FlowPage/GlassPanel/StatePanel/PrimaryAction/앱 토큰을 조립한다. 날짜·중량·단위는 mono, 설명/운동 이름은 KR을 사용한다. 빈 활성 계획, 이동 가능한 미래 없음, 후보 없음, 변경 없음, 유효성 오류, 저장 중, 저장 실패, 외부 변경, 취소를 각각 분리한다.

검토 카드와 복사 출처 다이얼로그는 좁은 화면·큰 글자에서 세로로 흐르게 하며 중요한 날짜와 버튼을 한 줄로 강제하지 않는다. 실제 폰트 headless 렌더에서 확인하고 관찰→수정→재캡처한다. Simulator는 실행하지 않는다.

## 4. 검증 계획

- 일정: 유효 이동/실제 임시 파일 재로딩, 오늘·과거/기록·초안·메모·마감·legacy 보호, 요일/순서/알 수 없는 ID 오류, D5·수행일 미상 포함 메타데이터 보존, 저장 실패/동시 변경/자정 경계, 검토/취소/적용/놓친 운동 진입.
- 이전 복사: kg/lb 보존, 확인 수행일 순서, 날짜 미상/동일 이름 다른 ID/다른 버전/모호한 종목/세트 종류/초안 제외, RIR·메모·날짜 원문 보존, 덮어쓰기 취소, 저장 실패·재시도·실제 재로딩, 작은 화면/큰 글자.

## 5. 구현·검증 결과

구현 전 명세 완료. 실제 결과와 커밋은 후속 기록한다.

### 5.1 LC02 완료

- `lib/domain/schedule_edit.dart`: `scheduleProtectionReason`과 `withReviewedSchedule`가 날짜 조건과 사용자 기록 보호를 검증한다.
- `lib/schedule_screen.dart`: 미래 날짜 선택, 유지 일정 펼침, 변경 전후 검토, 명시 적용, 저장 실패 재시도, 최신 일정 재로딩을 연결했다.
- `lib/training_screens.dart`: 오늘 루틴에 일정 편집과 놓친 운동 전체 목록을 연결했다. 프로필의 백업 진입도 LC01 화면에 연결했다.
- `TrainingController.commitReviewedState`의 revision 잠금과 저장 성공 후 반영을 사용하며, 화면 적용 직전 오늘 날짜를 다시 확인한다.
- `test/schedule_edit_test.dart` 8개가 실제 파일 재로딩·저장 실패·D5 이력·수행일 미상·과거/기록 보호를 검증했다.
- 일정 화면 5개와 이전 복사 화면 4개를 묶은 통합 화면 시험은 `test/schedule_previous_screen_test.dart`에 남긴다.

일정 기능 확인 순서: 오늘 루틴 → 남은 일정 편집 → 미래 세션 날짜 선택 → 선택했던 훈련 요일의 뒤 날짜 선택 → 변경 내용 확인 → 변경 전후 비교 → 일정 적용. 뒤로 가면 변경하지 않는다. 기록이 있는 미래 세션은 ‘유지되는 일정’의 보호 이유로 확인한다. 놓친 운동 모두 보기에서 과거 세션을 열면 ‘계획한 날짜’는 원래 날짜로 남고 실제 수행일은 별도 입력한다.

### 5.2 LC03 완료와 검증 증거

`lib/domain/previous_record.dart`가 프로그램 스냅샷·종목·세트 위치/종류를 비교하고, 수행일이 앞선 완료 기록을 최신순으로 제공한다. `lib/previous_record_dialog.dart`는 출처 선택/덮어쓰기 확인을 담당하며 `SetEditor._copyPrevious`는 확인 중 revision 또는 원본 값이 바뀌면 적용을 거부한다. 복사는 기존 초안 저장 경로를 쓰며 완료 기록을 만들지 않는다. 프로그램/운동 저장 스키마는 LC02/03 때문에 새로 상향하지 않는다.

확인 순서: 지난 운동을 중량·단위·반복·실제 수행일과 함께 완료 → 동일 프로그램의 뒤 운동 세트 열기 → 이전 기록 가져오기 → 프로그램/세션/종목/세트/실제 수행일/원래 단위 확인 → 이 기록 선택 → 기존 값이 있으면 입력 바꾸기 → RIR/메모/현재 수행일 유지 확인 → 완료 버튼을 누르지 않고 닫기 → 다시 열어 복사한 초안 확인. 취소 버튼은 입력을 바꾸지 않는다.

최종 담당 검증은 **26개 통과**: 일정 도메인·파일 8개, 이전 기록 도메인 9개, 통합 화면 9개(일정/놓친 운동 5개, 이전 복사 4개). 정적 분석은 **No issues found**다. 세트 종류가 워밍업/작업으로 다르면 ID·위치가 같아도 복사하지 않는 시험, 검토 중 출처 변경 거부, 자정 경계 보호가 포함된다.

[테스트 실행 결과](../research/2026-09-08/local-completion/schedule-previous/tests.txt), [정적 분석](../research/2026-09-08/local-completion/schedule-previous/analyze.txt).

[macOS zsh · 프로젝트 디렉토리]

```sh
flutter test test/schedule_edit_test.dart test/previous_record_test.dart test/schedule_previous_screen_test.dart --reporter expanded
flutter test test/schedule_previous_screen_test.dart --dart-define=SCHEDULE_PREVIOUS_RENDER_DIR=research/2026-09-08/local-completion/schedule-previous/final
flutter analyze lib/domain/schedule_edit.dart lib/domain/previous_record.dart lib/schedule_screen.dart lib/previous_record_dialog.dart lib/training_screens.dart lib/workout_screen.dart test/schedule_edit_test.dart test/previous_record_test.dart test/schedule_previous_screen_test.dart
```

### 5.3 렌더 관찰과 수정

375×900, 글자 1배/1.5배, 실제 IBM Plex Sans KR·IBM Plex Mono와 아이콘 폰트를 로드한 headless 렌더다. 첫 화면에서 이전 기록의 세션·운동·세트가 긴 한 줄로 합쳐져 큰 글자에서 종목명이 어색하게 끊겼다. 프로그램/세션/운동/세트의 계층을 나누고 선택 버튼 최소 높이를 터치 토큰으로 맞췄다. 일정 저장 오류에는 경고 아이콘과 ‘일정 저장 다시 시도’라는 동작 라벨을 추가했다.

- [첫 이전 기록 출처·큰 글자](../research/2026-09-08/local-completion/schedule-previous/first/previous-source-large.png) → [최종 출처·큰 글자](../research/2026-09-08/local-completion/schedule-previous/final/previous-source-large.png).
- [최종 일정 검토](../research/2026-09-08/local-completion/schedule-previous/final/schedule-review.png), [저장 실패와 재시도](../research/2026-09-08/local-completion/schedule-previous/final/schedule-save-failure.png), [일정 큰 글자](../research/2026-09-08/local-completion/schedule-previous/final/schedule-large.png).
- [복사한 입력](../research/2026-09-08/local-completion/schedule-previous/final/previous-copied.png), [후보 없음·큰 글자](../research/2026-09-08/local-completion/schedule-previous/final/previous-empty-large.png).

최종 이미지를 직접 확인했고, 가로 넘침·잘린 확인 버튼 없이 세로 스크롤로 읽을 수 있다. 테스트에서 처음 사용한 화면 호스트에 Material 조상이 없고 재펌프 시 이전 Navigator가 유지되던 시험 하네스 오류도 수정했다. 실제 앱 화면 오류로 분류하지 않는다. 위 결과는 전체 앱 회귀 시험/실제 OS 키보드·접근성·기기 재시작 검증을 대신하지 않는다. Simulator는 실행하지 않았다.

### 5.4 한 문장 변경 기록

1. 오늘 루틴에서 남은 미래 운동 날짜를 편집할 수 있다.
2. 기록이 있는 세션은 보호 이유와 함께 원래 날짜를 유지한다.
3. 변경 전후 날짜를 확인한 뒤 저장 성공한 일정만 반영한다.
4. 놓친 운동 전체를 원래 예정일로 열 수 있다.
5. 이전 기록의 출처와 원래 단위를 확인하고 입력으로 가져올 수 있다.
6. 이미 적은 중량·반복을 덮어쓸 때 확인을 받는다.
7. 복사해도 RIR·메모·실제 수행일과 원본 완료 기록은 유지한다.
8. 저장 실패·외부 변경·자정 경계를 검사하고 재시도 흐름을 제공한다.

선행 명세 커밋 `925359c`, 일정 기능 커밋 `07c9d9b`; 이전 복사 기능 커밋은 Git 로그의 `feat(training): copy confirmed previous actuals into set drafts`에서 확인한다.
