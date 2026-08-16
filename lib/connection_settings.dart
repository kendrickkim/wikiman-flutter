class ConnectionSettings {
  const ConnectionSettings({
    required this.url,
    required this.username,
    required this.password,
  });

  final String url;
  final String username;
  final String password;

  ConnectionSettings normalized() {
    return ConnectionSettings(
      url: normalizeWikimanUrl(url),
      username: username.trim(),
      password: password,
    );
  }
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
