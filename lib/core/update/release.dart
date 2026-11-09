class ReleaseInfo {
  const ReleaseInfo({
    required this.tag,
    required this.assetUrl,
    required this.assetName,
    this.assetSize = 0,
  });

  final String tag;
  final String assetUrl;
  final String assetName;
  final int assetSize;
}

/// Newest non-draft release that already has [assetName] uploaded.
ReleaseInfo? pickRelease(List<Object?> releases, String assetName) {
  for (final r in releases) {
    if (r is! Map<String, dynamic> || r['draft'] == true) continue;
    for (final a in (r['assets'] as List?) ?? const []) {
      if (a is! Map<String, dynamic>) continue;
      if (a['name'] == assetName && a['state'] == 'uploaded') {
        return ReleaseInfo(
          tag: r['tag_name'] as String? ?? '',
          assetUrl: a['browser_download_url'] as String? ?? '',
          assetName: assetName,
          assetSize: a['size'] as int? ?? 0,
        );
      }
    }
  }
  return null;
}

bool isUpdate(ReleaseInfo? release, String currentTag) =>
    release != null &&
    currentTag.isNotEmpty &&
    release.tag.isNotEmpty &&
    release.assetUrl.isNotEmpty &&
    release.tag != currentTag;
