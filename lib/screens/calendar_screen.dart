import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/attendance_provider.dart';
import '../models/attendance_record.dart';
import '../models/subject.dart';
import '../models/timetable_entry.dart';
import '../utils/color_utils.dart';
import 'package:intl/intl.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: Consumer<AttendanceProvider>(
        builder: (context, attendance, child) {
          final allRecords = attendance.allAttendance;

          return Column(
            children: [
              TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                eventLoader: (day) {
                  final dayStartMillis = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
                  return attendance.attendanceByDate[dayStartMillis] ?? [];
                },
              ),
              const Divider(),
              Expanded(
                child: _buildRecordsList(context, attendance),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRecordsList(BuildContext context, AttendanceProvider attendance) {
    if (_selectedDay == null) return const SizedBox();
    
    final dayOfWeek = _selectedDay!.weekday;
    final dayStartMillis = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day).millisecondsSinceEpoch;
    
    // Get all scheduled slots for this day of the week
    final slots = attendance.timetableSlots.where((s) => s.dayOfWeek == dayOfWeek).toList();
    
    // Get all attendance records for this date
    final dateRecords = attendance.attendanceByDate[dayStartMillis] ?? [];
    
    // Create a unified list of display items
    List<Map<String, dynamic>> displayItems = [];
    
    // 1. Add scheduled slots (and their corresponding records if any)
    for (var slot in slots) {
      final record = dateRecords.where((r) => r.periodNumber == slot.periodNumber).firstOrNull;
      final subject = attendance.subjects.firstWhere(
        (s) => s.id == slot.subjectId,
        orElse: () => Subject(id: -1, name: 'Unknown', code: 'UNK', facultyName: '', colorHex: '#9E9E9E', createdAt: 0),
      );
      displayItems.add({
        'periodNumber': slot.periodNumber,
        'subject': subject,
        'slot': slot,
        'record': record,
        'startTime': slot.startTime,
        'endTime': slot.endTime,
      });
    }
    
    // 2. Add records that don't have a matching slot (extra classes, holidays marked globally, etc.)
    for (var record in dateRecords) {
      if (!slots.any((s) => s.periodNumber == record.periodNumber)) {
        final subject = attendance.subjects.firstWhere(
          (s) => s.id == (record.actualSubjectId ?? record.scheduledSubjectId),
          orElse: () => Subject(id: -1, name: 'Unknown', code: 'UNK', facultyName: '', colorHex: '#9E9E9E', createdAt: 0),
        );
        displayItems.add({
          'periodNumber': record.periodNumber,
          'subject': subject,
          'slot': null,
          'record': record,
          'startTime': 'Extra',
          'endTime': '',
        });
      }
    }
    
    displayItems.sort((a, b) => (a['periodNumber'] as int).compareTo(b['periodNumber'] as int));
    
    if (displayItems.isEmpty) {
      return Center(
        child: Text(
          'No classes scheduled or attendance marked for ${DateFormat('MMM d, yyyy').format(_selectedDay!)}',
          style: const TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      itemCount: displayItems.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final item = displayItems[index];
        final subject = item['subject'] as Subject;
        final record = item['record'] as AttendanceRecord?;
        final slot = item['slot'] as TimetableSlot?;
        
        final status = record?.status ?? 'NOT MARKED';
        final startTime = item['startTime'] as String;
        final endTime = item['endTime'] as String;
        
        Color statusColor;
        switch (status) {
          case 'PRESENT':
          case 'SEMINAR':
            statusColor = Colors.green;
            break;
          case 'ABSENT':
            statusColor = Colors.red;
            break;
          case 'CANCELLED':
          case 'FREE':
          case 'HOLIDAY':
            statusColor = Colors.grey;
            break;
          default:
            statusColor = Colors.orange;
            break;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: ColorUtils.fromHex(subject.colorHex),
              child: Text('${item['periodNumber']}', style: const TextStyle(color: Colors.white)),
            ),
            title: Text(subject.name),
            subtitle: Text('$status • $startTime${endTime.isNotEmpty ? ' - $endTime' : ''}'),
            trailing: Icon(
              status == 'PRESENT' ? Icons.check_circle : (status == 'ABSENT' ? Icons.cancel : (status == 'NOT MARKED' ? Icons.help_outline : Icons.info)),
              color: statusColor,
            ),
            onTap: () {
              if (slot != null) {
                _showEditAttendanceDialog(context, slot, subject, record, attendance, dayStartMillis, dayOfWeek);
              } else {
                // If there's no slot, we can't easily recreate a dummy slot. 
                // Let's create a temporary slot to pass to the dialog for editing an extra class.
                final tempSlot = TimetableSlot(
                  id: -1, 
                  dayOfWeek: dayOfWeek, 
                  subjectId: subject.id ?? -1, 
                  startTime: startTime, 
                  endTime: endTime, 
                  periodNumber: item['periodNumber'] as int
                );
                _showEditAttendanceDialog(context, tempSlot, subject, record, attendance, dayStartMillis, dayOfWeek);
              }
            },
          ),
        );
      },
    );
  }

  void _showEditAttendanceDialog(BuildContext context, TimetableSlot slot, Subject subject, AttendanceRecord? record, AttendanceProvider provider, int dateMillis, int dayOfWeek) {
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
                Text(record == null ? 'Mark Attendance' : 'Edit Attendance', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('${subject.name} • ${slot.startTime} - ${slot.endTime}', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildMarkButton(context, 'PRESENT', Colors.green, slot, subject, provider, record, dateMillis, dayOfWeek),
                    _buildMarkButton(context, 'ABSENT', Colors.red, slot, subject, provider, record, dateMillis, dayOfWeek),
                    _buildMarkButton(context, 'CANCELLED', Colors.orange, slot, subject, provider, record, dateMillis, dayOfWeek),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMarkButton(BuildContext context, String status, Color color, TimetableSlot slot, Subject subject, AttendanceProvider provider, AttendanceRecord? record, int dateMillis, int dayOfWeek) {
    return InkWell(
      onTap: () async {
        if (record != null) {
          final updated = AttendanceRecord(
            id: record.id,
            date: record.date,
            dayOfWeek: record.dayOfWeek,
            periodNumber: record.periodNumber,
            scheduledSubjectId: record.scheduledSubjectId,
            actualSubjectId: record.actualSubjectId,
            status: status,
            createdAt: record.createdAt,
            note: record.note,
          );
          await provider.updateAttendance(updated);
        } else {
          final newRecord = AttendanceRecord(
            date: dateMillis,
            dayOfWeek: dayOfWeek,
            periodNumber: slot.periodNumber,
            scheduledSubjectId: subject.id,
            actualSubjectId: subject.id,
            status: status,
            createdAt: DateTime.now().millisecondsSinceEpoch,
          );
          await provider.addAttendance(newRecord);
        }
        
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
