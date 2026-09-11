import 'package:flutter/material.dart';

import 'app/training_controller.dart';
import 'app/working_max_controller.dart';
import 'app/working_max_scope.dart';
import 'domain/e1rm.dart';
import 'domain/e1rm_proposals.dart';
import 'domain/training_insights.dart';
import 'domain/training_program.dart';
import 'flow_components.dart';
import 'tokens.dart';
import 'widgets.dart';

class TrainingInsightsScreen extends StatefulWidget {
  final TrainingController controller;
  final WorkingMaxController? workingMax;
  final DateTime Function()? now;
  final bool showSuggestions;
  const TrainingInsightsScreen({
    super.key,
    required this.controller,
    this.workingMax,
    this.now,
    this.showSuggestions = true,
  });
  @override
  State<TrainingInsightsScreen> createState() => _TrainingInsightsScreenState();
}

class _TrainingInsightsScreenState extends State<TrainingInsightsScreen> {
  String? _planId, _error, _message;
  bool _busy = false;
  final _statusKey = GlobalKey();
  final _scrollController = ScrollController();
  DateTime get _today => widget.now?.call() ?? DateTime.now();
  bool get _saving => _busy || widget.controller.saving;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _revealStatus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      final context = _statusKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(context, alignment: 0);
      }
    });
  }

  Future<void> _save(TrainingAppState Function(TrainingAppState) change) async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final saved = await widget.controller.update(change);
      if (!mounted) return;
      setState(() {
        _error = saved ? null : widget.controller.saveError ?? '저장을 완료하지 못했어요.';
        _message = saved ? '기기에 저장했어요.' : null;
      });
      if (!saved) _revealStatus();
    } on FormatException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
        _revealStatus();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(
    TargetLoadAdjustment adjustment, {
    bool undo = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        backgroundColor: AppColors.bgLift,
        surfaceTintColor: AppColors.bgLift,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.panel),
          side: const BorderSide(color: AppColors.hairStrong),
        ),
        title: Text(
          undo ? '중량 조정을 되돌릴까요?' : '다음 목표를 확인해 주세요',
          style: AppType.heading,
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(adjustment.exerciseName, style: AppType.body),
            const SizedBox(height: AppSpace.x4),
            Text('운동·반복·RIR과 실제 기록은 유지돼요.', style: AppType.caption),
            ..._changes(adjustment, undo: undo),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소', style: AppType.action),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(undo ? '되돌리기' : '적용하기', style: AppType.action),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _save(
      (state) => undo
          ? state.undoLoadAdjustment(adjustment.id, asOf: _today)
          : state.withLoadAdjustment(adjustment, asOf: _today),
    );
  }

  List<Widget> _changes(TargetLoadAdjustment adjustment, {bool undo = false}) {
    final state = widget.controller.state;
    final plan = [
      ...state.planHistory,
      if (state.activePlan != null) state.activePlan!,
    ].firstWhere((p) => p.id == adjustment.planId);
    final children = <Widget>[];
    for (final session in plan.sessions) {
      final changes = [
        for (final exercise in session.exercises)
          for (var i = 0; i < exercise.sets.length; i++)
            if (adjustment.afterKg.containsKey(exercise.sets[i].id))
              (number: i + 1, id: exercise.sets[i].id),
      ];
      if (changes.isEmpty) continue;
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.x6),
          child: Text(isoDate(session.date), style: AppType.number),
        ),
      );
      for (final change in changes) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.x2),
            child: Wrap(
              spacing: AppSpace.x4,
              runSpacing: AppSpace.x1,
              children: [
                Text.rich(
                  TextSpan(
                    style: AppType.caption,
                    children: [
                      TextSpan(
                        text: '${change.number}',
                        style: mono(color: AppColors.muted),
                      ),
                      const TextSpan(text: '세트'),
                    ],
                  ),
                ),
                Text(
                  '${_number((undo ? adjustment.afterKg : adjustment.beforeKg)[change.id]!)} → '
                  '${_number((undo ? adjustment.beforeKg : adjustment.afterKg)[change.id]!)} kg',
                  style: AppType.number,
                ),
              ],
            ),
          ),
        );
      }
    }
    return children;
  }

  String? _undoReason(TargetLoadAdjustment adjustment) {
    try {
      widget.controller.state.undoLoadAdjustment(adjustment.id, asOf: _today);
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  Future<void> _adoptE1rm(
    WorkingMaxController workingMax,
    E1rmProposal proposal,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        backgroundColor: AppColors.bgLift,
        surfaceTintColor: AppColors.bgLift,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.panel),
          side: const BorderSide(color: AppColors.hairStrong),
        ),
        title: Text('추정 1RM을 채택할까요?', style: AppType.heading),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(liftLabel(proposal.lift), style: AppType.body),
            const SizedBox(height: AppSpace.x4),
            Text(
              '${_number(proposal.sourceWeightKg)} kg × ${proposal.sourceRepetitions}회 → '
              '추정 ${_number(proposal.estimatedKg)} kg',
              style: AppType.number,
            ),
            const SizedBox(height: AppSpace.x4),
            Text(
              '이미 끝난 세트의 목표 중량은 바꾸지 않아요. '
              '채택하면 working max와 진행 중 계획의 기준 중량만 갱신해요.',
              style: AppType.caption,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소', style: AppType.action),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('채택하기', style: AppType.action),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await workingMax.adoptEstimated(
        lift: proposal.lift,
        estimatedKg: proposal.estimatedKg,
        sourceWeightKg: proposal.sourceWeightKg,
        sourceRepetitions: proposal.sourceRepetitions,
        note: proposal.exerciseName,
        now: _today.toUtc(),
      );
      final plan = widget.controller.state.activePlan;
      if (plan != null) {
        final blocked = <String>{
          ...widget.controller.state.setActuals.keys,
          ...widget.controller.state.setDrafts.keys,
        };
        final saved = await widget.controller.update(
          (state) => state.replaceActivePlan(
            plan.refillFuturePercentTargets(
              lift: proposal.lift,
              baselineKg: roundE1rmKg(proposal.estimatedKg),
              asOf: _today,
              blockedSetIds: blocked,
            ),
          ),
        );
        if (!mounted) return;
        if (!saved) {
          setState(() {
            _error =
                widget.controller.saveError ??
                'working max는 저장했지만 계획 기준 중량 저장에 실패했어요.';
          });
          _revealStatus();
          return;
        }
      }
      if (!mounted) return;
      setState(
        () => _message =
            '${liftLabel(proposal.lift)} working max·기준 중량을 저장했어요.',
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'working max를 저장하지 못했어요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // push된 라우트는 HomeShell의 InheritedScope 밖이다. 생성자로 받은 컨트롤러를 우선한다.
    final workingMax =
        widget.workingMax ?? WorkingMaxScope.maybeOf(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        if (workingMax == null) {
          return _buildBody(context, workingMax: null);
        }
        return ListenableBuilder(
          listenable: workingMax,
          builder: (context, _) =>
              _buildBody(context, workingMax: workingMax),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required WorkingMaxController? workingMax,
  }) {
      final controller = widget.controller;
      final state = controller.state;
      if (controller.loading) {
        return const FlowPage(
          title: '기록 추세',
          children: [LinearProgressIndicator()],
        );
      }
      if (controller.loadError != null) {
        return FlowPage(
          title: '기록 추세',
          children: [
            StatePanel(
              title: '기록을 불러오지 못했어요',
              message: controller.loadError!,
              action: PrimaryAction(
                label: '다시 불러오기',
                onPressed: controller.initialize,
              ),
            ),
          ],
        );
      }
      final plans = [
        if (state.activePlan != null) state.activePlan!,
        ...state.planHistory.reversed,
      ];
      if (plans.isEmpty) {
        return const FlowPage(
          title: '기록 추세',
          children: [
            StatePanel(
              title: '아직 프로그램 기록이 없어요',
              message: '프로그램을 시작하고 세트를 기록하면 여기에서 확인할 수 있어요.',
              icon: Icons.show_chart,
            ),
          ],
        );
      }
      final plan =
          plans.where((p) => p.id == _planId).firstOrNull ?? plans.first;
      final trends = buildTrainingInsights(
        state,
        planId: plan.id,
        asOf: _today,
      );
      final suggestions = trends
          .map((t) => t.suggestion)
          .whereType<TargetLoadAdjustment>()
          .toList();
      final history = state.loadAdjustments
          .where((a) => a.planId == plan.id)
          .toList()
          .reversed;
      final proposals = e1rmFeatureFlag
          ? buildE1rmProposals(state, planId: plan.id, asOf: _today)
          : const <E1rmProposal>[];
      final offered = [
        for (final p in proposals)
          if (p.shouldOffer(workingMax?.state[p.lift])) p,
      ];
      return FlowPage(
        title: '기록 추세',
        scrollController: _scrollController,
        children: [
          DropdownButtonFormField<String>(
            key: const ValueKey('insights-plan'),
            value: plan.id,
            isExpanded: true,
            style: AppType.body,
            decoration: InputDecoration(
              labelText: '프로그램',
              labelStyle: AppType.caption,
            ),
            items: [
              for (final p in plans)
                DropdownMenuItem(
                  value: p.id,
                  child: Text(
                    '${p.program.title} · ${isoDate(p.startDate)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _saving
                ? null
                : (value) => setState(() {
                    _planId = value;
                    _error = null;
                  }),
          ),
          Text(
            state.activePlan?.id == plan.id ? '진행 중인 계획' : '보관한 계획 · 기록 조회',
            style: AppType.caption,
          ),
          Text('계획한 날짜 기준이에요. 실제 수행 날짜는 별도로 기록되지 않았어요.', style: AppType.body),
          Text(
            '프로그램별 기록을 구분하고 실제 중량은 kg로 환산해 보여요. 초안과 제외는 수행값에 넣지 않아요.',
            style: AppType.caption,
          ),
          if (_error != null || controller.saveError != null)
            KeyedSubtree(
              key: _statusKey,
              child: StatePanel(
                title: '변경을 확인해 주세요',
                message: _error ?? controller.saveError!,
                icon: Icons.info_outline,
                action: controller.saveError == null
                    ? null
                    : PrimaryAction(
                        label: '저장 다시 시도',
                        // 저장 중에도 라벨을 유지해 화면·테스트가 재시도 CTA를 놓치지 않게 한다.
                        onPressed: _saving
                            ? null
                            : () => _save((state) => state),
                      ),
              ),
            ),
          if (_saving) const LinearProgressIndicator(),
          if (_message != null)
            Semantics(
              liveRegion: true,
              child: Text(_message!, style: AppType.caption),
            ),
          if (e1rmFeatureFlag) ...[
            Text('추정 1RM (working max)', style: AppType.heading),
            Text(
              'Epley 공식으로 추정해요. 실제 1RM이 아니며, 채택해도 지난 세트 목표는 그대로예요.',
              style: AppType.caption,
            ),
            if (workingMax != null)
              for (final entry in workingMax.state.byLift.entries)
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(liftLabel(entry.key), style: AppType.heading),
                      const SizedBox(height: AppSpace.x2),
                      Text(
                        '${_number(entry.value.kilograms)} kg',
                        style: AppType.number,
                      ),
                      Text(
                        '채택 · ${isoDate(entry.value.adoptedAt)}',
                        style: AppType.caption,
                      ),
                    ],
                  ),
                ),
            if (workingMax == null)
              Text(
                'working max 저장소를 연결하지 못했어요. 앱을 다시 실행해 주세요.',
                style: AppType.caption,
              )
            else if (offered.isEmpty)
              Text(
                '채택할 새 추정이 없어요. mainLift가 있는 작업 세트와 1–12회 기록이 필요해요.',
                style: AppType.caption,
              )
            else
              for (final proposal in offered)
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(liftLabel(proposal.lift), style: AppType.heading),
                      const SizedBox(height: AppSpace.x2),
                      Text(
                        '${_number(proposal.sourceWeightKg)} kg × ${proposal.sourceRepetitions}회',
                        style: AppType.body,
                      ),
                      Text(
                        '추정 ${_number(proposal.estimatedKg)} kg · ${proposal.exerciseName}',
                        style: AppType.number,
                      ),
                      Text(
                        '근거 세션 · ${isoDate(proposal.plannedDate)}',
                        style: AppType.caption,
                      ),
                      const SizedBox(height: AppSpace.x4),
                      PrimaryAction(
                        label: 'working max로 채택',
                        busy: _saving,
                        onPressed: () => _adoptE1rm(workingMax, proposal),
                      ),
                    ],
                  ),
                ),
            ExpansionTile(
              title: Text('추정 1RM 기준', style: AppType.body),
              childrenPadding: const EdgeInsets.all(AppSpace.x4),
              children: [
                Text(
                  'e1RM = 무게 × (1 + 반복/30). 12회 초과·RIR 4 초과 세트는 제외해요. '
                  '정책 id: $e1rmPolicyId',
                  style: AppType.caption,
                ),
              ],
            ),
          ],
          Text('중량 조정', style: AppType.heading),
          if (!widget.showSuggestions)
            Text(
              '새 감량 제안 표시가 꺼져 있어요. 기존 조정은 아래에서 확인하고 되돌릴 수 있어요.',
              style: AppType.caption,
            )
          else if (suggestions.isEmpty)
            Text(
              '현재 적용할 새 제안이 없어요. 같은 운동의 비교 가능한 최근 기록 3회와 미기록 미래 목표가 필요해요.',
              style: AppType.caption,
            )
          else ...[
            Text(
              '목표와 반복 수가 같은 최근 3회에서 평균 RIR이 목표보다 1 이상 낮았어요. 다음 중량을 최대 5% 낮추는 제안이에요.',
              style: AppType.caption,
            ),
            for (final suggestion in suggestions)
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(suggestion.exerciseName, style: AppType.heading),
                    const SizedBox(height: AppSpace.x2),
                    Text(
                      '미래 ${suggestion.afterKg.length}세트 · 장비 단위에 맞춘 중량',
                      style: AppType.body,
                    ),
                    const SizedBox(height: AppSpace.x4),
                    PrimaryAction(
                      label: '변경 내용 확인',
                      busy: _saving,
                      onPressed: () => _review(suggestion),
                    ),
                  ],
                ),
              ),
          ],
          if (widget.showSuggestions)
            ExpansionTile(
              title: Text('제안 기준과 한계', style: AppType.body),
              childrenPadding: const EdgeInsets.all(AppSpace.x4),
              children: [
                Text(
                  'RIR은 주관적인 기록이에요. 3회·차이 1·최대 5%는 앱의 초기 규칙이며 보편적인 처방 공식은 아니에요. 누락·제외·초안이 있으면 제안을 보류하고, 조정 후 새로운 기록 3회를 기다려요. 세트 수와 반복, RIR은 바꾸지 않아요.',
                  style: AppType.caption,
                ),
              ],
            ),
          if (history.isNotEmpty) Text('적용 이력', style: AppType.heading),
          for (final adjustment in history) _historyCard(adjustment),
          Text('운동별 수행 기록', style: AppType.heading),
          if (trends.every(
            (trend) => trend.points.every(
              (p) => p.performedSets + p.skippedSets + p.draftSets == 0,
            ),
          ))
            const StatePanel(
              title: '아직 실제 수행 기록이 없어요',
              message: '세트를 완료하면 중량·반복·RIR 기록을 비교할 수 있어요.',
              icon: Icons.show_chart,
            )
          else
            for (final trend in trends) _trendCard(trend),
        ],
      );
  }

  Widget _historyCard(TargetLoadAdjustment adjustment) {
    final reason = adjustment.isUndone ? null : _undoReason(adjustment);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                adjustment.isUndone ? Icons.undo : Icons.check_circle_outline,
                color: AppColors.accent,
                size: AppSize.icon,
              ),
              const SizedBox(width: AppSpace.x2),
              Expanded(
                child: Text(adjustment.exerciseName, style: AppType.heading),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.x2),
          Text(
            adjustment.isUndone
                ? '되돌림 · ${isoDate(adjustment.undoneOn!)}'
                : '적용 · ${isoDate(adjustment.appliedOn)}',
            style: AppType.caption,
          ),
          Text(
            '${adjustment.afterKg.length}세트 · 원래 계획과 실제 기록 보존',
            style: AppType.caption,
          ),
          if (reason != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.x2),
              child: Text(reason, style: AppType.caption),
            ),
          if (!adjustment.isUndone) ...[
            const SizedBox(height: AppSpace.x4),
            OutlinedButton(
              onPressed: _saving || reason != null
                  ? null
                  : () => _review(adjustment, undo: true),
              child: Text('조정 되돌리기', style: AppType.action),
            ),
          ],
        ],
      ),
    );
  }

  Widget _trendCard(ExerciseTrend trend) {
    final points = trend.points
        .where((p) => p.performedSets + p.skippedSets + p.draftSets > 0)
        .toList();
    if (points.isEmpty) return const SizedBox.shrink();
    final largest = points
        .map((p) => p.maxWeightKg ?? 0)
        .fold<double>(0, (a, b) => a > b ? a : b);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(trend.name, style: AppType.heading),
          Text('세션별 실제 최대 중량 · 같은 반복 수를 보장하지 않아요.', style: AppType.caption),
          for (final point in points.reversed) ...[
            const SizedBox(height: AppSpace.x6),
            Wrap(
              spacing: AppSpace.x4,
              runSpacing: AppSpace.x2,
              children: [
                Text(isoDate(point.plannedDate), style: AppType.number),
                Text(
                  point.maxWeightKg == null
                      ? '수행값 없음'
                      : '${_number(point.maxWeightKg!)} kg',
                  style: point.maxWeightKg == null
                      ? AppType.caption
                      : AppType.number,
                ),
              ],
            ),
            const SizedBox(height: AppSpace.x2),
            LinearProgressIndicator(
              value: largest == 0 ? 0 : (point.maxWeightKg ?? 0) / largest,
              semanticsLabel: '${isoDate(point.plannedDate)} 실제 최대 중량',
              semanticsValue: point.maxWeightKg == null
                  ? '없음'
                  : '${_number(point.maxWeightKg!)} kg',
            ),
            const SizedBox(height: AppSpace.x2),
            Text(
              '수행 ${point.performedSets}세트 · 반복 ${point.repetitions}회 · 제외 ${point.skippedSets} · 초안 ${point.draftSets}',
              style: AppType.caption,
            ),
            Text(
              point.averageRir == null
                  ? 'RIR 미입력'
                  : '평균 RIR ${_number(point.averageRir!)} · ${point.rirCount}세트 입력',
              style: AppType.caption,
            ),
          ],
        ],
      ),
    );
  }
}

String _number(double value) =>
    formatNumber(double.parse(value.toStringAsFixed(2)));
