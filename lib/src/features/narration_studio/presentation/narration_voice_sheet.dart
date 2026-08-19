import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/storia_colors.dart';
import '../../../data/analytics_repository.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';
import '../application/narration_track_selection.dart';
import '../data/narration_providers.dart';
import '../domain/narration_track.dart';
import 'narration_record_pass.dart';

/// Entry point for everything narration inside the reader.
///
/// Recording is no longer its own screen: the voice list, the first-time
/// coaching, and the "narration is ready" summary are all sheets over the book,
/// and the record pass itself walks the same pages the child sees.
Future<void> showNarrationVoiceSheet(
  BuildContext context, {
  required String bookId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: StoriaColors.paper,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (ctx) => NarrationVoiceSheet(bookId: bookId),
  );
}

/// "Who reads it?" — the book's voices, their status, and the way to add one.
class NarrationVoiceSheet extends ConsumerStatefulWidget {
  const NarrationVoiceSheet({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<NarrationVoiceSheet> createState() =>
      _NarrationVoiceSheetState();
}

class _NarrationVoiceSheetState extends ConsumerState<NarrationVoiceSheet> {
  /// The row the adult has tapped but not confirmed. Selection only commits on
  /// "Use X", so a mis-tap never swaps the voice mid-page.
  String? _pending;
  bool _pendingInitialized = false;

  @override
  Widget build(BuildContext context) {
    final tracksAsync = ref.watch(bookNarrationTracksProvider(widget.bookId));
    final tracks = tracksAsync.value ?? const <NarrationTrack>[];
    final selectedId = ref.watch(
      narrationTrackSelectionProvider(widget.bookId),
    );
    final book = ref.watch(currentBookProvider(widget.bookId)).value;
    final pageCount = _recordablePageCount(book);

    if (!_pendingInitialized) {
      _pendingInitialized = true;
      _pending = selectedId;
    }

    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NarrationSheetGrip(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    'Who reads it?',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: StoriaColors.ink,
                    ),
                  ),
                ),
                if (book != null)
                  Flexible(
                    child: Text(
                      book.title,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: StoriaColors.inkMuted,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "Switch any time — the page you're on keeps its place.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: StoriaColors.inkMuted,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _VoiceRow(
                      initial: 'D',
                      avatarColor: StoriaColors.mustard,
                      name: 'Default Voice',
                      chip: selectedId == null ? 'Main' : 'Ready',
                      isMain: selectedId == null,
                      isComplete: true,
                      subtitle: 'Built-in narrator · English',
                      isPending: _pending == null,
                      onTap: () => setState(() => _pending = null),
                    ),
                    for (final track in tracks)
                      _VoiceRow(
                        initial: _initialOf(track.label),
                        avatarColor: _avatarColorFor(track.id),
                        name: track.label,
                        chip: selectedId == track.id
                            ? 'Main'
                            : (track.isReady ? 'Ready' : 'Draft'),
                        isMain: selectedId == track.id,
                        isComplete: track.isReady,
                        subtitle: _coverage(track, pageCount),
                        isPending: _pending == track.id,
                        // A draft can't be read from yet, but it can be
                        // resumed — the mic button is the way back in.
                        onTap: track.isReady
                            ? () => setState(() => _pending = track.id)
                            : null,
                        onResume: track.isReady
                            ? null
                            : () => unawaited(_record(track)),
                      ),
                    const SizedBox(height: 4),
                    _NewVoiceRow(onTap: () => unawaited(_record(null))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                NarrationSecondaryButton(
                  label: 'Cancel',
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NarrationPrimaryButton(
                    label: _pending == selectedId
                        ? 'Keep reading'
                        : 'Use ${_nameOf(_pending, tracks)}',
                    icon: Icons.check_rounded,
                    onTap: () => _use(selectedId),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _use(String? selectedId) {
    if (_pending != selectedId) {
      unawaited(
        ref
            .read(narrationTrackSelectionProvider(widget.bookId).notifier)
            .select(_pending),
      );
      unawaited(
        ref
            .read(analyticsRepositoryProvider)
            .track(
              AnalyticsEventType.narrationTrackSelected,
              bookId: widget.bookId,
              metadata: {'voice': _pending == null ? 'storia' : 'parent'},
            ),
      );
    }
    Navigator.of(context).pop();
  }

  Future<void> _record(NarrationTrack? resuming) async {
    Navigator.of(context).pop();
    if (!mounted) return;

    await startNarrationRecordPass(
      context,
      bookId: widget.bookId,
      resuming: resuming,
    );
  }

  String _nameOf(String? trackId, List<NarrationTrack> tracks) {
    if (trackId == null) return 'Default Voice';
    for (final track in tracks) {
      if (track.id == trackId) return track.label;
    }
    return 'this voice';
  }

  String _coverage(NarrationTrack track, int pageCount) {
    final done = track.pages.where((p) => p.audioUrl.isNotEmpty).length;
    if (track.isReady) {
      final shaky = track.pages.where((p) => !p.alignment.isReliable).length;
      if (shaky > 0) {
        return 'Your voice · $shaky page${shaky == 1 ? '' : 's'} may highlight out of sync';
      }
      return 'Your voice · all $done pages';
    }
    return 'Your voice · $done of $pageCount pages';
  }
}

int _recordablePageCount(Book? book) {
  if (book == null) return 0;
  return book.pages.where((p) => countRenderedWords(p) > 0).length;
}

String _initialOf(String label) =>
    label.trim().isEmpty ? '?' : label.trim()[0].toUpperCase();

/// Stable per-track tint so a voice keeps the same color between the chip in
/// the reader chrome and its row here.
Color _avatarColorFor(String trackId) {
  const palette = [
    StoriaColors.dustyPink,
    StoriaColors.sage,
    StoriaColors.mustard,
  ];
  return palette[trackId.hashCode.abs() % palette.length];
}

/// The chip that rides above the audio dial: who is reading right now.
class NarrationVoiceChip extends ConsumerWidget {
  const NarrationVoiceChip({super.key, required this.bookId, this.onTap});

  final String bookId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(narrationTrackSelectionProvider(bookId));
    final tracks =
        ref.watch(bookNarrationTracksProvider(bookId)).value ??
        const <NarrationTrack>[];
    final track = resolveSelectedTrack(tracks, selectedId);

    final name = track == null ? 'Default Voice' : "${track.label}'s voice";
    final sub = track == null ? 'BUILT-IN NARRATOR' : 'RECORDED FOR THIS BOOK';
    final color = track == null
        ? StoriaColors.mustard
        : _avatarColorFor(track.id);

    return Semantics(
      button: true,
      label: 'Narrator $name. Opens the voice list.',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(10, 15, 25, 0.55),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color.fromRGBO(255, 255, 255, 0.22),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              NarrationAvatar(
                initial: track == null ? 'D' : _initialOf(track.label),
                color: color,
                size: 32,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(
                      color: Color.fromRGBO(255, 255, 255, 0.62),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: 0.6,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: Color.fromRGBO(255, 255, 255, 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Sheet pieces
// =============================================================================

class NarrationSheetGrip extends StatelessWidget {
  const NarrationSheetGrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 46,
        height: 5,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFD7D7D2),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class NarrationAvatar extends StatelessWidget {
  const NarrationAvatar({
    super.key,
    required this.initial,
    required this.color,
    required this.size,
  });

  final String initial;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        initial,
        style: TextStyle(
          color: StoriaColors.ink,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}

class _VoiceRow extends StatelessWidget {
  const _VoiceRow({
    required this.initial,
    required this.avatarColor,
    required this.name,
    required this.chip,
    required this.isMain,
    required this.isComplete,
    required this.subtitle,
    required this.isPending,
    this.onTap,
    this.onResume,
  });

  final String initial;
  final Color avatarColor;
  final String name;
  final String chip;
  final bool isMain;
  final bool isComplete;
  final String subtitle;
  final bool isPending;
  final VoidCallback? onTap;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) {
    final chipBg = isMain
        ? StoriaColors.mustard
        : (isComplete
              ? const Color.fromRGBO(92, 138, 102, 0.18)
              : const Color.fromRGBO(217, 160, 160, 0.32));
    final chipFg = isMain
        ? StoriaColors.ink
        : (isComplete ? StoriaColors.success : StoriaColors.danger);

    return Semantics(
      selected: isPending,
      button: onTap != null,
      label: 'Narrator $name, $chip. $subtitle',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: StoriaColors.paperRaised,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPending ? StoriaColors.sageDeep : StoriaColors.line,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              NarrationAvatar(initial: initial, color: avatarColor, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: StoriaColors.ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: chipBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            chip.toUpperCase(),
                            style: TextStyle(
                              color: chipFg,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: StoriaColors.inkMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (onResume != null)
                Semantics(
                  button: true,
                  label: 'Continue recording $name',
                  child: GestureDetector(
                    onTap: onResume,
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(left: 8),
                      decoration: const BoxDecoration(
                        color: StoriaColors.mustard,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mic_rounded,
                        size: 20,
                        color: StoriaColors.ink,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPending ? StoriaColors.sageDeep : Colors.transparent,
                  border: Border.all(
                    color: isPending
                        ? StoriaColors.sageDeep
                        : StoriaColors.line,
                    width: 2,
                  ),
                ),
                child: isPending
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewVoiceRow extends StatelessWidget {
  const _NewVoiceRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Record a new voice',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(187, 223, 131, 0.24),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: StoriaColors.sageDeep, width: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: StoriaColors.paper,
                  shape: BoxShape.circle,
                  border: Border.all(color: StoriaColors.line, width: 1.5),
                ),
                child: const Icon(Icons.mic_rounded, color: StoriaColors.ink),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Record a new voice',
                      style: TextStyle(
                        color: StoriaColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Grandma, Dad, a big sister — about 4 minutes.',
                      style: TextStyle(
                        color: StoriaColors.inkMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NarrationPrimaryButton extends StatelessWidget {
  const NarrationPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: onTap == null
                ? StoriaColors.sage.withValues(alpha: 0.5)
                : StoriaColors.sage,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(color: StoriaColors.sageDeep, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: StoriaColors.ink),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: StoriaColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NarrationSecondaryButton extends StatelessWidget {
  const NarrationSecondaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.onDark = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: onDark
                ? const Color.fromRGBO(250, 243, 232, 0.16)
                : StoriaColors.paperRaised,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: onDark
                  ? const Color.fromRGBO(255, 255, 255, 0.4)
                  : StoriaColors.line,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: onDark ? Colors.white : StoriaColors.inkMuted,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
