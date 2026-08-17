import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'connection_settings.dart';

class CredentialStore {
  CredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _urlKey = 'wikiman_url';
  static const _usernameKey = 'wikiman_username';
  static const _passwordKey = 'wikiman_password';
  static const _autoLoginKey = 'wikiman_auto_login';

  final FlutterSecureStorage _storage;

  Future<ConnectionSettings> read() async {
    final values = await Future.wait([
      _storage.read(key: _urlKey),
      _storage.read(key: _usernameKey),
      _storage.read(key: _passwordKey),
      _storage.read(key: _autoLoginKey),
    ]);
    return ConnectionSettings(
      url: values[0] ?? '',
      username: values[1] ?? '',
      password: values[2] ?? '',
      autoLogin: values[3] == 'true',
    );
  }

  Future<void> write(ConnectionSettings settings) async {
    final value = settings.normalized();
    await Future.wait([
      _storage.write(key: _urlKey, value: value.url),
      _storage.write(key: _usernameKey, value: value.username),
      _storage.write(key: _passwordKey, value: value.password),
      _storage.write(
        key: _autoLoginKey,
        value: value.autoLogin ? 'true' : 'false',
      ),
    ]);
  }
}
