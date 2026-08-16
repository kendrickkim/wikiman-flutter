import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:share_intent_package/share_intent_package.dart';

import 'wikiman_auth_service.dart';

class ShareUploadService {
  ShareUploadService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String> createDraft(
    WikimanSession session,
    SharedData sharedData,
  ) async {
    final parts = <String>[];
    final text = sharedData.text?.trim();
    if (text != null && text.isNotEmpty) parts.add(text);

    for (final path in sharedData.filePaths) {
      final uploaded = await _upload(session, path);
      final name = _fileName(path);
      final isImage =
          (sharedData.mimeType?.startsWith('image/') ?? false) ||
          RegExp(
            r'\.(png|jpe?g|gif|webp|heic|bmp)$',
            caseSensitive: false,
          ).hasMatch(name);
      parts.add(
        isImage ? '![$name](${uploaded.url})' : '[$name](${uploaded.url})',
      );
    }
    return parts.where((part) => part.trim().isNotEmpty).join('\n\n');
  }

  Future<_UploadedFile> _upload(WikimanSession session, String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const ShareUploadException('공유된 파일을 읽을 수 없습니다.');
    }

    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('${session.settings.url}/api/uploads/files'),
          )
          ..headers['Authorization'] = 'Bearer ${session.token}'
          ..files.add(
            await http.MultipartFile.fromPath(
              'files',
              path,
              filename: _fileName(path),
            ),
          );

    late http.StreamedResponse response;
    try {
      response = await _client
          .send(request)
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      throw const ShareUploadException('공유 파일 업로드에 실패했습니다.');
    }

    final body = await response.stream.bytesToString();
    Map<String, dynamic> data;
    try {
      data = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw const ShareUploadException('업로드 응답을 확인할 수 없습니다.');
    }

    if (response.statusCode != 201) {
      if (data['error'] == 'UPLOAD_TOO_LARGE') {
        final max = (data['params'] as Map?)?['max'];
        throw ShareUploadException(
          max == null
              ? '공유 파일이 설정된 최대 용량을 초과했습니다.'
              : '공유 파일이 관리자 설정 최대 용량 ${max}MB를 초과했습니다.',
        );
      }
      throw ShareUploadException('공유 파일 업로드에 실패했습니다. (${response.statusCode})');
    }

    final files = data['files'];
    final first = files is List && files.isNotEmpty ? files.first : null;
    if (first is! Map || first['url'] is! String) {
      throw const ShareUploadException('업로드된 파일 주소를 받지 못했습니다.');
    }
    return _UploadedFile(url: first['url'] as String);
  }

  String _fileName(String path) {
    final segments = File(path).uri.pathSegments;
    return segments.isEmpty ? 'shared-file' : segments.last;
  }
}

class _UploadedFile {
  const _UploadedFile({required this.url});

  final String url;
}

class ShareUploadException implements Exception {
  const ShareUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}
