import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String _releasesUrl = 'https://api.github.com/repos/Jaswanth0811/AttendX/releases/latest';

  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse(_releasesUrl));
      if (response.statusCode != 200) return;

      final data = json.decode(response.body);
      final remoteTag = data['tag_name'] as String? ?? '';
      final releaseName = data['name'] as String? ?? remoteTag;
      final releaseNotes = data['body'] as String? ?? '';
      
      // Find APK download URL in assets
      String downloadUrl = data['html_url'] as String? ?? 'https://github.com/Jaswanth0811/AttendX/releases';
      final assets = data['assets'] as List<dynamic>? ?? [];
      for (var asset in assets) {
        final assetName = asset['name'] as String? ?? '';
        if (assetName.endsWith('.apk')) {
          downloadUrl = asset['browser_download_url'] as String? ?? downloadUrl;
          break;
        }
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuild = packageInfo.buildNumber;

      if (_isUpdateAvailable(currentVersion, currentBuild, remoteTag)) {
        if (context.mounted) {
          _showUpdateDialog(context, releaseName, currentVersion, downloadUrl, releaseNotes);
        }
      }
    } catch (e) {
      debugPrint("Failed to check for updates: $e");
    }
  }

  static bool _isUpdateAvailable(String currentVersion, String currentBuild, String remoteTag) {
    String cleanedRemote = remoteTag.toLowerCase();
    if (cleanedRemote.startsWith('v')) {
      cleanedRemote = cleanedRemote.substring(1);
    }

    int remoteBuild = 0;
    if (cleanedRemote.contains('-build')) {
      final parts = cleanedRemote.split('-build');
      remoteBuild = int.tryParse(parts.last) ?? 0;
      cleanedRemote = parts.first;
    } else if (cleanedRemote.contains('+')) {
      final parts = cleanedRemote.split('+');
      remoteBuild = int.tryParse(parts.last) ?? 0;
      cleanedRemote = parts.first;
    }

    int localBuild = int.tryParse(currentBuild) ?? 0;

    if (remoteBuild > localBuild) return true;

    // Semantic version check
    List<int> remoteSem = cleanedRemote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> localSem = currentVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      int rVal = remoteSem.length > i ? remoteSem[i] : 0;
      int lVal = localSem.length > i ? localSem[i] : 0;
      if (rVal > lVal) return true;
      if (rVal < lVal) return false;
    }

    return false;
  }

  static void _showUpdateDialog(
    BuildContext context,
    String remoteName,
    String currentVersion,
    String downloadUrl,
    String releaseNotes,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.rocket_launch, color: Colors.blue, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text('Update Available!')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A new version of AttendX is available: $remoteName',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Current version installed: v$currentVersion'),
            if (releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('What\'s New:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    releaseNotes,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final uri = Uri.parse(downloadUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.download),
            label: const Text('Install'),
          ),
        ],
      ),
    );
  }
}
