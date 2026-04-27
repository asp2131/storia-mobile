import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:confetti/confetti.dart';
import 'package:gif_player/gif_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/storia_colors.dart';
import '../../core/theme/storia_motion.dart';
import '../../core/widgets/sketch_border.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import 'liquid_page_clipper.dart';
import 'page_renderer.dart';
import 'runtime/providers/reader_session_provider.dart';
import 'runtime/providers/word_tts_provider.dart';
import 'runtime/reader_intent.dart';
import 'runtime/reader_session.dart';
import 'runtime/reader_view_state.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final String bookId;

  const ReaderScreen({super.key, required this.bookId});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final PageController _pageController = PageController();
  final ValueNotifier<bool> _showChromeNotifier = ValueNotifier(true);
  final ValueNotifier<Duration> _narrationPositionNotifier = ValueNotifier(
    Duration.zero,
  );
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier(0.0);
  late final ConfettiController _confettiController;
  bool _showCelebrationGif = false;
  late GifPlayerController _gifPlayerController;

  late final ReaderSession _session;
  StreamSubscription<ReaderViewState>? _sessionSubscription;
  ReaderViewState _runtimeState = const ReaderViewState.initial();
  String? _initializedBookId;
  String? _preloadedManifestBookId;

  @override
  void initState() {
    super.initState();
    _session = ref.read(readerSessionProvider);
    _sessionSubscription = _session.states.listen(_onRuntimeStateChanged);

    // Attach state stream to word TTS notifier for narration/mic coordination
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(wordTtsProvider.notifier).attachStateStream(_session.states);
    });

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

  void _onRuntimeStateChanged(ReaderViewState next) {
    final previous = _runtimeState;
    final wasCelebrating = previous.showCelebration;
    final isCelebrating = next.showCelebration;

    _narrationPositionNotifier.value = next.narrationPosition;

    final needsStructuralRebuild =
        previous.isReady != next.isReady ||
        previous.activePageIndex != next.activePageIndex ||
        previous.isNarrationPlaying != next.isNarrationPlaying ||
        previous.isSoundscapePlaying != next.isSoundscapePlaying ||
        previous.narrationVolume != next.narrationVolume ||
        previous.soundscapeVolume != next.soundscapeVolume ||
        previous.isPracticeMode != next.isPracticeMode ||
        previous.isListening != next.isListening ||
        previous.showCelebration != next.showCelebration ||
        !_sameWordIndices(previous.spokenWordIndices, next.spokenWordIndices);

    if (mounted && needsStructuralRebuild) {
      setState(() {
        _runtimeState = next;
      });
    } else {
      _runtimeState = next;
    }

    if (isCelebrating && !wasCelebrating) {
      _confettiController.play();
      _gifPlayerController.seekTo(0);
      _gifPlayerController.play();
      if (mounted) {
        setState(() => _showCelebrationGif = true);
      } else {
        _showCelebrationGif = true;
      }
    } else if (!isCelebrating && wasCelebrating) {
      _gifPlayerController.pause();
      if (mounted) {
        setState(() => _showCelebrationGif = false);
      } else {
        _showCelebrationGif = false;
      }
    }
  }

  void _onPageScroll() {
    final page = _pageController.page;
    if (page != null) _scrollOffsetNotifier.value = page;
  }

  bool _sameWordIndices(Set<int> a, Set<int> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (final value in a) {
      if (!b.contains(value)) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _showChromeNotifier.dispose();
    _narrationPositionNotifier.dispose();
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
              if (!mounted) {
                return;
              }
              ref.read(wordTtsProvider.notifier).setBookId(book.id);
              unawaited(_session.dispatch(ReaderStart(book: book)));
            });
          }

          if (_preloadedManifestBookId != book.id) {
            _preloadedManifestBookId = book.id;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              unawaited(ref.read(bookManifestProvider(book.id).future));
            });
          }

          final activeIndex = _runtimeState.activePageIndex.clamp(
            0,
            book.pages.length - 1,
          );
          final activePage = book.pages[activeIndex];
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
                  onPageChanged: (index) async {
                    await _session.dispatch(ReaderGoToPage(index));
                  },
                  itemBuilder: (context, index) {
                    final isInVirtualizationWindow =
                        (index - activeIndex).abs() <= 1;
                    if (!isInVirtualizationWindow) {
                      return const SizedBox.shrink();
                    }

                    final page = book.pages[index];

                    final pageRenderer = ValueListenableBuilder<Duration>(
                      valueListenable: _narrationPositionNotifier,
                      builder: (context, narrationPosition, _) {
                        return PageRenderer(
                          page: page,
                          pageIndex: index,
                          scrollOffsetListenable: _scrollOffsetNotifier,
                          narrationPosition: narrationPosition,
                          isActive: index == activeIndex,
                          spokenWordIndices: _runtimeState.spokenWordIndices,
                          onWordTap: (word, globalIndex) {
                            ref
                                .read(wordTtsProvider.notifier)
                                .onWordTapped(word, globalIndex);
                          },
                          onWordLongPress: (word, globalIndex) {
                            ref
                                .read(wordTtsProvider.notifier)
                                .onWordLongPressed(word, globalIndex);
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
                    child: AnimatedOpacity(
                      opacity: showChrome ? 1 : 0,
                      duration: 220.ms,
                      curve: Curves.easeOut,
                      child: _ReaderTopBar(
                        book: book,
                        activePageNumber: activePage.pageNumber,
                        onClose: () => Navigator.of(context).maybePop(),
                        onAudioSettingsTap: () => _showAudioSettings(context),
                      ),
                    ),
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _showChromeNotifier,
                builder: (context, showChrome, _) {
                  if (!hasNarration && !hasSoundscape) {
                    return const SizedBox.shrink();
                  }

                  final practiceKeepsVisible =
                      _runtimeState.isPracticeMode || _runtimeState.isListening;

                  return _AudioControlsPill(
                    hasNarration: hasNarration,
                    hasSoundscape: hasSoundscape,
                    isNarrationPlaying: _runtimeState.isNarrationPlaying,
                    isSoundscapePlaying: _runtimeState.isSoundscapePlaying,
                    isPracticeActive: _runtimeState.isPracticeMode,
                    isListening: _runtimeState.isListening,
                    isVisible: showChrome || practiceKeepsVisible,
                    showGrip: showChrome,
                    onToggleNarration: () =>
                        _session.dispatch(const ReaderToggleNarration()),
                    onToggleSoundscape: () =>
                        _session.dispatch(const ReaderToggleSoundscape()),
                    onTogglePractice: () =>
                        _session.dispatch(const ReaderPracticePrimaryAction()),
                  );
                },
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
              Positioned(
                right: 16,
                bottom: MediaQuery.paddingOf(context).bottom + 100,
                width: 160,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _showCelebrationGif ? 1.0 : 0.0,
                    duration: Duration(
                      milliseconds: _showCelebrationGif ? 300 : 500,
                    ),
                    child: GifPlayer(
                      controller: _gifPlayerController,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
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

  Future<void> _showAudioSettings(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: StoriaColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
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
              Text(
                'Audio Mix',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 18),
              _VolumeRow(
                icon: Icons.record_voice_over_rounded,
                label: 'Narration',
                semanticsLabel: 'Narration volume',
                value: _runtimeState.narrationVolume,
                onChanged: (value) {
                  _session.dispatch(ReaderSetNarrationVolume(value));
                },
              ),
              const SizedBox(height: 14),
              _VolumeRow(
                icon: Icons.surround_sound_rounded,
                label: 'Ambience',
                semanticsLabel: 'Ambience volume',
                value: _runtimeState.soundscapeVolume,
                onChanged: (value) {
                  _session.dispatch(ReaderSetSoundscapeVolume(value));
                },
              ),
            ],
          ),
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

class _AudioControlsPill extends StatefulWidget {
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

  const _AudioControlsPill({
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
  State<_AudioControlsPill> createState() => _AudioControlsPillState();
}

class _AudioControlsPillState extends State<_AudioControlsPill> {
  final GlobalKey _pillKey = GlobalKey();
  Offset _dragOffset = Offset.zero;
  Size _pillSize = Size.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant _AudioControlsPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hasNarration != widget.hasNarration ||
        oldWidget.hasSoundscape != widget.hasSoundscape ||
        oldWidget.showGrip != widget.showGrip) {
      _scheduleMeasure();
    }
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ro = _pillKey.currentContext?.findRenderObject();
      if (ro is! RenderBox || !ro.hasSize) return;
      final next = ro.size;
      if (next != _pillSize) setState(() => _pillSize = next);
    });
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

    // Angle: 0 = right, pi/2 = down, -pi/2 = up.
    final angle = math.atan2(delta.dy, delta.dx);

    // Wedge layout (matching sketch):
    // Left wedge (narration):  150° to 270° (-210° to -90°)
    // Right wedge (soundscape): 30° to 150° (top-right to bottom-right)
    // Bottom wedge (practice): 270° to 390° (i.e. -90° to 30°)
    //
    // In radians, using atan2 range (-pi, pi]:
    // Left:   angle > 5pi/6 or angle < -pi/2   → roughly left half
    // Right:  angle > pi/6 and angle <= 5pi/6   → roughly right half
    // Bottom: angle >= -pi/2 and angle <= pi/6  → top (grip area + bottom)

    // Simpler 3-way split: 120° each, rotated so dividers go from center
    // at -30°, 90°, 210° (matching the sketch's Y-shaped dividers).
    // Wedge 0 (top/bottom-center = practice): -90° ± 60° → -150° to -30°
    // Wedge 1 (right = soundscape): -30° ± 120° → -30° to 90°
    // Wedge 2 (left = narration): 90° to 210° (= 90° to -150°)

    // Normalize angle to [0, 2pi)
    final norm = angle < 0 ? angle + 2 * math.pi : angle;

    // Three 120° wedges, starting from -30° (= 330° = 11pi/6)
    // Wedge boundaries at 330°, 90°, 210°
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

  /// Icon position: center of a wedge at a given angle and radial distance.
  Offset _wedgeIconOffset(double angleDeg) {
    final angleRad = angleDeg * math.pi / 180;
    // Place icons at ~60% of the radius, between center grip and outer edge.
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
    // Icon positions: center of each 120° wedge.
    // Left (narration): wedge from 150° to 270° → center at 210°
    // Right (soundscape): wedge from 270° to 390° → center at 330°
    // Bottom (practice): wedge from 30° to 150° → center at 90°
    //
    // Using our wedge layout: dividers at -30°, 90°, 210°
    // Right (soundscape): -30° to 90° → center at 30°
    // Bottom (practice): 90° to 210° → center at 150°
    // Left (narration): 210° to 330° → center at 270°
    final narrationIconPos = _wedgeIconOffset(270); // left
    final soundscapeIconPos = _wedgeIconOffset(30); // right
    final practiceIconPos = _wedgeIconOffset(150); // bottom

    return GestureDetector(
      onTapUp: (details) {
        final zone = _hitTestWedge(details.localPosition);
        if (zone != null) _onWedgeTap(zone);
      },
      child: Container(
        width: _circleSize,
        height: _circleSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color.fromRGBO(10, 15, 25, 0.50),
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
                    // Left wedge icon (narration)
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
                    // Right wedge icon (soundscape)
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
                    // Bottom wedge icon (practice/mic)
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
                    // Center grip handle
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
        onPanStart: (_) => setState(() => _isDragging = true),
        onPanUpdate: (details) {
          final next = _clampOffset(
            candidate: _dragOffset + details.delta,
            viewportSize: viewportSize,
            safePadding: safePadding,
            baseBottom: baseBottom,
          );
          setState(() => _dragOffset = next);
        },
        onPanEnd: (_) => setState(() => _isDragging = false),
        onPanCancel: () => setState(() => _isDragging = false),
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
    final clampedOffset = _clampOffset(
      candidate: _dragOffset,
      viewportSize: viewportSize,
      safePadding: safePadding,
      baseBottom: baseBottom,
    );

    if (clampedOffset != _dragOffset) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _dragOffset = clampedOffset);
      });
    }

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !widget.isVisible,
        child: AnimatedOpacity(
          opacity: widget.isVisible ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: AnimatedSlide(
            offset: widget.isVisible ? Offset.zero : const Offset(0, 0.3),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Transform.translate(
                offset: clampedOffset,
                child: AnimatedScale(
                  scale: _isDragging ? 1.035 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: SizedBox(
                    key: _pillKey,
                    width: _circleSize,
                    height: _circleSize,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        if (_isDragging)
                          IgnorePointer(
                            child: Transform.translate(
                              offset: const Offset(0, 10),
                              child: Opacity(
                                opacity: 0.18,
                                child: _buildCircleBody(
                                  viewportSize: viewportSize,
                                  safePadding: safePadding,
                                  baseBottom: baseBottom,
                                ),
                              ),
                            ),
                          ),
                        _buildCircleBody(
                          viewportSize: viewportSize,
                          safePadding: safePadding,
                          baseBottom: baseBottom,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: StoriaMotion.medium),
                ),
              ),
            ),
          ),
        ),
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

    // Three 120° wedges. Start angles (from 3-o'clock, clockwise):
    // Right (soundscape): -30° to 90°   → startAngle = -30°
    // Bottom (practice):  90° to 210°   → startAngle = 90°
    // Left (narration):   210° to 330°  → startAngle = 210°
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

    // Draw active wedge fills.
    for (final w in wedges) {
      if (!w.active) continue;
      final paint = Paint()
        ..color = w.color.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;
      canvas.drawArc(rect, w.startAngle, sweep, true, paint);
    }

    // Draw divider lines from grip edge to outer edge at boundary angles.
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
                  value: value,
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.auto_stories_rounded,
              color: Color(0xFFC5CBD8),
              size: 34,
            ),
            const SizedBox(height: 12),
            Text(
              'This story could not be loaded',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFFC5CBD8)),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
