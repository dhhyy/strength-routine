import 'dart:convert';

import 'package:flutter/material.dart';

import '../domain/recent_lift_record.dart';
import '../domain/training_program.dart';
import '../flow_components.dart';
import '../tokens.dart';
import '../widgets.dart';
import 'detailed_routine.dart';

/// Only raw administrator drafts are autosaved. A catalog replacement requires
/// a separate review and a successful durable-save callback.
class DetailedRoutineScreen extends StatefulWidget {
  final DetailedRoutineDraft initialDraft;
  final List<TrainingProgram> catalog;
  final Future<bool> Function(DetailedRoutineDraft) onDraftChanged;
  final Future<bool> Function(TrainingProgram, DetailedRoutineDraft)
  onSaveProgram;

  const DetailedRoutineScreen({
    super.key,
    required this.initialDraft,
    required this.catalog,
    required this.onDraftChanged,
    required this.onSaveProgram,
  });

  @override
  State<DetailedRoutineScreen> createState() => _DetailedRoutineScreenState();
}

class _DetailedRoutineScreenState extends State<DetailedRoutineScreen> {
  late DetailedRoutineDraft _draft;
  late List<TrainingProgram> _catalog;
  final _undo = <DetailedRoutineDraft>[], _redo = <DetailedRoutineDraft>[];
  final _expandedSetOptions = <String>{};
  Future<void> _saveQueue = Future.value();
  int _week = 0, _session = 0, _formEpoch = 0, _revision = 0;
  bool _saving = false;
  String? _lastGroup, _saveError, _message;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialDraft.copy();
    _catalog = List.of(widget.catalog);
  }

  void _saveDraft() {
    final snapshot = _draft.copy();
    final revision = ++_revision;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    _saveQueue = _saveQueue.then((_) async {
      bool saved;
      try {
        saved = await widget.onDraftChanged(snapshot);
      } catch (_) {
        saved = false;
      }
      if (!mounted || revision != _revision) return;
      setState(() {
        _saving = false;
        _saveError = saved ? null : '입력을 유지했습니다. 저장 재시도 후 계속해 주세요.';
      });
    });
  }

  void _change(VoidCallback change, {String? group}) {
    final before = _draft.copy();
    change();
    if (jsonEncode(before.toJson()) == jsonEncode(_draft.toJson())) return;
    setState(() {
      if (group == null || group != _lastGroup) {
        _undo.add(before);
        if (_undo.length > 50) _undo.removeAt(0);
      }
      _lastGroup = group;
      _redo.clear();
      _message = null;
      if (group == null) _formEpoch++;
      _clampSelection();
    });
    _saveDraft();
  }

  void _clampSelection() {
    if (_draft.weeks.isEmpty) {
      _week = 0;
      _session = 0;
      return;
    }
    _week = _week.clamp(0, _draft.weeks.length - 1);
    final sessions = _draft.weeks[_week].sessions;
    _session = sessions.isEmpty ? 0 : _session.clamp(0, sessions.length - 1);
  }

  void _history(bool undo) {
    final source = undo ? _undo : _redo, target = undo ? _redo : _undo;
    if (source.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      target.add(_draft.copy());
      _draft = source.removeLast();
      _lastGroup = null;
      _formEpoch++;
      _message = null;
      _clampSelection();
    });
    _saveDraft();
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title, style: AppType.heading),
          content: SingleChildScrollView(
            child: Text(message, style: AppType.body),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('취소', style: AppType.action),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action, style: AppType.action),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _copyOnto() async {
    var target = _week == 0 ? 1 : 0;
    final source = _week;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('다른 주차에 덮어쓰기', style: AppType.heading),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${source + 1}주차의 전체 구성으로 ${target + 1}주차를 교체합니다. 세션 수 ${_draft.weeks[target].sessions.length} → ${_draft.weeks[source].sessions.length}개. 기존 대상 세션 ID를 순서대로 유지하고 부족한 세션에는 새 ID를 만듭니다.',
                  style: AppType.body,
                ),
                const SizedBox(height: AppSpace.x4),
                DropdownButtonFormField<int>(
                  key: const ValueKey('copy-week-target'),
                  value: target,
                  isExpanded: true,
                  decoration: _decoration('대상 주차'),
                  items: [
                    for (var i = 0; i < _draft.weeks.length; i++)
                      if (i != source)
                        DropdownMenuItem(
                          value: i,
                          child: Text('${i + 1}주차', style: AppType.body),
                        ),
                  ],
                  onChanged: (value) => setDialogState(() => target = value!),
                ),
                const SizedBox(height: AppSpace.x3),
                Text('현재 편집 중에는 되돌리기로 복구할 수 있습니다.', style: AppType.caption),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('취소', style: AppType.action),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('덮어쓰기', style: AppType.action),
            ),
          ],
        ),
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      _change(() => _draft.copyWeekOnto(source, target));
    } on FormatException catch (error) {
      setState(() => _message = error.message);
    }
  }

  Future<void> _preview() async {
    if (_saving || _saveError != null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _lastGroup = null;
    try {
      final snapshot = _draft.copy();
      final candidate = generateDetailedRoutine(snapshot);
      final previous = _catalog.where((p) => p.id == candidate.id).firstOrNull;
      if (previous != null && previous.version == candidate.version) {
        throw const FormatException(
          '기존 프로그램을 교체하려면 버전을 바꿔 주세요. 같은 ID·버전은 저장할 수 없습니다.',
        );
      }
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => _DetailedReview(
            program: candidate,
            previous: previous,
            onSave: () => widget.onSaveProgram(candidate, snapshot.copy()),
          ),
        ),
      );
      if (!mounted || saved != true) return;
      setState(() {
        _catalog = [..._catalog.where((p) => p.id != candidate.id), candidate];
        _message = '검토한 버전을 관리자 카탈로그에 저장했습니다. 사용자 앱 반영은 내보내기 후 진행해 주세요.';
      });
    } on FormatException catch (error) {
      setState(() => _message = error.message);
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: AppType.caption,
    filled: true,
    fillColor: AppColors.fill,
    contentPadding: const EdgeInsets.all(AppSpace.x4),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.ctrl),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.ctrl),
      borderSide: const BorderSide(color: AppColors.hairStrong),
    ),
  );

  Widget _field(
    String path,
    String label,
    String value,
    ValueChanged<String> update, {
    bool numeric = false,
    bool latin = false,
    int lines = 1,
  }) => TextFormField(
    key: ValueKey('detail-$_formEpoch-$path'),
    initialValue: value,
    maxLines: lines,
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    style: numeric || latin ? AppType.number : AppType.body,
    decoration: _decoration(label),
    onChanged: (text) => _change(() => update(text), group: path),
  );

  Widget _liftField(
    String key,
    String label,
    MainLift? value,
    ValueChanged<MainLift?> update,
  ) => DropdownButtonFormField<String>(
    key: ValueKey('detail-$_formEpoch-$key'),
    value: value?.key ?? '',
    isExpanded: true,
    decoration: _decoration(label),
    items: [
      DropdownMenuItem(
        value: '',
        child: Text('미지정', style: AppType.body),
      ),
      for (final lift in MainLift.values)
        DropdownMenuItem(
          value: lift.key,
          child: Text(liftLabel(lift), style: AppType.body),
        ),
    ],
    onChanged: (key) => _change(
      () => update(
        key == ''
            ? null
            : MainLift.values.firstWhere((lift) => lift.key == key),
      ),
    ),
  );

  String _nextId(String prefix, Iterable<String> used) {
    var i = 1;
    final ids = used.toSet();
    while (ids.contains('$prefix-$i')) {
      i++;
    }
    return '$prefix-$i';
  }

  Widget _orderActions(
    String kind,
    int index,
    int length,
    void Function(int) move,
    VoidCallback remove,
  ) => Wrap(
    spacing: AppSpace.x1,
    children: [
      IconButton(
        tooltip: '$kind 위로 이동',
        onPressed: index > 0 ? () => move(index - 1) : null,
        icon: const Icon(Icons.arrow_upward),
      ),
      IconButton(
        tooltip: '$kind 아래로 이동',
        onPressed: index + 1 < length ? () => move(index + 1) : null,
        icon: const Icon(Icons.arrow_downward),
      ),
      IconButton(
        tooltip: '$kind 삭제',
        onPressed: length > 1 ? remove : null,
        icon: const Icon(Icons.delete_outline),
      ),
    ],
  );

  void _move<T>(List<T> values, int from, int to) =>
      _change(() => values.insert(to, values.removeAt(from)));

  Widget _setFields(List<Widget> fields) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth >= AppSize.touch * 16 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.25
          ? 3
          : 1;
      final width =
          (constraints.maxWidth - AppSpace.x3 * (columns - 1)) / columns;
      return Wrap(
        spacing: AppSpace.x3,
        runSpacing: AppSpace.x3,
        children: [
          for (final field in fields) SizedBox(width: width, child: field),
        ],
      );
    },
  );

  Widget _setEditor(
    DetailedExerciseDraft exercise,
    int exerciseIndex,
    int index,
  ) {
    final value = exercise.sets[index];
    final path = 'w$_week-s$_session-e$exerciseIndex-t$index';
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.x4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.hairStrong),
          borderRadius: BorderRadius.circular(AppRadius.ctrl),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.x3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('${index + 1}세트', style: AppType.heading),
                  _orderActions(
                    '세트 ${index + 1}',
                    index,
                    exercise.sets.length,
                    (to) => _move(exercise.sets, index, to),
                    () async {
                      if (await _confirm(
                            '세트 삭제',
                            '${index + 1}세트의 처방을 삭제합니다. 다른 세트는 유지합니다.',
                            '삭제',
                          ) &&
                          mounted) {
                        _change(() => exercise.sets.removeAt(index));
                      }
                    },
                  ),
                ],
              ),
              _setFields([
                _field(
                  '$path-id',
                  '세트 ID',
                  value.id,
                  (text) => value.id = text,
                  latin: true,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        '$path-reps',
                        value.isAmrap ? '기준 반복 수' : '반복 수',
                        value.repetitions,
                        (text) => value.repetitions = text,
                        numeric: true,
                      ),
                    ),
                    const SizedBox(width: AppSpace.x3),
                    Expanded(
                      child: _field(
                        '$path-rir',
                        'RIR · 선택',
                        value.rir,
                        (text) => value.rir = text,
                        numeric: true,
                      ),
                    ),
                  ],
                ),
                DropdownButtonFormField<LoadKind>(
                  key: ValueKey('detail-$_formEpoch-$path-load-kind'),
                  value: value.loadKind,
                  isExpanded: true,
                  decoration: _decoration('중량 방식'),
                  items: [
                    for (final kind in LoadKind.values)
                      DropdownMenuItem(
                        value: kind,
                        child: Text(switch (kind) {
                          LoadKind.manual => '사용자가 직접 입력',
                          LoadKind.fixedKg => '고정 중량 · kg',
                          LoadKind.percentOfBaseline => '기준 작업중량 비율 · %',
                        }, style: AppType.body),
                      ),
                  ],
                  onChanged: (kind) => _change(() => value.loadKind = kind!),
                ),
                if (value.loadKind != LoadKind.manual) ...[
                  _field(
                    '$path-load',
                    value.loadKind == LoadKind.fixedKg
                        ? '고정 중량 · kg'
                        : '기준 작업중량 대비 · %',
                    value.loadValue,
                    (text) => value.loadValue = text,
                    numeric: true,
                  ),
                ],
                if (value.loadKind == LoadKind.percentOfBaseline) ...[
                  _liftField(
                    '$path-load-lift',
                    '중량 기준 리프트',
                    value.loadLift,
                    (lift) => value.loadLift = lift,
                  ),
                ],
                SwitchListTile.adaptive(
                  key: ValueKey('$path-required'),
                  value: value.isRequired,
                  activeColor: AppColors.ctaInk,
                  activeTrackColor: AppColors.accent,
                  inactiveThumbColor: AppColors.muted,
                  inactiveTrackColor: AppColors.fill,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    value.isRequired ? '필수 세트' : '선택 세트',
                    style: AppType.body,
                  ),
                  subtitle: Text(
                    '선택 세트는 기록 없이 운동을 마감할 수 있습니다.',
                    style: AppType.caption,
                  ),
                  onChanged: (required) =>
                      _change(() => value.isRequired = required),
                ),
              ]),
              ExpansionTile(
                key: ValueKey('detail-$_formEpoch-$path-advanced'),
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: _expandedSetOptions.contains(path),
                onExpansionChanged: (expanded) => expanded
                    ? _expandedSetOptions.add(path)
                    : _expandedSetOptions.remove(path),
                childrenPadding: const EdgeInsets.only(
                  top: AppSpace.x3,
                  bottom: AppSpace.x2,
                ),
                title: Text('고급 세트 설정', style: AppType.body),
                subtitle: Text(
                  [
                    value.restSeconds.isEmpty
                        ? '휴식 미지정'
                        : '휴식 ${value.restSeconds}초',
                    if (value.tempo.isNotEmpty) '템포 ${value.tempo}',
                    if (value.isAmrap) 'AMRAP',
                  ].join(' · '),
                  style: AppType.caption,
                ),
                children: [
                  _setFields([
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _field(
                          '$path-rest',
                          '휴식 시간 · 초',
                          value.restSeconds,
                          (text) => value.restSeconds = text,
                          numeric: true,
                        ),
                        const SizedBox(height: AppSpace.x2),
                        Text(
                          '비우면 미지정, 0은 쉬지 않음입니다. 최대 3600초.',
                          style: AppType.caption,
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _field(
                          '$path-tempo',
                          '템포 · 예: 3-1-X-0',
                          value.tempo,
                          (text) => value.tempo = text,
                          latin: true,
                        ),
                        const SizedBox(height: AppSpace.x2),
                        Text(
                          '내림–하단 정지–올림–상단 정지 순서, 각 0~9초이며 X는 빠른 올림입니다.',
                          style: AppType.caption,
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SwitchListTile.adaptive(
                          key: ValueKey('$path-amrap'),
                          value: value.isAmrap,
                          activeColor: AppColors.ctaInk,
                          activeTrackColor: AppColors.accent,
                          inactiveThumbColor: AppColors.muted,
                          inactiveTrackColor: AppColors.fill,
                          contentPadding: EdgeInsets.zero,
                          title: Text('AMRAP 세트', style: AppType.body),
                          onChanged: (enabled) =>
                              _change(() => value.isAmrap = enabled),
                        ),
                        Text(
                          value.isAmrap
                              ? '기준 반복 수는 비교용이며 최소 달성 조건이 아닙니다. RIR 처방은 따로 유지합니다.'
                              : '수행 가능한 반복 수를 기록하는 세트입니다.',
                          style: AppType.caption,
                        ),
                      ],
                    ),
                  ]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exerciseEditor(DetailedSessionDraft session, int index) {
    final exercise = session.exercises[index];
    final path = 'w$_week-s$_session-e$index';
    return GlassPanel(
      child: ExpansionTile(
        key: ValueKey('exercise-$_formEpoch-$_week-$_session-$index'),
        tilePadding: EdgeInsets.zero,
        initiallyExpanded: index == 0,
        title: Text(
          exercise.name.isEmpty ? '운동 ${index + 1}' : exercise.name,
          style: AppType.heading,
        ),
        subtitle: Text(
          '${index + 1}번째 운동 · ${exercise.sets.length}세트${exercise.supersetGroup.isEmpty ? '' : ' · 슈퍼세트 ${exercise.supersetGroup}'}',
          style: AppType.caption,
        ),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _orderActions(
                '운동 ${index + 1}',
                index,
                session.exercises.length,
                (to) => _move(session.exercises, index, to),
                () async {
                  if (await _confirm(
                        '운동 삭제',
                        '이 운동과 ${exercise.sets.length}개 세트를 현재 세션에서 삭제합니다.',
                        '삭제',
                      ) &&
                      mounted) {
                    _change(() => session.exercises.removeAt(index));
                  }
                },
              ),
              _field(
                '$path-id',
                '운동 ID · 같은 종목은 같은 ID',
                exercise.id,
                (text) => exercise.id = text,
                latin: true,
              ),
              const SizedBox(height: AppSpace.x3),
              _field(
                '$path-name',
                '운동 이름',
                exercise.name,
                (text) => exercise.name = text,
              ),
              const SizedBox(height: AppSpace.x3),
              _liftField(
                '$path-main-lift',
                '기록 종목 · 메인 리프트',
                exercise.mainLift,
                (lift) => exercise.mainLift = lift,
              ),
              const SizedBox(height: AppSpace.x2),
              Text(
                '같은 운동 ID의 이름과 기록 종목은 모든 주차에서 같아야 합니다. 중량 기준은 세트마다 지정합니다.',
                style: AppType.caption,
              ),
              ExpansionTile(
                key: ValueKey('$path-superset-options'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: AppSpace.x3),
                title: Text('운동 묶기 · 슈퍼세트', style: AppType.body),
                subtitle: Text(
                  exercise.supersetGroup.isEmpty
                      ? '묶음 없음'
                      : '슈퍼세트 ${exercise.supersetGroup}',
                  style: AppType.caption,
                ),
                children: [
                  _field(
                    '$path-superset',
                    '슈퍼세트 그룹 ID · 선택',
                    exercise.supersetGroup,
                    (text) => exercise.supersetGroup = text,
                  ),
                  const SizedBox(height: AppSpace.x2),
                  Text(
                    '같은 세션에서 연속한 운동 2개 이상에 같은 그룹 ID를 입력하면 한 세트씩 번갈아 진행합니다. 비우면 묶음을 해제합니다.',
                    style: AppType.caption,
                  ),
                ],
              ),
              for (var i = 0; i < exercise.sets.length; i++)
                _setEditor(exercise, index, i),
              TextButton.icon(
                onPressed: exercise.sets.length >= 10
                    ? null
                    : () => _change(
                        () => exercise.sets.add(
                          DetailedSetDraft(
                            id: _nextId('set', exercise.sets.map((s) => s.id)),
                          ),
                        ),
                      ),
                icon: const Icon(Icons.add),
                label: Text('세트 추가', style: AppType.action),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metadata() => GlassPanel(
    child: ExpansionTile(
      key: const ValueKey('detail-metadata'),
      tilePadding: EdgeInsets.zero,
      title: Text('프로그램 정보', style: AppType.heading),
      subtitle: Text(
        '${_draft.title.isEmpty ? '이름 미입력' : _draft.title} · v${_draft.version}',
        style: AppType.caption,
      ),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(
              'id',
              '프로그램 ID',
              _draft.id,
              (text) => _draft.id = text,
              latin: true,
            ),
            const SizedBox(height: AppSpace.x3),
            _field(
              'title',
              '프로그램 이름',
              _draft.title,
              (text) => _draft.title = text,
            ),
            const SizedBox(height: AppSpace.x3),
            _field(
              'version',
              '버전 · 기존 프로그램 교체 시 변경',
              _draft.version,
              (text) => _draft.version = text,
              latin: true,
            ),
            const SizedBox(height: AppSpace.x3),
            _field(
              'trainer',
              '운영자 이름',
              _draft.trainerName,
              (text) => _draft.trainerName = text,
            ),
            const SizedBox(height: AppSpace.x3),
            _field(
              'description',
              '대상·장비·중량 선택 안내',
              _draft.description,
              (text) => _draft.description = text,
              lines: 3,
            ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_draft.weeks.isEmpty || _draft.weeks[_week].sessions.isEmpty) {
      final missingWeek = _draft.weeks.isEmpty;
      return PopScope(
        canPop: !_saving && _saveError == null,
        child: FlowPage(
          title: '주차·세트 정밀 편집',
          children: [
            StatePanel(
              title: missingWeek ? '주차가 비어 있어요' : '세션이 비어 있어요',
              message: '불러온 초안을 유지했습니다. 구성을 추가해 계속 작성해 주세요.',
              action: PrimaryAction(
                label: missingWeek ? '첫 주차 추가' : '세션 추가',
                onPressed: () => _change(() {
                  final session = DetailedSessionDraft(
                    id: _draft.nextSessionId(),
                    exercises: [
                      DetailedExerciseDraft(
                        sets: [DetailedSetDraft(id: 'set-1')],
                      ),
                    ],
                  );
                  if (missingWeek) {
                    _draft.weeks.add(DetailedWeekDraft(sessions: [session]));
                  } else {
                    _draft.weeks[_week].sessions.add(session);
                  }
                }),
              ),
            ),
            if (_saveError != null)
              PrimaryAction(label: '저장 재시도', onPressed: _saveDraft),
          ],
        ),
      );
    }
    final week = _draft.weeks[_week];
    final session = week.sessions[_session];
    final children = <Widget>[
      Row(
        children: [
          Expanded(
            child: Text('${_draft.weeks.length}주 구성', style: AppType.heading),
          ),
          IconButton(
            tooltip: '되돌리기',
            onPressed: _undo.isEmpty ? null : () => _history(true),
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: '다시 실행',
            onPressed: _redo.isEmpty ? null : () => _history(false),
            icon: const Icon(Icons.redo),
          ),
        ],
      ),
      Text(
        _saving
            ? '초안 저장 중…'
            : _saveError == null
            ? '초안 저장됨 · 카탈로그 반영은 변경 검토 후 저장'
            : '초안 저장 실패 · 입력 유지 중',
        style: AppType.caption.copyWith(
          color: _saveError == null ? AppColors.muted : AppColors.warn,
        ),
      ),
      if (_saveError != null)
        StatePanel(
          title: '초안 저장 실패',
          message: _saveError!,
          icon: Icons.error_outline,
          action: PrimaryAction(
            label: '저장 재시도',
            onPressed: _saving ? null : _saveDraft,
          ),
        ),
      _metadata(),
      Text('편집할 주차', style: AppType.heading),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < _draft.weeks.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: AppSpace.x2),
                child: ChoiceChip(
                  key: ValueKey('detail-week-$i'),
                  label: Text(
                    '${i + 1}주차',
                    style: AppType.action.copyWith(
                      color: i == _week ? AppColors.ctaInk : AppColors.ink,
                    ),
                  ),
                  selectedColor: AppColors.accent,
                  backgroundColor: AppColors.bg,
                  checkmarkColor: AppColors.ctaInk,
                  side: const BorderSide(color: AppColors.hairStrong),
                  selected: i == _week,
                  onSelected: (_) => setState(() {
                    _week = i;
                    _session = 0;
                    _lastGroup = null;
                    _formEpoch++;
                  }),
                ),
              ),
          ],
        ),
      ),
      Wrap(
        spacing: AppSpace.x2,
        runSpacing: AppSpace.x1,
        children: [
          TextButton.icon(
            onPressed: _draft.weeks.length >= 52
                ? null
                : () => _change(() {
                    _draft.appendWeekCopy(_week);
                    _week = _draft.weeks.length - 1;
                  }),
            icon: const Icon(Icons.copy),
            label: Text('이 주차를 복사해 추가', style: AppType.action),
          ),
          TextButton(
            onPressed: _draft.weeks.length > 1 ? _copyOnto : null,
            child: Text('다른 주차에 덮어쓰기', style: AppType.action),
          ),
          TextButton(
            onPressed: _draft.weeks.length > 1
                ? () async {
                    if (await _confirm(
                          '주차 삭제',
                          '${_week + 1}주차의 전체 세션을 삭제하고 뒤 주차 번호를 앞당깁니다.',
                          '삭제',
                        ) &&
                        mounted) {
                      _change(() => _draft.weeks.removeAt(_week));
                    }
                  }
                : null,
            child: Text('주차 삭제', style: AppType.action),
          ),
        ],
      ),
      Text('${_week + 1}주차 · 세션 선택', style: AppType.heading),
      Wrap(
        spacing: AppSpace.x2,
        runSpacing: AppSpace.x2,
        children: [
          for (var i = 0; i < week.sessions.length; i++)
            ChoiceChip(
              key: ValueKey('detail-session-$i'),
              label: Text(
                '${i + 1}회차',
                style: AppType.action.copyWith(
                  color: i == _session ? AppColors.ctaInk : AppColors.ink,
                ),
              ),
              selectedColor: AppColors.accent,
              backgroundColor: AppColors.bg,
              checkmarkColor: AppColors.ctaInk,
              side: const BorderSide(color: AppColors.hairStrong),
              selected: i == _session,
              onSelected: (_) => setState(() {
                _session = i;
                _lastGroup = null;
                _formEpoch++;
              }),
            ),
        ],
      ),
      GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${_week + 1}주차 · ${_session + 1}회차', style: AppType.heading),
            const SizedBox(height: AppSpace.x2),
            _field(
              'w$_week-s$_session-id',
              '세션 ID · 전체 주차에서 고유',
              session.id,
              (text) => session.id = text,
              latin: true,
            ),
            const SizedBox(height: AppSpace.x3),
            _field(
              'w$_week-s$_session-title',
              '세션 이름',
              session.title,
              (text) => session.title = text,
            ),
            _orderActions(
              '세션',
              _session,
              week.sessions.length,
              (to) {
                _move(week.sessions, _session, to);
                setState(() => _session = to);
              },
              () async {
                if (await _confirm(
                      '세션 삭제',
                      '현재 세션의 모든 운동을 삭제합니다. 저장하려면 각 주차의 세션 수를 같게 맞춰 주세요.',
                      '삭제',
                    ) &&
                    mounted) {
                  _change(() => week.sessions.removeAt(_session));
                }
              },
            ),
            TextButton.icon(
              onPressed: week.sessions.length >= 7
                  ? null
                  : () => _change(() {
                      week.sessions.add(
                        DetailedSessionDraft(
                          id: _draft.nextSessionId(),
                          exercises: [
                            DetailedExerciseDraft(
                              sets: [DetailedSetDraft(id: 'set-1')],
                            ),
                          ],
                        ),
                      );
                      _session = week.sessions.length - 1;
                    }),
              icon: const Icon(Icons.add),
              label: Text('세션 추가', style: AppType.action),
            ),
          ],
        ),
      ),
      for (var i = 0; i < session.exercises.length; i++)
        _exerciseEditor(session, i),
      TextButton.icon(
        onPressed: session.exercises.length >= 20
            ? null
            : () => _change(
                () => session.exercises.add(
                  DetailedExerciseDraft(
                    sets: [DetailedSetDraft(id: 'set-1')],
                    id: _nextId(
                      'exercise',
                      _draft.weeks
                          .expand((w) => w.sessions)
                          .expand((s) => s.exercises)
                          .map((e) => e.id),
                    ),
                  ),
                ),
              ),
        icon: const Icon(Icons.add),
        label: Text('운동 추가', style: AppType.action),
      ),
      if (_message != null)
        Text(
          _message!,
          key: const ValueKey('detail-message'),
          style: AppType.body,
        ),
      PrimaryAction(
        label: '변경 검토',
        onPressed: _saving || _saveError != null ? null : _preview,
      ),
    ];
    return PopScope(
      canPop: !_saving && _saveError == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('초안 저장을 완료한 뒤 나갈 수 있습니다.')),
          );
        }
      },
      child: FlowPage(
        title: '주차·세트 정밀 편집',
        children: [
          for (final child in children)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppSize.touch * 24),
                child: SizedBox(width: double.infinity, child: child),
              ),
            ),
        ],
      ),
    );
  }
}

String _setDescription(ProgramSet set) =>
    '${set.isAmrap ? 'AMRAP · 기준 ' : ''}${set.repetitions}회 · RIR ${set.rir == null ? '미지정' : formatNumber(set.rir!)} · ${switch (set.load.kind) {
      LoadKind.manual => '중량 직접 입력',
      LoadKind.fixedKg => '${formatNumber(set.load.value!)} kg',
      LoadKind.percentOfBaseline => '${liftLabel(set.load.lift!)} 기준 ${formatNumber(set.load.value!)}%',
    }} · ${set.isRequired ? '필수' : '선택'} · ${set.restSeconds == null ? '휴식 미지정' : '휴식 ${set.restSeconds}초'}${set.tempo == null ? '' : ' · 템포 ${set.tempo}'}';

class _DetailedReview extends StatefulWidget {
  final TrainingProgram program;
  final TrainingProgram? previous;
  final Future<bool> Function() onSave;
  const _DetailedReview({
    required this.program,
    this.previous,
    required this.onSave,
  });
  @override
  State<_DetailedReview> createState() => _DetailedReviewState();
}

class _DetailedReviewState extends State<_DetailedReview> {
  bool _saving = false;
  String? _error;
  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    bool saved;
    try {
      saved = await widget.onSave();
    } catch (_) {
      saved = false;
    }
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = '카탈로그에 저장하지 못했습니다. 검토한 입력을 유지했습니다. 다시 시도해 주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final program = widget.program, old = widget.previous;
    final oldSets = <String, ProgramSet>{};
    final oldExercises = <String, ProgramExercise>{};
    final exerciseLabels = <String, String>{};
    for (final session in old?.sessions ?? <ProgramSession>[]) {
      for (final exercise in session.exercises) {
        final key = jsonEncode([session.id, exercise.id]);
        oldExercises[key] = exercise;
        exerciseLabels[key] =
            '${session.week}주차 ${session.dayOrder}회차 · ${exercise.name}';
        for (final set in exercise.sets) {
          oldSets[jsonEncode([session.id, exercise.id, set.id])] = set;
        }
      }
    }
    final newSets = <String, ProgramSet>{};
    final newExercises = <String, ProgramExercise>{};
    for (final session in program.sessions) {
      for (final exercise in session.exercises) {
        final key = jsonEncode([session.id, exercise.id]);
        newExercises[key] = exercise;
        exerciseLabels[key] =
            '${session.week}주차 ${session.dayOrder}회차 · ${exercise.name}';
        for (final set in exercise.sets) {
          newSets[jsonEncode([session.id, exercise.id, set.id])] = set;
        }
      }
    }
    final added = newSets.keys.where((key) => !oldSets.containsKey(key)).length;
    final removed = oldSets.keys
        .where((key) => !newSets.containsKey(key))
        .length;
    final changed = newSets.keys
        .where(
          (key) =>
              oldSets.containsKey(key) &&
              jsonEncode(oldSets[key]!.toJson()) !=
                  jsonEncode(newSets[key]!.toJson()),
        )
        .length;
    final groupChanges = {...oldExercises.keys, ...newExercises.keys}
        .where(
          (key) =>
              oldExercises[key]?.supersetGroup !=
              newExercises[key]?.supersetGroup,
        )
        .toList();
    return PopScope(
      canPop: !_saving,
      child: FlowPage(
        title: '프로그램 변경 검토',
        children: [
          Text(program.title, style: AppType.title),
          Text(
            '${program.weeks}주 · 주 ${program.sessionsPerWeek}회 · ${program.sessions.length}세션',
            style: AppType.body,
          ),
          Text(
            old == null
                ? '새 프로그램 · v${program.version}'
                : '버전 ${old.version} → ${program.version}',
            style: AppType.body,
          ),
          Text(
            '세트 추가 $added · 변경 $changed · 삭제 $removed',
            key: const ValueKey('detail-review-counts'),
            style: AppType.heading,
          ),
          Text(
            '세트 수치는 동일 ID의 처방을 비교합니다. 순서·운동 이름·세션 이름 변경은 아래 전체 구성에서 확인해 주세요.',
            style: AppType.caption,
          ),
          if (groupChanges.isNotEmpty)
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '슈퍼세트 묶음 변경 ${groupChanges.length}개 운동',
                    style: AppType.heading,
                  ),
                  for (final key in groupChanges)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.x2),
                      child: Text(
                        '${exerciseLabels[key]} · ${oldExercises[key]?.supersetGroup ?? '묶음 없음'} → ${newExercises[key]?.supersetGroup ?? '묶음 없음'}',
                        style: AppType.body,
                      ),
                    ),
                ],
              ),
            ),
          if (old != null)
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('기존 프로그램', style: AppType.heading),
                  Text(
                    '${old.title} · ${old.weeks}주 · 주 ${old.sessionsPerWeek}회',
                    style: AppType.body,
                  ),
                  Text(old.description, style: AppType.caption),
                ],
              ),
            ),
          Text('새 설명 · ${program.description}', style: AppType.body),
          Text('운영자 · ${program.trainerName}', style: AppType.caption),
          if (old != null)
            Text(
              '같은 ID의 관리자 카탈로그를 교체합니다. 사용자가 시작한 계획과 운동 기록은 기존 스냅샷을 유지합니다.',
              style: AppType.caption.copyWith(color: AppColors.warn),
            ),
          for (final session in program.orderedSessions)
            GlassPanel(
              child: ExpansionTile(
                key: ValueKey('review-session-${session.id}'),
                tilePadding: EdgeInsets.zero,
                title: Text(
                  '${session.week}주차 · ${session.dayOrder}회차',
                  style: AppType.heading,
                ),
                subtitle: Text(session.title, style: AppType.body),
                children: [
                  for (final exercise in session.exercises)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.x4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(exercise.name, style: AppType.heading),
                          Text(
                            exercise.supersetGroup == null
                                ? '슈퍼세트 · 묶음 없음'
                                : '슈퍼세트 ${exercise.supersetGroup} · 묶인 운동을 한 세트씩 번갈아 진행',
                            style: AppType.caption,
                          ),
                          Text(
                            '기록 종목 · ${exercise.mainLift == null ? '미지정' : liftLabel(exercise.mainLift!)}',
                            style: AppType.caption,
                          ),
                          for (var i = 0; i < exercise.sets.length; i++) ...[
                            const SizedBox(height: AppSpace.x3),
                            Text(
                              '${i + 1}세트 · ${_setDescription(exercise.sets[i])}',
                              style: AppType.body,
                            ),
                            if (oldSets[jsonEncode([
                                  session.id,
                                  exercise.id,
                                  exercise.sets[i].id,
                                ])]
                                case final previous?)
                              Text(
                                '기존 · ${_setDescription(previous)}',
                                style: AppType.caption,
                              ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if (removed > 0)
            ExpansionTile(
              title: Text('삭제되는 세트 $removed개', style: AppType.heading),
              children: [
                for (final key in oldSets.keys.where(
                  (key) => !newSets.containsKey(key),
                ))
                  ListTile(
                    title: Text(key, style: AppType.caption),
                    subtitle: Text(
                      _setDescription(oldSets[key]!),
                      style: AppType.body,
                    ),
                  ),
              ],
            ),
          if (_error != null)
            Text(_error!, style: AppType.body.copyWith(color: AppColors.warn)),
          PrimaryAction(
            label: _error == null ? '검토한 프로그램 저장' : '카탈로그 저장 재시도',
            busy: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
