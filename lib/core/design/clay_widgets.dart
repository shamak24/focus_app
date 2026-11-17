import 'package:flutter/material.dart';

import 'clay_card.dart';
import 'clay_theme.dart';

/// Pill button with the press-scale animation.
class ClayButton extends StatelessWidget {
  const ClayButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.expand = false,
    this.large = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Fill colour; defaults to the theme's primary.
  final Color? color;
  final bool expand;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final clay = context.clay;
    final fill = color ?? clay.primary;
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: ClayPressable(
        onTap: onPressed,
        scale: 0.94,
        builder: (context, pressed) => ClayCard(
          color: fill,
          radius: large ? 26 : 20,
          depth: pressed ? 2.5 : 6,
          padding: EdgeInsets.symmetric(horizontal: large ? 26 : 18, vertical: large ? 17 : 12),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: large ? 24 : 20), const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ClayText.label.copyWith(fontSize: large ? 17 : 14.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round icon-only button.
class ClayIconButton extends StatelessWidget {
  const ClayIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color,
    this.size = 46,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: ClayPressable(
        onTap: onPressed,
        scale: 0.9,
        builder: (context, pressed) => SizedBox.square(
          dimension: size,
          child: ClayCard(
            color: color,
            radius: size / 2,
            depth: pressed ? 2 : 5,
            padding: EdgeInsets.zero,
            child: Center(child: Icon(icon, size: size * 0.5)),
          ),
        ),
      ),
    );
  }
}

/// Selectable pill, used for pickers (priority, focus length, colours).
class ClayChip extends StatelessWidget {
  const ClayChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clay = context.clay;
    return ClayPressable(
      onTap: onTap,
      scale: 0.93,
      builder: (context, pressed) => ClayCard(
        color: selected ? clay.primary : clay.surface,
        radius: 18,
        depth: selected || pressed ? 3 : 5,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Text(label, style: ClayText.label),
      ),
    );
  }
}

/// Pressed-in track with a raised fill. [value] is 0 to 1.
class ClayProgressBar extends StatelessWidget {
  const ClayProgressBar({super.key, required this.value, this.height = 16, this.color});

  final double value;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final clay = context.clay;
    final fill = color ?? clay.primary;
    return SizedBox(
      height: height,
      child: ClayCard(
        inset: true,
        radius: height / 2,
        depth: 3,
        color: Color.alphaBlend(clay.ink.withValues(alpha: 0.07), clay.background),
        padding: EdgeInsets.zero,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: v,
              heightFactor: 1,
              child: v <= 0
                  ? const SizedBox.shrink()
                  : ClayCard(
                      color: fill,
                      radius: height / 2,
                      depth: 2,
                      padding: EdgeInsets.zero,
                      child: const SizedBox.expand(),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Text in the muted tone of whatever surface it sits on.
class Muted extends StatelessWidget {
  const Muted(this.text, {super.key, this.style = ClayText.caption, this.maxLines, this.textAlign});

  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: maxLines,
    textAlign: textAlign,
    overflow: maxLines == null ? null : TextOverflow.ellipsis,
    style: style.copyWith(color: context.inkMuted),
  );
}

/// Text field sitting in a pressed-in well.
class ClayTextField extends StatelessWidget {
  const ClayTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.autofocus = false,
    this.onSubmitted,
    this.textInputAction,
    this.maxLength,
  });

  final TextEditingController controller;
  final String hint;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final clay = context.clay;
    return ClayCard(
      inset: true,
      radius: 20,
      depth: 4,
      color: Color.alphaBlend(clay.ink.withValues(alpha: 0.05), clay.background),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        onSubmitted: onSubmitted,
        textInputAction: textInputAction,
        maxLength: maxLength,
        textCapitalization: TextCapitalization.sentences,
        cursorColor: clay.primary,
        style: ClayText.body.copyWith(color: clay.ink),
        decoration: InputDecoration(
          border: InputBorder.none,
          counterText: '',
          hintText: hint,
          hintStyle: ClayText.body.copyWith(color: clay.inkMuted),
        ),
      ),
    );
  }
}

/// Small rounded tag: a tinted pill with an optional icon.
class ClayTag extends StatelessWidget {
  const ClayTag({super.key, required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? context.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: ink), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ClayText.caption.copyWith(color: ink, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section heading with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
    child: Row(
      children: [
        Expanded(child: Text(title, style: ClayText.title)),
        ?trailing,
      ],
    ),
  );
}

/// Shows a bottom sheet over the whole app (above the nav and mini bars),
/// padded for the keyboard and with a grab handle.
Future<T?> showClaySheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: context.clay.ink.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              builder(context),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<bool> confirmClay(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel, style: TextStyle(color: context.clay.danger)),
        ),
      ],
    ),
  );
  return ok ?? false;
}
