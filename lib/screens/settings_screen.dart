import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import '../services/drive_service.dart';
import 'package:sqflite/sqflite.dart';
import '../providers/attendance_provider.dart';
import '../models/subject.dart';
import '../database/database_helper.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          if (!settings.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader(context, 'Data Backup & Restore'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.cloud_upload),
                      title: const Text('Backup to Device'),
                      subtitle: const Text('Save a copy of your data locally'),
                      onTap: () => _backupToDevice(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.settings_backup_restore),
                      title: const Text('Restore from Device'),
                      subtitle: const Text('Restore data from a local backup'),
                      onTap: () => _restoreFromDevice(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.cloud, color: Colors.blue),
                      title: const Text('Backup to Google Drive'),
                      subtitle: const Text('Safely backup to cloud'),
                      onTap: () => _backupToDrive(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.cloud_download, color: Colors.blue),
                      title: const Text('Restore from Google Drive'),
                      subtitle: const Text('Restore from cloud backup'),
                      onTap: () => _restoreFromDrive(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.file_download, color: Colors.green),
                      title: const Text('Export to CSV'),
                      subtitle: const Text('Export attendance records to a spreadsheet'),
                      onTap: () => _exportToCSV(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'Preferences'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.flag),
                      title: const Text('Target Attendance Percentage'),
                      trailing: Text('${settings.targetPercentage}%'),
                      onTap: () {
                        // Show dialog to change target
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Future<void> _backupToDevice(BuildContext context) async {
    try {
      final dbFolder = await getDatabasesPath();
      final dbPath = p.join(dbFolder, 'attendx_database');
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No database found to backup.')));
        return;
      }
      
      await DatabaseHelper().checkpoint();

      String? selectedDirectory = await FilePicker.getDirectoryPath();
      if (selectedDirectory != null) {
        final backupFile = File(p.join(selectedDirectory, 'attendx_database_backup.db'));
        await dbFile.copy(backupFile.path);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup saved to ${backupFile.path}')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to backup: $e')));
    }
  }

  Future<void> _restoreFromDevice(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final selectedFile = File(result.files.single.path!);
        
        final dbFolder = await getDatabasesPath();
        final dbPath = p.join(dbFolder, 'attendx_database');
        final dbFile = File(dbPath);
        final walFile = File('${dbPath}-wal');
        final shmFile = File('${dbPath}-shm');

        await DatabaseHelper().closeDatabase();

        await selectedFile.copy(dbFile.path);
        
        if (await walFile.exists()) await walFile.delete();
        if (await shmFile.exists()) await shmFile.delete();
        
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Restore Complete'),
              content: const Text('Data restored successfully. Please restart the app for changes to take effect.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to restore: $e')));
    }
  }

  Future<void> _backupToDrive(BuildContext context) async {
    try {
      final driveService = DriveService();
      await driveService.backupDatabase();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backed up to Google Drive successfully!')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to backup to Drive: $e')));
    }
  }

  Future<void> _restoreFromDrive(BuildContext context) async {
    try {
      final driveService = DriveService();
      await driveService.restoreDatabase();
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Restore Complete'),
            content: const Text('Data restored from Drive successfully. Please restart the app for changes to take effect.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to restore from Drive: $e')));
    }
  }

  Future<void> _exportToCSV(BuildContext context) async {
    try {
      final attendance = Provider.of<AttendanceProvider>(context, listen: false);
      final records = attendance.allAttendance;
      final subjects = attendance.subjects;

      if (records.isEmpty) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No attendance records to export.')));
        return;
      }

      final buffer = StringBuffer();
      buffer.writeln('Date,Subject,Status');

      for (var record in records) {
        final subject = subjects.firstWhere((s) => s.id == (record.actualSubjectId ?? record.scheduledSubjectId), orElse: () => Subject(id: -1, name: 'Unknown', code: 'UNK', facultyName: '', colorHex: '', createdAt: 0));
        final date = DateTime.fromMillisecondsSinceEpoch(record.date);
        buffer.writeln('${date.toIso8601String().split('T')[0]},${subject.name},${record.status}');
      }

      String? selectedDirectory = await FilePicker.getDirectoryPath();
      if (selectedDirectory != null) {
        final exportFile = File(p.join(selectedDirectory, 'attendx_export_${DateTime.now().millisecondsSinceEpoch}.csv'));
        await exportFile.writeAsString(buffer.toString());
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export saved to ${exportFile.path}')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to export CSV: $e')));
    }
  }
}
