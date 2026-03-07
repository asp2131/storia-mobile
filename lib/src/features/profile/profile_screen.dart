import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_providers.dart';
import '../settings/settings_screen.dart';
import 'profile_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static final Uri _privacyPolicyUri = Uri.parse(
    'https://storia.kids/privacy-policy',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final displayName = ref.watch(displayNameProvider);
    final email = ref.watch(userEmailProvider) ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileCard(
            displayName: displayName,
            email: email,
            isDark: isDark,
            onEditName: () => _showEditNameDialog(context, ref),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Legal',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF41315D),
              ),
            ),
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text('Privacy Policy', style: GoogleFonts.inter()),
                  subtitle: Text(
                    'storia.kids/privacy-policy',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  onTap: () => _openPrivacyPolicy(context),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.gavel_outlined),
                  title: Text('Terms of Service', style: GoogleFonts.inter()),
                  subtitle: Text(
                    'View terms used in Storia',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TermsOfServiceScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _signOut(ref),
              icon: const Icon(Icons.logout),
              label: Text('Sign Out', style: GoogleFonts.inter()),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _showEditNameDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final currentName = ref.read(displayNameProvider) ?? '';
    final controller = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Edit Display Name',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Display Name',
            labelStyle: GoogleFonts.inter(),
            border: const OutlineInputBorder(),
          ),
          style: GoogleFonts.inter(),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text('Save', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != currentName) {
      await ref.read(profileRepositoryProvider).updateDisplayName(newName);
      await ref.read(authStateProvider.notifier).checkSession();
    }
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final launched = await launchUrl(
      _privacyPolicyUri,
      mode: LaunchMode.externalApplication,
    );

    if (!context.mounted || launched) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open the privacy policy link.'),
      ),
    );
  }

  Future<void> _signOut(WidgetRef ref) async {
    await ref.read(authStateProvider.notifier).signOut();
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.displayName,
    required this.email,
    required this.isDark,
    required this.onEditName,
  });

  final String? displayName;
  final String email;
  final bool isDark;
  final VoidCallback onEditName;

  String _getInitials(String? name, String email) {
    if (name != null && name.isNotEmpty) {
      return name[0].toUpperCase();
    }
    if (email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(displayName, email);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF2A2040),
                  const Color(0xFF1E2A3A),
                  const Color(0xFF2A2520),
                ]
              : [
                  const Color(0xFFDCEBFF),
                  const Color(0xFFEDE4FF),
                  const Color(0xFFFFF5DD),
                ],
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor:
                isDark ? const Color(0xFF51456E) : const Color(0xFF41315D),
            child: Text(
              initials,
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onEditName,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName ?? 'Set your name',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF41315D),
                            fontStyle: displayName == null
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color:
                            isDark ? Colors.white54 : const Color(0xFF51456E),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : const Color(0xFF51456E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
