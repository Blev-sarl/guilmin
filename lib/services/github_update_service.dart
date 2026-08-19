import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class AppRelease {
  const AppRelease({
    required this.version,
    required this.name,
    required this.notes,
    required this.apkUrl,
    required this.apkSize,
    required this.publishedAt,
  });

  final String version;
  final String name;
  final String notes;
  final String apkUrl;
  final int apkSize;
  final DateTime? publishedAt;
}

class GitHubUpdateService {
  static const _releasesUrl =
      'https://api.github.com/repos/blev-dev/odoo-picking/releases?per_page=50';

  Future<AppRelease?> getAvailableUpdate() async {
    final releases = await getReleases();
    if (releases.isEmpty) return null;
    final package = await PackageInfo.fromPlatform();
    for (final release in releases) {
      if (_isNewer(release.version, package.version)) return release;
    }
    return null;
  }

  Future<List<AppRelease>> getReleases() async {
    if (!Platform.isAndroid) return <AppRelease>[];
    final response = await http.get(
      Uri.parse(_releasesUrl),
      headers: const <String, String>{
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'Guilmin-Odoo-Picking',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    );
    if (response.statusCode == 404) return <AppRelease>[];
    if (response.statusCode != 200) {
      throw Exception('GitHub indisponible (${response.statusCode}).');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    final releases = <AppRelease>[];
    for (final item in data.whereType<Map<String, dynamic>>()) {
      final assets = (item['assets'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>();
      Map<String, dynamic>? apk;
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          apk = asset;
          break;
        }
      }
      if (apk == null) continue;
      final version = (item['tag_name'] as String? ?? '').trim();
      releases.add(
        AppRelease(
          version: version,
          name: item['name'] as String? ?? version,
          notes: item['body'] as String? ?? '',
          apkUrl: apk['browser_download_url'] as String,
          apkSize: (apk['size'] as num?)?.toInt() ?? 0,
          publishedAt: DateTime.tryParse(item['published_at'] as String? ?? ''),
        ),
      );
    }
    return releases;
  }

  Future<File> downloadApk(
    AppRelease release, {
    required void Function(double progress) onProgress,
  }) async {
    final request = http.Request('GET', Uri.parse(release.apkUrl));
    request.headers['User-Agent'] = 'Guilmin-Odoo-Picking';
    final client = http.Client();
    final response = await client.send(request);
    if (response.statusCode != 200) {
      client.close();
      throw Exception('Téléchargement impossible (${response.statusCode}).');
    }
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/guilmin-update.apk');
    final sink = file.openWrite();
    var received = 0;
    final responseLength = response.contentLength ?? 0;
    final total = release.apkSize > 0 ? release.apkSize : responseLength;
    var lastReportedProgress = 0.0;
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          final progress = (received / total).clamp(0, 0.99).toDouble();
          if (progress - lastReportedProgress >= 0.01) {
            lastReportedProgress = progress;
            onProgress(progress);
            await Future<void>.delayed(const Duration(milliseconds: 18));
          }
        }
      }
    } finally {
      await sink.close();
      client.close();
    }
    onProgress(1);
    return file;
  }

  Future<void> installApk(File apk) async {
    final result = await OpenFilex.open(
      apk.path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw Exception(result.message);
    }
  }

  bool _isNewer(String candidate, String installed) {
    final left = _versionParts(candidate);
    final right = _versionParts(installed);
    final length = left.length > right.length ? left.length : right.length;
    for (var index = 0; index < length; index++) {
      final a = index < left.length ? left[index] : 0;
      final b = index < right.length ? right[index] : 0;
      if (a != b) return a > b;
    }
    return false;
  }

  List<int> _versionParts(String value) => RegExp(r'\d+')
      .allMatches(value)
      .map((match) => int.parse(match.group(0)!))
      .take(3)
      .toList();
}
