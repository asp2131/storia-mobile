import 'package:flutter/material.dart';

import '../theme/storia_colors.dart';
import '../theme/storia_motion.dart';
import 'sketch_border.dart';

enum SketchButtonTone { primary, secondary, muted }

class SketchButton extends StatelessWidget {
  const SketchButton({
    super.key,
    required this.label,
    this.onPressed,
    this.leading,
    this.trailing,
    this.expand = true,
    this.tone = SketchButtonTone.primary,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final Widget? trailing;
  final bool expand;
  final SketchButtonTone tone;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final background = switch (tone) {
      SketchButtonTone.primary => StoriaColors.ink,
      SketchButtonTone.secondary => Colors.white,
      SketchButtonTone.muted => StoriaColors.paperAlt,
    };
    final foreground = switch (tone) {
      SketchButtonTone.primary => StoriaColors.paper,
      SketchButtonTone.secondary => StoriaColors.ink,
      SketchButtonTone.muted => StoriaColors.ink,
    };
    final border = switch (tone) {
      SketchButtonTone.primary => StoriaColors.ink,
      SketchButtonTone.secondary => StoriaColors.lineStrong,
      SketchButtonTone.muted => StoriaColors.line,
    };

    final child = AnimatedOpacity(
      duration: StoriaMotion.quick,
      opacity: enabled ? 1 : 0.64,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background,
          disabledForegroundColor: foreground,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape: SketchBorderShape(side: BorderSide(color: border, width: 1.6)),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(foreground),
                ),
              )
            else if (leading != null)
              leading!,
            if (isLoading || leading != null) const SizedBox(width: 10),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          ],
        ),
      ),
    );

    if (expand) {
      return SizedBox(width: double.infinity, child: child);
    }
    return child;
  }
}
