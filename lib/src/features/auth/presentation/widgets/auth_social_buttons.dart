import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;

import '../../../../core/theme/loratone_entry_colors.dart';
import '../../../../core/theme/storia_spacing.dart';
import 'story_entry_widgets.dart';

/// Apple / Google buttons above the email field on the account screen.
///
/// These paths avoid the emailed-link failure modes entirely, so they lead.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (supportsApple) ...[
          _SocialButton(
            label: 'Continue with Apple',
            leading: const Icon(Icons.apple_rounded, size: 24),
            dark: true,
            isLoading: isSocialSubmitting,
            onPressed: isBusy
                ? null
                : () => onProviderSelected(OAuthProvider.apple),
          ),
          const SizedBox(height: StoriaSpacing.md),
        ],
        if (supportsGoogle) ...[
          _SocialButton(
            label: 'Continue with Google',
            leading: Text(
              'G',
              style: storyEntryText(size: 18, weight: FontWeight.w900),
            ),
            isLoading: isSocialSubmitting,
            onPressed: isBusy
                ? null
                : () => onProviderSelected(OAuthProvider.google),
          ),
          const SizedBox(height: StoriaSpacing.md),
        ],
        Row(
          children: [
            const Expanded(child: Divider(color: LoratoneEntryColors.line)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: StoriaSpacing.md),
              child: Text(
                dividerLabel,
                style: storyEntryText(
                  size: 15,
                  color: LoratoneEntryColors.inkMuted,
                ),
              ),
            ),
            const Expanded(child: Divider(color: LoratoneEntryColors.line)),
          ],
        ),
        const SizedBox(height: StoriaSpacing.md),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.leading,
    required this.isLoading,
    required this.onPressed,
    this.dark = false,
  });

  final String label;
  final Widget leading;
  final bool isLoading;
  final VoidCallback? onPressed;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final foreground = dark
        ? LoratoneEntryColors.surface
        : LoratoneEntryColors.ink;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: dark
            ? LoratoneEntryColors.ink
            : LoratoneEntryColors.surface,
        foregroundColor: foreground,
        minimumSize: const Size(0, 56),
        shape: const StadiumBorder(),
        side: BorderSide(
          color: dark ? LoratoneEntryColors.ink : LoratoneEntryColors.line,
          width: 1.5,
        ),
        textStyle: storyEntryText(size: 18, weight: FontWeight.w800),
      ),
      child: isLoading
          ? SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: foreground,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconTheme.merge(
                  data: IconThemeData(color: foreground),
                  child: leading,
                ),
                const SizedBox(width: StoriaSpacing.md),
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );
  }
}
