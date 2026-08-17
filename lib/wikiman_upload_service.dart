import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'wikiman_auth_service.dart';

class WikimanUploadException implements Exception {
  const WikimanUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WikimanUploadService {
  WikimanUploadService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> uploadFile(
    WikimanSession session,
    String path, {
    String? filename,
    MediaType? contentType,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const WikimanUploadException('업로드할 파일을 찾을 수 없습니다.');
    }
    final name = (filename ?? File(path).uri.pathSegments.last).trim();
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
              filename: name.isEmpty ? 'upload.bin' : name,
              contentType: contentType,
            ),
          );

    late http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(const Duration(seconds: 60));
    } catch (_) {
      throw const WikimanUploadException('파일 업로드에 실패했습니다.');
    }

    final body = await response.stream.bytesToString();
    Map<String, dynamic> data;
    try {
      data = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw const WikimanUploadException('업로드 응답을 확인할 수 없습니다.');
    }

    if (response.statusCode != 201) {
      if (data['error'] == 'UPLOAD_TOO_LARGE') {
        final max = (data['params'] as Map?)?['max'];
        throw WikimanUploadException(
          max == null
              ? '파일이 설정된 최대 용량을 초과했습니다.'
              : '파일이 관리자 설정 최대 용량 ${max}MB를 초과했습니다.',
        );
      }
      throw WikimanUploadException('파일 업로드에 실패했습니다. (${response.statusCode})');
    }

    final files = data['files'];
    final first = files is List && files.isNotEmpty ? files.first : null;
    if (first is! Map) {
      throw const WikimanUploadException('업로드된 파일 정보를 받지 못했습니다.');
    }
    return Map<String, dynamic>.from(first);
  }
}
