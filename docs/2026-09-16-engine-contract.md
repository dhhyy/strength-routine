# 2026-09-16 · 훈련 엔진 공개 계약

> 상태: 실행 중 (`engine-v1`) · 화면은 이 계약만 부른다  
> 관련: [06 실행·이력](06-engine-spec.md) · [보류 규칙](2026-09-16-deferred-scope.md) · 코드 `lib/engine/`

껍데기(Flutter 화면·웹·이후 다른 UI)는 바뀌어도 된다.  
훈련 판단은 **엔진 버전 + 명령 + 규칙 등록**으로만 바뀐다. 화면이 if로 규칙을 쌓지 않는다.

---

## 한 줄

앱은 `strengthEngine.run(명령)`만 호출한다.  
같은 입력·같은 `engine-v1`이면 같은 결과다. 저장된 계획은 새 엔진으로 몰래 다시 계산하지 않는다.

---

## 불변과 가변

| 고정(공개 계약) | 가변(추가만) |
|---|---|
| `EngineVersion.id` · 명령/결과 모양 | **새 규칙 ID** 등록 |
| 결정론 · 순수 함수 · Flutter 비의존 | 버그 수정은 **새 엔진 버전** |
| 충돌 사다리 순서 | 보류 규칙(Range 자동·코치 볼륨 표)은 숫자 오기 전 비활성 |
| 이미 저장된 계획의 스냅샷 | 화면 문구·레이아웃 |

「엔진이 바뀌면 안 된다」는 **옛 계획을 새 규칙으로 덮어쓰지 않는다**는 뜻이다.  
코드 동결이 아니다. 규칙 추가는 기존 규칙 본문을 고치지 않고 목록에 붙인다.

---

## 공개 API

```
run(EngineCommand) → EngineOutcome
```

- 입력: 명령 한 종류 + 그 명령이 필요로 하는 스냅샷(프로그램·계획·기록·설정).
- 출력: 엔진 버전, 발동한 규칙 ID·한 줄 이유, 성공 값 또는 거절 이유.
- 부작용 없음. 파일 저장·다이얼로그·컨트롤러는 앱 쪽이다.

명령 (`lib/engine/command.dart`):

| 명령 | 하는 일 | 발동 규칙 |
|---|---|---|
| `MatchTemplate` | 목표×주당일수 → 카탈로그 ID 매칭. 없으면 idle | `match_template` |
| `StartPlan` | 블록 주 수·악세 상한 적용 후 `createActivePlan` | `take_weeks`, `accessory_cap`, `start_plan` |
| `ProposeWorkingMax` | 완료 세트 → e1RM 제안. D5 살아 있으면 차단 | `live_working_max` / `conflict_recovery` |
| `ApplyWorkingMax` | 수락된 추정으로 미래 % 목표만 갱신 | `apply_working_max` |
| `InspectTrends` | 계획일순 추세 + D5 제안(적용 전) | `d5_inspect` |
| `ApplyLoadAdjustment` | D5 감량 적용 | `d5_apply` |
| `UndoLoadAdjustment` | D5 되돌리기 | `d5_undo` |
| `ReviewSchedule` | 미래 미기록 세션 날짜만 변경 | `review_schedule` |
| `PostponeSession` | 기록 없는 세션을 다음 훈련일로 | `postpone_session` |

결과:

- `EngineSuccess` — 값 있음 (`program` / `plan` / `state` / `workingMaxProposal` / `trends`)
- `EngineIdle` — 조건 미충족(매칭 없음, 제안 없음). 오류가 아님
- `EngineBlocked` — 사다리가 더 높은 규칙을 택함
- `EngineFailure` — 입력 검증 실패(메시지 그대로 화면에)

---

## 충돌 사다리 (D8)

규칙이 반대 방향을 가리키면 위가 이긴다.

1. 부상 방지  
2. 회복(피로·D5 감량)  
3. 볼륨 목표  
4. 강도 발전(working max 올리기)

`engine-v1`에서 실제로 막는 충돌은 **살아 있는 D5 감량 vs 같은 리프트 working max 제안**뿐이다.  
Range 자동 증감·같은 날 스쿼트/데드 볼륨은 표가 오기 전에는 등록하지 않는다.

---

## 버전

| 필드 | `engine-v1` |
|---|---|
| `id` | `engine-v1` |
| `policyIds` | `e1rm-epley-v1`, `d5-3x1-5pct-v1` |
| 시작 중량 | 사용자/생성기 기준 kg. 최근 기록을 자동 TM으로 쓰지 않음 |
| 구성 | 트레이너 프로그램 스냅샷 보존. 운동·세트 구조를 엔진이 새로 만들지 않음 |

운동 JSON envelope 버전(1~6)과 엔진 버전은 다르다. 새 계획은 `engineVersion: engine-v1`을 스냅샷에 박제한다. 필드가 없는 옛 계획은 `legacy`로 읽고 **다시 계산하지 않는다**. 저장 envelope는 [상태표](2026-09-08-remaining-work.md#현재-저장-계약)가 정본이다.

---

## 앱이 하지 말 것

- `createActivePlan` / `liveWorkingMaxProposal` / `withLoadAdjustment`를 **화면에서 직접** 새 호출로 늘리지 않는다. 기존 단위 시험·도메인 파일 내부는 유지한다.
- 보류 규칙 숫자를 추측해 넣지 않는다.
- 엔진 결과로 과거 세션의 실제 기록·원작 처방을 고치지 않는다.

---

## `engine-v1`에 없는 것

[일부러 안 한 항목](2026-09-16-deferred-scope.md): Range 자동, 미래 세트 수 변경, 코치 볼륨/강도 충돌 표, 보조 자유 추가.  
등록 위치는 `lib/engine/priority.dart`의 `kRegisteredRules`다. 표가 오면 **규칙 하나**로 붙인다.

---

## 이후 패키지

지금은 같은 앱의 `lib/engine`(Flutter import 없음).  
폴더를 `packages/strength_engine`으로 옮기는 것은 import 경로만 바꾸는 후속이며, 이 문서의 명령/결과/버전을 바꾸지 않는다.
