import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../audio/audio_engine.dart';
import '../../audio/audio_providers.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import 'page_renderer.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final String bookId;

  const ReaderScreen({super.key, required this.bookId});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final PageController _pageController = PageController();
  final ValueNotifier<Duration> _narrationPositionNotifier = ValueNotifier(
    Duration.zero,
  );
  int _activePageIndex = 0;
  bool _isNarrationPlaying = false;
  bool _isSoundscapePlaying = false;
  bool _showChrome = true;
  bool _loadedInitialAudio = false;
  double _narrationVolume = 1;
  double _soundscapeVolume = 0.6;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<bool>? _narrationPlayingSubscription;
  StreamSubscription<bool>? _soundscapePlayingSubscription;

  @override
  void initState() {
    super.initState();
    final audioEngine = ref.read(audioEngineProvider);
    audioEngine.ensureInitialized();

    _positionSubscription = audioEngine.narrationPosition.listen((position) {
      if (!mounted) return;
      _narrationPositionNotifier.value = position;
    });

    _narrationPlayingSubscription = audioEngine.narrationPlaying.listen((
      playing,
    ) {
      if (!mounted) return;
      setState(() => _isNarrationPlaying = playing);
    });

    _soundscapePlayingSubscription = audioEngine.soundscapePlaying.listen((
      playing,
    ) {
      if (!mounted) return;
      setState(() => _isSoundscapePlaying = playing);
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _narrationPlayingSubscription?.cancel();
    _soundscapePlayingSubscription?.cancel();
    _narrationPositionNotifier.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(currentBookProvider(widget.bookId));
    final audioEngine = ref.watch(audioEngineProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == .dark
          ? Theme.of(context).colorScheme.surface
          : const Color(0xFF121A24),
      body: bookAsync.when(
        data: (book) {
          if (book == null) {
            return const Center(child: Text('Book not found'));
          }

          if (book.pages.isEmpty) {
            return const Center(child: Text('No pages in this book'));
          }

          if (_activePageIndex >= book.pages.length) {
            _activePageIndex = book.pages.length - 1;
          }

          final activePage = book.pages[_activePageIndex];
          final hasNarration = (activePage.narrationUrl ?? '').isNotEmpty;
          final hasSoundscape = (activePage.soundscapeUrl ?? '').isNotEmpty;

          if (!_loadedInitialAudio) {
            _loadedInitialAudio = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await audioEngine.loadPage(book.pages[_activePageIndex]);
            });
          }

          return Stack(
            children: [
              GestureDetector(
                behavior: .translucent,
                excludeFromSemantics: true,
                onTap: () => setState(() => _showChrome = !_showChrome),
                child: PageView.builder(
                  controller: _pageController,
                  scrollDirection: .vertical,
                  itemCount: book.pages.length,
                  onPageChanged: (index) async {
                    setState(() {
                      _activePageIndex = index;
                    });
                    await audioEngine.transitionToPage(book.pages[index]);
                  },
                  itemBuilder: (context, index) {
                    final isInVirtualizationWindow =
                        (index - _activePageIndex).abs() <= 1;
                    if (!isInVirtualizationWindow) {
                      return const SizedBox.shrink();
                    }
                    final page = book.pages[index];
                    return ValueListenableBuilder<Duration>(
                      valueListenable: _narrationPositionNotifier,
                      builder: (context, narrationPosition, child) {
                        return PageRenderer(
                          page: page,
                          narrationPosition: narrationPosition,
                          isActive: index == _activePageIndex,
                        );
                      },
                    );
                  },
                ),
              ),
              // Top chrome
              IgnorePointer(
                ignoring: !_showChrome,
                child: AnimatedOpacity(
                  opacity: _showChrome ? 1 : 0,
                  duration: 220.ms,
                  curve: Curves.easeOut,
                  child: _ReaderTopBar(
                    book: book,
                    activePageNumber: activePage.pageNumber,
                    onClose: () => Navigator.of(context).maybePop(),
                    onAudioSettingsTap: () =>
                        _showAudioSettings(context, audioEngine),
                  ),
                ),
              ),
              // Bottom audio controls
              if (hasNarration || hasSoundscape)
                _AudioControlsPill(
                  hasNarration: hasNarration,
                  hasSoundscape: hasSoundscape,
                  isNarrationPlaying: _isNarrationPlaying,
                  isSoundscapePlaying: _isSoundscapePlaying,
                  isVisible: _showChrome,
                  onToggleNarration: () => audioEngine.toggleNarration(),
                  onToggleSoundscape: () => audioEngine.toggleSoundscape(),
                ),
            ],
          );
        },
        loading: () => const _ReaderLoadingState(),
        error: (error, _) => _ReaderErrorState(
          error: '$error',
          onRetry: () => ref.invalidate(currentBookProvider(widget.bookId)),
        ),
      ),
    );
  }

  Future<void> _showAudioSettings(
    BuildContext context,
    AudioEngine audioEngine,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFF9F8F4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              child: Column(
                mainAxisSize: .min,
                crossAxisAlignment: .start,
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
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 26,
                      fontWeight: .w700,
                      color: const Color(0xFF2E2A3D),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _VolumeRow(
                    icon: Icons.record_voice_over_rounded,
                    label: 'Narration',
                    semanticsLabel: 'Narration volume',
                    value: _narrationVolume,
                    onChanged: (value) async {
                      setModalState(() => _narrationVolume = value);
                      if (mounted) {
                        setState(() => _narrationVolume = value);
                      }
                      await audioEngine.setNarrationVolume(value);
                    },
                  ),
                  const SizedBox(height: 14),
                  _VolumeRow(
                    icon: Icons.surround_sound_rounded,
                    label: 'Ambience',
                    semanticsLabel: 'Ambience volume',
                    value: _soundscapeVolume,
                    onChanged: (value) async {
                      setModalState(() => _soundscapeVolume = value);
                      if (mounted) {
                        setState(() => _soundscapeVolume = value);
                      }
                      await audioEngine.setSoundscapeVolume(value);
                    },
                  ),
                ],
              ),
            );
          },
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
                  begin: .topCenter,
                  end: .bottomCenter,
                  colors: [Color.fromRGBO(8, 12, 17, 0.75), Colors.transparent],
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
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(10, 16, 26, 0.58),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color.fromRGBO(255, 255, 255, 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: .start,
                    mainAxisSize: .min,
                    children: [
                      Text(
                        book.title,
                        maxLines: 1,
                        overflow: .ellipsis,
                        style: GoogleFonts.lora(
                          fontSize: 14,
                          fontWeight: .w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Page $activePageNumber of ${book.pages.length}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: .w600,
                          color: const Color(0xFFD4D8E0),
                        ),
                      ),
                    ],
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
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(10, 16, 26, 0.72),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: const Color.fromRGBO(255, 255, 255, 0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: .min,
                  children: [
                    if (hasNarration)
                      _AudioIconButton(
                        icon: isNarrationPlaying
                            ? Icons.pause_rounded
                            : Icons.mic_rounded,
                        accentColor: _narrationColor,
                        isPlaying: isNarrationPlaying,
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
                            : Icons.music_note_rounded,
                        accentColor: _soundscapeColor,
                        isPlaying: isSoundscapePlaying,
                        semanticLabel: 'Ambience',
                        onTap: onToggleSoundscape,
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
}

class _AudioIconButton extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final bool isPlaying;
  final String semanticLabel;
  final Future<void> Function() onTap;

  const _AudioIconButton({
    required this.icon,
    required this.accentColor,
    required this.isPlaying,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: isPlaying,
      label: semanticLabel,
      hint: 'Double tap to ${isPlaying ? 'pause' : 'play'} $semanticLabel',
      value: isPlaying ? 'On' : 'Off',
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          alignment: .center,
          children: [
            // Glow ring behind button when active.
            AnimatedOpacity(
              opacity: isPlaying ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: .circle,
                  color: accentColor.withValues(alpha: 0.25),
                ),
              ),
            ),
            // Button circle.
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: .circle,
                color: const Color.fromRGBO(255, 255, 255, 0.06),
                border: Border.all(
                  color: isPlaying
                      ? accentColor
                      : const Color.fromRGBO(255, 255, 255, 0.08),
                  width: isPlaying ? 1.5 : 0.5,
                ),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isPlaying
                    ? accentColor
                    : const Color.fromRGBO(255, 255, 255, 0.7),
              ),
            ),
            // Pulsing dot indicator.
            if (isPlaying)
              Positioned(
                top: 6,
                right: 6,
                child: _PulsingDot(color: accentColor),
              ),
          ],
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
              decoration: BoxDecoration(shape: .circle, color: widget.color),
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
      child: Material(
        color: const Color.fromRGBO(255, 255, 255, 0.14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color.fromRGBO(255, 255, 255, 0.18)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, color: Colors.white, size: 21),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E4DE)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF585374)),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: .w700,
                color: const Color(0xFF2E2A3D),
              ),
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
                  activeColor: const Color(0xFF6F61C7),
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
          Text(
            '${(value * 100).round()}%',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: .w700,
              color: const Color(0xFF6B7280),
            ),
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
        mainAxisSize: .min,
        children: [
          const CircularProgressIndicator(color: Color(0xFF8A80CC)),
          const SizedBox(height: 14),
          Text(
            'Opening your story...',
            style: GoogleFonts.inter(
              color: const Color(0xFFC5CBD8),
              fontWeight: .w600,
            ),
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
          mainAxisSize: .min,
          children: [
            const Icon(
              Icons.auto_stories_rounded,
              color: Color(0xFFC5CBD8),
              size: 34,
            ),
            const SizedBox(height: 12),
            Text(
              'This story could not be loaded',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: .w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: .center,
              style: GoogleFonts.inter(
                color: const Color(0xFFC5CBD8),
                fontSize: 12,
              ),
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
