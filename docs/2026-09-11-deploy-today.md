# 오늘 배포 체크리스트 (당신 vs 에이전트)

> 작성: 2026-09-11 · 갱신: 2026-09-12 · 목표: **GitHub Pages 스테이징 URL**

## 배포 완료

| 항목 | 상태 |
|------|------|
| 저장소 | ✅ https://github.com/dhhyy/strength-routine (**public**) |
| Actions 시크릿 | ✅ `SUPABASE_URL` / `SUPABASE_ANON_KEY` |
| Pages 배포 | ✅ [Actions run](https://github.com/dhhyy/strength-routine/actions/runs/34615154992) |
| **스테이징 URL** | **https://dhhyy.github.io/strength-routine/** |

## 당신이 할 일 (필수 · 약 2분) — 카카오 로그인용

1. **카카오 Developers** Redirect URI 확인  
   `https://wpffntuffklmzkeiycgz.supabase.co/auth/v1/callback`
2. **Supabase** → Authentication → URL Configuration  
   - **Site URL** = `https://dhhyy.github.io/strength-routine/`  
   - **Additional Redirect URLs**에 같은 주소 추가 (끝 `/` 포함)
3. (선택) 카카오 웹 플랫폼에 사이트 도메인 `dhhyy.github.io` 등록
4. 트레이너에게 [보는 법](2026-09-10-trainer-staging-how-to.md) + URL 전달

## 로컬 개발

```bash
flutter run --dart-define=AUTH_BYPASS=true --dart-define=APP_ENV=local
```
