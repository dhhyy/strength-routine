import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'components.dart';
import 'data/local_habit_store.dart';
import 'domain/habit_record.dart';
import 'flow_components.dart';
import 'tokens.dart';
import 'widgets.dart';

/// 사용자 습관과 날짜별 체크만 표시한다. 추천 목표량은 생성하지 않는다.
class HabitsScreen extends StatefulWidget {
  final LocalHabitStore? store;
  final DateTime Function()? now;
  const HabitsScreen({super.key, this.store, this.now});
  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen>
    with WidgetsBindingObserver {
  final _name = TextEditingController();
  final _form = GlobalKey<FormState>();
  LocalHabitStore? _store;
  HabitState _state = HabitState();
  late DateTime _today, _selectedDate;
  bool _loading = true, _saving = false;
  String? _loadError, _saveError, _pendingAddedName;

  DateTime get _now => widget.now?.call() ?? DateTime.now();
  bool get _canEdit =>
      !_loading && !_saving && _loadError == null && _saveError == null;

  @override
  void initState() {
    super.initState();
    _today = habitDate(_now);
    _selectedDate = _today;
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  @override
  void didUpdateWidget(covariant HabitsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshToday();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _name.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshToday();
  }

  bool _refreshToday() {
    final today = habitDate(_now);
    if (today != _today) {
      setState(() {
        if (_selectedDate == _today || _selectedDate.isAfter(today)) {
          _selectedDate = today;
        }
        _today = today;
      });
      return true;
    }
    return false;
  }

  void _toggleHabit(HabitDefinition habit, bool value) {
    // 날짜가 바뀐 화면의 체크값은 이전 날짜 기준이므로 적용하지 않는다.
    if (_refreshToday() || !_canEdit) return;
    _save(_state.setCompleted(habit.id, _selectedDate, value, asOf: _now));
  }

  void _moveDate(int days) {
    if (_refreshToday() || _saving) return;
    final date = _selectedDate.add(Duration(days: days));
    if (date.isBefore(_firstDate) || date.isAfter(_today)) return;
    setState(() => _selectedDate = date);
  }

  Future<void> _open() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      _store ??=
          widget.store ??
          LocalHabitStore(
            File(
              '${(await getApplicationSupportDirectory()).path}/habits-state.json',
            ),
          );
      final state = await _store!.load();
      if (mounted) setState(() => _state = state);
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = '저장된 습관을 읽지 못했어요. 원본 파일은 유지했어요.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(HabitState state) async {
    setState(() {
      _state = state;
      _saving = true;
      _saveError = null;
    });
    try {
      await _store!.save(state);
      if (!mounted) return;
      if (_pendingAddedName != null) {
        _name.clear();
        _pendingAddedName = null;
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saveError = '아직 기기에 저장되지 않았어요. 입력을 유지하고 있어요.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _add() async {
    if (!_canEdit || !_form.currentState!.validate()) return;
    _refreshToday();
    final name = _name.text.trim();
    final prefix = 'habit-${_now.microsecondsSinceEpoch}';
    var id = prefix;
    var suffix = 0;
    while (_state.habits.any((habit) => habit.id == id)) {
      id = '$prefix-${++suffix}';
    }
    final next = _state.add(
      HabitDefinition(id: id, name: name, createdDate: _today),
    );
    _pendingAddedName = name;
    setState(() => _selectedDate = _today);
    await _save(next);
  }

  String? _nameError(String? value) {
    final name = (value ?? '').trim();
    if (name.isEmpty) return '습관 이름을 입력해 주세요.';
    if (name.runes.length > 80) return '이름은 80자 이하로 입력해 주세요.';
    if (_state.habits.any(
      (habit) => habit.name.toLowerCase() == name.toLowerCase(),
    )) {
      return '같은 이름의 습관이 있어요. 보관 목록도 확인해 주세요.';
    }
    return null;
  }

  DateTime get _firstDate => _state.habits.fold(
    _today,
    (earliest, habit) =>
        habit.createdDate.isBefore(earliest) ? habit.createdDate : earliest,
  );

  Future<void> _pickDate() async {
    _refreshToday();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(_firstDate)
          ? _firstDate
          : _selectedDate,
      firstDate: _firstDate,
      lastDate: _today,
    );
    if (date != null && mounted) {
      setState(() => _selectedDate = habitDate(date));
    }
  }

  Widget _habitRow(HabitDefinition habit, {bool archived = false}) {
    final existsOnDate = !habit.createdDate.isAfter(_selectedDate);
    return Row(
      children: [
        Expanded(
          child: CheckboxListTile(
            key: ValueKey('habit-check-${habit.id}'),
            value: _state.isCompleted(habit.id, _selectedDate),
            onChanged: _canEdit && existsOnDate
                ? (value) => _toggleHabit(habit, value!)
                : null,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.good,
            checkColor: AppColors.ctaInk,
            title: Text(habit.name, style: AppType.body),
            subtitle: !existsOnDate
                ? Text('등록 전 날짜', style: AppType.caption)
                : archived
                ? Text('보관된 습관', style: AppType.caption)
                : null,
          ),
        ),
        IconButton(
          key: ValueKey('habit-archive-${habit.id}'),
          tooltip: archived ? '${habit.name} 다시 활성화' : '${habit.name} 보관',
          onPressed: _canEdit
              ? () => _save(_state.setArchived(habit.id, !archived))
              : null,
          icon: Icon(
            archived ? Icons.unarchive_outlined : Icons.archive_outlined,
          ),
          color: AppColors.muted,
          iconSize: AppSize.icon,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _state.habits
        .where(
          (habit) =>
              !habit.archived && !habit.createdDate.isAfter(_selectedDate),
        )
        .toList();
    final archived = _state.habits.where((habit) => habit.archived).toList();
    final todaySelected = _selectedDate == _today;
    return ScreenScaffold(
      title: '생활습관',
      children: [
        if (_loading) ...[
          const LinearProgressIndicator(),
          Text('저장된 습관을 불러오고 있어요.', style: AppType.body),
        ] else if (_loadError != null)
          StatePanel(
            title: '습관을 불러오지 못했어요',
            message: _loadError!,
            icon: Icons.error_outline,
            action: PrimaryAction(label: '다시 불러오기', onPressed: _open),
          )
        else ...[
          Row(
            children: [
              IconButton(
                tooltip: '이전 날짜',
                onPressed: !_saving && _selectedDate.isAfter(_firstDate)
                    ? () => _moveDate(-1)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: TextButton(
                  onPressed: _saving ? null : _pickDate,
                  child: Text(
                    habitDateKey(_selectedDate),
                    style: AppType.number,
                  ),
                ),
              ),
              IconButton(
                tooltip: '다음 날짜',
                onPressed: !_saving && _selectedDate.isBefore(_today)
                    ? () => _moveDate(1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todaySelected ? '오늘 체크한 습관' : '선택한 날 체크한 습관',
                  style: AppType.caption,
                ),
                const SizedBox(height: AppSpace.x2),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${_state.completedCount(_selectedDate)}',
                        style: AppType.number,
                      ),
                      TextSpan(text: '개 완료', style: AppType.heading),
                    ],
                  ),
                ),
                if (!todaySelected)
                  TextButton(
                    onPressed: () {
                      _refreshToday();
                      setState(() => _selectedDate = _today);
                    },
                    child: Text('오늘로 이동', style: AppType.action),
                  ),
              ],
            ),
          ),
          if (_saving) const LinearProgressIndicator(),
          if (_saveError != null)
            StatePanel(
              title: '저장되지 않은 변경이 있어요',
              message: _saveError!,
              icon: Icons.save_outlined,
              action: PrimaryAction(
                label: '저장 다시 시도',
                onPressed: _saving ? null : () => _save(_state),
              ),
            ),
          if (active.isEmpty)
            StatePanel(
              title: _state.habits.isEmpty
                  ? '등록한 습관이 없어요'
                  : '이 날짜에 활동 중인 습관이 없어요',
              message: _state.habits.isEmpty
                  ? '기록할 습관의 이름을 아래에 입력해 주세요.'
                  : '보관한 습관과 다른 날짜의 기록을 확인할 수 있어요.',
              icon: Icons.checklist,
            )
          else
            GlassPanel(
              child: Column(
                children: [for (final habit in active) _habitRow(habit)],
              ),
            ),
          Form(
            key: _form,
            child: Column(
              children: [
                ConsoleField(
                  key: const ValueKey('habit-name'),
                  controller: _name,
                  label: '습관 이름',
                  numeric: false,
                  enabled: _canEdit,
                  validator: _nameError,
                ),
                const SizedBox(height: AppSpace.x3),
                PrimaryAction(
                  label: '습관 추가',
                  onPressed: _canEdit ? _add : null,
                ),
              ],
            ),
          ),
          if (archived.isNotEmpty)
            GlassPanel(
              child: ExpansionTile(
                key: const ValueKey('archived-habits'),
                tilePadding: EdgeInsets.zero,
                title: Text('보관한 습관', style: AppType.heading),
                subtitle: Text('체크 기록은 보관 후에도 유지돼요.', style: AppType.caption),
                children: [
                  for (final habit in archived)
                    _habitRow(habit, archived: true),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
