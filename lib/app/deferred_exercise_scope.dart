import 'package:flutter/widgets.dart';

import 'deferred_exercise_controller.dart';

class DeferredExerciseScope
    extends InheritedNotifier<DeferredExerciseController> {
  const DeferredExerciseScope({
    super.key,
    required DeferredExerciseController controller,
    required super.child,
  }) : super(notifier: controller);

  static DeferredExerciseController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DeferredExerciseScope>()
      ?.notifier;
}
