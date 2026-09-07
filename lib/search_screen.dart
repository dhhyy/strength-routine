import 'package:flutter/material.dart';

import 'app/training_controller.dart';
import 'domain/training_program.dart';
import 'flow_components.dart';
import 'tokens.dart';
import 'widgets.dart';

/// 실제 프로그램의 운동 항목을 출처별로 찾는다. 이름으로 종목을 합치지 않는다.
class SearchScreen extends StatefulWidget {
  final TrainingController controller;
  const SearchScreen({super.key, required this.controller});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final entries = _exerciseEntries(controller);
      final query = _query.text.trim().toLowerCase();
      final results = entries
          .where((entry) => entry.exercise.name.toLowerCase().contains(query))
          .toList();
      return FlowPage(
        title: '운동 검색',
        children: [
          ConsoleField(
            key: const ValueKey('exercise-search-query'),
            controller: _query,
            label: '운동 이름',
            numeric: false,
            onChanged: (_) => setState(() {}),
          ),
          if (query.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(_query.clear),
                icon: const Icon(Icons.clear, size: AppSize.icon),
                label: Text('검색어 지우기', style: AppType.action),
              ),
            ),
          if (controller.catalogLoading) ...[
            const LinearProgressIndicator(),
            Text('등록된 프로그램을 불러오고 있어요.', style: AppType.caption),
          ],
          if (controller.catalogError != null)
            StatePanel(
              title: '등록된 프로그램을 불러오지 못했어요',
              message: entries.isEmpty
                  ? '다시 시도해 주세요.'
                  : '기기에 있는 운동은 계속 검색할 수 있어요.',
              icon: Icons.cloud_off_outlined,
              action: PrimaryAction(
                label: '다시 불러오기',
                busy: controller.catalogLoading,
                onPressed: controller.refreshPrograms,
              ),
            ),
          if (entries.isEmpty &&
              !controller.catalogLoading &&
              controller.catalogError == null)
            const StatePanel(
              title: '검색할 운동이 없어요',
              message: '등록된 프로그램이나 기기에 저장한 계획의 운동이 여기에 표시돼요.',
              icon: Icons.search_outlined,
            )
          else if (entries.isNotEmpty && results.isEmpty)
            const StatePanel(
              title: '검색 결과가 없어요',
              message: '운동 이름을 확인하거나 검색어를 지워 주세요.',
              icon: Icons.search_off,
            )
          else if (results.isNotEmpty) ...[
            Text('프로그램별 운동 ${results.length}개', style: AppType.caption),
            for (final entry in results)
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.exercise.name, style: AppType.heading),
                    const SizedBox(height: AppSpace.x2),
                    Text(entry.program.title, style: AppType.body),
                    const SizedBox(height: AppSpace.x2),
                    Text(entry.program.trainerName, style: AppType.caption),
                    const SizedBox(height: AppSpace.x2),
                    Text(
                      '${entry.source} · ${entry.session.week}주차 · ${entry.session.title}',
                      style: AppType.caption,
                    ),
                    const SizedBox(height: AppSpace.x2),
                    Text(
                      '${entry.exercise.sets.length}세트${entry.plannedSession == null ? '' : ' · ${isoDate(entry.plannedSession!.date)}'}',
                      style: AppType.caption,
                    ),
                    const SizedBox(height: AppSpace.x3),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(AppSize.touch, AppSize.touch),
                      ),
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => _ExercisePlanDetail(entry: entry),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.receipt_long_outlined,
                        size: AppSize.icon,
                      ),
                      label: Text('운동 구성 보기', style: AppType.action),
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

/// 공통 종목 ID가 아닌 특정 프로그램·세션 안의 운동 발생 항목이다.
class _ExerciseEntry {
  final String source;
  final TrainingProgram program;
  final ProgramSession session;
  final ProgramExercise exercise;
  final PlannedSession? plannedSession;
  final PlannedExercise? plannedExercise;
  const _ExerciseEntry({
    required this.source,
    required this.program,
    required this.session,
    required this.exercise,
    this.plannedSession,
    this.plannedExercise,
  });
}

List<_ExerciseEntry> _exerciseEntries(TrainingController controller) {
  final entries = <_ExerciseEntry>[];
  void addProgram(
    TrainingProgram program,
    String source, {
    ActiveTrainingPlan? plan,
  }) {
    final sessions = program.orderedSessions;
    final planned = plan?.sessions;
    for (var i = 0; i < sessions.length; i++) {
      final session = sessions[i];
      for (var j = 0; j < session.exercises.length; j++) {
        entries.add(
          _ExerciseEntry(
            source: source,
            program: program,
            session: session,
            exercise: session.exercises[j],
            plannedSession: planned?[i],
            plannedExercise: planned?[i].exercises[j],
          ),
        );
      }
    }
  }

  final active = controller.state.activePlan;
  if (active != null) {
    addProgram(active.program, '진행 중 계획', plan: active);
  }
  for (final plan in controller.state.planHistory.reversed) {
    addProgram(plan.program, '보관한 계획', plan: plan);
  }
  for (final program in controller.programs) {
    addProgram(program, '등록 프로그램');
  }
  return entries;
}

class _ExercisePlanDetail extends StatelessWidget {
  final _ExerciseEntry entry;
  const _ExercisePlanDetail({required this.entry});

  @override
  Widget build(BuildContext context) => FlowPage(
    title: '운동 구성',
    children: [
      Text(entry.exercise.name, style: AppType.title),
      Text('${entry.source} · 읽기 전용', style: AppType.caption),
      GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.program.title, style: AppType.heading),
            const SizedBox(height: AppSpace.x2),
            Text(entry.program.trainerName, style: AppType.body),
            const SizedBox(height: AppSpace.x2),
            Text.rich(
              TextSpan(
                style: AppType.caption,
                children: [
                  const TextSpan(text: '프로그램 버전 '),
                  TextSpan(text: entry.program.version, style: mono()),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.x4),
            Text(
              '${entry.session.week}주차 · ${entry.session.dayOrder}번째 운동일',
              style: AppType.caption,
            ),
            Text(entry.session.title, style: AppType.body),
            if (entry.plannedSession != null) ...[
              const SizedBox(height: AppSpace.x2),
              Text(isoDate(entry.plannedSession!.date), style: mono()),
            ],
          ],
        ),
      ),
      for (var i = 0; i < entry.exercise.sets.length; i++)
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${i + 1}세트 · ${entry.exercise.sets[i].isRequired ? '필수' : '선택'}',
                style: AppType.heading,
              ),
              const SizedBox(height: AppSpace.x2),
              Text.rich(
                TextSpan(
                  style: AppType.body,
                  children: [
                    TextSpan(
                      text: '${entry.exercise.sets[i].repetitions}',
                      style: mono(),
                    ),
                    const TextSpan(text: '회'),
                    if (entry.exercise.sets[i].rir != null)
                      TextSpan(
                        text:
                            ' · RIR ${formatNumber(entry.exercise.sets[i].rir!)}',
                        style: mono(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.x2),
              Text.rich(
                TextSpan(
                  style: AppType.body,
                  children: [
                    const TextSpan(text: '원래 처방 · '),
                    ..._loadSpans(entry.exercise.sets[i].load),
                  ],
                ),
              ),
              if (entry.plannedExercise != null) ...[
                const SizedBox(height: AppSpace.x2),
                Text.rich(
                  TextSpan(
                    style: AppType.body,
                    children: [
                      const TextSpan(text: '이 계획의 목표 · '),
                      if (entry.plannedExercise!.sets[i].targetKg == null)
                        const TextSpan(text: '중량 직접 기록')
                      else
                        TextSpan(
                          text:
                              '${formatNumber(entry.plannedExercise!.sets[i].targetKg!)} kg',
                          style: mono(),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
    ],
  );

  List<InlineSpan> _loadSpans(LoadPrescription load) => switch (load.kind) {
    LoadKind.manual => [const TextSpan(text: '중량 직접 기록')],
    LoadKind.fixedKg => [
      TextSpan(text: '${formatNumber(load.value!)} kg', style: mono()),
    ],
    LoadKind.percentOfBaseline => [
      TextSpan(text: '${liftLabel(load.lift!)} 기준 중량의 '),
      TextSpan(text: '${formatNumber(load.value!)}%', style: mono()),
    ],
  };
}
