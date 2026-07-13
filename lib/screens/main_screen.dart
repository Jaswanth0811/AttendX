import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'timetable_screen.dart';
import 'calendar_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';
import '../services/update_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService().checkForUpdates(context, silent: true);
    });
  }

  final List<Widget> _screens = const [
    DashboardScreen(),
    TimetableScreen(),
    CalendarScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: _screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.95),
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  indicatorColor: Colors.transparent,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                  iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
                    if (states.contains(WidgetState.selected)) {
                      return IconThemeData(
                        color: theme.colorScheme.primary,
                        size: 26,
                      );
                    }
                    return IconThemeData(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                      size: 26,
                    );
                  }),
                ),
                child: NavigationBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.schedule_outlined),
                      selectedIcon: Icon(Icons.schedule),
                      label: 'Timetable',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.calendar_month_outlined),
                      selectedIcon: Icon(Icons.calendar_month),
                      label: 'Calendar',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.analytics_outlined),
                      selectedIcon: Icon(Icons.analytics),
                      label: 'Analytics',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: 'Settings',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
