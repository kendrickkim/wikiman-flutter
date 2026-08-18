import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wikiman_app/wikiman_app_updater.dart';
import 'package:wikiman_app/wikiman_github_release.dart';

void main() {
  test('GitHub 릴리스 JSON에서 wikiman APK를 고른다', () {
    final release = parseGithubRelease({
      'tag_name': 'v0.1.4',
      'assets': [
        {'name': 'notes.txt', 'browser_download_url': 'https://example.com/notes.txt'},
        {
          'name': 'app.apk',
          'browser_download_url': 'https://example.com/app.apk',
        },
        {
          'name': 'wikiman-0.1.4.apk',
          'browser_download_url': 'https://example.com/wikiman-0.1.4.apk',
        },
      ],
    });
    expect(release.version, 'v0.1.4');
    expect(release.apkName, 'wikiman-0.1.4.apk');
    expect(release.apkUrl, 'https://example.com/wikiman-0.1.4.apk');
  });

  test('최신 릴리스 API 응답을 파싱한다', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/repos/kendrickkim/wikiman-flutter/releases/latest');
      expect(request.headers['User-Agent'], 'WikimanApp');
      return http.Response(
        jsonEncode({
          'tag_name': 'v0.1.4',
          'assets': [
            {
              'name': 'wikiman-0.1.4.apk',
              'browser_download_url': 'https://example.com/wikiman-0.1.4.apk',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final release = await WikimanGithubReleaseClient(client: client).fetchLatest();
    expect(release.tag, 'v0.1.4');
    expect(release.apkUrl, 'https://example.com/wikiman-0.1.4.apk');
  });

  test('릴리스 APK를 파일로 받고 진행률을 알린다', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://example.com/wikiman-0.1.4.apk');
      return http.Response.bytes(
        List<int>.filled(8, 7),
        200,
        headers: {'content-length': '8'},
      );
    });
    final dir = await Directory.systemTemp.createTemp('wikiman-update-');
    final progress = <(int, int?)>[];
    final file = await WikimanAppUpdater(clientFactory: () => client).download(
      const WikimanGithubRelease(
        tag: 'v0.1.4',
        version: 'v0.1.4',
        apkUrl: 'https://example.com/wikiman-0.1.4.apk',
        apkName: 'wikiman-0.1.4.apk',
      ),
      directory: dir,
      onProgress: (received, total) => progress.add((received, total)),
    );

    expect(await file.readAsBytes(), List<int>.filled(8, 7));
    expect(progress, isNotEmpty);
    expect(progress.last.$1, 8);
    expect(progress.last.$2, 8);
  });
}
