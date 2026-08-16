import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wikiman_app/connection_settings.dart';
import 'package:wikiman_app/wikiman_auth_service.dart';

const _settings = ConnectionSettings(
  url: 'https://wiki.example.com',
  username: 'admin',
  password: 'secret',
);

void main() {
  test('관리자 로그인만 허용한다', () async {
    final service = WikimanAuthService(
      client: MockClient((request) async {
        expect(request.url.path, '/api/auth/login');
        expect(jsonDecode(request.body)['username'], 'admin');
        return http.Response(
          jsonEncode({
            'token': 'jwt-token',
            'user': {'role': 'writer', 'canWrite': true},
          }),
          200,
        );
      }),
    );

    final session = await service.login(_settings);
    expect(session.token, 'jwt-token');
  });

  test('읽기 전용 계정은 거부한다', () async {
    final service = WikimanAuthService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'token': 'reader-token',
            'user': {'role': 'reader', 'canWrite': false},
          }),
          200,
        ),
      ),
    );

    await expectLater(
      service.login(_settings),
      throwsA(
        isA<WikimanAuthException>().having(
          (error) => error.message,
          'message',
          contains('관리자'),
        ),
      ),
    );
  });
}
