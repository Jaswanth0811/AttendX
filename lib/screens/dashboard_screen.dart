import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/attendance_provider.dart';
import '../providers/settings_provider.dart';
import '../models/subject.dart';
import '../models/timetable_entry.dart';
import '../models/attendance_record.dart';
import '../utils/color_utils.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer2<AttendanceProvider, SettingsProvider>(
          builder: (context, attendance, settings, child) {
            if (attendance.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final today = DateTime.now();
            final currentDayOfWeek = today.weekday; // 1 = Monday, 7 = Sunday
            
            // Filter timetable for today
            final todaysSlots = attendance.timetableSlots
                .where((slot) => slot.dayOfWeek == currentDayOfWeek)
                .toList();
            todaysSlots.sort((a, b) => a.periodNumber.compareTo(b.periodNumber));

            final overallPercent = attendance.getOverallAttendancePercentage();

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good Morning,',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('EEEE, MMMM d').format(today),
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                        const SizedBox(height: 32),
                        _buildOverallStatsCard(context, overallPercent, settings.targetPercentage),
                        const SizedBox(height: 32),
                        Text(
                          'Today\'s Classes',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                if (todaysSlots.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.withOpacity(0.1)),
                        ),
                        child: const Center(
                          child: Text(
                            'No classes scheduled for today! 🎉',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
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
                        return _buildTimetableItem(context, slot, subject);
                      },
                      childCount: todaysSlots.length,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOverallStatsCard(BuildContext context, double current, double target) {
    final isSafe = current >= target;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Overall Attendance',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    current.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    '%',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSafe ? Colors.greenAccent.withOpacity(0.2) : Colors.redAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isSafe ? 'On Track' : 'Needs Attention',
                  style: TextStyle(
                    color: isSafe ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              children: [
                Center(
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: current / 100,
                      strokeWidth: 8,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isSafe ? Colors.white : Colors.redAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimetableItem(BuildContext context, TimetableSlot slot, Subject subject) {
    final color = ColorUtils.fromHex(subject.colorHex);
    return Padding(
      padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 16.0),
      child: InkWell(
        onTap: () {
          _showMarkAttendanceDialog(context, slot, subject);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    slot.startTime,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    slot.endTime,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subject.facultyName,
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Icon(Icons.check_circle_outline, color: color.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }

  void _showMarkAttendanceDialog(BuildContext context, TimetableSlot slot, Subject subject) {
    final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mark Attendance', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('${subject.name} • ${slot.startTime} - ${slot.endTime}', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildMarkButton(context, 'PRESENT', Colors.green, slot, subject, attendanceProvider),
                    _buildMarkButton(context, 'ABSENT', Colors.red, slot, subject, attendanceProvider),
                    _buildMarkButton(context, 'CANCELLED', Colors.orange, slot, subject, attendanceProvider),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMarkButton(BuildContext context, String status, Color color, TimetableSlot slot, Subject subject, AttendanceProvider provider) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final dayStartMillis = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
        
        // Check if already marked
        final dateRecords = provider.attendanceByDate[dayStartMillis] ?? [];
        final exists = dateRecords.any((r) => r.periodNumber == slot.periodNumber);
        
        if (exists) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance already marked for this period today.')));
          return;
        }

        final record = AttendanceRecord(
          date: dayStartMillis,
          dayOfWeek: now.weekday,
          periodNumber: slot.periodNumber,
          scheduledSubjectId: subject.id,
          actualSubjectId: subject.id,
          status: status,
          createdAt: now.millisecondsSinceEpoch,
        );

        await provider.addAttendance(record);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Marked as $status')));
        }
      },
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: color.withOpacity(0.2),
            child: Icon(
              status == 'PRESENT' ? Icons.check : (status == 'ABSENT' ? Icons.close : Icons.block),
              color: color,
              size: 32,
            ),
          ),
          const SizedBox(height: 8),
          Text(status, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
