# 스테이징·백엔드·지속 배포 (지금부터)

> 작성: 2026-09-10  
> 목표: **스토어 없이** 서버(스테이징)에 올려 두고, 트레이너와 **링크·빌드로 계속 공유**  
> 전제: 지금 앱은 기기 로컬 저장이 중심. 서버는 **새로 붙인다.**

---

## 0. 쉬운 한 줄

| 역할 | 할 일 |
|---|---|
| **당신(제품)** | Supabase·호스팅 계정 만들기, 비밀키 넣기 |
| **앱** | 스테이징 빌드 → 웹(또는 설치 파일)로 올림 |
| **서버(Supabase)** | 로그인 + (다음) 기록 동기화 저장소 |
| **트레이너** | 스테이징 링크로 확인·피드백 |

스토어 심사는 **나중**. 지금은 “같이 보는 개발 서버”입니다.

---

## 1. 목표 그림

```text
[개발자 Mac]
   │  push / 수동 실행
   ▼
[GitHub Actions] ── flutter build web ──► [스테이징 호스팅]
                                              │
                                              ▼
                                    트레이너가 URL로 열어 봄

[앱 / 웹] ── 카카오 로그인 ──► [Supabase Auth]
         ── (다음 단계) 기록 JSON ──► [Supabase DB]
```

**1단계(지금 골격):** 웹 스테이징 빌드 + Supabase 프로젝트 뼈대 + 배포 워크플로  
**2단계:** 카카오 실연동  
**3단계:** 운동 기록·working max를 서버에 저장/복원  
**4단계:** (선택) Android APK / iOS TestFlight 내부 배포

---

## 2. 왜 웹 스테이징부터인가

- 스토어·서명 없이 **URL 하나**로 트레이너와 공유 가능  
- 이미 `web/` 폴더와 `supabase_flutter`가 있음  
- 네이티브 전용(카카오 SDK·파일 경로)은 웹에서 제한될 수 있음 → **로그인·루틴 미리보기**부터 맞추고, 무거운 네이티브는 APK/시뮬로 보완

트레이너가 **아이폰 실기기 감**이 꼭 필요하면 2트랙:

1. 웹 = 빠른 공유  
2. later: Firebase App Distribution / TestFlight

---

## 3. 당신이 만들 계정 (체크)

- [ ] **Supabase** 프로젝트 1개 (`staging` 권장 이름)  
- [ ] **카카오 Developers** 앱 + 로그인 (Supabase 콜백 URL 등록)  
- [ ] **호스팅** 하나 선택  
  - 추천 기본: **Cloudflare Pages** 또는 **Firebase Hosting**  
  - GitHub 저장소가 있으면 **GitHub Pages**도 가능  
- [ ] GitHub 저장소 + Actions 시크릿  
  - `SUPABASE_URL`  
  - `SUPABASE_ANON_KEY`  
  - (호스팅용) 배포 토큰

이 저장소에는 **비밀키를 커밋하지 않습니다.**

---

## 4. 이 저장소에 넣어 둔 것

| 경로 | 역할 |
|---|---|
| `supabase/migrations/` | DB 초기 스키마 (프로필·기록 스냅샷 자리) |
| `supabase/config.toml` | 로컬/CLI용 Supabase 설정 뼈대 |
| `.github/workflows/staging-web.yml` | `main` push 또는 수동 → Flutter web 빌드 아티팩트 |
| `lib/app/app_environment.dart` | `APP_ENV=staging` 등 환경 구분 |
| [트레이너용 한 장](2026-09-10-trainer-staging-how-to.md) | 공유할 때 쓰는 쉬운 안내 |

---

## 5. 백엔드 범위 (지금 / 다음)

### 지금(마이그레이션에 포함)

- `profiles` — 로그인한 사용자 한 줄  
- `training_snapshots` — 운동 상태 JSON 통째 백업 자리 (앱 연결은 **다음 PR**)  
- `working_max_snapshots` — working max JSON 자리  
- RLS: **본인 행만** 읽기/쓰기

### 일부러 아직 안 함

- 게시판·댓글  
- 결제 entitlement  
- 실시간 presence  
- 관리자 원격 프로그램 CMS (지금은 JSON/내부 관리자 빌드)

### 앱 연결 순서 (다음 작업)

1. `SUPABASE_URL` / `ANON_KEY`로 **실 카카오 로그인**만 스테이징에서 확인  
2. 로컬 `training-state.json` ↔ `training_snapshots.payload` **수동 동기화 버튼**  
3. 자동 동기화·충돌 정책 (마지막 쓰기 우선 등)

로컬 파일 계약을 깨지 않고, **서버는 거울**부터 가는 편이 안전합니다.

---

## 6. 로컬에서 바로 쓰는 명령

```bash
# 스테이징 정의로 웹 실행 (키는 본인 값)
flutter run -d chrome \
  --dart-define=APP_ENV=staging \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...

# 웹 릴리스 빌드
flutter build web --release \
  --dart-define=APP_ENV=staging \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

Supabase CLI가 있으면:

```bash
supabase link --project-ref <project-ref>
supabase db push
```

---

## 7. 이번 주 할 일 (제안 순서)

1. Supabase 프로젝트 생성 → Dashboard URL/anon key 복사  
2. `supabase db push` (또는 SQL 에디터에 마이그레이션 붙여넣기)  
3. 카카오 로그인 Provider ON  
4. GitHub 시크릿 등록 후 Actions로 web 빌드 확인  
5. 호스팅에 `build/web` 올리고 트레이너에게 URL + [한 장 안내](2026-09-10-trainer-staging-how-to.md) 전달  
6. 그다음 PR: 스냅샷 업로드/다운로드 UI

---

## 9. 현재 스테이징 프로젝트 (자동 생성)

| 항목 | 값 |
|---|---|
| 이름 | `strength-routine-staging` |
| ref | `wpffntuffklmzkeiycgz` |
| 리전 | `ap-northeast-2` (서울) |
| Dashboard | https://supabase.com/dashboard/project/wpffntuffklmzkeiycgz |
| API URL | `https://wpffntuffklmzkeiycgz.supabase.co` |
| 마이그레이션 | `20260910120000_init_staging.sql` 적용됨 |
| 로컬 키 파일 | `.local/staging.env` (gitignore, 커밋 금지) |

카카오 Provider는 **활성화됨** (2026-09-11). REST API key + Client Secret을 Dashboard Auth에 push함.  
카카오 콘솔 Redirect URI: `https://wpffntuffklmzkeiycgz.supabase.co/auth/v1/callback`  
키 원본은 `.local/kakao.env` (gitignore).

---

## 8. 성공 기준 (스토어 전)

- [ ] 트레이너가 **북마크한 URL**로 최신 스테이징을 연다  
- [ ] 당신은 push(또는 Actions 수동)만으로 **다시 배포**한다  
- [ ] 스테이징에서 **실 카카오 로그인**이 된다 (우회 아님)  
- [ ] (다음) 같은 계정으로 기록 스냅샷이 서버에 남는다  

이 네 가지면 “서버에 올려 놓고 계속 공유”의 최소 형태입니다.
