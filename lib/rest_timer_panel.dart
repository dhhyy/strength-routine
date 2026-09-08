import 'dart:async';

import 'package:flutter/material.dart';

import 'app/training_controller.dart';
import 'app/settings_controller.dart';
import 'domain/rest_timer.dart';
import 'domain/training_program.dart';
import 'flow_components.dart';
import 'tokens.dart';
import 'widgets.dart';

Future<void> startSetRest(
  BuildContext context,
  TrainingController controller,
  PlannedSession session,
  PlannedExercise exercise,
  PlannedSet set,
  int number, {
  int? defaultRestSeconds,
}) async {
  final seconds = resolveRestSeconds(set.restSeconds, defaultRestSeconds);
  if (seconds == null ||
      seconds == 0 ||
      controller.saving ||
      controller.saveError != null) {
    return;
  }
  var replace = false;
  final active = controller.restTimer.available;
  if (active != null && active.remainingMilliseconds(controller.now()) > 0) {
    replace =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.bgLift,
            title: Text('진행 중인 휴식을 바꿀까요?', style: AppType.heading),
            content: Text(
              '${active.exerciseName} ${active.setNumber}세트의 타이머를 종료하고 선택한 세트의 휴식을 시작해요.',
              style: AppType.body,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('취소', style: AppType.action),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  '타이머 바꾸기',
                  style: AppType.action.copyWith(color: AppColors.accent),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!replace || !context.mounted) return;
  }
  // Recheck after the confirmation; the workout may have changed meanwhile.
  if (controller.saving || controller.saveError != null) return;
  final plan = controller.state.activePlan;
  if (plan == null || !plan.sessions.any((s) => s.id == session.id)) return;
  await controller.restTimer.start(
    RestTimerSnapshot(
      planId: plan.id,
      sessionId: session.id,
      setId: set.id,
      exerciseName: exercise.name,
      sourceStamp: controller.restSourceStamp(session.id, set.id),
      setNumber: number,
      durationSeconds: seconds,
      durationSource: set.restSeconds == null
          ? RestDurationSource.userDefault
          : RestDurationSource.prescription,
      endsAt: controller.now().toUtc().add(Duration(seconds: seconds)),
    ),
    replace: replace,
  );
}

/// Called only once by the set editor after a new completed actual is durable.
Future<void> autoStartCompletedSetRest(
  BuildContext context,
  TrainingController controller,
  String setId,
) async {
  final settings = SettingsScope.maybeOf(context)?.settings;
  if (settings?.autoStartRestTimer != true) return;
  final plan = controller.state.activePlan;
  if (plan == null) return;
  for (final session in plan.sessions) {
    for (final entry in session.executionSets) {
      if (entry.set.id == setId) {
        await startSetRest(
          context,
          controller,
          session,
          entry.exercise,
          entry.set,
          entry.number,
          defaultRestSeconds: settings!.defaultRestSeconds,
        );
        return;
      }
    }
  }
}

class RestTimerPanel extends StatefulWidget {
  final TrainingController controller;
  final String sessionId;
  const RestTimerPanel({
    super.key,
    required this.controller,
    required this.sessionId,
  });
  @override
  State<RestTimerPanel> createState() => _RestTimerPanelState();
}

class _RestTimerPanelState extends State<RestTimerPanel>
    with WidgetsBindingObserver {
  Timer? _ticker;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.controller.restTimer.available != null) {
        setState(() {});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller.restTimer,
    builder: (context, _) {
      final timer = widget.controller.restTimer;
      final snapshot = timer.available;
      if (timer.loadError != null) {
        return StatePanel(
          title: '휴식 타이머 읽기 실패',
          message: timer.loadError!,
          icon: Icons.timer_off_outlined,
          action: PrimaryAction(
            label: '타이머 다시 읽기',
            busy: timer.loading,
            onPressed: timer.initialize,
          ),
        );
      }
      final visible = snapshot?.sessionId == widget.sessionId;
      if (!visible && timer.saveError == null) return const SizedBox.shrink();
      final seconds = visible
          ? snapshot!.remainingSeconds(widget.controller.now())
          : 0;
      final finished = visible && seconds == 0;
      return GlassPanel(
        padding: const EdgeInsets.all(AppSpace.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (visible) ...[
              Text(
                finished
                    ? '휴식 시간이 끝났어요'
                    : snapshot!.isPaused
                    ? '휴식 일시정지'
                    : '휴식 중',
                style: AppType.heading,
              ),
              const SizedBox(height: AppSpace.x2),
              Text(
                '${snapshot!.exerciseName} · ${snapshot.setNumber}세트',
                style: AppType.caption,
              ),
              const SizedBox(height: AppSpace.x2),
              Text(
                '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
                key: const ValueKey('rest-time'),
                style: AppType.number,
                semanticsLabel: '휴식 남은 시간 $seconds초',
              ),
              const SizedBox(height: AppSpace.x2),
              Text(
                snapshot.durationSource == RestDurationSource.userDefault
                    ? '시작 당시 사용자 기본값 · ${snapshot.durationSeconds}초'
                    : '세트 처방 · ${snapshot.durationSeconds}초',
                style: AppType.caption,
              ),
              const SizedBox(height: AppSpace.x2),
              Text(
                '다음 세트는 직접 시작해 주세요. 앱 밖 알림은 제공하지 않아요.',
                style: AppType.caption,
              ),
            ],
            if (timer.saveError != null) ...[
              const SizedBox(height: AppSpace.x2),
              Text(
                timer.saveError!,
                style: AppType.body.copyWith(color: AppColors.danger),
              ),
              PrimaryAction(
                label: '타이머 저장 재시도',
                busy: timer.saving,
                onPressed: () async {
                  final saved = await timer.retrySave();
                  if (!saved || !context.mounted) return;
                  await WidgetsBinding.instance.endOfFrame;
                  if (context.mounted) await Scrollable.ensureVisible(context);
                },
              ),
            ] else if (visible)
              Wrap(
                spacing: AppSpace.x2,
                runSpacing: AppSpace.x2,
                children: [
                  if (!finished)
                    TextButton(
                      onPressed: timer.busy
                          ? null
                          : snapshot!.isPaused
                          ? timer.resume
                          : timer.pause,
                      child: Text(
                        snapshot!.isPaused ? '휴식 재개' : '휴식 일시정지',
                        style: AppType.action,
                      ),
                    ),
                  TextButton(
                    onPressed: timer.busy ? null : timer.stop,
                    child: Text(
                      finished ? '휴식 확인' : '휴식 종료',
                      style: AppType.action,
                    ),
                  ),
                ],
              ),
            if (timer.saving) Text('타이머 저장 중', style: AppType.caption),
          ],
        ),
      );
    },
  );
}
