import 'package:flutter_test/flutter_test.dart';
import 'package:wikiman_app/connection_settings.dart';

void main() {
  test('URL에 스킴을 추가하고 마지막 슬래시를 제거한다', () {
    expect(
      normalizeWikimanUrl(' wiki.example.com/// '),
      'https://wiki.example.com',
    );
    expect(normalizeWikimanUrl('http://192.168.0.10/'), 'http://192.168.0.10');
  });

  test('로그인 API URL을 만든다', () {
    expect(
      loginUriFor('https://wiki.example.com/').toString(),
      'https://wiki.example.com/api/auth/login',
    );
  });

  test('자동 로그인 플래그를 유지한 채 정규화한다', () {
    const settings = ConnectionSettings(
      url: ' wiki.example.com/ ',
      username: ' admin ',
      password: 'secret',
      autoLogin: true,
    );
    final normalized = settings.normalized();
    expect(normalized.url, 'https://wiki.example.com');
    expect(normalized.username, 'admin');
    expect(normalized.autoLogin, isTrue);
    expect(settings.canAttemptLogin, isTrue);
    expect(
      settings.copyWith(autoLogin: false).autoLogin,
      isFalse,
    );
  });
}
