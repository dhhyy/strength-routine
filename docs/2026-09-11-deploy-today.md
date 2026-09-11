# 오늘 배포 체크리스트 (당신 vs 에이전트)

> 작성: 2026-09-11 · 목표: **GitHub Pages 스테이징 URL**로 트레이너 공유

## 에이전트가 하는 일
- [x] Pages용 GitHub Actions 워크플로
- [x] 웹용 카카오 redirect (`Uri.base`)
- [ ] GitHub 저장소 생성·푸시·시크릿 등록·Pages 배포 트리거 (실행 중)

## 당신이 할 일 (배포 직후·필수)

1. **카카오 Developers** Redirect URI에 Supabase 콜백이 있는지 확인  
   `https://wpffntuffklmzkeiycgz.supabase.co/auth/v1/callback`
2. 배포 URL이 나오면 **Supabase** → Authentication → URL Configuration  
   - Site URL = Pages 주소  
   - Additional Redirect URLs에 Pages 주소(끝 `/` 포함) 추가  
3. 트레이너에게 [보는 법](2026-09-10-trainer-staging-how-to.md) + URL 전달  
4. (선택) 카카오 웹 플랫폼에 사이트 도메인 등록이 필요하면 Developers에서 추가

## 배포 후 주소 형태
`https://<github-user>.github.io/<repo>/`

실 카카오 로그인은 **시크릿이 Actions에 들어간 빌드**에서만 동작합니다.
