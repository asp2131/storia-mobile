import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/storia_colors.dart';
import '../theme/storia_motion.dart';

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
      SketchButtonTone.primary => StoriaColors.sage,
      SketchButtonTone.secondary => Colors.white,
      SketchButtonTone.muted => StoriaColors.paperAlt,
    };
    final foreground = switch (tone) {
      SketchButtonTone.primary => StoriaColors.ink,
      SketchButtonTone.secondary => StoriaColors.ink,
      SketchButtonTone.muted => StoriaColors.inkMuted,
    };
    final borderColor = switch (tone) {
      SketchButtonTone.primary => StoriaColors.ink,
      SketchButtonTone.secondary => StoriaColors.ink,
      SketchButtonTone.muted => StoriaColors.line,
    };

    final child = AnimatedOpacity(
      duration: StoriaMotion.quick,
      opacity: enabled ? 1 : 0.64,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: borderColor,
              offset: const Offset(0, 6),
              blurRadius: 0,
            ),
          ],
        ),
        child: FilledButton(
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            disabledBackgroundColor: background,
            disabledForegroundColor: foreground,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: borderColor, width: 3),
            ),
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
                IconTheme(
                  data: IconThemeData(color: foreground),
                  child: leading!,
                ),
              if (isLoading || leading != null) const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.baloo2(
                    color: foreground,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                IconTheme(
                  data: IconThemeData(color: foreground),
                  child: trailing!,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (expand) {
      return SizedBox(width: double.infinity, child: child);
    }
    return child;
  }
}
