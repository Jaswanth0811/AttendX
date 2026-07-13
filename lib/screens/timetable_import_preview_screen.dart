import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/settings_provider.dart';
import '../models/timetable_entry.dart';
import '../models/subject.dart';
import '../utils/color_utils.dart';

class TimetableImportPreviewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> initialSlots;

  const TimetableImportPreviewScreen({super.key, required this.initialSlots});

  @override
  State<TimetableImportPreviewScreen> createState() => _TimetableImportPreviewScreenState();
}

class _TimetableImportPreviewScreenState extends State<TimetableImportPreviewScreen> {
  late List<Map<String, dynamic>> _slots;
  final List<String> _dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  @override
  void initState() {
    super.initState();
    // Copy slot maps to a mutable list
    _slots = widget.initialSlots.map((item) => Map<String, dynamic>.from(item)).toList();
    _slots.sort((a, b) {
      final dayComp = (a['day'] as int? ?? 1).compareTo(b['day'] as int? ?? 1);
      if (dayComp != 0) return dayComp;
      return (a['periodNumber'] as int? ?? 1).compareTo(b['periodNumber'] as int? ?? 1);
    });
  }

  void _editSlot(int index) {
    final slot = _slots[index];
    final nameController = TextEditingController(text: slot['subjectName']?.toString() ?? '');
    final codeController = TextEditingController(text: slot['subjectCode']?.toString() ?? '');
    final facultyController = TextEditingController(text: slot['facultyName']?.toString() ?? '');
    final periodController = TextEditingController(text: slot['periodNumber']?.toString() ?? '1');
    
    // Parse times
    final startTimeParts = (slot['startTime']?.toString() ?? '09:00').split(':');
    final endTimeParts = (slot['endTime']?.toString() ?? '10:00').split(':');
    
    TimeOfDay startTime = TimeOfDay(
      hour: int.tryParse(startTimeParts[0]) ?? 9,
      minute: startTimeParts.length > 1 ? (int.tryParse(startTimeParts[1]) ?? 0) : 0,
    );
    TimeOfDay endTime = TimeOfDay(
      hour: int.tryParse(endTimeParts[0]) ?? 10,
      minute: endTimeParts.length > 1 ? (int.tryParse(endTimeParts[1]) ?? 0) : 0,
    );

    int selectedDay = slot['day'] as int? ?? 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20, right: 20, top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Edit Extracted Period', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),

                      // Day Selector Dropdown
                      DropdownButtonFormField<int>(
                        value: selectedDay,
                        decoration: InputDecoration(
                          labelText: 'Day of Week',
                          prefixIcon: const Icon(Icons.calendar_today_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainer,
                        ),
                        items: List.generate(6, (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text(_dayNames[i]),
                        )),
                        onChanged: (val) => setState(() => selectedDay = val!),
                      ),
                      const SizedBox(height: 16),

                      // Subject Name
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Subject Name',
                          prefixIcon: const Icon(Icons.book_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainer,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Subject Code
                      TextField(
                        controller: codeController,
                        decoration: InputDecoration(
                          labelText: 'Subject Code',
                          prefixIcon: const Icon(Icons.code),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainer,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Faculty Name
                      TextField(
                        controller: facultyController,
                        decoration: InputDecoration(
                          labelText: 'Faculty Name',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainer,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Period Number
                      TextField(
                        controller: periodController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Period or Class Number',
                          prefixIcon: const Icon(Icons.format_list_numbered),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainer,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Timings Row
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(context: context, initialTime: startTime);
                                if (picked != null) setState(() => startTime = picked);
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Start Time',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  filled: true,
                                  fillColor: Theme.of(context).colorScheme.surfaceContainer,
                                ),
                                child: Text(startTime.format(context)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(context: context, initialTime: endTime);
                                if (picked != null) setState(() => endTime = picked);
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'End Time',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  filled: true,
                                  fillColor: Theme.of(context).colorScheme.surfaceContainer,
                                ),
                                child: Text(endTime.format(context)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            final name = nameController.text.trim();
                            if (name.isEmpty) return;

                            final startStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
                            final endStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

                            this.setState(() {
                              _slots[index] = {
                                'day': selectedDay,
                                'periodNumber': int.tryParse(periodController.text) ?? 1,
                                'subjectName': name,
                                'subjectCode': codeController.text.trim(),
                                'facultyName': facultyController.text.trim(),
                                'startTime': startStr,
                                'endTime': endStr,
                              };
                              // Re-sort list
                              _slots.sort((a, b) {
                                final dayComp = (a['day'] as int? ?? 1).compareTo(b['day'] as int? ?? 1);
                                if (dayComp != 0) return dayComp;
                                return (a['periodNumber'] as int? ?? 1).compareTo(b['periodNumber'] as int? ?? 1);
                              });
                            });
                            Navigator.pop(ctx);
                          },
                          child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _addSlot() {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final facultyController = TextEditingController();
    final periodController = TextEditingController(text: '1');
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0);
    int selectedDay = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20, right: 20, top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Add Timetable Period', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),

                      // Day Selector Dropdown
                      DropdownButtonFormField<int>(
                        value: selectedDay,
                        decoration: InputDecoration(
                          labelText: 'Day of Week',
                          prefixIcon: const Icon(Icons.calendar_today_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainer,
                        ),
                        items: List.generate(6, (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text(_dayNames[i]),
                        )),
                        onChanged: (val) => setState(() => selectedDay = val!),
                      ),
                      const SizedBox(height: 16),

                      // Subject Name
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Subject Name',
                          prefixIcon: const Icon(Icons.book_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainer,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Subject Code
                      TextField(
                        controller: codeController,
                        decoration: InputDecoration(
                          labelText: 'Subject Code',
                          prefixIcon: const Icon(Icons.code),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainer,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Faculty Name
                      TextField(
                        controller: facultyController,
                        decoration: InputDecoration(
                          labelText: 'Faculty Name',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainer,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Period Number
                      TextField(
                        controller: periodController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Period or Class Number',
                          prefixIcon: const Icon(Icons.format_list_numbered),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainer,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Timings Row
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(context: context, initialTime: startTime);
                                if (picked != null) setState(() => startTime = picked);
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Start Time',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  filled: true,
                                  fillColor: Theme.of(context).colorScheme.surfaceContainer,
                                ),
                                child: Text(startTime.format(context)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(context: context, initialTime: endTime);
                                if (picked != null) setState(() => endTime = picked);
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'End Time',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  filled: true,
                                  fillColor: Theme.of(context).colorScheme.surfaceContainer,
                                ),
                                child: Text(endTime.format(context)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Add Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            final name = nameController.text.trim();
                            if (name.isEmpty) return;

                            final startStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
                            final endStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

                            this.setState(() {
                              _slots.add({
                                'day': selectedDay,
                                'periodNumber': int.tryParse(periodController.text) ?? 1,
                                'subjectName': name,
                                'subjectCode': codeController.text.trim(),
                                'facultyName': facultyController.text.trim(),
                                'startTime': startStr,
                                'endTime': endStr,
                              });
                              // Re-sort list
                              _slots.sort((a, b) {
                                final dayComp = (a['day'] as int? ?? 1).compareTo(b['day'] as int? ?? 1);
                                if (dayComp != 0) return dayComp;
                                return (a['periodNumber'] as int? ?? 1).compareTo(b['periodNumber'] as int? ?? 1);
                              });
                            });
                            Navigator.pop(ctx);
                          },
                          child: const Text('Add Period', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _deleteSlot(int index) {
    setState(() {
      _slots.removeAt(index);
    });
  }

  Future<void> _saveAndImport(BuildContext context, AttendanceProvider attendance) async {
    if (_slots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No slots to import'), backgroundColor: Colors.orange),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Loop over extracted slots and save them
      for (var s in _slots) {
        final subjectName = s['subjectName']?.toString().trim() ?? '';
        final subjectCode = s['subjectCode']?.toString().trim() ?? 'SUB';
        final facultyName = s['facultyName']?.toString().trim() ?? '';

        // 1. Resolve subject ID
        int subjectId;
        final existingSubject = attendance.subjects.firstWhere(
          (sub) => sub.name.toLowerCase() == subjectName.toLowerCase(),
          orElse: () => Subject(id: -2, name: '', code: '', facultyName: '', colorHex: '', createdAt: 0),
        );

        if (existingSubject.id != -2) {
          subjectId = existingSubject.id!;
        } else {
          // Create new subject
          final newSubject = Subject(
            name: subjectName,
            code: subjectCode,
            facultyName: facultyName,
            colorHex: '#3F51B5', // Default Indigo theme color
            createdAt: DateTime.now().millisecondsSinceEpoch,
          );
          // Wait, addSubject returns final ID!
          subjectId = await attendance.addSubject(newSubject);
        }

        // 2. Save TimetableSlot
        final slot = TimetableSlot(
          dayOfWeek: s['day'] as int? ?? 1,
          periodNumber: s['periodNumber'] as int? ?? 1,
          startTime: s['startTime']?.toString() ?? '09:00',
          endTime: s['endTime']?.toString() ?? '10:00',
          subjectId: subjectId,
        );

        await attendance.saveTimetableSlot(slot);
      }

      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        Navigator.pop(context); // Return to Timetable screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Timetable imported successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Import failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final attendance = Provider.of<AttendanceProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Extracted Timetable', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addSlot,
            tooltip: 'Add Period',
          )
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            height: 50,
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.cloud_download),
              label: const Text('Confirm & Save Timetable', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _saveAndImport(context, attendance),
            ),
          ),
        ),
      ),
      body: _slots.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_view_day, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No slots extracted', style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _slots.length,
              itemBuilder: (context, index) {
                final s = _slots[index];
                final dayNum = s['day'] as int? ?? 1;
                final dayName = _dayNames[dayNum - 1];
                final subjectName = s['subjectName']?.toString() ?? 'Subject';
                final subjectCode = s['subjectCode']?.toString() ?? '';
                final facultyName = s['facultyName']?.toString() ?? '';
                final periodNum = s['periodNumber'] as int? ?? 1;
                final startTime = s['startTime']?.toString() ?? '';
                final endTime = s['endTime']?.toString() ?? '';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        dayName,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Period or Class $periodNum',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  subjectName,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                if (subjectCode.isNotEmpty || facultyName.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '${subjectCode.isNotEmpty ? "$subjectCode " : ""}${facultyName.isNotEmpty ? "• $facultyName" : ""}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text('$startTime - $endTime', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _editSlot(index),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                            onPressed: () => _deleteSlot(index),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
