import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/attendance_provider.dart';
import '../models/timetable_entry.dart';
import '../models/subject.dart';
import '../utils/color_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/settings_provider.dart';
import '../services/timetable_parser_service.dart';
import '../services/openrouter_service.dart';
import 'timetable_import_preview_screen.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  int _selectedDay = 1; // 1 = Mon, 6 = Sat

  static const List<String> _dayShortNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const List<String> _dayFullNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday'
  ];

  @override
  Widget build(BuildContext context) {
    final attendance = Provider.of<AttendanceProvider>(context);
    final daySlots = attendance.timetableSlots
        .where((slot) => slot.dayOfWeek == _selectedDay)
        .toList();
    daySlots.sort((a, b) => a.periodNumber.compareTo(b.periodNumber));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Timetable',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareTimetable(context, attendance),
            tooltip: 'Share Timetable',
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _scanTimetable(context, attendance),
            tooltip: 'Scan Timetable',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditorSheet(context, null),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Icon(
          Icons.add,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
      body: Column(
        children: [
          // Import Timetable button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showImportOptions(context),
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Import Timetable', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // Day Selection Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: List.generate(6, (index) {
                final day = index + 1;
                final isSelected = _selectedDay == day;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  key: ValueKey(day),
                  child: FilterChip(
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedDay = day;
                        });
                      }
                    },
                    label: Text(_dayShortNames[index]),
                    selectedColor: Theme.of(context).colorScheme.primary,
                    checkmarkColor: Theme.of(context).colorScheme.onPrimary,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                );
              }),
            ),
          ),

          // Slots List
          Expanded(
            child: daySlots.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: daySlots.length,
                    itemBuilder: (context, index) {
                      final slot = daySlots[index];
                      final subject = attendance.subjects.firstWhere(
                        (s) => s.id == slot.subjectId,
                        orElse: () => Subject(
                          id: -1,
                          name: 'Free Period or Class',
                          code: 'FREE',
                          facultyName: '',
                          colorHex: '#EEEEEE',
                          createdAt: 0,
                        ),
                      );

                      final subjectColor = slot.subjectId == null
                          ? Theme.of(context).colorScheme.surfaceContainerHighest
                          : ColorUtils.fromHex(subject.colorHex);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          color: subjectColor.withOpacity(0.12),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Period or Class ${slot.periodNumber}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: subjectColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        subject.name,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${_formatTime(slot.startTime)} - ${_formatTime(slot.endTime)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _showEditorSheet(context, slot),
                                  icon: Icon(
                                    Icons.edit,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _deleteSlot(context, slot),
                                  icon: Icon(
                                    Icons.delete,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_month,
            size: 64,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Periods or Classes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap + to add periods or classes for ${_dayFullNames[_selectedDay - 1]}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final tod = TimeOfDay(hour: hour, minute: minute);
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
      return TimeOfDay.fromDateTime(dt).format(context);
    } catch (_) {
      return timeStr;
    }
  }

  void _deleteSlot(BuildContext context, TimetableSlot slot) {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Period or Class'),
        content: Text('Are you sure you want to delete Period or Class ${slot.periodNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await provider.deleteTimetableSlot(slot.id!);
              if (context.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditorSheet(BuildContext context, TimetableSlot? slot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return TimetableEditorSheet(
          selectedDay: _selectedDay,
          editingSlot: slot,
        );
      },
    );
  }

  void _shareTimetable(BuildContext context, AttendanceProvider provider) {
    final subjects = provider.subjects;
    final slots = provider.timetableSlots;

    final List<Map<String, dynamic>> subjectMaps = subjects.map((sub) => {
      'name': sub.name,
      'code': sub.code,
      'color': sub.colorHex,
    }).toList();

    final List<Map<String, dynamic>> slotMaps = slots.map((slot) {
      final subIdx = subjects.indexWhere((sub) => sub.id == slot.subjectId);
      return {
        'day': slot.dayOfWeek,
        'p': slot.periodNumber,
        'start': slot.startTime,
        'end': slot.endTime,
        'subIdx': subIdx,
      };
    }).toList();

    final payload = jsonEncode({
      'version': 1,
      'subjects': subjectMaps,
      'slots': slotMaps,
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Timetable'),
        content: SizedBox(
          width: 280,
          height: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              QrImageView(
                data: payload,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 16),
              const Text(
                'Let your classmate scan this QR code inside their AttendX app to import this timetable instantly.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _scanTimetable(BuildContext context, AttendanceProvider provider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRScannerScreen(onScan: (data) async {
          await _importTimetableData(context, provider, data);
        }),
      ),
    );
  }

  Future<void> _importTimetableData(BuildContext context, AttendanceProvider provider, String data) async {
    try {
      final decoded = jsonDecode(data);
      if (decoded['version'] != 1 || decoded['subjects'] == null || decoded['slots'] == null) {
        throw Exception('Invalid timetable format');
      }

      final List<dynamic> subjectsData = decoded['subjects'];
      final List<dynamic> slotsData = decoded['slots'];
      final Map<int, int?> subjectIdMapping = {};

      for (int i = 0; i < subjectsData.length; i++) {
        final subMap = subjectsData[i];
        final name = subMap['name'].toString();
        final code = subMap['code'].toString();
        final color = subMap['color'].toString();

        Subject? existingSubject;
        try {
          existingSubject = provider.subjects.firstWhere((s) => s.code.toLowerCase() == code.toLowerCase() || s.name.toLowerCase() == name.toLowerCase());
        } catch (_) {}

        if (existingSubject != null) {
          subjectIdMapping[i] = existingSubject.id;
        } else {
          final newSub = Subject(
            name: name,
            code: code,
            colorHex: color,
            facultyName: '',
            createdAt: DateTime.now().millisecondsSinceEpoch,
          );
          await provider.addSubject(newSub);
          
          final updatedProvider = Provider.of<AttendanceProvider>(context, listen: false);
          final createdSub = updatedProvider.subjects.firstWhere((s) => s.code.toLowerCase() == code.toLowerCase());
          subjectIdMapping[i] = createdSub.id;
        }
      }

      await provider.clearTimetable();

      for (var slotMap in slotsData) {
        final day = slotMap['day'] as int;
        final period = slotMap['p'] as int;
        final start = slotMap['start'].toString();
        final end = slotMap['end'].toString();
        final subIdx = slotMap['subIdx'] as int;

        int? mappedSubId;
        if (subIdx != -1 && subjectIdMapping.containsKey(subIdx)) {
          mappedSubId = subjectIdMapping[subIdx];
        }

        final slot = TimetableSlot(
          dayOfWeek: day,
          periodNumber: period,
          startTime: start,
          endTime: end,
          subjectId: mappedSubId,
        );
        await provider.saveTimetableSlot(slot);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timetable imported successfully! 🎉')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Import Failed'),
            content: Text('Could not import timetable. Error: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        );
      }
    }
  }

  final TimetableParserService _parserService = TimetableParserService();
  final OpenRouterService _openRouterService = OpenRouterService();

  Future<void> _checkOpenRouterKey(BuildContext context, VoidCallback onKeyReady) async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('openrouter_api_key') ?? '';
    if (key.isNotEmpty) {
      onKeyReady();
      return;
    }

    if (!context.mounted) return;

    final keyController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('OpenRouter API Key Required', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To extract your timetable using AI, AttendX needs a free API Key from OpenRouter.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              'How to get a Free API Key:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const Text('1. Go to openrouter.ai/keys\\n2. Create a Free API Key\\n3. Copy and paste it below.', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: keyController,
              decoration: const InputDecoration(
                labelText: 'Paste API Key here',
                border: OutlineInputBorder(),
                hintText: 'sk-or-v1-...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newKey = keyController.text.trim();
              if (newKey.isNotEmpty) {
                await prefs.setString('openrouter_api_key', newKey);
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                onKeyReady();
              }
            },
            child: const Text('Save & Continue'),
          ),
        ],
      ),
    );
  }

  void _showImportOptions(BuildContext context) {
    _checkOpenRouterKey(context, () {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (sheetCtx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.deepPurple[50],
                    child: const Icon(Icons.image_outlined, color: Colors.deepPurple),
                  ),
                  title: const Text('Import from Image', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Capture photo or upload from Gallery'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _importFromImage(context);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red[50],
                    child: Icon(Icons.picture_as_pdf_outlined, color: Colors.red[700]),
                  ),
                  title: const Text('Import from PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Select a scanned or digital PDF file'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _importFromPdf(context);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green[50],
                    child: Icon(Icons.table_chart_outlined, color: Colors.green[700]),
                  ),
                  title: const Text('Import from Excel', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Select a .xlsx or .xls file'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _importFromExcel(context);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[50],
                    child: Icon(Icons.description_outlined, color: Colors.blue[700]),
                  ),
                  title: const Text('Import from CSV', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Select a standard CSV file'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _importFromCsv(context);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Future<void> _processImport({
    required BuildContext context,
    required String fileType,
    required bool isVision,
    required Future<dynamic> Function() extractor,
  }) async {
    String status = "Extracting layout & processing $fileType...";
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    status,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      final extractedData = await extractor();
      if (extractedData == null || (extractedData is String && extractedData.isEmpty) || (extractedData is List && extractedData.isEmpty)) {
        if (context.mounted) Navigator.pop(context);
        return;
      }

      final settings = Provider.of<SettingsProvider>(context, listen: false);
      List<Map<String, dynamic>> result;

      if (isVision) {
        // Send base64 image strings directly to AI model
        final List<String> images = extractedData is String ? [extractedData] : List<String>.from(extractedData);
        result = await _openRouterService.parseTimetableWithVision(
          base64Images: images,
          collegeStartMins: settings.collegeStartTimeMinutes,
          periodDuration: settings.periodDurationMinutes,
          lunchStartMins: settings.lunchStartTimeMinutes,
          lunchEndMins: settings.lunchEndTimeMinutes,
        );
      } else {
        // Excel and CSV (text-based extraction)
        result = await _openRouterService.parseTimetable(
          rawText: extractedData as String,
          fileType: fileType,
          collegeStartMins: settings.collegeStartTimeMinutes,
          periodDuration: settings.periodDurationMinutes,
          lunchStartMins: settings.lunchStartTimeMinutes,
          lunchEndMins: settings.lunchEndTimeMinutes,
        );
      }

      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TimetableImportPreviewScreen(initialSlots: result),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('AI Import Failed'),
            content: Text('Could not extract timetable. Error: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _importFromImage(BuildContext context) async {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Import from Image', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Capture a photo of your timetable or upload an existing image from Gallery.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _processImport(
                context: context,
                fileType: "Image (Camera)",
                isVision: true,
                extractor: () => _parserService.parseImageToBase64(ImageSource.camera),
              );
            },
            child: const Text('Take Photo'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _processImport(
                context: context,
                fileType: "Image (Gallery)",
                isVision: true,
                extractor: () => _parserService.parseImageToBase64(ImageSource.gallery),
              );
            },
            child: const Text('Upload Gallery'),
          ),
        ],
      ),
    );
  }

  Future<void> _importFromPdf(BuildContext context) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.single.path != null) {
        if (context.mounted) {
          _processImport(
            context: context,
            fileType: "PDF",
            isVision: true,
            extractor: () => _parserService.parsePdfToBase64(result.files.single.path!),
          );
        }
      }
    } catch (e) {
      debugPrint("PDF pick error: $e");
    }
  }

  Future<void> _importFromExcel(BuildContext context) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (result != null && result.files.single.path != null) {
        if (context.mounted) {
          _processImport(
            context: context,
            fileType: "Excel",
            isVision: false,
            extractor: () => _parserService.parseExcel(result.files.single.path!),
          );
        }
      }
    } catch (e) {
      debugPrint("Excel pick error: $e");
    }
  }

  Future<void> _importFromCsv(BuildContext context) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result != null && result.files.single.path != null) {
        if (context.mounted) {
          _processImport(
            context: context,
            fileType: "CSV",
            isVision: false,
            extractor: () => _parserService.parseCsv(result.files.single.path!),
          );
        }
      }
    } catch (e) {
      debugPrint("CSV pick error: $e");
    }
  }
}

class TimetableEditorSheet extends StatefulWidget {
  final int selectedDay;
  final TimetableSlot? editingSlot;

  const TimetableEditorSheet({
    super.key,
    required this.selectedDay,
    this.editingSlot,
  });

  @override
  State<TimetableEditorSheet> createState() => _TimetableEditorSheetState();
}

class _TimetableEditorSheetState extends State<TimetableEditorSheet> {
  int? _selectedSubjectId;
  String _startTime = '09:00';
  String _endTime = '10:00';

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = widget.editingSlot?.subjectId;
    _startTime = widget.editingSlot?.startTime ?? '09:00';
    _endTime = widget.editingSlot?.endTime ?? '10:00';
  }

  Future<void> _selectTime(bool isStart) async {
    final initialTimeStr = isStart ? _startTime : _endTime;
    final parts = initialTimeStr.split(':');
    final initialHour = int.tryParse(parts[0]) ?? 9;
    final initialMinute = int.tryParse(parts[1]) ?? 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
    );

    if (picked != null) {
      final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isStart) {
          _startTime = formatted;
        } else {
          _endTime = formatted;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendance = Provider.of<AttendanceProvider>(context);
    final theme = Theme.of(context);

    final subjects = attendance.subjects;
    final selectedSubjectName = _selectedSubjectId == null
        ? 'Free Period or Class'
        : subjects.firstWhere((s) => s.id == _selectedSubjectId).name;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
            widget.editingSlot != null ? 'Edit Period or Class' : 'Add Period or Class',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Dropdown for Subject
          DropdownButtonFormField<int?>(
            value: _selectedSubjectId,
            decoration: InputDecoration(
              labelText: 'Subject',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Free Period or Class'),
              ),
              ...subjects.map((sub) => DropdownMenuItem<int?>(
                    value: sub.id,
                    child: Text(sub.name),
                  )),
            ],
            onChanged: (val) {
              setState(() {
                _selectedSubjectId = val;
              });
            },
          ),
          const SizedBox(height: 16),

          // Start & End Time Fields
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectTime(true),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Start',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(_startTime),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _selectTime(false),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'End',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(_endTime),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Save Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () async {
                final provider = Provider.of<AttendanceProvider>(context, listen: false);
                if (widget.editingSlot != null) {
                  final updatedSlot = TimetableSlot(
                    id: widget.editingSlot!.id,
                    dayOfWeek: widget.editingSlot!.dayOfWeek,
                    periodNumber: widget.editingSlot!.periodNumber,
                    startTime: _startTime,
                    endTime: _endTime,
                    subjectId: _selectedSubjectId,
                  );
                  await provider.saveTimetableSlot(updatedSlot);
                } else {
                  // Calculate max period
                  final daySlots = provider.timetableSlots
                      .where((s) => s.dayOfWeek == widget.selectedDay)
                      .toList();
                  int maxPeriod = 0;
                  for (var slot in daySlots) {
                    if (slot.periodNumber > maxPeriod) {
                      maxPeriod = slot.periodNumber;
                    }
                  }

                  final newSlot = TimetableSlot(
                    dayOfWeek: widget.selectedDay,
                    periodNumber: maxPeriod + 1,
                    startTime: _startTime,
                    endTime: _endTime,
                    subjectId: _selectedSubjectId,
                  );
                  await provider.saveTimetableSlot(newSlot);
                }

                if (mounted) {
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                widget.editingSlot != null ? 'Update' : 'Add Period or Class',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class QRScannerScreen extends StatefulWidget {
  final Function(String) onScan;

  const QRScannerScreen({super.key, required this.onScan});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool _processed = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Timetable QR'),
      ),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty && !_processed) {
            final rawValue = barcodes.first.rawValue;
            if (rawValue != null) {
              _processed = true;
              widget.onScan(rawValue);
              Navigator.pop(context);
            }
          }
        },
      ),
    );
  }
}
