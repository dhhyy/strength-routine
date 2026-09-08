# Strength Routine

운영자 1명이 작성한 완성 프로그램을 선택하고 운동·세트 구성을 유지한 채 중량·시작일·요일을 맞추며, 실제 운동 기록을 기기에 저장하는 Flutter 앱입니다.

- [프로젝트 개요와 문서 지도](docs/00-overview.md)
- [현재 구현·남은 작업 정본](docs/2026-09-08-remaining-work.md)
- [검토 후 안정화 명세·결과](docs/2026-09-08-review-fixes.md)
- [실제 기기 확인 자료와 절차](docs/2026-09-08-device-test-guide.md)
- [독립 랜딩 시안 5개 실행 안내](landing/concepts/README.md)

일반 앱은 `lib/main.dart`, 내부 관리자 도구는 `lib/main_admin.dart`, 합성 기기 QA는 `tool/device_qa.dart`입니다. 관리자는 별도 실행 진입점으로 배포를 제한하며 서버 계정 인증은 없습니다. 관리자·QA 산출물을 일반 사용자 앱으로 배포하지 않습니다.

현재 호스트는 macOS입니다. **[macOS 터미널 · 앱 루트]**에서 자동 검사를 실행합니다.

```sh
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
git diff --check
```

사용자 지시로 Simulator 자동 실행은 보류합니다. 파일/위젯 시험 통과와 실제 기기의 강제 종료·아이콘 재실행·OS 파일 공급자 확인은 별도로 기록합니다. 상세 문서와 기능 단위 커밋을 함께 유지합니다.
