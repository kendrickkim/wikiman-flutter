import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:share_intent_package/share_intent_package.dart';
import 'package:wikiman_app/connection_settings.dart';
import 'package:wikiman_app/share_upload_service.dart';
import 'package:wikiman_app/wikiman_auth_service.dart';

void main() {
  test('공유 텍스트를 간단 포스트 초안으로 만든다', () async {
    const session = WikimanSession(
      settings: ConnectionSettings(
        url: 'https://wiki.example.com',
        username: 'admin',
        password: 'secret',
      ),
      token: 'token',
    );

    final draft = await ShareUploadService().createDraft(
      session,
      const SharedData(text: '공유한 문장\nhttps://example.com'),
    );

    expect(draft, '공유한 문장\nhttps://example.com');
  });

  test('HEIC 공유 파일은 PNG로 변환한 뒤 업로드한다', () async {
    final tempDir = await Directory.systemTemp.createTemp('wikiman-heic-');
    final heic = File('${tempDir.path}/photo.heic');
    final png = File('${tempDir.path}/photo.png');
    await heic.writeAsBytes([0, 1, 2]);
    await png.writeAsBytes([9, 8, 7]);

    String? uploadedName;
    String? uploadedContentType;

    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/uploads/files');
      expect(request.headers['Authorization'], 'Bearer token');

      final body = request.bodyBytes;
      final text = utf8.decode(body);
      final nameMatch = RegExp(
        r'filename="([^"]+)"',
      ).firstMatch(text);
      final typeMatch = RegExp(
        r'Content-Type:\s*([^\r\n]+)',
        caseSensitive: false,
      ).firstMatch(text);
      uploadedName = nameMatch?.group(1);
      uploadedContentType = typeMatch?.group(1)?.trim();

      return http.Response(
        jsonEncode({
          'files': [
            {'url': '/api/files/converted.png'},
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

    final draft = await ShareUploadService(
      client: client,
      convertHeicToPng: (path) async {
        expect(path, heic.path);
        return png.path;
      },
    ).createDraft(
      session,
      SharedData(
        filePaths: [heic.path],
        mimeType: 'image/heic',
      ),
    );

    expect(uploadedName, 'photo.png');
    expect(uploadedContentType, 'image/png');
    expect(draft, '![photo.png](/api/files/converted.png)');

    await tempDir.delete(recursive: true);
  });
}
