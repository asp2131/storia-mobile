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
  double _scrollOffset = 0.0;
  late final ConfettiController _confettiController;
  bool _showCelebrationGif = false;
  late GifPlayerController _gifPlayerController;

  late final ReaderSession _session;
  StreamSubscription<ReaderViewState>? _sessionSubscription;
  ReaderViewState _runtimeState = const ReaderViewState.initial();
  String? _initializedBookId;

  @override
  void initState() {
    super.initState();
    _session = ref.read(readerSessionProvider);
    _sessionSubscription = _session.states.listen(_onRuntimeStateChanged);

    _pageController.addListener(_onPageScroll);
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _gifPlayerController = GifPlayerController(
      dataSource: GifPlayerDataSource.asset('assets/gifs/green_screen.gif'),
      isAutoPlay: false,
      isAutoInitialize: true,
      loop: true,
      showControls: false,
    );
  }

  void _onRuntimeStateChanged(ReaderViewState next) {
    final wasCelebrating = _runtimeState.showCelebration;
    final isCelebrating = next.showCelebration;

    if (mounted) {
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
    if (page != null) setState(() => _scrollOffset = page);
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _showChromeNotifier.dispose();
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
              _session.dispatch(ReaderStart(book: book));
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
                    if (!isInVirtualizationWindow) return const SizedBox.shrink();

                    final page = book.pages[index];
                    final heroTag = index == 0 && (book.coverUrl ?? '').isNotEmpty
                        ? 'book-cover-${book.id}'
                        : null;

                    final localOffset = _scrollOffset - index;

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
                      child: PageRenderer(
                        page: page,
                        narrationPosition: _runtimeState.narrationPosition,
                        isActive: index == activeIndex,
                        heroTag: heroTag,
                        spokenWordIndices: _runtimeState.spokenWordIndices,
                      ),
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
                        isPracticeMode: _runtimeState.isPracticeMode,
                        isListening: _runtimeState.isListening,
                        onPracticeToggle: () {
                          _session.dispatch(const ReaderPracticePrimaryAction());
                        },
                      ),
                    ),
                  );
                },
              ),
              if (hasNarration || hasSoundscape)
                _AudioControlsPill(
                  hasNarration: hasNarration,
                  hasSoundscape: hasSoundscape,
                  isNarrationPlaying: _runtimeState.isNarrationPlaying,
                  isSoundscapePlaying: _runtimeState.isSoundscapePlaying,
                  isVisible: true,
                  onToggleNarration: () =>
                      _session.dispatch(const ReaderToggleNarration()),
                  onToggleSoundscape: () =>
                      _session.dispatch(const ReaderToggleSoundscape()),
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
                    duration: Duration(milliseconds: _showCelebrationGif ? 300 : 500),
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
  final bool isPracticeMode;
  final bool isListening;
  final VoidCallback onPracticeToggle;

  const _ReaderTopBar({
    required this.book,
    required this.activePageNumber,
    required this.onClose,
    required this.onAudioSettingsTap,
    required this.isPracticeMode,
    required this.isListening,
    required this.onPracticeToggle,
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
                icon: isListening
                    ? Icons.mic_rounded
                    : isPracticeMode
                        ? Icons.mic_none_rounded
                        : Icons.menu_book_rounded,
                color: isPracticeMode ? const Color(0xFFF59E0B) : Colors.white,
                onTap: onPracticeToggle,
                semanticLabel: isPracticeMode ? 'Stop practice' : 'Practice reading',
                semanticHint: isPracticeMode
                    ? 'Tap to stop reading practice'
                    : 'Tap to start reading practice',
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
// Bottom audio controls pill — separate narration & soundscape toggles
// =============================================================================

const _narrationColor = Color(0xFFF59E0B); // Warm amber
const _soundscapeColor = Color(0xFF14B8A6); // Teal

class _AudioControlsPill extends StatelessWidget {
  final bool hasNarration;
  final bool hasSoundscape;
  final bool isNarrationPlaying;
  final bool isSoundscapePlaying;
  final bool isVisible;
  final Future<void> Function() onToggleNarration;
  final Future<void> Function() onToggleSoundscape;

  const _AudioControlsPill({
    required this.hasNarration,
    required this.hasSoundscape,
    required this.isNarrationPlaying,
    required this.isSoundscapePlaying,
    required this.isVisible,
    required this.onToggleNarration,
    required this.onToggleSoundscape,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: math.max(28, bottomInset + 12),
      child: IgnorePointer(
        ignoring: !isVisible,
        child: AnimatedOpacity(
          opacity: isVisible ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: AnimatedSlide(
            offset: isVisible ? Offset.zero : const Offset(0, 0.3),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: Center(
              child: ClipPath(
                clipper: ShapeBorderClipper(
                  shape: const SketchBorderShape(
                    side: BorderSide(
                      color: Color.fromRGBO(255, 255, 255, 0.18),
                      width: 1.1,
                    ),
                    radiusScale: 0.9,
                  ),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: DecoratedBox(
                    decoration: const ShapeDecoration(
                      color: Color.fromRGBO(10, 15, 25, 0.40),
                      shape: SketchBorderShape(
                        side: BorderSide(
                          color: Color.fromRGBO(255, 255, 255, 0.18),
                          width: 1.1,
                        ),
                        radiusScale: 0.9,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasNarration)
                            _AudioIconButton(
                              icon: isNarrationPlaying
                                  ? Icons.pause_rounded
                                  : Icons.headphones_rounded,
                              accentColor: _narrationColor,
                              isPlaying: isNarrationPlaying,
                              label: 'Story',
                              semanticLabel: 'Narration',
                              onTap: onToggleNarration,
                            ),
                          if (hasNarration && hasSoundscape)
                            Container(
                              width: 1,
                              height: 24,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              color: const Color.fromRGBO(255, 255, 255, 0.12),
                            ),
                          if (hasSoundscape)
                            _AudioIconButton(
                              icon: isSoundscapePlaying
                                  ? Icons.volume_up_rounded
                                  : Icons.waves_rounded,
                              accentColor: _soundscapeColor,
                              isPlaying: isSoundscapePlaying,
                              label: 'Music',
                              semanticLabel: 'Ambience',
                              onTap: onToggleSoundscape,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: StoriaMotion.medium),
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioIconButton extends StatefulWidget {
  final IconData icon;
  final Color accentColor;
  final bool isPlaying;
  final String label;
  final String semanticLabel;
  final Future<void> Function() onTap;

  const _AudioIconButton({
    required this.icon,
    required this.accentColor,
    required this.isPlaying,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  State<_AudioIconButton> createState() => _AudioIconButtonState();
}

class _AudioIconButtonState extends State<_AudioIconButton>
    with TickerProviderStateMixin {
  late final AnimationController _breathController;
  late final AnimationController _pressController;
  late final Animation<double> _breathAnimation;
  late final Animation<double> _pressAnimation;

  @override
  void initState() {
    super.initState();

    // Breathing idle pulse — gentle scale when not playing
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _breathAnimation = Tween<double>(begin: 1.0, end: 1.07).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );
    if (!widget.isPlaying) {
      _breathController.repeat(reverse: true);
    }

    // Press bounce
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _pressAnimation = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(_AudioIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _breathController.stop();
        _breathController.animateTo(0);
      } else {
        _breathController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _breathController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _pressController.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _pressController.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: widget.isPlaying,
      label: widget.semanticLabel,
      hint: 'Double tap to ${widget.isPlaying ? 'pause' : 'play'} ${widget.semanticLabel}',
      value: widget.isPlaying ? 'On' : 'Off',
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedBuilder(
          animation: Listenable.merge([_breathAnimation, _pressAnimation]),
          builder: (context, child) {
            final scale = _pressAnimation.value * _breathAnimation.value;
            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  // Glow ring behind button when active.
                  AnimatedOpacity(
                    opacity: widget.isPlaying ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.accentColor.withValues(alpha: 0.28),
                      ),
                    ),
                  ),
                  // Button circle — filled with accent when playing.
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isPlaying
                          ? widget.accentColor.withValues(alpha: 0.88)
                          : const Color.fromRGBO(255, 255, 255, 0.08),
                      border: Border.all(
                        color: widget.isPlaying
                            ? widget.accentColor
                            : const Color.fromRGBO(255, 255, 255, 0.22),
                        width: widget.isPlaying ? 2.0 : 1.0,
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 24,
                      color: widget.isPlaying
                          ? Colors.white
                          : const Color.fromRGBO(255, 255, 255, 0.85),
                    ),
                  ),
                  // Pulsing dot indicator when playing.
                  if (widget.isPlaying)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _PulsingDot(color: widget.accentColor),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Opacity(
          opacity: 0.4 + t * 0.6,
          child: Transform.scale(
            scale: 0.6 + t * 0.4,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// Shared chrome button
// =============================================================================

class _ChromeButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final String semanticHint;
  final Color color;

  const _ChromeButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    required this.semanticHint,
    this.color = Colors.white,
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
                child: Icon(icon, color: color, size: 21),
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
