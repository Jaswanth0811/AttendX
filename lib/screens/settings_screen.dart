import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
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
import '../models/holiday.dart';
import 'attendance_history_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  GoogleSignInAccount? _googleUser;
  String _appVersion = '1.0.8';

  @override
  void initState() {
    super.initState();
    _checkGoogleSignInStatus();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
        });
      }
    } catch (_) {}
  }

  Future<void> _checkGoogleSignInStatus() async {
    try {
      final user = await DriveService.googleSignIn.signInSilently();
      if (mounted) {
        setState(() {
          _googleUser = user;
        });
      }
    } catch (e) {
      debugPrint("Google silent sign in check failed: $e");
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      final user = await DriveService.googleSignIn.signIn();
      if (mounted) {
        setState(() {
          _googleUser = user;
        });
      }
    } catch (e) {
      _showGoogleSignInError(e);
    }
  }

  Future<void> _signOutWithGoogle() async {
    try {
      await DriveService.googleSignIn.signOut();
      if (mounted) {
        setState(() {
          _googleUser = null;
        });
      }
    } catch (e) {
      debugPrint("Failed to sign out: $e");
    }
  }

  void _showGoogleSignInError(Object error) {
    if (!mounted) return;
    final errorStr = error.toString();
    String message = "Sign in failed: $error";
    bool showInstructions = false;
    
    if (errorStr.contains("sign_in_failed") || errorStr.contains("10")) {
      message = "Google Sign-In failed (Error 10: Developer Error).\n\n"
          "This typically means the SHA-1 signing fingerprint of this app release is not registered in the Google Cloud / Firebase Console under the package name 'com.attendx.attendx'.";
      showInstructions = true;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text("Google Sign-In Error"),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Dismiss"),
          ),
          if (showInstructions)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showGoogleSignInSetupGuide();
              },
              child: const Text("Setup Guide"),
            ),
        ],
      ),
    );
  }

  void _showGoogleSignInSetupGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Firebase / Google API Setup Guide"),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("1. Open Google API Console or Firebase Console.", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("2. Navigate to project settings and add an Android App."),
              Text("3. Set Package Name to:"),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 4.0),
                child: SelectionArea(
                  child: Text(
                    "com.attendx.attendx",
                    style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ),
              ),
              Text("4. Under SHA-1 Fingerprints, add the SHA-1 of the keystore used to sign the APK. (Check google_signin_instructions.md in workspace for details.)"),
              SizedBox(height: 8),
              Text("Once added, Google Cloud will authorize the requests and backup will work instantly!"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = Provider.of<SettingsProvider>(context);
    final attendance = Provider.of<AttendanceProvider>(context);

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
                // Google Account Connection Status
                ListTile(
                  leading: Icon(
                    _googleUser != null ? Icons.account_circle : Icons.account_circle_outlined,
                    color: _googleUser != null ? Colors.blue : Colors.grey,
                    size: 28,
                  ),
                  title: Text(_googleUser != null ? 'Connected to Google' : 'Google Account'),
                  subtitle: Text(_googleUser != null ? _googleUser!.email : 'Not connected (Sign in for cloud backup)'),
                  trailing: TextButton(
                    onPressed: _googleUser != null ? _signOutWithGoogle : _signInWithGoogle,
                    child: Text(_googleUser != null ? 'Sign Out' : 'Sign In'),
                  ),
                ),
                const Divider(height: 1),
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
                SwitchListTile.adaptive(
                  secondary: const Icon(Icons.sync, color: Colors.blue),
                  title: const Text('Auto-Sync (Google Drive)'),
                  subtitle: const Text('Sync data across devices automatically'),
                  value: settings.autoSync,
                  onChanged: (val) async {
                    if (val) {
                      if (_googleUser == null) {
                        await _signInWithGoogle();
                        if (_googleUser == null) return;
                      }
                      await settings.setAutoSync(true);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Auto-sync enabled! Syncing database...')),
                        );
                        try {
                          await DriveService().backupDatabase(silentOnly: true);
                        } catch (_) {}
                      }
                    } else {
                      await settings.setAutoSync(false);
                    }
                  },
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  secondary: const Icon(Icons.notifications_active, color: Colors.purple),
                  title: const Text('Daily Attendance Reminders'),
                  subtitle: const Text('Remind me at 5:00 PM to mark daily attendance'),
                  value: settings.dailyReminders,
                  onChanged: (val) async {
                    await settings.setDailyReminders(val);
                    await NotificationService().scheduleDailySetupReminder(val);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(val ? 'Daily reminders enabled!' : 'Daily reminders disabled!')),
                      );
                    }
                  },
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
                  leading: const Icon(Icons.date_range),
                  title: const Text('Semester Setup'),
                  subtitle: Text(
                    'Start: ${DateFormat('yyyy-MM-dd').format(settings.semesterStartDate)} | End: ${DateFormat('yyyy-MM-dd').format(settings.semesterEndDate)}',
                  ),
                  onTap: () => _selectSemesterDates(context, settings),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.filter_alt),
                  title: const Text('Select Calculated Subjects'),
                  subtitle: const Text('Choose which subjects count in overall %'),
                  onTap: () => _showSubjectsCalculationDialog(context, settings, attendance),
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
          const SizedBox(height: 24),

          _buildSectionHeader(context, 'Holidays'),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainer,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.celebration, color: Colors.orange),
                  title: const Text('Manage Holidays'),
                  subtitle: Text('${attendance.holidays.length} holidays added'),
                  onTap: () => _showHolidaysManagementSheet(context, attendance),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.add_circle_outline, color: Colors.orange),
                  title: const Text('Add Single Holiday'),
                  onTap: () => _showAddSingleHolidayDialog(context, attendance),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.date_range, color: Colors.orange),
                  title: const Text('Add Holiday Range'),
                  subtitle: const Text('e.g., Semester break, festival week'),
                  onTap: () => _showAddHolidayRangeDialog(context, attendance),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildSectionHeader(context, 'History & Info'),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainer,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Attendance History'),
                  subtitle: const Text('View and manage all past records'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AttendanceHistoryScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                 ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About AttendX'),
                  subtitle: Text('Version $_appVersion'),
                  onTap: () => _showAboutDialog(context),
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

  Future<void> _selectSemesterDates(BuildContext context, SettingsProvider settings) async {
    final initialRange = DateTimeRange(
      start: settings.semesterStartDate,
      end: settings.semesterEndDate,
    );
    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: initialRange,
    );
    if (pickedRange != null) {
      await settings.updateSemesterDates(pickedRange.start, pickedRange.end);
    }
  }

  void _showSubjectsCalculationDialog(BuildContext context, SettingsProvider settings, AttendanceProvider attendance) {
    if (attendance.subjects.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Calculated Subjects'),
          content: const Text('No subjects added yet. Please add subjects first.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Calculated Subjects'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: attendance.subjects.length,
                  itemBuilder: (context, index) {
                    final subject = attendance.subjects[index];
                    final isCalculated = !settings.excludedSubjectIds.contains(subject.id);
                    return CheckboxListTile(
                      title: Text(subject.name),
                      subtitle: Text(subject.code),
                      value: isCalculated,
                      onChanged: (val) async {
                        if (val != null && subject.id != null) {
                          await settings.toggleSubjectCalculation(subject.id!, val);
                          setState(() {});
                        }
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About AttendX'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AttendX',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text('Version: $_appVersion'),
            const SizedBox(height: 16),
            const Text(
              'AttendX is an offline-first college attendance manager built to keep your schedules tracked and help you calculate bunk days safely.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Developed by Jaswanth0811',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
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
    if (_googleUser == null) {
      await _signInWithGoogle();
      if (_googleUser == null) return;
    }
    try {
      final driveService = DriveService();
      await driveService.backupDatabase();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backed up to Google Drive successfully!')),
        );
      }
    } catch (e) {
      _showGoogleSignInError(e);
    }
  }

  Future<void> _restoreFromDrive(BuildContext context) async {
    if (_googleUser == null) {
      await _signInWithGoogle();
      if (_googleUser == null) return;
    }
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
      _showGoogleSignInError(e);
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

  // --- Holiday Management ---
  void _showHolidaysManagementSheet(BuildContext context, AttendanceProvider attendance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final holidays = attendance.holidays;
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.3,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.celebration, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('All Holidays', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: holidays.isEmpty
                          ? const Center(
                              child: Text('No holidays added yet.', style: TextStyle(color: Colors.grey)),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: holidays.length,
                              itemBuilder: (context, index) {
                                final holiday = holidays[index];
                                final date = DateTime.fromMillisecondsSinceEpoch(holiday.date);
                                return ListTile(
                                  leading: const Icon(Icons.event, color: Colors.orange),
                                  title: Text(holiday.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(DateFormat('EEEE, MMM d, yyyy').format(date)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () {
                                      attendance.deleteHoliday(holiday.id!);
                                      setModalState(() {});
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showAddSingleHolidayDialog(BuildContext context, AttendanceProvider attendance) async {
    final nameController = TextEditingController();
    DateTime? selectedDate;

    selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (selectedDate == null || !context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Holiday'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('EEEE, MMM d, yyyy').format(selectedDate!),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Holiday Name',
                hintText: 'e.g., Independence Day',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty && selectedDate != null) {
                final dateMillis = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day).millisecondsSinceEpoch;
                attendance.addHoliday(Holiday(
                  date: dateMillis,
                  name: name,
                  createdAt: DateTime.now().millisecondsSinceEpoch,
                ));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Holiday "$name" added!')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddHolidayRangeDialog(BuildContext context, AttendanceProvider attendance) async {
    final nameController = TextEditingController();
    DateTimeRange? selectedRange;

    selectedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (selectedRange == null || !context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Holiday Range'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${DateFormat('MMM d').format(selectedRange!.start)} — ${DateFormat('MMM d, yyyy').format(selectedRange!.end)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              '${selectedRange!.end.difference(selectedRange!.start).inDays + 1} days',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Holiday Name',
                hintText: 'e.g., Dussehra Break',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty && selectedRange != null) {
                attendance.addHolidayRange(name, selectedRange!.start, selectedRange!.end);
                Navigator.pop(ctx);
                final days = selectedRange!.end.difference(selectedRange!.start).inDays + 1;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$days holiday days added for "$name"!')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
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

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final controller = isStart ? _startController : _endController;
    final parts = controller.text.split(':');
    final initialHour = parts.length == 2 ? (int.tryParse(parts[0]) ?? 9) : 9;
    final initialMinute = parts.length == 2 ? (int.tryParse(parts[1]) ?? 0) : 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
    );

    if (picked != null) {
      final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isStart) {
          _startController.text = formatted;
        } else {
          _endController.text = formatted;
        }
      });
    }
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
            'Tap fields to select time using clock',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _startController,
                  readOnly: true,
                  onTap: () => _selectTime(context, true),
                  decoration: const InputDecoration(
                    labelText: 'Start Time',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.access_time),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _endController,
                  readOnly: true,
                  onTap: () => _selectTime(context, false),
                  decoration: const InputDecoration(
                    labelText: 'End Time',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.access_time),
                  ),
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
