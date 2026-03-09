import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/storia_colors.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../core/widgets/sketch_text_field.dart';
import '../data/auth_providers.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_screen_shell.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AuthScreenShell(
      title: 'Join the Library',
      subtitle:
          'Create a Storia parent account with email and password, or confirm your email if Supabase asks first.',
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
            textInputAction: TextInputAction.next,
            leading: const Icon(Icons.mail_outline_rounded),
          ),
          const SizedBox(height: 16),
          SketchTextField(
            controller: _passwordController,
            label: 'Password',
            hintText: 'Create a password',
            obscureText: true,
            textInputAction: TextInputAction.next,
            leading: const Icon(Icons.lock_outline_rounded),
          ),
          const SizedBox(height: 16),
          SketchTextField(
            controller: _confirmController,
            label: 'Confirm Password',
            hintText: 'Re-enter password',
            obscureText: true,
            textInputAction: TextInputAction.done,
            leading: const Icon(Icons.verified_user_outlined),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          Text(
            'We use a parent account to keep progress, purchases, and reading time organized across devices.',
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
            label: 'Create Account',
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
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _errorMessage = 'Fill in every account field.');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }
    if (password.length < 8) {
      setState(() => _errorMessage = 'Use at least 8 characters.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final response = await repository.signUp(
        email: email,
        password: password,
      );
      if (!mounted) {
        return;
      }
      if (response.session != null) {
        context.go('/library');
      } else {
        setState(() {
          _successMessage =
              'Account created. Check your inbox if email confirmation is required before signing in.';
        });
      }
    } on AppAuthException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Could not create the account right now.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
