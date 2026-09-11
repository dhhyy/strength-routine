import 'package:flutter/material.dart';

import 'app/training_controller.dart';
import 'app/working_max_controller.dart';
import 'domain/recent_lift_record.dart';
import 'domain/recovery_block.dart';
import 'domain/routine_match.dart';
import 'domain/training_program.dart';
import 'flow_components.dart';
import 'tokens.dart';
import 'widgets.dart';

/// Phase 2 MVP: 목표·일수·요일 → 템플릿 매칭 → createActivePlan.
class RoutineGeneratorScreen extends StatefulWidget {
  final TrainingController controller;
  final WorkingMaxController? workingMax;
  final DateTime Function()? now;
  const RoutineGeneratorScreen({
    super.key,
    required this.controller,
    this.workingMax,
    this.now,
  });

  @override
  State<RoutineGeneratorScreen> createState() => _RoutineGeneratorScreenState();
}

class _RoutineGeneratorScreenState extends State<RoutineGeneratorScreen> {
  var _step = 0;
  RoutineGoal? _goal;
  int? _daysPerWeek;
  final _weekdays = <int>{};
  final _baselineFields = <MainLift, TextEditingController>{};
  late DateTime _start;
  final _increment = TextEditingController(text: '2.5');
  /// 악세 필수 세트 상한: 0=유지, 1~2=끝에서부터 비필수.
  var _recoveryDrop = 0;
  var _block = BlockPreset.full;
  bool _busy = false;
  String? _error;
  TrainingProgram? _matched;

  DateTime get _today => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _start = calendarDate(_today);
  }

  @override
  void dispose() {
    _increment.dispose();
    for (final c in _baselineFields.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _selectGoal(RoutineGoal goal) {
    setState(() {
      _goal = goal;
      _daysPerWeek = null;
      _weekdays.clear();
      _matched = null;
      _error = null;
      _step = 1;
    });
  }

  void _selectDays(int days) {
    final program = matchProgram(
      goal: _goal!,
      daysPerWeek: days,
      programs: widget.controller.programs,
    );
    setState(() {
      _daysPerWeek = days;
      _weekdays.clear();
      _matched = program;
      _error = program == null
          ? '이 조합의 코치 템플릿이 아직 없어요. 다른 일수나 목표를 골라 주세요.'
          : null;
      if (program != null) {
        _prepareBaselines(program);
        _step = 2;
      }
    });
  }

  void _prepareBaselines(TrainingProgram program) {
    for (final c in _baselineFields.values) {
      c.dispose();
    }
    _baselineFields.clear();
    final working = widget.workingMax?.state;
    for (final lift in requiredBaselineLifts(program)) {
      final field = TextEditingController();
      final adopted = working?[lift]?.kilograms;
      if (adopted != null) field.text = formatNumber(adopted);
      _baselineFields[lift] = field;
    }
  }

  String? _positive(String? text) {
    final value = double.tryParse(text ?? '');
    return value == null || !value.isFinite || value <= 0
        ? '0보다 큰 수를 입력해 주세요.'
        : null;
  }

  TrainingProgram _materialize(TrainingProgram program) {
    var next = program;
    final weeks = _block.weekLimit;
    if (weeks != null) next = takeFirstWeeks(next, weeks);
    if (_recoveryDrop > 0) {
      next = applyAccessorySetCap(next, dropCount: _recoveryDrop);
    }
    return next;
  }

  Future<void> _startPlan() async {
    final program = _matched;
    if (program == null || _daysPerWeek == null) return;
    if (_weekdays.length != _daysPerWeek) {
      setState(() => _error = '운동요일을 $_daysPerWeek개 선택해 주세요.');
      return;
    }
    final increment = double.tryParse(_increment.text);
    if (increment == null || increment <= 0) {
      setState(() => _error = '증량 단위를 확인해 주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final kilograms = <MainLift, double>{
        for (final e in _baselineFields.entries)
          e.key: double.parse(e.value.text),
      };
      final baselines = baselinesForGenerator(
        lifts: _baselineFields.keys.toSet(),
        kilograms: kilograms,
      );
      final plan = createActivePlan(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        program: _materialize(program),
        startDate: _start,
        weekdays: _weekdays.toList()..sort(),
        incrementKg: increment,
        baselines: baselines,
      );
      final saved = await widget.controller.update(
        (state) => state.withActivePlan(plan),
      );
      if (!mounted) return;
      if (saved) {
        Navigator.of(context).pop(true);
      } else {
        setState(
          () => _error =
              widget.controller.saveError ?? '루틴을 저장하지 못했어요. 다시 시도해 주세요.',
        );
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '입력한 기준 중량을 확인해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!generatorFeatureFlag) {
      return const FlowPage(
        title: '루틴 만들기',
        children: [
          StatePanel(
            title: '지금은 프로그램 선택으로 시작해요',
            message: '생성 마법사가 꺼져 있어요. 프로그램 선택에서 코치 루틴을 고를 수 있어요.',
          ),
        ],
      );
    }
    return FlowPage(
      title: '루틴 만들기',
      children: [
        Text(
          _step == 0
              ? '목표를 골라 주세요'
              : _step == 1
              ? '일주일에 며칠 할까요?'
              : '일정과 기준 중량',
          style: AppType.heading,
        ),
        Text(
          '코치가 준비한 템플릿만 매칭해요. 없는 조합은 만들지 않아요.',
          style: AppType.caption,
        ),
        if (_error != null)
          StatePanel(
            title: '확인해 주세요',
            message: _error!,
            icon: Icons.info_outline,
          ),
        if (_busy) const LinearProgressIndicator(),
        if (_step == 0) ...[
          for (final goal in RoutineGoal.values)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.x4),
              child: GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.label, style: AppType.heading),
                    const SizedBox(height: AppSpace.x2),
                    Text(
                      availableDaysForGoal(goal).isEmpty
                          ? '준비된 템플릿이 없어요.'
                          : '주 ${(availableDaysForGoal(goal).toList()..sort()).join('/')}일 템플릿',
                      style: AppType.caption,
                    ),
                    const SizedBox(height: AppSpace.x4),
                    PrimaryAction(
                      label: '${goal.label}로 계속',
                      onPressed: _busy ? null : () => _selectGoal(goal),
                    ),
                  ],
                ),
              ),
            ),
        ] else if (_step == 1) ...[
          Text(_goal!.label, style: AppType.caption),
          Wrap(
            spacing: AppSpace.x2,
            runSpacing: AppSpace.x2,
            children: [
              for (final days
                  in (availableDaysForGoal(_goal!).toList()..sort()))
                FilterChip(
                  label: Text('주 $days일', style: AppType.body),
                  selected: _daysPerWeek == days,
                  onSelected: _busy ? null : (_) => _selectDays(days),
                ),
            ],
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                    _step = 0;
                    _error = null;
                  }),
            child: Text('목표 다시 고르기', style: AppType.action),
          ),
        ] else ...[
          if (_matched != null) ...[
            Text(_matched!.title, style: AppType.heading),
            Text(
              '${_matched!.trainerName} · ${_matched!.weeks}주 · 주 $_daysPerWeek일',
              style: AppType.caption,
            ),
            const SizedBox(height: AppSpace.x4),
            Text('블록', style: AppType.body),
            Wrap(
              spacing: AppSpace.x2,
              runSpacing: AppSpace.x2,
              children: [
                for (final preset in BlockPreset.values)
                  FilterChip(
                    label: Text(preset.label, style: AppType.body),
                    selected: _block == preset,
                    onSelected: _busy
                        ? null
                        : (_) => setState(() => _block = preset),
                  ),
              ],
            ),
            Text(
              _block.weekLimit == null
                  ? '템플릿 전체 주차를 씁니다.'
                  : '앞 ${_block.weekLimit}주만 잘라 시작합니다.',
              style: AppType.caption,
            ),
            const SizedBox(height: AppSpace.x4),
            Text('회복 · 악세 상한', style: AppType.body),
            Wrap(
              spacing: AppSpace.x2,
              runSpacing: AppSpace.x2,
              children: [
                for (final drop in [0, 1, 2])
                  FilterChip(
                    label: Text(
                      drop == 0 ? '그대로' : '악세 −$drop세트',
                      style: AppType.body,
                    ),
                    selected: _recoveryDrop == drop,
                    onSelected: _busy
                        ? null
                        : (_) => setState(() => _recoveryDrop = drop),
                  ),
              ],
            ),
            Text(
              '메인 리프트는 유지하고, 그 외 종목의 필수 작업 세트만 줄여요. 진단이 아닙니다.',
              style: AppType.caption,
            ),
            const SizedBox(height: AppSpace.x4),
            Text('시작일', style: AppType.body),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_month),
              onPressed: _busy
                  ? null
                  : () async {
                      final today = calendarDate(_today);
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _start.isBefore(today) ? today : _start,
                        firstDate: today,
                        lastDate: DateTime(today.year + 2),
                      );
                      if (date != null && mounted) {
                        setState(() => _start = calendarDate(date));
                      }
                    },
              label: Text(isoDate(_start), style: mono()),
            ),
            const SizedBox(height: AppSpace.x4),
            Text('운동요일 · $_daysPerWeek일', style: AppType.body),
            Wrap(
              spacing: AppSpace.x2,
              runSpacing: AppSpace.x2,
              children: [
                for (var day = 1; day <= 7; day++)
                  FilterChip(
                    label: Text(
                      const ['월', '화', '수', '목', '금', '토', '일'][day - 1],
                      style: AppType.body,
                    ),
                    selected: _weekdays.contains(day),
                    onSelected: _busy
                        ? null
                        : (selected) => setState(() {
                            selected
                                ? _weekdays.add(day)
                                : _weekdays.remove(day);
                          }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.x4),
            ConsoleField(
              controller: _increment,
              label: '장비 최소 증량 단위 (kg)',
              validator: _positive,
              enabled: !_busy,
            ),
            for (final lift in _baselineFields.keys) ...[
              const SizedBox(height: AppSpace.x4),
              ConsoleField(
                controller: _baselineFields[lift]!,
                label: '${liftLabel(lift)} 기준 중량 (kg)',
                validator: _positive,
                enabled: !_busy,
              ),
              Text(
                widget.workingMax?.state[lift] != null
                    ? '채택한 working max를 넣었어요. 필요하면 수정하세요.'
                    : '이 템플릿의 % 처방에 쓰는 기준 중량이에요.',
                style: AppType.caption,
              ),
            ],
            if (widget.controller.state.activePlan != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.x4),
                child: Text(
                  '새 루틴을 시작하면 현재 프로그램은 기록에 보관돼요.',
                  style: AppType.caption,
                ),
              ),
            const SizedBox(height: AppSpace.x6),
            PrimaryAction(
              label: '이 루틴으로 시작',
              busy: _busy,
              onPressed: _busy ? null : _startPlan,
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _step = 1;
                      _error = null;
                    }),
              child: Text('일수 다시 고르기', style: AppType.action),
            ),
          ],
        ],
      ],
    );
  }
}
