import 'package:flutter/material.dart';

import 'app/training_controller.dart';
import 'domain/schedule_edit.dart';
import 'domain/training_program.dart';
import 'flow_components.dart';
import 'tokens.dart';
import 'widgets.dart';

class ScheduleScreen extends StatefulWidget {
  final TrainingController controller;
  const ScheduleScreen({super.key, required this.controller});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late TrainingAppState _base;
  late int _revision;
  final _changes = <String, DateTime>{};
  TrainingAppState? _review;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _base = widget.controller.state;
    _revision = widget.controller.revision;
    _changes.clear();
    _review = null;
    _error = null;
  }

  bool get _stale => widget.controller.revision != _revision;

  Future<void> _pick(PlannedSession session) async {
    if (_busy ||
        _stale ||
        scheduleProtectionReason(
              _base,
              session,
              asOf: widget.controller.now(),
            ) !=
            null) {
      return;
    }
    final now = widget.controller.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final selected = _changes[session.id] ?? session.date;
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(selected.year, selected.month, selected.day),
      firstDate: tomorrow,
      lastDate: DateTime(9999, 12, 31),
      helpText: '새 예정일',
      cancelText: '취소',
      confirmText: '선택',
      selectableDayPredicate: (date) =>
          _base.activePlan!.weekdays.contains(date.weekday),
    );
    if (date == null || !mounted || _stale) return;
    setState(() {
      if (calendarDate(date) == session.date) {
        _changes.remove(session.id);
      } else {
        _changes[session.id] = calendarDate(date);
      }
      _review = null;
      _error = null;
    });
  }

  void _prepare() {
    try {
      if (_stale) throw const FormatException('기록이 바뀌었어요. 최신 일정을 다시 불러와 주세요.');
      final next = _base.withReviewedSchedule(
        _changes,
        asOf: widget.controller.now(),
      );
      setState(() {
        _review = next;
        _error = null;
      });
    } on FormatException catch (error) {
      setState(() {
        _review = null;
        _error = error.message;
      });
    }
  }

  Future<void> _apply() async {
    if (_busy || _review == null) return;
    // Revalidate today's boundary and protected records just before saving.
    try {
      _base.withReviewedSchedule(_changes, asOf: widget.controller.now());
    } on FormatException catch (error) {
      setState(() {
        _review = null;
        _error = error.message;
      });
      return;
    }
    setState(() => _busy = true);
    final saved = await widget.controller.commitReviewedState(
      _review!,
      expectedRevision: _revision,
    );
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = widget.controller.sessionActionError;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final plan = _base.activePlan;
      final busy = _busy || widget.controller.sessionActionPending;
      final available =
          plan?.sessions
              .where(
                (session) =>
                    scheduleProtectionReason(
                      _base,
                      session,
                      asOf: widget.controller.now(),
                    ) ==
                    null,
              )
              .toList() ??
          [];
      return PopScope(
        canPop: !busy,
        child: FlowPage(
          title: '남은 일정 편집',
          children: [
            if (plan == null)
              const StatePanel(
                title: '진행 중인 프로그램이 없어요',
                message: '프로그램을 시작하면 남은 일정을 편집할 수 있어요.',
              )
            else ...[
              Text(plan.program.title, style: AppType.heading),
              Text(
                '훈련 요일 · ${plan.weekdays.map((day) => const ['월', '화', '수', '목', '금', '토', '일'][day - 1]).join(' · ')}',
                style: AppType.body,
              ),
              Text(
                '오늘·지난 일정과 기록이 있는 운동은 유지해요. 남은 운동을 순서대로 배치해 주세요.',
                style: AppType.caption,
              ),
              if (_stale)
                StatePanel(
                  title: '기록이 바뀌었어요',
                  message: '현재 입력을 적용하기 전에 최신 일정을 다시 불러와 주세요.',
                  action: PrimaryAction(
                    label: '최신 일정 다시 불러오기',
                    onPressed: busy ? null : () => setState(_reload),
                  ),
                )
              else if (available.isEmpty)
                const StatePanel(
                  title: '이동할 수 있는 미래 운동이 없어요',
                  message: '오늘·지난 일정 또는 기록이 있는 미래 운동은 이동하지 않아요.',
                  icon: Icons.event_available,
                ),
              if (_error != null)
                Row(
                  key: const ValueKey('schedule-error'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.warn,
                      size: AppSize.icon,
                    ),
                    const SizedBox(width: AppSpace.x2),
                    Expanded(
                      child: Text(
                        _error!,
                        style: AppType.body.copyWith(color: AppColors.warn),
                      ),
                    ),
                  ],
                ),
              if (widget.controller.saveError != null)
                StatePanel(
                  title: '기록 저장을 먼저 마쳐 주세요',
                  message: widget.controller.saveError!,
                  action: PrimaryAction(
                    label: '기록 저장 다시 시도',
                    onPressed: busy
                        ? null
                        : () => widget.controller.retrySave(),
                  ),
                ),
              if (_review != null && !_stale) ...[
                Text('변경 전후 확인', style: AppType.heading),
                for (final session in plan.sessions.where(
                  (s) => _changes.containsKey(s.id),
                ))
                  GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${session.week}주차 · ${session.title}',
                          style: AppType.body,
                        ),
                        const SizedBox(height: AppSpace.x3),
                        Text('변경 전', style: AppType.caption),
                        Text(isoDate(session.date), style: AppType.number),
                        const SizedBox(height: AppSpace.x2),
                        Text('변경 후', style: AppType.caption),
                        Text(
                          isoDate(_changes[session.id]!),
                          style: AppType.number.copyWith(
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                Text('운동 구성·목표 중량·기존 기록은 그대로 남아요.', style: AppType.caption),
                PrimaryAction(
                  key: const ValueKey('schedule-apply'),
                  label: _error == null
                      ? '${_changes.length}개 일정 적용'
                      : '일정 저장 다시 시도',
                  busy: busy,
                  onPressed:
                      widget.controller.saving ||
                          widget.controller.saveError != null
                      ? null
                      : _apply,
                ),
                TextButton(
                  onPressed: busy ? null : () => setState(() => _review = null),
                  child: Text('날짜 다시 편집', style: AppType.action),
                ),
              ] else ...[
                for (final session in available)
                  GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${session.week}주차 · ${session.title}',
                          style: AppType.body,
                        ),
                        const SizedBox(height: AppSpace.x2),
                        Text(
                          isoDate(_changes[session.id] ?? session.date),
                          style: AppType.number,
                        ),
                        if (_changes.containsKey(session.id))
                          Text(
                            '변경할 날짜',
                            style: AppType.caption.copyWith(
                              color: AppColors.accent,
                            ),
                          ),
                        TextButton.icon(
                          key: ValueKey('schedule-date-${session.id}'),
                          onPressed: busy || _stale
                              ? null
                              : () => _pick(session),
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: Text('날짜 선택', style: AppType.action),
                        ),
                      ],
                    ),
                  ),
                if (available.isNotEmpty)
                  PrimaryAction(
                    key: const ValueKey('schedule-review'),
                    label: _changes.isEmpty ? '변경할 날짜를 선택해 주세요' : '변경 내용 확인',
                    onPressed: busy || _stale || _changes.isEmpty
                        ? null
                        : _prepare,
                  ),
              ],
              ExpansionTile(
                title: Text('유지되는 일정', style: AppType.body),
                children: [
                  for (final session in plan.sessions.where(
                    (s) =>
                        scheduleProtectionReason(
                          _base,
                          s,
                          asOf: widget.controller.now(),
                        ) !=
                        null,
                  ))
                    Padding(
                      padding: const EdgeInsets.all(AppSpace.x3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(session.title, style: AppType.body),
                          Text(isoDate(session.date), style: AppType.number),
                          Text(
                            scheduleProtectionReason(
                              _base,
                              session,
                              asOf: widget.controller.now(),
                            )!,
                            style: AppType.caption,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      );
    },
  );
}
