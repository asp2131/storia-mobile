import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;

import '../../../../core/theme/storia_colors.dart';
import '../../../../core/widgets/sketch_button.dart';

/// Apple / Google sign-in block shared by the sign-in and sign-up screens.
///
/// Both screens offer the same providers: an account created with Apple is the
/// same account whether the user arrived via "sign in" or "sign up", and these
/// paths avoid the emailed-link failure modes entirely.
class AuthSocialButtons extends StatelessWidget {
  const AuthSocialButtons({
    super.key,
    required this.isBusy,
    required this.isSocialSubmitting,
    required this.onProviderSelected,
    this.dividerLabel = 'or',
  });

  /// Any auth request in flight — disables the buttons.
  final bool isBusy;

  /// A social request specifically, which also drives the spinner.
  final bool isSocialSubmitting;

  final ValueChanged<OAuthProvider> onProviderSelected;
  final String dividerLabel;

  /// Apple's guidelines require Sign in with Apple on Apple platforms; it is
  /// unavailable elsewhere.
  static bool get supportsApple {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// Google is offered everywhere except iOS, where Apple is the native path.
  static bool get supportsGoogle {
    if (kIsWeb) return true;
    return defaultTargetPlatform != TargetPlatform.iOS;
  }

  @override
  Widget build(BuildContext context) {
    if (!supportsApple && !supportsGoogle) {
      return const SizedBox.shrink();
    }

    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Divider(color: StoriaColors.ink.withValues(alpha: 0.18)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                dividerLabel,
                style: textTheme.bodySmall?.copyWith(
                  color: StoriaColors.ink.withValues(alpha: 0.58),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Divider(color: StoriaColors.ink.withValues(alpha: 0.18)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (supportsGoogle)
          SketchButton(
            label: 'Continue with Google',
            tone: SketchButtonTone.secondary,
            leading: const Icon(Icons.g_mobiledata_rounded, size: 24),
            isLoading: isSocialSubmitting,
            onPressed: isBusy
                ? null
                : () => onProviderSelected(OAuthProvider.google),
          ),
        if (supportsApple) ...[
          const SizedBox(height: 12),
          SketchButton(
            label: 'Continue with Apple',
            tone: SketchButtonTone.secondary,
            leading: const Icon(Icons.apple_rounded, size: 18),
            isLoading: isSocialSubmitting,
            onPressed: isBusy
                ? null
                : () => onProviderSelected(OAuthProvider.apple),
          ),
        ],
      ],
    );
  }
}
