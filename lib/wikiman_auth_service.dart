import 'dart:convert';

import 'package:http/http.dart' as http;

import 'connection_settings.dart';

class WikimanSession {
  const WikimanSession({required this.settings, required this.token});

  final ConnectionSettings settings;
  final String token;
}

class WikimanAuthException implements Exception {
  const WikimanAuthException(
    this.message, {
    this.invalidCredentials = false,
  });

  final String message;

  /// True when saved login details should not be reused for auto-login.
  final bool invalidCredentials;

  @override
  String toString() => message;
}

class WikimanAuthService {
  WikimanAuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<WikimanSession> login(ConnectionSettings settings) async {
    final normalized = settings.normalized();
    final uri = _validate(normalized);

    late http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': normalized.username,
              'password': normalized.password,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const WikimanAuthException(
        'Wikiman 서버에 연결할 수 없습니다. URL과 네트워크를 확인해 주세요.',
      );
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const WikimanAuthException('Wikiman 서버의 응답을 확인할 수 없습니다.');
    }

    if (response.statusCode != 200) {
      final code = data['error'];
      if (code == 'INVALID_CREDENTIALS') {
        throw const WikimanAuthException(
          '아이디 또는 비밀번호가 올바르지 않습니다.',
          invalidCredentials: true,
        );
      }
      throw WikimanAuthException('로그인에 실패했습니다. (${response.statusCode})');
    }

    final user = data['user'];
    final canWrite =
        user is Map<String, dynamic> &&
        (user['canWrite'] == true || user['role'] == 'writer');
    if (!canWrite) {
      throw const WikimanAuthException(
        '관리자 권한이 있는 계정만 접속할 수 있습니다.',
        invalidCredentials: true,
      );
    }

    final token = data['token'];
    if (token is! String || token.isEmpty) {
      throw const WikimanAuthException('로그인 토큰을 받지 못했습니다.');
    }

    return WikimanSession(settings: normalized, token: token);
  }

  Uri _validate(ConnectionSettings settings) {
    if (settings.url.isEmpty ||
        settings.username.isEmpty ||
        settings.password.isEmpty) {
      throw const WikimanAuthException(
        'URL, 아이디, 비밀번호를 모두 입력해 주세요.',
        invalidCredentials: true,
      );
    }

    final uri = Uri.tryParse(settings.url);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const WikimanAuthException('올바른 Wikiman URL을 입력해 주세요.');
    }
    return loginUriFor(settings.url);
  }
}
