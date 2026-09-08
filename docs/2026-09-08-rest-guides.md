# 9/8 · 휴식 설정과 오프라인 운동 가이드

후속: LC05의 최초 완료 저장 실패·재시도·취소 경계는 [자동 휴식 재시도 안정화](2026-09-08-rest-retry-fix.md)에서 보강했다. 아래 LC05·LC06 명세와 당시 검증은 구현 이력으로 유지한다.

작성: 2026-09-08. 상위 명세: [독립 구현 기능 전체](2026-09-08-local-completion.md). 이 문서는 LC05·LC06의 구현 전에 작성한다. 완료·검증 증거는 실행 후 추가한다.

## 1. 휴식 설정 구현 계약

- 기본값: 사용자 기본 휴식 미지정, 새 완료 뒤 자동 시작 꺼짐.
- 설정 화면에서 정수 1~3600초를 입력하고 저장하거나 기본 시간을 해제한다. 빈 값은 미지정이다. 음수·0·소수·범위 밖은 입력 오류이며 저장하지 않는다.
- 휴식 시간은 세트 처방 → 사용자 기본값 순이다. 세트의 명시 0초는 휴식 없음으로 유지하며 기본값으로 바꾸지 않는다.
- 설정은 저장 성공 후 적용한다. 설정 저장 실패는 화면의 후보를 유지하고 재시도한다. 진행 중인 타이머는 설정 변경으로 갱신하지 않는다.
- 설정 파일은 기존 버전1을 읽고 새 버전2로 저장한다. 버전1에 새 의미 필드가 들어 있으면 오독하지 않고 거부한다.
- 타이머 출처는 처방 또는 사용자 기본값이다. 사용자 기본값의 시작 당시 초를 보관하며 현재 설정 변경으로 기존 타이머를 무효화하지 않는다.
- 타이머 출처 필드가 없는 버전1은 처방으로 읽는다. 사용자 기본값을 사용한 타이머는 버전2로 저장한다. 세트에 처방이 있으면 사용자 기본값 출처로 시작할 수 없다.
- 자동 시작은 실제 기록이 없던 세트의 완료 저장 성공 후 한 번만 시도한다. 기존 완료 수정·불러오기·초안·제외·페이지 재진입은 시작하지 않는다. 실패한 운동 저장의 재시도는 최초 완료를 확정하는 시점에만 한 번 시도한다.
- 기존 진행/일시정지 타이머는 확인 없이 교체하지 않는다. 사용자가 취소하면 운동 완료는 유지한다. 타이머 저장 실패는 완료 기록을 취소하지 않는다.
- 기존 실제값·초안·마감/재개·백업 복원 저장 세대 경계를 모두 유지한다. 앱 외부 알림·음성·진동·워치·백그라운드 서비스는 이번 범위가 아니다.

## 2. 운동 가이드 구현 계약

- 기본 다섯 프로그램의 서로 다른 24개 종목을 대상으로 로컬 안내를 작성한다.
- 종목마다 시작 자세·동작·확인할 점·장비·공식 출처를 제공한다. 영상이나 사진을 검토하지 않은 상태에서 미디어를 붙이지 않는다.
- 명시적인 정확한 이름/별칭만 연결한다. 장비가 다른 종목이나 미등록 이름은 가이드를 추정하지 않는다. 운동 기록의 종목 동일성 판정과 가이드 이름 매핑은 별개이다.
- 검색 탭의 가이드 목록 진입과 운동 구성 상세의 가이드 링크를 제공한다. 가이드 검색은 목록 필터이며 기록/처방을 변경하지 않는다.
- 본문은 오프라인에 포함한다. 출처 링크는 기기 외부 브라우저로 열고 실패하면 본문 유지·오류·재시도를 제공한다.
- 용어는 세트·반복·RIR·AMRAP·템포·슈퍼세트·워밍업·드롭세트·반복 범위와 앱의 실제 해석을 설명한다. 고유명사/숫자는 mono, 한글은 KR 토큰으로 표시한다.
- 안내는 일반적인 동작 이해용이며 맞춤 처방·의료 진단·통증 치료나 운영자 검수 완료를 주장하지 않는다.

## 3. 디자인과 검증 계획

기존 Console v2와 Hevy 기록 행 참조를 유지한다. FlowPage의 고정 앱바와 유동 목록, GlassPanel·ConsoleField·StatePanel·PrimaryAction을 조립한다. 새 설정은 기존 중량/조정 설정 다음에 배치한다. 가이드 읽기는 제목 → 시작 → 움직임 → 확인 → 출처 순서로 조립한다.

검증은 기본값/버전 이행/유효성/0초 우선/출처 보존/저장 실패/타이머 교체/기존 완료 제외/카탈로그 24개 커버리지/명시 별칭/없는 가이드/검색 빈 결과/외부 링크 실패를 포함한다. 375px 및 큰 글자에서 실제 폰트 headless 렌더를 보고 수정·재캡처한다. Simulator는 실행하지 않는다.

## 4. 조사 출처 및 구현 결과

상태: LC05 휴식 설정·자동 시작과 LC06 운동·용어 가이드 구현 완료. 아래에 단위·연결·실제 폰트 렌더 검증을 구분하여 기록했다. 실제 기기 OS 동작은 사용자 확인 항목으로 남긴다.


### 4.1 휴식 설정 구현 증거

`AppSettings.defaultRestSeconds/autoStartRestTimer`를 추가하고 설정 파일2로 읽기/쓰기를 연결했다. 버전1의 두 기존 필드는 기본값으로 이행한다. 세트0초 우선과 사용자 출처의 보존은 `RestDurationSource/resolveRestSeconds`에서 명시한다. 타이머는 처방 출처의 기존 파일1을 유지하고 사용자 출처일 때 파일2를 쓴다. 출처가 있는 파일1은 거부한다.

타이머 자격 검사는 사용자 출처일 때 원래 세트 처방이 미지정인지 확인하며 현재 사용자 설정을 비교하지 않는다. 실제 기록/초안/마감·재개/복원 세대는 기존 검사를 계속 통과해야 한다. `startSetRest`와 `autoStartCompletedSetRest`는 처방 우선과 기존 타이머 교체 확인을 공유한다. 운동 화면의 저장 성공 직후 단발 호출은 LC03 담당 작업에 연결하여 별도 회귀 검증한다.

기존 설정/타이머 23개 시험 통과. 새 `rest_preferences_test.dart`의 7개 시험과 `settings_screen_test.dart`에 추가한 2개 경로가 통과했다(기존5개 포함14개 실행). 처음 렌더에서 큰 글자의 ‘새 세트 완료 후 자동 시작’이 마지막 한 글자를 다음 줄에 남겼다. 표시를 ‘완료 후 자동 시작’으로 줄여 동작 설명은 본문에 보존하고 재캡처한다. 처음 증거: `research/2026-09-08/rest-guides/rest-first/`. 정식 최종 증거는 실행 후 아래에 기록한다.

테스트가 검증한 범위는 headless Flutter 위젯·임시 파일이며 실제 OS 앱 재실행이나 Simulator 동작을 뜻하지 않는다.

휴식 단위 최종: `flutter test test/rest_preferences_test.dart test/settings_screen_test.dart test/rest_timer_test.dart test/local_settings_store_test.dart --dart-define=SETTINGS_RENDER_DIR=research/2026-09-08/rest-guides/rest-final --reporter expanded` **32개 통과**. `rest-settings-large.png`에서 단축한 자동 시작 라벨이 한 줄로 읽히며 입력·저장·설명·스위치가 잘리지 않음을 직접 확인했다. PNG는 실제 KR/Mono 폰트로 렌더했다. 새 테스트 수는 도메인7+위젯2=9개이며32개 전체가 새 테스트라는 뜻은 아니다.


### 4.2 가이드 출처와 콘텐츠 범위

조사일: 2026-09-08. ACE/NASM 자격교육기관의 직접 작성 자료, Muscle & Strength·StrengthLog 자체 운동 안내, REP Fitness의 직접 작성 동작 안내를 읽었다. 아래 링크는 검색 결과가 아닌 실제 원문으로 열어 본 페이지이다. 인용문/사진/영상을 복사하지 않고 시작·움직임·확인 세 항목을 독립적으로 짧게 작성했다. 원문에 포함된 근육 증가·부상 방지·치료 효능이나 권장 세트/반복을 앱 처방으로 옮기지 않았다.

| 실제 카탈로그 종목 | 검토 원문 |
|---|---|
| 고블렛 스쿼트 | [ACE · Goblet Squat](https://www.acefitness.org/resources/everyone/exercise-library/362/goblet-squat/) |
| 덤벨 스쿼트 | [Muscle & Strength · Dumbbell Squat](https://www.muscleandstrength.com/exercises/dumbbell-squat.html) |
| 바벨 백스쿼트 | [ACE · Back Squat](https://www.acefitness.org/resources/everyone/exercise-library/11/back-squat/) |
| 레그 프레스 | [NASM · Leg Press](https://www.nasm.org/resource-center/exercise-library/leg-press) |
| 덤벨 루마니안 데드리프트 | [NASM · Dumbbell Romanian Deadlift](https://www.nasm.org/resource-center/exercise-library/dumbbell-romanian-deadlift) |
| 바벨 루마니안 데드리프트 | [ACE · Romanian Deadlift](https://www.acefitness.org/continuing-education/certified/may-2025/8865/the-ace-do-it-better-series-the-romanian-deadlift/) |
| 시티드 레그 컬 | [ACE · Hamstrings study exercise instructions](https://www.acefitness.org/continuing-education/certified/february-2018/6896/ace-sponsored-research-what-is-the-best-exercise-for-the-hamstrings/) |
| 덤벨 글루트 브리지 | [NASM · Squat alternatives / Floor bridges](https://www.nasm.org/resource-center/blog/squat-alternatives) |
| 덤벨 스탠딩 카프 레이즈 | [REP Fitness · Dumbbell calf raises](https://repfitness.com/blogs/training/dumbbell-calf-raises) |
| 덤벨 벤치프레스 | [ACE · Dumbbell chest press](https://www.acefitness.org/resources/everyone/exercise-library/19/chest-press/) |
| 덤벨 인클라인 프레스 | [ACE · Incline chest press](https://www.acefitness.org/resources/everyone/exercise-library/25/incline-chest-press/) |
| 덤벨 플로어 프레스 | [Muscle & Strength · Dumbbell floor press](https://www.muscleandstrength.com/exercises/dumbbell-floor-press.html) |
| 바벨 벤치프레스 | [ACE · Barbell chest press](https://www.acefitness.org/resources/everyone/exercise-library/5/chest-press/) |
| 머신 체스트 프레스 | [ACE · Seated chest press](https://www.acefitness.org/resources/everyone/exercise-library/188/seated-chest-press/) |
| 덤벨 숄더 프레스 | [ACE · Seated overhead press](https://www.acefitness.org/resources/everyone/exercise-library/45/seated-overhead-press/) |
| 바벨 오버헤드프레스 | [Muscle & Strength · Military press](https://www.muscleandstrength.com/exercises/military-press.html) |
| 덤벨 레터럴 레이즈 | [ACE · Lateral raise](https://www.acefitness.org/resources/everyone/exercise-library/26/lateral-raise/) |
| 랫 풀다운 | [ACE · Seated lat pulldown](https://www.acefitness.org/resources/everyone/exercise-library/158/seated-lat-pulldown/) |
| 시티드 케이블 로우 | [Muscle & Strength · Seated cable row](https://www.muscleandstrength.com/exercises/seated-row.html) |
| 덤벨 벤트오버 로우 | [Muscle & Strength · Bent over dumbbell row](https://www.muscleandstrength.com/exercises/bent-over-dumbbell-row.html) |
| 덤벨 체스트 서포티드 로우 | [Muscle & Strength · Chest supported dumbbell row](https://www.muscleandstrength.com/exercises/chest-supported-dumbbell-row) |
| 덤벨 바이셉스 컬 | [ACE · Seated biceps curl](https://www.acefitness.org/resources/everyone/exercise-library/44/seated-biceps-curl/) |
| 케이블 트라이셉스 프레스다운 | [StrengthLog · Tricep pushdown with bar](https://www.strengthlog.com/tricep-pushdown-with-bar/) |
| 크런치 (맨몸) | [StrengthLog · Crunch](https://www.strengthlog.com/crunch/) |

자세가 이름만으로 확정되지 않는 덤벨 숄더 프레스/바이셉스 컬은 화면에 ‘앉은 자세 기준’, 케이블 프레스다운은 ‘바 손잡이 기준’을 표시한다. 덤벨 스쿼트는 양손에 들고 몸 옆에 둔 자세, 체스트 서포티드 로우는 인클라인 벤치에 가슴을 대는 자세로 명시했다. 시티드 레그 컬은 ACE 연구의 수행 방법을 참고하고 NASM 페이지의 패드 설명에 혼동 여지가 있어 ACE를 앱의 출처로 선택했다. RDL의 동작 범위·스쿼트 깊이는 원문의 특정 깊이를 모든 사용자에게 강요하지 않고 몸통 지지가 가능한 범위로 작성했다.

`guideForExercise`는 작성된 이름·별칭의 정확한 일치(양끝 공백과 영문 대소문자만 정리)만 허용한다. 장비가 생략된 ‘스쿼트’나 ‘덤벨 벤치프레스 변형’은 연결하지 않는다. 가이드 검색에서는 부분 이름/장비를 찾을 수 있지만 기록 복사나 종목 동일성 판단에 이 검색 결과를 사용하지 않는다. 24개 목록과 9개 용어 본문은 Dart 상수이며 파일 다운로드나 원격 응답 없이 제공한다.

새 페이지는 `ExerciseGuidesScreen`(검색/빈 상태), `ExerciseGuideScreen`(본문/원문 열기/진행/실패/재시도), `TrainingGlossaryScreen`(용어), `ExerciseGuideLink`(정확한 종목 연결/미등록 안내)이다. 검색 화면·운동 구성 상세·프로그램 구성 및 시작 전 검토에 링크를 연결했다. `GuideText`가 한글과 라틴·숫자 폰트를 분리한다. 외부 링크 어댑터는 `url_launcher`의 `LaunchMode.externalApplication`을 사용하며 중복 열기를 막는다.

### 4.3 가이드 검증과 렌더 수정

`flutter test test/exercise_guides_test.dart test/exercise_guide_screen_test.dart --dart-define=GUIDE_RENDER_DIR=research/2026-09-08/rest-guides/guide-final --reporter expanded` **10개 통과**(도메인4·위젯6). 실제 카탈로그의 24개 이름 전체, 고유 별칭, 미등록/모호한 이름, 장비/영문 검색,9개 용어, 정확한 외부 URI, false/throw 실패, 열기 중 상태, 재시도, 프로그램 상세·검색 진입, 큰 글자 경로를 검증했다.

처음 375px·1.8배 렌더에서 긴 종목 제목이 ‘서포티/드’로 끊겼다. 가이드 본문 제목을 heading 토큰으로 조정해 전체 종목 이름이 읽히게 했다. 링크 실패 패널이 기존 버튼 앞에 삽입되어 버튼을 화면 밖으로 밀어내던 문제는 실패 패널을 출처 버튼 뒤에 두어 해결했다. 테스트의 화면 교체 시 기존 Navigator 경로가 남던 설정도 분리하여 실제 새 진입으로 검사했다. 처음 실패 로그/PNG와 최종 통과 로그/PNG를 `guide-first/`와 `guide-final/`에 각각 보존했다. 최종 큰 글자 제목·본문·출처 재시도 화면을 직접 열어 확인했다.

외부 링크 시험은 주입한 어댑터의 성공/실패를 확인한 headless 시험이다. 실제 iOS/Android 브라우저 전환·뒤로 복귀·오프라인 네트워크·스크린리더·실제 키보드 검증은 운영 확인표에 남는다. 앱이 사용자 동작을 측정하거나 자세의 정확성을 판정한다고 설명하지 않는다.

## 5. 사용자가 확인할 순서

1. 프로필 → 앱 설정에서 기본 휴식을 90초로 저장하고 자동 시작은 꺼진 상태를 확인한다.
2. 휴식 처방이 없는 세트를 완료해 수동 휴식 시작에90초가 표시되는지 확인한다.
3. 설정에서 자동 시작을 켜고 새 세트를 완료해 타이머의 ‘시작 당시 사용자 기본값’ 출처를 확인한다.
4. 설정값을120초로 바꾸고 이미 시작한 타이머의 원래 시간과 출처가 유지되는지 확인한다.
5. 처방0초인 세트는 기본값이 있어도 타이머가 시작되지 않는지 확인한다.
6. 진행 중 타이머가 있을 때 새 세트를 완료하고 교체 확인을 취소하여 원래 타이머가 유지되는지 확인한다.
7. 기존 완료 기록을 수정해 자동 타이머가 다시 시작되지 않는지 확인한다.
8. 검색 → 운동·용어 가이드에서 종목·장비·영문 별칭을 검색하고 내용을 연다.
9. 네트워크를 끊은 뒤에도 본문을 읽을 수 있는지 확인하고 원문 열기 실패 후 앱으로 돌아온다.
10. 프로그램 상세와 시작 전 검토에서 같은 종목 가이드를 열고, 미등록 관리자 종목에는 가이드 없음이 표시되는지 확인한다.
11. 기기 글자 크기를 키워 모든 입력/버튼/본문이 스크롤로 도달 가능한지 확인한다.
12. 기기를 종료하고 다시 켜 설정·타이머를 확인한다. 실제 OS 종료/복귀 결과는 수행한 기기와 시간을 별도로 기록한다.

## 6. 한 문장 변경 목록

- 휴식 처방이 없는 세트에 적용할 사용자 기본 시간을 기기에 저장한다.
- 새 완료 기록의 저장이 성공한 뒤에만 자동 휴식을 시작한다.
- 명시0초는 사용자 기본값으로 대체하지 않는다.
- 진행 중인 타이머의 처방/사용자 출처와 시작 당시 시간을 보존한다.
- 기존 타이머를 교체할 때 사용자의 확인을 받는다.
- 기본5개 프로그램의24개 종목에 오프라인 동작 설명을 연결한다.
- 9개 운동 용어를 앱의 실제 기록·처방 규칙과 함께 설명한다.
- 미등록 종목에는 다른 종목의 가이드를 추정해서 보여주지 않는다.
- 출처 링크 열기 실패 뒤에도 본문과 재시도 버튼을 유지한다.

가이드 연결 회귀: `flutter test test/exercise_guides_test.dart test/exercise_guide_screen_test.dart test/advanced_workout_screen_test.dart --reporter expanded` **16개 통과**. 기존 고급 처방 표시·슈퍼세트 순서·수동 타이머·실패/재시도·보관 읽기 전용 검사를 함께 통과했다. [회귀 로그](../research/2026-09-08/rest-guides/guide-regression.txt).


## 7. 자동 시작 연결 최종 검증

운동 입력 화면에서 아직 완료하지 않은 세트를 완료할 때 자동 시작 여부를 한 번 캡처한다. 운동 파일 저장 성공 후에만 휴식 시작을 호출하고, 호출 전에 대기 플래그를 해제하여 중복 실행을 막는다. 저장 실패 후 재시도는 완료가 확정된 시점에 한 번 시작한다. 기존 완료 기록 수정, 초안, 제외, 화면 재진입은 새 타이머를 시작하지 않는다.

설정 범위가 Navigator 아래에 있는 앱 구조를 고려하여 오늘/놓친 운동 경로와 세트 입력 시트에 같은 SettingsController를 전달했다. 수동 시작 표시도 처방과 사용자 기본값을 함께 해석하여, 처방 미지정·사용자 기본 90초인 경우 `1세트 휴식 시작 · 90초`로 표시한다. 명시 0초는 버튼과 자동 시작을 모두 생략한다. 기존 타이머의 교체 확인 동안 기록 저장 잠금을 유지하며, 교체를 취소해도 완료 기록과 기존 타이머를 보존한다.

`flutter test test/rest_auto_start_screen_test.dart --reporter expanded` **6개 통과**. 새 완료의 기본 90초 시작·재진입 및 설정 변경 시 원래 기한 유지, 자동 꺼짐과 명시 0초, 기존 완료 수정, 타이머 교체 취소, 운동 파일 저장 실패/재시도, 타이머 파일 저장 실패/재시도를 검증했다. 두 저장 실패 시험은 실제 임시 파일 경로의 쓰기를 막아 재현했으며, 타이머 실패 때 운동 파일에 완료가 남는지 별도로 읽어 확인했다.

`flutter test test/rest_auto_start_screen_test.dart test/settings_screen_test.dart test/exercise_search_test.dart test/settings_integration_test.dart --reporter expanded` **21개 통과**. 새 가이드 진입이 추가된 검색 화면의 300px 키보드와 큰 글자 설정 화면에서 스크롤이 정착한 후 실제 버튼이 터치 가능한지를 확인했다. 기존 시험은 `ensureVisible` 직후 재배치가 완료되기 전에 터치해 실패했으므로, 애니메이션 정착과 재노출 뒤 `hitTestable` 검사를 유지했다. 기능 검증을 제거하거나 화면 제약을 완화하지 않았다.

`flutter test test/rest_auto_start_screen_test.dart --dart-define=REST_AUTO_RENDER_DIR=research/2026-09-08/rest-guides/auto-render --reporter expanded` **6개 통과**. 실제 KR/Mono 폰트의 375px 렌더에서 자동 시작 완료 패널과 타이머 교체 확인 창을 직접 열어 확인했다. 기본 90초·출처·완료 기록·수동 시작 문구가 읽히며 확인 창의 취소/교체 버튼이 잘리지 않는다. 처음 자동 시작 시험의 대화상자 대기 중 spinner 정착 실패와 중복 재시도 finder 문제는 테스트를 실제 입력 시트/대화상자 상태에 맞게 수정했다. 첫 실패 로그와 최종 로그를 함께 보존했다.

증거: [자동 시작 시험](../research/2026-09-08/rest-guides/rest-auto-tests.txt), [연결 회귀](../research/2026-09-08/rest-guides/rest-integration-tests.txt), [실제 폰트 렌더](../research/2026-09-08/rest-guides/auto-render/). LC05의 새 시험은 설정/도메인 9개와 자동 시작 6개이고 LC06의 새 시험은 10개다. 실행 명령별 개수는 중복 실행을 포함하므로 합산하여 전체 고유 시험 수로 사용하지 않는다. 이 검증에서는 Simulator를 실행하지 않았다.

최종 담당 파일 정적분석: 휴식/설정/가이드 도메인·저장·화면·전용 시험에 `dart analyze`를 실행하여 **No issues found**를 확인했다. 발견한 if 블록 중괄호 5곳과 사용하지 않는 테스트 import 1곳을 정리했으며 동작은 바꾸지 않았다.
