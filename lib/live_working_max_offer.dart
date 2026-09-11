import 'package:flutter/material.dart';

import 'app/training_controller.dart';
import 'app/working_max_controller.dart';
import 'domain/e1rm.dart';
import 'domain/live_working_max.dart';
import 'domain/recent_lift_record.dart';
import 'domain/training_program.dart';
import 'domain/working_max.dart';
import 'flow_components.dart';
import 'tokens.dart';

/// 세트 저장 직후 조건이 맞으면 working max 갱신 제안을 보여 준다.
Future<void> maybeOfferLiveWorkingMaxUpdate(
  BuildContext context, {
  required TrainingController controller,
  required WorkingMaxController? workingMax,
  required PlannedSession session,
  required PlannedExercise exercise,
  required PlannedSet set,
}) async {
  if (!e1rmFeatureFlag || workingMax == null || !context.mounted) return;
  final plan = controller.state.activePlan;
  if (plan == null) return;
  final actual = controller.state.setActuals[set.id];
  if (actual == null) return;
  final lift = mainLiftForExercise(plan, exercise);
  final proposal = liveWorkingMaxProposal(
    lift: lift,
    exerciseName: exercise.name,
    sessionId: session.id,
    plannedDate: session.date,
    actual: actual,
    current: lift == null ? null : workingMax.state[lift],
    setKind: set.kind,
  );
  if (proposal == null || !context.mounted) return;

  // D5 감량 조정이 살아 있으면 회복·감량 우선 — working max 제안 숨김.
  final hasActiveDeload = controller.state.loadAdjustments.any((a) {
    if (a.isUndone || a.planId != plan.id) return false;
    return a.afterKg.keys.any((setId) {
      for (final session in plan.sessions) {
        for (final exercise in session.exercises) {
          for (final set in exercise.sets) {
            if (set.id == setId) {
              return mainLiftForExercise(plan, exercise) == proposal.lift;
            }
          }
        }
      }
      return false;
    });
  });
  if (hasActiveDeload) return;

  final previousWm = workingMax.state[proposal.lift];
  final previousPlan = plan;
  final fromText = previousWm == null
      ? '없음'
      : '${previousWm.kilograms}';
  final apply = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.bgLift,
      title: Text('working max 제안', style: AppType.heading),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(liftLabel(proposal.lift), style: AppType.body),
          const SizedBox(height: AppSpace.x2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: fromText, style: AppType.number),
                TextSpan(text: ' → ', style: AppType.body),
                TextSpan(
                  text: '${proposal.estimatedKg}',
                  style: AppType.number,
                ),
                TextSpan(text: ' kg', style: AppType.body),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.x2),
          Text(
            '이 세트로 추정한 값입니다. 적용하면 이후 미기록 % 목표만 다시 채워요.',
            style: AppType.caption,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('나중에', style: AppType.action),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('적용', style: AppType.action),
        ),
      ],
    ),
  );
  if (apply != true || !context.mounted) return;

  final blocked = <String>{
    ...controller.state.setActuals.keys,
    ...controller.state.setDrafts.keys,
  };
  final asOf = controller.now();
  try {
    await workingMax.adoptEstimated(
      lift: proposal.lift,
      estimatedKg: proposal.estimatedKg,
      sourceWeightKg: proposal.sourceWeightKg,
      sourceRepetitions: proposal.sourceRepetitions,
      note: proposal.exerciseName,
      now: asOf.toUtc(),
    );
    final saved = await controller.update(
      (state) => state.replaceActivePlan(
        applyLiveWorkingMax(
          previousPlan,
          lift: proposal.lift,
          estimatedKg: proposal.estimatedKg,
          asOf: asOf,
          blockedSetIds: blocked,
        ),
      ),
    );
    if (!context.mounted) return;
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            controller.saveError ??
                'working max는 저장했지만 계획 갱신에 실패했어요.',
            style: AppType.body,
          ),
        ),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${liftLabel(proposal.lift)} working max를 적용했어요.',
          style: AppType.body,
        ),
        action: SnackBarAction(
          label: '되돌리기',
          onPressed: () {
            _undoLiveWorkingMax(
              controller: controller,
              workingMax: workingMax,
              lift: proposal.lift,
              previousWm: previousWm,
              previousPlan: previousPlan,
            );
          },
        ),
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('working max를 저장하지 못했어요.', style: AppType.body),
      ),
    );
  }
}

Future<void> _undoLiveWorkingMax({
  required TrainingController controller,
  required WorkingMaxController workingMax,
  required MainLift lift,
  required WorkingMax? previousWm,
  required ActiveTrainingPlan previousPlan,
}) async {
  try {
    await workingMax.restoreLift(lift, previousWm);
    await controller.update((state) => state.replaceActivePlan(previousPlan));
  } catch (_) {
    // SnackBar 액션에서는 추가 안내는 생략한다.
  }
}
