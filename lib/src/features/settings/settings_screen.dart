import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static final Uri _privacyPolicyUri = Uri.parse(
    'https://storia.kids/privacy-policy',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
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
            subtitle: const Text('View terms used in Storia'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TermsOfServiceScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final launched = await launchUrl(
      _privacyPolicyUri,
      mode: .externalApplication,
    );

    if (!context.mounted || launched) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the privacy policy link.')),
    );
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
                  'By using Storia, you agree to use the app for personal, non-commercial reading and learning.',
                  style: bodyStyle,
                ),
                const SizedBox(height: 12),
                Text(
                  'Do not misuse the service, and ensure child accounts are used with parent or guardian oversight where required.',
                  style: bodyStyle,
                ),
                const SizedBox(height: 12),
                Text(
                  'Storia content and branding are protected by applicable intellectual property laws.',
                  style: bodyStyle,
                ),
                const SizedBox(height: 12),
                Text(
                  'For legal questions, contact support through official Storia channels.',
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
