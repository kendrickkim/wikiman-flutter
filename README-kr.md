[English](README.md)

# Wikiman Flutter

[Wikiman](https://github.com/kendrickkim/wikiman)을 Android와 iOS에서 사용하는 보조 앱입니다.

이미 운영 중인 Wikiman을 WebView로 열고, 휴대폰에서 공유한 글·사진·파일을
간단 포스트로 바로 보낼 수 있습니다. 위키 서버를 포함한 독립 실행형 앱은 아니며,
사이트 관리자를 위한 도구입니다.

## 주요 기능

- `writer` 권한을 확인한 뒤 Wikiman WebView에 접속
- 접속 정보를 기기 보안 저장소에 보관
- Android·iOS 공유 메뉴에서 글·이미지·파일 수신
- 공유 파일을 업로드하고 간단 포스트에 Markdown 초안 작성
- 선택한 사이트 테마에 맞춰 WebView와 시스템 상·하단 색상 적용
- 웹에서 로그아웃하면 접속 정보 화면으로 복귀

## 로컬 실행

Flutter 3.11 이상과 Android 또는 iOS 개발 환경이 필요합니다.

```bash
flutter pub get
flutter run
```

실행 중인 Wikiman 주소를 입력하고 작성자 계정으로 로그인하세요.

## 플랫폼 설정

### iOS

배포하기 전에 `Runner`와 `ShareExtension` 타깃에 같은 Development Team과
App Group을 지정해야 합니다. 공유 확장은 받은 파일을 App Group으로 복사하고,
메인 앱이 그 파일을 업로드합니다.

### 사설망 HTTP

사설망에서 운영하는 Wikiman에 접속할 수 있도록 HTTP를 허용합니다. 인터넷에
노출된 사이트에서는 HTTPS를 사용하세요.

공유 파일의 최대 크기는 **사이트 관리 → 첨부파일 → 용량 제한**을 따르며,
서버에서도 같은 값으로 검사합니다.

## 앱 아이콘

런처 아이콘과 접속 화면 로고는 프론트엔드 파비콘에서 생성합니다.

```bash
node tool/generate-app-icons.mjs
```

이 스크립트는 프론트엔드의 `public/icons/favicon.svg`와 `sharp` 패키지를
사용하므로 먼저 프론트엔드 의존성을 설치해야 합니다.

## 관련 저장소

- [Wikiman 허브](https://github.com/kendrickkim/wikiman)
- [프론트엔드](https://github.com/kendrickkim/wikiman-frontend)
- [Node 백엔드](https://github.com/kendrickkim/wikiman-backend)
- [PHP 백엔드](https://github.com/kendrickkim/wikiman-backend-php)
