import 'package:flutter/material.dart';
import 'theme.dart';
import 'onboarding_screen.dart';
import 'today_routine_screen.dart';
import 'records_screen.dart';
import 'search_screen.dart';
import 'habits_screen.dart';
import 'profile_screen.dart';

void main() => runApp(const StrengthApp());

class StrengthApp extends StatelessWidget {
  const StrengthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '오늘 루틴',
      debugShowCheckedModeBanner: false,
      theme: buildConsoleTheme(),
      home: const RootGate(),
    );
  }
}

/// 첫 실행이면 온보딩, 끝나면 5탭 앱.
/// (지금은 세션 내 상태만 — 영구 저장은 데이터 단계에서.)
class RootGate extends StatefulWidget {
  const RootGate({super.key});
  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  bool _onboarded = false;

  @override
  Widget build(BuildContext context) {
    return _onboarded
        ? const HomeShell()
        : OnboardingScreen(onDone: () => setState(() => _onboarded = true));
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  Widget _screen(int i) => switch (i) {
        0 => const TodayRoutineScreen(),
        1 => const RecordsScreen(),
        2 => const SearchScreen(),
        3 => const HabitsScreen(),
        _ => const ProfileScreen(),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screen(_index),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.monitor_heart_outlined), selectedIcon: Icon(Icons.monitor_heart), label: '오늘'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: '기록'),
          NavigationDestination(icon: Icon(Icons.search), label: '검색'),
          NavigationDestination(
              icon: Icon(Icons.water_drop_outlined), selectedIcon: Icon(Icons.water_drop), label: '습관'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '프로필'),
        ],
      ),
    );
  }
}
