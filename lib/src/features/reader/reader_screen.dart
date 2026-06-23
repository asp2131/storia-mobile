import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:confetti/confetti.dart';
import 'package:cue/cue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gif_player/gif_player.dart';
import 'package:gooey/gooey.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/storia_colors.dart';
import '../../core/theme/storia_motion.dart';
import '../../core/widgets/sketch_border.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../gen_ui/data/gen_ui_preferences_provider.dart';
import '../gen_ui/presentation/reader_activity_card.dart';
import 'application/reader_experience_controller.dart';
import 'liquid_page_clipper.dart';
import 'page_renderer.dart';
import 'walkthrough/reader_walkthrough.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final String bookId;

  const ReaderScreen({super.key, required this.bookId});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final ValueNotifier<bool> _showChromeNotifier = ValueNotifier(true);
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier(0.0);
  late final ConfettiController _confettiController;
  late GifPlayerController _gifPlayerController;

  late final ReaderExperienceControllerNotifier _controller;
  String? _initializedBookId;
  String? _preloadedManifestBookId;
  bool _walkthroughDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = ref.read(
      readerExperienceControllerProvider(widget.bookId).notifier,
    );
    _pageController.addListener(_onPageScroll);
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _gifPlayerController = GifPlayerController(
      dataSource: GifPlayerDataSource.asset('assets/gifs/green_screen.gif'),
      isAutoPlay: false,
      isAutoInitialize: true,
      loop: true,
      showControls: false,
    );
  }

  void _onPageScroll() {
    final page = _pageController.page;
    if (page != null) _scrollOffsetNotifier.value = page;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(_controller.handleLifecycleState(state));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(
      _controller.dispatch(const ReaderExperienceEnd(reason: 'screen_dispose')),
    );
    _showChromeNotifier.dispose();
    _scrollOffsetNotifier.dispose();
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    _confettiController.dispose();
    _gifPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(currentBookProvider(widget.bookId));
    final c = _controller;
    final state = ref.watch(readerExperienceControllerProvider(widget.bookId));
    final walkthroughSeen = ref.watch(readerWalkthroughSeenProvider);

    ref.listen<ReaderExperienceState>(
      readerExperienceControllerProvider(widget.bookId),
      (previous, next) {
        if (previous == null) return;
        final wasCelebrating = previous.readerState.showCelebration;
        final isCelebrating = next.readerState.showCelebration;
        if (isCelebrating && !wasCelebrating) {
          _confettiController.play();
          _gifPlayerController.seekTo(0);
          _gifPlayerController.play();
        } else if (!isCelebrating && wasCelebrating) {
          _gifPlayerController.pause();
        }
      },
    );

    return Scaffold(
      backgroundColor: StoriaColors.readerBackground,
      body: bookAsync.when(
        data: (book) {
          if (book == null) {
            return const Center(child: Text('Book not found'));
          }

          if (book.pages.isEmpty) {
            return const Center(child: Text('No pages in this book'));
          }

          if (_initializedBookId != book.id) {
            _initializedBookId = book.id;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              // Always open at the beginning. Starting at page 0 (the default)
              // also resets any page index a surviving reader controller or the
              // singleton session retained from a prior visit, so the physical
              // PageView (which starts at 0) and the logical active page agree
              // and re-entering a book is deterministic.
              c.dispatch(ReaderExperienceStart(book: book));
            });
          }

          if (_preloadedManifestBookId != book.id) {
            _preloadedManifestBookId = book.id;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ref.read(bookManifestProvider(book.id).future);
            });
          }

          final activeIndex = state.readerState.activePageIndex.clamp(
            0,
            book.pages.length - 1,
          );
          final activePage = book.pages[activeIndex];
          final wordHelpSnapshot = state.wordHelpSnapshot;
          final hasNarration = (activePage.narrationUrl ?? '').isNotEmpty;
          final hasSoundscape = (activePage.soundscapeUrl ?? '').isNotEmpty;

          return Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                excludeFromSemantics: true,
                onTap: () =>
                    _showChromeNotifier.value = !_showChromeNotifier.value,
                child: PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  itemCount: book.pages.length,
                  onPageChanged: (index) {
                    unawaited(c.dispatch(ReaderExperiencePageChanged(index)));
                  },
                  itemBuilder: (context, index) {
                    final isInVirtualizationWindow =
                        (index - activeIndex).abs() <= 1;
                    if (!isInVirtualizationWindow) {
                      return const SizedBox.shrink();
                    }

                    final page = book.pages[index];

                    final pageRenderer = ValueListenableBuilder<Duration>(
                      valueListenable: c.narrationPositionListenable,
                      builder: (context, narrationPosition, _) {
                        return PageRenderer(
                          page: page,
                          pageIndex: index,
                          scrollOffsetListenable: _scrollOffsetNotifier,
                          narrationPosition: narrationPosition,
                          isActive: index == activeIndex,
                          spokenWordIndices:
                              state.readerState.spokenWordIndices,
                          tappedWordIndex: wordHelpSnapshot.activeWordIndex,
                          tappedWordHighlightParts:
                              wordHelpSnapshot.highlightParts,
                          activeTappedWordHighlightPartIndex:
                              wordHelpSnapshot.activeHighlightPartIndex,
                          onWordTap: (word, globalIndex) {
                            unawaited(
                              c.dispatch(
                                ReaderExperienceWordTapped(
                                  word: word,
                                  globalIndex: globalIndex,
                                  pageIndex: index,
                                ),
                              ),
                            );
                          },
                          onWordLongPress: (word, globalIndex) {
                            unawaited(
                              c.dispatch(
                                ReaderExperienceWordLongPressed(
                                  word: word,
                                  globalIndex: globalIndex,
                                  pageIndex: index,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );

                    return ValueListenableBuilder<double>(
                      valueListenable: _scrollOffsetNotifier,
                      child: pageRenderer,
                      builder: (context, scrollOffset, child) {
                        final localOffset = scrollOffset - index;

                        final double progress;
                        final bool revealFromTop;

                        if (localOffset < 0) {
                          progress = (1.0 + localOffset).clamp(0.0, 1.0);
                          revealFromTop = false;
                        } else if (localOffset > 0) {
                          progress = (1.0 - localOffset).clamp(0.0, 1.0);
                          revealFromTop = true;
                        } else {
                          progress = 1.0;
                          revealFromTop = false;
                        }

                        return ClipPath(
                          clipper: VerticalLiquidClipper(
                            progress: progress,
                            revealFromTop: revealFromTop,
                          ),
                          child: child,
                        );
                      },
                    );
                  },
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _showChromeNotifier,
                builder: (context, showChrome, child) {
                  return IgnorePointer(
                    ignoring: !showChrome,
                    // TODO(STO-13): CueFlexibleSpaceBar needs a SliverAppBar +
                    // CustomScrollView reader refactor; keep Stack chrome for now.
                    child: Cue.onToggle(
                      debugLabel: 'reader-top-bar-chrome',
                      toggled: showChrome,
                      motion: const CueMotion.curved(
                        StoriaMotion.quick,
                        curve: StoriaMotion.emphasized,
                      ),
                      acts: const [.fadeIn()],
                      child: _ReaderTopBar(
                        book: book,
                        activePageNumber: activePage.pageNumber,
                        onClose: () => Navigator.of(context).maybePop(),
                        onAudioSettingsTap: () => _showAudioSettings(
                          context,
                          c,
                          state.readerState.narrationVolume,
                          state.readerState.soundscapeVolume,
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (ref.watch(storySparksEnabledProvider))
                ReaderActivityPromptOverlay(
                  bookId: book.id,
                  pageIndex: activeIndex,
                  isNarrationPlaying: state.readerState.isNarrationPlaying,
                  narrationPositionListenable: c.narrationPositionListenable,
                  narrationTimestamps: activePage.narrationTimestamps,
                  onActivityShown: () => unawaited(
                    c.dispatch(const ReaderExperienceActivityShown()),
                  ),
                  onActivityDismissed: () => unawaited(
                    c.dispatch(const ReaderExperienceActivityDismissed()),
                  ),
                ),
              AudioControlsPill(
                hasNarration: hasNarration,
                hasSoundscape: hasSoundscape,
                isNarrationPlaying: state.readerState.isNarrationPlaying,
                isSoundscapePlaying: state.readerState.isSoundscapePlaying,
                isPracticeActive: state.readerState.isPracticeMode,
                isListening: state.readerState.isListening,
                isVisible: true,
                showGrip: true,
                onToggleNarration: () =>
                    c.dispatch(const ReaderExperienceToggleNarration()),
                onToggleSoundscape: () =>
                    c.dispatch(const ReaderExperienceToggleSoundscape()),
                onTogglePractice: () =>
                    c.dispatch(const ReaderExperienceTogglePractice()),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  numberOfParticles: 30,
                  gravity: 0.1,
                  emissionFrequency: 0.05,
                  colors: const [
                    Color(0xFFF59E0B),
                    Color(0xFF14B8A6),
                    Color(0xFF8A80CC),
                    Color(0xFFEC4899),
                    Color(0xFF34D399),
                  ],
                ),
              ),
              // Only render the GIF player when celebration is active. The
              // controller is owned by ReaderScreen so it can survive these
              // conditional unmounts and be disposed exactly once in dispose().
              if (state.showCelebrationGif)
                Positioned(
                  right: 16,
                  bottom: MediaQuery.paddingOf(context).bottom + 100,
                  width: 160,
                  child: IgnorePointer(
                    child: GifPlayer(
                      controller: _gifPlayerController,
                      isAutoDisposeController: false,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              if (walkthroughSeen.valueOrNull == false &&
                  !_walkthroughDismissed)
                ReaderWalkthrough(
                  onComplete: () =>
                      setState(() => _walkthroughDismissed = true),
                ),
            ],
          );
        },
        loading: () => const _ReaderLoadingState(),
        error: (error, _) => _ReaderErrorState(
          error: '$error',
          onRetry: () {
            _initializedBookId = null;
            _preloadedManifestBookId = null;
            ref.invalidate(currentBookProvider(widget.bookId));
          },
        ),
      ),
    );
  }

  void _showAudioSettings(
    BuildContext context,
    ReaderExperienceControllerNotifier controller,
    double narrationVolume,
    double soundscapeVolume,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: StoriaColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) {
        return _AudioSettingsSheet(
          controller: controller,
          initialNarrationVolume: narrationVolume,
          initialSoundscapeVolume: soundscapeVolume,
        );
      },
    );
  }
}

// =============================================================================
// Top bar with title / page info / settings
// =============================================================================

class _ReaderTopBar extends StatelessWidget {
  final Book book;
  final int activePageNumber;
  final VoidCallback onClose;
  final VoidCallback onAudioSettingsTap;

  const _ReaderTopBar({
    required this.book,
    required this.activePageNumber,
    required this.onClose,
    required this.onAudioSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: IgnorePointer(
            child: Container(
              height: topInset + 110,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color.fromRGBO(8, 12, 17, 0.82), Colors.transparent],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: topInset + 10,
          left: 14,
          right: 14,
          child: Row(
            children: [
              _ChromeButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: onClose,
                semanticLabel: 'Back to library',
                semanticHint: 'Returns to your library',
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipPath(
                  clipper: ShapeBorderClipper(
                    shape: const SketchBorderShape(
                      side: BorderSide(
                        color: Color.fromRGBO(255, 255, 255, 0.22),
                        width: 1.2,
                      ),
                      radiusScale: 0.88,
                    ),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: DecoratedBox(
                      decoration: const ShapeDecoration(
                        color: Color.fromRGBO(10, 15, 25, 0.35),
                        shape: SketchBorderShape(
                          side: BorderSide(
                            color: Color.fromRGBO(255, 255, 255, 0.22),
                            width: 1.2,
                          ),
                          radiusScale: 0.88,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              book.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.lora(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Page $activePageNumber of ${book.pages.length}',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFD4D8E0),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _ChromeButton(
                icon: Icons.tune_rounded,
                onTap: onAudioSettingsTap,
                semanticLabel: 'Audio settings',
                semanticHint: 'Opens narration and ambience volume controls',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Bottom audio controls — circular pie-wedge design
// =============================================================================

const _narrationColor = Color(0xFFF59E0B); // Warm amber
const _soundscapeColor = Color(0xFF14B8A6); // Teal
const _practiceColor = Color(0xFFF87171); // Coral

const _circleSize = 120.0;
const _gripSize = 36.0;

/// Which pie wedge was tapped.
enum _WedgeZone { left, right, bottom }

class AudioControlsPill extends StatefulWidget {
  final bool hasNarration;
  final bool hasSoundscape;
  final bool isNarrationPlaying;
  final bool isSoundscapePlaying;
  final bool isPracticeActive;
  final bool isListening;
  final bool isVisible;
  final bool showGrip;
  final Future<void> Function() onToggleNarration;
  final Future<void> Function() onToggleSoundscape;
  final Future<void> Function() onTogglePractice;

  const AudioControlsPill({
    super.key,
    required this.hasNarration,
    required this.hasSoundscape,
    required this.isNarrationPlaying,
    required this.isSoundscapePlaying,
    required this.isPracticeActive,
    required this.isListening,
    required this.isVisible,
    required this.showGrip,
    required this.onToggleNarration,
    required this.onToggleSoundscape,
    required this.onTogglePractice,
  });

  @override
  State<AudioControlsPill> createState() => AudioControlsPillState();
}

class AudioControlsPillState extends State<AudioControlsPill>
    with TickerProviderStateMixin {
  // ---------------------------------------------------------------------------
  // Drag state
  // ---------------------------------------------------------------------------
  final ValueNotifier<Offset> _dragOffsetNotifier = ValueNotifier(Offset.zero);
  bool _isDragging = false;

  // ---------------------------------------------------------------------------
  // Gooey wobble state
  //
  // While the pill is being dragged, a gooey overlay paints behind the pill
  // with a small "trail" blob that lags behind the drag direction. The blob
  // catches up smoothly on release (the outro animation), making the pill
  // feel like jelly. When fully idle, the overlay is unmounted entirely so
  // there is zero overhead.
  // ---------------------------------------------------------------------------
  final ValueNotifier<Offset> _trailVectorNotifier = ValueNotifier(Offset.zero);
  late final AnimationController _outroController;
  bool _wobbleActive = false;
  Offset _outroStartVector = Offset.zero;

  /// Maximum pixel distance the trail blob can lag from the pill center.
  ///
  /// This must be large enough to protrude past the 60px pill radius; otherwise
  /// the gooey overlay is technically mounted but hidden under the pill body.
  static const double _maxTrailDistance = 72.0;

  /// Pixel-amplification of each per-frame pan delta when computing the
  /// trail's target offset. Tuned so a brisk drag visibly stretches the goo
  /// without exploding past [_maxTrailDistance].
  static const double _trailDeltaGain = 12.0;

  /// EMA smoothing factor for the trail vector. Higher = more responsive,
  /// lower = more inertia.
  static const double _trailSmoothing = 0.4;

  /// Color of the gooey wobble blobs. Matches the pill body so the trail
  /// reads as the same material extending out of the pill.
  static const Color _wobbleColor = Color.fromRGBO(10, 15, 25, 0.62);

  static const Size _pillSize = Size(_circleSize, _circleSize);

  Offset get _dragOffset => _dragOffsetNotifier.value;

  @override
  void initState() {
    super.initState();
    _outroController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 260),
          )
          ..addListener(_handleOutroTick)
          ..addStatusListener(_handleOutroStatus);
  }

  @override
  void dispose() {
    _outroController
      ..removeListener(_handleOutroTick)
      ..removeStatusListener(_handleOutroStatus)
      ..dispose();
    _trailVectorNotifier.dispose();
    _dragOffsetNotifier.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Wobble lifecycle
  // ---------------------------------------------------------------------------

  void _activateWobble() {
    if (_outroController.isAnimating) {
      _outroController.stop();
    }
    if (!_wobbleActive) {
      setState(() => _wobbleActive = true);
    }
  }

  void _beginWobbleOutro() {
    final start = _trailVectorNotifier.value;
    if (start.distance < 0.5) {
      _trailVectorNotifier.value = Offset.zero;
      if (_wobbleActive) {
        setState(() => _wobbleActive = false);
      }
      return;
    }
    _outroStartVector = start;
    _outroController.forward(from: 0.0);
  }

  void _handleOutroTick() {
    final progress = Curves.easeOut.transform(_outroController.value);
    _trailVectorNotifier.value = Offset.lerp(
      _outroStartVector,
      Offset.zero,
      progress,
    )!;
  }

  void _handleOutroStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _trailVectorNotifier.value = Offset.zero;
      if (_wobbleActive && !_isDragging) {
        setState(() => _wobbleActive = false);
      }
    }
  }

  void _updateTrail(Offset delta) {
    final current = _trailVectorNotifier.value;
    // Trail lags opposite to drag motion ("the pill drags itself forward,
    // leaving a tail behind").
    final lagTarget = -delta * _trailDeltaGain;
    final smoothed =
        current * (1 - _trailSmoothing) + lagTarget * _trailSmoothing;
    final magnitude = smoothed.distance;
    final clamped = magnitude > _maxTrailDistance
        ? Offset.fromDirection(smoothed.direction, _maxTrailDistance)
        : smoothed;
    _trailVectorNotifier.value = clamped;
  }

  Offset _clampOffset({
    required Offset candidate,
    required Size viewportSize,
    required EdgeInsets safePadding,
    required double baseBottom,
  }) {
    if (_pillSize == Size.zero) return candidate;

    final baseLeft = (viewportSize.width - _pillSize.width) / 2;
    final baseTop = viewportSize.height - baseBottom - _pillSize.height;

    final minLeft = 8.0;
    final maxLeft = math.max(
      minLeft,
      viewportSize.width - _pillSize.width - 8.0,
    );
    final minTop = safePadding.top + 12.0;
    final maxTop = math.max(
      minTop,
      viewportSize.height - safePadding.bottom - _pillSize.height - 12.0,
    );

    final left = (baseLeft + candidate.dx).clamp(minLeft, maxLeft);
    final top = (baseTop + candidate.dy).clamp(minTop, maxTop);
    return Offset(left - baseLeft, top - baseTop);
  }

  /// Determine which wedge was tapped based on angle from center.
  _WedgeZone? _hitTestWedge(Offset localPosition) {
    final center = Offset(_circleSize / 2, _circleSize / 2);
    final delta = localPosition - center;
    final distance = delta.distance;
    if (distance > _circleSize / 2) return null;
    // Ignore taps in the grip center zone.
    if (distance < 18) return null;

    // Normalize angle to [0, 2pi)
    final angle = math.atan2(delta.dy, delta.dx);
    final norm = angle < 0 ? angle + 2 * math.pi : angle;

    // Three 120° wedges, starting from -30° (= 330° = 11pi/6)
    if (norm >= 11 * math.pi / 6 || norm < math.pi / 2) {
      return _WedgeZone.right; // Soundscape (right side)
    } else if (norm >= math.pi / 2 && norm < 7 * math.pi / 6) {
      return _WedgeZone.bottom; // Practice (bottom)
    } else {
      return _WedgeZone.left; // Narration (left side)
    }
  }

  void _onWedgeTap(_WedgeZone zone) {
    switch (zone) {
      case _WedgeZone.left:
        widget.onToggleNarration();
      case _WedgeZone.right:
        widget.onToggleSoundscape();
      case _WedgeZone.bottom:
        widget.onTogglePractice();
    }
  }

  void _handlePanStart() {
    setState(() => _isDragging = true);
    _activateWobble();
  }

  void _handlePanEnd() {
    setState(() => _isDragging = false);
    _beginWobbleOutro();
  }

  void _handlePanUpdate(
    DragUpdateDetails details, {
    required Size viewportSize,
    required EdgeInsets safePadding,
    required double baseBottom,
  }) {
    final next = _clampOffset(
      candidate: _dragOffset + details.delta,
      viewportSize: viewportSize,
      safePadding: safePadding,
      baseBottom: baseBottom,
    );
    _dragOffsetNotifier.value = next;
    _updateTrail(details.delta);
  }

  /// Builds the gooey wobble overlay that paints behind the pill while it is
  /// being dragged (and during the brief release outro). Returns `null` when
  /// the overlay should not be rendered at all.
  Widget? _buildWobbleOverlay() {
    if (!_wobbleActive) return null;

    const double overlaySize = _circleSize + _maxTrailDistance * 2 + 24;

    return IgnorePointer(
      child: SizedBox(
        width: overlaySize,
        height: overlaySize,
        child: GooeyZone(
          color: _wobbleColor,
          gooiness: 38,
          borderWidth: 1.0,
          borderColor: const Color.fromRGBO(255, 255, 255, 0.16),
          child: ValueListenableBuilder<Offset>(
            valueListenable: _trailVectorNotifier,
            builder: (context, trail, _) {
              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  const GooeyBlob(
                    shape: BlobShape.circle(),
                    child: SizedBox.square(dimension: _circleSize),
                  ),
                  Transform.translate(
                    offset: trail,
                    child: const GooeyBlob(
                      shape: BlobShape.circle(),
                      child: SizedBox.square(
                        key: ValueKey('audio-controls-gooey-trail'),
                        dimension: 58,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Icon position: center of a wedge at a given angle and radial distance.
  Offset _wedgeIconOffset(double angleDeg) {
    final angleRad = angleDeg * math.pi / 180;
    const iconRadius = (_circleSize / 2 - _gripSize / 2) / 2 + _gripSize / 2;
    return Offset(
      _circleSize / 2 + iconRadius * math.cos(angleRad) - 11,
      _circleSize / 2 + iconRadius * math.sin(angleRad) - 11,
    );
  }

  Widget _buildCircleBody({
    required Size viewportSize,
    required EdgeInsets safePadding,
    required double baseBottom,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        final zone = _hitTestWedge(details.localPosition);
        if (zone != null) _onWedgeTap(zone);
      },
      onPanStart: (_) => _handlePanStart(),
      onPanUpdate: (details) => _handlePanUpdate(
        details,
        viewportSize: viewportSize,
        safePadding: safePadding,
        baseBottom: baseBottom,
      ),
      onPanEnd: (_) => _handlePanEnd(),
      onPanCancel: _handlePanEnd,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (_buildWobbleOverlay() case final overlay?) overlay,
          _buildPillVisual(
            viewportSize: viewportSize,
            safePadding: safePadding,
            baseBottom: baseBottom,
          ),
        ],
      ),
    );
  }

  /// The opaque, glassy pill itself: wedge icons, divider painter, blur,
  /// and the central grip handle.
  Widget _buildPillVisual({
    required Size viewportSize,
    required EdgeInsets safePadding,
    required double baseBottom,
  }) {
    final narrationIconPos = _wedgeIconOffset(270); // left
    final soundscapeIconPos = _wedgeIconOffset(30); // right
    final practiceIconPos = _wedgeIconOffset(150); // bottom

    return Container(
      width: _circleSize,
      height: _circleSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _wobbleColor,
        border: Border.all(
          color: _isDragging
              ? const Color.fromRGBO(255, 255, 255, 0.34)
              : const Color.fromRGBO(255, 255, 255, 0.18),
          width: _isDragging ? 1.4 : 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDragging ? 0.34 : 0.18),
            blurRadius: _isDragging ? 28 : 18,
            offset: Offset(0, _isDragging ? 16 : 8),
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: CustomPaint(
            painter: _WedgePainter(
              isNarrationActive: widget.isNarrationPlaying,
              isSoundscapeActive: widget.isSoundscapePlaying,
              isPracticeActive: widget.isPracticeActive || widget.isListening,
              gripRadius: _gripSize / 2,
            ),
            child: SizedBox(
              width: _circleSize,
              height: _circleSize,
              child: Stack(
                children: [
                  Positioned(
                    left: narrationIconPos.dx,
                    top: narrationIconPos.dy,
                    child: Icon(
                      widget.isNarrationPlaying
                          ? Icons.pause_rounded
                          : Icons.headphones_rounded,
                      size: 22,
                      color: widget.isNarrationPlaying
                          ? _narrationColor
                          : const Color.fromRGBO(255, 255, 255, 0.85),
                    ),
                  ),
                  Positioned(
                    left: soundscapeIconPos.dx,
                    top: soundscapeIconPos.dy,
                    child: Icon(
                      widget.isSoundscapePlaying
                          ? Icons.volume_up_rounded
                          : Icons.waves_rounded,
                      size: 22,
                      color: widget.isSoundscapePlaying
                          ? _soundscapeColor
                          : const Color.fromRGBO(255, 255, 255, 0.85),
                    ),
                  ),
                  Positioned(
                    left: practiceIconPos.dx,
                    top: practiceIconPos.dy,
                    child: Icon(
                      widget.isListening
                          ? Icons.mic_rounded
                          : Icons.mic_off_rounded,
                      size: 22,
                      color: (widget.isPracticeActive || widget.isListening)
                          ? _practiceColor
                          : const Color.fromRGBO(255, 255, 255, 0.85),
                    ),
                  ),
                  Center(
                    child: _buildGripHandle(
                      viewportSize: viewportSize,
                      safePadding: safePadding,
                      baseBottom: baseBottom,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGripHandle({
    required Size viewportSize,
    required EdgeInsets safePadding,
    required double baseBottom,
  }) {
    return Semantics(
      button: true,
      label: 'Move audio controls',
      hint: 'Drag to reposition the audio controls',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => _handlePanStart(),
        onPanUpdate: (details) => _handlePanUpdate(
          details,
          viewportSize: viewportSize,
          safePadding: safePadding,
          baseBottom: baseBottom,
        ),
        onPanEnd: (_) => _handlePanEnd(),
        onPanCancel: _handlePanEnd,
        child: AnimatedScale(
          scale: _isDragging ? 1.06 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: Container(
            width: _gripSize,
            height: _gripSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.fromRGBO(96, 116, 150, _isDragging ? 0.40 : 0.32),
                  Color.fromRGBO(23, 29, 40, _isDragging ? 0.78 : 0.68),
                ],
              ),
              border: Border.all(
                color: Color.fromRGBO(255, 255, 255, _isDragging ? 0.36 : 0.26),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: _isDragging ? 0.32 : 0.24,
                  ),
                  blurRadius: _isDragging ? 12 : 8,
                  offset: Offset(0, _isDragging ? 4 : 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (_) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Container(
                    width: 3,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(
                        235,
                        246,
                        255,
                        _isDragging ? 0.90 : 0.75,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.paddingOf(context);
    final viewportSize = MediaQuery.sizeOf(context);
    final baseBottom = math.max(28.0, safePadding.bottom + 12.0);
    final baseLeft = (viewportSize.width - _circleSize) / 2;
    final baseTop = viewportSize.height - baseBottom - _circleSize;

    final pillSubtree = IgnorePointer(
      ignoring: !widget.isVisible,
      child: AnimatedOpacity(
        opacity: widget.isVisible ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        child: AnimatedScale(
          scale: _isDragging ? 1.035 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: _circleSize,
            height: _circleSize,
            child: _buildCircleBody(
              viewportSize: viewportSize,
              safePadding: safePadding,
              baseBottom: baseBottom,
            ),
          ),
        ),
      ),
    );

    return Positioned.fill(
      child: ValueListenableBuilder<Offset>(
        valueListenable: _dragOffsetNotifier,
        builder: (context, dragOffset, child) {
          final clamped = _clampOffset(
            candidate: dragOffset,
            viewportSize: viewportSize,
            safePadding: safePadding,
            baseBottom: baseBottom,
          );
          if (clamped != dragOffset) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _dragOffsetNotifier.value = clamped;
            });
          }
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: baseLeft + clamped.dx,
                top: baseTop + clamped.dy,
                width: _circleSize,
                height: _circleSize,
                child: child!,
              ),
            ],
          );
        },
        child: pillSubtree,
      ),
    );
  }
}

/// Paints the 3 pie wedges with active-state fills and divider lines.
class _WedgePainter extends CustomPainter {
  final bool isNarrationActive;
  final bool isSoundscapeActive;
  final bool isPracticeActive;
  final double gripRadius;

  _WedgePainter({
    required this.isNarrationActive,
    required this.isSoundscapeActive,
    required this.isPracticeActive,
    required this.gripRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    const sweep = 2 * math.pi / 3; // 120°

    final wedges = [
      (
        startAngle: -math.pi / 6,
        color: _soundscapeColor,
        active: isSoundscapeActive,
      ),
      (
        startAngle: math.pi / 2,
        color: _practiceColor,
        active: isPracticeActive,
      ),
      (
        startAngle: 7 * math.pi / 6,
        color: _narrationColor,
        active: isNarrationActive,
      ),
    ];

    for (final w in wedges) {
      if (!w.active) continue;
      final paint = Paint()
        ..color = w.color.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;
      canvas.drawArc(rect, w.startAngle, sweep, true, paint);
    }

    final dividerPaint = Paint()
      ..color = const Color.fromRGBO(255, 255, 255, 0.15)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final dividerAngles = [-math.pi / 6, math.pi / 2, 7 * math.pi / 6];
    for (final a in dividerAngles) {
      final start = Offset(
        center.dx + gripRadius * math.cos(a),
        center.dy + gripRadius * math.sin(a),
      );
      final end = Offset(
        center.dx + radius * math.cos(a),
        center.dy + radius * math.sin(a),
      );
      canvas.drawLine(start, end, dividerPaint);
    }
  }

  @override
  bool shouldRepaint(_WedgePainter oldDelegate) =>
      oldDelegate.isNarrationActive != isNarrationActive ||
      oldDelegate.isSoundscapeActive != isSoundscapeActive ||
      oldDelegate.isPracticeActive != isPracticeActive;
}

// =============================================================================
// Shared chrome button
// =============================================================================

class _ChromeButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final String semanticHint;
  const _ChromeButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    required this.semanticHint,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      hint: semanticHint,
      child: ClipPath(
        clipper: ShapeBorderClipper(
          shape: const SketchBorderShape(
            side: BorderSide(color: Color.fromRGBO(255, 255, 255, 0.28)),
            radiusScale: 0.8,
          ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: const Color.fromRGBO(255, 255, 255, 0.10),
            shape: const SketchBorderShape(
              side: BorderSide(color: Color.fromRGBO(255, 255, 255, 0.28)),
              radiusScale: 0.8,
            ),
            child: InkWell(
              customBorder: const SketchBorderShape(
                side: BorderSide(color: Color.fromRGBO(255, 255, 255, 0.28)),
                radiusScale: 0.8,
              ),
              onTap: onTap,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(icon, color: Colors.white, size: 21),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Volume settings sheet
// =============================================================================

class _AudioSettingsSheet extends ConsumerStatefulWidget {
  final ReaderExperienceControllerNotifier controller;
  final double initialNarrationVolume;
  final double initialSoundscapeVolume;

  const _AudioSettingsSheet({
    required this.controller,
    required this.initialNarrationVolume,
    required this.initialSoundscapeVolume,
  });

  @override
  ConsumerState<_AudioSettingsSheet> createState() =>
      _AudioSettingsSheetState();
}

class _AudioSettingsSheetState extends ConsumerState<_AudioSettingsSheet> {
  late double _narrationVolume;
  late double _soundscapeVolume;

  @override
  void initState() {
    super.initState();
    _narrationVolume = widget.initialNarrationVolume;
    _soundscapeVolume = widget.initialSoundscapeVolume;
  }

  void _setNarrationVolume(double value) {
    setState(() => _narrationVolume = value);
    unawaited(
      widget.controller.dispatch(ReaderExperienceSetNarrationVolume(value)),
    );
  }

  void _setSoundscapeVolume(double value) {
    setState(() => _soundscapeVolume = value);
    unawaited(
      widget.controller.dispatch(ReaderExperienceSetSoundscapeVolume(value)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 46,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD7D7D2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Audio Mix', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 18),
          _VolumeRow(
            icon: Icons.record_voice_over_rounded,
            label: 'Narration',
            semanticsLabel: 'Narration volume',
            value: _narrationVolume,
            onChanged: _setNarrationVolume,
          ),
          const SizedBox(height: 14),
          _VolumeRow(
            icon: Icons.surround_sound_rounded,
            label: 'Ambience',
            semanticsLabel: 'Ambience volume',
            value: _soundscapeVolume,
            onChanged: _setSoundscapeVolume,
          ),
          const SizedBox(height: 14),
          _ToggleRow(
            icon: Icons.auto_awesome_rounded,
            label: 'Story Sparks',
            description: 'Playful activity cards that pop up while reading.',
            semanticsLabel: 'Story Sparks activity cards',
            value: ref.watch(storySparksEnabledProvider),
            onChanged: (enabled) => unawaited(
              ref
                  .read(genUiPreferencesNotifierProvider)
                  .setStorySparksEnabled(enabled),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final String semanticsLabel;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.semanticsLabel,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: SketchBorderShape(
          side: BorderSide(color: StoriaColors.line, width: 1.1),
          radiusScale: 0.82,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: StoriaColors.inkMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: StoriaColors.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Semantics(
            label: semanticsLabel,
            toggled: value,
            child: Switch.adaptive(
              value: value,
              activeThumbColor: StoriaColors.dustyPinkStrong,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _VolumeRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final String semanticsLabel;
  final ValueChanged<double> onChanged;

  const _VolumeRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.semanticsLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: SketchBorderShape(
          side: BorderSide(color: StoriaColors.line, width: 1.1),
          radiusScale: 0.82,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: StoriaColors.inkMuted),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Semantics(
                label: semanticsLabel,
                value: '${(value * 100).round()} percent',
                hint: 'Adjust $label volume',
                child: Slider(
                  value: value.clamp(0.0, 1.0),
                  min: 0,
                  max: 1,
                  activeColor: StoriaColors.dustyPinkStrong,
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
          Text(
            '${(value * 100).round()}%',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Loading / error states
// =============================================================================

class _ReaderLoadingState extends StatelessWidget {
  const _ReaderLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Color(0xFF8A80CC)),
          const SizedBox(height: 14),
          Text(
            'Opening your story...',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: const Color(0xFFC5CBD8)),
          ),
        ],
      ),
    );
  }
}

class _ReaderErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ReaderErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sentiment_dissatisfied_outlined,
              size: 52,
              color: Color(0xFF8A80CC),
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFD4D8E0)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8A80CC),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
