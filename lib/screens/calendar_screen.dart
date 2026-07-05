import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/attendance_provider.dart';
import '../models/attendance_record.dart';
import '../models/subject.dart';
import '../models/timetable_entry.dart';
import '../utils/color_utils.dart';
import 'package:intl/intl.dart';
import '../widgets/attendance_wizard_sheet.dart';

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
    
    return Column(
      children: [
        Expanded(
          child: displayItems.isEmpty
              ? Center(
                  child: Text(
                    'No classes scheduled or attendance marked for ${DateFormat('MMM d, yyyy').format(_selectedDay!)}',
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
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
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                            ),
                            builder: (context) {
                              return AttendanceWizardSheet(
                                slot: slot,
                                subject: subject.id == -1 ? null : subject,
                                record: record,
                                dateMillis: dayStartMillis,
                                dayOfWeek: dayOfWeek,
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (context) {
                    return AttendanceWizardSheet(
                      dateMillis: dayStartMillis,
                      dayOfWeek: dayOfWeek,
                    );
                  },
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add / Edit Extra Attendance', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
