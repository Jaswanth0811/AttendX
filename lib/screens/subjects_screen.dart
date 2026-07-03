import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../models/subject.dart';
import '../utils/color_utils.dart';
import 'dart:math';

class SubjectsScreen extends StatelessWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subjects'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _showAddSubjectDialog(context);
            },
          ),
        ],
      ),
      body: Consumer<AttendanceProvider>(
        builder: (context, attendance, child) {
          final subjects = attendance.subjects;
          if (subjects.isEmpty) {
            return const Center(child: Text('No subjects added yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              final subject = subjects[index];
              final stats = _calculateSubjectStats(attendance, subject.id!);
              
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: ColorUtils.fromHex(subject.colorHex),
                    child: Text(
                      subject.code.substring(0, min(subject.code.length, 2)),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(subject.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(subject.facultyName),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${stats['percent']!.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: stats['percent']! >= 75.0 ? Colors.green : Colors.red,
                        ),
                      ),
                      Text(
                        '${stats['present']}/${stats['total']}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  onTap: () {
                    // Show options to edit/delete
                    _showEditSubjectDialog(context, subject);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Map<String, double> _calculateSubjectStats(AttendanceProvider attendance, int subjectId) {
    final records = attendance.allAttendance.where((r) => r.scheduledSubjectId == subjectId).toList();
    if (records.isEmpty) return {'percent': 0.0, 'present': 0.0, 'total': 0.0};
    
    int present = 0;
    int total = 0;
    for (var r in records) {
      if (r.status == 'PRESENT' || r.status == 'SEMINAR') {
        present++;
        total++;
      } else if (r.status == 'ABSENT') {
        total++;
      }
    }
    
    if (total == 0) return {'percent': 0.0, 'present': 0.0, 'total': 0.0};
    return {
      'percent': (present / total) * 100,
      'present': present.toDouble(),
      'total': total.toDouble(),
    };
  }

  void _showAddSubjectDialog(BuildContext context) {
    // Implement add subject form (Name, Code, Faculty, Color)
  }

  void _showEditSubjectDialog(BuildContext context, Subject subject) {
    // Implement edit/delete
  }
}
