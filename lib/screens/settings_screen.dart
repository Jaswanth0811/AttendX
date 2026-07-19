import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import '../providers/settings_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import '../services/neon_service.dart';
import '../services/drive_service.dart';
import '../database/database_helper.dart';
import '../providers/attendance_provider.dart';
import '../models/subject.dart';
import '../models/holiday.dart';
import '../models/special_timetable.dart';
import '../models/special_schedule.dart';
import 'attendance_history_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  GoogleSignInAccount? _googleUser;
  String _appVersion = '1.1.4';
  bool _testingConnection = false;
  bool _neonConnected = false;
  String _lastBackupStatus = 'None';
  String _lastBackupTime = 'Never';
  String _localDbSize = 'Unknown';
  String _lastDriveBackupTime = 'Never';

  @override
  @override
  void initState() {
    super.initState();
    _checkGoogleSignInStatus();
    _loadAppVersion();
    _loadBackupDetails();
  }

  Future<void> _loadBackupDetails() async {
    final prefs = await SharedPreferences.getInstance();
    
    String dbSizeStr = 'Unknown';
    try {
      final dbFolder = await getDatabasesPath();
      final dbPath = p.join(dbFolder, 'attendx_database');
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        final length = await dbFile.length();
        dbSizeStr = '${(length / 1024).toStringAsFixed(1)} KB';
      }
    } catch (_) {}

    final status = prefs.getString('last_db_backup_status') ?? 'None';
    final timeStr = prefs.getString('last_db_backup_time') ?? '';
    
    String formattedTime = 'Never';
    if (timeStr.isNotEmpty) {
      final parsed = DateTime.tryParse(timeStr);
      if (parsed != null) {
        formattedTime = DateFormat('yyyy-MM-dd hh:mm a').format(parsed.toLocal());
      }
    }

    final driveTimeStr = prefs.getString('last_synced_drive_time') ?? '';
    String formattedDriveTime = 'Never';
    if (driveTimeStr.isNotEmpty) {
      final parsed = DateTime.tryParse(driveTimeStr);
      if (parsed != null) {
        formattedDriveTime = DateFormat('yyyy-MM-dd hh:mm a').format(parsed.toLocal());
      }
    }

    if (mounted) {
      setState(() {
        _lastBackupStatus = status;
        _lastBackupTime = formattedTime;
        _localDbSize = dbSizeStr;
        _lastDriveBackupTime = formattedDriveTime;
      });
    }

    if (mounted) {
      setState(() {
        _testingConnection = true;
      });
    }
    final isConnected = await NeonService().testConnection();
    if (mounted) {
      setState(() {
        _neonConnected = isConnected;
        _testingConnection = false;
      });
    }
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
      final user = await NeonService.googleSignIn.signInSilently();
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
      final user = await NeonService.googleSignIn.signIn();
      if (mounted) {
        setState(() {
          _googleUser = user;
        });
      }
      _loadBackupDetails();
    } catch (e) {
      _showGoogleSignInError(e);
    }
  }

  Future<void> _signOutWithGoogle() async {
    try {
      await NeonService.googleSignIn.signOut();
      if (mounted) {
        setState(() {
          _googleUser = null;
        });
      }
      _loadBackupDetails();
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
                  title: const Text('Backup to Cloud Database'),
                  subtitle: const Text('Safely backup to Neon PostgreSQL'),
                  onTap: () => _backupToNeon(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_download, color: Colors.blue),
                  title: const Text('Restore from Cloud Database'),
                  subtitle: const Text('Restore from Neon PostgreSQL backup'),
                  onTap: () => _restoreFromNeon(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_queue, color: Colors.green),
                  title: const Text('Backup to Google Drive (Fallback)'),
                  subtitle: const Text('Secondary fallback cloud backup'),
                  onTap: () => _backupToDrive(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings_backup_restore, color: Colors.green),
                  title: const Text('Restore from Google Drive (Fallback)'),
                  subtitle: const Text('Restore from secondary fallback backup'),
                  onTap: () => _restoreFromDrive(context),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  secondary: const Icon(Icons.sync, color: Colors.blue),
                  title: const Text('Auto-Sync (Cloud Database)'),
                  subtitle: const Text('Automatically backup/sync every 2 hours'),
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
                          await NeonService().backupDatabase();
                        } catch (_) {}
                      }
                    } else {
                      await settings.setAutoSync(false);
                    }
                    _loadBackupDetails();
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

          _buildSectionHeader(context, 'Backup Details'),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainer,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Connection Status:', style: TextStyle(fontWeight: FontWeight.w600)),
                      _testingConnection
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : Row(
                              children: [
                                Icon(
                                  _neonConnected ? Icons.cloud_done : Icons.cloud_off,
                                  color: _neonConnected ? Colors.green : Colors.red,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _neonConnected ? 'Connected to Neon' : 'Offline / Disconnected',
                                  style: TextStyle(
                                    color: _neonConnected ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Last Backup Status:', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        _lastBackupStatus,
                        style: TextStyle(
                          color: _lastBackupStatus == 'Success' || _lastBackupStatus.contains('Success')
                              ? Colors.green
                              : (_lastBackupStatus == 'None' ? Colors.grey : Colors.red),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Last Backup Time:', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(_lastBackupTime),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Local Database Size:', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(_localDbSize),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Last Google Drive Sync:', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(_lastDriveBackupTime),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Account Info:', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(_googleUser != null ? _googleUser!.email : 'No email connection'),
                    ],
                  ),
                ],
              ),
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
                  subtitle: const Text('Start/End times, period/class duration and lunch duration'),
                  onTap: () => _showGlobalTimetableSettings(context, settings),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.calendar_view_week),
                  title: const Text('Periods or Classes Per Day'),
                  subtitle: const Text('Number of periods or classes from Monday to Saturday (excluding Lunch Period)'),
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

          _buildSectionHeader(context, 'Special Schedules'),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainer,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.event_note, color: Colors.deepPurple),
                  title: const Text('Manage Special Schedules'),
                  subtitle: Text('${attendance.specialSchedules.length} schedules added'),
                  onTap: () => _showSpecialScheduleManagementSheet(context, attendance),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.add_circle_outline, color: Colors.deepPurple),
                  title: const Text('Add Special Schedule'),
                  subtitle: const Text('Courses, workshops, exams, events'),
                  onTap: () => _showAddSpecialScheduleDialog(context, attendance),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.swap_calls, color: Colors.deepPurple),
                  title: const Text('Day Swaps'),
                  subtitle: Text('${attendance.specialTimetables.length} overrides configured'),
                  onTap: () => _showSpecialTimetableManagementSheet(context, attendance),
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
                  leading: const Icon(Icons.system_update_alt_outlined),
                  title: const Text('Check for Updates'),
                  subtitle: const Text('Check GitHub for new releases'),
                  onTap: () => UpdateService().checkForUpdates(context),
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
          initialLunchStartMins: settings.lunchStartTimeMinutes,
          initialLunchEndMins: settings.lunchEndTimeMinutes,
          onSave: (start, end, period, lunchStart, lunchEnd) async {
            await settings.updateTimetableSettings(
              start: start,
              end: end,
              period: period,
              lunchStart: lunchStart,
              lunchEnd: lunchEnd,
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

  // --- Google Drive Backup & Restore (Fallback) ---
  Future<void> _backupToDrive(BuildContext context) async {
    if (_googleUser == null) {
      await _signInWithGoogle();
      if (_googleUser == null) return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Uploading database to Google Drive...'),
          ],
        ),
      ),
    );

    try {
      final driveService = DriveService();
      final uploadedTime = await driveService.backupDatabase();
      
      if (context.mounted) {
        Navigator.pop(context); // Pop loading dialog
        if (uploadedTime != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('last_synced_drive_time', uploadedTime.toIso8601String());
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backed up to Google Drive successfully!'), backgroundColor: Colors.green),
        );
      }
      _loadBackupDetails();
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Pop loading dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Backup Failed'),
            content: Text('Could not backup to Google Drive. Error: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      _loadBackupDetails();
    }
  }

  Future<void> _restoreFromDrive(BuildContext context) async {
    if (_googleUser == null) {
      await _signInWithGoogle();
      if (_googleUser == null) return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Data'),
        content: const Text(
          'This will overwrite your local database with the database stored in Google Drive. '
          'Any unsaved changes on this device will be lost. Proceed?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Restoring database from Google Drive...'),
          ],
        ),
      ),
    );

    try {
      final driveService = DriveService();
      final restoredTime = await driveService.restoreDatabase();
      
      if (context.mounted) {
        Navigator.pop(context); // Pop loading dialog
        if (restoredTime != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('last_synced_drive_time', restoredTime.toIso8601String());
        }
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Restore Complete'),
            content: const Text('Data restored from Google Drive successfully.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Provider.of<AttendanceProvider>(context, listen: false).loadData();
                  Provider.of<SettingsProvider>(context, listen: false).reloadSettings();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      _loadBackupDetails();
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Pop loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore from Drive: $e')),
        );
      }
      _loadBackupDetails();
    }
  }

  // --- Neon Cloud Backup & Restore ---
  Future<void> _backupToNeon(BuildContext context) async {
    if (_googleUser == null) {
      await _signInWithGoogle();
      if (_googleUser == null) return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Uploading database to Neon...'),
          ],
        ),
      ),
    );

    try {
      final neonService = NeonService();
      await neonService.backupDatabase();
      
      if (context.mounted) {
        Navigator.pop(context); // Pop loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backed up to Neon database successfully!'), backgroundColor: Colors.green),
        );
      }
      _loadBackupDetails();
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Pop loading dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Backup Failed'),
            content: Text('Could not backup to Neon database. Error: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      _loadBackupDetails();
    }
  }

  Future<void> _restoreFromNeon(BuildContext context) async {
    if (_googleUser == null) {
      await _signInWithGoogle();
      if (_googleUser == null) return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Data'),
        content: const Text(
          'This will overwrite your local database with the database stored in Neon. '
          'Any unsaved changes on this device will be lost. Proceed?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Restoring database from Neon...'),
          ],
        ),
      ),
    );

    try {
      final neonService = NeonService();
      await neonService.restoreDatabase();
      
      if (context.mounted) {
        Navigator.pop(context); // Pop loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Restore Complete'),
            content: const Text('Data restored from Neon successfully. Please restart the app for changes to take effect.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Provider.of<AttendanceProvider>(context, listen: false).loadData();
                  Provider.of<SettingsProvider>(context, listen: false).reloadSettings();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      _loadBackupDetails();
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Pop loading dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Restore Failed'),
            content: Text('Could not restore from Neon database. Error: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      _loadBackupDetails();
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

  void _showSpecialScheduleManagementSheet(BuildContext context, AttendanceProvider attendance) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.event_note, color: Colors.deepPurple, size: 28),
                    const SizedBox(width: 10),
                    Text('Special Schedules', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.deepPurple, size: 28),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showAddSpecialScheduleDialog(context, attendance);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: attendance.specialSchedules.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text('No special schedules yet', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('Add courses, workshops, exams, or events', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: attendance.specialSchedules.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final ss = attendance.specialSchedules[i];
                        final start = DateTime.fromMillisecondsSinceEpoch(ss.startDateMillis);
                        final end = DateTime.fromMillisecondsSinceEpoch(ss.endDateMillis);
                        final subject = attendance.subjects.where((s) => s.id == ss.subjectId).firstOrNull;
                        final subjectName = subject?.name ?? 'Unknown Subject';
                        final now = DateTime.now();
                        final todayMillis = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
                        final isActive = ss.isActiveForDate(todayMillis);
                        final isPast = todayMillis > ss.endDateMillis;

                        // Type icon
                        IconData typeIcon;
                        Color typeColor;
                        switch (ss.scheduleType.toLowerCase()) {
                          case 'course': typeIcon = Icons.school; typeColor = Colors.deepPurple; break;
                          case 'workshop': typeIcon = Icons.build_circle; typeColor = Colors.teal; break;
                          case 'exam': typeIcon = Icons.quiz; typeColor = Colors.red; break;
                          case 'event': typeIcon = Icons.celebration; typeColor = Colors.orange; break;
                          default: typeIcon = Icons.event_note; typeColor = Colors.blueGrey;
                        }

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: typeColor.withOpacity(0.15),
                            child: Icon(typeIcon, color: typeColor, size: 22),
                          ),
                          title: Row(
                            children: [
                              Expanded(child: Text(ss.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                              if (isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Active', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                                )
                              else if (isPast)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Ended', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text('$subjectName  •  ${ss.scheduleType}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              Text(
                                '${start.day}/${start.month}/${start.year} → ${end.day}/${end.month}/${end.year}  •  ${ss.dailyStartTime} - ${ss.dailyEndTime}',
                                style: TextStyle(color: Colors.grey[500], fontSize: 11),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (dCtx) => AlertDialog(
                                  title: const Text('Delete Schedule'),
                                  content: Text('Remove "${ss.name}"?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                                    TextButton(
                                      onPressed: () => Navigator.pop(dCtx, true),
                                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true && ss.id != null) {
                                await attendance.deleteSpecialSchedule(ss.id!);
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('"${ss.name}" deleted'), backgroundColor: Colors.redAccent),
                                  );
                                }
                              }
                            },
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddSpecialScheduleDialog(BuildContext context, AttendanceProvider attendance) {
    final theme = Theme.of(context);
    final nameController = TextEditingController();
    final typeController = TextEditingController(text: 'Course');
    final otherClassController = TextEditingController();
    String classSelection = 'Subject';
    int? selectedSubjectId;
    DateTimeRange? dateRange;
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 16, minute: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final dateRangeText = dateRange != null
                ? '${dateRange!.start.day}/${dateRange!.start.month}/${dateRange!.start.year} → ${dateRange!.end.day}/${dateRange!.end.month}/${dateRange!.end.year}'
                : 'Tap to select date range';
            final startTimeText = startTime.format(context);
            final endTimeText = endTime.format(context);

            return Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20, right: 20, top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.event_note, color: Colors.deepPurple, size: 28),
                          const SizedBox(width: 10),
                          Text('Add Special Schedule', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Temporary courses, workshops, exams that override your regular timetable',
                          style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                      const SizedBox(height: 20),

                      // Schedule Name
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Schedule Name',
                          hintText: 'e.g., TCS NQT Mock Test',
                          prefixIcon: const Icon(Icons.label_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainer,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Schedule Type TextField
                      TextField(
                        controller: typeController,
                        decoration: InputDecoration(
                          labelText: 'Schedule Type',
                          hintText: 'e.g., Workshop, Exam, Course',
                          prefixIcon: const Icon(Icons.category_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainer,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // What Class Dropdown
                      DropdownButtonFormField<String>(
                        value: classSelection,
                        decoration: InputDecoration(
                          labelText: 'What Class',
                          prefixIcon: const Icon(Icons.class_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainer,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Subject', child: Text('Subject')),
                          DropdownMenuItem(value: 'Other', child: Text('Other Class or Period')),
                        ],
                        onChanged: (val) => setState(() => classSelection = val!),
                      ),
                      
                      if (classSelection == 'Subject') ...[
                        const SizedBox(height: 16),
                        // Which Subject Dropdown
                        DropdownButtonFormField<int>(
                          value: selectedSubjectId,
                          decoration: InputDecoration(
                            labelText: 'Which Subject',
                            prefixIcon: const Icon(Icons.book_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainer,
                          ),
                          items: attendance.subjects.map((s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name, overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (val) => setState(() => selectedSubjectId = val),
                          hint: const Text('Select subject'),
                        ),
                      ] else ...[
                        const SizedBox(height: 16),
                        // Tell me TextField
                        TextField(
                          controller: otherClassController,
                          decoration: InputDecoration(
                            labelText: 'Tell me',
                            hintText: 'What?',
                            prefixIcon: const Icon(Icons.question_mark_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainer,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Date Range
                      InkWell(
                        onTap: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            initialDateRange: dateRange,
                            builder: (ctx, child) {
                              return Theme(
                                data: theme.copyWith(
                                  colorScheme: theme.colorScheme.copyWith(primary: Colors.deepPurple),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) setState(() => dateRange = picked);
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Date Range',
                            prefixIcon: const Icon(Icons.date_range),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainer,
                          ),
                          child: Text(dateRangeText, style: TextStyle(
                            color: dateRange != null ? theme.colorScheme.onSurface : Colors.grey[500],
                          )),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Time Row
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(context: context, initialTime: startTime);
                                if (picked != null) setState(() => startTime = picked);
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Daily Start',
                                  prefixIcon: const Icon(Icons.access_time, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  filled: true,
                                  fillColor: theme.colorScheme.surfaceContainer,
                                ),
                                child: Text(startTimeText),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(context: context, initialTime: endTime);
                                if (picked != null) setState(() => endTime = picked);
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Daily End',
                                  prefixIcon: const Icon(Icons.access_time, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  filled: true,
                                  fillColor: theme.colorScheme.surfaceContainer,
                                ),
                                child: Text(endTimeText),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check),
                          label: const Text('Add Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () async {
                            // Validate
                            if (nameController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter a schedule name'), backgroundColor: Colors.orange),
                              );
                              return;
                            }
                            if (typeController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter a schedule type'), backgroundColor: Colors.orange),
                              );
                              return;
                            }
                            
                            int finalSubjectId;
                            if (classSelection == 'Subject') {
                              if (selectedSubjectId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please select a subject'), backgroundColor: Colors.orange),
                                );
                                return;
                              }
                              finalSubjectId = selectedSubjectId!;
                            } else {
                              final customName = otherClassController.text.trim();
                              if (customName.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please type the name of the class/period'), backgroundColor: Colors.orange),
                                );
                                return;
                              }

                              // Check if a subject with this name already exists
                              final existingSubject = attendance.subjects.firstWhere(
                                (s) => s.name.toLowerCase() == customName.toLowerCase(),
                                orElse: () => Subject(id: -2, name: '', code: '', facultyName: '', colorHex: '', createdAt: 0),
                              );

                              if (existingSubject.id != -2) {
                                finalSubjectId = existingSubject.id!;
                              } else {
                                final newSubject = Subject(
                                  name: customName,
                                  code: customName.length > 4 ? customName.substring(0, 4).toUpperCase() : customName.toUpperCase(),
                                  facultyName: '',
                                  colorHex: '#9E9E9E',
                                  createdAt: DateTime.now().millisecondsSinceEpoch,
                                );
                                finalSubjectId = await attendance.addSubject(newSubject);
                              }
                            }

                            if (dateRange == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please select a date range'), backgroundColor: Colors.orange),
                              );
                              return;
                            }

                            final startDateMillis = DateTime(dateRange!.start.year, dateRange!.start.month, dateRange!.start.day).millisecondsSinceEpoch;
                            final endDateMillis = DateTime(dateRange!.end.year, dateRange!.end.month, dateRange!.end.day).millisecondsSinceEpoch;
                            final startTimeStr = startTime.format(context);
                            final endTimeStr = endTime.format(context);

                            final ss = SpecialSchedule(
                              name: nameController.text.trim(),
                              scheduleType: typeController.text.trim(),
                              subjectId: finalSubjectId,
                              startDateMillis: startDateMillis,
                              endDateMillis: endDateMillis,
                              dailyStartTime: startTimeStr,
                              dailyEndTime: endTimeStr,
                            );

                            await attendance.addSpecialSchedule(ss);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✅ "${ss.name}" added!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSpecialTimetableManagementSheet(BuildContext context, AttendanceProvider attendance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final overrides = attendance.specialTimetables;
            final days = ['Holiday / No Classes', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
            
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.swap_calls, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Special Timetables', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await _showAddSpecialTimetableDialog(context, attendance);
                              setModalState(() {});
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: overrides.isEmpty
                          ? const Center(
                              child: Text('No special timetables configured.', style: TextStyle(color: Colors.grey)),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: overrides.length,
                              itemBuilder: (context, index) {
                                final st = overrides[index];
                                final date = DateTime.fromMillisecondsSinceEpoch(st.dateMillis);
                                final dayText = st.targetDayOfWeek == 0 ? 'Holiday / No Classes' : 'Follows ${days[st.targetDayOfWeek]} Schedule';
                                
                                return ListTile(
                                  leading: const Icon(Icons.swap_horiz, color: Colors.orange),
                                  title: Text(DateFormat('EEEE, MMM d, yyyy').format(date), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(st.notes.isNotEmpty ? '$dayText\nNote: ${st.notes}' : dayText),
                                  isThreeLine: st.notes.isNotEmpty,
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () async {
                                      await attendance.deleteSpecialTimetable(st.id!);
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

  Future<void> _showAddSpecialTimetableDialog(BuildContext context, AttendanceProvider attendance) async {
    final notesController = TextEditingController();
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (selectedDate == null) return;

    int targetDay = 1; // Default Monday
    final days = [
      {'val': 0, 'label': 'Holiday / No Classes'},
      {'val': 1, 'label': 'Monday'},
      {'val': 2, 'label': 'Tuesday'},
      {'val': 3, 'label': 'Wednesday'},
      {'val': 4, 'label': 'Thursday'},
      {'val': 5, 'label': 'Friday'},
      {'val': 6, 'label': 'Saturday'},
      {'val': 7, 'label': 'Sunday'},
    ];

    if (context.mounted) {
      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Add Day-Swap Override'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'For Date: ${DateFormat('EEE, MMM d, yyyy').format(selectedDate!)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select schedule to run on this day:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: targetDay,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: days.map((d) => DropdownMenuItem<int>(
                      value: d['val'] as int,
                      child: Text(d['label'] as String),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          targetDay = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: 'Note (Optional)',
                      hintText: 'e.g., Run Friday timetable',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final midnightDate = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day).millisecondsSinceEpoch;
                    final override = SpecialTimetable(
                      dateMillis: midnightDate,
                      targetDayOfWeek: targetDay,
                      notes: notesController.text.trim(),
                    );
                    await attendance.addSpecialTimetable(override);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        ),
      );
    }
  }
}

// --- Timetable Setup Bottom Sheet ---
class TimetableSetupSheet extends StatefulWidget {
  final int initialStartMins;
  final int initialEndMins;
  final int initialPeriodMins;
  final int initialLunchStartMins;
  final int initialLunchEndMins;
  final Function(int start, int end, int period, int lunchStart, int lunchEnd) onSave;

  const TimetableSetupSheet({
    super.key,
    required this.initialStartMins,
    required this.initialEndMins,
    required this.initialPeriodMins,
    required this.initialLunchStartMins,
    required this.initialLunchEndMins,
    required this.onSave,
  });

  @override
  State<TimetableSetupSheet> createState() => _TimetableSetupSheetState();
}

class _TimetableSetupSheetState extends State<TimetableSetupSheet> {
  late TextEditingController _startController;
  late TextEditingController _endController;
  late TextEditingController _periodController;
  late TextEditingController _lunchStartController;
  late TextEditingController _lunchEndController;

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController(text: _formatMinsToTime(widget.initialStartMins));
    _endController = TextEditingController(text: _formatMinsToTime(widget.initialEndMins));
    _periodController = TextEditingController(text: widget.initialPeriodMins.toString());
    _lunchStartController = TextEditingController(text: _formatMinsToTime(widget.initialLunchStartMins));
    _lunchEndController = TextEditingController(text: _formatMinsToTime(widget.initialLunchEndMins));
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _periodController.dispose();
    _lunchStartController.dispose();
    _lunchEndController.dispose();
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

  Future<void> _selectTime(BuildContext context, String field) async {
    TextEditingController controller;
    if (field == 'start') {
      controller = _startController;
    } else if (field == 'end') {
      controller = _endController;
    } else if (field == 'lunchStart') {
      controller = _lunchStartController;
    } else {
      controller = _lunchEndController;
    }

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
        controller.text = formatted;
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
                  onTap: () => _selectTime(context, 'start'),
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
                  onTap: () => _selectTime(context, 'end'),
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
          TextField(
            controller: _periodController,
            decoration: const InputDecoration(
              labelText: 'Period or Class (mins)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _lunchStartController,
                  readOnly: true,
                  onTap: () => _selectTime(context, 'lunchStart'),
                  decoration: const InputDecoration(
                    labelText: 'Lunch Start Time',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.access_time),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _lunchEndController,
                  readOnly: true,
                  onTap: () => _selectTime(context, 'lunchEnd'),
                  decoration: const InputDecoration(
                    labelText: 'Lunch End Time',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.access_time),
                  ),
                ),
              ),
            ],
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
                final lunchStart = _parseTimeToMins(_lunchStartController.text);
                final lunchEnd = _parseTimeToMins(_lunchEndController.text);

                widget.onSave(start, end, period, lunchStart, lunchEnd);
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
            'Periods or Classes Per Day',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            '(excluding Lunch Period)',
            style: TextStyle(fontSize: 14, color: Colors.grey),
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
              child: const Text('Save Periods or Classes', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
