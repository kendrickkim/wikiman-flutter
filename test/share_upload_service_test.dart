import 'package:flutter_test/flutter_test.dart';
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
}
