import 'dart:convert';

import 'package:http/http.dart' as http;

class WikimanUpdateException implements Exception {
  const WikimanUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WikimanUpdateCancelled implements Exception {
  const WikimanUpdateCancelled();

  @override
  String toString() => '업데이트가 취소되었습니다.';
}

class WikimanGithubRelease {
  const WikimanGithubRelease({
    required this.tag,
    required this.version,
    required this.apkUrl,
    required this.apkName,
    this.notes = '',
  });

  final String tag;
  final String version;
  final String apkUrl;
  final String apkName;
  final String notes;
}

WikimanGithubRelease parseGithubRelease(Object? raw) {
  if (raw is! Map) {
    throw const WikimanUpdateException('GitHub 릴리스 형식을 확인할 수 없습니다.');
  }
  final tag = '${raw['tag_name'] ?? ''}'.trim();
  if (tag.isEmpty) {
    throw const WikimanUpdateException('GitHub 릴리스 태그를 확인할 수 없습니다.');
  }
  final assets = raw['assets'];
  if (assets is! List) {
    throw const WikimanUpdateException('GitHub 릴리스에 APK가 없습니다.');
  }
  Map? apk;
  for (final item in assets) {
    if (item is! Map) continue;
    final name = '${item['name'] ?? ''}'.toLowerCase();
    if (!name.endsWith('.apk')) continue;
    apk = item;
    if (name.contains('wikiman')) break;
  }
  if (apk == null) {
    throw const WikimanUpdateException('GitHub 릴리스에서 APK를 찾지 못했습니다.');
  }
  final url = '${apk['browser_download_url'] ?? ''}'.trim();
  final name = '${apk['name'] ?? ''}'.trim();
  if (url.isEmpty) {
    throw const WikimanUpdateException('APK 다운로드 주소가 없습니다.');
  }
  return WikimanGithubRelease(
    tag: tag,
    version: tag,
    apkUrl: url,
    apkName: name.isEmpty ? 'wikiman-update.apk' : name,
    notes: '${raw['body'] ?? ''}'.trim(),
  );
}

class WikimanGithubReleaseClient {
  WikimanGithubReleaseClient({
    http.Client? client,
    this.owner = 'kendrickkim',
    this.repo = 'wikiman-flutter',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String owner;
  final String repo;

  Future<WikimanGithubRelease> fetchLatest() async {
    final uri = Uri.https('api.github.com', '/repos/$owner/$repo/releases/latest');
    late http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'WikimanApp',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      );
    } catch (_) {
      throw const WikimanUpdateException('GitHub 릴리스를 확인하지 못했습니다.');
    }
    if (response.statusCode != 200) {
      throw const WikimanUpdateException('GitHub 릴리스를 확인하지 못했습니다.');
    }
    try {
      return parseGithubRelease(jsonDecode(response.body));
    } on WikimanUpdateException {
      rethrow;
    } catch (_) {
      throw const WikimanUpdateException('GitHub 릴리스 형식을 확인할 수 없습니다.');
    }
  }
}
