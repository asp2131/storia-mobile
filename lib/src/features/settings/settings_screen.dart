import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/parental_gate.dart';
import '../auth/data/auth_providers.dart';
import '../auth/data/auth_repository.dart';
import '../auth/domain/auth_state.dart';
import '../child/providers/active_child_provider.dart';
import '../onboarding/data/app_review_flow_providers.dart';
import '../reports/domain/report_summary.dart';
import '../reports/providers/report_providers.dart';

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
  bool _isExportingSummary = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProgressSection(context),
          const SizedBox(height: 24),
          _buildLegalSection(context),
          const SizedBox(height: 24),
          _buildAccountSection(context),
        ],
      ),
    );
  }

  Widget _buildProgressSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeChildAsync = ref.watch(activeChildProvider);
    final selectedRange = ref.watch(selectedReportRangeProvider);
    final reportSummaryAsync = ref.watch(reportSummaryProvider);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reading progress',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track reading, comprehension, and practice mode usage for your active child.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh summary',
                  onPressed: () => ref.refresh(reportSummaryProvider),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            activeChildAsync.when(
              data: (child) => child == null
                  ? const _InlineMessage(
                      icon: Icons.child_care_outlined,
                      title: 'No child profile selected',
                      subtitle:
                          'Create or choose a child profile to view reading insights.',
                    )
                  : Row(
                      children: [
                        Icon(
                          Icons.child_friendly_outlined,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${child.displayName} · ${child.ageBand}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
              loading: () => const LinearProgressIndicator(minHeight: 3),
              error: (_, __) => const _InlineMessage(
                icon: Icons.error_outline,
                title: 'Could not load child profile',
                subtitle: 'Try again in a moment.',
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final range in reportRanges)
                  ChoiceChip(
                    label: Text(reportRangeLabel(range)),
                    selected: selectedRange == range,
                    onSelected: (_) =>
                        ref.read(selectedReportRangeProvider.notifier).state =
                            range,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            reportSummaryAsync.when(
              data: (summary) {
                if (summary == null) {
                  return const _InlineMessage(
                    icon: Icons.auto_graph_outlined,
                    title: 'Progress summary will appear here',
                    subtitle:
                        'Once a child profile is active, Storia will show recent reading trends.',
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MetricGrid(summary: summary),
                    const SizedBox(height: 16),
                    _PracticeHighlight(summary: summary),
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      onPressed: _isExportingSummary
                          ? null
                          : () => _exportSummaryCsv(context, summary),
                      icon: _isExportingSummary
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded),
                      label: Text(
                        _isExportingSummary
                            ? 'Preparing CSV…'
                            : 'Export summary CSV',
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _InlineMessage(
                    icon: Icons.signal_wifi_bad_rounded,
                    title: 'Could not load the progress summary',
                    subtitle: 'Check your connection and try again.',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => ref.refresh(reportSummaryProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Legal',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy'),
                subtitle: const Text('storia.kids/privacy-policy'),
                onTap: () => _openPrivacyPolicy(context),
              ),
              const Divider(height: 1),
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
        ),
      ],
    );
  }

  Widget _buildAccountSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Account',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
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
        ),
      ],
    );
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final passed = await ParentalGate.verify(context);
    if (!context.mounted || !passed) return;

    final launched = await launchUrl(
      SettingsScreen._privacyPolicyUri,
      mode: LaunchMode.externalApplication,
    );

    if (!context.mounted || launched) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the privacy policy link.')),
    );
  }

  Future<void> _exportSummaryCsv(
    BuildContext context,
    ReportSummary summary,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final passed = await ParentalGate.verify(context);
    if (!context.mounted || !passed) return;

    final child = ref.read(activeChildProvider).valueOrNull;
    if (child == null) return;
    final range = ref.read(selectedReportRangeProvider);
    setState(() => _isExportingSummary = true);

    try {
      final csv = await ref
          .read(reportRepositoryProvider)
          .exportSummaryCsv(
            childProfileId: summary.childProfileId,
            range: range,
          );
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/storia-reading-summary-${summary.childProfileId}-$range.csv',
      );
      await file.writeAsString(csv);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Storia reading summary for ${child.displayName}',
        subject: 'Storia reading summary',
      );

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Reading summary ready to share.')),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not export the summary right now.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExportingSummary = false);
      }
    }
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
        await repository.signOut();
      }
      await reviewFlowNotifier.clearReviewFlow();
      if (!mounted) {
        return;
      }
      context.go('/intro');
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

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.summary});

  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _MetricCard(
          label: 'Reading minutes',
          value: '${summary.totalReadingMinutes}m',
          icon: Icons.menu_book_rounded,
        ),
        _MetricCard(
          label: 'Sessions',
          value: '${summary.totalSessions}',
          icon: Icons.timer_outlined,
        ),
        _MetricCard(
          label: 'Avg session',
          value: '${summary.averageSessionMinutes}m',
          icon: Icons.speed_rounded,
        ),
        _MetricCard(
          label: 'Books completed',
          value: '${summary.booksCompleted}',
          icon: Icons.task_alt_rounded,
        ),
        _MetricCard(
          label: 'Comprehension',
          value: '${summary.averageComprehensionScore}%',
          icon: Icons.quiz_outlined,
        ),
        _MetricCard(
          label: 'Practice rate',
          value: '${summary.practiceSessionRatePercent}%',
          icon: Icons.mic_external_on_outlined,
        ),
      ],
    );
  }
}

class _PracticeHighlight extends StatelessWidget {
  const _PracticeHighlight({required this.summary});

  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Practice summary',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${summary.practiceSessions} practice sessions · ${summary.practiceMinutes} total minutes · ${summary.practiceSessionRatePercent}% of sessions used practice mode.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              summary.practiceSessions == 0
                  ? 'Try using practice mode during read-aloud time to build confidence with spoken reading.'
                  : 'Practice mode is being used regularly — keep pairing it with comprehension check-ins for a fuller learning picture.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.82),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = (MediaQuery.sizeOf(context).width - 56) / 2;

    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: width.clamp(140, 260)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
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
