import 'dart:async';

import 'package:flutter/material.dart';

import 'app/training_controller.dart';
import 'domain/recent_lift_record.dart';
import 'domain/training_program.dart';
import 'flow_components.dart';
import 'tokens.dart';
import 'widgets.dart';

/// 트레이너가 정한 운동 순서와 목표를 보존하며 실제 수행만 기록한다.
class WorkoutScreen extends StatelessWidget {
  final TrainingController controller;
  final PlannedSession session;
  final bool readOnly;

  const WorkoutScreen({
    super.key,
    required this.controller,
    required this.session,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
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
      return FlowPage(
        title: readOnly ? '운동 상세' : '운동 기록',
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isoDate(session.date), style: AppType.number),
              const SizedBox(height: AppSpace.x2),
              Text(session.title, style: AppType.title),
              const SizedBox(height: AppSpace.x3),
              Text(
                '완료 $completed · 제외 $skipped · 전체 ${sets.length}세트',
                style: AppType.body.copyWith(color: AppColors.inkDim),
              ),
            ],
          ),
          if (readOnly)
            Text('계획과 기록을 확인하는 화면이에요.', style: AppType.caption)
          else
            Text(
              '세트를 눌러 실제 중량과 반복을 기록해 주세요.',
              style: AppType.body.copyWith(color: AppColors.inkDim),
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
          for (final exercise in session.exercises)
            GlassPanel(
              padding: const EdgeInsets.all(AppSpace.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(exercise.name, style: AppType.heading),
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
                      actual: actuals[exercise.sets[index].id],
                      hasDraft: controller.state.setDrafts.containsKey(
                        exercise.sets[index].id,
                      ),
                      onPressed: readOnly
                          ? null
                          : () => _editSet(
                              context,
                              exercise,
                              exercise.sets[index],
                              index + 1,
                            ),
                    ),
                  ],
                ],
              ),
            ),
          if (controller.state.isSessionComplete(session.id))
            StatePanel(
              title: '모든 필수 세트가 기록됐어요',
              message:
                  '완료 $completed세트 · 제외 $skipped세트${readOnly ? '' : '\n기록한 세트를 눌러 수정할 수 있어요.'}',
              icon: Icons.task_alt,
            ),
        ],
      );
    },
  );

  Future<void> _editSet(
    BuildContext context,
    PlannedExercise exercise,
    PlannedSet set,
    int number,
  ) async {
    final saved = await showModalBottomSheet<bool>(
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
      builder: (_) => SetEditor(
        controller: controller,
        exerciseName: exercise.name,
        set: set,
        number: number,
      ),
    );
    if (saved != true ||
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

/// 목표와 실제 수행, 완료·제외·초안을 같은 위치에서 비교하는 세트 행.
class WorkoutSetRow extends StatelessWidget {
  final int number;
  final PlannedSet set;
  final SetActual? actual;
  final bool hasDraft;
  final VoidCallback? onPressed;

  const WorkoutSetRow({
    super.key,
    required this.number,
    required this.set,
    required this.actual,
    required this.hasDraft,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final done = actual?.status == SetActualStatus.completed;
    final skipped = actual?.status == SetActualStatus.skipped;
    final label = hasDraft
        ? (actual == null ? '입력 중' : '수정 중')
        : done
        ? '완료'
        : skipped
        ? '제외'
        : '기록 전';
    final color = done
        ? AppColors.good
        : skipped
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
                      _TargetLine(set: set),
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
                      done
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

class _TargetLine extends StatelessWidget {
  final PlannedSet set;
  const _TargetLine({required this.set});

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: '목표  ', style: AppType.caption),
        if (set.targetKg == null)
          TextSpan(text: '중량 직접 입력 · ', style: AppType.caption)
        else
          TextSpan(
            text: '${formatNumber(set.targetKg!)} kg × ',
            style: mono(color: AppColors.muted),
          ),
        TextSpan(
          text: '${set.repetitions}',
          style: mono(color: AppColors.muted),
        ),
        TextSpan(text: '회', style: AppType.caption),
        if (set.rir != null)
          TextSpan(
            text: ' · RIR ${formatNumber(set.rir!)}',
            style: mono(color: AppColors.muted),
          ),
      ],
    ),
  );
}

/// 입력 초안을 보존하고 저장 성공 후에만 닫히는 세트 편집 시트.
class SetEditor extends StatefulWidget {
  final TrainingController controller;
  final String exerciseName;
  final PlannedSet set;
  final int number;
  const SetEditor({
    super.key,
    required this.controller,
    required this.exerciseName,
    required this.set,
    required this.number,
  });

  @override
  State<SetEditor> createState() => _SetEditorState();
}

class _SetEditorState extends State<SetEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _weight, _repetitions, _rir, _note;
  late WeightUnit _unit;
  bool _committing = false, _closeAfterRetry = false, _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final draft = widget.controller.state.setDrafts[widget.set.id];
    final actual = widget.controller.state.setActuals[widget.set.id];
    _hasChanges = draft != null;
    _unit = switch (draft?['unit']) {
      'kg' => WeightUnit.kg,
      'lb' => WeightUnit.lb,
      _ => actual?.unit ?? WeightUnit.kg,
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
  };

  void _changed(String _) {
    _hasChanges = true;
    _closeAfterRetry = false;
    final draft = _draft;
    unawaited(
      widget.controller.update(
        (state) => state.withSetDraft(widget.set.id, draft),
      ),
    );
  }

  Future<void> _complete() async {
    if (!_form.currentState!.validate()) return;
    final rir = _rir.text.trim();
    await _commit(
      SetActual.completed(
        weight: double.parse(_weight.text.trim()),
        unit: _unit,
        repetitions: int.parse(_repetitions.text.trim()),
        rir: rir.isEmpty ? null : double.parse(rir),
        note: _note.text.trim(),
      ),
    );
  }

  Future<void> _commit(SetActual? actual) async {
    setState(() {
      _committing = true;
      _closeAfterRetry = true;
    });
    final draft = _draft;
    final saved = await widget.controller.update((state) {
      final updated = state.withSetActual(widget.set.id, actual);
      return actual == null
          ? updated.withSetDraft(widget.set.id, draft)
          : updated;
    });
    if (!mounted) return;
    setState(() => _committing = false);
    if (saved && widget.controller.saveError == null) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _retry() async {
    setState(() => _committing = true);
    final saved = await widget.controller.retrySave();
    if (!mounted) return;
    setState(() => _committing = false);
    if (saved && _closeAfterRetry) Navigator.pop(context, true);
  }

  Future<void> _close() async {
    FocusScope.of(context).unfocus();
    if (!_hasChanges && widget.controller.saveError == null) {
      Navigator.pop(context, false);
      return;
    }
    setState(() => _committing = true);
    final draft = _draft;
    final saved = await widget.controller.update(
      (state) => state.withSetDraft(widget.set.id, draft),
    );
    if (!mounted) return;
    setState(() => _committing = false);
    if (saved) Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final actual = widget.controller.state.setActuals[widget.set.id];
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
                    _TargetLine(set: widget.set),
                    const SizedBox(height: AppSpace.x6),
                    AbsorbPointer(
                      absorbing: _committing,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                            onSelectionChanged: _committing
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
                      onPressed: _complete,
                    ),
                    const SizedBox(height: AppSpace.x2),
                    TextButton(
                      onPressed: _committing
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
                        onPressed: _committing ? null : () => _commit(null),
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
