import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;

import '../../../core/theme/storia_colors.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../core/widgets/sketch_text_field.dart';
import '../../../routing/journey/journey_actions.dart';
import '../../onboarding/data/app_review_flow_providers.dart';
import '../data/auth_providers.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_screen_shell.dart';
import 'widgets/auth_social_buttons.dart';
import 'widgets/magic_code_field.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSocialSubmitting = false;
  bool _isVerifying = false;

  /// The code field only appears once an email has actually been sent.
  bool _hasSentLink = false;

  String? _errorMessage;
  String? _successMessage;

  bool get _isBusy => _isSubmitting || _isSocialSubmitting || _isVerifying;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Post-auth advancement is owned by the router redirect backstop:
    // authStateNotifierProvider is in the router's refreshListenable, so
    // JourneyPolicy moves the user off this screen the moment auth flips.
    // (A screen-side listener here used to hardcode the library route, skipping
    // the profile-picker gate and causing a visible double hop.)
    final textTheme = Theme.of(context).textTheme;

    return AuthScreenShell(
      title: 'Join the Library',
      subtitle:
          'Create a Loratone parent account with a magic link. No password to remember, no reset flow to babysit.',
      onBack: () => backOutOfJourneyStep(context),
      footer: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Text(
              'Already have a bookmark?',
              style: textTheme.bodyMedium?.copyWith(
                color: StoriaColors.ink.withValues(alpha: 0.9),
              ),
            ),
            TextButton(
              onPressed: () => enterAuth(context, AuthEntry.signIn),
              style: TextButton.styleFrom(foregroundColor: StoriaColors.ink),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SketchTextField(
            controller: _emailController,
            label: "Parent's Email",
            hintText: 'hello@example.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            leading: const Icon(Icons.mail_outline_rounded),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          Text(
            'We will create your parent account and send a secure link to this inbox. Tap it on this device to finish.',
            style: textTheme.bodyMedium?.copyWith(
              color: StoriaColors.ink.withValues(alpha: 0.88),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: textTheme.bodyMedium?.copyWith(color: StoriaColors.danger),
            ),
          ],
          if (_successMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _successMessage!,
              style: textTheme.bodyMedium?.copyWith(
                color: StoriaColors.success,
              ),
            ),
          ],
          const SizedBox(height: 20),
          SketchButton(
            label: _hasSentLink
                ? 'Send Another Link'
                : 'Create Account with Magic Link',
            trailing: const Icon(Icons.arrow_forward_rounded, size: 18),
            isLoading: _isSubmitting,
            onPressed: _isBusy ? null : _submit,
          ),
          if (_hasSentLink)
            MagicCodeField(
              controller: _codeController,
              isVerifying: _isVerifying,
              isBusy: _isBusy,
              onVerify: _verifyCode,
            ),
          AuthSocialButtons(
            isBusy: _isBusy,
            isSocialSubmitting: _isSocialSubmitting,
            onProviderSelected: _startOAuth,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final repository = ref.read(authRepositoryProvider);
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Enter your email address.');
      return;
    }

    if (email.toLowerCase() == appReviewBypassEmail) {
      await _submitAppReviewBypass(email);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await repository.sendMagicLink(email: email, shouldCreateUser: true);
      if (mounted) {
        setState(() {
          _hasSentLink = true;
          _successMessage =
              'Email sent. Tap the link on this device, or enter the 6-digit '
              'code from that email below.';
        });
      }
    } on AppAuthException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Could not send a magic link right now.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _verifyCode() async {
    final repository = ref.read(authRepositoryProvider);
    final email = _emailController.text.trim();
    final code = normalizeMagicCode(_codeController.text);

    if (code.length < 6) {
      setState(() => _errorMessage = 'Enter the 6-digit code from your email.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      // On success the router's auth backstop advances the journey; this screen
      // deliberately does not navigate (see the build() note).
      await repository.verifyEmailCode(
        email: email,
        code: code,
        isSignUp: true,
      );
    } on AppAuthException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = 'That code did not work. Request a new one.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _startOAuth(OAuthProvider provider) async {
    final repository = ref.read(authRepositoryProvider);

    setState(() {
      _isSocialSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      if (provider == OAuthProvider.apple) {
        await repository.signInWithNativeApple();
      } else {
        await repository.signInWithOAuth(provider);
      }
    } on AppAuthException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Could not start the social sign-in flow.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSocialSubmitting = false);
      }
    }
  }

  Future<void> _submitAppReviewBypass(String email) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await ref
          .read(appReviewFlowNotifierProvider)
          .enableReviewBypass(email: email);
      if (!mounted) {
        return;
      }
      continueJourney(ref, context);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not start the App Review flow.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
