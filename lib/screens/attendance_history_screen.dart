import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/attendance_provider.dart';
import '../models/attendance_record.dart';
import '../models/subject.dart';
import '../utils/color_utils.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  String _searchQuery = '';
  String _statusFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final attendance = Provider.of<AttendanceProvider>(context);

    // Group records by date (descending)
    final allRecords = List<AttendanceRecord>.from(attendance.allAttendance);
    allRecords.sort((a, b) => b.date.compareTo(a.date));

    // Filter records
    final filteredRecords = allRecords.where((record) {
      final subject = attendance.subjects.firstWhere(
        (s) => s.id == (record.actualSubjectId ?? record.scheduledSubjectId),
        orElse: () => Subject(id: -1, name: 'Unknown', code: 'UNK', facultyName: '', colorHex: '#9E9E9E', createdAt: 0),
      );

      final matchesSearch = subject.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          subject.code.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStatus = _statusFilter == 'ALL' || record.status == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();

    // Group by date string
    final Map<String, List<AttendanceRecord>> groupedRecords = {};
    for (var record in filteredRecords) {
      final dateStr = DateFormat('EEEE, d MMMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(record.date));
      if (groupedRecords.containsKey(dateStr)) {
        groupedRecords[dateStr]!.add(record);
      } else {
        groupedRecords[dateStr] = [record];
      }
    }

    final dateKeys = groupedRecords.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Filter section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by subject name or code...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Status: ', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment<String>(value: 'ALL', label: Text('All')),
                          ButtonSegment<String>(value: 'PRESENT', label: Text('Present')),
                          ButtonSegment<String>(value: 'ABSENT', label: Text('Absent')),
                          ButtonSegment<String>(value: 'CANCELLED', label: Text('Cancelled')),
                        ],
                        selected: {_statusFilter},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _statusFilter = newSelection.first;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // History list
          Expanded(
            child: filteredRecords.isEmpty
                ? Center(
                    child: Text(
                      'No attendance records found',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    itemCount: dateKeys.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemBuilder: (context, dateIndex) {
                      final dateStr = dateKeys[dateIndex];
                      final recordsForDate = groupedRecords[dateStr]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                            child: Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          ...recordsForDate.map((record) {
                            final subject = attendance.subjects.firstWhere(
                              (s) => s.id == (record.actualSubjectId ?? record.scheduledSubjectId),
                              orElse: () => Subject(id: -1, name: 'Unknown', code: 'UNK', facultyName: '', colorHex: '#9E9E9E', createdAt: 0),
                            );

                            Color statusColor;
                            IconData statusIcon;
                            switch (record.status) {
                              case 'PRESENT':
                                statusColor = Colors.green;
                                statusIcon = Icons.check_circle;
                                break;
                              case 'ABSENT':
                                statusColor = Colors.red;
                                statusIcon = Icons.cancel;
                                break;
                              default:
                                statusColor = Colors.grey;
                                statusIcon = Icons.remove_circle;
                                break;
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8.0),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: ColorUtils.fromHex(subject.colorHex),
                                  child: Text(
                                    'P${record.periodNumber}',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(subject.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                                subtitle: Text(
                                  'Period ${record.periodNumber} • ${record.status}',
                                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                                  onPressed: () => _confirmDelete(context, record, attendance, subject),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, AttendanceRecord record, AttendanceProvider provider, Subject subject) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Record'),
          content: Text('Are you sure you want to delete the attendance record for ${subject.name} (Period ${record.periodNumber})?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (record.id != null) {
                  await provider.deleteAttendance(record.id!);
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Record deleted successfully')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
