import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app/training_controller.dart';
import '../domain/recent_lift_record.dart';
import '../domain/training_program.dart';
import '../flow_components.dart';
import '../tokens.dart';
import '../widgets.dart';
import 'admin_program_store.dart';
import 'routine_builder.dart';

class AdminScreen extends StatefulWidget {
  final AdminProgramStore store;
  final ProgramLoader? seedPrograms;
  const AdminScreen({super.key, required this.store, this.seedPrograms});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  RoutineBlueprint _draft = RoutineBlueprint();
  List<TrainingProgram> _programs = [];
  bool _loading = true, _saving = false, _exporting = false;
  String? _loadError, _saveError, _message;
  int _revision = 0, _formVersion = 0;
  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final saved = await widget.store.load();
      final programs =
          saved?.programs ??
          await (widget.seedPrograms ?? loadBundledPrograms)();
      if (!mounted) return;
      setState(() {
        _draft = saved?.draft ?? RoutineBlueprint();
        _programs = programs;
        _formVersion++;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = '관리자 작업 파일을 읽지 못했어요. 원본을 유지했습니다.');
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  AdminWorkspace get _workspace =>
      AdminWorkspace(draft: _draft, programs: _programs);
  Future<bool> _save() async {
    final revision = ++_revision;
    setState(() {
      _saving = true;
      _saveError = null;
      _message = null;
    });
    try {
      await widget.store.save(_workspace);
      if (mounted && revision == _revision) {
        setState(() {
          _saving = false;
          _saveError = null;
        });
      }
      return true;
    } catch (_) {
      if (mounted && revision == _revision) {
        setState(() {
          _saving = false;
          _saveError = '아직 저장되지 않았어요. 입력을 유지하고 있어요.';
        });
      }
      return false;
    }
  }

  Future<void> _generate() async {
    try {
      final program = generateRoutine(_draft);
      final old = _programs.where((p) => p.id == program.id).firstOrNull;
      if (old != null && old.version == program.version) {
        throw const FormatException('같은 ID를 등록하려면 새 버전을 입력해 주세요.');
      }
      final approved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) =>
              AdminProgramReview(program: program, replacing: old != null),
        ),
      );
      if (!mounted || approved != true) return;
      setState(
        () => _programs = [
          ..._programs.where((p) => p.id != program.id),
          program,
        ],
      );
      final saved = await _save();
      if (mounted && saved) {
        setState(() => _message = '관리자 카탈로그에 저장했습니다. 사용자 앱에는 내보내기 후 반영해 주세요.');
      }
    } on FormatException catch (error) {
      setState(() => _message = error.message);
    }
  }

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      if (!await _save() || !mounted) return;
      final snapshot = AdminWorkspace.fromJson(_workspace.toJson());
      final exportedJson = snapshot.exportCatalog();
      final file = await widget.store.export(snapshot);
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('카탈로그 내보내기', style: AppType.heading),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${snapshot.programs.length}개 프로그램을 파일로 저장했습니다.',
                    style: AppType.body,
                  ),
                  const SizedBox(height: AppSpace.x3),
                  SelectableText(file.path, style: AppType.caption),
                  const SizedBox(height: AppSpace.x3),
                  Text(
                    '사용자 앱의 assets/programs.json에 반영하고 검증한 뒤 배포해 주세요.',
                    style: AppType.caption,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: exportedJson));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('카탈로그 JSON을 복사했습니다.')),
                    );
                  }
                },
                child: Text('JSON 복사', style: AppType.action),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('닫기', style: AppType.action),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = '내보내지 못했어요. 작업은 유지되며 다시 시도할 수 있습니다.');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _field(
    String key,
    String label,
    String value,
    void Function(String) update, {
    bool numeric = false,
    bool monoText = false,
    int lines = 1,
  }) => TextFormField(
    key: ValueKey('$_formVersion-$key'),
    initialValue: value,
    maxLines: lines,
    maxLength: lines > 1 ? 2000 : 80,
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    style: numeric || monoText ? AppType.number : AppType.body,
    onChanged: (text) {
      update(text);
      _save();
    },
    decoration: InputDecoration(
      labelText: label,
      labelStyle: AppType.caption,
      counterText: '',
      filled: true,
      fillColor: AppColors.fill,
      contentPadding: const EdgeInsets.all(AppSpace.x4),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.ctrl),
        borderSide: const BorderSide(color: AppColors.hairStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.ctrl),
        borderSide: const BorderSide(color: AppColors.accent),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.ctrl),
        borderSide: const BorderSide(color: AppColors.hairStrong),
      ),
    ),
  );
  Widget _exercise(int day, int index, ExerciseBlueprint exercise) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Divider(color: AppColors.hair, height: AppSpace.x6),
      Row(
        children: [
          Expanded(child: Text('운동 ${index + 1}', style: AppType.heading)),
          if (_draft.sessions[day].exercises.length > 1)
            IconButton(
              tooltip: '운동 삭제',
              onPressed: () {
                setState(() {
                  _draft.sessions[day].exercises.removeAt(index);
                  _formVersion++;
                });
                _save();
              },
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      _field(
        'd$day-e$index-id',
        '운동 ID · 같은 종목은 같은 ID',
        exercise.id,
        (v) => exercise.id = v,
      ),
      const SizedBox(height: AppSpace.x3),
      _field(
        'd$day-e$index-name',
        '운동 이름',
        exercise.name,
        (v) => exercise.name = v,
      ),
      const SizedBox(height: AppSpace.x3),
      DropdownButtonFormField<MainLift>(
        value: exercise.mainLift,
        hint: Text('메인 리프트 미지정', style: AppType.body),
        isExpanded: true,
        items: [
          const DropdownMenuItem<MainLift>(
            value: null,
            child: Text('메인 리프트 미지정'),
          ),
          for (final lift in MainLift.values)
            DropdownMenuItem(
              value: lift,
              child: Text(liftLabel(lift), style: AppType.body),
            ),
        ],
        onChanged: (v) {
          setState(() => exercise.mainLift = v);
          _save();
        },
      ),
      const SizedBox(height: AppSpace.x3),
      Row(
        children: [
          Expanded(
            child: _field(
              'd$day-e$index-count',
              '세트 수',
              exercise.setCount,
              (v) => exercise.setCount = v,
              numeric: true,
            ),
          ),
          const SizedBox(width: AppSpace.x3),
          Expanded(
            child: _field(
              'd$day-e$index-reps',
              '반복 수',
              exercise.repetitions,
              (v) => exercise.repetitions = v,
              numeric: true,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpace.x3),
      _field(
        'd$day-e$index-rir',
        '목표 RIR · 선택',
        exercise.rir,
        (v) => exercise.rir = v,
        numeric: true,
      ),
      const SizedBox(height: AppSpace.x3),
      DropdownButtonFormField<LoadKind>(
        value: exercise.loadKind,
        isExpanded: true,
        items: [
          for (final kind in LoadKind.values)
            DropdownMenuItem(
              value: kind,
              child: Text(switch (kind) {
                LoadKind.manual => '운동할 때 직접 중량 입력',
                LoadKind.fixedKg => '고정 중량 kg',
                LoadKind.percentOfBaseline => '기준 작업중량의 비율 %',
              }, style: AppType.body),
            ),
        ],
        onChanged: (v) {
          if (v != null) {
            setState(() => exercise.loadKind = v);
            _save();
          }
        },
      ),
      if (exercise.loadKind != LoadKind.manual) ...[
        const SizedBox(height: AppSpace.x3),
        _field(
          'd$day-e$index-load',
          exercise.loadKind == LoadKind.fixedKg
              ? '목표 kg'
              : '기준 작업중량 비율 % · 1RM 아님',
          exercise.loadValue,
          (v) => exercise.loadValue = v,
          numeric: true,
        ),
      ],
    ],
  );
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const FlowPage(
        title: '프로그램 관리',
        children: [LinearProgressIndicator()],
      );
    }
    if (_loadError != null) {
      return FlowPage(
        title: '프로그램 관리',
        children: [
          StatePanel(
            title: '불러오기 실패',
            message: _loadError!,
            action: PrimaryAction(label: '다시 시도', onPressed: _open),
          ),
        ],
      );
    }
    return FlowPage(
      title: '프로그램 관리',
      children: [
        Text(
          '관리자 내부 도구',
          style: AppType.caption.copyWith(color: AppColors.accent),
        ),
        Text('주간 운동 구성을 입력하고 원하는 기간만큼 반복 생성합니다.', style: AppType.body),
        Text(
          '세트·반복·중량은 관리자가 정합니다. 자동 처방이나 온라인 게시를 하지 않습니다.',
          style: AppType.caption,
        ),
        Text('관리자 카탈로그 ${_programs.length}개', style: AppType.heading),
        for (final program in _programs)
          Text(
            '${program.title} · ${program.weeks}주 · 주 ${program.sessionsPerWeek}회 · v${program.version}',
            style: AppType.caption,
          ),
        PrimaryAction(label: '카탈로그 내보내기', onPressed: _saving ? null : _export),
        const Divider(color: AppColors.hair),
        Text('새 루틴 생성', style: AppType.title),
        _field(
          'id',
          '프로그램 ID',
          _draft.id,
          (v) => _draft.id = v,
          monoText: true,
        ),
        _field('title', '프로그램 이름', _draft.title, (v) => _draft.title = v),
        _field(
          'description',
          '대상·장비·중량 선택 안내',
          _draft.description,
          (v) => _draft.description = v,
          lines: 3,
        ),
        Row(
          children: [
            Expanded(
              child: _field(
                'version',
                '버전',
                _draft.version,
                (v) => _draft.version = v,
              ),
            ),
            const SizedBox(width: AppSpace.x3),
            Expanded(
              child: _field(
                'weeks',
                '기간 · 주',
                _draft.weeks,
                (v) => _draft.weeks = v,
                numeric: true,
              ),
            ),
          ],
        ),
        for (var day = 0; day < _draft.sessions.length; day++)
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('주간 세션 ${day + 1}', style: AppType.heading),
                    ),
                    if (_draft.sessions.length > 1)
                      IconButton(
                        tooltip: '세션 삭제',
                        onPressed: () {
                          setState(() {
                            _draft.sessions.removeAt(day);
                            _formVersion++;
                          });
                          _save();
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.x3),
                _field(
                  'd$day-title',
                  '세션 이름',
                  _draft.sessions[day].title,
                  (v) => _draft.sessions[day].title = v,
                ),
                for (
                  var index = 0;
                  index < _draft.sessions[day].exercises.length;
                  index++
                )
                  _exercise(day, index, _draft.sessions[day].exercises[index]),
                if (_draft.sessions[day].exercises.length < 20)
                  TextButton.icon(
                    onPressed: () {
                      setState(
                        () => _draft.sessions[day].exercises.add(
                          ExerciseBlueprint(),
                        ),
                      );
                      _save();
                    },
                    icon: const Icon(Icons.add),
                    label: Text('운동 추가', style: AppType.action),
                  ),
              ],
            ),
          ),
        if (_draft.sessions.length < 7)
          TextButton.icon(
            onPressed: () {
              setState(() => _draft.sessions.add(SessionBlueprint()));
              _save();
            },
            icon: const Icon(Icons.add),
            label: Text('주간 세션 추가', style: AppType.action),
          ),
        if (_saveError != null)
          StatePanel(
            title: '초안 저장 실패',
            message: _saveError!,
            action: PrimaryAction(label: '저장 재시도', onPressed: _save),
          ),
        if (_message != null) Text(_message!, style: AppType.body),
        Text(
          _saving
              ? '초안 저장 중'
              : _saveError == null
              ? '초안은 관리자 기기에 저장됩니다.'
              : '아직 저장되지 않았습니다.',
          style: AppType.caption,
        ),
        PrimaryAction(label: '생성 결과 확인', busy: _saving, onPressed: _generate),
      ],
    );
  }
}

class AdminProgramReview extends StatelessWidget {
  final TrainingProgram program;
  final bool replacing;
  const AdminProgramReview({
    super.key,
    required this.program,
    this.replacing = false,
  });
  @override
  Widget build(BuildContext context) => FlowPage(
    title: '생성 결과 확인',
    children: [
      Text(program.title, style: AppType.title),
      Text(
        '${program.weeks}주 · 주 ${program.sessionsPerWeek}회 · 전체 ${program.sessions.length}세션',
        style: AppType.body,
      ),
      Text(program.description, style: AppType.caption),
      if (replacing)
        Text(
          '같은 ID의 관리자 카탈로그를 새 버전으로 교체합니다. 이미 시작한 사용자 계획은 별도 스냅샷입니다.',
          style: AppType.caption.copyWith(color: AppColors.warn),
        ),
      for (final session in program.orderedSessions)
        ExpansionTile(
          title: Text(
            '${session.week}주 · ${session.title}',
            style: AppType.heading,
          ),
          children: [
            for (final exercise in session.exercises)
              Padding(
                padding: const EdgeInsets.all(AppSpace.x4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.name, style: AppType.body),
                    for (final set in exercise.sets)
                      Text(
                        '${set.repetitions}회 · RIR ${set.rir ?? "미지정"} · ${switch (set.load.kind) {
                          LoadKind.manual => "중량 직접 입력",
                          LoadKind.fixedKg => "${set.load.value} kg",
                          LoadKind.percentOfBaseline => "기준 작업중량 ${set.load.value}%",
                        }}',
                        style: AppType.caption,
                      ),
                  ],
                ),
              ),
          ],
        ),
      PrimaryAction(
        label: '관리자 카탈로그에 저장',
        onPressed: () => Navigator.pop(context, true),
      ),
    ],
  );
}
