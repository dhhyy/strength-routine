# 2026-09-07 · 개인화·운동 가이드 앱 확장 분석

대상: **Fitbod, Caliber, RP Hypertrophy App, 번핏(BurnFit)**. 열람일: **2026-09-07 (Asia/Seoul)**.

공식 제품 페이지·도움말과 번핏의 한국 App Store 개발자 설명을 검색하고 본문을 직접 열어 확인했다. **앱 설치·로그인·운동 수행·결제 등 실기 체험은 하지 않았다.** 관찰은 공개 문서에 설명된 기능을 뜻한다. 입력 속도, 추천 정확도, 운동 효과, 실제 화면 배치와 접근성은 검증하지 않았다. 긴 원문 인용 없이 출처별 사실을 짧게 요약했다. 이번 작업은 조사와 제안이며 앱 코드는 변경하지 않았다.

분석 기준은 [9월 7일 사용자 결정](../../../docs/2026-09-07-work-log.md)의 I05·I06이다. 사용자는 **트레이너가 만든 완성 프로그램을 선택하고 운동·세트 구성은 보존하며 중량·시작일·요일만 맞춘다.** 트레이너 도구는 후속 개발이고 실제 수록 프로그램은 아직 미선정이다. 다른 앱의 자동 처방을 도입하거나 새로운 설문을 필수화하는 승인은 이번 조사에 포함되지 않는다.

**P1**은 현재 생성→기록→복원 흐름에서 우선 검토할 개선, **P2**는 실제 콘텐츠와 기록이 쌓인 뒤 검토할 확장이다. 우선순위는 조사자의 제안이며 확정 개발 순서가 아니다.

## Fitbod

### 공식 관찰

| 단계 | 공식 본문에서 확인한 사실 |
|---|---|
| 처음 시작·설정 입력 | My Plan은 목표·운동 장소/장비·주당 운동일을 설정하고 경험·시간 등의 상세 설정을 제공한다. 장비별 사용 가능한 중량 간격도 지정한다. 첫 설치의 필수 화면 순서를 확인한 것은 아니다. [GUIDE01](https://help.fitbod.me/hc/en-us/articles/34336407191191-My-Plan) |
| 개인화 설명 | 목표와 기록·회복·장비 등을 바탕으로 운동·세트·반복·중량을 추천한다. 시작 전 추천이 새로 생성될 수 있지만 Start Workout 이후에는 해당 운동이 재생성되지 않는다고 설명한다. [GUIDE02](https://help.fitbod.me/hc/en-us/sections/360001078993-How-Fitbod-Works) |
| 진행 분석 | 실제 운동 이력과 추정 지표를 구분해 설명하고, Overall Strength Score는 필요한 기록이 충분해질 때 표시한다. 운동별 이력 접근 경로도 안내한다. [GUIDE03](https://help.fitbod.me/hc/en-us/articles/12732749777047-Fitbod-Metrics-Records) |
| 운동 가이드 | 운동 시연 영상 제공을 설명한다. [GUIDE02](https://help.fitbod.me/hc/en-us/sections/360001078993-How-Fitbod-Works) |
| 완료 후 피드백 | 완료·가져온 운동과 설정 변경이 후속 추천에 영향을 줄 수 있다. 완료 직후 피드백 입력 화면의 순서·필수 여부는 이 조사에서 확인하지 않았다. [GUIDE02](https://help.fitbod.me/hc/en-us/sections/360001078993-How-Fitbod-Works) |

### 미확인

현재 iOS·Android의 화면 동일성, 최초 설치 시 실제 입력 단계 수, 데이터 부족 화면의 정확한 문구, 점수의 개인별 타당성은 미확인이다. My Plan 문서는 2026-03-03 수정본이며, 다른 도움말의 명칭·이전 화면 안내가 현재 앱과 완전히 일치한다고 가정하지 않는다.

### 우리 제품 분석과 개선 제안 · 2건

1. **P1 · 기존 ‘시작 전 확인’에 중량의 출처를 추가한다.** 현재 앱은 기준 중량을 직접 입력받고 일정·세트 목표를 미리 보여준다. 여기에 트레이너의 처방 방식, 사용자가 입력한 기준, 장비 간격 적용 결과를 펼쳐 확인하도록 제안한다. 고정 중량·비율·직접 기록을 구분하고 최근 수행 기록을 자동 추정 기준으로 바꾸지 않는다. 이미 있는 미리보기의 설명 개선이며 새 생성 흐름을 만들자는 제안이 아니다.
2. **P2 · 운동별 실제 이력과 ‘비교할 기록 없음’을 먼저 제공한다.** 같은 운동의 날짜·실제 중량·반복을 보여주고 목표와 실제를 나란히 비교한다. 임의의 종합 점수나 e1RM 수치로 빈 상태를 채우지 않는다. 운동 식별자와 단위·비교 조건을 정한 뒤 그래프를 추가한다.

**요구 충돌:** Fitbod의 운동 교체·세트 재구성과 기록 부족 시 추천 중량 추정은 우리 I03·I06과 그대로 호환되지 않는다. 참고할 부분은 입력 목적과 계산 근거의 설명, 시작한 계획의 보존이다. 추천 엔진을 복사하는 근거로 사용하지 않는다.

## Caliber

### 공식 관찰

| 단계 | 공식 본문에서 확인한 사실 |
|---|---|
| 처음 시작·설정 입력 | 무료 운동 앱 페이지는 경험·장비에 맞는 코치 작성 계획을 안내한다. 별도 **1:1 코칭 서비스** 상담에서는 목표·경험·시간·장비·식사 선호를 묻는다. 이 상담 항목을 무료 앱의 필수 온보딩으로 일반화하지 않는다. [GUIDE04](https://caliberstrong.com/workout-app/) [GUIDE05](https://caliberstrong.com/online-personal-trainer/) |
| 개인화 설명 | 무료 앱은 운동 대체·휴식 조절 등 편집 기능을, 코칭 서비스는 사람 코치가 계획을 맞추는 방식을 설명한다. [GUIDE04](https://caliberstrong.com/workout-app/) [GUIDE05](https://caliberstrong.com/online-personal-trainer/) |
| 진행 분석 | 운동 이력, Strength Score·Strength Balance 등의 지표를 안내한다. 계산 정확도와 서비스별 제공 범위는 검증하지 않았다. [GUIDE04](https://caliberstrong.com/workout-app/) |
| 운동 가이드 | 운동 설명·시연 영상·운동별 메모를 안내한다. 코치의 영상 자세 검토는 1:1 서비스 설명에서 확인된다. [GUIDE04](https://caliberstrong.com/workout-app/) [GUIDE05](https://caliberstrong.com/online-personal-trainer/) |
| 완료 후 피드백 | 2023년 릴리스 노트는 시간·평가·개인 최고기록을 담은 완료 요약을 다시 열 수 있다고 설명한다. 코칭 서비스는 주간 진행 검토와 다음 주 집중 항목을 안내한다. [GUIDE06](https://feedback.caliberstrong.com/announcements/caliber-3127-home-screen-and-calendar-revamp-activity-summaries) [GUIDE05](https://caliberstrong.com/online-personal-trainer/) |

### 미확인

무료 앱의 최초 질문 순서, 코칭 없는 사용자의 모든 가이드 접근 범위, 현재 완료 화면과 재진입 메뉴 위치는 미확인이다. GUIDE06은 **2023-12-06의 과거 업데이트 발표**로 기능 방향의 근거이며 최신 화면 실측이 아니다. 무료 기록 앱과 유료 코칭의 기능을 한 묶음으로 비교하지 않는다.

### 우리 제품 분석과 개선 제안 · 2건

1. **P1 · 운동 카드에서 트레이너의 수행 안내를 바로 연다.** 짧은 핵심 설명을 먼저 보여주고 자세한 동작·주의점·승인된 영상 링크를 펼친다. 안내는 운동 ID와 프로그램 버전에 연결한다. 현재 트레이너 등록 도구가 없으므로 운영 콘텐츠의 공급 방식과 사용 가능한 매체를 먼저 정해야 한다. 코치 채팅이나 영상 업로드는 이번 개선에 포함하지 않는다.
2. **P1 · 기존 완료 표시를 재열람 가능한 수행 요약으로 확장한다.** 현재 앱은 완료/제외 집계와 달력 재진입이 있으므로 이를 재사용한다. 필수·선택 세트의 실제 완료, 제외, 남은 기록을 구분하고 운동별 실제값과 다음 예정일을 연결한다. 기록하지 않은 시간·개인 최고기록을 만들어 넣지 않으며, 알림을 닫아도 같은 요약을 다시 볼 수 있게 한다.

## RP Hypertrophy App

### 공식 관찰

| 단계 | 공식 본문에서 확인한 사실 |
|---|---|
| 처음 시작·설정 입력 | 공식 페이지는 사전 제작 계획을 고르거나 직접 mesocycle을 구성하는 경로를 안내한다. 우선 부위를 선택해 프로그램을 만드는 기능도 소개한다. 정확한 최초 설치 순서는 미확인이다. [GUIDE07](https://rpstrength.com/pages/hypertrophy-app) |
| 개인화 설명 | 장비 간격과 수행·피드백을 바탕으로 후속 중량·반복·세트를 조절한다고 설명한다. 사용자가 세트를 수동 추가·삭제할 수도 있다. [GUIDE08](https://help.rpstrength.com/hc/en-us/articles/32600173777815-How-does-the-app-determine-when-to-add-weight-reps-and-sets) |
| 진행 분석 | 수행 저하를 감지한 경우 권고 표시를 제공하고, 사용자는 이를 따르지 않을 수 있다고 안내한다. 이 근거만으로 장기 추세 차트나 종합 분석 화면이 있다고 판단하지 않는다. [GUIDE09](https://help.rpstrength.com/hc/en-us/articles/32435171890967-If-I-get-a-flag-for-underperformance-what-do-I-do) |
| 운동 가이드 | 운동 라이브러리와 자세 영상 제공을 설명한다. [GUIDE07](https://rpstrength.com/pages/hypertrophy-app) |
| 완료 후 피드백 | 펌프·근육통·체감 운동량 피드백이 다음 운동의 구성에 영향을 준다고 설명한다. 각 질문이 나오는 정확한 시점과 필수 여부는 실기 확인하지 않았다. [GUIDE07](https://rpstrength.com/pages/hypertrophy-app) [GUIDE08](https://help.rpstrength.com/hc/en-us/articles/32600173777815-How-does-the-app-determine-when-to-add-weight-reps-and-sets) |

### 미확인

최신 프로그램 목록, 현재 온보딩 단계 수, 피드백 누락 시 동작, 추천의 개인별 타당성은 미확인이다. 공식 페이지 내 템플릿 수 표현도 일정하지 않아 숫자를 비교 지표로 채택하지 않았다. 도움말은 알고리즘 개요를 설명하며 재현 가능한 전체 엔진 명세가 아니다.

### 우리 제품 분석과 개선 제안 · 2건

1. **P1 · 기존 선택 입력인 RIR에 뜻과 사용 목적을 붙인다.** 세트 입력에서 짧은 설명을 열 수 있게 하고 트레이너 목표와 사용자가 기록한 값을 구분한다. 현재 자동 조절이 없다는 범위에서 ‘실제 수행 기록으로 보관된다’고 설명한다. 다른 앱의 펌프·근육통 설문을 필수로 추가하는 제안이 아니다.
2. **P2 · 피드백을 쓸 경우 먼저 기록과 제안을 구분한다.** 기존 메모를 완료 요약에서 다시 확인할 수 있게 하고, 이후 정책이 확정되면 변경 이유·영향 범위·사용자 수락·되돌리기를 갖춘 제안으로 설계한다. 원본과 이미 시작한 계획을 소급 변경하지 않는다. 자동 조절 정책 인터뷰 이전에는 설명 설계에 머문다.

**요구 충돌:** RP의 세트 자동 증감·사용자 임의 추가 삭제를 그대로 옮기면 트레이너 운동·세트 보존 결정과 충돌한다. 피드백 항목도 추천 계산의 전제이므로 설문만 복사하지 않는다. 이번 자료는 처방 수치·통증 대응·의학적 조언의 근거로 사용하지 않는다.

## 번핏(BurnFit)

### 공식 관찰

| 단계 | 공식 본문에서 확인한 사실 |
|---|---|
| 처음 시작·설정 입력 | 한국 App Store의 Bunnit 개발자 설명에서 루틴·운동 기록 기능은 확인된다. 최초 시작 시 묻는 정보와 입력 순서는 설명만으로 확인되지 않는다. [GUIDE10](https://apps.apple.com/kr/app/burnfit-workout-log-tracker/id1503464984) |
| 개인화 설명 | 개발자 설명은 직접 만드는 루틴, 이전 운동 불러오기와 세트 복사를 안내한다. AI 리포트도 소개하지만 개인화 계산식은 공개 설명에서 확인하지 못했다. [GUIDE10](https://apps.apple.com/kr/app/burnfit-workout-log-tracker/id1503464984) |
| 진행 분석 | 주간·월간 운동 현황, 볼륨·시간과 전월 비교를 안내한다. [GUIDE10](https://apps.apple.com/kr/app/burnfit-workout-log-tracker/id1503464984) |
| 운동 가이드 | 개발자 설명에는 GIF 가이드가 있다. 공식 한국어 웹 라이브러리의 ‘싯업’은 동작 설명·체크 항목·흔한 실수·외부 영상 링크를 나눈다. 웹 문서가 앱에서도 같은 구조인지는 미확인이다. [GUIDE10](https://apps.apple.com/kr/app/burnfit-workout-log-tracker/id1503464984) [GUIDE11](https://burnfit.io/%EB%9D%BC%EC%9D%B4%EB%B8%8C%EB%9F%AC%EB%A6%AC/%EC%8B%AF%EC%97%85/) |
| 완료 후 피드백 | 완료 직후의 요약·설문·재진입 방식은 확인하지 못했다. 주간 리포트 안내를 운동 직후 피드백 화면의 증거로 쓰지 않는다. |

### 미확인

한국 서비스의 요금제별 제공 범위, 추천·리포트 산식, 오프라인 저장과 재실행 복원, 정확한 현재 화면 경로는 미확인이다. 한국 App Store의 **개발자 작성 설명**과 한국어 공식 웹 본문만 국내 기능 근거로 삼았다. 사용자 리뷰, 영어판 설명, 별점과 홍보 성과를 한국 서비스 전체의 검증 결과로 일반화하지 않는다.

### 우리 제품 분석과 개선 제안 · 2건

1. **P1 · ‘지난 실제 기록 보기/사용’을 운동 안에 둔다.** 날짜와 운동·단위를 확인한 뒤 사용자가 선택할 때만 지난 실제 중량·반복을 현재 초안에 복사한다. 기존 초안을 보호하고 복사만으로 완료하지 않는다. 전체 운동·세트를 복제하면 원본 구성이 달라지므로 이번 앱에서는 값 재사용으로 범위를 좁힌다.
2. **P2 · 주간·월간 현황은 검증 가능한 사실부터 보여준다.** 예정 세션과 실제 수행일, 완료·제외·미기록을 구분한다. 초안은 실제 성과 집계에 포함하지 않는다. 기존 볼륨 결정은 hard set이므로 중량×반복량이나 시간과 혼용하지 않고, 완료 필수 세트 처리율을 운동 효과·프로그램 성공률로 이름 붙이지 않는다. AI 점수·피로도 추정은 별도 정책 검토 대상이다.

## 현재 제품에 적용할 핵심 5개 · 분석자의 우선순위

| 우선 | 제안 | 기존 구현에서 더할 부분 | 검증할 완료 기준 |
|---|---|---|---|
| P1 | 중량 출처를 설명하는 시작 전 확인 | 이미 있는 일정·목표 미리보기에 처방 방식·명시적 기준·장비 간격 설명 추가 | 사용자가 ‘최근 기록’과 ‘프로그램 기준’을 구분하고 입력 변경 결과를 확인한다. 원본 운동·세트는 유지된다. |
| P1 | 운동 안에서 가이드와 선택 입력 설명 | 트레이너 안내·승인된 매체 접근, RIR 설명 | 운동 카드에서 맥락을 잃지 않고 설명을 열고 닫는다. 입력 초안이 유지된다. |
| P1 | 지난 실제값을 보고 선택적으로 재사용 | 현재 목표/실제 표시 옆에 비교 날짜와 초안 복사 동작 | 초안 덮어쓰기·자동 완료·원본 변경이 없다. 첫 기록은 빈 상태다. |
| P1 | 다시 열 수 있는 완료 요약 | 기존 완료/제외 집계·달력 재진입을 운동별 결과와 다음 일정에 연결 | 제외와 실제 완료를 구분하고 필수·선택 기준을 설명한다. 재실행해도 같은 기록을 확인한다. |
| P2 | 원자료 기반 진행 분석 | 같은 운동의 실제 이력, 주간·월간 수행 현황 | 단위·날짜·비교 범위를 명시하고 초안은 제외한다. 자료 부족 상태를 숨기지 않는다. |

이 다섯 항목은 여러 앱에서 얻은 패턴을 현재 요구에 맞게 합친 **제품 가설**이다. 이미 구현된 미리보기·목표/실제 분리·초안 복원·완료 집계를 미구현으로 취급하지 않는다. 향후 UI 검증은 이해도와 입력 보존을 중심으로 하며, 경쟁 앱보다 빠르거나 효과적이라는 결론은 실측 전 내리지 않는다.

자동 운동 교체·세트 증감·임의 추정 중량·종합 근력 점수는 이번 우선 항목에 포함하지 않는다. 중량 규칙과 자동 조절은 별도 사용자 결정 및 검증 가능한 계약이 필요하다.

## 출처 등록부

모든 출처의 열람일은 **2026-09-07**이다. 수정일 미표시는 최신성을 보장한다는 뜻이 아니다. GUIDE ID는 이 조사 묶음에서 사용하는 출처 식별자다.

| ID | 앱 · 공식 페이지 제목 / URL | 종류 · 공개된 날짜 / 해석 범위 |
|---|---|---|
| GUIDE01 | Fitbod · [My Plan](https://help.fitbod.me/hc/en-us/articles/34336407191191-My-Plan) | 공식 도움말 · 수정 2026-03-03 |
| GUIDE02 | Fitbod · [Understanding Fitbod & How It Works](https://help.fitbod.me/hc/en-us/sections/360001078993-How-Fitbod-Works) | 공식 도움말 섹션의 본문 안내 · 문서별 시점 차이 가능 |
| GUIDE03 | Fitbod · [Fitbod Metrics & Records](https://help.fitbod.me/hc/en-us/articles/12732749777047-Fitbod-Metrics-Records) | 공식 도움말 · 수정 2026-01-20 |
| GUIDE04 | Caliber · [Caliber - Best Free Workout App & Gym Tracker](https://caliberstrong.com/workout-app/) | 공식 무료 앱 제품 페이지 · 수정일 미표시 |
| GUIDE05 | Caliber · [Online Personal Trainer and Online Fitness Coaches](https://caliberstrong.com/online-personal-trainer/) | 공식 **1:1 코칭 서비스** 페이지 · 수정일 미표시 |
| GUIDE06 | Caliber · [Caliber 3.1.27 - Home Screen and Calendar Revamp, Activity Summaries](https://feedback.caliberstrong.com/announcements/caliber-3127-home-screen-and-calendar-revamp-activity-summaries) | 공식 업데이트 · 게시 2023-12-06 · 과거 기능 발표 |
| GUIDE07 | RP · [RP Hypertrophy App - Bodybuilding App, Muscle Growth Workouts](https://rpstrength.com/pages/hypertrophy-app) | 공식 제품 페이지 · 수정일 미표시 |
| GUIDE08 | RP · [How does the app determine when to add weight, reps, and sets?](https://help.rpstrength.com/hc/en-us/articles/32600173777815-How-does-the-app-determine-when-to-add-weight-reps-and-sets) | 공식 도움말 · 표시일 2025-06-05 |
| GUIDE09 | RP · [If I get a flag for underperformance, what do I do?](https://help.rpstrength.com/hc/en-us/articles/32435171890967-If-I-get-a-flag-for-underperformance-what-do-I-do) | 공식 도움말 · 수정 2025-08-15 |
| GUIDE10 | 번핏 · [번핏 -헬스 & 운동일지 운동기록 운동루틴 헬스루틴](https://apps.apple.com/kr/app/burnfit-workout-log-tracker/id1503464984) | 한국 App Store · 개발자 Bunnit 작성 기능 설명만 채택 |
| GUIDE11 | 번핏 · [싯업 - 번핏 - 운동 기록이 만드는 진짜 성장](https://burnfit.io/%EB%9D%BC%EC%9D%B4%EB%B8%8C%EB%9F%AC%EB%A6%AC/%EC%8B%AF%EC%97%85/) | 공식 한국어 웹 라이브러리 · 수정일 미표시 · 콘텐츠 구조만 참고 |

공식 제품 설명의 추천·분석 기능이 존재한다는 주장과 그 기능의 정확성·훈련 효과는 구분한다. 외부 운동 설명·이미지·영상을 앱 자산으로 복사하지 않았으며, 앱에 수록할 콘텐츠와 사용 조건은 별도 결정 사항이다.
