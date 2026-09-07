import 'package:flutter/material.dart';
import 'app/training_controller.dart';
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
  MaterialPageRoute(builder: (_) => ProgramScreen(controller: controller)),
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
              !controller.state.isSessionComplete(s.id),
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
          Text('기록이 남아 있는 운동', style: AppType.heading),
          _SessionCard(controller: controller, session: missed.last),
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
  const _SessionCard({
    required this.controller,
    required this.session,
    this.readOnly = false,
  });
  @override
  Widget build(BuildContext context) {
    final sets = session.exercises.expand((e) => e.sets).toList();
    final done = sets
        .where((s) => controller.state.setActuals.containsKey(s.id))
        .length;
    final complete = controller.state.isSessionComplete(session.id);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${session.date.month}월 ${session.date.day}일 · ${session.week}주차',
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
            complete ? '운동 완료' : '$done / ${sets.length}세트 기록',
            style: AppType.caption.copyWith(
              color: complete ? AppColors.good : AppColors.muted,
            ),
          ),
          const SizedBox(height: AppSpace.x4),
          PrimaryAction(
            label: readOnly ? '계획 미리보기' : (complete ? '기록 확인하기' : '운동 기록하기'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WorkoutScreen(
                  controller: controller,
                  session: session,
                  readOnly: readOnly,
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
  const SavedRecordsScreen({
    super.key,
    required this.controller,
    required this.today,
  });
  @override
  State<SavedRecordsScreen> createState() => _SavedRecordsScreenState();
}

class _SavedRecordsScreenState extends State<SavedRecordsScreen> {
  late DateTime _selected;
  late DateTime _month;
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
          (s) => s.exercises
              .expand((e) => e.sets)
              .any((set) => c.state.setActuals.containsKey(set.id)),
        )
        .toList();
    final activeIds =
        c.state.activePlan?.sessions.map((s) => s.id).toSet() ?? <String>{};
    final selectedSessions = all
        .where((s) => s.date == _selected)
        .where((s) => activeIds.contains(s.id) || recorded.contains(s))
        .toList();
    final lead = _month.weekday - 1;
    final days = DateTime.utc(_month.year, _month.month + 1, 0).day;
    return FlowPage(
      title: '기록',
      children: [
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
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                ),
                itemCount: lead + days,
                itemBuilder: (context, index) {
                  if (index < lead) return const SizedBox.shrink();
                  final date = DateTime.utc(
                    _month.year,
                    _month.month,
                    index - lead + 1,
                  );
                  final marked = recorded.any((s) => s.date == date);
                  final planned = all.any(
                    (s) => s.date == date && activeIds.contains(s.id),
                  );
                  return Semantics(
                    label:
                        '${date.month}월 ${date.day}일${marked
                            ? ', 운동 기록 있음'
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
        Text('• 기록한 운동   · 예정된 운동', style: AppType.caption),
        Text('${_selected.month}월 ${_selected.day}일', style: AppType.heading),
        if (selectedSessions.isEmpty)
          const StatePanel(
            title: '이 날짜의 기록이 없어요',
            message: '운동을 기록하면 실제 수행한 세트가 여기에 표시돼요.',
            icon: Icons.calendar_month_outlined,
          ),
        for (final session in selectedSessions)
          _SessionCard(
            controller: c,
            session: session,
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
