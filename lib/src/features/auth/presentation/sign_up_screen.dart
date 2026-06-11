import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/storia_colors.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../core/widgets/sketch_text_field.dart';
import '../../../routing/journey/journey_actions.dart';
import '../../onboarding/data/app_review_flow_providers.dart';
import '../data/auth_providers.dart';
import '../data/auth_repository.dart';
import '../domain/auth_state.dart';
import 'widgets/auth_screen_shell.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthViewState>(authViewStateProvider, (previous, next) {
      if (!mounted || !next.isAuthenticated) {
        return;
      }
      final location = GoRouterState.of(context).matchedLocation;
      if (location == '/sign-up' ||
          location == '/sign-in' ||
          location == '/intro') {
        context.go('/library');
      }
    });

    final textTheme = Theme.of(context).textTheme;

    return AuthScreenShell(
      title: 'Join the Library',
      subtitle:
          'Create a Storia parent account with a magic link. No password to remember, no reset flow to babysit.',
      onBack: () => context.go('/intro'),
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
              onPressed: () => context.go('/sign-in'),
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
            label: 'Create Account with Magic Link',
            trailing: const Icon(Icons.arrow_forward_rounded, size: 18),
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submit,
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
          _successMessage =
              'Magic link sent. Check your email and open it on this device to create your account.';
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
