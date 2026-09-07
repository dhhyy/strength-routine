# 2026-09-07 · 운동 기록 앱 확장 분석

대상: Hevy, Strong, FitNotes, Alpha Progression. 열람일: **2026-09-07 (Asia/Seoul)**.

이번 문서는 공식 페이지의 본문을 직접 열어 확인한 동작과 제품 개선 제안을 구분한다. **앱 설치·계정 로그인·실제 운동 기록 체험은 하지 않았다.** 이미지 설명이나 홍보 문구를 실제 화면 조작 결과로 취급하지 않았으며, 입력 시간·터치 횟수·오류율도 측정하지 않았다. 별점·운동 효과·알고리즘 우수성·자체 순위는 검증된 효과로 채택하지 않는다. 앱 코드는 변경하지 않았다.

기존 [기록 UX 조사](../logging.md)에 비해 **이전값의 표시와 재사용의 차이, 숫자 증감과 다음 세트 이동, 백업과 CSV의 차이, 비교 지표의 기준**을 더 구체적으로 조사했다. 아래 개선은 제안이며 사용자 확정 사항이나 구현 완료 목록이 아니다.

## 플랫폼과 확인 범위

| 앱 | 공식 자료로 확인한 범위 | 확인하지 않은 범위 |
|---|---|---|
| Hevy | iOS·Android의 진행 중 운동 표시와 알림 설정을 각각 안내한다. [LOG03](https://help.hevyapp.com/hc/en-us/articles/35649846517399-How-to-Use-Hevy-s-Live-Activity-on-iOS-and-Android) | 플랫폼별 모든 버튼의 동일 동작, 최소 OS 버전, 현재 네이티브 렌더 |
| Strong | CSV 내보내기·기록 수정·타이머 문서는 iPhone/iOS와 Android를 명시한다. [LOG05](https://help.strongapp.io/article/235-export-workout-data) [LOG06](https://help.strongapp.io/article/231-rest-timer) [LOG07](https://help.strongapp.io/article/249-how-do-i-edit-a-past-workout) | Focus Metric 문서에는 Android 6.0이 아직 ‘upcoming’으로 기재된다. 현재 Android 기능 출시 여부는 미확인. 해당 문서는 Apple Watch 미지원이라고 설명한다. [LOG04](https://help.strongapp.io/article/226-focus-metric) |
| FitNotes | 공식 홈에서 Android 전용 앱이라고 명시한다. 동명의 다른 플랫폼 앱에 이 분석을 적용하지 않는다. [LOG12](https://www.fitnotesapp.com/) | iOS 제품과의 관계, 기기별 알림 안정성, 설치 버전 |
| Alpha Progression | 운영사 글이 iOS Live Activity와 Android 진행 알림을 각각 설명한다. [LOG15](https://alphaprogression.com/en/blog/alpha-progression-vs-fitbod) | OS별 상세 입력 동작, 백업 복원·기록 수정 메뉴, 실제 기능 응답 속도 |

Strong 문서의 최종 수정일은 Focus Metric 2024-09-20, 내보내기 2021-04-27, 타이머 2021-02-08, 기록 수정 2022-02-22다. 조회일이 최신 앱 버전의 실측을 의미하지 않는다. Alpha Progression의 비교 글은 운영사가 작성한 2026-09-02 자료이며, **자사 기능 설명만 참고**하고 경쟁 앱 평가는 근거로 사용하지 않았다.

## Hevy · 지난 수행과 프로그램 기본값의 경계를 드러낸다

| 확인한 동작 | 의미와 적용 주의 |
|---|---|
| ‘이전값’은 모든 운동 또는 같은 루틴 기준으로 고를 수 있고, 이 설정만으로 현재 중량·반복 입력값이 바뀌지는 않는다. 루틴 중량·반복 갱신은 운동 저장 화면의 별도 설정이며 반복 범위가 활성화된 운동에는 갱신 예외가 있다. [LOG01](https://help.hevyapp.com/hc/en-us/articles/34105442929943-Previous-Workout-Values-Vs-Routine-Values-How-to-Adjust-in-Settings) | ‘비교할 과거’와 ‘다음에 수행할 목표’는 별도 개념이다. 우리 앱은 트레이너 원본을 유지해야 하므로 과거 기록을 표시하거나 복사하는 동작이 원본 변경으로 이어지면 안 된다. |
| 진행 표시에서 현재/다음 운동, 세트, 목표 중량·반복과 휴식을 볼 수 있고 완료 입력·휴식 조절도 안내한다. [LOG03](https://help.hevyapp.com/hc/en-us/articles/35649846517399-How-to-Use-Hevy-s-Live-Activity-on-iOS-and-Android) | 알림 허용과 OS 설정이 전제다. 앱 내 기록 확정과 외부 완료 동작이 같은 세트를 중복 기록하지 않도록 해야 한다. 우선 앱 안의 진행 표시를 완성하고 외부 알림으로 확장한다. |
| 프로필 설정의 Export & Import Data에서 운동 기록과 신체 측정값을 구분해 내보낸다. 가져오기는 영어로 내보낸 Strong CSV가 공식 지원 경로다. [LOG02](https://help.hevyapp.com/hc/en-us/articles/38001424401943-How-to-Import-Strong-App-CSV-Files-and-Export-Your-Data-in-Hevy) | CSV라는 확장자만 같아도 호환되는 것은 아니다. 우리 기록을 내보낼 때 단위·날짜·필드 정의를 명시해야 한다. |

사용자 입력 개선 제안:

1. **세트 입력에 ‘지난 기록 사용’ 추가.** 같은 프로그램·세션·운동에서 마지막으로 완료한 실제값과 날짜를 보여주고, 사용자가 누르면 현재 초안에만 복사한다. 복사만으로 완료 처리하지 않고 기존 초안이 있으면 유지한다. 목표·지난 기록·이번 입력을 별도로 표시한다. LOG01에서 경계 원칙을 가져온 제안이며 Hevy의 동일 버튼 존재를 주장하지 않는다.
2. **운동 중 현재 위치를 고정 표시.** 현재 운동·세트와 ‘다음 세트’를 작은 영역에서 유지한다. 휴식 시간이 정의된 뒤에는 그 영역에서 타이머 조절·건너뛰기를 제공한다. 잠금화면 입력은 후속 단계로 둔다. [LOG03](https://help.hevyapp.com/hc/en-us/articles/35649846517399-How-to-Use-Hevy-s-Live-Activity-on-iOS-and-Android)

## Strong · 비교 지표를 좁히고 기록을 다시 고칠 수 있게 한다

| 확인한 동작 | 의미와 적용 주의 |
|---|---|
| Focus Metric은 운동마다 볼륨·반복·시간·거리 중 해당 운동에 맞는 지표를 골라 이전 수행과 비교한다. [LOG04](https://help.strongapp.io/article/226-focus-metric) | 한 화면에 지표를 모두 넣지 않고 그 운동에서 볼 기준 하나를 선택하는 패턴이다. 계획된 디로딩이나 반복 구성 변화 때문에 숫자가 줄 수도 있으므로 감소를 실패 판정으로 만들지 않는다. |
| 세트 완료에서 자동 휴식이 시작되고, 작은 타이머를 펼쳐 시간 수정·건너뛰기를 할 수 있다. 운동별 설정에서 워밍업과 일반 세트의 시간을 구분한다. [LOG06](https://help.strongapp.io/article/231-rest-timer) | 우리 프로그램 정의에 휴식·세트 유형이 추가돼야 그대로 적용할 수 있다. 경쟁사의 기본 시간을 훈련 처방으로 복사하지 않는다. |
| 과거 운동은 History의 해당 항목에서 Edit Workout에 들어가 수정 후 Save한다. [LOG07](https://help.strongapp.io/article/249-how-do-i-edit-a-past-workout) | 운동 완료가 기록 수정 불가를 의미하지 않는다. 수정 이력과 프로그램 버전 보존은 별도 설계가 필요하다. |
| iOS·Android 설정에서 CSV를 내보내지만 그 파일을 Strong으로 다시 가져올 수는 없다고 명시한다. [LOG05](https://help.strongapp.io/article/235-export-workout-data) | 내보내기를 ‘백업 완료’라고 안내하면 안 된다. 기기 교체용 복원 파일과 분석용 CSV를 구분해야 한다. |

사용자 입력 개선 제안:

1. **세트 입력 아래에 비교 기준 하나만 선택적으로 표시.** 예를 들어 동일 반복에서의 지난 실제 중량을 먼저 보여주고, 상세에서 총 반복·완료 세트 수를 펼친다. 첫 기록에는 비교 수치를 만들지 않는다. 특정 지표 선택 패턴은 [LOG04](https://help.strongapp.io/article/226-focus-metric)에서 참고했다.
2. **보관된 프로그램의 실제 기록도 같은 편집기로 정정.** 현재 활성 계획과 관계없이 수행 기록을 고칠 수 있게 하되 원본 세트 구성·목표는 보존한다. 저장 취소와 실패 시 이전 값·작성 중 값을 각각 유지하고, 수정 날짜를 남긴다. [LOG07](https://help.strongapp.io/article/249-how-do-i-edit-a-past-workout)

## FitNotes · 반복 입력과 이동을 줄이는 구체적인 조작

| 확인한 동작 | 의미와 적용 주의 |
|---|---|
| 운동 화면은 이전 운동 첫 세트의 값을 입력란에 채우고, 키보드 또는 증감 버튼으로 수정한다. 기존 세트를 선택하면 해당 값을 불러오면서 Save가 Update/Delete로 바뀐다. [LOG08](https://www.fitnotesapp.com/workout_tracking/) | 새 기록과 수정의 맥락을 명확히 바꾸는 패턴이다. 우리 앱에서는 무조건 자동 채우기보다 사용자가 고르는 재사용 동작이 초안·실제값의 혼동을 줄인다. |
| 사전 생성한 루틴에서는 다음 세트를 자동 선택할 수 있다. 전체 증량 단위와 운동별 증량 단위를 구분한다. [LOG10](https://www.fitnotesapp.com/settings/) | 트레이너의 세트 목록을 유지하면서 현재 편집 대상만 이동할 수 있다. 숨겨진 자동 완료로 바꾸면 안 된다. |
| History에서 과거 날짜의 세트 묶음 또는 특정 세트를 편집·복사할 수 있다. 그래프는 최대 중량, 총 반복, 볼륨, 특정 반복수에서의 중량 등 기준을 나눈다. [LOG09](https://www.fitnotesapp.com/progress_tracking/) | 전체 운동 복제가 필요하지 않아도 지난 실제 세트값만 가져올 수 있다. 같은 운동·단위·비교 조건을 먼저 정해야 한다. |
| 휴식은 이전 시간을 기억하거나 운동별 기본 시간을 사용한다. 자동 시작은 세트 생성 또는 완료 체크 설정에 따라 달라진다. [LOG13](https://www.fitnotesapp.com/workout_tools/) | 우리 앱의 ‘입력 초안 저장’에서는 타이머를 시작하지 않고 ‘실제 세트 완료’를 트리거로 삼는 것이 적합하다. |
| Settings는 복원 가능한 전용 백업과 복원 불가능한 분석용 CSV를 구분한다. 복원은 기존 기기 데이터를 덮어쓴다고 안내한다. [LOG10](https://www.fitnotesapp.com/settings/) v25는 Android 기본 Google One 백업 지원을 추가하고 기존 자체 자동 백업은 향후 제거될 수 있다고 설명한다. [LOG11](https://www.fitnotesapp.com/release_25/) | 오래된 Settings의 자체 백업 방식만 보고 현재 권장 경로라고 단정하지 않는다. OS 자동 백업도 우리 앱의 기록 저장 성공을 대신하지 않는다. |

사용자 입력 개선 제안:

1. **중량 증감 버튼 추가.** 키보드 입력과 함께 `− / +`를 제공하고 장비 최소 증량 단위를 적용한다. kg/lb와 장비 단위가 다를 때의 정책은 별도로 정하며, 단위를 바꾸는 것과 중량을 환산하는 동작을 섞지 않는다. [LOG08](https://www.fitnotesapp.com/workout_tracking/) [LOG10](https://www.fitnotesapp.com/settings/)
2. **‘저장하고 다음 세트’ 추가.** 저장 성공 후 트레이너가 정한 순서의 다음 미기록 세트로 편집 대상을 옮긴다. 저장 실패 시 현재 입력을 유지하고 이동하지 않는다. 사용자가 자유롭게 다른 세트를 고르는 경로는 유지한다. [LOG10](https://www.fitnotesapp.com/settings/)

## Alpha Progression · 입력과 제안을 함께 보되 필요한 것만 받는다

| 확인한 동작 | 의미와 적용 주의 |
|---|---|
| 공식 제품 페이지는 수행 기록을 기반으로 세트별 중량·반복·강도 목표를 제안한다고 설명한다. 진행 정보로 중량·strength rating·볼륨 그래프, PR, CSV 내보내기를 안내한다. [LOG14](https://alphaprogression.com/en) | ‘제안 기능이 있다’는 자사 설명을 확인한 것이며 정확도나 운동 효과를 검증한 결과가 아니다. 자체 strength rating의 계산식·우리 데이터와의 호환은 미확인이다. |
| 운영사 글은 운동 중 지난 수행·현재 권장값·완료 세트·휴식 타이머를 함께 확인할 수 있고, iOS Live Activity/Android 진행 알림도 제공한다고 설명한다. RIR 입력 없이도 권장값이 동작한다고 적는다. [LOG15](https://alphaprogression.com/en/blog/alpha-progression-vs-fitbod) | 선택적 상세 입력과 핵심 기록을 분리하는 패턴이다. 해당 글의 경쟁 앱 평가와 운동 효과 주장, 순위는 채택하지 않는다. CSV 메뉴의 정확한 경로와 완료된 세트 정정 동작은 미확인이다. |

사용자 입력 개선 제안:

1. **RIR·메모를 필요할 때 펼치기.** 중량·반복과 완료를 기본 입력으로 유지하고, 목표 RIR이 있는 세트에는 RIR을 바로 표시한다. 그 외에는 추가 기록 영역으로 제공한다. 기존 작성값은 접어도 보존한다. 이는 [LOG15](https://alphaprogression.com/en/blog/alpha-progression-vs-fitbod)의 선택적 RIR 패턴을 바탕으로 한 우리 앱의 제안이다.
2. **향후 개인화 제안은 수락 전 실제 기록으로 넣지 않기.** 트레이너 목표와 지난 실제 수행을 먼저 보여주고, 알고리즘이 확정된 뒤 ‘제안 사용’으로 초안에 적용한다. 제안의 계산 근거·버전을 추적하고 원본 세트 구성을 유지한다. [LOG14](https://alphaprogression.com/en)

## 우리 앱에서 우선 검토할 5개

| 우선 검토 | 예상 사용자 이득 — 실측 전 가설 | 제안 완료 기준 |
|---|---|---|
| 지난 실제 세트값 보기·선택 복사 | 매번 중량과 반복을 기억해 다시 입력하는 부담 감소 | 비교 날짜·프로그램 범위 표시, 초안 보호, 복사와 완료 분리. LOG01·LOG09 |
| 다음 미기록 세트로 이동 | 세트마다 시트를 닫고 목록에서 다시 찾는 동작 감소 | 저장 성공에서만 이동, 실패 시 현재 화면 유지. LOG10 |
| 장비 단위에 맞춘 숫자 증감 | 작은 중량 변경 때 키보드 재입력 감소 | 단위 일치, 음수 방지, 입력 직후 초안 복원. LOG08·LOG10 |
| 분석용 CSV와 복원용 백업 구분 | 기록을 장기간 쌓을 때 다른 도구·기기로 가져갈 수 있음 | 파일 포맷·단위·버전 설명, 복원 전 검사와 데이터 보존. LOG02·LOG05·LOG10·LOG11 |
| 진행 지표를 1개씩 명확하게 표시 | 숫자를 보고 무엇을 비교하는지 이해 가능 | 같은 운동·단위·조건, 실제/추정 구분, 첫 기록 빈 상태. LOG04·LOG09 |

실행 전에는 실기기에서 **세트 완료까지 터치 수, 키보드 재호출, 값 정정 성공, 복원 후 초안·완료 상태 보존**을 비교한다. 이 문서의 제안이 입력을 더 빠르게 만든다는 결론은 그 측정 후에 내린다. 타이머는 프로그램 휴식 정의와 OS 알림 검증이 필요하므로 이 다섯 항목과 별도 범위로 산정한다.

## 출처 등록부

모든 항목은 2026-09-07에 본문을 직접 열었다. 아래 ID는 이 문서 내부 인용 식별자다.

| ID | 앱 · 정확한 페이지 제목 / URL | 근거 종류 |
|---|---|---|
| LOG01 | Hevy · [Previous Workout Values Vs. Routine Values: How to Adjust in Settings?](https://help.hevyapp.com/hc/en-us/articles/34105442929943-Previous-Workout-Values-Vs-Routine-Values-How-to-Adjust-in-Settings) | 공식 도움말 |
| LOG02 | Hevy · [How to Import Strong App CSV Files and Export Your Data in Hevy](https://help.hevyapp.com/hc/en-us/articles/38001424401943-How-to-Import-Strong-App-CSV-Files-and-Export-Your-Data-in-Hevy) | 공식 도움말 |
| LOG03 | Hevy · [How to Use Hevy’s Live Activity on iOS and Android](https://help.hevyapp.com/hc/en-us/articles/35649846517399-How-to-Use-Hevy-s-Live-Activity-on-iOS-and-Android) | 공식 도움말 |
| LOG04 | Strong · [About Focus Metric](https://help.strongapp.io/article/226-focus-metric) | 공식 도움말 · 수정 2024-09-20 |
| LOG05 | Strong · [Can I export my workout data?](https://help.strongapp.io/article/235-export-workout-data) | 공식 도움말 · 수정 2021-04-27 |
| LOG06 | Strong · [About Rest Timer](https://help.strongapp.io/article/231-rest-timer) | 공식 도움말 · 수정 2021-02-08 |
| LOG07 | Strong · [How do I edit a past workout?](https://help.strongapp.io/article/249-how-do-i-edit-a-past-workout) | 공식 도움말 · 수정 2022-02-22 |
| LOG08 | FitNotes · [Workout Tracking](https://www.fitnotesapp.com/workout_tracking/) | 공식 도움말 |
| LOG09 | FitNotes · [Progress Tracking](https://www.fitnotesapp.com/progress_tracking/) | 공식 도움말 |
| LOG10 | FitNotes · [Settings](https://www.fitnotesapp.com/settings/) | 공식 도움말 |
| LOG11 | FitNotes · [Version 25](https://www.fitnotesapp.com/release_25/) | 공식 릴리스 노트 |
| LOG12 | FitNotes · [FitNotes - Gym Workout Log App](https://www.fitnotesapp.com/) | 공식 제품 페이지 |
| LOG13 | FitNotes · [Workout Tools](https://www.fitnotesapp.com/workout_tools/) | 공식 도움말 |
| LOG14 | Alpha Progression · [Alpha Progression · Gym Tracker & Workout Planner](https://alphaprogression.com/en) | 공식 제품 페이지 |
| LOG15 | Alpha Progression · [Alpha Progression vs Fitbod: Which Is Best? (2026)](https://alphaprogression.com/en/blog/alpha-progression-vs-fitbod) | 운영사 작성 비교 글 · 자사 기능만 채택 · 게시 2026-09-02 |
