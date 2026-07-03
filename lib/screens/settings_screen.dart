import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import '../services/drive_service.dart';
import '../database/database_helper.dart';
import '../providers/attendance_provider.dart';
import '../models/subject.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = Provider.of<SettingsProvider>(context);

    if (!settings.isLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(context, 'Data Backup & Restore'),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainer,
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
            elevation: 0,
            color: theme.colorScheme.surfaceContainer,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.flag),
                  title: const Text('Target Attendance Percentage'),
                  trailing: Text('${settings.targetPercentage.toInt()}%'),
                  onTap: () => _showTargetPercentageDialog(context, settings),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Timetable Global Settings'),
                  subtitle: const Text('Start/End times, periods and lunch duration'),
                  onTap: () => _showGlobalTimetableSettings(context, settings),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.calendar_view_week),
                  title: const Text('Periods Per Day'),
                  subtitle: const Text('Number of periods from Monday to Saturday'),
                  onTap: () => _showPeriodsPerDaySettings(context, settings),
                ),
              ],
            ),
          ),
        ],
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

  void _showTargetPercentageDialog(BuildContext context, SettingsProvider settings) {
    double tempVal = settings.targetPercentage;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Target Attendance %'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${tempVal.toInt()}%',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: tempVal,
                    min: 50,
                    max: 100,
                    divisions: 50,
                    onChanged: (val) {
                      setState(() {
                        tempVal = val;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    await settings.setTargetPercentage(tempVal);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showGlobalTimetableSettings(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return TimetableSetupSheet(
          initialStartMins: settings.collegeStartTimeMinutes,
          initialEndMins: settings.collegeEndTimeMinutes,
          initialPeriodMins: settings.periodDurationMinutes,
          initialLunchMins: settings.lunchBreakDurationMinutes,
          initialLunchIndex: settings.lunchPeriodIndex,
          onSave: (start, end, period, lunch, lunchIdx) async {
            await settings.updateTimetableSettings(
              start: start,
              end: end,
              period: period,
              lunch: lunch,
              lunchIdx: lunchIdx,
            );
          },
        );
      },
    );
  }

  void _showPeriodsPerDaySettings(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return PerDayPeriodsSheet(
          initialPeriodsString: settings.periodsPerDayString,
          onSave: (val) async {
            await settings.setPeriodsPerDayString(val);
          },
        );
      },
    );
  }

  // --- Device Backup ---
  Future<void> _backupToDevice(BuildContext context) async {
    try {
      final dbFolder = await getDatabasesPath();
      final dbPath = p.join(dbFolder, 'attendx_database');
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No database found to backup.')),
          );
        }
        return;
      }

      await DatabaseHelper().checkpoint();

      String? selectedDirectory = await FilePicker.getDirectoryPath();
      if (selectedDirectory != null) {
        final backupFile = File(p.join(selectedDirectory, 'attendx_database_backup.db'));
        await dbFile.copy(backupFile.path);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Backup saved to ${backupFile.path}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to backup: $e')),
        );
      }
    }
  }

  Future<void> _restoreFromDevice(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(type: FileType.any);

      if (result != null && result.files.single.path != null) {
        final selectedFile = File(result.files.single.path!);

        final dbFolder = await getDatabasesPath();
        final dbPath = p.join(dbFolder, 'attendx_database');
        final dbFile = File(dbPath);
        final walFile = File('$dbPath-wal');
        final shmFile = File('$dbPath-shm');

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
              content: const Text(
                  'Data restored successfully. Please restart the app for changes to take effect.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Reload data in provider
                    Provider.of<AttendanceProvider>(context, listen: false).loadData();
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore: $e')),
        );
      }
    }
  }

  // --- Drive Backup ---
  Future<void> _backupToDrive(BuildContext context) async {
    try {
      final driveService = DriveService();
      await driveService.backupDatabase();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backed up to Google Drive successfully!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to backup to Drive: $e')),
        );
      }
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
            content: const Text(
                'Data restored from Drive successfully. Please restart the app for changes to take effect.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Provider.of<AttendanceProvider>(context, listen: false).loadData();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore from Drive: $e')),
        );
      }
    }
  }

  Future<void> _exportToCSV(BuildContext context) async {
    try {
      final attendance = Provider.of<AttendanceProvider>(context, listen: false);
      final records = attendance.allAttendance;
      final subjects = attendance.subjects;

      if (records.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No attendance records to export.')),
          );
        }
        return;
      }

      final buffer = StringBuffer();
      buffer.writeln('Date,Subject,Status');

      for (var record in records) {
        final subject = subjects.firstWhere(
            (s) => s.id == (record.actualSubjectId ?? record.scheduledSubjectId),
            orElse: () => Subject(
                id: -1,
                name: 'Unknown',
                code: 'UNK',
                facultyName: '',
                colorHex: '',
                createdAt: 0));
        final date = DateTime.fromMillisecondsSinceEpoch(record.date);
        buffer.writeln('${date.toIso8601String().split('T')[0]},${subject.name},${record.status}');
      }

      String? selectedDirectory = await FilePicker.getDirectoryPath();
      if (selectedDirectory != null) {
        final exportFile = File(
            p.join(selectedDirectory, 'attendx_export_${DateTime.now().millisecondsSinceEpoch}.csv'));
        await exportFile.writeAsString(buffer.toString());
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Export saved to ${exportFile.path}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export CSV: $e')),
        );
      }
    }
  }
}

// --- Timetable Setup Bottom Sheet ---
class TimetableSetupSheet extends StatefulWidget {
  final int initialStartMins;
  final int initialEndMins;
  final int initialPeriodMins;
  final int initialLunchMins;
  final int initialLunchIndex;
  final Function(int start, int end, int period, int lunch, int lunchIdx) onSave;

  const TimetableSetupSheet({
    super.key,
    required this.initialStartMins,
    required this.initialEndMins,
    required this.initialPeriodMins,
    required this.initialLunchMins,
    required this.initialLunchIndex,
    required this.onSave,
  });

  @override
  State<TimetableSetupSheet> createState() => _TimetableSetupSheetState();
}

class _TimetableSetupSheetState extends State<TimetableSetupSheet> {
  late TextEditingController _startController;
  late TextEditingController _endController;
  late TextEditingController _periodController;
  late TextEditingController _lunchController;
  late TextEditingController _lunchIndexController;

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController(text: _formatMinsToTime(widget.initialStartMins));
    _endController = TextEditingController(text: _formatMinsToTime(widget.initialEndMins));
    _periodController = TextEditingController(text: widget.initialPeriodMins.toString());
    _lunchController = TextEditingController(text: widget.initialLunchMins.toString());
    _lunchIndexController = TextEditingController(text: widget.initialLunchIndex.toString());
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _periodController.dispose();
    _lunchController.dispose();
    _lunchIndexController.dispose();
    super.dispose();
  }

  String _formatMinsToTime(int minutes) {
    final h = (minutes / 60).floor() % 24;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  int _parseTimeToMins(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length != 2) return 540;
    final h = int.tryParse(parts[0]) ?? 9;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Timetable Global Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter time as HH:MM (24-hour)',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _startController,
                  decoration: const InputDecoration(
                    labelText: 'Start Time',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.datetime,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _endController,
                  decoration: const InputDecoration(
                    labelText: 'End Time',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.datetime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _periodController,
                  decoration: const InputDecoration(
                    labelText: 'Period (mins)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _lunchController,
                  decoration: const InputDecoration(
                    labelText: 'Lunch (mins)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lunchIndexController,
            decoration: const InputDecoration(
              labelText: 'Lunch is after Period #',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                final start = _parseTimeToMins(_startController.text);
                final end = _parseTimeToMins(_endController.text);
                final period = int.tryParse(_periodController.text) ?? 50;
                final lunch = int.tryParse(_lunchController.text) ?? 45;
                final lunchIdx = int.tryParse(_lunchIndexController.text) ?? 4;

                widget.onSave(start, end, period, lunch, lunchIdx);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Save Timetable', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Periods Per Day Bottom Sheet ---
class PerDayPeriodsSheet extends StatefulWidget {
  final String initialPeriodsString;
  final Function(String val) onSave;

  const PerDayPeriodsSheet({
    super.key,
    required this.initialPeriodsString,
    required this.onSave,
  });

  @override
  State<PerDayPeriodsSheet> createState() => _PerDayPeriodsSheetState();
}

class _PerDayPeriodsSheetState extends State<PerDayPeriodsSheet> {
  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    List<int> defaultVals;
    if (widget.initialPeriodsString.contains(':')) {
      // Handle Flutter format: "1:6,2:6,3:6,4:6,5:6,6:6"
      final Map<int, int> map = {};
      for (var part in widget.initialPeriodsString.split(',')) {
        final kv = part.split(':');
        if (kv.length == 2) {
          final k = int.tryParse(kv[0]);
          final v = int.tryParse(kv[1]);
          if (k != null && v != null) {
            map[k] = v;
          }
        }
      }
      defaultVals = List.generate(6, (i) => map[i + 1] ?? 6);
    } else {
      // Handle Compose format: "7,7,7,7,7,4"
      defaultVals = widget.initialPeriodsString
          .split(',')
          .map((x) => int.tryParse(x.trim()) ?? 7)
          .toList();
      while (defaultVals.length < 6) {
        defaultVals.add(7);
      }
    }

    _controllers = List.generate(
      6,
      (i) => TextEditingController(text: defaultVals[i].toString()),
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Periods Per Day',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: 6,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _days[index],
                        style: const TextStyle(fontSize: 16),
                      ),
                      SizedBox(
                        width: 100,
                        height: 45,
                        child: TextField(
                          controller: _controllers[index],
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                // Save in Flutter format: "1:X,2:Y..."
                final List<String> list = [];
                for (int i = 0; i < 6; i++) {
                  final val = int.tryParse(_controllers[i].text) ?? 6;
                  list.add('${i + 1}:$val');
                }
                widget.onSave(list.join(','));
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Save Periods', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
