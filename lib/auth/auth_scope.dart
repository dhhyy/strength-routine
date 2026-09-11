import 'package:flutter/widgets.dart';

import '../auth/auth_controller.dart';

class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({
    super.key,
    required AuthController controller,
    required super.child,
  }) : super(notifier: controller);

  static AuthController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthScope>()?.notifier;

  static AuthController of(BuildContext context) {
    final c = maybeOf(context);
    assert(c != null, 'AuthScope not found');
    return c!;
  }
}
