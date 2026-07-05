import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../models/attendance_record.dart';
import '../models/subject.dart';
import '../models/timetable_entry.dart';

class AttendanceWizardSheet extends StatefulWidget {
  final TimetableSlot? slot;
  final Subject? subject;
  final AttendanceRecord? record;
  final int dateMillis;
  final int dayOfWeek;

  const AttendanceWizardSheet({
    super.key,
    this.slot,
    this.subject,
    this.record,
    required this.dateMillis,
    required this.dayOfWeek,
  });

  @override
  State<AttendanceWizardSheet> createState() => _AttendanceWizardSheetState();
}

class _AttendanceWizardSheetState extends State<AttendanceWizardSheet> {
  int _step = 0; // 0: Was scheduled taken?, 1: Choose instead subject, 2: Present/Absent, 3: Choose subject first (manual flow)
  bool _isScheduledTaken = true;
  Subject? _chosenSubject;
  int _periodNumber = 1;

  @override
  void initState() {
    super.initState();
    _chosenSubject = widget.subject;
    _periodNumber = widget.slot?.periodNumber ?? widget.record?.periodNumber ?? 1;

    if (widget.record != null) {
      final isTaken = widget.record!.actualSubjectId == widget.record!.scheduledSubjectId;
      _isScheduledTaken = isTaken;
      if (!isTaken) {
        _chosenSubject = widget.subject;
      }
    }

    // If there is no preset subject/slot (e.g. manual marking from FAB), start directly at choosing subject
    if (widget.subject == null) {
      _step = 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final theme = Theme.of(context);
    final subjects = provider.subjects;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            Text(
              widget.record == null ? 'Mark Attendance' : 'Edit Attendance',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Period $_periodNumber' + (widget.slot != null ? ' (${widget.slot!.startTime} - ${widget.slot!.endTime})' : ''),
              style: const TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const Divider(height: 32),
            _buildStepContent(subjects, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent(List<Subject> subjects, ThemeData theme) {
    if (_step == 0) {
      final scheduledSubName = widget.subject?.name ?? "Scheduled Class";
      return Column(
        children: [
          Text(
            'Is the scheduled class "$scheduledSubName" taken?',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _isScheduledTaken = false;
                        _step = 1;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: theme.colorScheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isScheduledTaken = true;
                        _chosenSubject = widget.subject;
                        _step = 2;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Yes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    } else if (_step == 1) {
      if (subjects.isEmpty) {
        return const Center(child: Text('Please add subjects in Settings first.'));
      }

      if (_chosenSubject == null || !subjects.any((s) => s.id == _chosenSubject!.id)) {
        _chosenSubject = subjects.first;
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Which class was taken instead?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Subject>(
            isExpanded: true,
            value: subjects.firstWhere((s) => s.id == _chosenSubject?.id, orElse: () => subjects.first),
            decoration: InputDecoration(
              labelText: 'Select Subject',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: subjects.map((sub) {
              return DropdownMenuItem<Subject>(
                value: sub,
                child: Text(sub.name),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _chosenSubject = val;
              });
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _step = 2;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Next', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      );
    } else if (_step == 3) {
      // Manual flow: choose subject and period first
      if (subjects.isEmpty) {
        return const Center(child: Text('Please add subjects in Settings first.'));
      }

      if (_chosenSubject == null || !subjects.any((s) => s.id == _chosenSubject!.id)) {
        _chosenSubject = subjects.first;
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Select Class Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Subject>(
            isExpanded: true,
            value: subjects.firstWhere((s) => s.id == _chosenSubject?.id, orElse: () => subjects.first),
            decoration: InputDecoration(
              labelText: 'Select Subject',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: subjects.map((sub) {
              return DropdownMenuItem<Subject>(
                value: sub,
                child: Text(sub.name),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _chosenSubject = val;
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            isExpanded: true,
            value: _periodNumber,
            decoration: InputDecoration(
              labelText: 'Select Period',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: List.generate(10, (i) => i + 1).map((p) {
              return DropdownMenuItem<int>(
                value: p,
                child: Text('Period $p'),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _periodNumber = val ?? 1;
              });
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _isScheduledTaken = true; // Mark as main subject chosen
                  _step = 2;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Next', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      );
    } else {
      final displaySubName = _chosenSubject?.name ?? widget.subject?.name ?? "Class";
      return Column(
        children: [
          Text(
            'Mark "$displaySubName" as:',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildMarkButton(context, 'ABSENT', Colors.red, theme),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMarkButton(context, 'PRESENT', Colors.green, theme),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() {
                if (widget.subject == null) {
                  _step = 3;
                } else if (_isScheduledTaken) {
                  _step = 0;
                } else {
                  _step = 1;
                }
              });
            },
            child: const Text('Back'),
          ),
        ],
      );
    }
  }

  Widget _buildMarkButton(BuildContext context, String status, Color color, ThemeData theme) {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);

    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: () async {
          final actualSubjectId = _chosenSubject?.id ?? widget.subject?.id;
          final scheduledSubjectId = widget.subject?.id;

          if (widget.record != null) {
            final updated = AttendanceRecord(
              id: widget.record!.id,
              date: widget.record!.date,
              dayOfWeek: widget.record!.dayOfWeek,
              periodNumber: widget.record!.periodNumber,
              scheduledSubjectId: scheduledSubjectId ?? actualSubjectId,
              actualSubjectId: actualSubjectId,
              status: status,
              createdAt: widget.record!.createdAt,
              note: widget.record!.note,
            );
            await provider.updateAttendance(updated);
          } else {
            final newRecord = AttendanceRecord(
              date: widget.dateMillis,
              dayOfWeek: widget.dayOfWeek,
              periodNumber: _periodNumber,
              scheduledSubjectId: scheduledSubjectId ?? actualSubjectId,
              actualSubjectId: actualSubjectId,
              status: status,
              createdAt: DateTime.now().millisecondsSinceEpoch,
            );
            await provider.addAttendance(newRecord);
          }

          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Marked as $status')),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          status,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}
