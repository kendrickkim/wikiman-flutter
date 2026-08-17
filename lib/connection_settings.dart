class ConnectionSettings {
  const ConnectionSettings({
    required this.url,
    required this.username,
    required this.password,
    this.autoLogin = false,
  });

  final String url;
  final String username;
  final String password;
  final bool autoLogin;

  ConnectionSettings normalized() {
    return ConnectionSettings(
      url: normalizeWikimanUrl(url),
      username: username.trim(),
      password: password,
      autoLogin: autoLogin,
    );
  }

  ConnectionSettings copyWith({
    String? url,
    String? username,
    String? password,
    bool? autoLogin,
  }) {
    return ConnectionSettings(
      url: url ?? this.url,
      username: username ?? this.username,
      password: password ?? this.password,
      autoLogin: autoLogin ?? this.autoLogin,
    );
  }

  bool get canAttemptLogin =>
      url.trim().isNotEmpty &&
      username.trim().isNotEmpty &&
      password.isNotEmpty;
}

String normalizeWikimanUrl(String value) {
  var normalized = value.trim();
  if (normalized.isEmpty) return '';
  if (!normalized.contains('://')) normalized = 'https://$normalized';
  normalized = normalized.replaceFirst(RegExp(r'/+$'), '');
  return normalized;
}

Uri loginUriFor(String baseUrl) {
  return Uri.parse('${normalizeWikimanUrl(baseUrl)}/api/auth/login');
}
