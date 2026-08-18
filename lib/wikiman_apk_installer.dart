import 'dart:io';

import 'package:flutter/services.dart';

class WikimanApkInstaller {
  WikimanApkInstaller({MethodChannel? channel, bool? android})
    : _channel = channel ?? const MethodChannel('com.example.wikiman_app/update'),
      _android = android ?? Platform.isAndroid;

  final MethodChannel _channel;
  final bool _android;

  Future<String> currentVersion() async {
    if (!_android) return '';
    try {
      final version = await _channel.invokeMethod<String>('getVersionName');
      return (version ?? '').trim();
    } on MissingPluginException {
      return '';
    } on PlatformException {
      return '';
    }
  }

  Future<bool> canInstallPackages() async {
    if (!_android) return false;
    try {
      final allowed = await _channel.invokeMethod<bool>('canInstallPackages');
      return allowed == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> openInstallSettings() async {
    if (!_android) return;
    await _channel.invokeMethod<void>('openInstallSettings');
  }

  Future<void> focusWebView() async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<void>('focusWebView');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<void> installApk(String path) async {
    if (!_android) {
      throw const WikimanInstallException('안드로이드에서만 앱을 업데이트할 수 있습니다.');
    }
    final file = File(path);
    if (!await file.exists()) {
      throw const WikimanInstallException('설치할 APK를 찾을 수 없습니다.');
    }
    try {
      await _channel.invokeMethod<void>('installApk', {'path': path});
    } on MissingPluginException {
      throw const WikimanInstallException('이 기기에서는 앱 설치를 지원하지 않습니다.');
    } on PlatformException catch (error) {
      throw WikimanInstallException(
        error.message?.isNotEmpty == true
            ? error.message!
            : '앱을 설치하지 못했습니다.',
      );
    }
  }
}

class WikimanInstallException implements Exception {
  const WikimanInstallException(this.message);

  final String message;

  @override
  String toString() => message;
}
