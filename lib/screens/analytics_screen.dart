import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/color_utils.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final attendance = Provider.of<AttendanceProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);

    final overallPercent = attendance.getOverallAttendancePercentage();
    final targetPercent = settings.targetPercentage;

    // Define colors from Compose theme
    const presentGreen = Color(0xFF10B981); // PresentGreen
    const absentRed = Color(0xFFEF4444); // AbsentRed

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Analytics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period Attendance Section
            const Text(
              'Period Attendance',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Total Classes',
                    attendance.allAttendance
                        .where((r) => r.status == 'PRESENT' || r.status == 'ABSENT')
                        .length,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Present',
                    attendance.allAttendance.where((r) => r.status == 'PRESENT').length,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Absent',
                    attendance.allAttendance.where((r) => r.status == 'ABSENT').length,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Day Attendance Section
            const Text(
              'Day Attendance',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Total Days',
                    attendance.totalDays,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Present Days',
                    attendance.presentDays,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Absent Days',
                    attendance.absentDays,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Overall Progress Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                child: Column(
                  children: [
                    const Text(
                      'Overall Attendance (Periods)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: SizedBox(
                        width: 160,
                        height: 160,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: attendance.allAttendance.isEmpty ? 0 : overallPercent / 100,
                              strokeWidth: 16,
                              backgroundColor: Colors.grey.withOpacity(0.15),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                attendance.allAttendance.isEmpty
                                    ? Colors.grey
                                    : (overallPercent >= targetPercent ? presentGreen : absentRed),
                              ),
                            ),
                            Center(
                              child: Text(
                                attendance.allAttendance.isEmpty
                                    ? '—'
                                    : '${overallPercent.toInt()}%',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Subject Details Section
            if (attendance.subjects.isNotEmpty) ...[
              const Text(
                'Subject Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...attendance.subjects.map((sub) {
                final present = attendance.getPresentCountForSubject(sub.id!);
                final total = attendance.getTotalCountForSubject(sub.id!);
                final percentage = total > 0 ? (present / total) * 100 : 0.0;
                final neededClasses = attendance.calculateClassesNeeded(present, total, targetPercent);
                final safeBunks = attendance.calculateSafeBunks(present, total, targetPercent);
                final subjectColor = ColorUtils.fromHex(sub.colorHex);

                String targetText = '';
                Color targetColor = presentGreen;
                if (total > 0) {
                  if (percentage < targetPercent) {
                    targetText = '🔴 Need $neededClasses classes for ${targetPercent.toInt()}%';
                    targetColor = absentRed;
                  } else {
                    if (safeBunks > 0) {
                      targetText = '🟢 Can miss $safeBunks classes';
                    } else {
                      targetText = '🟢 On track (0 safe bunks)';
                    }
                  }
                } else {
                  targetText = '🟢 No classes recorded yet';
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    color: subjectColor.withOpacity(0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sub.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$present/$total classes',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  targetText,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: targetColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            total > 0 ? '${percentage.toInt()}%' : '—',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: subjectColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, int value) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: [
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
