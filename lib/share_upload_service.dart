import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:share_intent_package/share_intent_package.dart';

import 'heic_converter.dart';
import 'wikiman_auth_service.dart';

typedef HeicPathConverter = Future<String> Function(String path);

class ShareUploadService {
  ShareUploadService({
    http.Client? client,
    HeicConverter? heicConverter,
    HeicPathConverter? convertHeicToPng,
  }) : _client = client ?? http.Client(),
       _heicConverter = heicConverter ?? HeicConverter(),
       _convertHeicToPng = convertHeicToPng;

  final http.Client _client;
  final HeicConverter _heicConverter;
  final HeicPathConverter? _convertHeicToPng;

  Future<String> createDraft(
    WikimanSession session,
    SharedData sharedData,
  ) async {
    final parts = <String>[];
    final text = sharedData.text?.trim();
    if (text != null && text.isNotEmpty) parts.add(text);

    for (final path in sharedData.filePaths) {
      final prepared = await _prepareUploadPath(path, sharedData.mimeType);
      final uploaded = await _upload(
        session,
        prepared.path,
        filename: prepared.filename,
        contentType: prepared.contentType,
      );
      final name = prepared.filename;
      final isImage =
          prepared.contentType?.type == 'image' ||
          (sharedData.mimeType?.startsWith('image/') ?? false) ||
          RegExp(
            r'\.(png|jpe?g|gif|webp|bmp)$',
            caseSensitive: false,
          ).hasMatch(name);
      parts.add(
        isImage ? '![$name](${uploaded.url})' : '[$name](${uploaded.url})',
      );
    }
    return parts.where((part) => part.trim().isNotEmpty).join('\n\n');
  }

  Future<_PreparedUpload> _prepareUploadPath(
    String path,
    String? mimeType,
  ) async {
    final originalName = _fileName(path);
    final looksHeic =
        _heicConverter.isHeicPath(path) ||
        (mimeType != null &&
            RegExp(r'image/(heic|heif)', caseSensitive: false).hasMatch(
              mimeType,
            ));

    if (!looksHeic) {
      return _PreparedUpload(path: path, filename: originalName);
    }

    try {
      final pngPath = _convertHeicToPng != null
          ? await _convertHeicToPng(path)
          : await _heicConverter.convertToPng(path);
      final base = originalName.replaceFirst(
        HeicConverter.heicExt,
        '',
      );
      final pngName = '${base.isEmpty ? 'shared-image' : base}.png';
      return _PreparedUpload(
        path: pngPath,
        filename: pngName,
        contentType: MediaType('image', 'png'),
      );
    } on HeicConvertException catch (error) {
      throw ShareUploadException(error.message);
    } catch (_) {
      throw const ShareUploadException('HEIC 이미지를 PNG로 변환하지 못했습니다.');
    }
  }

  Future<_UploadedFile> _upload(
    WikimanSession session,
    String path, {
    required String filename,
    MediaType? contentType,
  }) async {
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
              filename: filename,
              contentType: contentType,
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

class _PreparedUpload {
  const _PreparedUpload({
    required this.path,
    required this.filename,
    this.contentType,
  });

  final String path;
  final String filename;
  final MediaType? contentType;
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
