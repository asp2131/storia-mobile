import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/parental_gate.dart';
import '../auth/data/auth_providers.dart';
import '../auth/data/auth_repository.dart';
import '../auth/domain/auth_state.dart';
import '../child/data/child_profile_providers.dart';
import '../gen_ui/data/gen_ui_providers.dart';
import '../gen_ui/presentation/parent_insight_cards.dart';
import '../onboarding/data/app_review_flow_providers.dart';
import '../../routing/journey/journey_policy.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  static final Uri _privacyPolicyUri = Uri.parse(
    'https://storia.kids/privacy-policy',
  );

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isSigningOut = false;

  @override
  Widget build(BuildContext context) {
    final activeProfile = ref.watch(activeChildProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ParentInsightCards(
            log: ref.watch(genUiActivityControllerProvider),
            profileName: activeProfile.maybeWhen(
              data: (profile) => profile?.displayName ?? 'Your reader',
              orElse: () => 'Your reader',
            ),
          ),
          const Divider(height: 32),
          const ListTile(
            title: Text('Reader'),
            subtitle: Text('Child profile used for progress and analytics'),
          ),
          ListTile(
            leading: const Icon(Icons.child_care_rounded),
            title: const Text('Active Reader'),
            subtitle: Text(
              activeProfile.when(
                data: (profile) => profile?.displayName ?? 'Choose a reader',
                loading: () => 'Loading reader…',
                error: (_, _) => 'Could not load reader',
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(JourneyRoutes.profilePicker),
          ),
          const Divider(height: 32),
          const ListTile(
            title: Text('Legal'),
            subtitle: Text('Privacy and terms'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            subtitle: const Text('storia.kids/privacy-policy'),
            onTap: () => _openPrivacyPolicy(context),
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('Terms of Service'),
            subtitle: const Text('View terms used in Loratone'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TermsOfServiceScreen(),
              ),
            ),
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Sign Out'),
            subtitle: const Text('Leave this device and return to sign in'),
            textColor: Theme.of(context).colorScheme.error,
            iconColor: Theme.of(context).colorScheme.error,
            trailing: _isSigningOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _isSigningOut ? null : _signOut,
          ),
        ],
      ),
    );
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final passed = await ParentalGate.verify(context);
    if (!context.mounted || !passed) return;

    final launched = await launchUrl(
      SettingsScreen._privacyPolicyUri,
      mode: .externalApplication,
    );

    if (!context.mounted || launched) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the privacy policy link.')),
    );
  }

  Future<void> _signOut() async {
    final passed = await ParentalGate.verify(context);
    if (!mounted || !passed) return;

    final repository = ref.read(authRepositoryProvider);
    final authState = ref.read<AuthViewState>(authViewStateProvider);
    final reviewFlowNotifier = ref.read(appReviewFlowNotifierProvider);

    setState(() => _isSigningOut = true);

    try {
      if (authState.isAuthenticated) {
        await ref
            .read(activeChildProfileIdStateProvider.notifier)
            .setActiveChildProfileId(null);
        await repository.signOut();
      }
      await reviewFlowNotifier.clearReviewFlow();
      if (!mounted) {
        return;
      }
      context.go(JourneyRoutes.intro);
    } on AppAuthException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sign out right now.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurface,
      height: 1.5,
    );

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(title: const Text('Terms of Service')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Text(
                  'By using Loratone, you agree to use the app for personal, non-commercial reading and learning.',
                  style: bodyStyle,
                ),
                const SizedBox(height: 12),
                Text(
                  'Do not misuse the service, and ensure child accounts are used with parent or guardian oversight where required.',
                  style: bodyStyle,
                ),
                const SizedBox(height: 12),
                Text(
                  'Loratone content and branding are protected by applicable intellectual property laws.',
                  style: bodyStyle,
                ),
                const SizedBox(height: 12),
                Text(
                  'For legal questions, contact support through official Loratone channels.',
                  style: bodyStyle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
