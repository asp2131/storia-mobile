import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/storia_colors.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../core/widgets/sketch_card.dart';
import '../../../core/widgets/watercolor_scaffold.dart';
import 'widgets/intro_hero_illustration.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: StoriaColors.paper,
      body: WatercolorScaffold(
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              const IntroHeroIllustration(),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: SketchCard(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'A Story Awaits',
                        textAlign: TextAlign.center,
                        style: textTheme.displayMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Storia Kids',
                        textAlign: TextAlign.center,
                        style: textTheme.titleLarge?.copyWith(
                          color: const Color.fromARGB(
                            255,
                            0,
                            0,
                            0,
                          ).withValues(alpha: 0.78),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const SizedBox(height: 18),
                      SketchButton(
                        label: 'Open the Library',
                        trailing: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                        ),
                        onPressed: () => context.go('/sign-up'),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => context.go('/sign-in'),
                        child: RichText(
                          text: TextSpan(
                            style: textTheme.bodyMedium?.copyWith(
                              color: StoriaColors.ink.withValues(alpha: 0.6),
                            ),
                            children: const [
                              TextSpan(text: 'Already have a bookmark? '),
                              TextSpan(
                                text: 'Sign in',
                                style: TextStyle(
                                  color: StoriaColors.dustyPinkStrong,
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
