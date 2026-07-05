import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/settings_provider.dart';
import '../services/notification_service.dart';

class DailySetupPrompt extends StatefulWidget {
  const DailySetupPrompt({super.key});

  @override
  State<DailySetupPrompt> createState() => _DailySetupPromptState();
}

class _DailySetupPromptState extends State<DailySetupPrompt> {
  bool _showPrompt = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPrompt();
    });
  }

  void _checkPrompt() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final weekday = now.weekday; // 1 = Monday, 7 = Sunday

    if (weekday == DateTime.sunday) {
      return;
    }

    // Parse periods today
    final defaultPeriodsToday = _getPeriodsForDay(settings.periodsPerDayString, weekday);

    if (defaultPeriodsToday == 0) {
      if (settings.lastPromptedDate != todayStr) {
        settings.setLastPromptedDate(todayStr);
        // Clear daily alarms for today
        NotificationService().scheduleDailyPeriodEndReminders(
          startTimeMins: settings.collegeStartTimeMinutes,
          periodDurationMins: settings.periodDurationMinutes,
          lunchDurationMins: settings.lunchBreakDurationMinutes,
          lunchPeriodIdx: settings.lunchPeriodIndex,
          totalPeriodsToday: 0,
        );
      }
    } else {
      if (settings.lastPromptedDate.isEmpty || settings.lastPromptedDate != todayStr) {
        setState(() {
          _showPrompt = true;
        });
      }
    }
  }

  int _getPeriodsForDay(String periodsStr, int dayOfWeek) {
    if (periodsStr.contains(':')) {
      final Map<int, int> map = {};
      for (var part in periodsStr.split(',')) {
        final kv = part.split(':');
        if (kv.length == 2) {
          final k = int.tryParse(kv[0]);
          final v = int.tryParse(kv[1]);
          if (k != null && v != null) {
            map[k] = v;
          }
        }
      }
      return map[dayOfWeek] ?? 6;
    } else {
      final list = periodsStr.split(',').map((x) => int.tryParse(x.trim()) ?? 7).toList();
      if (dayOfWeek >= 1 && dayOfWeek <= 6) {
        return list[dayOfWeek - 1];
      }
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showPrompt) return const SizedBox.shrink();

    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final defaultPeriodsToday = _getPeriodsForDay(settings.periodsPerDayString, now.weekday);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Timetable Check',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Is today a Full Day following your normal timetable?',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _showPrompt = false;
                    });
                    _showCustomizeSheet(context, settings, defaultPeriodsToday, todayStr);
                  },
                  child: const Text('No, Customize'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    await settings.setLastPromptedDate(todayStr);
                    setState(() {
                      _showPrompt = false;
                    });

                    // Schedule default period end alarms
                    await NotificationService().scheduleDailyPeriodEndReminders(
                      startTimeMins: settings.collegeStartTimeMinutes,
                      periodDurationMins: settings.periodDurationMinutes,
                      lunchDurationMins: settings.lunchBreakDurationMinutes,
                      lunchPeriodIdx: settings.lunchPeriodIndex,
                      totalPeriodsToday: defaultPeriodsToday,
                    );
                  },
                  child: const Text('Yes, Full Day'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomizeSheet(
      BuildContext context, SettingsProvider settings, int totalPeriods, String todayStr) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DailyOverrideSheet(
          initialStartMins: settings.collegeStartTimeMinutes,
          initialPeriodMins: settings.periodDurationMinutes,
          initialLunchMins: settings.lunchBreakDurationMinutes,
          initialLunchIndex: settings.lunchPeriodIndex,
          totalPeriods: totalPeriods,
          onSave: (start, period, lunch, lunchIdx) async {
            await settings.setLastPromptedDate(todayStr);
            await NotificationService().scheduleDailyPeriodEndReminders(
              startTimeMins: start,
              periodDurationMins: period,
              lunchDurationMins: lunch,
              lunchPeriodIdx: lunchIdx,
              totalPeriodsToday: totalPeriods,
            );
          },
        );
      },
    );
  }
}

class DailyOverrideSheet extends StatefulWidget {
  final int initialStartMins;
  final int initialPeriodMins;
  final int initialLunchMins;
  final int initialLunchIndex;
  final int totalPeriods;
  final Function(int start, int period, int lunch, int lunchIdx) onSave;

  const DailyOverrideSheet({
    super.key,
    required this.initialStartMins,
    required this.initialPeriodMins,
    required this.initialLunchMins,
    required this.initialLunchIndex,
    required this.totalPeriods,
    required this.onSave,
  });

  @override
  State<DailyOverrideSheet> createState() => _DailyOverrideSheetState();
}

class _DailyOverrideSheetState extends State<DailyOverrideSheet> {
  late TextEditingController _startController;
  late TextEditingController _periodController;
  late TextEditingController _lunchController;
  late TextEditingController _lunchIndexController;

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController(text: _formatMinsToTime(widget.initialStartMins));
    _periodController = TextEditingController(text: widget.initialPeriodMins.toString());
    _lunchController = TextEditingController(text: widget.initialLunchMins.toString());
    _lunchIndexController = TextEditingController(text: widget.initialLunchIndex.toString());
  }

  @override
  void dispose() {
    _startController.dispose();
    _periodController.dispose();
    _lunchController.dispose();
    _lunchIndexController.dispose();
    super.dispose();
  }

  String _formatMinsToTime(int minutes) {
    final h = (minutes / 60).floor() % 24;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  int _parseTimeToMins(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length != 2) return 540;
    final h = int.tryParse(parts[0]) ?? 9;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  Future<void> _selectTime(BuildContext context) async {
    final parts = _startController.text.split(':');
    final initialHour = parts.length == 2 ? (int.tryParse(parts[0]) ?? 9) : 9;
    final initialMinute = parts.length == 2 ? (int.tryParse(parts[1]) ?? 0) : 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
    );

    if (picked != null) {
      final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        _startController.text = formatted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          const Text(
            'Customize Today\'s Alarms',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _startController,
                  readOnly: true,
                  onTap: () => _selectTime(context),
                  decoration: const InputDecoration(
                    labelText: 'Start Time',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.access_time),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _periodController,
                  decoration: const InputDecoration(
                    labelText: 'Period (mins)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _lunchController,
                  decoration: const InputDecoration(
                    labelText: 'Lunch (mins)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _lunchIndexController,
                  decoration: const InputDecoration(
                    labelText: 'Lunch after Period #',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                final start = _parseTimeToMins(_startController.text);
                final period = int.tryParse(_periodController.text) ?? 50;
                final lunch = int.tryParse(_lunchController.text) ?? 45;
                final lunchIdx = int.tryParse(_lunchIndexController.text) ?? 4;

                widget.onSave(start, period, lunch, lunchIdx);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Save Override Alarms', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
