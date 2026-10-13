import 'package:fl_clash/select/github_updates.dart';
import 'package:flutter_test/flutter_test.dart';

const repository = 'Xiao-Yanjiu/FlClashSelect';
Map<String, dynamic> release(
  String tag,
  List<String> names, {
  bool draft = false,
}) => {
  'tag_name': tag,
  'draft': draft,
  'prerelease': true,
  'assets': [
    for (final name in names)
      {
        'name': name,
        'browser_download_url':
            'https://github.com/$repository/releases/download/$tag/$name',
      },
  ],
};

void main() {
  test(
    'selects newest platform-compatible release including test releases',
    () {
      final releases = [
        release('v0.19.0', ['app-windows-portable.zip']),
        release('v0.20.0', ['app-android-arm64.apk']),
        release('v0.21.0', ['app-windows-portable.zip'], draft: true),
      ];
      final windows = selectGithubUpdate(
        releases,
        currentVersion: '0.18.0',
        android: false,
        repository: repository,
      );
      final android = selectGithubUpdate(
        releases,
        currentVersion: '0.18.0',
        android: true,
        repository: repository,
      );
      expect(windows?['tag_name'], 'v0.19.0');
      expect(android?['tag_name'], 'v0.20.0');
      expect(android?['select_download_url'], endsWith('.apk'));
    },
  );
  test('ignores current, older, invalid tags and unrelated download hosts', () {
    final malicious = release('v0.99.0', ['app-android-arm64.apk']);
    (malicious['assets'] as List).first['browser_download_url'] =
        'https://example.com/app.apk';
    expect(
      selectGithubUpdate(
        [
          malicious,
          release('v0.18.0', ['app-android-arm64.apk']),
          release('v0.17.0', ['app-android-arm64.apk']),
          release('invalid', ['app-android-arm64.apk']),
        ],
        currentVersion: '0.18.0',
        android: true,
        repository: repository,
      ),
      isNull,
    );
  });
}
