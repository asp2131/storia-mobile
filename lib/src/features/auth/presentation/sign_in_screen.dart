import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;

import '../../../core/theme/storia_colors.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../core/widgets/sketch_text_field.dart';
import 'widgets/auth_screen_shell.dart';
import '../data/auth_providers.dart';
import '../data/auth_repository.dart';
import '../domain/auth_state.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSocialSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  bool get _supportsAppleSignIn {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

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
      if (location == '/sign-in' ||
          location == '/sign-up' ||
          location == '/intro') {
        context.go('/library');
      }
    });

    final textTheme = Theme.of(context).textTheme;

    return AuthScreenShell(
      title: 'Welcome Back',
      subtitle:
          'Skip the password. Enter your email and we will send a magic link to open Storia securely.',
      onBack: () => context.go('/intro'),
      footer: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Text(
              'Need a new account?',
              style: textTheme.bodyMedium?.copyWith(
                color: StoriaColors.ink.withValues(alpha: 0.9),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/sign-up'),
              style: TextButton.styleFrom(foregroundColor: StoriaColors.ink),
              child: const Text('Create account'),
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
            'We will email a secure sign-in link. Open it on this device and Storia will bring you straight into the library.',
            style: textTheme.bodyMedium?.copyWith(
              color: StoriaColors.ink.withValues(alpha: 0.84),
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
          const SizedBox(height: 18),
          SketchButton(
            label: 'Email Me a Magic Link',
            trailing: const Icon(Icons.mark_email_read_outlined, size: 18),
            isLoading: _isSubmitting,
            onPressed: (_isSubmitting || _isSocialSubmitting) ? null : _submit,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Divider(color: StoriaColors.ink.withValues(alpha: 0.18)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or',
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
          SketchButton(
            label: 'Continue with Google',
            tone: SketchButtonTone.secondary,
            leading: const Icon(Icons.g_mobiledata_rounded, size: 24),
            isLoading: _isSocialSubmitting,
            onPressed: (_isSubmitting || _isSocialSubmitting)
                ? null
                : () => _startOAuth(OAuthProvider.google),
          ),
          if (_supportsAppleSignIn) ...[
            const SizedBox(height: 12),
            SketchButton(
              label: 'Continue with Apple',
              tone: SketchButtonTone.secondary,
              leading: const Icon(Icons.apple_rounded, size: 18),
              isLoading: _isSocialSubmitting,
              onPressed: (_isSubmitting || _isSocialSubmitting)
                  ? null
                  : () => _startOAuth(OAuthProvider.apple),
            ),
          ],
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

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await repository.sendMagicLink(email: email, shouldCreateUser: false);
      if (mounted) {
        setState(() {
          _successMessage =
              'Magic link sent. Check your email and open the link on this device.';
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
}
