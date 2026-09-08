import 'dart:async';

import 'package:flutter/material.dart';

import 'app/training_controller.dart';
import 'app/settings_controller.dart';
import 'domain/previous_record.dart';
import 'domain/rest_timer.dart';
import 'previous_record_dialog.dart';
import 'domain/recent_lift_record.dart';
import 'domain/training_program.dart';
import 'flow_components.dart';
import 'prescription_widgets.dart';
import 'rest_timer_panel.dart';
import 'tokens.dart';
import 'widgets.dart';

enum _SetEditorResult { saved, savedAndNext, closed }

typedef _SessionSet = ({PlannedExercise exercise, PlannedSet set, int number});

_SessionSet? _nextUnrecordedSet(
  List<_SessionSet> sets,
  String currentSetId,
  Map<String, SetActual> actuals,
) {
  final current = sets.indexWhere((entry) => entry.set.id == currentSetId);
  if (current < 0) return null;
  for (final entry in sets.skip(current + 1)) {
    if (!actuals.containsKey(entry.set.id)) return entry;
  }
  return null;
}

/// 트레이너가 정한 운동 순서와 목표를 보존하며 실제 수행만 기록한다.
class WorkoutScreen extends StatelessWidget {
  final TrainingController controller;
  final PlannedSession session;
  final bool readOnly;
  final WeightUnit defaultUnit;

  const WorkoutScreen({
    super.key,
    required this.controller,
    required this.session,
    this.readOnly = false,
    this.defaultUnit = WeightUnit.kg,
  });

  bool get _readOnly =>
      readOnly ||
      !(controller.state.activePlan?.sessions.any((s) => s.id == session.id) ??
          false);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final restPanelKey = GlobalKey();
      final sets = session.exercises
          .expand((exercise) => exercise.sets)
          .toList();
      final actuals = controller.state.setActuals;
      final completed = sets
          .where((set) => actuals[set.id]?.status == SetActualStatus.completed)
          .length;
      final skipped = sets
          .where((set) => actuals[set.id]?.status == SetActualStatus.skipped)
          .length;
      final readOnly = _readOnly;
      final closed = controller.state.isSessionClosed(session.id);
      final locked = readOnly || closed || controller.sessionActionPending;
      final summary = controller.state.sessionSummary(session.id);
      final lifecycle = controller.state.sessionEvents
          .where((e) => e.sessionId == session.id)
          .lastOrNull;
      return FlowPage(
        title: readOnly ? '운동 상세' : '운동 기록',
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('계획한 날짜', style: AppType.caption),
              Text(isoDate(session.date), style: AppType.number),
              const SizedBox(height: AppSpace.x2),
              Text(session.title, style: AppType.title),
              const SizedBox(height: AppSpace.x3),
              Text(
                '실제 수행 $completed · 제외 $skipped · 전체 ${sets.length}세트',
                style: AppType.body.copyWith(color: AppColors.inkDim),
              ),
            ],
          ),
          if (readOnly)
            Text(
              sets.any((set) => controller.state.setDrafts.containsKey(set.id))
                  ? '작성 중인 세트를 눌러 남겨 둔 초안을 확인할 수 있어요.'
                  : '계획과 기록을 확인하는 화면이에요.',
              style: AppType.caption,
            )
          else if (closed)
            Text('마감한 기록이에요. 수정하려면 먼저 기록을 다시 열어 주세요.', style: AppType.body)
          else
            Text(
              '세트를 눌러 실제 중량과 반복을 기록해 주세요.',
              style: AppType.body.copyWith(color: AppColors.inkDim),
            ),
          if (controller.state.sessionNotes[session.id]?.trim().isNotEmpty ??
              false)
            GlassPanel(
              padding: const EdgeInsets.all(AppSpace.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('세션 메모', style: AppType.caption),
                  const SizedBox(height: AppSpace.x2),
                  Text(
                    controller.state.sessionNotes[session.id]!,
                    style: AppType.body,
                  ),
                ],
              ),
            ),
          if (controller.saveError != null)
            StatePanel(
              title: '아직 저장되지 않았어요',
              message: controller.saveError!,
              icon: Icons.cloud_off_outlined,
              action: PrimaryAction(
                label: '저장 다시 시도',
                busy: controller.saving,
                onPressed: () => controller.retrySave(),
              ),
            )
          else if (!readOnly)
            Row(
              children: [
                Icon(
                  controller.saving ? Icons.sync : Icons.check_circle_outline,
                  color: controller.saving ? AppColors.muted : AppColors.good,
                  size: AppSize.icon,
                ),
                const SizedBox(width: AppSpace.x2),
                Text(
                  controller.saving ? '기기에 저장 중' : '기기에 저장됨',
                  style: AppType.caption,
                ),
              ],
            ),
          if (sets.isEmpty)
            const StatePanel(
              title: '기록할 세트가 없어요',
              message: '프로그램 구성을 확인해 주세요.',
              icon: Icons.info_outline,
            ),
          if (!readOnly)
            RestTimerPanel(
              key: restPanelKey,
              controller: controller,
              sessionId: session.id,
            ),
          for (final exercise in session.exercises)
            GlassPanel(
              padding: const EdgeInsets.all(AppSpace.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(exercise.name, style: AppType.heading),
                  SupersetNote(group: exercise.supersetGroup),
                  const SizedBox(height: AppSpace.x2),
                  Text(
                    '${exercise.sets.length}세트 · 목표는 프로그램 기준',
                    style: AppType.caption,
                  ),
                  const SizedBox(height: AppSpace.x4),
                  for (
                    var index = 0;
                    index < exercise.sets.length;
                    index++
                  ) ...[
                    if (index > 0)
                      const Divider(color: AppColors.hair, height: AppSpace.x4),
                    WorkoutSetRow(
                      number: index + 1,
                      set: exercise.sets[index],
                      targetKg: controller.state.effectiveTargetKg(
                        exercise.sets[index],
                      ),
                      actual: actuals[exercise.sets[index].id],
                      hasDraft: controller.state.setDrafts.containsKey(
                        exercise.sets[index].id,
                      ),
                      readOnly: locked,
                      onPressed: locked
                          ? (controller.state.setDrafts.containsKey(
                                  exercise.sets[index].id,
                                )
                                ? () => _openDraft(
                                    context,
                                    exercise,
                                    exercise.sets[index],
                                    index + 1,
                                  )
                                : null)
                          : () => _editSet(
                              context,
                              exercise,
                              exercise.sets[index],
                              index + 1,
                            ),
                    ),
                    if (!locked &&
                        (resolveRestSeconds(
                                  exercise.sets[index].restSeconds,
                                  SettingsScope.maybeOf(
                                    context,
                                  )?.settings.defaultRestSeconds,
                                ) ??
                                0) >
                            0 &&
                        actuals[exercise.sets[index].id]?.status ==
                            SetActualStatus.completed &&
                        !controller.state.setDrafts.containsKey(
                          exercise.sets[index].id,
                        ))
                      AnimatedBuilder(
                        animation: controller.restTimer,
                        builder: (context, _) => TextButton.icon(
                          key: ValueKey(
                            'rest-start-${exercise.sets[index].id}',
                          ),
                          onPressed:
                              controller.saving ||
                                  controller.saveError != null ||
                                  controller.restTimer.busy ||
                                  controller.restTimer.loadError != null ||
                                  controller.restTimer.saveError != null
                              ? null
                              : () async {
                                  await startSetRest(
                                    context,
                                    controller,
                                    session,
                                    exercise,
                                    exercise.sets[index],
                                    index + 1,
                                    defaultRestSeconds: SettingsScope.maybeOf(
                                      context,
                                    )?.settings.defaultRestSeconds,
                                  );
                                  if (!context.mounted) return;
                                  // The lazy list may have disposed its top panel.
                                  // Reveal the beginning first so it is mounted.
                                  Scrollable.of(context).position.jumpTo(0);
                                  await WidgetsBinding.instance.endOfFrame;
                                  final panelContext =
                                      restPanelKey.currentContext;
                                  if (panelContext != null &&
                                      panelContext.mounted) {
                                    await Scrollable.ensureVisible(
                                      panelContext,
                                    );
                                  }
                                },
                          icon: const Icon(
                            Icons.timer_outlined,
                            color: AppColors.accent,
                            size: AppSize.icon,
                          ),
                          label: Text(
                            '${index + 1}세트 휴식 시작 · ${resolveRestSeconds(exercise.sets[index].restSeconds, SettingsScope.maybeOf(context)?.settings.defaultRestSeconds)}초',
                            style: AppType.action,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          if (!closed && controller.state.isSessionComplete(session.id))
            StatePanel(
              title: '모든 필수 세트가 기록됐어요',
              message:
                  '완료 $completed세트 · 제외 $skipped세트${readOnly ? '' : '\n아직 마감 전이에요. 기록한 세트를 눌러 수정할 수 있어요.'}',
              icon: Icons.task_alt,
            ),
          GlassPanel(
            padding: const EdgeInsets.all(AppSpace.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(closed ? '기록을 마감했어요' : '기록 요약', style: AppType.heading),
                const SizedBox(height: AppSpace.x4),
                _SessionSummaryView(summary: summary),
                if (lifecycle != null) ...[
                  const SizedBox(height: AppSpace.x4),
                  Text(
                    closed ? '마감 시각 · 기기 시간' : '다시 연 시각 · 기기 시간',
                    style: AppType.caption,
                  ),
                  Text(_eventTime(lifecycle.at), style: AppType.number),
                  Text('마감 시각은 운동 종료 시각과 달라요.', style: AppType.caption),
                ] else if (controller.state.legacySessionIds.contains(
                  session.id,
                )) ...[
                  const SizedBox(height: AppSpace.x4),
                  Text('이전 기록 · 마감 여부 미확인', style: AppType.caption),
                ],
                if (!readOnly) ...[
                  const SizedBox(height: AppSpace.x4),
                  if (!closed && !summary.canClose)
                    Text(
                      '필수 미기록 ${summary.requiredUnrecordedSets}세트 · 초안 ${summary.draftSets}세트를 먼저 확인해 주세요.',
                      style: AppType.caption,
                    ),
                  if (!closed && controller.saveError != null)
                    Text('마감 전에 미저장 기록의 저장을 완료해 주세요.', style: AppType.caption),
                  PrimaryAction(
                    key: const ValueKey('session-lifecycle-action'),
                    label: closed ? '기록 다시 열기' : '기록 마감',
                    busy: controller.sessionActionPending,
                    onPressed:
                        controller.saving ||
                            controller.saveError != null ||
                            (!closed && !summary.canClose)
                        ? null
                        : () => _reviewLifecycle(context, reopen: closed),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    },
  );

  Future<void> _reviewLifecycle(
    BuildContext context, {
    required bool reopen,
  }) async {
    if (_readOnly || controller.sessionActionPending) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SessionLifecycleDialog(
        controller: controller,
        sessionId: session.id,
        reopen: reopen,
      ),
    );
  }

  Future<void> _openDraft(
    BuildContext context,
    PlannedExercise exercise,
    PlannedSet set,
    int number,
  ) async {
    final draft = controller.state.setDrafts[set.id];
    if (draft == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.bgLift,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.panel),
        ),
      ),
      builder: (_) => WorkoutDraftPreview(
        exerciseName: exercise.name,
        number: number,
        draft: draft,
      ),
    );
  }

  Future<void> _editSet(
    BuildContext context,
    PlannedExercise exercise,
    PlannedSet set,
    int number,
  ) async {
    final orderedSets = session.executionSets;
    _SessionSet current = (exercise: exercise, set: set, number: number);
    var saved = false;
    while (context.mounted) {
      if (_readOnly ||
          controller.state.isSessionClosed(session.id) ||
          controller.sessionActionPending) {
        break;
      }
      final editing = current;
      final result = await showModalBottomSheet<_SetEditorResult>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: AppColors.bgLift,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.panel),
          ),
        ),
        builder: (_) => _withSettings(
          context,
          SetEditor(
            key: ValueKey(editing.set.id),
            controller: controller,
            exerciseName: editing.exercise.name,
            set: editing.set,
            number: editing.number,
            defaultUnit: defaultUnit,
            hasNextSet:
                _nextUnrecordedSet(
                  orderedSets,
                  editing.set.id,
                  controller.state.setActuals,
                ) !=
                null,
          ),
        ),
      );
      saved =
          saved ||
          result == _SetEditorResult.saved ||
          result == _SetEditorResult.savedAndNext;
      if (!context.mounted || result != _SetEditorResult.savedAndNext) break;
      final next = _nextUnrecordedSet(
        orderedSets,
        current.set.id,
        controller.state.setActuals,
      );
      if (next == null) break;
      current = next;
    }
    if (!saved ||
        !context.mounted ||
        !controller.state.isSessionComplete(session.id) ||
        controller.state.completionNotified.contains(session.id)) {
      return;
    }
    final notificationSaved = await controller.update(
      (state) => state.withCompletionNotified(session.id),
    );
    if (!notificationSaved || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgLift,
        title: Text('운동 기록을 저장했어요', style: AppType.heading),
        content: Text(
          '필수 세트의 완료·제외 기록이 모두 남았어요. 기록 탭에서 다시 확인할 수 있어요.',
          style: AppType.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('확인', style: AppType.action),
          ),
        ],
      ),
    );
  }
}

String _eventTime(DateTime at) {
  final local = at.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${isoDate(local)} ${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

class _SessionSummaryView extends StatelessWidget {
  final SessionSummary summary;
  const _SessionSummaryView({required this.summary});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: AppSpace.x4,
        runSpacing: AppSpace.x2,
        children: [
          for (final entry in {
            '실제 수행': summary.performedSets,
            '제외': summary.skippedSets,
            '미기록': summary.unrecordedSets,
            '초안': summary.draftSets,
            '수행일 미상': summary.unknownDateSets,
          }.entries)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${entry.key} ', style: AppType.body),
                  TextSpan(text: '${entry.value}', style: AppType.number),
                  TextSpan(text: '세트', style: AppType.body),
                ],
              ),
            ),
        ],
      ),
      const SizedBox(height: AppSpace.x4),
      Text('실제 수행일', style: AppType.caption),
      if (summary.performedDates.isEmpty)
        Text(
          summary.performedSets == 0 ? '실제 수행 기록 없음' : '알려진 수행일 없음',
          style: AppType.body,
        )
      else
        Wrap(
          spacing: AppSpace.x4,
          runSpacing: AppSpace.x2,
          children: [
            for (final date in summary.performedDates)
              Text(isoDate(date), style: AppType.number),
          ],
        ),
      if (summary.unrecordedSets > 0) ...[
        const SizedBox(height: AppSpace.x2),
        Text('미기록 세트는 수행이나 제외로 바뀌지 않아요.', style: AppType.caption),
      ],
    ],
  );
}

class _SessionLifecycleDialog extends StatefulWidget {
  final TrainingController controller;
  final String sessionId;
  final bool reopen;
  const _SessionLifecycleDialog({
    required this.controller,
    required this.sessionId,
    required this.reopen,
  });

  @override
  State<_SessionLifecycleDialog> createState() =>
      _SessionLifecycleDialogState();
}

class _SessionLifecycleDialogState extends State<_SessionLifecycleDialog> {
  static int _sequence = 0;
  String? _eventId, _error;
  DateTime? _at;
  bool _busy = false;

  Future<void> _confirm() async {
    if (_busy || widget.controller.sessionActionPending) return;
    _at ??= widget.controller.now().toUtc();
    _eventId ??=
        '${widget.sessionId}:${widget.reopen ? 'reopen' : 'close'}:${_at!.microsecondsSinceEpoch}:${_sequence++}';
    setState(() {
      _busy = true;
      _error = null;
    });
    final saved = widget.reopen
        ? await widget.controller.reopenSession(
            widget.sessionId,
            eventId: _eventId!,
            at: _at,
          )
        : await widget.controller.closeSession(
            widget.sessionId,
            eventId: _eventId!,
            at: _at,
          );
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _busy = false;
      _error =
          widget.controller.sessionActionError ??
          '저장하지 못했어요. 같은 버튼으로 다시 시도해 주세요.';
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      key: const ValueKey('session-lifecycle-dialog'),
      scrollable: true,
      backgroundColor: AppColors.bgLift,
      surfaceTintColor: AppColors.bgLift,
      title: Text(
        widget.reopen ? '기록을 다시 열까요?' : '기록을 마감할까요?',
        style: AppType.heading,
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SessionSummaryView(
            summary: widget.controller.state.sessionSummary(widget.sessionId),
          ),
          const SizedBox(height: AppSpace.x4),
          Text(
            widget.reopen
                ? '다시 열기 저장이 끝나면 세트를 수정할 수 있어요. 기존 기록과 마감 이력은 남아요.'
                : '마감 시각은 운동 종료 시각과 달라요. 마감 후 수정하려면 기록을 다시 열어 주세요.',
            style: AppType.caption,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.x4),
            Text(
              _error!,
              key: const ValueKey('session-lifecycle-error'),
              style: AppType.body.copyWith(color: AppColors.warn),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text('취소', style: AppType.action),
        ),
        TextButton(
          key: const ValueKey('session-lifecycle-confirm'),
          onPressed: _busy ? null : _confirm,
          child: Text(
            _busy
                ? '저장 중…'
                : widget.reopen
                ? '다시 열기'
                : '마감하기',
            style: AppType.action,
          ),
        ),
      ],
    ),
  );
}

/// 목표와 실제 수행, 완료·제외·초안을 같은 위치에서 비교하는 세트 행.
class WorkoutSetRow extends StatelessWidget {
  final int number;
  final PlannedSet set;
  final SetActual? actual;
  final bool hasDraft;
  final bool readOnly;
  final VoidCallback? onPressed;
  final double? targetKg;

  const WorkoutSetRow({
    super.key,
    required this.number,
    required this.set,
    required this.actual,
    required this.hasDraft,
    this.readOnly = false,
    this.onPressed,
    this.targetKg,
  });

  @override
  Widget build(BuildContext context) {
    final done = actual?.status == SetActualStatus.completed;
    final skipped = actual?.status == SetActualStatus.skipped;
    final label = hasDraft
        ? (readOnly ? '초안 보기' : (actual == null ? '입력 중' : '수정 중'))
        : done
        ? '완료'
        : skipped
        ? '제외'
        : '기록 전';
    final color = done
        ? AppColors.good
        : skipped || (readOnly && onPressed == null)
        ? AppColors.muted
        : AppColors.accent;
    return Semantics(
      button: onPressed != null,
      label: '$number세트, $label',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.ctrl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.touch),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.x2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: AppSize.touch,
                  child: Column(
                    children: [
                      Text('$number', style: AppType.number),
                      if (!set.isRequired) Text('선택', style: AppType.caption),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TargetLine(set: set, targetKg: targetKg),
                      const SizedBox(height: AppSpace.x2),
                      if (done)
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text:
                                    '${formatNumber(actual!.weight!)} ${actual!.unit!.key} × ${actual!.repetitions}',
                                style: AppType.number,
                              ),
                              TextSpan(text: '회', style: AppType.body),
                            ],
                          ),
                        )
                      else
                        Text(
                          skipped
                              ? '이번 세트 제외'
                              : hasDraft
                              ? '작성하던 기록이 있어요'
                              : onPressed == null
                              ? '아직 기록 없음'
                              : '실제 기록 입력',
                          style: AppType.body.copyWith(
                            color: skipped ? AppColors.muted : AppColors.ink,
                          ),
                        ),
                      if (actual?.rir != null) ...[
                        const SizedBox(height: AppSpace.x1),
                        Text(
                          'RIR ${formatNumber(actual!.rir!)}',
                          style: mono(),
                        ),
                      ],
                      if (done) ...[
                        const SizedBox(height: AppSpace.x2),
                        Text(
                          actual!.performedDate == null ? '수행일 미상' : '실제 수행일',
                          style: AppType.caption,
                        ),
                        if (actual!.performedDate != null)
                          Text(
                            isoDate(actual!.performedDate!),
                            style: mono(color: AppColors.muted),
                          ),
                      ],
                      if (actual?.note.isNotEmpty ?? false) ...[
                        const SizedBox(height: AppSpace.x2),
                        Text(actual!.note, style: AppType.caption),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.x2),
                Column(
                  children: [
                    Icon(
                      readOnly && hasDraft
                          ? Icons.visibility_outlined
                          : done
                          ? Icons.check_circle
                          : skipped
                          ? Icons.remove_circle_outline
                          : onPressed == null
                          ? Icons.radio_button_unchecked
                          : Icons.edit_outlined,
                      color: color,
                      size: AppSize.icon,
                    ),
                    const SizedBox(height: AppSpace.x1),
                    Text(label, style: AppType.caption.copyWith(color: color)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 실제 기록으로 반영하지 않은 입력 원문을 변경 없이 확인한다.
class WorkoutDraftPreview extends StatelessWidget {
  final String exerciseName;
  final int number;
  final Map<String, String> draft;

  const WorkoutDraftPreview({
    super.key,
    required this.exerciseName,
    required this.number,
    required this.draft,
  });

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.x6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$exerciseName · $number세트', style: AppType.heading),
          const SizedBox(height: AppSpace.x2),
          Text('작성 중인 초안 · 읽기 전용', style: AppType.body),
          const SizedBox(height: AppSpace.x2),
          Text('이 초안은 완료 기록에 반영되지 않았어요.', style: AppType.caption),
          const SizedBox(height: AppSpace.x6),
          for (final entry in const {
            'weight': '중량',
            'unit': '단위',
            'repetitions': '반복',
            'rir': 'RIR',
            'note': '메모',
            'performedDate': '실제 수행일',
          }.entries) ...[
            Text(
              entry.value,
              style: entry.key == 'rir'
                  ? mono(color: AppColors.muted)
                  : AppType.caption,
            ),
            const SizedBox(height: AppSpace.x2),
            Text(
              draft[entry.key]?.isNotEmpty == true
                  ? draft[entry.key]!
                  : entry.key == 'performedDate'
                  ? '수행일 미상'
                  : '입력 없음',
              key: ValueKey('draft-preview-${entry.key}'),
              style:
                  entry.key != 'note' &&
                      (double.tryParse(draft[entry.key] ?? '') != null ||
                          const ['kg', 'lb'].contains(draft[entry.key]))
                  ? AppType.number
                  : AppType.body,
            ),
            const SizedBox(height: AppSpace.x4),
          ],
          PrimaryAction(label: '닫기', onPressed: () => Navigator.pop(context)),
        ],
      ),
    ),
  );
}

class _TargetLine extends StatelessWidget {
  final PlannedSet set;
  final double? targetKg;
  final bool explain;
  const _TargetLine({required this.set, this.targetKg, this.explain = false});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: targetKg != null && targetKg != set.targetKg
                  ? '조정 목표  '
                  : '목표  ',
              style: AppType.caption,
            ),
            if ((targetKg ?? set.targetKg) == null)
              TextSpan(text: '중량 직접 입력 · ', style: AppType.caption)
            else
              TextSpan(
                text:
                    '${formatNumber((targetKg ?? set.targetKg)!)} kg${set.isAmrap ? ' · ' : ' × '}',
                style: mono(color: AppColors.muted),
              ),
            ...repetitionSpans(set.template),
            if (set.rir != null)
              TextSpan(
                text: ' · RIR ${formatNumber(set.rir!)}',
                style: mono(color: AppColors.muted),
              ),
          ],
        ),
      ),
      SetPrescriptionNotes(set: set.template, explain: explain),
    ],
  );
}

/// 입력 초안을 보존하고 저장 성공 후에만 닫히는 세트 편집 시트.
class SetEditor extends StatefulWidget {
  final TrainingController controller;
  final String exerciseName;
  final PlannedSet set;
  final int number;
  final bool hasNextSet;
  final WeightUnit defaultUnit;
  const SetEditor({
    super.key,
    required this.controller,
    required this.exerciseName,
    required this.set,
    required this.number,
    this.hasNextSet = false,
    this.defaultUnit = WeightUnit.kg,
  });

  @override
  State<SetEditor> createState() => _SetEditorState();
}

class _SetEditorState extends State<SetEditor> {
  final _form = GlobalKey<FormState>();
  final _dateField = GlobalKey<FormFieldState<String>>();
  late final TextEditingController _weight, _repetitions, _rir, _note;
  late WeightUnit _unit;
  late String _performedDate;
  late final bool _allowUnknownDate;
  String? _entryError;
  bool _committing = false, _hasChanges = false, _finished = false;
  _SetEditorResult? _resultAfterRetry;
  bool _autoRestPending = false;

  @override
  void initState() {
    super.initState();
    final draft = widget.controller.state.setDrafts[widget.set.id];
    final actual = widget.controller.state.setActuals[widget.set.id];
    _allowUnknownDate =
        actual?.status == SetActualStatus.completed &&
        actual?.performedDate == null;
    _performedDate =
        draft?['performedDate'] ??
        (actual?.status == SetActualStatus.completed
            ? actual?.performedDate == null
                  ? ''
                  : isoDate(actual!.performedDate!)
            : isoDate(widget.controller.now()));
    _unit = switch (draft?['unit']) {
      'kg' => WeightUnit.kg,
      'lb' => WeightUnit.lb,
      _ => actual?.unit ?? widget.defaultUnit,
    };
    _weight = TextEditingController(
      text:
          draft?['weight'] ??
          (actual?.weight == null ? '' : formatNumber(actual!.weight!)),
    );
    _repetitions = TextEditingController(
      text: draft?['repetitions'] ?? (actual?.repetitions?.toString() ?? ''),
    );
    _rir = TextEditingController(
      text:
          draft?['rir'] ??
          (actual?.rir == null ? '' : formatNumber(actual!.rir!)),
    );
    _note = TextEditingController(text: draft?['note'] ?? actual?.note ?? '');
  }

  @override
  void dispose() {
    for (final field in [_weight, _repetitions, _rir, _note]) {
      field.dispose();
    }
    super.dispose();
  }

  Map<String, String> get _draft => {
    'weight': _weight.text,
    'repetitions': _repetitions.text,
    'rir': _rir.text,
    'note': _note.text,
    'unit': _unit.key,
    'performedDate': _performedDate,
  };

  bool get _editable {
    if (widget.controller.sessionActionPending) return false;
    final sessions =
        widget.controller.state.activePlan?.sessions ??
        const <PlannedSession>[];
    final session = sessions
        .where(
          (s) => s.exercises.any(
            (e) => e.sets.any((set) => set.id == widget.set.id),
          ),
        )
        .firstOrNull;
    return session != null &&
        !widget.controller.state.isSessionClosed(session.id);
  }

  String? _dateError(String? value) {
    if (value == null || value.isEmpty) {
      return _allowUnknownDate ? null : '실제 수행일을 지정해 주세요.';
    }
    try {
      final date = parseCalendarDate(value);
      return date.isAfter(calendarDate(widget.controller.now()))
          ? '오늘 이후 날짜는 선택할 수 없어요.'
          : null;
    } on FormatException {
      return '실제 수행일 형식을 확인해 주세요.';
    }
  }

  Future<void> _pickDate() async {
    if (_committing || !_editable) return;
    FocusScope.of(context).unfocus();
    final today = DateUtils.dateOnly(widget.controller.now());
    DateTime initial = today;
    if (_dateError(_performedDate) == null && _performedDate.isNotEmpty) {
      final date = parseCalendarDate(_performedDate);
      initial = DateTime(date.year, date.month, date.day);
    }
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1),
      lastDate: today,
      currentDate: today,
      helpText: '실제 수행일',
      cancelText: '취소',
      confirmText: '선택',
    );
    if (date == null || !mounted || !_editable) return;
    setState(() {
      _performedDate = isoDate(date);
      _entryError = null;
    });
    _dateField.currentState?.didChange(_performedDate);
    _changed('');
  }

  void _changed(String _) {
    if (!_editable) return;
    _hasChanges = true;
    _resultAfterRetry = null;
    final draft = _draft;
    unawaited(
      widget.controller.update(
        (state) => state.withSetDraft(widget.set.id, draft),
      ),
    );
  }

  Future<void> _copyPrevious() async {
    if (_committing || !_editable) return;
    FocusScope.of(context).unfocus();
    DateTime? before;
    try {
      before = parseCalendarDate(_performedDate);
    } on FormatException {
      /* Unknown dates are not ordered. */
    }
    final revision = widget.controller.revision;
    final records = previousSetRecords(
      widget.controller.state,
      targetSetId: widget.set.id,
      performedBefore: before,
      asOf: widget.controller.now(),
    );
    final selected = await choosePreviousRecord(context, records);
    if (selected == null || !mounted || !_editable) return;
    if (_weight.text.isNotEmpty || _repetitions.text.isNotEmpty) {
      if (!await confirmPreviousOverwrite(context) || !mounted || !_editable) {
        return;
      }
    }
    final current = previousSetRecords(
      widget.controller.state,
      targetSetId: widget.set.id,
      performedBefore: before,
      asOf: widget.controller.now(),
    );
    if (widget.controller.revision != revision ||
        !current.any((record) => record.fingerprint == selected.fingerprint)) {
      setState(() => _entryError = '이전 기록이 바뀌었어요. 다시 선택해 주세요.');
      return;
    }
    final copied = selected.copyInto(_draft);
    setState(() {
      _weight.text = copied['weight']!;
      _repetitions.text = copied['repetitions']!;
      _unit = selected.actual.unit!;
      _entryError = null;
    });
    _changed('');
  }

  Future<void> _finishSaved() async {
    if (_autoRestPending) {
      _autoRestPending = false;
      await autoStartCompletedSetRest(
        context,
        widget.controller,
        widget.set.id,
      );
    }
    if (!mounted) return;
    setState(() => _committing = false);
    _finish(_resultAfterRetry!);
  }

  Future<void> _complete({bool advance = false}) async {
    if (_committing || _finished || !_editable) return;
    if (!_form.currentState!.validate()) return;
    final rir = _rir.text.trim();
    final at = widget.controller.now().toUtc();
    final previous = widget.controller.state.setActuals[widget.set.id];
    await _commit(
      SetActual.completed(
        weight: double.parse(_weight.text.trim()),
        unit: _unit,
        repetitions: int.parse(_repetitions.text.trim()),
        rir: rir.isEmpty ? null : double.parse(rir),
        note: _note.text.trim(),
        performedDate: _performedDate.isEmpty
            ? null
            : parseCalendarDate(_performedDate),
        recordedAt: previous?.status == SetActualStatus.completed
            ? previous?.recordedAt
            : at,
        updatedAt: at,
      ),
      advance: advance,
    );
  }

  Future<void> _commit(SetActual? actual, {bool advance = false}) async {
    if (_committing || _finished || !_editable) return;
    setState(() {
      _committing = true;
      _resultAfterRetry = advance
          ? _SetEditorResult.savedAndNext
          : _SetEditorResult.saved;
    });
    _autoRestPending =
        actual?.status == SetActualStatus.completed &&
        widget.controller.state.setActuals[widget.set.id]?.status !=
            SetActualStatus.completed &&
        (SettingsScope.maybeOf(context)?.settings.autoStartRestTimer ?? false);
    final draft = _draft;
    final saved = await widget.controller.update((state) {
      final updated = state.withSetActual(widget.set.id, actual);
      return actual == null
          ? updated.withSetDraft(widget.set.id, draft)
          : updated;
    });
    if (!mounted) return;
    if (saved && widget.controller.saveError == null) {
      await _finishSaved();
    } else {
      setState(() => _committing = false);
    }
  }

  Future<void> _retry() async {
    if (_committing || _finished) return;
    setState(() => _committing = true);
    final saved = await widget.controller.retrySave();
    if (!mounted) return;
    if (saved &&
        widget.controller.saveError == null &&
        _resultAfterRetry != null) {
      await _finishSaved();
    } else {
      setState(() => _committing = false);
    }
  }

  void _finish(_SetEditorResult result) {
    if (_finished) return;
    _finished = true;
    Navigator.pop(context, result);
  }

  Future<void> _close() async {
    if (_committing || _finished) return;
    FocusScope.of(context).unfocus();
    if (!_editable) {
      _finish(_SetEditorResult.closed);
      return;
    }
    if (!_hasChanges && widget.controller.saveError == null) {
      _finish(_SetEditorResult.closed);
      return;
    }
    setState(() {
      _committing = true;
      _resultAfterRetry = _SetEditorResult.closed;
    });
    final draft = _draft;
    final saved = await widget.controller.update(
      (state) => _hasChanges ? state.withSetDraft(widget.set.id, draft) : state,
    );
    if (!mounted) return;
    setState(() => _committing = false);
    if (saved) _finish(_SetEditorResult.closed);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final actual = widget.controller.state.setActuals[widget.set.id];
      final blocked = _committing || !_editable;
      return PopScope(
        canPop: !_committing && widget.controller.saveError == null,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpace.x6),
              child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${widget.exerciseName} · ${widget.number}세트',
                            style: AppType.heading,
                          ),
                        ),
                        IconButton(
                          tooltip: '기록 초안 저장하고 닫기',
                          constraints: const BoxConstraints(
                            minWidth: AppSize.touch,
                            minHeight: AppSize.touch,
                          ),
                          onPressed: _committing ? null : _close,
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.ink,
                            size: AppSize.icon,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.x2),
                    _TargetLine(
                      set: widget.set,
                      explain: true,
                      targetKg: widget.controller.state.effectiveTargetKg(
                        widget.set,
                      ),
                    ),
                    const SizedBox(height: AppSpace.x6),
                    AbsorbPointer(
                      absorbing: blocked,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FormField<String>(
                            key: _dateField,
                            initialValue: _performedDate,
                            validator: _dateError,
                            autovalidateMode: AutovalidateMode.always,
                            builder: (field) => Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('실제 수행일', style: AppType.caption),
                                const SizedBox(height: AppSpace.x2),
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: AppSpace.x3,
                                  children: [
                                    Text(
                                      _performedDate.isEmpty
                                          ? '수행일 미상'
                                          : _performedDate,
                                      key: const ValueKey(
                                        'set-performed-date-value',
                                      ),
                                      style: _performedDate.isEmpty
                                          ? AppType.body
                                          : AppType.number,
                                    ),
                                    TextButton(
                                      key: const ValueKey(
                                        'set-performed-date-picker',
                                      ),
                                      onPressed: blocked ? null : _pickDate,
                                      child: Text(
                                        _performedDate.isEmpty
                                            ? '날짜 지정'
                                            : '날짜 변경',
                                        style: AppType.action,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_allowUnknownDate && _performedDate.isEmpty)
                                  Text(
                                    '이전 기록에 날짜가 없어요. 지정하기 전까지 미상으로 남겨요.',
                                    style: AppType.caption,
                                  ),
                                if (field.errorText != null)
                                  Text(
                                    field.errorText!,
                                    style: AppType.caption.copyWith(
                                      color: AppColors.warn,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpace.x3),
                          OutlinedButton.icon(
                            key: const ValueKey('previous-record-open'),
                            onPressed:
                                blocked ||
                                    widget.controller.saving ||
                                    widget.controller.saveError != null
                                ? null
                                : _copyPrevious,
                            icon: const Icon(Icons.history),
                            label: Text('이전 기록 가져오기', style: AppType.action),
                          ),
                          const SizedBox(height: AppSpace.x4),
                          SegmentedButton<WeightUnit>(
                            key: const ValueKey('set-weight-unit'),
                            segments: [
                              for (final unit in WeightUnit.values)
                                ButtonSegment(
                                  value: unit,
                                  label: Text(unit.key, style: AppType.number),
                                ),
                            ],
                            selected: {_unit},
                            style: ButtonStyle(
                              minimumSize: const WidgetStatePropertyAll(
                                Size(AppSize.touch, AppSize.touch),
                              ),
                              side: const WidgetStatePropertyAll(
                                BorderSide(color: AppColors.hairStrong),
                              ),
                              backgroundColor: WidgetStateProperty.resolveWith(
                                (states) =>
                                    states.contains(WidgetState.selected)
                                    ? AppColors.accentSoft
                                    : AppColors.fill,
                              ),
                              foregroundColor: const WidgetStatePropertyAll(
                                AppColors.ink,
                              ),
                            ),
                            onSelectionChanged: blocked
                                ? null
                                : (selection) {
                                    setState(() => _unit = selection.single);
                                    _changed('');
                                  },
                          ),
                          const SizedBox(height: AppSpace.x2),
                          Text('단위를 바꿔도 입력한 숫자는 유지돼요.', style: AppType.caption),
                          const SizedBox(height: AppSpace.x4),
                          ConsoleField(
                            key: const ValueKey('set-weight'),
                            controller: _weight,
                            label: '실제 중량 (${_unit.key})',
                            validator: _weightError,
                            onChanged: _changed,
                          ),
                          const SizedBox(height: AppSpace.x4),
                          ConsoleField(
                            key: const ValueKey('set-repetitions'),
                            controller: _repetitions,
                            label: '실제 반복 (회)',
                            validator: _repetitionsError,
                            onChanged: _changed,
                          ),
                          const SizedBox(height: AppSpace.x4),
                          ConsoleField(
                            key: const ValueKey('set-rir'),
                            controller: _rir,
                            label: 'RIR · 선택',
                            hint: '더 할 수 있었던 반복 수',
                            validator: _rirError,
                            onChanged: _changed,
                          ),
                          const SizedBox(height: AppSpace.x4),
                          ConsoleField(
                            key: const ValueKey('set-note'),
                            controller: _note,
                            label: '메모 · 선택',
                            numeric: false,
                            maxLines: 2,
                            onChanged: _changed,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.x4),
                    if (!_editable)
                      Text(
                        '지금은 기록을 수정할 수 없어요. 목록에서 마감 상태를 확인해 주세요.',
                        style: AppType.caption,
                      ),
                    if (_entryError != null)
                      Text(
                        _entryError!,
                        style: AppType.body.copyWith(color: AppColors.warn),
                      ),
                    if (widget.controller.saveError != null) ...[
                      Text(
                        widget.controller.saveError!,
                        style: AppType.body.copyWith(color: AppColors.warn),
                      ),
                      const SizedBox(height: AppSpace.x2),
                      OutlinedButton(
                        onPressed: _committing ? null : _retry,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(
                            double.infinity,
                            AppSize.touch,
                          ),
                        ),
                        child: Text('저장 다시 시도', style: AppType.action),
                      ),
                      const SizedBox(height: AppSpace.x4),
                    ] else
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.x4),
                        child: Text(
                          widget.controller.saving
                              ? '입력 저장 중…'
                              : '입력은 기기에 자동 저장돼요.',
                          style: AppType.caption,
                        ),
                      ),
                    PrimaryAction(
                      label: actual?.status == SetActualStatus.completed
                          ? '수정한 기록 저장'
                          : '세트 완료',
                      busy: _committing,
                      onPressed: blocked ? null : () => _complete(),
                    ),
                    if (widget.hasNextSet) ...[
                      const SizedBox(height: AppSpace.x2),
                      OutlinedButton(
                        onPressed: blocked
                            ? null
                            : () => _complete(advance: true),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(
                            double.infinity,
                            AppSize.touch,
                          ),
                          foregroundColor: AppColors.ink,
                          side: const BorderSide(color: AppColors.hairStrong),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.ctrl),
                          ),
                        ),
                        child: Text('저장하고 다음 세트', style: AppType.action),
                      ),
                    ],
                    const SizedBox(height: AppSpace.x2),
                    TextButton(
                      onPressed: blocked
                          ? null
                          : () => _commit(
                              SetActual.skipped(note: _note.text.trim()),
                            ),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(double.infinity, AppSize.touch),
                      ),
                      child: Text(
                        '이번 세트 제외',
                        style: AppType.action.copyWith(color: AppColors.inkDim),
                      ),
                    ),
                    if (actual != null)
                      TextButton(
                        onPressed: blocked ? null : () => _commit(null),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(
                            double.infinity,
                            AppSize.touch,
                          ),
                        ),
                        child: Text(
                          '기록 전으로 되돌리기',
                          style: AppType.action.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  String? _weightError(String? value) {
    final number = double.tryParse(value?.trim() ?? '');
    return number == null || !number.isFinite || number < 0
        ? '0 이상의 중량을 입력해 주세요.'
        : null;
  }

  String? _repetitionsError(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    return number == null || number <= 0 ? '1 이상의 정수로 입력해 주세요.' : null;
  }

  String? _rirError(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final number = double.tryParse(value.trim());
    return number == null || !number.isFinite || number < 0
        ? '0 이상의 숫자를 입력하거나 비워 주세요.'
        : null;
  }
}

Widget _withSettings(BuildContext source, Widget child) {
  final settings = SettingsScope.maybeOf(source);
  return settings == null
      ? child
      : SettingsScope(controller: settings, child: child);
}
