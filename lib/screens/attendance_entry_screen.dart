import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/attendance_provider.dart';
import '../models/subject.dart';
import '../models/timetable_entry.dart';
import '../models/attendance_record.dart';
import '../utils/color_utils.dart';

class AttendanceEntryScreen extends StatefulWidget {
  final int dateMillis;

  const AttendanceEntryScreen({super.key, required this.dateMillis});

  @override
  State<AttendanceEntryScreen> createState() => _AttendanceEntryScreenState();
}

class _AttendanceEntryScreenState extends State<AttendanceEntryScreen> {
  final Map<int, bool?> _isClassTakenMap = {};
  final Map<int, Subject?> _actuallyTakenSubjectMap = {};
  final Map<int, String?> _specialTypeMap = {};
  final Map<int, String?> _statusSelectionMap = {};

  @override
  Widget build(BuildContext context) {
    final attendance = Provider.of<AttendanceProvider>(context);
    final theme = Theme.of(context);

    final date = DateTime.fromMillisecondsSinceEpoch(widget.dateMillis);
    final dayOfWeek = date.weekday;

    final slots = attendance.timetableSlots.where((s) => s.dayOfWeek == dayOfWeek).toList();
    slots.sort((a, b) => a.periodNumber.compareTo(b.periodNumber));

    final dateRecords = attendance.attendanceByDate[widget.dateMillis] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mark Attendance', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(date),
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: attendance.isHoliday(widget.dateMillis)
          ? _buildHolidayState(theme, attendance.getHolidayForDate(widget.dateMillis)?.name ?? 'Holiday')
          : slots.isEmpty
              ? _buildEmptyState(theme)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: slots.length,
                  itemBuilder: (context, index) {
                    final slot = slots[index];
                    final scheduledSubject = attendance.subjects.firstWhere(
                      (s) => s.id == slot.subjectId,
                      orElse: () => Subject(id: -1, name: 'Free Period', code: 'FREE', facultyName: '', colorHex: '#9E9E9E', createdAt: 0),
                    );

                    final record = dateRecords.where((r) => r.periodNumber == slot.periodNumber).firstOrNull;
                    final isLocked = record != null;

                    return _buildEntryCard(context, slot, scheduledSubject, record, isLocked, attendance, theme);
                  },
                ),
    );
  }

  Widget _buildHolidayState(ThemeData theme, String holidayName) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('\ud83c\udf89', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text(
            'This is a Holiday!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          const SizedBox(height: 8),
          Text(
            holidayName,
            style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            'No attendance to mark today.',
            style: TextStyle(fontSize: 14, color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          const Text(
            'No Classes Scheduled',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text('There are no periods to mark for this date.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildEntryCard(
    BuildContext context,
    TimetableSlot slot,
    Subject scheduledSubject,
    AttendanceRecord? record,
    bool isLocked,
    AttendanceProvider provider,
    ThemeData theme,
  ) {
    final period = slot.periodNumber;

    if (isLocked) {
      final isTaken = record!.actualSubjectId == record.scheduledSubjectId;
      _isClassTakenMap[period] ??= isTaken;
      if (!isTaken) {
        if (record.status == 'FREE' || record.status == 'CANCELLED' || record.status == 'SEMINAR') {
          _specialTypeMap[period] ??= record.status;
        } else {
          _actuallyTakenSubjectMap[period] ??= provider.subjects.firstWhere((s) => s.id == record.actualSubjectId, orElse: () => provider.subjects.first);
        }
      }
      _statusSelectionMap[period] ??= record.status;
    }

    final isClassTaken = _isClassTakenMap[period];
    final selectedSubject = _actuallyTakenSubjectMap[period];
    final specialType = _specialTypeMap[period];
    final statusSelection = _statusSelectionMap[period];

    Color cardColor = ColorUtils.fromHex(scheduledSubject.colorHex).withOpacity(0.08);
    if (isLocked) {
      cardColor = theme.colorScheme.surfaceVariant.withOpacity(0.3);
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isLocked ? BorderSide(color: theme.colorScheme.outlineVariant) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Period $period',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  '${slot.startTime} - ${slot.endTime}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Scheduled: ${scheduledSubject.name}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (isLocked) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Marked as ${record!.status}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                        if (record!.actualSubjectId != record!.scheduledSubjectId) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '(${provider.subjects.firstWhere((s) => s.id == record!.actualSubjectId, orElse: () => Subject(id: -1, name: 'Other', code: '', facultyName: '', colorHex: '', createdAt: 0)).name})',
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        provider.deleteAttendance(record!.id!);
                        _isClassTakenMap[period] = null;
                        _actuallyTakenSubjectMap[period] = null;
                        _specialTypeMap[period] = null;
                        _statusSelectionMap[period] = null;
                      });
                    },
                    child: const Text('Change'),
                  ),
                ],
              ),
            ] else ...[
              const Text('Was the scheduled class taken?', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _isClassTakenMap[period] = true;
                          _actuallyTakenSubjectMap[period] = null;
                          _specialTypeMap[period] = null;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isClassTaken == true ? theme.colorScheme.primaryContainer : Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Yes'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _isClassTakenMap[period] = false;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isClassTaken == false ? theme.colorScheme.errorContainer : Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('No'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (isClassTaken == false) ...[
                const Text('Actually taken:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: specialType ?? (selectedSubject != null ? 'SUB_${selectedSubject.id}' : null),
                  hint: const Text('Select subject or type'),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: [
                    ...provider.subjects.map((sub) => DropdownMenuItem<String>(
                          value: 'SUB_${sub.id}',
                          child: Text(sub.name),
                        )),
                    const DropdownMenuItem<String>(
                      value: 'FREE',
                      child: Text('Free Period'),
                    ),
                    const DropdownMenuItem<String>(
                      value: 'CANCELLED',
                      child: Text('Cancelled'),
                    ),
                    const DropdownMenuItem<String>(
                      value: 'SEMINAR',
                      child: Text('Seminar'),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      if (val == 'FREE' || val == 'CANCELLED' || val == 'SEMINAR') {
                        _specialTypeMap[period] = val;
                        _actuallyTakenSubjectMap[period] = null;
                        _statusSelectionMap[period] = val;
                      } else if (val != null && val.startsWith('SUB_')) {
                        final subId = int.parse(val.substring(4));
                        _actuallyTakenSubjectMap[period] = provider.subjects.firstWhere((s) => s.id == subId);
                        _specialTypeMap[period] = null;
                        if (_statusSelectionMap[period] == 'FREE' || _statusSelectionMap[period] == 'CANCELLED' || _statusSelectionMap[period] == 'SEMINAR') {
                          _statusSelectionMap[period] = null;
                        }
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],
              if (isClassTaken != null) ...[
                if (specialType == 'FREE' || specialType == 'CANCELLED' || specialType == 'SEMINAR') ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () => _saveRecord(context, slot, provider, specialType!),
                      icon: const Icon(Icons.check),
                      label: const Text('Save Period'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        foregroundColor: theme.colorScheme.onPrimaryContainer,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _statusSelectionMap[period] = 'PRESENT';
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: statusSelection == 'PRESENT' ? Colors.green : theme.colorScheme.surface,
                            foregroundColor: statusSelection == 'PRESENT' ? Colors.white : theme.colorScheme.onSurface,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Present'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _statusSelectionMap[period] = 'ABSENT';
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: statusSelection == 'ABSENT' ? Colors.red : theme.colorScheme.surface,
                            foregroundColor: statusSelection == 'ABSENT' ? Colors.white : theme.colorScheme.onSurface,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Absent'),
                        ),
                      ),
                      if (statusSelection != null) ...[
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () => _saveRecord(context, slot, provider, statusSelection),
                          icon: const Icon(Icons.check),
                          style: IconButton.styleFrom(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            foregroundColor: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _saveRecord(BuildContext context, TimetableSlot slot, AttendanceProvider provider, String status) async {
    final period = slot.periodNumber;
    final isTaken = _isClassTakenMap[period] ?? true;
    final actualSubject = _actuallyTakenSubjectMap[period];

    int? actualSubjectId;
    if (isTaken) {
      actualSubjectId = slot.subjectId;
    } else {
      actualSubjectId = actualSubject?.id;
    }

    final newRecord = AttendanceRecord(
      date: widget.dateMillis,
      dayOfWeek: DateTime.fromMillisecondsSinceEpoch(widget.dateMillis).weekday,
      periodNumber: period,
      scheduledSubjectId: slot.subjectId,
      actualSubjectId: actualSubjectId,
      status: status,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    await provider.addAttendance(newRecord);
    setState(() {});
  }
}
