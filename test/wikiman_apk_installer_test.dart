import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wikiman_app/wikiman_apk_installer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('설치 채널로 APK 경로를 넘긴다', () async {
    String? method;
    Map<dynamic, dynamic>? arguments;
    const channel = MethodChannel('com.example.wikiman_app/update');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      method = call.method;
      arguments = call.arguments as Map<dynamic, dynamic>?;
      return null;
    });

    final dir = await Directory.systemTemp.createTemp('wikiman-apk-');
    final apk = File('${dir.path}/wikiman-update.apk');
    await apk.writeAsBytes([1, 2, 3]);

    await WikimanApkInstaller(channel: channel, android: true).installApk(apk.path);
    expect(method, 'installApk');
    expect(arguments?['path'], apk.path);
  });
}
