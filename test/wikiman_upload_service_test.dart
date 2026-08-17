import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:http_parser/http_parser.dart';
import 'package:wikiman_app/connection_settings.dart';
import 'package:wikiman_app/wikiman_auth_service.dart';
import 'package:wikiman_app/wikiman_upload_service.dart';

void main() {
  test('녹음 파일을 첨부 업로드 API로 보낸다', () async {
    final tempDir = await Directory.systemTemp.createTemp('wikiman-upload-');
    final file = File('${tempDir.path}/recording.m4a');
    await file.writeAsBytes([1, 2, 3]);

    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/uploads/files');
      expect(request.headers['Authorization'], 'Bearer token');
      final text = utf8.decode(request.bodyBytes);
      expect(text, contains('filename="recording.m4a"'));
      return http.Response(
        jsonEncode({
          'files': [
            {
              'storedName': 'abc.m4a',
              'originalName': 'recording.m4a',
              'mimeType': 'audio/mp4',
              'size': 3,
              'url': '/api/files/abc.m4a',
            },
          ],
        }),
        201,
        headers: {'content-type': 'application/json'},
      );
    });

    const session = WikimanSession(
      settings: ConnectionSettings(
        url: 'https://wiki.example.com',
        username: 'admin',
        password: 'secret',
      ),
      token: 'token',
    );

    final uploaded = await WikimanUploadService(client: client).uploadFile(
      session,
      file.path,
      filename: 'recording.m4a',
      contentType: MediaType('audio', 'mp4'),
    );

    expect(uploaded['storedName'], 'abc.m4a');
    expect(uploaded['url'], '/api/files/abc.m4a');
  });
}
