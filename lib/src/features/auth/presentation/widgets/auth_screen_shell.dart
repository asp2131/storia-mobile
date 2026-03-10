import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/storia_colors.dart';
import '../../../../core/widgets/leaf_accent.dart';
import '../../../../core/widgets/parent_safety_box.dart';
import '../../../../core/widgets/sketch_icon_button.dart';
import '../../../../core/widgets/watercolor_scaffold.dart';

class AuthScreenShell extends StatelessWidget {
  const AuthScreenShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onBack,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onBack;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final lightTheme = buildAppTheme(brightness: Brightness.light);

    return Theme(
      data: lightTheme,
      child: Builder(
        builder: (context) {
          final textTheme = Theme.of(context).textTheme;
          final topPadding = MediaQuery.paddingOf(context).top;

          return Scaffold(
            backgroundColor: StoriaColors.paper,
            body: WatercolorScaffold(
              child: SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    topPadding > 0 ? 4 : 20,
                    24,
                    28,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          MediaQuery.sizeOf(context).height - topPadding - 28,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (onBack != null)
                              SketchIconButton(
                                icon: Icons.arrow_back_ios_new_rounded,
                                onPressed: onBack,
                                tooltip: 'Go back',
                              )
                            else
                              const SizedBox(width: 46),
                            const Spacer(),
                            Text(
                              'Storia Kids',
                              style: textTheme.titleMedium?.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(width: 46),
                          ],
                        ),
                        const SizedBox(height: 28),
                        const Align(
                          alignment: Alignment.topRight,
                          child: Opacity(
                            opacity: 0.82,
                            child: LeafAccent(size: 46),
                          ),
                        ),
                        Text(title, style: textTheme.displayMedium),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: textTheme.bodyLarge?.copyWith(
                            color: StoriaColors.ink.withValues(alpha: 0.72),
                          ),
                        ),
                        const SizedBox(height: 28),
                        child,
                        const SizedBox(height: 22),
                        if (footer != null) footer!,
                        const SizedBox(height: 22),
                        const ParentSafetyBox(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
