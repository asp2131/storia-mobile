import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/theme/storia_colors.dart';
import '../../../core/widgets/sketch_text_field.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';
import '../application/narration_recorder.dart';
import '../application/narration_track_selection.dart';
import '../application/recording_controller.dart';
import '../data/narration_providers.dart';
import '../domain/narration_track.dart';
import 'narration_voice_sheet.dart';

/// Opens the parent's record pass over the book.
///
/// Not a router destination on purpose: recording is a mode of the reader, and
/// leaving it must land the adult back on the page they came from.
Future<void> startNarrationRecordPass(
  BuildContext context, {
  required String bookId,
  NarrationTrack? resuming,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          NarrationRecordPass(bookId: bookId, resumingTrack: resuming),
    ),
  );
}

class NarrationRecordPass extends ConsumerStatefulWidget {
  const NarrationRecordPass({
    super.key,
    required this.bookId,
    this.resumingTrack,
  });

  final String bookId;
  final NarrationTrack? resumingTrack;

  @override
  ConsumerState<NarrationRecordPass> createState() =>
      _NarrationRecordPassState();
}

class _NarrationRecordPassState extends ConsumerState<NarrationRecordPass> {
  NarrationStudioController? _controller;
  final AudioPlayer _player = AudioPlayer();

  /// Path currently loaded into [_player], so a redo reloads the new take
  /// instead of replaying the discarded one.
  String? _loadedTakePath;
  final TextEditingController _labelController = TextEditingController();

  List<PageData> _pages = const [];
  int _activeIndex = 0;

  /// Live capture timer. The recorder owns the audio; this only drives the
  /// "Recording · 0:12" readout so the adult knows it is running.
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;
  bool _coachShown = false;

  @override
  void initState() {
    super.initState();
    _labelController.text = widget.resumingTrack?.label ?? '';
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _controller?.dispose();
    _player.dispose();
    _labelController.dispose();
    super.dispose();
  }

  String get _label {
    final typed = _labelController.text.trim();
    return typed.isEmpty ? 'My voice' : typed;
  }

  void _ensureController(Book book) {
    if (_controller != null) return;

    _pages = book.pages;
    final recordable = <int>[];
    final textless = <int>[];
    for (final page in book.pages) {
      (countRenderedWords(page) > 0 ? recordable : textless).add(
        page.pageNumber,
      );
    }

    _controller = NarrationStudioController(
      repository: ref.read(narrationRepositoryProvider),
      recorder: RecordNarrationRecorder(),
      bookId: widget.bookId,
      recordablePageNumbers: recordable,
      textlessPageNumbers: textless,
      existingTrack: widget.resumingTrack,
      analytics: ref.read(analyticsRepositoryProvider),
    );

    // Resume where the draft stopped rather than at page 1.
    _activeIndex = _firstUnrecordedIndex();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_coachShown) unawaited(_showCoach());
    });
  }

  int _firstUnrecordedIndex() {
    final state = _controller!.value;
    for (var i = 0; i < _pages.length; i++) {
      final page = state.pageAt(_pages[i].pageNumber);
      if (page?.status == PageRecordingStatus.notRecorded) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(currentBookProvider(widget.bookId));

    return Scaffold(
      backgroundColor: StoriaColors.readerBackground,
      body: bookAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Message('Could not open this book:\n$error'),
        data: (book) {
          if (book == null || book.pages.isEmpty) {
            return const _Message('This book has no pages yet.');
          }
          _ensureController(book);

          return ValueListenableBuilder<NarrationStudioState>(
            valueListenable: _controller!,
            builder: (context, state, _) => _buildPass(book, state),
          );
        },
      ),
    );
  }

  Widget _buildPass(Book book, NarrationStudioState state) {
    final page = _pages[_activeIndex.clamp(0, _pages.length - 1)];
    final pageState = state.pageAt(page.pageNumber);
    final status = pageState?.status ?? PageRecordingStatus.notRecorded;
    final imageUrl = page.compositedImageUrl ?? page.imageUrl;

    return Stack(
      children: [
        if (imageUrl != null && imageUrl.isNotEmpty)
          Positioned.fill(
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        const Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.fromRGBO(8, 12, 17, 0.82),
                    Color.fromRGBO(8, 12, 17, 0),
                    Color.fromRGBO(8, 12, 17, 0),
                    Color.fromRGBO(8, 12, 17, 0.86),
                  ],
                  stops: [0, 0.26, 0.46, 1],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              _buildHeader(state),
              const SizedBox(height: 20),
              _buildTextCard(page),
              const Spacer(),
              if (state.errorMessage != null || pageState?.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    state.errorMessage ?? pageState!.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: StoriaColors.gateError),
                  ),
                ),
              if (pageState?.needsRetakeNudge ?? false)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Highlighting may drift on this page — redo for a better match.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _buildControls(page, pageState, status),
              ),
              _buildPager(state),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Chrome
  // ---------------------------------------------------------------------------

  Widget _buildHeader(NarrationStudioState state) {
    final recorded = state.readyCount;
    final total = state.recordablePages.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Row(
        children: [
          _GlassButton(
            icon: Icons.close_rounded,
            semanticLabel: 'Leave recording',
            onTap: () => unawaited(_exit(state)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(13, 9, 13, 9),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(143, 184, 90, 0.30),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: const Color.fromRGBO(187, 223, 131, 0.55),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$recorded of $total recorded',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          _label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color.fromRGBO(255, 255, 255, 0.72),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  _ProgressDots(
                    pages: state.recordablePages.toList(growable: false),
                    activePageNumber:
                        _pages[_activeIndex.clamp(0, _pages.length - 1)]
                            .pageNumber,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _GlassButton(
            icon: Icons.help_outline_rounded,
            semanticLabel: 'Recording tips',
            onTap: () => unawaited(_showCoach(force: true)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextCard(PageData page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(250, 243, 232, 0.96),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'READ PAGE ${page.pageNumber} ALOUD',
              style: const TextStyle(
                color: StoriaColors.sageDeep,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              readablePageText(page),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: StoriaColors.ink,
                height: 1.42,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPager(NarrationStudioState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _PagerButton(
            icon: Icons.chevron_left_rounded,
            semanticLabel: 'Previous page',
            onTap: _activeIndex > 0 ? () => _goToPage(_activeIndex - 1) : null,
          ),
          _PagerButton(
            icon: Icons.chevron_right_rounded,
            semanticLabel: 'Next page',
            onTap: _activeIndex < _pages.length - 1
                ? () => _goToPage(_activeIndex + 1)
                : null,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Mic states
  // ---------------------------------------------------------------------------

  Widget _buildControls(
    PageData page,
    PageRecordingState? pageState,
    PageRecordingStatus status,
  ) {
    final controller = _controller!;

    return switch (status) {
      PageRecordingStatus.skipped => const _Hint(
        'This page has no words — skip ahead.',
      ),
      PageRecordingStatus.uploading => const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          _Hint('Saving and syncing the words…'),
        ],
      ),
      PageRecordingStatus.failed => NarrationPrimaryButton(
        label: 'Try saving again',
        onTap: () =>
            unawaited(controller.retryUpload(page.pageNumber, label: _label)),
      ),
      PageRecordingStatus.previewing => _buildReview(page, pageState),
      PageRecordingStatus.recording => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: StoriaColors.danger,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Recording · ${_formatDuration(_elapsed)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _Waveform(),
          const SizedBox(height: 16),
          _MicButton(isLive: true, onTap: () => unawaited(_stopRecording())),
        ],
      ),
      PageRecordingStatus.ready || PageRecordingStatus.notRecorded => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Hint(
            status == PageRecordingStatus.ready
                ? 'This page is recorded — tap the mic to redo it.'
                : 'Tap the mic and read this page',
          ),
          const SizedBox(height: 16),
          _MicButton(
            isLive: false,
            onTap: () => unawaited(_startRecording(page.pageNumber)),
          ),
        ],
      ),
    };
  }

  Widget _buildReview(PageData page, PageRecordingState? pageState) {
    final controller = _controller!;
    final file = pageState?.localFile;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(250, 243, 232, 0.96),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              StreamBuilder<PlayerState>(
                stream: _player.playerStateStream,
                builder: (context, snapshot) {
                  final playing = snapshot.data?.playing ?? false;
                  return Semantics(
                    button: true,
                    label: playing ? 'Pause the take' : 'Listen to the take',
                    child: GestureDetector(
                      onTap: () => unawaited(_togglePlay(file)),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: StoriaColors.sage,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: StoriaColors.ink,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Listen back · ${_formatDuration(pageState?.duration ?? Duration.zero)}',
                      style: const TextStyle(
                        color: StoriaColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    StreamBuilder<Duration>(
                      stream: _player.positionStream,
                      builder: (context, snapshot) {
                        final total =
                            _player.duration ??
                            pageState?.duration ??
                            Duration.zero;
                        final value = total.inMilliseconds == 0
                            ? 0.0
                            : (snapshot.data ?? Duration.zero).inMilliseconds /
                                  total.inMilliseconds;
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: value.clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: StoriaColors.line,
                            valueColor: const AlwaysStoppedAnimation(
                              StoriaColors.sageDeep,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            NarrationSecondaryButton(
              label: 'Redo',
              onDark: true,
              onTap: () => unawaited(_redo(page.pageNumber)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: NarrationPrimaryButton(
                label: _isLastRecordablePage()
                    ? 'Keep · finish'
                    : 'Keep · next page',
                icon: Icons.check_rounded,
                onTap: () => unawaited(_keep(controller, page.pageNumber)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Verbs
  // ---------------------------------------------------------------------------

  Future<void> _startRecording(int pageNumber) async {
    await _player.stop();
    final started = await _controller!.startRecording(pageNumber);
    if (!started || !mounted) return;

    setState(() => _elapsed = Duration.zero);
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _stopRecording() async {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    await _controller!.stopRecording();
  }

  Future<void> _togglePlay(File? file) async {
    if (file == null) return;
    if (_player.playing) {
      await _player.pause();
      return;
    }
    if (_loadedTakePath != file.path) {
      await _player.setFilePath(file.path);
      _loadedTakePath = file.path;
    }
    await _player.seek(Duration.zero);
    await _player.play();
  }

  Future<void> _redo(int pageNumber) async {
    await _player.stop();
    _loadedTakePath = null;
    await _controller!.retake(pageNumber);
  }

  Future<void> _keep(
    NarrationStudioController controller,
    int pageNumber,
  ) async {
    await _player.stop();
    _loadedTakePath = null;

    final isLast = _isLastRecordablePage();
    unawaited(controller.keepAndUpload(pageNumber, label: _label));

    if (isLast) {
      await _finish(controller);
      return;
    }
    _goToPage(_nextRecordableIndex());
  }

  /// Marks the track ready and shows the summary. Leaving before this keeps the
  /// track a draft, which is exactly what the voice sheet offers to resume.
  Future<void> _finish(NarrationStudioController controller) async {
    final saved = await controller.finish();
    if (!mounted) return;

    ref.invalidate(bookNarrationTracksProvider(widget.bookId));
    if (!saved) return;

    final trackId = controller.value.trackId;
    await _showDone(controller.value, trackId);
  }

  Future<void> _exit(NarrationStudioState state) async {
    _elapsedTimer?.cancel();
    await _player.stop();

    // Every kept page is already uploaded, so leaving mid-pass loses nothing —
    // the track stays a draft and the voice sheet shows it as resumable.
    if (state.isComplete && state.trackId != null) {
      await _finish(_controller!);
      if (!mounted) return;
    }

    ref.invalidate(bookNarrationTracksProvider(widget.bookId));
    if (mounted) Navigator.of(context).pop();
  }

  void _goToPage(int index) {
    unawaited(_player.stop());
    setState(() {
      _activeIndex = index.clamp(0, _pages.length - 1);
      _elapsed = Duration.zero;
    });
  }

  int _nextRecordableIndex() {
    final state = _controller!.value;
    for (var i = _activeIndex + 1; i < _pages.length; i++) {
      if (state.pageAt(_pages[i].pageNumber)?.status !=
          PageRecordingStatus.skipped) {
        return i;
      }
    }
    return _activeIndex;
  }

  bool _isLastRecordablePage() => _nextRecordableIndex() == _activeIndex;

  // ---------------------------------------------------------------------------
  // Sheets
  // ---------------------------------------------------------------------------

  Future<void> _showCoach({bool force = false}) async {
    if (_coachShown && !force) return;
    _coachShown = true;

    final state = _controller?.value;
    final recorded = state?.readyCount ?? 0;
    final pageNumber = _pages.isEmpty
        ? 1
        : _pages[_activeIndex.clamp(0, _pages.length - 1)].pageNumber;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: StoriaColors.paper,
      isScrollControlled: true,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => _CoachSheet(
        labelController: _labelController,
        askForName: widget.resumingTrack == null && recorded == 0,
        voiceName: _label,
        cta: recorded > 0
            ? 'Continue at page $pageNumber'
            : 'Start with page $pageNumber',
        onCancel: () {
          Navigator.of(ctx).pop();
          if (mounted) Navigator.of(context).pop();
        },
        onBegin: () => Navigator.of(ctx).pop(),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _showDone(NarrationStudioState state, String? trackId) async {
    final totalMs = state.recordablePages.fold<int>(
      0,
      (sum, page) => sum + (page.recording?.durationMs ?? 0),
    );

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: StoriaColors.paper,
      isScrollControlled: true,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => _DoneSheet(
        voiceName: _label,
        pagesKept: state.readyCount,
        totalLength: _formatDuration(Duration(milliseconds: totalMs)),
        onSetAsMain: () {
          if (trackId != null) {
            unawaited(
              ref
                  .read(narrationTrackSelectionProvider(widget.bookId).notifier)
                  .select(trackId),
            );
          }
          Navigator.of(ctx).pop();
        },
        onLater: () => Navigator.of(ctx).pop(),
      ),
    );

    if (mounted) Navigator.of(context).pop();
  }
}

String _formatDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// The words the adult is asked to read — overlay text when the page has one,
/// otherwise the plain page text. Mirrors what `countRenderedWords` counts.
String readablePageText(PageData page) {
  final overlay = page.overlay;
  if (overlay != null && overlay.elements.isNotEmpty) {
    return overlay.elements.map((e) => e.text).join('\n\n');
  }
  return page.textContent ?? '';
}

// =============================================================================
// Pieces
// =============================================================================

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white),
      ),
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(10, 15, 25, 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.18)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color.fromRGBO(255, 255, 255, 0.9),
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color.fromRGBO(255, 255, 255, 0.10),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: const Color.fromRGBO(255, 255, 255, 0.28),
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _PagerButton extends StatelessWidget {
  const _PagerButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.35 : 1,
          child: Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Color.fromRGBO(250, 243, 232, 0.92),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: StoriaColors.sageDeep, size: 28),
          ),
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.isLive, required this.onTap});

  final bool isLive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isLive ? 'Stop recording' : 'Start recording this page',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: isLive ? StoriaColors.danger : StoriaColors.dustyPinkStrong,
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color.fromRGBO(255, 255, 255, 0.92),
              width: 4,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.34),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: isLive
              ? Center(
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                )
              : const Icon(Icons.mic_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}

/// Decorative level meter. The recorder does not expose amplitude, so this
/// animates on a fixed cycle purely to show that capture is live.
class _Waveform extends StatefulWidget {
  const _Waveform();

  @override
  State<_Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<_Waveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: 44,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 28; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Container(
                      width: 4,
                      height:
                          38 *
                          (0.28 +
                              0.72 *
                                  (0.5 +
                                      0.5 *
                                          -math.cos(
                                            2 *
                                                math.pi *
                                                ((_controller.value + i / 12) %
                                                    1),
                                          ))),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(255, 255, 255, 0.72),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.pages, required this.activePageNumber});

  final List<PageRecordingState> pages;
  final int activePageNumber;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        children: [
          for (final page in pages)
            Expanded(
              child: Container(
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: page.status == PageRecordingStatus.ready
                      ? StoriaColors.sage
                      : (page.pageNumber == activePageNumber
                            ? Colors.white
                            : const Color.fromRGBO(255, 255, 255, 0.28)),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CoachSheet extends StatelessWidget {
  const _CoachSheet({
    required this.labelController,
    required this.askForName,
    required this.voiceName,
    required this.cta,
    required this.onCancel,
    required this.onBegin,
  });

  final TextEditingController labelController;
  final bool askForName;
  final String voiceName;
  final String cta;
  final VoidCallback onCancel;
  final VoidCallback onBegin;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          22 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NarrationSheetGrip(),
              Text(
                askForName ? 'Record your voice' : 'Recording as $voiceName',
                style: Theme.of(
                  context,
                ).textTheme.headlineLarge?.copyWith(color: StoriaColors.ink),
              ),
              const SizedBox(height: 4),
              const Text(
                'One page at a time. Stop whenever you like — every page you finish is saved.',
                style: TextStyle(
                  color: StoriaColors.inkMuted,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              if (askForName) ...[
                SketchTextField(
                  controller: labelController,
                  label: 'What should we call this voice?',
                  hintText: 'Mom',
                ),
                const SizedBox(height: 14),
              ],
              const _CoachStep(
                index: '1',
                color: StoriaColors.mustard,
                title: 'Read the line on the page',
                body:
                    "The child's own page stays on screen, so pacing matches the art.",
              ),
              const SizedBox(height: 10),
              const _CoachStep(
                index: '2',
                color: StoriaColors.sage,
                title: 'Hear it back before you keep it',
                body:
                    'Redo as many times as you want; only the take you keep is stored.',
              ),
              const SizedBox(height: 10),
              const _CoachStep(
                index: '3',
                color: StoriaColors.dustyPink,
                title: 'A quiet room beats a good mic',
                body: "Hold the phone a hand's width away and speak normally.",
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  NarrationSecondaryButton(label: 'Not now', onTap: onCancel),
                  const SizedBox(width: 10),
                  Expanded(
                    child: NarrationPrimaryButton(label: cta, onTap: onBegin),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachStep extends StatelessWidget {
  const _CoachStep({
    required this.index,
    required this.color,
    required this.title,
    required this.body,
  });

  final String index;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: StoriaColors.paperRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: StoriaColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Text(
              index,
              style: const TextStyle(
                color: StoriaColors.ink,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: StoriaColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                Text(
                  body,
                  style: const TextStyle(
                    color: StoriaColors.inkMuted,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
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

class _DoneSheet extends StatelessWidget {
  const _DoneSheet({
    required this.voiceName,
    required this.pagesKept,
    required this.totalLength,
    required this.onSetAsMain,
    required this.onLater,
  });

  final String voiceName;
  final int pagesKept;
  final String totalLength;
  final VoidCallback onSetAsMain;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NarrationSheetGrip(),
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    color: StoriaColors.sage,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: StoriaColors.ink,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "$voiceName's narration is ready",
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(color: StoriaColors.ink),
                      ),
                      Text(
                        'All $pagesKept pages · about $totalLength',
                        style: const TextStyle(
                          color: StoriaColors.inkMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Stat(value: '$pagesKept', label: 'pages kept'),
                const SizedBox(width: 10),
                _Stat(value: totalLength, label: 'total length'),
              ],
            ),
            const SizedBox(height: 16),
            NarrationPrimaryButton(
              label: "Make this the book's main voice",
              onTap: onSetAsMain,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: NarrationSecondaryButton(
                label: 'Not right now',
                onTap: onLater,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: BoxDecoration(
          color: StoriaColors.paperRaised,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: StoriaColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: StoriaColors.ink,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: StoriaColors.inkMuted,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
