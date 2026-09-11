import 'package:flutter/widgets.dart';

import '../app/cloud_snapshot_controller.dart';

class CloudSnapshotScope extends InheritedNotifier<CloudSnapshotController> {
  const CloudSnapshotScope({
    super.key,
    required CloudSnapshotController controller,
    required super.child,
  }) : super(notifier: controller);

  static CloudSnapshotController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<CloudSnapshotScope>()
      ?.notifier;
}
