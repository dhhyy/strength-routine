import 'backup_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app/training_controller.dart';
import 'app/settings_controller.dart';
import 'app/working_max_controller.dart';
import 'app/working_max_scope.dart';
import 'app/deferred_exercise_controller.dart';
import 'app/deferred_exercise_scope.dart';
import 'app/app_environment.dart';
import 'auth/auth_controller.dart';
import 'auth/auth_config.dart';
import 'auth/auth_scope.dart';
import 'auth/login_screen.dart';
import 'auth/signup_screen.dart';
import 'app/cloud_snapshot_controller.dart';
import 'app/cloud_snapshot_scope.dart';
import 'data/app_storage.dart';
import 'data/cloud_snapshot_store.dart';
import 'data/supabase_cloud_snapshot_store.dart';
import 'data/local_settings_store.dart';
import 'data/local_training_store.dart';
import 'data/local_working_max_store.dart';
import 'data/local_deferred_exercise_store.dart';
import 'data/local_habit_store.dart';
import 'data/rest_timer_store.dart';
import 'data/text_store.dart';
import 'demo/e1rm_demo.dart';
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
  final AuthController? auth;
  final DateTime Function()? now;
  final LocalHabitStore? habitStore;
  const StrengthApp({
    super.key,
    this.controller,
    this.auth,
    this.now,
    this.habitStore,
  });
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '오늘 루틴',
    debugShowCheckedModeBanner: false,
    theme: buildConsoleTheme(),
    home: RootGate(
      controller: controller,
      auth: auth,
      now: now,
      habitStore: habitStore,
    ),
  );
}

class RootGate extends StatefulWidget {
  final TrainingController? controller;
  final AuthController? auth;
  final DateTime Function()? now;
  final LocalHabitStore? habitStore;
  const RootGate({
    super.key,
    this.controller,
    this.auth,
    this.now,
    this.habitStore,
  });
  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  TrainingController? _controller;
  SettingsController? _settings;
  WorkingMaxController? _workingMax;
  DeferredExerciseController? _deferred;
  CloudSnapshotController? _cloud;
  AuthController? _auth;
  LocalHabitStore? _habitStore;
  TextStore? _trialStore;
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
      final needsStorage =
          widget.controller == null ||
          widget.auth == null ||
          widget.habitStore == null;
      final storage = needsStorage ? await AppStorage.open() : null;

      _auth ??=
          widget.auth ??
          AuthController(bypassBlobs: storage!.authBypass);
      if (!_auth!.ready) await _auth!.initialize();
      if (_controller == null) {
        if (widget.controller != null) {
          _controller = widget.controller;
        } else {
          _controller = TrainingController(
            now: widget.now,
            store: LocalTrainingStore.blobs(storage!.training),
            restTimerStore: RestTimerStore.blobs(storage.restTimer),
          );
        }
      }
      _settings ??= SettingsController(
        store: LocalSettingsStore.blobs(
          widget.controller == null
              ? storage!.settings
              : _controller!.store.blobs.sibling('.settings.json'),
        ),
      );
      _workingMax ??= WorkingMaxController(
        store: LocalWorkingMaxStore.blobs(
          widget.controller == null
              ? storage!.workingMax
              : _controller!.store.blobs.sibling('.working-max.json'),
        ),
      );
      _deferred ??= DeferredExerciseController(
        store: LocalDeferredExerciseStore.blobs(
          widget.controller == null
              ? storage!.deferred
              : _controller!.store.blobs.sibling('.deferred-exercises.json'),
        ),
      );
      if (_settings!.loading) await _settings!.initialize();
      if (_workingMax!.loading) await _workingMax!.initialize();
      if (_deferred!.loading) await _deferred!.initialize();
      if (_controller!.loading || _controller!.loadError != null) {
        await _controller!.initialize();
      }
      if (widget.controller == null &&
          shouldSeedStagingE1rmDemo(
            isStaging: AppEnvironment.current.isStaging,
            isWeb: kIsWeb,
            activePlan: _controller!.state.activePlan,
          )) {
        final demo = buildE1rmDemo(now: widget.now?.call() ?? DateTime.now());
        final saved = await _controller!.update((_) => demo.state);
        if (saved) {
          await _workingMax!.replaceState(demo.workingMax);
        }
      }
      _cloud ??= CloudSnapshotController(
        auth: _auth!,
        training: _controller!,
        workingMax: _workingMax!,
        store: AuthConfig.isConfigured
            ? SupabaseCloudSnapshotStore()
            : MemoryCloudSnapshotStore(),
      );
      if (_auth!.isSignedIn && !_controller!.state.onboarded) {
        await _controller!.update((state) => state.copyWith(onboarded: true));
      }
      _habitStore ??=
          widget.habitStore ?? LocalHabitStore.blobs(storage!.habits);
      _trialStore ??= storage?.trial;
    } catch (error, stack) {
      debugPrint('RootGate._open: $error\n$stack');
      _error = '기록 저장 공간을 열지 못했어요.';
    }
    if (mounted) setState(() => _opening = false);
  }

  Future<void> _afterAuth() async {
    final c = _controller;
    if (c == null) return;
    if (!c.state.onboarded) {
      await c.update((state) => state.copyWith(onboarded: true));
    }
  }

  void _openSignup() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SignupScreen(auth: _auth!, onSignedIn: _afterAuth),
      ),
    );
  }

  void _openLogin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(auth: _auth!, onSignedIn: _afterAuth),
      ),
    );
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller?.dispose();
    if (widget.auth == null) _auth?.dispose();
    _settings?.dispose();
    _workingMax?.dispose();
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
    if (_error != null || _controller == null || _auth == null) {
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
    final auth = _auth!;
    return ListenableBuilder(
      listenable: Listenable.merge([c, auth]),
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
              PrimaryAction(
                label: '백업으로 기록 복원',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BackupScreen(controller: c),
                  ),
                ),
              ),
            ],
          );
        }
        if (!auth.isSignedIn) {
          return OnboardingScreen(
            onSignup: _openSignup,
            onLogin: _openLogin,
            onBypass: auth.canBypass
                ? () async {
                    await auth.signInBypass();
                    await _afterAuth();
                  }
                : null,
          );
        }
        return SettingsScope(
          controller: _settings!,
          child: AuthScope(
            controller: _auth!,
            child: WorkingMaxScope(
              controller: _workingMax!,
              child: DeferredExerciseScope(
                controller: _deferred!,
                child: CloudSnapshotScope(
                  controller: _cloud!,
                  child: HomeShell(
                    controller: c,
                    now: widget.now,
                    habitStore: _habitStore ?? widget.habitStore,
                    trialStore: _trialStore,
                  ),
                ),
              ),
            ),
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
  final TextStore? trialStore;
  const HomeShell({
    super.key,
    required this.controller,
    this.now,
    this.habitStore,
    this.trialStore,
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
          if (AppEnvironment.current.isStaging)
            Material(
              color: AppColors.accentSoft,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.x4,
                    vertical: AppSpace.x2,
                  ),
                  child: Text(
                    appEnvironmentLabel,
                    style: AppType.caption.copyWith(color: AppColors.accent),
                  ),
                ),
              ),
            ),
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
