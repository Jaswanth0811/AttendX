import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class UpdateService {
  Future<void> checkForUpdates(BuildContext context, {bool silent = false}) async {
    try {
      final response = await http.get(
        Uri.parse("https://api.github.com/repos/Jaswanth0811/AttendX/releases/latest"),
      );
      if (response.statusCode != 200) {
        if (!silent) {
          _showErrorDialog(context, "Failed to connect to update server.");
        }
        return;
      }

      final data = jsonDecode(response.body);
      final String latestTag = data['tag_name']?.toString() ?? '';
      if (latestTag.isEmpty) {
        if (!silent) {
          _showNoUpdatesDialog(context);
        }
        return;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final String localVersion = packageInfo.version; // e.g., 1.1.0
      final String localBuildStr = packageInfo.buildNumber; // e.g., 25
      final int localBuild = int.tryParse(localBuildStr) ?? 0;

      int remoteBuild = 0;
      final String cleanTag = latestTag.toLowerCase();
      String remoteVersion = cleanTag.replaceAll('v', '');
      if (cleanTag.contains('-build')) {
        final parts = cleanTag.split('-build');
        remoteVersion = parts[0].replaceAll('v', '');
        remoteBuild = int.tryParse(parts[1]) ?? 0;
      } else if (cleanTag.contains('+')) {
        final parts = cleanTag.split('+');
        remoteVersion = parts[0].replaceAll('v', '');
        remoteBuild = int.tryParse(parts[1]) ?? 0;
      }

      final String cleanRemote = remoteVersion.split('+').first.split('-').first.trim();
      final String cleanLocal = localVersion.split('+').first.split('-').first.trim();

      debugPrint("Update Check: Clean Remote: '$cleanRemote' (Build: $remoteBuild), Clean Local: '$cleanLocal' (Build: $localBuild)");

      bool isNewer = false;
      if (cleanRemote != cleanLocal) {
        isNewer = _isVersionNewer(cleanRemote, cleanLocal);
      } else {
        isNewer = remoteBuild > localBuild;
      }

      if (isNewer) {
        if (context.mounted) {
          _showUpdateDialog(context, latestTag, data['body']?.toString() ?? '', data['html_url']?.toString() ?? '');
        }
      } else {
        if (!silent && context.mounted) {
          _showNoUpdatesDialog(context);
        }
      }
    } catch (e) {
      if (!silent && context.mounted) {
        _showErrorDialog(context, "Error checking for updates: $e");
      }
    }
  }

  bool _isVersionNewer(String remote, String local) {
    final rParts = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final lParts = local.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < rParts.length && i < lParts.length; i++) {
      if (rParts[i] > lParts[i]) return true;
      if (rParts[i] < lParts[i]) return false;
    }
    return rParts.length > lParts.length;
  }

  void _showUpdateDialog(BuildContext context, String tagName, String notes, String downloadUrl) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.system_update_alt_outlined, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('New Update Available!', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version $tagName is now available.', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            const Text('Release Notes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                child: Text(notes.isNotEmpty ? notes : 'No release notes provided.', style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final Uri url = Uri.parse(downloadUrl);
              await launchUrl(url, mode: LaunchMode.externalApplication);
            },
            child: const Text('Download & Install'),
          ),
        ],
      ),
    );
  }

  void _showNoUpdatesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Up to Date', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Colors are updated and auto-sync is verified. You are already running the latest version of AttendX.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Update Check Failed', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
