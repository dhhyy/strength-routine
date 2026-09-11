# 오늘 배포 체크리스트 (당신 vs 에이전트)

> 작성: 2026-09-11 · 목표: **스테이징 웹 URL**로 트레이너 공유

## 현재 상태 (에이전트 완료)

| 항목 | 상태 |
|------|------|
| GitHub 저장소 | ✅ https://github.com/dhhyy/strength-routine (private) |
| Actions 시크릿 `SUPABASE_URL` / `SUPABASE_ANON_KEY` | ✅ 등록됨 |
| Pages용 워크플로 `.github/workflows/staging-web.yml` | ✅ main에 푸시됨 |
| 로컬 `flutter build web` (staging defines) | ✅ `build/web` 준비 |
| GitHub Pages 실제 배포 | ❌ **막힘** — free 플랜 + **private** 저장소는 Pages 미지원 |

## 당신이 지금 고를 일 (하나만 · 배포 차단 해제)

### 옵션 A — 가장 빠름 (추천): 저장소 공개
채팅에 **`공개해`** 라고만 답하세요. 에이전트가 이어서:

1. `gh repo edit --visibility public`
2. Pages(GitHub Actions) 활성화
3. Actions 배포 실행 → URL: `https://dhhyy.github.io/strength-routine/`

소스·anon key는 클라이언트에 들어가는 값이라 공개 저장소와 맞습니다. DB는 RLS로 보호됩니다.

### 옵션 B: Firebase Hosting (비공개 유지)
터미널에서 직접:

```bash
firebase login --reauth
```

끝나면 채팅에 **`파이어베이스 로그인 됨`** 이라고 알려주세요. 에이전트가 프로젝트 생성·Hosting 배포까지 합니다.

### 옵션 C: Netlify Drop (수동 1회)
에이전트가 zip을 만들면, [Netlify Drop](https://app.netlify.com/drop)에 `build/web` zip을 올리면 됩니다.  
(카카오 redirect용 최종 URL은 Netlify가 준 주소로 Supabase에 넣습니다.)

---

## 배포 URL이 나온 뒤 (당신 · 필수 2분)

1. **카카오 Developers** Redirect URI 확인  
   `https://wpffntuffklmzkeiycgz.supabase.co/auth/v1/callback`
2. **Supabase** → Authentication → URL Configuration  
   - **Site URL** = 배포 주소 (예: `https://dhhyy.github.io/strength-routine/`)  
   - **Additional Redirect URLs**에 같은 주소 추가 (끝 `/` 포함)
3. (선택) 카카오 웹 플랫폼에 사이트 도메인 등록
4. 트레이너에게 [보는 법](2026-09-10-trainer-staging-how-to.md) + URL 전달

## 배포 후 주소 형태

- Pages(옵션 A): `https://dhhyy.github.io/strength-routine/`
- Firebase/Netlify: 콘솔이 준 HTTPS URL

실 카카오 로그인은 **시크릿이 들어간 빌드**에서만 동작합니다.
