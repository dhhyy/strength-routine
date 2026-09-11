import 'package:flutter/widgets.dart';

import '../app/working_max_controller.dart';

class WorkingMaxScope extends InheritedNotifier<WorkingMaxController> {
  const WorkingMaxScope({
    super.key,
    required WorkingMaxController controller,
    required super.child,
  }) : super(notifier: controller);

  static WorkingMaxController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WorkingMaxScope>()?.notifier;

  static WorkingMaxController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'WorkingMaxScope not found');
    return controller!;
  }
}
