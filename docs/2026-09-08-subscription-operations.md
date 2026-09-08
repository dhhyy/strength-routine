# 9/8 · 1인 트레이너 구독 운영과 앱 설정

기준일·공식 문서 열람일: 2026-09-08 (Asia/Seoul). 이번 사용자 방향은 **트레이너 1명이 운영**하는 앱이다. 여러 트레이너의 입점·승인·정산 도구는 범위에서 제외한다. 기존의 완성 프로그램 선택 및 운동·세트 구성 보존 결정을 유지한다.

현재 구현은 **기기에 저장하는 앱 설정, 구독 준비 안내, 로컬 도움말**이다. 결제 상품·가격·유료 권한·계정 서버는 없다. 아래 운영 방식과 출시 순서는 설계 제안이며 사용자 가격/제공 주기 확정이나 실제 판매 개시를 뜻하지 않는다.

## 지금 사용할 수 있는 기능

| 기능 | 동작 | 저장·실패 경계 |
|---|---|---|
| 기본 중량 단위 | kg/lb 선택. 새 세트와 최근 기록 입력의 초기 단위로 사용 | 저장 성공 후 적용. 기존 초안/실제 단위를 우선하며 숫자 환산·목표 변경 없음 |
| 중량 조정 제안 표시 | 표시 여부를 저장. 끄더라도 적용 이력·되돌리기 접근은 유지 | 표시 설정일 뿐 자동 적용 동의나 구매 권한이 아님. 제안 조건·기록 연결은 별도 D5 구현 계약을 따름 |
| 구독 안내 | 구매할 상품이 아직 없다는 상태와 기기 기록 접근을 안내 | 결제·무료 체험·구매 복원·해지 성공 버튼 없음 |
| 도움말 | 구독 준비/복원 미연결/기기 저장/단위/보관 초안/문의 범위 6개 항목 펼치기 | 앱 내 고정 본문. 네트워크 요청·실시간 상담·문의 접수 없음 |

코드: [설정 모델](../lib/domain/app_settings.dart), [설정 저장소](../lib/data/local_settings_store.dart), [컨트롤러와 주입 범위](../lib/app/settings_controller.dart), [설정 화면](../lib/settings_screen.dart), [구독 안내](../lib/subscription_screen.dart), [도움말](../lib/support_screen.dart). [RootGate](../lib/main.dart)는 설정 컨트롤러를 한 번 생성·초기화하고 `SettingsScope`로 `HomeShell`에 공유한다. 프로필의 앱 설정·도움말·구독 안내 진입, 설정 저장 후 새 세트/최근 기록의 lb 입력, 기존 kg 초안/실제 기록 보존은 [통합 테스트 3개](../test/settings_integration_test.dart)로 확인했다. 기록 탭의 ‘기록 추세·중량 조절’은 저장된 `showLoadSuggestions`를 화면에 전달한다. 이 연결은 코드로 확인했으며 해당 설정의 켜기/끄기 조작을 통합 테스트 3개가 검증한 것으로 확대하지 않는다.

### 설정 계약

- `AppSettings.defaultWeightUnit`: `WeightUnit.kg`가 초기값. `showLoadSuggestions`: 초기값 `true`. 타이머가 없으므로 휴식 시간 설정은 추가하지 않는다.
- `LocalSettingsStore`는 envelope `schemaVersion: 1`을 사용한다. 일반 앱 진입은 운동 저장 폴더의 `app-settings.json`에 저장하고, 테스트처럼 운동 컨트롤러를 외부 주입한 진입은 해당 운동 파일 경로 뒤에 `.settings.json`을 붙여 격리한다. 저장소는 파일이 없을 때만 기본값을 반환한다. 손상/미지원 스키마/알 수 없는 단위/잘못된 bool은 오류로 보존한다.
- 읽기·쓰기는 인스턴스의 큐로 직렬화한다. 임시 파일 flush 후 rename하며 실패한 쓰기가 후속 재시도를 막지 않는다. 여러 프로세스 동시 쓰기나 전원 차단 검증을 뜻하지 않는다.
- `SettingsController.settings`는 마지막으로 읽기·저장에 성공한 적용값이며, 성공 이력이 없으면 초기값 kg/제안 표시 켜짐이다. `displayedSettings`는 미저장 선택을 포함한다. 저장 중 중복 변경은 막고, 실패 시 선택·오류를 유지한다. 재시도 성공 시에만 다른 화면에 적용한다.
- 설정 화면을 닫았다 다시 열어도 같은 컨트롤러가 미저장 선택을 보존한다. 앱 프로세스 종료 뒤에는 마지막 파일 저장 성공값까지만 복원한다. 설정 손상 상태에서는 화면에서 새 설정으로 덮어쓰지 않는다.
- 새 입력의 단위 우선순위: 유효한 저장 초안 단위 → 기존 실제 기록 단위 → 저장된 기본 단위. 기존 수치·목표 중량을 환산하거나 초기화하지 않는다.
- **설정 읽기 실패의 현재 동작:** 컨트롤러가 읽기 오류를 보유하고 원본 파일을 유지하며, `RootGate`는 이 오류만으로 앱 진입을 막지 않는다. 설정 화면에는 ‘설정을 불러오지 못했어요’와 ‘다시 불러오기’만 표시하고 수정 컨트롤을 숨긴다. 다른 화면은 컨트롤러에 남은 적용값을 사용하므로 최초 읽기 실패라면 새 입력은 kg, 제안 표시는 켜짐으로 동작한다. 같은 컨트롤러에 이전 성공값이 있으면 그 값을 유지한다. 홈 전체에 설정 오류 배너를 따로 표시하지는 않는다. 읽기 실패 후 설정 화면의 오류·원본 보존·재시도는 단독 위젯 테스트로 확인했고, 실패 상태에서 앱 진입과 새 입력으로 이어지는 대체값 경로는 코드 확인 범위다.

## 1명이 지속할 수 있는 구독 가치

정기 결제의 가치는 신규 화면 잠금 자체보다 **지속적으로 관리되는 프로그램과 설명**에서 만든다. Apple은 구독에 지속적 가치와 콘텐츠/기능의 정기적인 개선을 설명한다. 이를 근거로 아래 운영안을 제안한다. [S01 · Apple 구독](https://developer.apple.com/app-store/subscriptions/)

| 운영 작업 | 제안 주기·산출물 | 1인 운영을 위한 범위 |
|---|---|---|
| 프로그램 관리 | 월간 검토 후보: 프로그램 버전·대상·장비·기간·변경 이유 | 새 프로그램 개수를 먼저 약속하지 않고 기존 구성의 정확성과 설명부터 유지 |
| 운동 설명·FAQ | 반복 문의가 쌓일 때 공통 답변 업데이트 | 개인별 무제한 상담을 구독 혜택에 포함하지 않음 |
| 품질 점검 | 콘텐츠 배포 전 계획 생성→실제 기록→복원 회귀 | 기존 계획 스냅샷을 새 버전으로 몰래 교체하지 않음 |
| 운영 공지 | 제공 일정 변경·장애·정정 시 공지 | 날짜·영향·복구 상태를 기록. 아직 푸시/공지 서버 없음 |

콘텐츠는 초기에는 운영자가 관리하는 검증된 데이터 파일로 시작할 수 있다. 이 방식에도 작성일·버전·소스·처방 기준·변경 이력이 필요하다. 여러 트레이너의 프로필 등록, 역할별 승인, 매출 분배, 메시지 중계 기능은 만들지 않는다. 운영자가 사용자 데이터를 수동으로 받아 중량을 처방하는 기능도 이번 범위가 아니다.

### 월간·연간 상품은 선택지이며 가격은 미정

우선 동일한 콘텐츠 권한의 월간 상품 하나를 검토하고, 정기 제공을 지속할 수 있음을 확인한 뒤 같은 권한의 연간 상품을 검토한다. 연간 할인율·무료 체험·출시 가격·혜택 개수는 아직 확정하지 않는다. 이 순서는 운영 제안이며 스토어의 강제 조건이 아니다.

출시 전 결정할 항목: 포함 콘텐츠/업데이트 범위, 무료 기능과 유료 신규 콘텐츠 경계, 월/년 제공 여부, 소비자 표시 가격, 무료 체험 여부, 구독 종료 후 이미 시작한 프로그램의 편집 범위, 지원 채널·답변 가능 시간. Apple에서는 같은 권한의 월/년 상품을 한 구독 그룹 안에서 단순하게 구성하는 방안을 검토한다. 표시 가격은 스토어가 반환한 지역화된 금액·주기를 사용한다. [S01](https://developer.apple.com/app-store/subscriptions/)

한국 운영을 위한 외부 결제·지역 예외·수수료·세금 수치를 이번 조사에서 확정하지 않는다. iOS App Store와 Android Google Play의 일반적인 인앱 구독 경로를 기준으로 설계하며, 실제 판매 국가와 사업자 계정·계약을 확인한 뒤 출시 시점의 정책을 다시 점검한다.

## 결제 연결 전에 필요한 권한 구조

현재 `AppSettings`나 운동 저장 JSON에 `isPremium` 같은 유료 플래그를 넣지 않는다. 기기의 구매 완료 화면을 누른 사실만으로 권한을 발급하면 복원·환불·다른 기기·변조에 대응하기 어렵다. 아래는 **미구현 서버 설계안**이다.

1. 앱은 스토어 상품 조회값으로 혜택·결제 주기·가격을 표시한다. 상품 조회 실패/판매 불가면 구매를 막고 재시도 상태를 보여준다.
2. 실제 구매 결과의 식별자/서명 거래를 서버에 보내 플랫폼·상품·환경·사용자 연결을 검증한다. Apple StoreKit 2는 App Store 서명 JWS 거래를 제공하고 최신 거래를 앱/서버에서 조회할 수 있다. [S02 · StoreKit 2](https://developer.apple.com/storekit/)
3. Google은 `purchaseToken`을 서버에서 검증하고 `purchases.subscriptionsv2.get` 결과를 확인한 뒤 권한을 부여한다. `PENDING`에는 권한을 부여하지 않으며, 구매 인정 처리를 성공적으로 마쳐야 한다. [S03 · 구매 검증](https://developer.android.com/google/play/billing/security)
4. 최소 서버 데이터 제안: 사용자 연결키, 스토어/상품/환경, 거래 식별자, 확인한 상태·만료 시각·검증 시각, 처리한 이벤트 식별자. 거래별 중복 처리는 차단하고 서버 알림 누락·순서 변경은 최신 상태 재조회로 맞춘다. 비밀 키와 원본 결제 토큰을 앱 로그에 노출하지 않는다.
5. Apple App Store Server Notifications/API와 Google RTDN/API를 연결한다. 알림 한 건만 보고 최종 상태를 추정하지 말고 검증한 최신 상태를 반영한다. 운영자용 화면도 상태 조회·오류 확인부터 만들고 임의 유료 전환 버튼을 먼저 만들지 않는다. [S01](https://developer.apple.com/app-store/subscriptions/), [S04 · Google 구독 수명주기](https://developer.android.com/google/play/billing/lifecycle/subscriptions)

같은 스토어 계정의 구매 재조회와 iOS↔Android 권한 공유는 별개다. 후자는 앱 계정·연결 정책이 있어야 하므로 현재 지원한다고 안내하지 않는다. 권한 서버 도입이 운동 기록의 자동 업로드나 클라우드 백업 동의를 의미하지도 않는다.

## 갱신·해지·환불·만료의 사용자 경험

아래 표는 이후 구현할 상태 처리안이다. **현재 앱에는 이 상태를 흉내 내는 구매 데이터가 없다.**

| 확인한 상태 | 이후 앱 동작 제안 | 기기에 남은 사용자 기록 |
|---|---|---|
| 구매 없음/상품 준비 중 | 구매 불가 사유와 현재 기능 안내 | 열람 유지 |
| 구매 대기/권한 확인 중 | 처리 중 표시, 같은 구매 중복 요청 차단. 성공으로 표시하지 않음 | 열람 유지 |
| 검증된 활성 | 제공 범위·갱신일·스토어 관리 진입 표시 | 열람 유지 |
| 자동 갱신 해제, 기간 남음 | 종료 예정일 안내. 유효 기간까지 권한 유지 | 열람 유지 |
| 결제 유예 | 스토어가 확인한 유예 기간 동안 권한 유지, 결제 수단 관리 안내 | 열람 유지 |
| 유예 없는 재청구/계정 보류 | 스토어별 상태로 유료 권한을 판단. 단순히 ‘재청구’라는 이유로 연장하지 않음 | 열람 유지 |
| 만료/확인된 권한 철회 | 신규 유료 콘텐츠 접근 종료, 재구독 가능 상태 설명 | 실제 기록·초안·기존 계획 열람 유지; 자동 삭제 금지 |
| 서버 통신 실패 | 마지막 확인 시점과 재확인 오류 표시. 신규 권한 발급/무기한 연장 없음 | 열람 유지 |

Apple의 Billing Grace Period와 일반 billing retry는 동일하지 않다. Google은 유예 중 권한을 유지하고 account hold에 들어가면 유료 권한을 중단하며, 취소됐어도 아직 유효한 기간에는 접근을 유지한다. 만료·철회는 확인된 상태에 따라 처리한다. 유예 기간의 실제 길이는 스토어 설정에서 정할 사항이다. [S01](https://developer.apple.com/app-store/subscriptions/), [S04](https://developer.android.com/google/play/billing/lifecycle/subscriptions)

환불 요청 접수와 승인·권한 철회는 서로 다른 사건이다. 앱은 스토어의 환불/구독 관리 기능으로 안내하고 확인된 결과를 서버 상태에 반영한다. 운영자가 앱 화면만으로 환불 성공을 보장하지 않는다. 기록을 계속 읽게 하는 것은 이 앱의 제안 정책이며 환불된 유료 콘텐츠를 계속 제공한다는 뜻은 아니다. [S02](https://developer.apple.com/storekit/), [S03](https://developer.android.com/google/play/billing/security)

구매 복원은 ‘기존 구매를 다시 확인’하는 동작으로 설계한다. 결과 없음, 다른 계정, 연결 실패, 만료, 정상 활성 상태를 구분하고 금액을 다시 청구하는 구매와 혼동하지 않는다. Google 문서의 `restore`는 만료 전 자동 갱신 복구 의미로도 쓰이므로, UI의 재설치 후 구매 확인과 내부 용어를 구분한다. [S04](https://developer.android.com/google/play/billing/lifecycle/subscriptions)

## 운영·오픈 순서

1. **내용 먼저:** 1인이 책임질 최초 프로그램·설명·제공 주기·구독 범위를 확정한다. 실제 카탈로그 데이터로 기록/복원 흐름을 검증한다.
2. **접수 준비:** 지원 주소·문의 유형·답변 가능 시간·개인정보 처리 범위를 정한다. 그전에는 현재 로컬 FAQ만 제공하고 접수 완료를 표시하지 않는다.
3. **스토어 준비:** 개발자 계정, 앱 식별자, 계약/정산 정보, 상품·지역화 메타데이터·이용 조건·개인정보 안내를 준비한다. 계정 유무는 현재 작업에서 확인되지 않았고 접근/상품 정보가 제공되지 않았다.
4. **실제 연결:** 결제 SDK, 구매 검증 서버, 알림 처리, 복원/관리 진입, 콘텐츠 권한 경계를 연결한다. 상품 가격·유료 상태를 로컬 상수로 대체하지 않는다.
5. **테스트 환경:** Apple Sandbox 계정과 실제 상품 정보로 검증한다. Apple의 Sandbox/TestFlight 구매는 실제 과금 없이 검증하는 경로다. Google은 license tester와 테스트 결제 수단을 명시적으로 사용한다. 단순 내부 테스트 트랙 설치만으로 비과금이 보장되지 않는다. [S05 · Apple Sandbox](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox), [S06 · Google 테스트](https://developer.android.com/google/play/billing/test)
6. **판매 전 확인:** 아래 실패 행렬과 현재 기록 회귀를 통과하고, 스토어 심사/지역별 표시/지원 준비를 확인한 뒤 제한적으로 공개한다. 결제 운영 장애 시 신규 판매 진입을 멈출 수 있어도 기존 기록 읽기는 막지 않는다.

### 판매 전 테스트 행렬 — 아직 실행하지 않음

| 분류 | 반드시 확인할 결과 |
|---|---|
| 상품 조회/사용자 취소/대기 결제 | 잘못된 가격·유료 성공을 표시하지 않고 중복 청구 경로를 만들지 않음 |
| 구매→앱 종료→복원 | 서버 확인 뒤 같은 권한 복구, 거래 중복 처리 없음 |
| 갱신/자동 갱신 해제/유예/보류/만료 | 스토어의 유효 기간·상태와 앱 접근이 일치 |
| 환불 요청/승인/거절/철회 | 요청 단계에서 임의 삭제 없음, 확인된 결과 반영 |
| 지연·중복·순서가 바뀐 서버 알림 | 최신 상태 재조회와 중복 방지, 재시도 후 일관된 권한 |
| 다른 계정/다른 환경 토큰/위조 거래 | 다른 사용자의 권한으로 연결되지 않음 |
| 만료 후 로컬 기록/초안/기존 계획 | 계속 열람, 삭제·빈 파일 덮어쓰기 없음 |
| 권한 서버 장애/오프라인 | 재확인 오류와 보유 기록 분리, 새 권한 임의 생성 없음 |

위 검증에는 실제 스토어 준비가 필요하다. 이번에는 돈을 받거나 스토어 상품을 생성하지 않았고 Sandbox 거래·실제 기기 결제도 실행하지 않았다. 사용자 지시에 따라 시뮬레이터를 실행하지 않는다.

## 이번 자체 검증과 렌더

설정 관련 테스트는 **총 13개**다. [파일·컨트롤러 5개](../test/local_settings_store_test.dart)와 [위젯 5개](../test/settings_screen_test.dart)는 기본값/설정 왕복/큐/손상 원본/실패 보존/중복 저장 차단/재진입/재시도/큰 글자/도움말을 확인했다. 이후 [실제 앱 통합 3개](../test/settings_integration_test.dart)를 추가했고 모두 통과했다.

| 통합 테스트 | 확인한 사용자 흐름·저장 결과 |
|---|---|
| 프로필 설정·도움말·구독 진입 후 새 세트 기록 | `StrengthApp`→프로필→앱 설정에서 lb 저장→도움말/구독 화면→오늘 운동에서 빈 실제값을 80 lb로 입력·완료. 새 저장소로 실제값 lb와 원래 목표 스냅샷 불변을 확인 |
| 기존 kg 초안·실제 기록 보존 | 프로필 기본값을 lb로 변경해도 kg 초안 `87.`/RIR 0 및 kg 실제 기록 `92.5`/RIR 0을 그대로 열고 닫음. 메모리 전체 상태와 저장 JSON이 동일 |
| 프로그램 흐름의 최근 기록 기본값 | 프로필→프로그램 선택→상세→기록과 일정→최근 기록 입력에서 초기 lb, 빈 실제값 확인. 100 lb·5회를 저장하고 새 저장소로 복원. 활성 계획은 아직 생성되지 않음 |

위 테스트는 임시 운동/설정/습관 파일을 사용하고 플러그인 대신 컨트롤러와 저장소를 주입한 `StrengthApp`의 실제 화면 경로를 조작한다. 네이티브 프로세스 재실행이나 실제 사용자 데이터 시험은 아니다. 중량 조정 엔진·추세·이력 등의 테스트는 설정 13개와 별도이며 앱 전체 회귀에 포함된다.

최종 앱 전체 `flutter test --concurrency=2 --reporter expanded`는 **120개 통과(1분 52초)**했고 [실행 로그](../research/2026-09-08/features/flutter-test.txt)에 남겼다. 설정 13개는 이 120개에 포함되며 합산해 133개라고 세지 않는다. 전체 `flutter analyze`도 [문제 없음](../research/2026-09-08/features/flutter-analyze.txt)으로 완료했다. 실제 결제/Sandbox·시뮬레이터 검증은 이 결과에 포함되지 않는다.

화면 목적은 설정 기본값 변경, 구독 현재 상태 확인, FAQ 열람으로 각각 하나다. Fixed 앱바, Fluid 본문, Hybrid 설정·안내 패널에 기존 FlowPage/GlassPanel/StatePanel과 AppType/AppSpace를 사용한다. 새 브랜드 색·휴식 타이머·유료 잠금 토큰을 만들지 않는다.

375×812, 실제 번들 폰트·아이콘의 headless 위젯 렌더를 확인했다. 초기 kg 선택 배경에 Material 기본 보라색이 나타나 기존 운동 입력의 `accentSoft`/`fill`/`hairStrong` 토큰으로 바꿨다. 구독 준비 설명도 두 줄로 줄여 재렌더했고, 한글/숫자·설정 선택·FAQ 펼침·버튼 접근을 확인했다. [설정](../research/2026-09-08/settings/settings-default.png), [구독 준비](../research/2026-09-08/settings/subscription-preparation.png), [도움말](../research/2026-09-08/settings/support-faq.png). 이는 네이티브 캡처나 실제 VoiceOver 검증이 아니다. 설정의 글자 2배 확대는 위젯 조작 테스트로 별도 확인했다.

재현 명령 **[macOS zsh · `apps/strength_routine`]**:

```sh
flutter test test/local_settings_store_test.dart test/settings_screen_test.dart --concurrency=1 --reporter expanded
flutter test test/settings_integration_test.dart --concurrency=1 --reporter expanded
flutter test test/settings_screen_test.dart --dart-define=SETTINGS_RENDER_DIR=/tmp/strength-settings-render
flutter test --concurrency=2 --reporter expanded
flutter analyze
```

`SETTINGS_RENDER_DIR`를 지정한 실행에서만 PNG를 쓴다. 일반 회귀 실행은 렌더 파일을 만들지 않는다. 담당 단독 10개는 5초, 추가 통합 3개는 14초에 각각 통과했고 이후 전체 120개 회귀도 통과했다. 최초 8파일 정적 분석과 추가 통합 테스트 파일 정적 분석 모두 문제가 없었으며, 전체 분석 결과는 위 로그를 따른다. 당시 `git diff --check`도 오류가 없었다. 이번 문서 갱신에서는 코드를 확인하고 기존 실행 결과를 반영했으며 테스트를 재실행하지 않았다.

## 공식 출처 목록

모두 2026-09-08 열람. Apple/Google 공식 기술 문서만 사용했다. 한국 사업자 법률·세무·지역 예외에 대한 결론으로 확대하지 않는다. Apple의 JavaScript 문서 일부는 검색 색인의 공식 본문으로 내용을 확인했고, 일반 구독/StoreKit 페이지는 직접 열린 본문을 확인했다.

| ID | 공식 제목·URL | 이번 확인 범위 |
|---|---|---|
| S01 | [Auto-renewable Subscriptions](https://developer.apple.com/app-store/subscriptions/) | Apple 플랫폼의 정기 가치·상품 그룹·관리 진입·상태 확인·유예 |
| S02 | [StoreKit 2](https://developer.apple.com/storekit/) | 서명 거래·최신 상태·환불 요청/관리 API. Flutter SDK 선택을 확정한 자료는 아님 |
| S03 | [Fight fraud and abuse](https://developer.android.com/google/play/billing/security) | Play 구매 토큰 서버 검증·구매 인정·대기 결제·철회 |
| S04 | [Subscription lifecycle](https://developer.android.com/google/play/billing/lifecycle/subscriptions) | Play 유효 기간·갱신 해제·유예/보류·만료·복구·철회 |
| S05 | [Testing In-App Purchases with sandbox](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox) | Apple 상품/계정 준비·Sandbox 비과금. 직접 open은 JS 안내만 반환하여 공식 검색 색인의 본문으로 보완 |
| S06 | [Test your Google Play Billing Library integration](https://developer.android.com/google/play/billing/test) | license tester·테스트 결제·테스트 트랙 과금 차이·지연 결제 |
