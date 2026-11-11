import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/widgets/sketch_button.dart';
import '../../core/widgets/sketch_card.dart';
import '../../data/analytics_repository.dart';
import '../../data/providers.dart';

const _kParentPulseKey = 'parent_pulse_answer';

/// One-question parent pulse behind the "parents report their child is more
/// interested in reading" KPI. Shown until answered once; the answer is kept
/// locally and sent as a `parent_pulse_answered` analytics event.
class ParentPulseCard extends ConsumerStatefulWidget {
  const ParentPulseCard({super.key});

  @override
  ConsumerState<ParentPulseCard> createState() => _ParentPulseCardState();
}

class _ParentPulseCardState extends ConsumerState<ParentPulseCard> {
  String? _answer;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _answer = prefs.getString(_kParentPulseKey);
      _loaded = true;
    });
  }

  Future<void> _answerWith(String answer) async {
    setState(() => _answer = answer);
    unawaited(
      ref
          .read(analyticsRepositoryProvider)
          .track(
            AnalyticsEventType.parentPulseAnswered,
            metadata: {'answer': answer},
          ),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kParentPulseKey, answer);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    if (_answer != null) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text('Thanks for telling us how reading is going.'),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SketchCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Since using Loratone, is your child more interested in reading?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SketchButton(
                  label: 'More',
                  onPressed: () => _answerWith('more'),
                ),
                SketchButton(
                  label: 'About the same',
                  onPressed: () => _answerWith('same'),
                ),
                SketchButton(
                  label: 'Less',
                  onPressed: () => _answerWith('less'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
