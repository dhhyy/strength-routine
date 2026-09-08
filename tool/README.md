# 자체 검증과 QA 진입점

**최신 고급 처방:** [휴식·템포·슈퍼세트·AMRAP 명세·수용 기준·검증](../docs/2026-09-08-advanced-prescriptions.md)을 먼저 읽는다. 관리자 고급 처방을 사용자 화면과 저장·복원에 연결했고 휴식은 별도 파일에 명시 시작한 타이머 한 개를 저장한다. 조건부 스키마 승격과 실제 실행/미실행 범위도 이 문서가 우선한다.

고급 기능의 자체 검증 명령 **[macOS zsh · 앱 폴더]**:

```sh
flutter test test/advanced_prescription_test.dart test/advanced_prescription_store_test.dart test/advanced_catalog_test.dart test/advanced_insights_test.dart test/rest_timer_test.dart --reporter expanded
flutter test test/advanced_admin_screen_test.dart --reporter expanded --dart-define=ADVANCED_ADMIN_RENDER_DIR=research/2026-09-08/advanced-prescriptions/admin-local
flutter test test/advanced_workout_screen_test.dart --reporter expanded --dart-define=ADVANCED_WORKOUT_RENDER_DIR=research/2026-09-08/advanced-prescriptions/workout-local
```

렌더 플래그를 주면 테스트가 실제 번들 폰트를 로드하고 PNG를 남긴다. 테스트 합성 프로그램은 앱 기본 5개 콘텐츠나 실제 기록 파일을 변경하지 않는다. 새 인스턴스의 임시 파일 복원 시험과 실제 기기의 OS 종료/재실행은 구별한다.

**최신 관리자 정밀 편집:** [제어 범위·운영자 확인·검증](../docs/2026-09-08-admin-precise-editor.md)을 먼저 읽는다. 실제 목록에서 기존 프로그램을 열어 한 세트를 바꾸고 새 버전으로 내보내는 경로까지 연결했으며 전체 189개가 통과했다.

**9/8 최신:** [실기기 확인 순서](../docs/2026-09-08-device-test-guide.md)와 [기능 검증](../docs/2026-09-08-feature-verification.md)을 먼저 읽는다. `tool/device_qa.dart`는 오늘 완료→D5→OS 재실행을 위한 별도 합성 저장 파일을 사용하며 최초 한 번만 자료를 만든다. `lib/main_admin.dart`는 운영자의 내부 생성 도구이며 사용자 배포 대상이 아니다.

**수행일·마감 후속:** [현재 구현 명세](../docs/2026-09-08-session-lifecycle.md)와 실기기 가이드의 **F1~F8**을 추가로 따른다. 실제 날짜 선택→초안/실제 저장→`기록 마감`→`기록 다시 열기`→수정·재마감·수행일 달력을 확인하는 절차다. 이번 문서 갱신에서는 코드/테스트를 읽었으며 **시뮬레이터·실기기·OS 강제 종료 시험을 실행하지 않았다**. 최종 테스트 수·커밋·렌더 결과는 최신 명세/검증 문서에서 확인한다.

**현재 지시:** 사용자는 “시뮬레이터는 띄우지 말고, 자체적으로 검증하고 문서로 상세하게 업데이트해줘”라고 요청했다. 아래 자체 검증이 기본 순서다. 사용자 재요청 전까지 시뮬레이터 실행·조작·장애 해결 재시도를 자동 재개하지 않는다.

이전 결과는 [9/7 자체 검증 보고서](../docs/2026-09-07-verification.md)에 있다. 같은 보고서의 V01은 자정 후 습관 탭 복귀, V02는 프로그램 시작일 선택기 경계다. 아래 과거 QA 진입점과 최신 `device_qa.dart`의 파일·실행 목적을 구분한다.

**[macOS zsh · 앱 폴더]**

```sh
cd /Users/yudongheon/Documents/vibe-design/apps/strength_routine
flutter analyze
flutter test --concurrency=2 --reporter expanded
git diff --check
```

기본 순서: 자체 검증 보고서·해당 기능 테스트 확인 → 필요한 실패 재현과 수정 → 관련 테스트 및 전체 회귀 확인 → 실행 로그·확인 범위·미검증 경계를 보고서와 작업 기록에 남긴다. 테스트의 새 저장소/위젯 복원은 OS 강제 종료 후 실제 화면 복원과 구별한다.

## 수행일·마감의 최신 자체 검증과 기기 인수인계

운동 저장소는 envelope **v1~v4를 읽고 고급 처방이 있을 때 v4, 없을 때 v3으로 저장**한다. 수행일·마감 단위 당시에는 v3이었다. 카탈로그·습관·설정·타이머 파일 버전은 별개다. 수행일·최초 입력 시각이 없던 실제값은 미상으로 유지하고, 예전 `completionNotified`를 마감 사건으로 만들지 않는다. 상세한 필드·마감 조건·재시도/경합 계약은 [수명주기 명세](../docs/2026-09-08-session-lifecycle.md)에 있다.

**[macOS zsh · 앱 폴더 · 명령 안내, 이 문서 작업에서 미실행]**

```sh
flutter test test/session_lifecycle_test.dart test/session_lifecycle_controller_test.dart --reporter expanded
flutter test test/workout_session_lifecycle_screen_test.dart test/training_calendar_test.dart test/storage_schema_upgrade_test.dart --reporter expanded
```

| 시험 파일 | 읽고 확인할 계약 |
|---|---|
| `test/session_lifecycle_test.dart` | 실제 날짜/UTC 사건 분리, 수행0·제외·선택 미기록·초안 집계, 명시 사건 순서, 옛 날짜/마감 미상 이행, v3 구조/참조 검증, D5 원문 보존 |
| `test/session_lifecycle_controller_test.dart` | 마감/재개 후보 저장 성공 뒤 확정, 실패 중 원본 유지, 같은 동작 재시도, 일반 저장과 마감 명령 경합 |
| `test/workout_session_lifecycle_screen_test.dart` | 실제 수행일 선택/취소·미상 수정·날짜 초안 복원, 마감/재개 버튼, 실패 확인창, 작은 화면·큰 글자/키보드 |
| `test/training_calendar_test.dart` | `예정일`/`수행일` 구분, 실제 날짜별 동일 세션, 전부 제외한 마감, 보관·미래 읽기 전용 |
| `test/storage_schema_upgrade_test.dart` | 구버전 읽기 뒤 v3 쓰기와 미지원 미래 스키마의 원본 보존 |

위 파일의 존재는 최종 통과 선언이 아니다. 같은 데이터의 단위/화면/통합 시험을 서로 더해 실기기 시험 수로 표시하지 않는다. 마감 상태의 실제값 수정은 먼저 `기록 다시 열기`→확인창 `다시 열기` 저장 성공이 필요하다. `기록 마감`→확인창 `마감하기`와 개별 `세트 완료`는 다른 동작이다.

### 현재 기기 QA 자료의 범위

- `device_qa.dart`의 경로 `device-qa-v1-training.json`은 유지한다. 이름의 v1은 현재 파일 내용이 v1이라는 의미가 아니다. 파일이 이미 있으면 다시 seed하지 않으며 손상 파일도 빈 데이터로 덮지 않는다.
- `device_qa_state.dart`는 첫 생성 날짜를 기준으로 과거 합성 완료·오늘·미래 세션을 만든다. 과거 실제값에는 수행일을 넣지 않으므로 날짜 미상 UI 시험이 가능하다.
- 처음부터 v3으로 만든 QA 파일의 `legacySessionIds`가 비어 있어도 정상이다. 과거 날짜 미상과 과거 마감 여부 미상 이행은 다른 검증이다. v1/v2 기기 이행은 이전 QA 원본을 확보한 별도 회차에서만 한다. 최신 envelope 숫자를 낮추어 구버전 파일이라고 주장하지 않는다.
- 현행 기기 QA는 세션당 필수 2세트다. 선택 미기록/필수 0개/잘못된 날짜/저장 오류는 자동 fixture 또는 별도 검토한 합성 자료가 필요하다. 이 조건용 기기 fixture·파일 주입 UI는 현재 제공하지 않는다.
- 현재 사용자 백업/가져오기 UI는 없다. 기기 QA 원본 복사·읽기 수단이 없으면 파일 항목 확인은 미실행으로 남기고, 자동 임시 파일 왕복만 확인했다고 표시한다. 일반 파일·사용자 기록을 대신 변경하지 않는다.

### 허용된 실제 기기 시험을 수행할 때

현재 지시는 시뮬레이터 실행 금지이며 여기서는 기기 조작을 실행하지 않는다. 나중에 실제 기기 시험을 수행할 때의 정확한 연결/서명 명령과 실패 기록 양식은 [기기 가이드](../docs/2026-09-08-device-test-guide.md)를 사용한다.

1. QA 최초 날짜·데이터 파일 범위를 기록하고 기본 단위 확인→초안 날짜 선택/취소→개별 완료→D5/undo 증거 순서로 진행한다. 마감/제외 시험은 그 뒤에 하여 기존 D5 시험 전제를 보존한다.
2. `날짜 변경`/`날짜 지정`으로 사용자가 확인한 실제일만 저장한다. 옛 중량/메모 수정만으로 미상 날짜나 최초 입력 시각을 오늘로 채우면 실패다.
3. `기록 마감` 확인 취소→확정·잠금→`기록 다시 열기` 취소→확정·편집→수정 초안→재마감의 각 경계에서 원문·날짜·수행/제외/미기록/초안 수를 남긴다.
4. 날짜 초안, 마감, 재개, 수정 초안, 재마감 **각 저장 성공 상태**에서 OS로 종료하고 기기 아이콘으로 재실행한다. 삭제·재설치·데이터 지우기·hot restart는 이 복원 시험을 대신하지 않는다. 미저장 후보 자동 복원/실행까지 지원한다고 해석하지 않는다.
5. `수행일` 달력에서 확인된 완료 날짜만 표시하고 0kg도 수행에 포함되는지 확인한다. 같은 세션의 서로 다른 날짜에서는 같은 세션을 열어야 한다. 제외·초안·미상만으로 수행일이 생기면 실패다. 보기 기준/선택 날짜의 영구 복원은 이번 계약이 아니다.
6. UI는 최신 사건 시각만 보여준다. 전체 `closed → reopened → closed` 이력·이전 요약은 자동 시험 또는 허용된 QA 파일 읽기로 대조한다. 화면에서 확인하지 못한 내부 값을 추정해 통과 처리하지 않는다.

결과에는 출발 단계, 기대/실제, 마지막 저장 성공/실패 문구, OS 종료 방법, 재현 횟수, 전후 캡처, 원본 파일 버전과 확인 가능한 세션 ID를 남긴다. 저장 실패를 재현하려고 일반 파일을 손상시키거나 앱 전체를 지우지 않는다. 아래 9/7 네이티브 이력은 보존된 과거 절차이며 최신 수행일·마감 검증을 대체하지 않는다.

## QA 합성 데이터

`qa_preview.dart`는 화면과 영구 저장을 검증하는 합성 프로그램을 주입한다. 실제 훈련 처방이 아니며 `assets/programs.json`과 일반 실행의 `training-state.json`을 변경하지 않는다. QA 운동 상태는 같은 앱 지원 폴더의 `qa-training-state.json`, QA 습관은 `qa-habits-state.json`에 분리해 보관한다. 일반 실행의 `habits-state.json`은 사용하지 않는다.

## 과거 네이티브 절차 · 현재 실행 보류

아래는 **사용자가 네이티브 검증을 다시 요청했을 때만** 재개할 절차다. 이전 `NSMachErrorDomain -308` 및 전용 기기 인식 실패 이력 뒤 마지막 재시도에서 Xcode 빌드(124.0초)는 성공했지만 앱 화면은 확인하지 못했다. 빌드 성공을 실제 네이티브 기능 검증 성공으로 보지 않는다.

**[macOS zsh · 앱 폴더]**

```sh
flutter devices
flutter run -d 003D93A6-D728-4968-92EE-7996BD1E568E -t tool/qa_preview.dart
```

위 ID는 9/7 생성한 전용 **Strength QA / iPhone 17 Pro / iOS 26.5**다. 장치가 바뀌면 실제 `flutter devices` 결과를 사용한다. 여러 작업이 Simulator를 공유할 경우 해당 기기 창인지 확인하고, 다른 기기를 종료하거나 초기화하지 않는다.

화면 검증 순서:

1. 소개 → 건너뛰기 → 프로그램 선택 → `동작 검증 프로그램` 상세.
2. 오늘 날짜·오늘 요일·장비 최소 증량 단위 입력. 스쿼트의 검증용 최근 기록 입력.
3. `루틴 시작하기` → 날짜/운동/세트 확인 → `이 일정으로 시작`.
4. 오늘 운동의 1세트에 검증용 실제 중량·반복·RIR 입력. 닫기 후 다시 열어 초안 확인.
5. 1세트의 `저장하고 다음 세트` → 2세트 제외 → 실제 수행 1세트/제외 1세트 집계 → 달력에서 기록 재확인.
6. 검색에서 검증용 운동의 프로그램/주차/세션 상세를 확인한다. 습관 탭에서 `검증용 습관`을 추가·체크한다.
7. Flutter 실행 터미널에서 `q`로 앱 프로세스 종료 후 위 명령으로 재실행. 같은 날짜·계획·실제 값·완료/제외 상태와 습관 체크가 남는지 확인.
8. 일반 실행은 아래 명령으로 되돌린다. 실제 카탈로그가 비어 있으면 빈 상태가 정상이다.

```sh
flutter run -d 003D93A6-D728-4968-92EE-7996BD1E568E
```

파일 저장·실패 복구·복원 및 375×812/키보드 제약의 최신 결과는 [자체 검증 보고서](../docs/2026-09-07-verification.md)에 남긴다. 네이티브 렌더와 실제 기기 조작을 테스트 통과만으로 완료 처리하지 않는다. 과거 캡처·실행 이력은 [작업 기록](../docs/2026-09-07-work-log.md)을 따른다.

## 최신 관리자 정밀 편집 확인 · 9/8

[정밀 편집 명세·검증](../docs/2026-09-08-admin-precise-editor.md)의 §10 운영자 조작과 §13 자동 검사 결과를 먼저 읽는다. 내부 진입점은 계속 `lib/main_admin.dart`이며 사용자 재요청 전 Simulator를 실행하지 않는다. 관리자 작업 파일 v2, 소비자 카탈로그 v1, 사용자 운동 파일 v3을 구별한다.

**[macOS Terminal] 앱 루트에서:**

```sh
flutter test test/detailed_routine_test.dart test/detailed_admin_workspace_test.dart test/detailed_admin_screen_test.dart test/detailed_admin_integration_test.dart --concurrency=1 --reporter expanded
flutter test test/detailed_admin_screen_test.dart --reporter expanded --dart-define=DETAILED_ADMIN_RENDER_DIR=/tmp/strength-admin-precise
```

원형 보존·주차 독립성·중량 기준·순서/복사·v1/v2 이행·실제 카탈로그 편집→새 버전 저장→내보내기·저장 충돌을 각각 확인한다. 두 번째 명령은 번들 폰트의 headless 위젯 렌더이며 실제 내부 앱/OS 프로세스 복원을 의미하지 않는다.
