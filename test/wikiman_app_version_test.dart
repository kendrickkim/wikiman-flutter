import 'package:flutter_test/flutter_test.dart';
import 'package:wikiman_app/wikiman_app_version.dart';

void main() {
  test('버전 문자열에서 접두와 빌드 번호를 제거한다', () {
    expect(normalizeAppVersion('v0.1.4+5'), '0.1.4');
    expect(normalizeAppVersion('0.1.3'), '0.1.3');
  });

  test('GitHub 태그가 설치된 버전보다 높은지 비교한다', () {
    expect(isGithubVersionNewer('0.1.3+4', 'v0.1.4'), isTrue);
    expect(isGithubVersionNewer('0.1.4', 'v0.1.4'), isFalse);
    expect(isGithubVersionNewer('0.1.4', 'v0.1.3'), isFalse);
    expect(compareAppVersions('0.1.10', '0.1.9'), greaterThan(0));
  });

  test('다운로드 용량을 사람이 읽기 쉽게 표시한다', () {
    expect(formatDownloadBytes(512), '512 B');
    expect(formatDownloadBytes(2048), '2.0 KB');
    expect(formatDownloadBytes(5 * 1024 * 1024), '5.0 MB');
  });
}
