import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// UpdateService
/// Checks GitHub Releases for a newer APK, downloads + installs it.
/// Only works on Android. Web + iOS return "up to date" always.
class UpdateService {
  UpdateService._();

  static const _repoOwner = 'lawrenceiyanuabiodun-cyber';
  static const _repoName = 'nggc-mobile-app';
  static const _apiUrl =
      'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest';
  static const _installedShaKey = 'installed_apk_sha';
  static const _lastCheckKey = 'last_update_check_ms';

  /// Public: check if an update is available.
  /// Returns null if no update. Returns UpdateInfo if update available.
  static Future<UpdateInfo?> checkForUpdate() async {
    // Web + iOS always up-to-date
    if (kIsWeb) return null;
    if (!Platform.isAndroid) return null;

    try {
      final resp = await http.get(
        Uri.parse(_apiUrl),
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) return null;

      final data = json.decode(resp.body) as Map<String, dynamic>;
      final assets = (data['assets'] as List?) ?? [];
      if (assets.isEmpty) return null;

      // Find the APK asset
      final apkAsset = assets.firstWhere(
        (a) {
          final name = (a['name'] as String?)?.toLowerCase() ?? '';
          return name.endsWith('.apk');
        },
        orElse: () => null,
      );
      if (apkAsset == null) return null;

      final remoteSha = (apkAsset['digest'] as String?) ?? '';
      final downloadUrl =
          (apkAsset['browser_download_url'] as String?) ?? '';
      final sizeBytes = (apkAsset['size'] as int?) ?? 0;
      final updatedAt = (apkAsset['updated_at'] as String?) ?? '';
      final releaseName = (data['name'] as String?) ?? '';
      final releaseNotes = (data['body'] as String?) ?? '';

      if (remoteSha.isEmpty || downloadUrl.isEmpty) return null;

      // Compare with installed SHA
      final prefs = await SharedPreferences.getInstance();
      final installedSha = prefs.getString(_installedShaKey);

      // First run — mark current version as installed
      if (installedSha == null || installedSha.isEmpty) {
        await prefs.setString(_installedShaKey, remoteSha);
        return null;
      }

      // Same SHA = up to date
      if (installedSha == remoteSha) return null;

      // Different SHA = update available!
      return UpdateInfo(
        remoteSha: remoteSha,
        downloadUrl: downloadUrl,
        sizeBytes: sizeBytes,
        updatedAt: updatedAt,
        releaseName: releaseName,
        releaseNotes: releaseNotes,
      );
    } catch (e) {
      debugPrint('UpdateService checkForUpdate error: $e');
      return null;
    }
  }

  /// Downloads the APK to a temp file with progress callback.
  /// Returns the file path on success, null on failure.
  static Future<String?> downloadApk({
    required String downloadUrl,
    required Function(double progress) onProgress,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/nggc_update.apk';
      final file = File(filePath);

      // Delete old download if exists
      if (await file.exists()) {
        await file.delete();
      }

      final request = http.Request('GET', Uri.parse(downloadUrl));
      final resp = await http.Client().send(request);

      if (resp.statusCode != 200) return null;

      final totalBytes = resp.contentLength ?? 0;
      int downloadedBytes = 0;
      final sink = file.openWrite();

      await for (final chunk in resp.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress(downloadedBytes / totalBytes);
        }
      }

      await sink.close();
      return filePath;
    } catch (e) {
      debugPrint('UpdateService downloadApk error: $e');
      return null;
    }
  }

  /// Launches the Android package installer.
  /// Requires REQUEST_INSTALL_PACKAGES permission (auto-requested by installer).
  static Future<bool> installApk(String filePath) async {
    try {
      // Request install permission (Android 8+)
      if (Platform.isAndroid) {
        final status = await Permission.requestInstallPackages.request();
        if (!status.isGranted) {
          debugPrint('Install permission denied');
          return false;
        }
      }

      final result = await OpenFile.open(filePath);
      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('UpdateService installApk error: $e');
      return false;
    }
  }

  /// Mark the new SHA as installed (call after successful install prompt).
  static Future<void> markInstalled(String sha) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_installedShaKey, sha);
  }

  /// Get current app version for display.
  static Future<String> getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return 'v${info.version} (build ${info.buildNumber})';
    } catch (_) {
      return 'v1.0.0';
    }
  }

  /// Should we auto-check today? (only once per day)
  static Future<bool> shouldAutoCheck() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    const oneDayMs = 24 * 60 * 60 * 1000;
    if (now - lastCheck < oneDayMs) return false;
    await prefs.setInt(_lastCheckKey, now);
    return true;
  }
}

/// Data class for update info
class UpdateInfo {
  final String remoteSha;
  final String downloadUrl;
  final int sizeBytes;
  final String updatedAt;
  final String releaseName;
  final String releaseNotes;

  UpdateInfo({
    required this.remoteSha,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.updatedAt,
    required this.releaseName,
    required this.releaseNotes,
  });

  String get sizeMb => (sizeBytes / (1024 * 1024)).toStringAsFixed(1);
  String get formattedDate {
    try {
      final dt = DateTime.parse(updatedAt).toLocal();
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return updatedAt;
    }
  }
}
