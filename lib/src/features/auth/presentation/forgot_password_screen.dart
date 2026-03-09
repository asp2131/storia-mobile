import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/storia_colors.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../core/widgets/sketch_text_field.dart';
import '../data/auth_providers.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_screen_shell.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.mode});

  final String? mode;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  bool get _isUpdateMode => widget.mode == 'update';

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
      title: _isUpdateMode ? 'Choose a New Password' : 'Forgot Bookmark?',
      subtitle: _isUpdateMode
          ? 'Your reset link opened a recovery session. Set a new password to get back into the library.'
          : 'Enter your parent email and we will send a reset link back to your storybook.',
      onBack: () => context.go('/sign-in'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isUpdateMode) ...[
            SketchTextField(
              controller: _passwordController,
              label: 'New Password',
              hintText: 'Choose a strong new password',
              obscureText: true,
              textInputAction: TextInputAction.next,
              leading: const Icon(Icons.lock_reset_rounded),
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
          ] else
            SketchTextField(
              controller: _emailController,
              label: "Parent's Email",
              hintText: 'hello@example.com',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              leading: const Icon(Icons.mail_outline_rounded),
              onSubmitted: (_) => _submit(),
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
            label: _isUpdateMode ? 'Save New Password' : 'Send Reset Link',
            trailing: const Icon(Icons.arrow_forward_rounded, size: 18),
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submit,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go('/sign-in'),
            child: Text(
              _isUpdateMode ? 'Back to sign in' : 'Remembered it? Sign in',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final repository = ref.read(authRepositoryProvider);
    final notifier = ref.read(authStateNotifierProvider);

    if (_isUpdateMode) {
      final password = _passwordController.text;
      final confirm = _confirmController.text;
      if (password.isEmpty || confirm.isEmpty) {
        setState(() => _errorMessage = 'Enter and confirm your new password.');
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
        await repository.updatePassword(password);
        notifier.clearRecoveryMode();
        if (!mounted) {
          return;
        }
        context.go('/sign-in');
      } on AppAuthException catch (error) {
        if (mounted) {
          setState(() => _errorMessage = error.message);
        }
      } catch (_) {
        if (mounted) {
          setState(() => _errorMessage = 'Could not update the password.');
        }
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
      return;
    }

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Enter your account email.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await repository.sendPasswordReset(email);
      if (mounted) {
        setState(() {
          _successMessage =
              'Reset instructions are on the way if that email is in the library.';
        });
      }
    } on AppAuthException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not send the reset email.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
