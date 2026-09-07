# 9/7 오프라인 폰트 번들

날짜: 2026-09-07. 기존 앱의 **IBM Plex Sans KR / IBM Plex Mono** 선택을 유지하면서 런타임 폰트 다운로드에 의존하지 않도록 공식 정적 TTF 8개를 준비했다. 시스템에 폰트를 설치하지 않았고 폰트 바이너리를 수정하거나 서브셋으로 재가공하지 않았다.

## 공식 출처와 고정 버전

- 원본 저장소: [google/fonts](https://github.com/google/fonts).
- 다운로드를 고정한 커밋: [`5e35378e6bda803962ee6fd257e444a7d459660d`](https://github.com/google/fonts/commit/5e35378e6bda803962ee6fd257e444a7d459660d), 커밋 시간 2026-09-04T18:48:05Z.
- [IBM Plex Sans KR 디렉터리](https://github.com/google/fonts/tree/5e35378e6bda803962ee6fd257e444a7d459660d/ofl/ibmplexsanskr) 및 [공식 메타데이터](https://raw.githubusercontent.com/google/fonts/5e35378e6bda803962ee6fd257e444a7d459660d/ofl/ibmplexsanskr/METADATA.pb).
- [IBM Plex Mono 디렉터리](https://github.com/google/fonts/tree/5e35378e6bda803962ee6fd257e444a7d459660d/ofl/ibmplexmono) 및 [공식 메타데이터](https://raw.githubusercontent.com/google/fonts/5e35378e6bda803962ee6fd257e444a7d459660d/ofl/ibmplexmono/METADATA.pb).
- 파일은 해당 커밋의 `raw.githubusercontent.com/google/fonts/<commit>/ofl/<family>/<filename>`에서 내려받았다. HTTP 오류 시 실패하는 `curl --fail`을 사용했고 모든 요청이 성공했다.

## 파일과 Flutter 등록

앱 루트 기준 경로다. 모든 스타일은 normal이며, 파일 내부 OS/2 테이블의 weight와 공식 METADATA가 일치한다.

| Flutter family | weight | 로컬 파일 |
|---|---:|---|
| IBM Plex Sans KR | 400 | `assets/fonts/IBMPlexSansKR-Regular.ttf` |
| IBM Plex Sans KR | 500 | `assets/fonts/IBMPlexSansKR-Medium.ttf` |
| IBM Plex Sans KR | 600 | `assets/fonts/IBMPlexSansKR-SemiBold.ttf` |
| IBM Plex Sans KR | 700 | `assets/fonts/IBMPlexSansKR-Bold.ttf` |
| IBM Plex Mono | 400 | `assets/fonts/IBMPlexMono-Regular.ttf` |
| IBM Plex Mono | 500 | `assets/fonts/IBMPlexMono-Medium.ttf` |
| IBM Plex Mono | 600 | `assets/fonts/IBMPlexMono-SemiBold.ttf` |
| IBM Plex Mono | 700 | `assets/fonts/IBMPlexMono-Bold.ttf` |

[Flutter 공식 커스텀 폰트 안내](https://docs.flutter.dev/cookbook/design/fonts)에 따라 `pubspec.yaml`의 기존 `flutter:` 아래에 `fonts:`를 추가하고, 기존 토큰이 같은 family 이름을 참조하게 한다. 예시는 다음과 같다. 실제 pubspec/테마 통합은 루트 에이전트 작업 범위다.

```yaml
flutter:
  fonts:
    - family: IBM Plex Sans KR
      fonts:
        - asset: assets/fonts/IBMPlexSansKR-Regular.ttf
          weight: 400
        - asset: assets/fonts/IBMPlexSansKR-Medium.ttf
          weight: 500
        - asset: assets/fonts/IBMPlexSansKR-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/IBMPlexSansKR-Bold.ttf
          weight: 700
    - family: IBM Plex Mono
      fonts:
        - asset: assets/fonts/IBMPlexMono-Regular.ttf
          weight: 400
        - asset: assets/fonts/IBMPlexMono-Medium.ttf
          weight: 500
        - asset: assets/fonts/IBMPlexMono-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/IBMPlexMono-Bold.ttf
          weight: 700
```

한글 텍스트는 Sans KR, 라틴·숫자는 Mono 토큰을 유지한다. 필요할 경우 Mono 스타일에 Sans KR을 `fontFamilyFallback`으로 둔다. GoogleFonts API의 런타임 다운로드 호출을 끄는 것만으로 로컬 family 참조 전환을 대체하지 않는다.

## 라이선스 동봉

- [원본 Sans KR OFL](https://raw.githubusercontent.com/google/fonts/5e35378e6bda803962ee6fd257e444a7d459660d/ofl/ibmplexsanskr/OFL.txt) → `assets/fonts/OFL-IBMPlexSansKR.txt`.
- [원본 Mono OFL](https://raw.githubusercontent.com/google/fonts/5e35378e6bda803962ee6fd257e444a7d459660d/ofl/ibmplexmono/OFL.txt) → `assets/fonts/OFL-IBMPlexMono.txt`.
- 두 원본은 같은 내용의 **SIL Open Font License 1.1**이며, IBM의 저작권 고지와 reserved font name `Plex`를 포함한다. 파일 내용과 줄바꿈을 그대로 보존했다.
- OFL에 기재된 소프트웨어 번들 조건에 따라 저작권 고지와 라이선스를 배포물에 포함해야 한다. 두 라이선스 파일을 Flutter assets로 등록하고 앱의 오픈소스 라이선스 화면에서 읽을 수 있도록 연결하는 방식을 권장한다. 이 문서만 저장했다고 앱 내 라이선스 표시가 구현되는 것은 아니다.

## 무결성 검증

다운로드된 8개 파일은 TrueType 헤더 및 테이블 범위 검사를 통과했고, `fvar` 테이블이 없어 variable font가 아닌 정적 폰트임을 확인했다. Sans KR 4개는 현대 한글 음절 U+AC00–U+D7A3 총 11,172자 전부에 cmap glyph가 있으며, 8개 모두 ASCII 영문 대소문자와 숫자 glyph가 존재한다. 이 검사는 glyph 존재를 확인한 것이며 실제 Flutter 렌더 검증은 통합 이후 별도로 수행한다.

파일 내부 버전: Sans KR `Version 1.001`, Mono `Version 2.3`. 총 크기는 라이선스를 포함해 **11,953,360 bytes (약 11.4 MiB)**다.

| 파일 | SHA-256 |
|---|---|
| IBMPlexSansKR-Regular.ttf | `53750379270312368cf7641901f43a98dd892e3d9d5798cf25cdc245c85c71c0` |
| IBMPlexSansKR-Medium.ttf | `4a7130f56ce50bf10f9d383f624e50bad2c80bebc63e51f4269ece2c7d919166` |
| IBMPlexSansKR-SemiBold.ttf | `823c1956adf56c27c06b062725dfce23f266e4fd1366290f2957c8407482a817` |
| IBMPlexSansKR-Bold.ttf | `9d82a8be5330f6d7b53121262867b402baca672eb69b852928f06d185d357f7d` |
| IBMPlexMono-Regular.ttf | `6a3412f058c7d8dfd9170c41e85ade48e5156ecb89356110ca57a0a27734af46` |
| IBMPlexMono-Medium.ttf | `a9b4c49bb299e05b5f6c481e7fb5e78943d2793249a0c8874ab574a2d1ea6755` |
| IBMPlexMono-SemiBold.ttf | `d3c38e55c78f5b0f28009fddba4834ec503278936a5986032424c9bd2d23aa46` |
| IBMPlexMono-Bold.ttf | `ac27abd6450a64dd94467580a02fe6235156d5b92f2926ebbc8e7489df64e0be` |
| OFL-IBMPlexSansKR.txt | `7e6b2818edbd8f6a01ae80641cc8f16a51080d08fb4e532be3a0b6f74adb07da` |
| OFL-IBMPlexMono.txt | `7e6b2818edbd8f6a01ae80641cc8f16a51080d08fb4e532be3a0b6f74adb07da` |
