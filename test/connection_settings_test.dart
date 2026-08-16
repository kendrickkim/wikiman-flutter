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
}
