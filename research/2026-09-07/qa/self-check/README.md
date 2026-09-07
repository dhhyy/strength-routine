# 9/7 자체 검증 증거

- 실행 환경: macOS / zsh, Flutter 3.32.1, Dart 3.8.1.
- 기준 소스: `aeea479`, 날짜 수정: `b813d85` / `46ef544`.
- `baseline-*.txt`: 수정 전 전체 회귀/정적 분석의 실제 명령 출력.
- `habits-tab-before.txt` / `habits-tab-after.txt`: 새 탭 복귀 회귀의 수정 전 실패/수정 후 통과; 도구 출력 transcript를 보존했음을 파일에 표시했다.
- `program-date-before.txt` / `program-date-after.txt`: 날짜 선택기 두 경계의 수정 전 assertion 및 수정 후 해당 테스트 파일 전체 통과.
- `final-*.txt`: 두 수정 후 최종 전체 회귀/정적 분석 출력.
- Git 공백 검사를 위해 줄 끝 공백만 제거했다. 실패 로그는 수정 전 결함의 증거이며 최종 회귀 실패로 해석하지 않는다.
- 실제 사용자 데이터·시뮬레이터 조작·OS 종료/재실행 검증은 포함하지 않는다.

명령·개수·해석은 [상세 검증 보고서](../../../../docs/2026-09-07-verification.md)를 따른다.
