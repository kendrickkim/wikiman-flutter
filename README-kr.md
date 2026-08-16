[English](README.md)

# Wikiman Flutter

Wikiman을 관리자 전용 WebView로 여는 Flutter 앱입니다.

백엔드와 프론트엔드는 별도 저장소입니다.

## 기능

- Wikiman URL, 관리자 아이디, 비밀번호 입력
- 로그인 API에서 `writer` 권한을 확인한 뒤에만 WebView 진입
- 접속 정보를 기기 보안 저장소에 보관하고 다음 입력 화면에 다시 표시
- 웹 로그아웃 시 접속 정보 화면으로 자동 복귀
- 앱에서만 웹 사용자 메뉴에 **접속 정보 변경** 표시
- Android·iOS 공유 메뉴에서 **Wikiman**으로 텍스트·이미지·파일 수신
- 공유 파일 업로드 후 간단 포스트 새 입력 화면에 Markdown 초안으로 전달

## 실행

```bash
flutter run
```

Android와 iOS를 지원합니다. 사설망의 HTTP Wikiman도 사용할 수 있도록
평문 HTTP 접속이 허용되어 있으므로, 외부망에서는 HTTPS 사용을 권장합니다.

공유 파일의 최대 용량은 Wikiman의 **사이트 관리 → 첨부파일 → 용량 제한**을
따르며 서버에서도 동일하게 검증합니다. iOS 배포 시 Runner와 ShareExtension
타깃에 같은 Development Team과 App Group 권한을 설정해야 합니다.
