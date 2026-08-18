String normalizeAppVersion(String raw) {
  var value = raw.trim();
  if (value.startsWith('v') || value.startsWith('V')) {
    value = value.substring(1);
  }
  final plus = value.indexOf('+');
  if (plus >= 0) value = value.substring(0, plus);
  return value;
}

List<int> appVersionParts(String raw) {
  if (normalizeAppVersion(raw).isEmpty) return const [0];
  return normalizeAppVersion(raw).split('.').map((part) {
    final digits = part.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }).toList();
}

int compareAppVersions(String left, String right) {
  final a = appVersionParts(left);
  final b = appVersionParts(right);
  final length = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < length; i++) {
    final l = i < a.length ? a[i] : 0;
    final r = i < b.length ? b[i] : 0;
    if (l != r) return l.compareTo(r);
  }
  return 0;
}

bool isGithubVersionNewer(String current, String github) {
  return compareAppVersions(github, current) > 0;
}

String formatDownloadBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
