import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/color_utils.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isPeriodMode = true; // true = Period Mode, false = Day Mode
  int? _expandedSubjectId;

  // Simulator values: map of subjectId -> simulated additional present/absent
  final Map<int, int> _simulatedPresentMap = {};
  final Map<int, int> _simulatedAbsentMap = {};

  @override
  Widget build(BuildContext context) {
    final attendance = Provider.of<AttendanceProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);

    final targetPercent = settings.targetPercentage;
    const presentGreen = Color(0xFF10B981);
    const absentRed = Color(0xFFEF4444);

    // Calculate overall percent based on toggle mode
    double overallPercent = 0.0;
    int totalCount = 0;
    int presentCount = 0;
    int absentCount = 0;

    if (_isPeriodMode) {
      totalCount = attendance.allAttendance
          .where((r) => r.status == 'PRESENT' || r.status == 'ABSENT')
          .length;
      presentCount = attendance.allAttendance.where((r) => r.status == 'PRESENT').length;
      absentCount = attendance.allAttendance.where((r) => r.status == 'ABSENT').length;
      overallPercent = attendance.getOverallAttendancePercentage();
    } else {
      totalCount = attendance.totalDays;
      presentCount = attendance.presentDays;
      absentCount = attendance.absentDays;
      overallPercent = totalCount > 0 ? (presentCount / totalCount) * 100 : 0.0;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Interactive Analytics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mode Toggle Switch
            Center(
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Period Wise'),
                    icon: Icon(Icons.school),
                  ),
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Day Wise'),
                    icon: Icon(Icons.calendar_today),
                  ),
                ],
                selected: {_isPeriodMode},
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() {
                    _isPeriodMode = newSelection.first;
                  });
                },
              ),
            ),
            const SizedBox(height: 24),

            // Top Statistics Grid
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    _isPeriodMode ? 'Total Classes' : 'Total Days',
                    totalCount,
                    themeColor: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Present',
                    presentCount,
                    themeColor: presentGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Absent',
                    absentCount,
                    themeColor: absentRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Overall Progress Wheel
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
                    Text(
                      _isPeriodMode ? 'Overall Attendance (Periods)' : 'Overall Attendance (Days)',
                      style: const TextStyle(
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
                              value: totalCount == 0 ? 0 : overallPercent / 100,
                              strokeWidth: 16,
                              backgroundColor: Colors.grey.withOpacity(0.15),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                totalCount == 0
                                    ? Colors.grey
                                    : (overallPercent >= targetPercent ? presentGreen : absentRed),
                              ),
                            ),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    totalCount == 0 ? '—' : '${overallPercent.toInt()}%',
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Target: ${targetPercent.toInt()}%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
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

            // Interactive Subjects Simulator Header
            const Row(
              children: [
                Icon(Icons.tune, color: Colors.blueAccent),
                SizedBox(width: 8),
                Text(
                  'Subject Details & Bunk Simulator',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap any subject card below to expand it and simulate what happens if you attend or miss future classes!',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Interactive Subject cards list
            if (attendance.subjects.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text('No subjects added yet.', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ...attendance.subjects.map((sub) {
                final isExpanded = _expandedSubjectId == sub.id;
                final present = attendance.getPresentCountForSubject(sub.id!);
                final total = attendance.getTotalCountForSubject(sub.id!);

                // Get simulation values
                final simPresent = _simulatedPresentMap[sub.id!] ?? 0;
                final simAbsent = _simulatedAbsentMap[sub.id!] ?? 0;

                final displayPresent = present + simPresent;
                final displayTotal = total + simPresent + simAbsent;
                final percentage = displayTotal > 0 ? (displayPresent / displayTotal) * 100 : 0.0;

                final neededClasses = attendance.calculateClassesNeeded(displayPresent, displayTotal, targetPercent);
                final safeBunks = attendance.calculateSafeBunks(displayPresent, displayTotal, targetPercent);
                final subjectColor = ColorUtils.fromHex(sub.colorHex);

                String targetText = '';
                Color targetColor = presentGreen;
                if (displayTotal > 0) {
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
                  targetText = '🟢 No classes recorded';
                }

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isExpanded ? subjectColor : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  color: subjectColor.withOpacity(0.06),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedSubjectId = null;
                        } else {
                          _expandedSubjectId = sub.id;
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
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
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$present/$total classes' +
                                          ((simPresent > 0 || simAbsent > 0)
                                              ? ' (+${simPresent}P, +${simAbsent}A sim)'
                                              : ''),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    displayTotal > 0 ? '${percentage.toInt()}%' : '—',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: subjectColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            targetText,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: targetColor,
                            ),
                          ),
                          
                          // Expanded simulation controls
                          if (isExpanded) ...[
                            const Divider(height: 24),
                            const Text(
                              'Simulation Controls:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            
                            // Simulate Future Present Classes
                            Row(
                              children: [
                                const SizedBox(
                                  width: 140,
                                  child: Text('Simulate Present Classes:', style: TextStyle(fontSize: 12)),
                                ),
                                Expanded(
                                  child: Slider(
                                    min: 0,
                                    max: 20,
                                    divisions: 20,
                                    value: simPresent.toDouble(),
                                    activeColor: presentGreen,
                                    onChanged: (val) {
                                      setState(() {
                                        _simulatedPresentMap[sub.id!] = val.toInt();
                                      });
                                    },
                                  ),
                                ),
                                Text('+$simPresent', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            
                            // Simulate Future Absent Classes
                            Row(
                              children: [
                                const SizedBox(
                                  width: 140,
                                  child: Text('Simulate Absent Classes:', style: TextStyle(fontSize: 12)),
                                ),
                                Expanded(
                                  child: Slider(
                                    min: 0,
                                    max: 20,
                                    divisions: 20,
                                    value: simAbsent.toDouble(),
                                    activeColor: absentRed,
                                    onChanged: (val) {
                                      setState(() {
                                        _simulatedAbsentMap[sub.id!] = val.toInt();
                                      });
                                    },
                                  ),
                                ),
                                Text('+$simAbsent', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            
                            // Reset Simulator Button
                            if (simPresent > 0 || simAbsent > 0)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _simulatedPresentMap[sub.id!] = 0;
                                      _simulatedAbsentMap[sub.id!] = 0;
                                    });
                                  },
                                  icon: const Icon(Icons.restart_alt, size: 16),
                                  label: const Text('Reset Simulator', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, int value, {required Color themeColor}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: themeColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
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
