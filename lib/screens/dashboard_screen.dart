import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/attendance_provider.dart';
import '../providers/settings_provider.dart';
import '../models/subject.dart';
import '../models/timetable_entry.dart';
import '../models/attendance_record.dart';
import '../utils/color_utils.dart';
import 'daily_setup_prompt.dart';
import 'subjects_screen.dart';
import 'analytics_screen.dart';
import 'attendance_entry_screen.dart';
import '../widgets/attendance_wizard_sheet.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  @override
  Widget build(BuildContext context) {
    final attendance = Provider.of<AttendanceProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);

    if (attendance.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final today = DateTime.now();
    final currentDayOfWeek = today.weekday; // 1 = Monday, 7 = Sunday

    // Filter timetable for today
    final todaysSlots = attendance.timetableSlots
        .where((slot) => slot.dayOfWeek == currentDayOfWeek)
        .toList();
    todaysSlots.sort((a, b) => a.periodNumber.compareTo(b.periodNumber));

    final overallPercent = attendance.getOverallAttendancePercentage();
    final targetPercent = settings.targetPercentage;

    // Define colors from Compose theme
    const presentGreen = Color(0xFF10B981);
    const absentRed = Color(0xFFEF4444);

    // Calculate per-subject attendance info
    final subjectAttendanceList = attendance.subjects.map((sub) {
      final pCount = attendance.getPresentCountForSubject(sub.id!);
      final tCount = attendance.getTotalCountForSubject(sub.id!);
      final pct = tCount > 0 ? (pCount / tCount) * 100 : 0.0;
      final safeBunks = attendance.calculateSafeBunks(pCount, tCount, targetPercent);
      return _SubjectAttendanceInfo(
        subject: sub,
        presentCount: pCount,
        totalCount: tCount,
        percentage: pct,
        safeBunks: safeBunks,
      );
    }).toList();

    final lowAttendanceSubjects = subjectAttendanceList
        .where((info) => info.totalCount > 0 && info.percentage < targetPercent)
        .toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final now = DateTime.now();
          final todayStartMillis = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AttendanceEntryScreen(dateMillis: todayStartMillis),
            ),
          );
        },
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Mark', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 90,
              backgroundColor: Colors.transparent,
              elevation: 0,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                title: Text(
                  'Good ${_getGreeting()}!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Here's your attendance overview",
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Daily Setup Alert
                    const DailySetupPrompt(),
                    const SizedBox(height: 12),

                    // Overall Progress Card
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      color: theme.colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Row(
                          children: [
                            // Circular indicator
                            SizedBox(
                              width: 130,
                              height: 130,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CircularProgressIndicator(
                                    value: attendance.allAttendance.isEmpty ? 0 : overallPercent / 100,
                                    strokeWidth: 14,
                                    backgroundColor: theme.colorScheme.outline.withOpacity(0.2),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      attendance.allAttendance.isEmpty
                                          ? theme.colorScheme.outline
                                          : (overallPercent >= targetPercent ? presentGreen : absentRed),
                                    ),
                                  ),
                                  Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          attendance.allAttendance.isEmpty ? '—' : '${overallPercent.toInt()}%',
                                          style: TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                        Text(
                                          'Overall',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            // Stats Column
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildStatRow('Present Days', attendance.presentDays, presentGreen, theme),
                                  const SizedBox(height: 8),
                                  _buildStatRow('Absent Days', attendance.absentDays, absentRed, theme),
                                  const SizedBox(height: 8),
                                  _buildStatRow('Total Days', attendance.totalDays, theme.colorScheme.onSurfaceVariant, theme),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.local_fire_department,
                                        size: 20,
                                        color: theme.colorScheme.tertiary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${attendance.streak} day streak',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Today's Schedule Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Today's Schedule",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat('EEEE').format(today),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // Today's Schedule horizontal list
            SliverToBoxAdapter(
              child: SizedBox(
                height: 110,
                child: todaysSlots.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Card(
                          elevation: 0,
                          color: theme.colorScheme.surfaceContainerHighest,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 24.0),
                              child: Text(
                                'No classes scheduled today 🎉',
                                style: TextStyle(fontSize: 15),
                              ),
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: todaysSlots.length,
                        itemBuilder: (context, index) {
                          final slot = todaysSlots[index];
                          final subject = attendance.subjects.firstWhere(
                            (s) => s.id == slot.subjectId,
                            orElse: () => Subject(
                              id: -1,
                              name: 'Free Period',
                              code: 'FREE',
                              facultyName: '',
                              colorHex: '#EEEEEE',
                              createdAt: 0,
                            ),
                          );

                          final subjectColor = slot.subjectId == null
                              ? theme.colorScheme.surfaceContainerHighest
                              : ColorUtils.fromHex(subject.colorHex);

                          return Container(
                            width: 140,
                            margin: const EdgeInsets.only(right: 12),
                            child: Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              color: subjectColor.withOpacity(0.15),
                              child: Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Period ${slot.periodNumber}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: subjectColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      subject.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${_formatTime(slot.startTime)} - ${_formatTime(slot.endTime)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),

            // Low Attendance warning & safe bunks
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Low Attendance Warnings
                    if (lowAttendanceSubjects.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        '⚠️ Low Attendance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...lowAttendanceSubjects.map((info) {
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 8),
                          color: theme.colorScheme.errorContainer,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                const Icon(Icons.warning, color: Colors.red),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        info.subject.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${info.percentage.toInt()}% — Need more classes',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme.colorScheme.onErrorContainer,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],

                    const SizedBox(height: 24),

                    // Quick Actions
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SubjectsScreen(),
                                ),
                              );
                            },
                            child: Card(
                              elevation: 0,
                              color: theme.colorScheme.secondaryContainer,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.menu_book,
                                      color: theme.colorScheme.onSecondaryContainer,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Subjects',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '${attendance.subjects.length} added',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AnalyticsScreen(),
                                ),
                              );
                            },
                            child: Card(
                              elevation: 0,
                              color: theme.colorScheme.tertiaryContainer,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.trending_down,
                                      color: theme.colorScheme.onTertiaryContainer,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Analytics',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const Text(
                                      'View insights',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Safe Bunk Calculator Section
                    if (subjectAttendanceList.isNotEmpty) ...[
                      const Text(
                        'Safe Bunk Calculator',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...subjectAttendanceList.where((info) => info.totalCount > 0 && !attendance.excludedSubjectIds.contains(info.subject.id)).map((info) {
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        info.subject.name,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${info.percentage.toInt()}% attendance',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (info.percentage < targetPercent)
                                  const Text(
                                    '🔴 Attend more!',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: absentRed,
                                    ),
                                  )
                                else if (info.safeBunks > 0)
                                  Text(
                                    '🟢 Can miss ${info.safeBunks}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: presentGreen,
                                    ),
                                  )
                                else
                                  const Text(
                                    '🟢 On track',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: presentGreen,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int value, Color color, ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ],
    );
  }

  String _formatTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final tod = TimeOfDay(hour: hour, minute: minute);
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
      // We don't have BuildContext here directly for localizations, so format custom
      final ampm = tod.period == DayPeriod.am ? 'AM' : 'PM';
      final hour12 = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
      final minStr = tod.minute.toString().padLeft(2, '0');
      return '$hour12:$minStr $ampm';
    } catch (_) {
      return timeStr;
    }
  }
}

class _SubjectAttendanceInfo {
  final Subject subject;
  final int presentCount;
  final int totalCount;
  final double percentage;
  final int safeBunks;

  _SubjectAttendanceInfo({
    required this.subject,
    required this.presentCount,
    required this.totalCount,
    required this.percentage,
    required this.safeBunks,
  });
}
