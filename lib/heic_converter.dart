import 'dart:io';

import 'package:flutter/services.dart';

/// Converts HEIC/HEIF images to PNG via a platform MethodChannel.
class HeicConverter {
  HeicConverter({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.example.wikiman_app/heic');

  final MethodChannel _channel;

  static final RegExp heicExt = RegExp(
    r'\.(heic|heif)$',
    caseSensitive: false,
  );

  bool isHeicPath(String path) => heicExt.hasMatch(path);

  Future<String> convertToPng(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const HeicConvertException('변환할 HEIC 파일을 찾을 수 없습니다.');
    }

    try {
      final result = await _channel.invokeMethod<String>('convertToPng', {
        'path': path,
      });
      if (result == null || result.isEmpty) {
        throw const HeicConvertException('HEIC를 PNG로 변환하지 못했습니다.');
      }
      final out = File(result);
      if (!await out.exists()) {
        throw const HeicConvertException('변환된 PNG 파일을 찾을 수 없습니다.');
      }
      return result;
    } on PlatformException catch (error) {
      throw HeicConvertException(
        error.message?.isNotEmpty == true
            ? error.message!
            : 'HEIC를 PNG로 변환하지 못했습니다.',
      );
    } on MissingPluginException {
      throw const HeicConvertException(
        '이 기기에서는 HEIC 변환을 지원하지 않습니다.',
      );
    }
  }
}

class HeicConvertException implements Exception {
  const HeicConvertException(this.message);

  final String message;

  @override
  String toString() => message;
}
