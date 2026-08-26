class UpdateModel {
  final int versionCode;
  final String versionName;
  final String? publishedAt;
  final int? minSupportedVersionCode;
  final String apkFilename;
  final String apkUrl;
  final Map<String, String> apkArchUrls;
  final String changelogUrl;
  final String? changelogMarkdown;

  const UpdateModel({
    required this.versionCode,
    required this.versionName,
    this.publishedAt,
    this.minSupportedVersionCode,
    required this.apkFilename,
    required this.apkUrl,
    this.apkArchUrls = const {},
    required this.changelogUrl,
    this.changelogMarkdown,
  });

  bool isForceUpdate(int currentVersionCode) {
    if (minSupportedVersionCode == null) return false;
    return currentVersionCode < minSupportedVersionCode!;
  }

  factory UpdateModel.fromJson(Map<String, dynamic> json, {String? changelogMarkdown}) {
    final rawArch = json['apk_arch_urls'];
    final archMap = <String, String>{};
    if (rawArch is Map) {
      rawArch.forEach((k, v) {
        if (k is String && v is String) {
          archMap[k] = v;
        }
      });
    }

    return UpdateModel(
      versionCode: json['version_code'] as int? ?? 0,
      versionName: json['version_name'] as String? ?? 'Unknown',
      publishedAt: json['published_at'] as String?,
      minSupportedVersionCode: json['min_supported_version_code'] as int?,
      apkFilename: json['apk_filename'] as String? ?? 'Arcane.apk',
      apkUrl: json['apk_url'] as String? ?? '',
      apkArchUrls: archMap,
      changelogUrl: json['changelog_url'] as String? ?? '',
      changelogMarkdown: changelogMarkdown ?? json['changelog_markdown'] as String?,
    );
  }

  String get versionedApkFilename {
    final cleanVersion = versionName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return 'Arcane_v${cleanVersion}_b$versionCode.apk';
  }

  UpdateModel copyWith({String? changelogMarkdown}) {
    return UpdateModel(
      versionCode: versionCode,
      versionName: versionName,
      publishedAt: publishedAt,
      minSupportedVersionCode: minSupportedVersionCode,
      apkFilename: apkFilename,
      apkUrl: apkUrl,
      apkArchUrls: apkArchUrls,
      changelogUrl: changelogUrl,
      changelogMarkdown: changelogMarkdown ?? this.changelogMarkdown,
    );
  }
}
