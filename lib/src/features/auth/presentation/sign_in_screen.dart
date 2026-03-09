import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;

import '../../../core/theme/storia_colors.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../core/widgets/sketch_text_field.dart';
import '../data/auth_providers.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_screen_shell.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSocialSubmitting = false;
  String? _errorMessage;

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
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AuthScreenShell(
      title: 'Welcome Back',
      subtitle:
          'Sign in with your Storia parent account to pick up reading where you left off.',
      onBack: () => context.go('/intro'),
      footer: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Text(
              'New to the library?',
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
            textInputAction: TextInputAction.next,
            leading: const Icon(Icons.mail_outline_rounded),
          ),
          const SizedBox(height: 16),
          SketchTextField(
            controller: _passwordController,
            label: 'Password',
            hintText: 'Enter your password',
            obscureText: true,
            textInputAction: TextInputAction.done,
            leading: const Icon(Icons.lock_outline_rounded),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.go('/forgot-password'),
              child: Text(
                'Forgot bookmark?',
                style: TextStyle(
                  color: StoriaColors.ink.withValues(alpha: 0.88),
                ),
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: textTheme.bodyMedium?.copyWith(color: StoriaColors.danger),
            ),
          ],
          const SizedBox(height: 18),
          SketchButton(
            label: 'Continue to the Library',
            trailing: const Icon(Icons.auto_stories_rounded, size: 18),
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
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Enter your email and password.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await repository.signInWithPassword(email: email, password: password);
      if (!mounted) {
        return;
      }
      context.go('/library');
    } on AppAuthException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not sign in right now.');
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
    });

    try {
      await repository.signInWithOAuth(provider);
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
