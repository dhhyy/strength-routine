import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'app/training_controller.dart';
import 'app/settings_controller.dart';
import 'data/local_settings_store.dart';
import 'data/local_training_store.dart';
import 'data/local_habit_store.dart';
import 'flow_components.dart';
import 'theme.dart';
import 'tokens.dart';
import 'onboarding_screen.dart';
import 'search_screen.dart';
import 'habits_screen.dart';
import 'training_screens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    for (final name in ['IBMPlexSansKR', 'IBMPlexMono']) {
      yield LicenseEntryWithLineBreaks([
        name,
      ], await rootBundle.loadString('assets/fonts/OFL-$name.txt'));
    }
  });
  runApp(const StrengthApp());
}

class StrengthApp extends StatelessWidget {
  final TrainingController? controller;
  final DateTime Function()? now;
  final LocalHabitStore? habitStore;
  const StrengthApp({super.key, this.controller, this.now, this.habitStore});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '오늘 루틴',
    debugShowCheckedModeBanner: false,
    theme: buildConsoleTheme(),
    home: RootGate(controller: controller, now: now, habitStore: habitStore),
  );
}

class RootGate extends StatefulWidget {
  final TrainingController? controller;
  final DateTime Function()? now;
  final LocalHabitStore? habitStore;
  const RootGate({super.key, this.controller, this.now, this.habitStore});
  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  TrainingController? _controller;
  SettingsController? _settings;
  bool _opening = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      if (_controller == null) {
        if (widget.controller != null) {
          _controller = widget.controller;
        } else {
          final directory = await getApplicationSupportDirectory();
          _controller = TrainingController(
            now: widget.now,
            store: LocalTrainingStore(
              File('${directory.path}/training-state.json'),
            ),
          );
        }
      }
      _settings ??= SettingsController(
        store: LocalSettingsStore(
          File(
            widget.controller == null
                ? '${_controller!.store.file.parent.path}/app-settings.json'
                : '${_controller!.store.file.path}.settings.json',
          ),
        ),
      );
      if (_settings!.loading) await _settings!.initialize();
      if (_controller!.loading || _controller!.loadError != null) {
        await _controller!.initialize();
      }
    } catch (_) {
      _error = '기록 저장 공간을 열지 못했어요.';
    }
    if (mounted) setState(() => _opening = false);
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller?.dispose();
    _settings?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_opening) {
      return FlowPage(
        title: '오늘 루틴',
        children: [
          const LinearProgressIndicator(),
          Text('저장된 기록을 불러오고 있어요.', style: AppType.body),
        ],
      );
    }
    if (_error != null || _controller == null) {
      return FlowPage(
        title: '오늘 루틴',
        children: [
          StatePanel(
            title: '기록을 불러오지 못했어요',
            message: '저장 공간을 확인한 뒤 다시 시도해 주세요.',
            action: PrimaryAction(label: '다시 시도', onPressed: _open),
          ),
        ],
      );
    }
    final c = _controller!;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        if (c.loadError != null) {
          return FlowPage(
            title: '오늘 루틴',
            children: [
              StatePanel(
                title: '기록을 불러오지 못했어요',
                message: c.loadError!,
                action: PrimaryAction(label: '다시 시도', onPressed: _open),
              ),
            ],
          );
        }
        if (!c.state.onboarded) {
          return OnboardingScreen(
            onDone: () => c.update((state) => state.copyWith(onboarded: true)),
          );
        }
        return SettingsScope(
          controller: _settings!,
          child: HomeShell(
            controller: c,
            now: widget.now,
            habitStore: widget.habitStore,
          ),
        );
      },
    );
  }
}

class HomeShell extends StatefulWidget {
  final TrainingController controller;
  final DateTime Function()? now;
  final LocalHabitStore? habitStore;
  const HomeShell({
    super.key,
    required this.controller,
    this.now,
    this.habitStore,
  });
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final today = widget.now?.call() ?? DateTime.now();
    return Scaffold(
      body: Column(
        children: [
          if (c.saveError != null)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.saveError!,
                        style: AppType.caption.copyWith(color: AppColors.warn),
                      ),
                    ),
                    TextButton(
                      onPressed: c.retrySave,
                      child: Text('재시도', style: AppType.action),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                ActiveTodayScreen(controller: c, today: today),
                SavedRecordsScreen(
                  controller: c,
                  today: today,
                  now: widget.now,
                ),
                SearchScreen(controller: c),
                HabitsScreen(store: widget.habitStore, now: widget.now),
                CurrentProfileScreen(controller: c),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: '오늘',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: '기록',
          ),
          NavigationDestination(icon: Icon(Icons.search), label: '검색'),
          NavigationDestination(
            icon: Icon(Icons.water_drop_outlined),
            label: '습관',
          ),
          NavigationDestination(icon: Icon(Icons.person_outline), label: '프로필'),
        ],
      ),
    );
  }
}
