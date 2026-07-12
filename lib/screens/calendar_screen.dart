import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/attendance_provider.dart';
import '../providers/settings_provider.dart';
import '../models/attendance_record.dart';
import '../models/subject.dart';
import '../models/timetable_entry.dart';
import '../models/holiday.dart';
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
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    return _buildCalendarDayCell(context, day, attendance, false, false);
                  },
                  todayBuilder: (context, day, focusedDay) {
                    return _buildCalendarDayCell(context, day, attendance, false, true);
                  },
                  selectedBuilder: (context, day, focusedDay) {
                    return _buildCalendarDayCell(context, day, attendance, true, isSameDay(day, DateTime.now()));
                  },
                ),
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
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    
    // Get all scheduled slots for this day of the week
    final rawSlots = attendance.timetableSlots.where((s) => s.dayOfWeek == dayOfWeek).toList();
    final List<TimetableSlot> slots = [];
    for (var slot in rawSlots) {
      slots.addAll(slot.expandSlots(settings.periodDurationMinutes));
    }
    
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
        // Holiday banner
        if (attendance.isHoliday(dayStartMillis)) ...[
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.orange.withOpacity(0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Colors.orange, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Holiday', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange)),
                        Text(
                          attendance.getHolidayForDate(dayStartMillis)?.name ?? 'Holiday',
                          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.orange),
                    onPressed: () {
                      final holiday = attendance.getHolidayForDate(dayStartMillis);
                      if (holiday != null) {
                        attendance.deleteHoliday(holiday.id!);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
        Expanded(
          child: displayItems.isEmpty && !attendance.isHoliday(dayStartMillis)
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
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
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
        if (!attendance.isHoliday(dayStartMillis))
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () => _showAddHolidayDialog(context, attendance, dayStartMillis),
                icon: const Icon(Icons.celebration, color: Colors.orange),
                label: const Text('Mark as Holiday', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.orange),
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

  void _showAddHolidayDialog(BuildContext context, AttendanceProvider attendance, int dateMillis) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Holiday'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Holiday Name',
            hintText: 'e.g., Independence Day',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                attendance.addHoliday(Holiday(
                  date: dateMillis,
                  name: name,
                  createdAt: DateTime.now().millisecondsSinceEpoch,
                ));
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget? _buildCalendarDayCell(BuildContext context, DateTime day, AttendanceProvider attendance, bool isSelected, bool isToday) {
    final dayMillis = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final theme = Theme.of(context);
    final isHoliday = attendance.isHoliday(dayMillis);
    final isSunday = day.weekday == DateTime.sunday;
    final records = attendance.attendanceByDate[dayMillis] ?? [];

    Color? dotColor;
    if (isHoliday || isSunday) {
      dotColor = Colors.orange;
    } else if (records.isNotEmpty) {
      final hasPresent = records.any((r) => r.status == 'PRESENT');
      final hasAbsent = records.any((r) => r.status == 'ABSENT');
      if (hasPresent && hasAbsent) {
        dotColor = Colors.amber;
      } else if (hasPresent) {
        dotColor = Colors.green;
      } else if (hasAbsent) {
        dotColor = Colors.red;
      }
    }

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isSelected 
            ? theme.colorScheme.primary 
            : (isToday ? theme.colorScheme.primary.withOpacity(0.15) : Colors.transparent),
        shape: BoxShape.circle,
        border: isHoliday 
          ? Border.all(color: Colors.orange, width: 1.5) 
          : (isToday ? Border.all(color: theme.colorScheme.primary, width: 1) : null),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              color: isSelected 
                  ? theme.colorScheme.onPrimary 
                  : (isHoliday ? Colors.orange : (isSunday ? Colors.red.shade400 : theme.colorScheme.onSurface)),
              fontWeight: (isToday || isHoliday || isSelected) ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
          if (dotColor != null) ...[
            const SizedBox(height: 2),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
