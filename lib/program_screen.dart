import 'package:flutter/material.dart';
import 'app/training_controller.dart';
import 'domain/recent_lift_record.dart';
import 'domain/training_program.dart';
import 'flow_components.dart';
import 'tokens.dart';
import 'widgets.dart';

class ProgramScreen extends StatefulWidget {
  final TrainingController controller;
  const ProgramScreen({super.key, required this.controller});
  @override
  State<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends State<ProgramScreen> {
  String _query = '';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final programs = c.programs
          .where(
            (p) => '${p.title} ${p.trainerName}'.toLowerCase().contains(
              _query.toLowerCase(),
            ),
          )
          .toList();
      return FlowPage(
        title: '프로그램 선택',
        children: [
          Text('나에게 맞는 프로그램', style: AppType.title),
          Text('운동 구성은 그대로, 중량과 일정은 나에게 맞게.', style: AppType.caption),
          if (c.catalogLoading) const LinearProgressIndicator(),
          if (c.catalogError != null)
            StatePanel(
              title: '목록을 불러오지 못했어요',
              message: c.catalogError!,
              icon: Icons.cloud_off,
              action: PrimaryAction(
                label: '다시 불러오기',
                onPressed: c.refreshPrograms,
              ),
            )
          else if (c.programs.isEmpty && !c.catalogLoading)
            StatePanel(
              title: '등록된 프로그램이 없어요',
              message: '프로그램이 등록되면 여기에서 선택할 수 있어요.',
              icon: Icons.library_books_outlined,
              action: PrimaryAction(
                label: '새로고침',
                onPressed: c.refreshPrograms,
              ),
            )
          else ...[
            TextField(
              onChanged: (value) => setState(() => _query = value),
              style: AppType.body,
              decoration: InputDecoration(
                labelText: '프로그램·트레이너 검색',
                labelStyle: AppType.caption,
                prefixIcon: const Icon(Icons.search),
              ),
            ),
            if (programs.isEmpty)
              const StatePanel(
                title: '검색 결과가 없어요',
                message: '프로그램명이나 트레이너 이름을 바꿔 검색해 주세요.',
                icon: Icons.search,
              ),
            for (final program in programs)
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(program.trainerName, style: AppType.caption),
                    const SizedBox(height: AppSpace.x2),
                    Text(program.title, style: AppType.heading),
                    const SizedBox(height: AppSpace.x3),
                    Text(
                      '${program.weeks}주 · 주 ${program.sessionsPerWeek}회',
                      style: AppType.body,
                    ),
                    const SizedBox(height: AppSpace.x4),
                    PrimaryAction(
                      label: '프로그램 보기',
                      onPressed: () async {
                        final started = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => ProgramDetailScreen(
                              controller: c,
                              program: program,
                            ),
                          ),
                        );
                        if (started == true && context.mounted) {
                          Navigator.of(context).pop(true);
                        }
                      },
                    ),
                  ],
                ),
              ),
          ],
        ],
      );
    },
  );
}

class ProgramDetailScreen extends StatelessWidget {
  final TrainingController controller;
  final TrainingProgram program;
  const ProgramDetailScreen({
    super.key,
    required this.controller,
    required this.program,
  });
  @override
  Widget build(BuildContext context) => FlowPage(
    title: '프로그램',
    children: [
      Text(program.trainerName, style: AppType.caption),
      Text(program.title, style: AppType.title),
      Text(
        '${program.weeks}주 · 주 ${program.sessionsPerWeek}회',
        style: AppType.body,
      ),
      if (program.description.isNotEmpty)
        Text(program.description, style: AppType.body),
      Text('운동 구성', style: AppType.heading),
      for (final session in program.orderedSessions)
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${session.week}주차 · ${session.dayOrder}번째 운동',
                style: AppType.caption,
              ),
              const SizedBox(height: AppSpace.x2),
              Text(session.title, style: AppType.heading),
              for (final exercise in session.exercises) ...[
                const SizedBox(height: AppSpace.x4),
                Text(exercise.name, style: AppType.body),
                const SizedBox(height: AppSpace.x1),
                Text(
                  '${exercise.sets.length}세트 · ${exercise.sets.map((s) => '${s.repetitions}회').join(' / ')}',
                  style: AppType.caption,
                ),
              ],
            ],
          ),
        ),
      PrimaryAction(
        label: '이 프로그램으로 시작',
        onPressed: () async {
          final started = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) =>
                  ProgramSetupScreen(controller: controller, program: program),
            ),
          );
          if (started == true && context.mounted) {
            Navigator.of(context).pop(true);
          }
        },
      ),
    ],
  );
}

class ProgramSetupScreen extends StatefulWidget {
  final TrainingController controller;
  final TrainingProgram program;
  const ProgramSetupScreen({
    super.key,
    required this.controller,
    required this.program,
  });
  @override
  State<ProgramSetupScreen> createState() => _ProgramSetupScreenState();
}

class _ProgramSetupScreenState extends State<ProgramSetupScreen> {
  final _form = GlobalKey<FormState>();
  final _increment = TextEditingController();
  final _days = <int>{};
  final _baselines = <MainLift, TextEditingController>{};
  final _requiredLifts = <MainLift>{};
  final _records = <MainLift, RecentLiftRecord>{};
  late DateTime _start;
  bool _busy = false;
  String? _error;
  ActiveTrainingPlan? _pendingPlan;

  @override
  void initState() {
    super.initState();
    _start = calendarDate(DateTime.now());
    for (final exercise in widget.program.sessions.expand((s) => s.exercises)) {
      if (exercise.mainLift != null) _requiredLifts.add(exercise.mainLift!);
    }
    for (final load
        in widget.program.sessions
            .expand((s) => s.exercises)
            .expand((e) => e.sets)
            .map((s) => s.load)) {
      if (load.lift != null) {
        _requiredLifts.add(load.lift!);
        _baselines.putIfAbsent(load.lift!, TextEditingController.new);
      }
    }
    for (final record in widget.controller.state.recentRecords) {
      if (record.validate(asOf: DateTime.now()).isValid) {
        _records[record.lift] = record;
      }
    }
  }

  @override
  void dispose() {
    _increment.dispose();
    for (final field in _baselines.values) {
      field.dispose();
    }
    super.dispose();
  }

  String? _positive(String? text) {
    final value = double.tryParse(text ?? '');
    return value == null || !value.isFinite || value <= 0
        ? '0보다 큰 수를 입력해 주세요.'
        : null;
  }

  Future<void> _startProgram() async {
    if (!_form.currentState!.validate()) return;
    if (_days.length != widget.program.sessionsPerWeek) {
      setState(
        () => _error = '운동요일을 ${widget.program.sessionsPerWeek}개 선택해 주세요.',
      );
      return;
    }
    if (_requiredLifts.any((lift) => !_records.containsKey(lift))) {
      setState(() => _error = '프로그램에 필요한 최근 기록을 입력해 주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _pendingPlan ??= createActivePlan(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        program: widget.program,
        startDate: _start,
        weekdays: _days.toList()..sort(),
        incrementKg: double.parse(_increment.text),
        baselines: {
          for (final entry in _baselines.entries)
            entry.key: LiftBaseline(
              lift: entry.key,
              kilograms: double.parse(entry.value.text),
              source: BaselineSource.userEntered,
            ),
        },
      );
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PlanReviewScreen(
            controller: widget.controller,
            plan: _pendingPlan!,
            records: _records.values.toList(),
          ),
        ),
      );
      if (!mounted) return;
      if (saved == true) {
        Navigator.of(context).pop(true);
      } else {
        // 저장 실패 후 돌아오면 같은 계획으로 재시도해 중복 보관을 막는다.
        if (widget.controller.state.activePlan?.id != _pendingPlan!.id) {
          setState(() => _pendingPlan = null);
        }
      }
    } on FormatException {
      if (mounted) setState(() => _error = '입력한 중량과 프로그램 설정을 확인해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FlowPage(
    title: '기록과 일정',
    children: [
      Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.program.title, style: AppType.heading),
            const SizedBox(height: AppSpace.x4),
            Text('운동·세트 구성은 그대로 유지돼요.', style: AppType.caption),
            const SizedBox(height: AppSpace.x6),
            Text('시작일', style: AppType.heading),
            const SizedBox(height: AppSpace.x2),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_month),
              onPressed: _busy || _pendingPlan != null
                  ? null
                  : () async {
                      final today = DateTime.now();
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _start,
                        firstDate: DateTime(today.year, today.month, today.day),
                        lastDate: DateTime(today.year + 2),
                      );
                      if (date != null && mounted) {
                        setState(() => _start = calendarDate(date));
                      }
                    },
              label: Text(isoDate(_start), style: mono()),
            ),
            const SizedBox(height: AppSpace.x6),
            Text(
              '운동요일 · ${widget.program.sessionsPerWeek}일 선택',
              style: AppType.heading,
            ),
            const SizedBox(height: AppSpace.x2),
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
                    selected: _days.contains(day),
                    onSelected: _busy || _pendingPlan != null
                        ? null
                        : (selected) => setState(() {
                            selected ? _days.add(day) : _days.remove(day);
                          }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.x6),
            ConsoleField(
              controller: _increment,
              label: '장비 최소 증량 단위 (kg)',
              validator: _positive,
              enabled: !_busy && _pendingPlan == null,
            ),
            for (final lift in _requiredLifts) ...[
              const SizedBox(height: AppSpace.x6),
              Text(liftLabel(lift), style: AppType.heading),
              const SizedBox(height: AppSpace.x2),
              OutlinedButton(
                onPressed: _busy || _pendingPlan != null
                    ? null
                    : () async {
                        final record =
                            await showModalBottomSheet<RecentLiftRecord>(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => RecentRecordEditor(
                                lift: lift,
                                initial: _records[lift],
                              ),
                            );
                        if (record != null && mounted) {
                          setState(() => _records[lift] = record);
                          final saved = await widget.controller.update(
                            (state) => state.copyWith(
                              recentRecords: _records.values.toList(),
                            ),
                          );
                          if (mounted) {
                            setState(
                              () => _error = saved
                                  ? null
                                  : widget.controller.saveError,
                            );
                          }
                        }
                      },
                child: Text(
                  _records[lift] == null
                      ? '최근 기록 입력'
                      : '${formatNumber(_records[lift]!.weight)} ${_records[lift]!.unit.key} · ${_records[lift]!.repetitions}회',
                  style: AppType.body,
                ),
              ),
              if (_baselines.containsKey(lift)) ...[
                const SizedBox(height: AppSpace.x3),
                ConsoleField(
                  controller: _baselines[lift]!,
                  label: '${liftLabel(lift)} 프로그램 기준 중량 (kg)',
                  validator: _positive,
                  enabled: !_busy && _pendingPlan == null,
                ),
                const SizedBox(height: AppSpace.x2),
                Text(
                  '프로그램이 사용하는 기준 중량을 입력해 주세요. 최근 기록에서 자동 추정하지 않아요.',
                  style: AppType.caption,
                ),
              ],
            ],
            const SizedBox(height: AppSpace.x6),
            if (widget.controller.state.activePlan != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.x4),
                child: Text(
                  '새 프로그램을 시작하면 현재 프로그램은 기록에 보관돼요.',
                  style: AppType.caption,
                ),
              ),
            if (_error != null) ...[
              Text(
                _error!,
                style: AppType.body.copyWith(color: AppColors.danger),
              ),
              const SizedBox(height: AppSpace.x4),
            ],
            PrimaryAction(
              label: _pendingPlan == null ? '루틴 시작하기' : '저장 다시 시도',
              busy: _busy,
              onPressed: _startProgram,
            ),
          ],
        ),
      ),
    ],
  );
}

/// 시작 전에 실제 날짜와 개인화된 목표를 확인한다. 확인 전에는 활성화하지 않는다.
class PlanReviewScreen extends StatefulWidget {
  final TrainingController controller;
  final ActiveTrainingPlan plan;
  final List<RecentLiftRecord> records;
  const PlanReviewScreen({
    super.key,
    required this.controller,
    required this.plan,
    required this.records,
  });
  @override
  State<PlanReviewScreen> createState() => _PlanReviewScreenState();
}

class _PlanReviewScreenState extends State<PlanReviewScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final saved = await widget.controller.update((state) {
      final updated = state.copyWith(recentRecords: widget.records);
      return state.activePlan?.id == widget.plan.id
          ? updated
          : updated.withActivePlan(widget.plan);
    });
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = widget.controller.saveError;
      });
    }
  }

  @override
  Widget build(BuildContext context) => FlowPage(
    title: '시작 전 확인',
    children: [
      Text(widget.plan.program.title, style: AppType.title),
      Text('날짜와 목표 중량을 확인해 주세요. 실제 수행은 운동할 때 기록해요.', style: AppType.body),
      for (final session in widget.plan.sessions)
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isoDate(session.date), style: AppType.number),
              const SizedBox(height: AppSpace.x2),
              Text(session.title, style: AppType.heading),
              for (final exercise in session.exercises) ...[
                const SizedBox(height: AppSpace.x4),
                Text(exercise.name, style: AppType.body),
                for (var i = 0; i < exercise.sets.length; i++) ...[
                  const SizedBox(height: AppSpace.x2),
                  Text(
                    '${i + 1}세트 · ${exercise.sets[i].targetKg == null ? '중량 직접 기록' : '${formatNumber(exercise.sets[i].targetKg!)} kg'} · ${exercise.sets[i].repetitions}회${exercise.sets[i].rir == null ? '' : ' · RIR ${formatNumber(exercise.sets[i].rir!)}'}${exercise.sets[i].isRequired ? '' : ' · 선택'}',
                    style: AppType.caption,
                  ),
                ],
              ],
            ],
          ),
        ),
      if (_error != null)
        Text(_error!, style: AppType.body.copyWith(color: AppColors.danger)),
      PrimaryAction(
        label: _error == null ? '이 일정으로 시작' : '저장 다시 시도',
        busy: _busy,
        onPressed: _confirm,
      ),
    ],
  );
}

class RecentRecordEditor extends StatefulWidget {
  final MainLift lift;
  final RecentLiftRecord? initial;
  const RecentRecordEditor({super.key, required this.lift, this.initial});
  @override
  State<RecentRecordEditor> createState() => _RecentRecordEditorState();
}

class _RecentRecordEditorState extends State<RecentRecordEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _weight, _reps, _rir;
  late DateTime _date;
  late WeightUnit _unit;
  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    _weight = TextEditingController(
      text: r == null ? '' : formatNumber(r.weight),
    );
    _reps = TextEditingController(text: r?.repetitions.toString() ?? '');
    _rir = TextEditingController(
      text: r?.rir == null ? '' : formatNumber(r!.rir!),
    );
    _date = r?.date ?? calendarDate(DateTime.now());
    _unit = r?.unit ?? WeightUnit.kg;
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    _rir.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.x4,
        AppSpace.x6,
        AppSpace.x4,
        MediaQuery.viewInsetsOf(context).bottom + AppSpace.x4,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${liftLabel(widget.lift)} 최근 기록', style: AppType.heading),
              const SizedBox(height: AppSpace.x4),
              SegmentedButton<WeightUnit>(
                segments: [
                  for (final unit in WeightUnit.values)
                    ButtonSegment(
                      value: unit,
                      label: Text(unit.key, style: mono()),
                    ),
                ],
                selected: {_unit},
                onSelectionChanged: (s) => setState(() => _unit = s.single),
              ),
              const SizedBox(height: AppSpace.x4),
              ConsoleField(
                controller: _weight,
                label: '실제 중량',
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  return n == null || !n.isFinite || n <= 0
                      ? '중량을 입력해 주세요.'
                      : null;
                },
              ),
              const SizedBox(height: AppSpace.x4),
              ConsoleField(
                controller: _reps,
                label: '반복 횟수',
                validator: (v) =>
                    (int.tryParse(v ?? '') ?? 0) > 0 ? null : '반복 횟수를 입력해 주세요.',
              ),
              const SizedBox(height: AppSpace.x4),
              ConsoleField(
                controller: _rir,
                label: '남은 반복 RIR (선택)',
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final n = double.tryParse(v);
                  return n == null || !n.isFinite || n < 0
                      ? '0 이상의 수를 입력해 주세요.'
                      : null;
                },
              ),
              const SizedBox(height: AppSpace.x4),
              OutlinedButton.icon(
                icon: const Icon(Icons.event),
                label: Text(isoDate(_date), style: mono()),
                onPressed: () async {
                  final value = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (value != null && mounted) {
                    setState(() => _date = calendarDate(value));
                  }
                },
              ),
              const SizedBox(height: AppSpace.x4),
              PrimaryAction(
                label: '기록 확인',
                onPressed: () {
                  if (!_form.currentState!.validate()) return;
                  final record = RecentLiftRecord(
                    lift: widget.lift,
                    weight: double.parse(_weight.text),
                    unit: _unit,
                    repetitions: int.parse(_reps.text),
                    date: _date,
                    rir: _rir.text.isEmpty ? null : double.parse(_rir.text),
                  );
                  if (record.validate(asOf: DateTime.now()).isValid) {
                    Navigator.of(context).pop(record);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
