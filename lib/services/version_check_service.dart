import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class VersionCheckService {
  static const String versionUrl =
      'https://raw.githubusercontent.com/MoaazBesher/expensesTracker/main/version.json';

  static Future<VersionInfo?> checkForUpdates() async {
    try {
      final response = await http.get(Uri.parse(versionUrl)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => http.Response('', 408),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final remoteVersion = data['version'] as String;
        final currentVersion = await _getCurrentVersion();

        if (_isNewerVersion(remoteVersion, currentVersion)) {
          return VersionInfo(
            version: remoteVersion,
            downloadUrl: data['downloadUrl'] as String,
            releaseNotes: data['releaseNotes'] as String? ?? '',
            forceUpdate: data['forceUpdate'] as bool? ?? false,
          );
        }
      }
    } catch (e) {
      print('Version check error: $e');
    }
    return null;
  }

  static Future<String> _getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  static bool _isNewerVersion(String remote, String current) {
    try {
      final remoteVersions = remote.split('.').map(int.parse).toList();
      final currentVersions = current.split('.').map(int.parse).toList();

      // Pad with zeros if needed
      while (remoteVersions.length < currentVersions.length) {
        remoteVersions.add(0);
      }
      while (currentVersions.length < remoteVersions.length) {
        currentVersions.add(0);
      }

      for (int i = 0; i < remoteVersions.length; i++) {
        if (remoteVersions[i] > currentVersions[i]) return true;
        if (remoteVersions[i] < currentVersions[i]) return false;
      }
      return false;
    } catch (e) {
      print('Version comparison error: $e');
      return false;
    }
  }
}

class VersionInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;
  final bool forceUpdate;

  VersionInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.forceUpdate,
  });
}
