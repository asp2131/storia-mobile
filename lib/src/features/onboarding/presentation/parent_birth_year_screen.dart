import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/storia_colors.dart';
import '../../../core/widgets/parental_gate.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../core/widgets/sketch_card.dart';
import '../../../core/widgets/sketch_icon_button.dart';
import '../../../core/widgets/watercolor_scaffold.dart';
import '../../../routing/journey/journey_actions.dart';
import '../data/app_review_flow_providers.dart';

class ParentBirthYearScreen extends ConsumerStatefulWidget {
  const ParentBirthYearScreen({super.key});

  @override
  ConsumerState<ParentBirthYearScreen> createState() =>
      _ParentBirthYearScreenState();
}

class _ParentBirthYearScreenState extends ConsumerState<ParentBirthYearScreen> {
  static final _random = Random();

  final _challengeController = TextEditingController();
  final _challengeFocusNode = FocusNode();
  final _yearController = TextEditingController();
  final _yearFocusNode = FocusNode();

  Timer? _ticker;
  bool _gatePassed = false;
  bool _isSubmitting = false;
  String? _challengeError;
  String? _yearError;

  late int _answer;
  late String _question;

  int _solveSecondsLeft = ParentalGate.solveSeconds;
  bool _isLockedOut = false;
  int _lockoutSecondsLeft = 0;

  @override
  void initState() {
    super.initState();
    if (GateLockout.isLocked) {
      _isLockedOut = true;
      _lockoutSecondsLeft = GateLockout.remainingSeconds;
    } else {
      _solveSecondsLeft = ParentalGate.solveSeconds;
    }
    _regenerateChallenge();
    _startTicker();
  }

  void _regenerateChallenge() {
    final challenge = generateGateChallenge(_random);
    _answer = challenge.answer;
    _question = challenge.question;
    _challengeController.clear();
    _challengeError = null;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_gatePassed) return;
      setState(() {
        if (_isLockedOut) {
          _lockoutSecondsLeft--;
          if (_lockoutSecondsLeft <= 0) {
            _isLockedOut = false;
            _regenerateChallenge();
            _solveSecondsLeft = ParentalGate.solveSeconds;
          }
        } else {
          _solveSecondsLeft--;
          if (_solveSecondsLeft <= 0) {
            _onChallengeFailure();
          }
        }
      });
    });
  }

  void _onChallengeFailure() {
    GateLockout.recordFailure();
    _isLockedOut = true;
    _lockoutSecondsLeft = GateLockout.remainingSeconds;
    _challengeError = null;
    _challengeController.clear();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _challengeController.dispose();
    _challengeFocusNode.dispose();
    _yearController.dispose();
    _yearFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: StoriaColors.paper,
      body: WatercolorScaffold(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              children: [
                Row(
                  children: [
                    SketchIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onPressed: _startOver,
                      tooltip: 'Go back',
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: _gatePassed
                          ? _buildBirthYearStep(textTheme)
                          : _isLockedOut
                              ? _buildLockoutStep(textTheme)
                              : _buildChallengeStep(textTheme),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeStep(TextTheme textTheme) {
    final timerColor = _solveSecondsLeft <= 10
        ? const Color(0xFFFFB4B4)
        : StoriaColors.paper.withValues(alpha: 0.7);

    return SketchCard(
      color: const Color(0xFF2C3358),
      borderColor: const Color(0xFF1E2445),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _ParentsOnlyArt(),
          const SizedBox(height: 18),
          Text(
            'Parents only',
            textAlign: TextAlign.center,
            style: textTheme.headlineMedium?.copyWith(
              color: StoriaColors.paper,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatCountdown(_solveSecondsLeft),
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              color: timerColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _question,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(
                color: StoriaColors.paper.withValues(alpha: 0.95),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 140,
            child: TextField(
              controller: _challengeController,
              focusNode: _challengeFocusNode,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                color: StoriaColors.ink,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                hintText: '???',
                hintStyle: textTheme.headlineSmall?.copyWith(
                  color: StoriaColors.ink.withValues(alpha: 0.3),
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              onChanged: (_) {
                if (_challengeError != null) {
                  setState(() => _challengeError = null);
                }
              },
              onSubmitted: (_) => _submitChallenge(),
            ),
          ),
          if (_challengeError != null) ...[
            const SizedBox(height: 14),
            Text(
              _challengeError!,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFFFD4D4),
              ),
            ),
          ],
          const SizedBox(height: 22),
          SketchButton(
            label: 'Continue',
            expand: false,
            onPressed: _submitChallenge,
          ),
        ],
      ),
    );
  }

  Widget _buildLockoutStep(TextTheme textTheme) {
    return SketchCard(
      color: const Color(0xFF2C3358),
      borderColor: const Color(0xFF1E2445),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFFAF3E8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_clock_rounded,
              color: StoriaColors.ink,
              size: 28,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Please wait',
            textAlign: TextAlign.center,
            style: textTheme.headlineMedium?.copyWith(
              color: StoriaColors.paper,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Please try again in',
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(
              color: StoriaColors.paper.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatCountdown(_lockoutSecondsLeft),
            textAlign: TextAlign.center,
            style: textTheme.displaySmall?.copyWith(
              color: StoriaColors.paper,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBirthYearStep(TextTheme textTheme) {
    final digits = _yearController.text;

    return SketchCard(
      color: const Color(0xFF2C3358),
      borderColor: const Color(0xFF1E2445),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _ParentsOnlyArt(),
          const SizedBox(height: 18),
          Text(
            'Almost there',
            textAlign: TextAlign.center,
            style: textTheme.headlineMedium?.copyWith(
              color: StoriaColors.paper,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Please enter your year of birth.',
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(
              color: StoriaColors.paper.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 44,
            child: Stack(
              children: [
                Align(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List<Widget>.generate(4, (index) {
                      final char =
                          index < digits.length ? digits[index] : '';
                      return _YearDigitSlot(value: char);
                    }),
                  ),
                ),
                Positioned.fill(
                  child: TextField(
                    controller: _yearController,
                    focusNode: _yearFocusNode,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    maxLength: 4,
                    style: const TextStyle(
                      color: Colors.transparent,
                      fontSize: 1,
                    ),
                    cursorColor: Colors.transparent,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    onChanged: (_) => setState(() => _yearError = null),
                    onSubmitted: (_) => _submitBirthYear(),
                  ),
                ),
              ],
            ),
          ),
          if (_yearError != null) ...[
            const SizedBox(height: 14),
            Text(
              _yearError!,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFFFD4D4),
              ),
            ),
          ],
          const SizedBox(height: 22),
          SketchButton(
            label: 'Continue',
            expand: false,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submitBirthYear,
          ),
        ],
      ),
    );
  }

  void _submitChallenge() {
    final input = int.tryParse(_challengeController.text.trim());
    if (input == null) {
      setState(() => _challengeError = 'Please enter a number.');
      return;
    }

    if (input == _answer) {
      GateLockout.recordSuccess();
      setState(() {
        _gatePassed = true;
        _challengeError = null;
      });
      return;
    }

    setState(() => _onChallengeFailure());
  }

  Future<void> _submitBirthYear() async {
    final rawYear = _yearController.text.trim();
    final year = int.tryParse(rawYear);
    final latestAllowedYear = DateTime.now().year - 18;

    if (rawYear.length != 4 || year == null) {
      setState(() {
        _yearError = 'Enter all 4 digits of your birth year.';
      });
      return;
    }

    if (year < 1930 || year > latestAllowedYear) {
      setState(() {
        _yearError = 'Enter a valid parent birth year.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _yearError = null;
    });

    try {
      await ref.read(appReviewFlowNotifierProvider).saveParentBirthYear(year);
      if (!mounted) {
        return;
      }
      continueJourney(ref, context);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _yearError = 'Could not save your birth year right now.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _startOver() => restartJourney(ref, context);
}

class _ParentsOnlyArt extends StatelessWidget {
  const _ParentsOnlyArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 10,
            top: 12,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFFFAF3E8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.family_restroom_rounded,
                color: StoriaColors.ink,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _YearDigitSlot extends StatelessWidget {
  const _YearDigitSlot({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: 44,
      child: Column(
        children: [
          SizedBox(
            height: 34,
            child: Center(
              child: Text(
                value,
                style: textTheme.headlineMedium?.copyWith(
                  color: StoriaColors.paper,
                ),
              ),
            ),
          ),
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: StoriaColors.paper.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}
