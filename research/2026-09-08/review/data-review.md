# 9/8 · 주요 문서별 데이터·저장 계약 독립 검토

검토 기준: `5eaaed8`, 2026-09-08, macOS 호스트. 대상은 로컬 완성 명세의 LC01/공통 저장, 수행일·마감 명세와 검증 보고서, 일정 변경·이전 기록 복사 명세다. 기존 코드·문서 수정과 커밋은 하지 않았다. Simulator·실제 기기를 실행하지 않았다.

## 판정

**이 범위의 정상 UI 흐름에서 확정할 데이터 손실·저장 경합 결함을 발견하지 못했다.** 이는 결함이 없다는 보증이나 실기기 복구 시험을 통과했다는 뜻이 아니다. 요구 문구와 실제 코드, 실패를 주입한 기존 시험을 대조한 결과다. 같은 전체 회귀를 중복 실행하지 않기 위해 이번 담당 검토에서는 별도 Flutter 실행을 하지 않았으며, 최신 실행 결과는 통합 검토 보고서를 따른다.

## 1. `docs/2026-09-08-local-completion.md` — 백업과 공통 저장

판정: **명세와 구현이 맞으며 저장 전후 경계가 구체적이다.**

| 문서 계약 | 실제 근거 | 평가 |
|---|---|---|
| 운동 기록 전체만 백업, 설정·습관·관리자·타이머 제외 | `TrainingBackup`이 `TrainingAppState` envelope를 포함하고 `BackupScreen`이 포함/제외를 표시 | 앱 전체 백업으로 오인하지 않게 범위를 밝힘 |
| 검토 후 상태 변경 감지 | `TrainingController.commitReviewedState` 164행에서 `expectedRevision` 검사 | 오래된 후보로 새 입력을 덮지 않음 |
| 저장 중/실패 중 교체·내보내기 차단 | `training_backup.dart` 101–118행, 컨트롤러 169–177행 | 메모리 최신값과 마지막 성공 저장의 차이를 숨기지 않음 |
| 복구본 확보 후 주 파일 교체 | `training_backup.dart` 131–156행의 복구본 쓰기/재파싱/rename, 이후 controller의 store.save | 복구본 확보 실패 시 주 파일에 진입하지 않음 |
| 손상 현재 파일의 원본 바이트 보존 | `training_backup.dart` 132–141행, `.unreadable-before-restore.json` | 손상 파일을 빈 정상 백업처럼 꾸미지 않음 |
| 저장 성공 후 메모리 교체 | controller 182–186행 | 실패 시 기존 상태 유지와 재시도 후보가 분리됨 |
| 저장 순서·원자 파일 교체 | `LocalTrainingStore._enqueue`, 동일 디렉터리 임시 파일+flush+rename | 공유 저장소 인스턴스 안의 직렬화 보장 |
| 복원 전 타이머 무효화 | 복원마다 새 generation, state schema6, `restSourceStamp`에 generation 포함 | 같은 계획·실제값을 복원해도 구 타이머와 출처가 달라짐 |
| 파일 크기·중첩·버전·무결성 검사 | `TrainingBackup.parse`, `NativeBackupFileGateway.pick` | 스트림 읽기에서도 10MiB 제한을 다시 적용함 |

대조한 시험: `test/training_backup_test.dart`, `test/backup_screen_test.dart`, `test/local_training_store_test.dart`. 정상 왕복뿐 아니라 손상·미지원 버전·고아 참조·깊이·복구본 쓰기 실패·주 파일 쓰기 실패·저장 중 복원·stale revision·중복 commit·손상 원본 보존·재시작 후 타이머 무효화를 실제 assertions로 확인한다.

검증 한계: native 파일 선택/저장 공급자는 위젯 시험에서 가짜 gateway다. OS 저장 대화상자·클라우드 공급자의 실제 바이트 보관, 프로세스 강제 종료와 전원 차단은 별도 실기기 확인 대상이다. 다중 파일 동시 트랜잭션·다중 프로세스 동기화를 주장하지 않는 문서 설명이 정확하다. 복구본은 최근 한 개이며 암호화/인증 파일이 아니다.

## 2. `docs/2026-09-08-session-lifecycle.md` — 실제 수행일·마감

판정: **상태 전환과 과거 기록 보존 규칙을 UI 외부까지 구현했다.**

- `SetActual`은 달력 날짜를 UTC 자정 표현에 보관하고 실제 순간의 UTC 기록/수정 시각과 분리한다.
- 과거 nullable 수행일·최초 기록 시각은 null 키를 새로 쓰지 않아 기존 D5 근거 JSON을 유지한다.
- `SessionSummary`는 완료·제외·미기록·초안과 필수 미기록을 독립 집계한다.
- `TrainingAppState._validateSessionEvents`는 고아 사건, 중복 ID, 사건 순서, 요약 불일치, 마감 후 몰래 변경을 거부한다.
- 마감/재개는 `_commitSessionAction`이 파일 저장 후에만 공개하고, UI 확인창은 재시도에 같은 event ID와 시각을 사용한다.
- 닫힌 세션의 실제값·초안·메모 변경을 도메인에서도 막는다.
- 프로그램 교체 시 활성 계획을 보관으로 넘기고 사건·초안·실제값을 보존한다.
- 새 입력과 오래된 날짜 미상 입력을 편집기에서 구별하며, 값 변경 없이 닫은 기존 초안에 날짜 키를 자동으로 붙이지 않는다.

대조한 시험: `test/session_lifecycle_test.dart`, `test/session_lifecycle_controller_test.dart`, `test/workout_session_lifecycle_screen_test.dart`, `test/training_calendar_test.dart`. 필수0개/선택 미기록/전체 제외, 실패 재시도, 명령 중복, 날짜 미상, 재개 후 수정·재마감, v1/v2 이행, D5 근거 보존을 시험한다.

검증 한계: 일반 자동 저장은 메모리부터 갱신하므로 마지막 성공 저장 이후 프로세스가 끝나면 미저장 입력은 복원되지 않을 수 있다. 문서가 이 점을 마감의 저장 후 확정과 구분한다. UI의 미래/보관 세션 읽기 전용과 실제 OS 종료 경계는 순수 도메인 시험만으로 전체 기기 동작을 입증할 수 없다.

## 3. `docs/2026-09-08-session-lifecycle-verification.md` — 검증 보고서

판정: **당시 구현의 근거는 상세하지만 현재 상태 진입점으로 읽을 때 역사 표식을 보강하면 좋다.**

시험 개수를 하위 묶음과 중복 합산하지 않고, 저장 실패 주입으로 검증한 메모리 보존과 디스크 원본 바이트 보존 시험을 구분한다. 실제 폰트 headless 렌더와 OS 키보드·기기 시험도 구분되어 있다.

문서 개선 제안(코드 결함 아님): 144행은 백업·일정·이전 복사·타이머·관리자 세부 편집·가이드를 아직 `미구현`이라고 쓰고 148행은 백업 구현을 다음 순서로 안내한다. 이는 당시 단계의 기록으로는 맞지만 이후 구현과 같은 9/8 날짜라 단독 독자가 최신 상태로 오해할 수 있다. 내용을 삭제하기보다 절 제목에 ‘당시 상태’와 기준 커밋을 표시하고 `2026-09-08-local-completion.md`/최신 상태표 링크를 가까이 둔다.

## 4. `docs/2026-09-08-schedule-previous.md` — 일정·이전 기록

판정: **문서의 보수적인 변경 범위와 입력 보존 계약을 충족한다.**

| 기능 | 확인한 구현 | 검증 근거 |
|---|---|---|
| 기록이 있는 일정 보호 | `scheduleProtectionReason`이 실제값/제외/초안/메모/마감/legacy/완료 표식을 검사 | 보호 유형별 domain 시험 |
| 오늘·과거/요일/시작일/순서 검증 | `withReviewedSchedule`과 `ActiveTrainingPlan.rescheduleFuture` 양쪽 검사 | 무효 날짜와 유효 날짜 시험 |
| 자정 경계와 stale revision | `_apply`가 적용 직전 현재 날짜로 재검증, controller revision 확인 | 화면 자정·검토 후 변경 시험 |
| 날짜만 교체 | `TrainingAppState` 전체 codec 중 activePlan의 날짜만 바꾸고 목표·이력 보존 | D5 적용값·수행일 미상 포함 파일 왕복 |
| 이전 기록의 동일성 | 프로그램 ID/버전/전체 내용 + 종목 ID/이름/mainLift + 세트 ID/순번/종류 | 다른 버전·동일 이름·모호한 ID·종류 혼합 제외 |
| 실제 수행일 기준 후보 | 확인된 앞선 날짜, 완료만, 초안/미상/같은 날/미래 제외 | 예정일과 실제 수행일 순서가 다른 시험 |
| 원단위·숫자 및 현재 부가값 보존 | `copyInto`는 weight/unit/repetitions만 교체 | kg/lb·RIR/메모/날짜 원문 보존 시험 |
| 선택 도중 변경 차단 | `_copyPrevious`의 revision 및 원본 fingerprint 재검사 | 출처 변경 후 적용 거부 위젯 시험 |

대조한 시험: `test/schedule_edit_test.dart`, `test/previous_record_test.dart`, `test/schedule_previous_screen_test.dart`와 fixture. 문서의 8+9+9=26개는 이 세 파일의 역할과 맞는다. 프로그램 버전 사이 종목을 연결하지 않는 점, 같은 날 기록을 앞선 기록으로 쓰지 않는 점, 요일 변경이 없는 점은 명시한 제품 범위이므로 결함으로 세지 않았다.

검증 한계: 실제 OS 날짜 선택기 접근성/키보드/앱 재개는 기기 확인이 필요하다. 이 리뷰에서는 기존 PNG를 새로운 실제 기기 렌더 증거로 재사용하지 않았다.

## 이번 리뷰의 변경

이 노트만 추가했다. 확정 결함 재현용 probe를 만들지 않았고 일반 `test/`에 실패 시험을 남기지 않았다. 코드 수정·기능 범위 확대·배포·커밋은 하지 않았다.
