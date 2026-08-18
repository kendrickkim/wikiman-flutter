import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'wikiman_github_release.dart';

typedef WikimanDownloadProgress = void Function(int received, int? total);

class WikimanAppUpdater {
  WikimanAppUpdater({http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  final http.Client Function() _clientFactory;
  http.Client? _client;
  bool _cancelled = false;

  bool get isDownloading => _client != null && !_cancelled;

  void cancel() {
    _cancelled = true;
    _client?.close();
    _client = null;
  }

  Future<File> download(
    WikimanGithubRelease release, {
    required WikimanDownloadProgress onProgress,
    Directory? directory,
  }) async {
    _cancelled = false;
    final client = _clientFactory();
    _client = client;
    final dir = directory ?? await _updateDirectory();
    await dir.create(recursive: true);
    final dest = File('${dir.path}/wikiman-update.apk');
    if (await dest.exists()) {
      await dest.delete();
    }

    try {
      final request = http.Request('GET', Uri.parse(release.apkUrl))
        ..headers.addAll(const {
          'User-Agent': 'WikimanApp',
          'Accept': '*/*',
          'Accept-Encoding': 'identity',
        })
        ..followRedirects = true;
      final response = await client.send(request);
      if (_cancelled) throw const WikimanUpdateCancelled();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const WikimanUpdateException('업데이트 파일을 받지 못했습니다.');
      }
      final total = response.contentLength;
      var received = 0;
      final sink = dest.openWrite();
      try {
        await for (final chunk in response.stream) {
          if (_cancelled) throw const WikimanUpdateCancelled();
          sink.add(chunk);
          received += chunk.length;
          onProgress(received, total == null || total <= 0 ? null : total);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (_cancelled) throw const WikimanUpdateCancelled();
      if (received <= 0) {
        throw const WikimanUpdateException('업데이트 파일이 비어 있습니다.');
      }
      return dest;
    } on WikimanUpdateCancelled {
      if (await dest.exists()) await dest.delete();
      rethrow;
    } on WikimanUpdateException {
      if (await dest.exists()) await dest.delete();
      rethrow;
    } catch (_) {
      if (await dest.exists()) await dest.delete();
      if (_cancelled) throw const WikimanUpdateCancelled();
      throw const WikimanUpdateException('업데이트 파일을 받지 못했습니다.');
    } finally {
      try {
        client.close();
      } catch (_) {}
      if (identical(_client, client)) _client = null;
    }
  }

  Future<Directory> _updateDirectory() async {
    final root = await getApplicationSupportDirectory();
    return Directory('${root.path}/updates');
  }
}
