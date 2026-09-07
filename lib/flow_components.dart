import 'package:flutter/material.dart';
import 'domain/recent_lift_record.dart';
import 'tokens.dart';
import 'widgets.dart';

class FlowPage extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  const FlowPage({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title, style: AppType.heading),
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.ink,
      surfaceTintColor: AppColors.bg,
      actions: [if (trailing != null) trailing!],
    ),
    body: DecoratedBox(
      decoration: const BoxDecoration(gradient: AppGradients.screen),
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.x4),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpace.x4),
              children[i],
            ],
          ],
        ),
      ),
    ),
  );
}

class StatePanel extends StatelessWidget {
  final String title, message;
  final IconData icon;
  final Widget? action;
  const StatePanel({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.fitness_center,
    this.action,
  });

  @override
  Widget build(BuildContext context) => GlassPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppSize.emptyIcon, color: AppColors.accent),
        const SizedBox(height: AppSpace.x6),
        Text(title, style: AppType.heading),
        const SizedBox(height: AppSpace.x2),
        Text(message, style: AppType.body.copyWith(color: AppColors.inkDim)),
        if (action != null) ...[const SizedBox(height: AppSpace.x6), action!],
      ],
    ),
  );
}

class PrimaryAction extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  const PrimaryAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    style: FilledButton.styleFrom(
      minimumSize: const Size(double.infinity, AppSize.touch),
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.ctaInk,
      disabledBackgroundColor: AppColors.fill,
      disabledForegroundColor: AppColors.muted,
      textStyle: AppType.action,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.ctrl),
      ),
    ),
    child: busy
        ? const SizedBox.square(
            dimension: AppSize.icon,
            child: CircularProgressIndicator(),
          )
        : Text(label),
  );
}

class ConsoleField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool numeric;
  final bool enabled;
  final int maxLines;
  const ConsoleField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.onChanged,
    this.numeric = true,
    this.maxLines = 1,
    this.hint,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    enabled: enabled,
    validator: validator,
    onChanged: onChanged,
    maxLines: maxLines,
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    textInputAction: TextInputAction.next,
    style: numeric ? AppType.number : AppType.body,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: AppType.caption,
      hintStyle: AppType.caption,
      errorStyle: AppType.caption.copyWith(color: AppColors.danger),
      errorMaxLines: 3,
      filled: true,
      fillColor: AppColors.fill,
      contentPadding: const EdgeInsets.all(AppSpace.x4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.ctrl),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.ctrl),
        borderSide: const BorderSide(color: AppColors.hairStrong),
      ),
    ),
  );
}

String formatNumber(num value) =>
    value == value.roundToDouble() ? '${value.toInt()}' : '$value';
String liftLabel(MainLift lift) => switch (lift) {
  MainLift.squat => '스쿼트',
  MainLift.benchPress => '벤치프레스',
  MainLift.deadlift => '데드리프트',
  MainLift.overheadPress => '오버헤드프레스',
};
