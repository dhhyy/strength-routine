# 인증·가입 플로우 (2026-09-10)

## 제품 결정

| 항목 | 결정 |
|------|------|
| IdP | **카카오만** |
| 백엔드 | **Supabase Auth** (Kakao OAuth). 세션·토큰 보관이 수월함 |
| 게스트 | **없음.** 결제 전제라 가입/로그인 강제 |
| 게스트 병합 | **비범위** (생각하지 않음) |
| 온보딩 마지막 | `간단하게 가입하기` / `로그인하기` |
| 세션 | 로그인·가입 성공 시 Supabase 세션 저장. **다음 실행에 인트로/로그인 미표시** |

## 사용자 흐름

1. 앱 실행 → 유효 세션 있으면 **홈**
2. 세션 없음 → 소개 5장 → 마지막 장에서 가입 or 로그인
3. **로그인하기** → 로그인 화면 → 카카오 → 성공 시 세션 저장 → 홈
4. **간단하게 가입하기** → 약관(필수) → 카카오 → 성공 시 세션 저장 → 홈
5. 소개 중 **건너뛰기**는 홈이 아니라 **마지막 인증 허브**로만 이동

## 토스식 “부드러운 UI”

상세 디자인 원칙은 [auth-design-principles](2026-09-10-auth-design-principles.md)를 본다. 요약만 여기 둔다.

참고: [가입 화면](https://toss.tech/article/toss-signup-process), [최소 입력](https://toss.tech/article/4-ways-for-minimum-input), [인터랙션](https://toss.tech/article/interaction), TDS Agreement.

**가져올 것:** 한 화면 한 일 · 왜 한 줄 · 클릭 최소화 · 약관 필수/선택 · 짧은 easeOutCubic · CTA morph  
**가져오지 말 것:** 주민·통신사·금융 KYC·앱 PIN·역순 실명 필드 스택

## Supabase + 카카오

1. Kakao Developers: 로그인 활성화, Redirect URI = Supabase callback
2. Supabase Dashboard → Auth → Providers → Kakao ON (REST key / client secret)
3. Additional Redirect URLs에 앱 딥링크 추가  
   예: `tech.vibe.strengthroutine://login-callback`
4. 빌드 시  
   `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`

공식: https://supabase.com/docs/guides/auth/social-login/auth-kakao

## 테스트 모드 (인증 우회)

키 없이 UI·홈을 보려면:

```bash
flutter run --dart-define=AUTH_BYPASS=true
```

- 콜드 스타트 시 로컬 테스트 세션으로 **바로 홈**
- 키가 없으면 온보딩/로그인에 **「테스트로 시작 (인증 없음)」** 도 표시
- 우회 세션은 `auth-bypass-session.json`에 저장 → 다음 실행에도 유지(로그아웃 시 삭제)

실카카오는 Supabase+Kakao 콘솔 키가 준비된 뒤에만 E2E 가능.

## 비범위

- Apple/Google 로그인, 이메일·비번, 게스트, 기록 병합 UI, 실결제 SDK 연결(계정 강제만 전제)
