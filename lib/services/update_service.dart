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
      String remoteVersion = latestTag.replaceAll('v', '');
      if (latestTag.contains('-build')) {
        final parts = latestTag.split('-build');
        remoteVersion = parts[0].replaceAll('v', '');
        remoteBuild = int.tryParse(parts[1]) ?? 0;
      } else if (latestTag.contains('+')) {
        final parts = latestTag.split('+');
        remoteVersion = parts[0].replaceAll('v', '');
        remoteBuild = int.tryParse(parts[1]) ?? 0;
      }

      bool isNewer = false;
      if (remoteVersion != localVersion) {
        isNewer = _isVersionNewer(remoteVersion, localVersion);
      } else {
        isNewer = remoteBuild > localBuild;
      }

      if (isNewer) {
        if (context.mounted) {
          _showUpdateDialog(context, latestTag, data['body']?.toString() ?? '', data);
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

  void _showUpdateDialog(BuildContext context, String tagName, String notes, Map<String, dynamic> releaseData) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final String localVersion = packageInfo.version;

    String downloadUrl = '';
    final List<dynamic> assets = releaseData['assets'] ?? [];
    if (assets.isNotEmpty) {
      downloadUrl = assets.first['browser_download_url']?.toString() ?? '';
    }
    if (downloadUrl.isEmpty) {
      downloadUrl = releaseData['html_url']?.toString() ?? '';
    }

    bool isDownloading = false;
    double progress = 0.0;
    String statusText = '';

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: !isDownloading,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(
                  isDownloading ? Icons.file_download : Icons.system_update_alt_outlined, 
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  isDownloading ? 'Downloading Update...' : 'New Update Available!', 
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isDownloading) ...[
                  Text('Version $tagName is now available (Your version: $localVersion).', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                ] else ...[
                  Text(statusText, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ],
            ),
            actions: [
              if (!isDownloading) ...[
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Later'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setDialogState(() {
                      isDownloading = true;
                      statusText = 'Initializing download...';
                      progress = 0.0;
                    });
                    _startDownload(
                      url: downloadUrl,
                      onProgress: (p, status) {
                        setDialogState(() {
                          progress = p;
                          statusText = status;
                        });
                      },
                      onComplete: (apkPath) async {
                        Navigator.pop(dialogCtx);
                        final openResult = await OpenFilex.open(apkPath);
                        if (openResult.type != ResultType.done) {
                          debugPrint("OpenFilex failed to open APK: ${openResult.message}. Falling back to browser...");
                          final Uri fallbackUri = Uri.parse(downloadUrl);
                          await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
                        }
                      },
                      onError: (err) {
                        setDialogState(() {
                          isDownloading = false;
                          statusText = '';
                          progress = 0.0;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Download failed: $err'), backgroundColor: Colors.red),
                        );
                      },
                    );
                  },
                  child: const Text('Download & Install'),
                ),
              ] else ...[
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                  },
                  child: const Text('Cancel'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _startDownload({
    required String url,
    required void Function(double progress, String status) onProgress,
    required void Function(String apkPath) onComplete,
    required void Function(String error) onError,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final apkPath = "${tempDir.path}/AttendX_Update.apk";

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);
      final contentLength = response.contentLength ?? 0;

      if (response.statusCode != 200) {
        onError("Http server returned error code ${response.statusCode}");
        client.close();
        return;
      }

      final file = File(apkPath);
      final sink = file.openWrite();
      int downloadedBytes = 0;

      response.stream.listen(
        (chunk) {
          sink.add(chunk);
          downloadedBytes += chunk.length;
          final double p = contentLength > 0 ? (downloadedBytes / contentLength) : 0.0;
          final sizeMb = (contentLength / (1024 * 1024)).toStringAsFixed(1);
          final downloadedMb = (downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
          onProgress(p, "Downloading APK ($downloadedMb MB / $sizeMb MB)...");
        },
        onDone: () async {
          await sink.close();
          client.close();
          onComplete(apkPath);
        },
        onError: (err) {
          sink.close();
          client.close();
          onError(err.toString());
        },
        cancelOnError: true,
      );
    } catch (e) {
      onError(e.toString());
    }
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
