import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/loratone_entry_colors.dart';
import '../../../core/theme/storia_spacing.dart';
import '../../../core/widgets/parental_gate.dart';
import '../../../routing/journey/journey_actions.dart';
import '../../onboarding/data/app_review_flow_providers.dart';
import '../../onboarding/data/entry_flow_provider.dart';
import '../../settings/settings_screen.dart' show TermsOfServiceScreen;
import '../data/auth_providers.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_social_buttons.dart';
import 'widgets/story_entry_widgets.dart';

/// One path for new and returning parents — no sign-in/sign-up toggle.
///
/// Supabase OTP with `shouldCreateUser: true` signs in an existing account and
/// creates a missing one, so both `/sign-in` and `/sign-up` render this screen.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  static final _privacyPolicyUri = Uri.parse(
    'https://storia.kids/privacy-policy',
  );

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSocialSubmitting = false;
  bool _isVerifying = false;

  /// Swaps the email step for the code step once an email has been sent.
  bool _hasSentCode = false;

  String? _errorMessage;

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
    return Scaffold(
      backgroundColor: LoratoneEntryColors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    StoriaSpacing.md,
                    StoriaSpacing.md,
                    StoriaSpacing.xl,
                    0,
                  ),
                  child: TextButton.icon(
                    onPressed: _isBusy
                        ? null
                        : _hasSentCode
                        ? () => setState(() {
                            _hasSentCode = false;
                            _errorMessage = null;
                          })
                        : () => backOutOfJourneyStep(context),
                    style: TextButton.styleFrom(
                      foregroundColor: LoratoneEntryColors.blue,
                      minimumSize: const Size(44, 48),
                      textStyle: storyEntryText(
                        size: 17,
                        weight: FontWeight.w800,
                      ),
                    ),
                    icon: const Icon(Icons.chevron_left_rounded, size: 24),
                    label: const Text('Back'),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      StoriaSpacing.xl,
                      StoriaSpacing.xl,
                      StoriaSpacing.xl,
                      StoriaSpacing.xl,
                    ),
                    child: _hasSentCode ? _codeStep() : _emailStep(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    StoriaSpacing.xl,
                    0,
                    StoriaSpacing.xl,
                    StoriaSpacing.lg,
                  ),
                  child: _termsFooter(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emailStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _Heading(
        title: 'Create an account or sign in',
        subtitle: 'Same steps for both. No password.',
      ),
      const SizedBox(height: StoriaSpacing.xl),
      AuthSocialButtons(
        isBusy: _isBusy,
        isSocialSubmitting: _isSocialSubmitting,
        onProviderSelected: _startOAuth,
      ),
      StoryEntryTextField(
        controller: _emailController,
        hintText: 'you@email.com',
        semanticLabel: "Parent's email",
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        onSubmitted: (_) => _submit(),
      ),
      _error(),
      const SizedBox(height: StoriaSpacing.lg),
      StoryEntryButton(
        label: _isSubmitting ? 'Sending…' : 'Email me a code',
        onPressed: _isBusy ? null : _submit,
      ),
    ],
  );

  Widget _codeStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Heading(
        title: 'Check your email',
        subtitle:
            'We sent a code to ${_emailController.text.trim()}. Type it here, '
            'or tap the link in that email on this device.',
      ),
      const SizedBox(height: StoriaSpacing.xl),
      StoryEntryTextField(
        controller: _codeController,
        hintText: '6-digit code',
        semanticLabel: 'Code from email',
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        textAlign: TextAlign.center,
        letterSpacing: 8,
        onSubmitted: (_) => _verifyCode(),
      ),
      _error(),
      const SizedBox(height: StoriaSpacing.lg),
      StoryEntryButton(
        label: _isVerifying ? 'Checking…' : 'Check code',
        onPressed: _isBusy ? null : _verifyCode,
      ),
      const SizedBox(height: StoriaSpacing.sm),
      TextButton(
        onPressed: _isBusy ? null : _submit,
        style: TextButton.styleFrom(
          foregroundColor: LoratoneEntryColors.blue,
          minimumSize: const Size(44, 48),
          textStyle: storyEntryText(size: 16, weight: FontWeight.w800),
        ),
        child: Text(_isSubmitting ? 'Sending…' : 'Send a new code'),
      ),
    ],
  );

  Widget _error() => _errorMessage == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: StoriaSpacing.md),
          child: Text(
            _errorMessage!,
            style: storyEntryText(size: 15, color: LoratoneEntryColors.coral),
          ),
        );

  Widget _termsFooter() {
    final linkStyle = storyEntryText(
      size: 13,
      color: LoratoneEntryColors.blue,
    ).copyWith(decoration: TextDecoration.underline);
    return Text.rich(
      TextSpan(
        style: storyEntryText(size: 13, color: LoratoneEntryColors.inkMuted),
        children: [
          const TextSpan(text: 'By continuing you agree to our '),
          TextSpan(
            text: 'Terms',
            style: linkStyle,
            recognizer: TapGestureRecognizer()..onTap = _openTerms,
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: linkStyle,
            recognizer: TapGestureRecognizer()..onTap = _openPrivacyPolicy,
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  void _openTerms() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const TermsOfServiceScreen()));

  /// Kids Category: links that leave the app sit behind the parental gate.
  Future<void> _openPrivacyPolicy() async {
    final passed = await ParentalGate.verify(context);
    if (!passed) return;
    await launchUrl(_privacyPolicyUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _submit() async {
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
    });

    // Keeps a passed parent gate alive while the parent checks their inbox.
    final entry = ref.read(entryFlowNotifierProvider)..beginAuthRoundTrip();
    try {
      await ref
          .read(authRepositoryProvider)
          .sendMagicLink(email: email, shouldCreateUser: true);
      if (mounted) setState(() => _hasSentCode = true);
    } on AppAuthException catch (error) {
      entry.endAuthRoundTrip();
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      entry.endAuthRoundTrip();
      if (mounted) {
        setState(() => _errorMessage = 'Could not send a code right now.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _verifyCode() async {
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
      await ref
          .read(authRepositoryProvider)
          .verifyEmailCode(
            email: _emailController.text.trim(),
            code: code,
            isSignUp: true,
          );
      ref.read(entryFlowNotifierProvider).endAuthRoundTrip();
    } on AppAuthException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = 'That code did not work. Send a new one.',
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _startOAuth(OAuthProvider provider) async {
    final repository = ref.read(authRepositoryProvider);

    setState(() {
      _isSocialSubmitting = true;
      _errorMessage = null;
    });

    final entry = ref.read(entryFlowNotifierProvider)..beginAuthRoundTrip();
    try {
      if (provider == OAuthProvider.apple) {
        await repository.signInWithNativeApple();
      } else {
        await repository.signInWithOAuth(provider);
      }
    } on AppAuthException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not start that sign-in.');
      }
    } finally {
      entry.endAuthRoundTrip();
      if (mounted) setState(() => _isSocialSubmitting = false);
    }
  }

  Future<void> _submitAppReviewBypass(String email) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(appReviewFlowNotifierProvider)
          .enableReviewBypass(email: email);
      if (!mounted) return;
      continueJourney(ref, context);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not start the App Review flow.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: storyEntryText(size: 30, weight: FontWeight.w900, height: 1.1),
      ),
      const SizedBox(height: StoriaSpacing.sm),
      Text(
        subtitle,
        style: storyEntryText(size: 17, color: LoratoneEntryColors.inkMuted),
      ),
    ],
  );
}

/// Keeps only digits and caps length, so a code pasted with spaces or a stray
/// character still verifies.
String normalizeMagicCode(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  return digits.length > 6 ? digits.substring(0, 6) : digits;
}
