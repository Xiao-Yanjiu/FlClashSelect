int? _compareReleaseVersions(String candidate, String current) {
  final pattern = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$');
  final remote = pattern.firstMatch(candidate);
  final local = pattern.firstMatch(current);
  if (remote == null || local == null) return null;
  for (var i = 1; i <= 3; i++) {
    final difference = int.parse(remote.group(i)!) - int.parse(local.group(i)!);
    if (difference != 0) return difference;
  }
  return 0;
}

Map<String, dynamic>? selectGithubUpdate(
  List<dynamic> releases, {
  required String currentVersion,
  required bool android,
  required String repository,
}) {
  Map<String, dynamic>? selected;
  for (final raw in releases) {
    if (raw is! Map<String, dynamic> || raw['draft'] == true) continue;
    final tag = raw['tag_name'];
    if (tag is! String ||
        (_compareReleaseVersions(tag, currentVersion) ?? -1) <= 0) {
      continue;
    }
    final assets = raw['assets'];
    if (assets is! List) continue;
    String? download;
    for (final asset in assets) {
      if (asset is! Map) continue;
      final name = asset['name'];
      final url = asset['browser_download_url'];
      if (name is! String || url is! String) continue;
      final matches = android
          ? name.endsWith('-android-arm64.apk')
          : name.endsWith('-windows-portable.zip');
      if (matches &&
          url.startsWith('https://github.com/$repository/releases/download/')) {
        download = url;
        break;
      }
    }
    if (download == null) continue;
    if (selected == null ||
        (_compareReleaseVersions(tag, selected['tag_name'] as String) ?? -1) >
            0) {
      selected = {...raw, 'select_download_url': download};
    }
  }
  return selected;
}
