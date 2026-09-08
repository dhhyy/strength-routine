import 'package:flutter/material.dart';
import 'app/training_controller.dart';
import 'backup_screen.dart';
import 'schedule_screen.dart';
import 'app/settings_controller.dart';
import 'domain/recent_lift_record.dart';
import 'settings_screen.dart';
import 'support_screen.dart';
import 'subscription_screen.dart';
import 'training_insights_screen.dart';
import 'domain/training_program.dart';
import 'flow_components.dart';
import 'program_screen.dart';
import 'tokens.dart';
import 'widgets.dart';
import 'workout_screen.dart';

Future<void> openPrograms(
  BuildContext context,
  TrainingController controller,
) => Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => ProgramScreen(
      controller: controller,
      defaultUnit:
          SettingsScope.maybeOf(context)?.settings.defaultWeightUnit ??
          WeightUnit.kg,
    ),
  ),
);

class ActiveTodayScreen extends StatelessWidget {
  final TrainingController controller;
  final DateTime today;
  const ActiveTodayScreen({
    super.key,
    required this.controller,
    required this.today,
  });
  @override
  Widget build(BuildContext context) {
    final plan = controller.state.activePlan;
    if (plan == null) {
      return FlowPage(
        title: '오늘 루틴',
        children: [
          Text('${today.month}월 ${today.day}일', style: AppType.caption),
          const StatePanel(
            title: '첫 프로그램을 선택해 주세요',
            message: '트레이너의 프로그램을 선택하면 오늘 할 운동을 확인하고 기록할 수 있어요.',
          ),
          PrimaryAction(
            label: '프로그램 선택하기',
            onPressed: () => openPrograms(context, controller),
          ),
        ],
      );
    }
    final todaySessions = plan.sessions
        .where((s) => s.date == calendarDate(today))
        .toList();
    final future = plan.sessions
        .where((s) => s.date.isAfter(calendarDate(today)))
        .toList();
    final missed = plan.sessions
        .where(
          (s) =>
              s.date.isBefore(calendarDate(today)) &&
              !controller.state.isSessionClosed(s.id),
        )
        .toList();
    return FlowPage(
      title: '오늘 루틴',
      trailing: IconButton(
        tooltip: '프로그램 선택',
        icon: const Icon(Icons.library_books_outlined),
        onPressed: () => openPrograms(context, controller),
      ),
      children: [
        Text('${today.month}월 ${today.day}일', style: AppType.caption),
        Text(plan.program.title, style: AppType.title),
        Text(
          '${plan.program.trainerName} · ${plan.program.weeks}주',
          style: AppType.caption,
        ),
        TextButton.icon(
          key: const ValueKey('open-schedule-editor'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ScheduleScreen(controller: controller),
            ),
          ),
          icon: const Icon(Icons.edit_calendar_outlined),
          label: Text('남은 일정 편집', style: AppType.action),
        ),
        if (todaySessions.isEmpty)
          StatePanel(
            title: future.isEmpty ? '예정된 운동이 끝났어요' : '오늘은 예정된 운동이 없어요',
            message: future.isEmpty
                ? '기록 탭에서 수행한 운동을 확인할 수 있어요.'
                : '다음 운동은 ${future.first.date.month}월 ${future.first.date.day}일이에요.',
            icon: Icons.event_available,
          ),
        for (final session in todaySessions)
          _SessionCard(controller: controller, session: session),
        if (missed.isNotEmpty) ...[
          Text('놓친 운동 · 기록이 남아 있어요', style: AppType.heading),
          _SessionCard(controller: controller, session: missed.last),
          TextButton(
            key: const ValueKey('open-missed-workouts'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    MissedWorkoutsScreen(controller: controller, today: today),
              ),
            ),
            child: Text(
              '놓친 운동 모두 보기 · ${missed.length}개',
              style: AppType.action,
            ),
          ),
        ],
        if (future.isNotEmpty) ...[
          Text('다음 운동', style: AppType.heading),
          _SessionCard(
            controller: controller,
            session: future.first,
            readOnly: true,
          ),
        ],
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  final TrainingController controller;
  final PlannedSession session;
  final bool readOnly;
  final DateTime? performedOn;
  const _SessionCard({
    required this.controller,
    required this.session,
    this.readOnly = false,
    this.performedOn,
  });
  @override
  Widget build(BuildContext context) {
    final sets = session.exercises.expand((e) => e.sets).toList();
    final recorded = sets
        .where((s) => controller.state.setActuals.containsKey(s.id))
        .length;
    final performed = sets
        .where(
          (s) =>
              controller.state.setActuals[s.id]?.status ==
              SetActualStatus.completed,
        )
        .length;
    final skipped = recorded - performed;
    final drafts = sets
        .where((s) => controller.state.setDrafts.containsKey(s.id))
        .length;
    final complete = controller.state.isSessionComplete(session.id);
    final summary = controller.state.sessionSummary(session.id);
    final closed = controller.state.isSessionClosed(session.id);
    final hasEvents = controller.state.sessionEvents.any(
      (event) => event.sessionId == session.id,
    );
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '예정 ${session.date.month}월 ${session.date.day}일 · ${session.week}주차',
            style: AppType.caption,
          ),
          const SizedBox(height: AppSpace.x2),
          Text(session.title, style: AppType.heading),
          const SizedBox(height: AppSpace.x3),
          Text(
            session.exercises.map((e) => e.name).join(' · '),
            style: AppType.body,
          ),
          const SizedBox(height: AppSpace.x4),
          Text(
            recorded == sets.length
                ? '모든 세트 기록됨'
                : complete
                ? '필수 세트 기록됨'
                : '$recorded / ${sets.length}세트 기록',
            style: AppType.caption.copyWith(
              color: complete && performed > 0
                  ? AppColors.good
                  : AppColors.muted,
            ),
          ),
          const SizedBox(height: AppSpace.x2),
          Text(
            '${performedOn == null ? '' : '세션 전체 · '}실제 수행 $performed세트 · 제외 $skipped세트${drafts > 0 ? ' · 작성 중 $drafts세트' : ''}',
            style: AppType.caption,
          ),
          if (performedOn != null)
            Text(
              '선택한 날 실제 수행 ${sets.where((set) => controller.state.setActuals[set.id]?.status == SetActualStatus.completed && controller.state.setActuals[set.id]?.performedDate == performedOn).length}세트',
              key: ValueKey('performed-on-${session.id}'),
              style: AppType.caption.copyWith(color: AppColors.accent),
            ),
          const SizedBox(height: AppSpace.x2),
          Text(
            closed
                ? '기록 마침'
                : hasEvents
                ? '기록 다시 열림 · 수정 후 다시 마쳐 주세요'
                : controller.state.legacySessionIds.contains(session.id)
                ? '이전 기록 · 마감 여부 미상'
                : '아직 기록을 마치지 않았어요',
            style: AppType.caption.copyWith(
              color: closed ? AppColors.good : AppColors.muted,
            ),
          ),
          if (summary.performedDates.isNotEmpty) ...[
            const SizedBox(height: AppSpace.x2),
            Text('실제 수행일', style: AppType.caption),
            Text(
              summary.performedDates.map(isoDate).join(' · '),
              style: mono(color: AppColors.inkDim),
            ),
          ],
          if (summary.unknownDateSets > 0)
            Text('수행일 미상 ${summary.unknownDateSets}세트', style: AppType.caption),
          const SizedBox(height: AppSpace.x4),
          PrimaryAction(
            label: readOnly
                ? (recorded > 0 ||
                          drafts > 0 ||
                          hasEvents ||
                          controller.state.sessionNotes.containsKey(
                            session.id,
                          ) ||
                          controller.state.legacySessionIds.contains(session.id)
                      ? '기록 확인하기'
                      : '계획 미리보기')
                : (complete ? '기록 확인하기' : '운동 기록하기'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _inheritSettings(
                  context,
                  WorkoutScreen(
                    controller: controller,
                    session: session,
                    readOnly: readOnly,
                    defaultUnit:
                        SettingsScope.maybeOf(
                          context,
                        )?.settings.defaultWeightUnit ??
                        WeightUnit.kg,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SavedRecordsScreen extends StatefulWidget {
  final TrainingController controller;
  final DateTime today;
  final DateTime Function()? now;
  const SavedRecordsScreen({
    super.key,
    required this.controller,
    required this.today,
    this.now,
  });
  @override
  State<SavedRecordsScreen> createState() => _SavedRecordsScreenState();
}

class _SavedRecordsScreenState extends State<SavedRecordsScreen> {
  late DateTime _selected;
  late DateTime _month;
  bool _byPerformedDate = false;
  @override
  void initState() {
    super.initState();
    _selected = calendarDate(widget.today);
    _month = DateTime.utc(_selected.year, _selected.month);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final all = [
      ...c.state.planHistory,
      if (c.state.activePlan != null) c.state.activePlan!,
    ].expand((p) => p.sessions).toList();
    final recorded = all
        .where(
          (s) =>
              c.state.sessionNotes.containsKey(s.id) ||
              c.state.legacySessionIds.contains(s.id) ||
              c.state.completionNotified.contains(s.id) ||
              c.state.sessionEvents.any((event) => event.sessionId == s.id) ||
              s.exercises
                  .expand((e) => e.sets)
                  .any(
                    (set) =>
                        c.state.setActuals.containsKey(set.id) ||
                        c.state.setDrafts.containsKey(set.id),
                  ),
        )
        .toList();
    final activeIds =
        c.state.activePlan?.sessions.map((s) => s.id).toSet() ?? <String>{};
    final performedDates = {
      for (final session in all)
        session.id: c.state.sessionSummary(session.id).performedDates.toSet(),
    };
    final unknownDateSets = all.fold<int>(
      0,
      (sum, session) =>
          sum + c.state.sessionSummary(session.id).unknownDateSets,
    );
    final selectedSessions = all.where((session) {
      if (_byPerformedDate) {
        return performedDates[session.id]!.contains(_selected);
      }
      return session.date == _selected &&
          (activeIds.contains(session.id) || recorded.contains(session));
    }).toList();
    final lead = _month.weekday - 1;
    final days = DateTime.utc(_month.year, _month.month + 1, 0).day;
    return FlowPage(
      title: '기록',
      children: [
        PrimaryAction(
          label: '기록 추세·중량 조절',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TrainingInsightsScreen(
                controller: c,
                now: widget.now,
                showSuggestions:
                    SettingsScope.maybeOf(
                      context,
                    )?.settings.showLoadSuggestions ??
                    true,
              ),
            ),
          ),
        ),
        SegmentedButton<bool>(
          key: const ValueKey('record-date-basis'),
          segments: [
            ButtonSegment(
              value: false,
              label: Text('예정일', style: AppType.action),
            ),
            ButtonSegment(
              value: true,
              label: Text('수행일', style: AppType.action),
            ),
          ],
          selected: {_byPerformedDate},
          onSelectionChanged: (selection) =>
              setState(() => _byPerformedDate = selection.single),
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(
              Size(AppSize.touch, AppSize.touch),
            ),
            side: const WidgetStatePropertyAll(
              BorderSide(color: AppColors.hairStrong),
            ),
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? AppColors.accentSoft
                  : AppColors.fill,
            ),
            foregroundColor: const WidgetStatePropertyAll(AppColors.ink),
          ),
        ),
        GlassPanel(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: '이전 달',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() {
                      _month = DateTime.utc(_month.year, _month.month - 1);
                      _selected = _month;
                    }),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '${_month.year}.${_month.month.toString().padLeft(2, '0')}',
                        style: AppType.number,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '다음 달',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(() {
                      _month = DateTime.utc(_month.year, _month.month + 1);
                      _selected = _month;
                    }),
                  ),
                ],
              ),
              Row(
                children: [
                  for (final name in const ['월', '화', '수', '목', '금', '토', '일'])
                    Expanded(
                      child: Center(child: Text(name, style: AppType.caption)),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.x2),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: MediaQuery.textScalerOf(
                    context,
                  ).scale(AppSize.touch),
                ),
                itemCount: lead + days,
                itemBuilder: (context, index) {
                  if (index < lead) return const SizedBox.shrink();
                  final date = DateTime.utc(
                    _month.year,
                    _month.month,
                    index - lead + 1,
                  );
                  final marked = _byPerformedDate
                      ? performedDates.values.any(
                          (dates) => dates.contains(date),
                        )
                      : recorded.any((s) => s.date == date);
                  final planned =
                      !_byPerformedDate &&
                      all.any(
                        (s) => s.date == date && activeIds.contains(s.id),
                      );
                  return Semantics(
                    label:
                        '${date.month}월 ${date.day}일${marked
                            ? (_byPerformedDate ? ', 실제 수행 있음' : ', 운동 기록 있음')
                            : planned
                            ? ', 운동 계획 있음'
                            : ''}',
                    selected: date == _selected,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.ctrl),
                      onTap: () => setState(() => _selected = date),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: date == _selected
                              ? AppColors.accentSoft
                              : null,
                          borderRadius: BorderRadius.circular(AppRadius.ctrl),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${date.day}',
                              style: mono(
                                color: date == _selected
                                    ? AppColors.accent
                                    : AppColors.ink,
                              ),
                            ),
                            Text(
                              marked
                                  ? '•'
                                  : planned
                                  ? '·'
                                  : ' ',
                              style: mono(
                                color: marked
                                    ? AppColors.good
                                    : AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        Text(
          _byPerformedDate
              ? '확인된 실제 수행일 · 완료 세트만 표시'
              : '계획한 날짜별 기록 · 작성 중인 입력도 포함',
          style: AppType.caption,
        ),
        if (_byPerformedDate && unknownDateSets > 0)
          Text(
            '수행일 미상 $unknownDateSets세트는 예정일 보기에서 확인할 수 있어요.',
            key: const ValueKey('unknown-performed-dates'),
            style: AppType.caption,
          ),
        Text('${_selected.month}월 ${_selected.day}일', style: AppType.heading),
        if (selectedSessions.isEmpty)
          StatePanel(
            title: _byPerformedDate ? '확인된 실제 수행이 없어요' : '이 날짜의 기록이 없어요',
            message: _byPerformedDate
                ? '제외·초안·수행일 미상은 이 날짜의 실제 수행에 포함하지 않아요.'
                : '운동을 기록하면 실제 수행한 세트가 여기에 표시돼요.',
            icon: Icons.calendar_month_outlined,
          ),
        for (final session in selectedSessions)
          _SessionCard(
            controller: c,
            session: session,
            performedOn: _byPerformedDate ? _selected : null,
            readOnly:
                !activeIds.contains(session.id) ||
                session.date.isAfter(calendarDate(widget.today)),
          ),
      ],
    );
  }
}

class CurrentProfileScreen extends StatelessWidget {
  final TrainingController controller;
  const CurrentProfileScreen({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => FlowPage(
    title: '프로필',
    children: [
      StatePanel(
        title: '나의 프로그램',
        message:
            controller.state.activePlan?.program.title ?? '아직 시작한 프로그램이 없어요.',
        icon: Icons.fitness_center,
        action: PrimaryAction(
          label: '프로그램 선택',
          onPressed: () => openPrograms(context, controller),
        ),
      ),
      if (SettingsScope.maybeOf(context) != null)
        PrimaryAction(
          label: '앱 설정',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  SettingsScreen(controller: SettingsScope.maybeOf(context)!),
            ),
          ),
        ),
      PrimaryAction(
        label: '운동 기록 백업',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BackupScreen(controller: controller),
          ),
        ),
      ),
      TextButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SupportScreen())),
        child: Text('도움말·자주 묻는 질문', style: AppType.action),
      ),
      TextButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SubscriptionScreen())),
        child: Text('구독 안내', style: AppType.action),
      ),
      Text('최근 리프트 기록', style: AppType.heading),
      if (controller.state.recentRecords.isEmpty)
        Text('프로그램을 시작할 때 입력한 기록이 여기에 보관돼요.', style: AppType.caption),
      for (final record in controller.state.recentRecords)
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(liftLabel(record.lift), style: AppType.heading),
              const SizedBox(height: AppSpace.x2),
              Text(
                '${formatNumber(record.weight)} ${record.unit.key} · ${record.repetitions}회 · ${isoDate(record.date)}',
                style: AppType.body,
              ),
            ],
          ),
        ),
      Text('기록은 이 기기에 저장돼요.', style: AppType.caption),
      TextButton(
        onPressed: () =>
            showLicensePage(context: context, applicationName: '오늘 루틴'),
        child: Text('오픈소스 라이선스', style: AppType.caption),
      ),
    ],
  );
}

/// Missed sessions retain their schedule and record on a separate performed date.
class MissedWorkoutsScreen extends StatelessWidget {
  final TrainingController controller;
  final DateTime today;
  const MissedWorkoutsScreen({
    super.key,
    required this.controller,
    required this.today,
  });
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final missed =
          controller.state.activePlan?.sessions
              .where(
                (session) =>
                    session.date.isBefore(calendarDate(today)) &&
                    !controller.state.isSessionClosed(session.id),
              )
              .toList() ??
          [];
      return FlowPage(
        title: '놓친 운동',
        children: [
          Text('예정일은 유지해요. 실제로 운동한 날은 세트 입력에서 지정해 주세요.', style: AppType.body),
          if (missed.isEmpty)
            const StatePanel(
              title: '놓친 운동이 없어요',
              message: '지난 예정일 중 아직 마감하지 않은 운동이 여기에 표시돼요.',
              icon: Icons.event_available,
            ),
          for (final session in missed)
            _SessionCard(controller: controller, session: session),
        ],
      );
    },
  );
}

Widget _inheritSettings(BuildContext source, Widget child) {
  final settings = SettingsScope.maybeOf(source);
  return settings == null
      ? child
      : SettingsScope(controller: settings, child: child);
}
