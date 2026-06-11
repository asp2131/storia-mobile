import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/resilient_cache_manager.dart';
import '../../data/models.dart';
import 'overlay/overlay_layout_engine.dart';
import 'overlay/overlay_text_layer.dart';
import 'overlay/text_overlay_utils.dart';
import 'pronunciation_highlight.dart';

// Parallax multipliers for depth-layer illusion (Feature 1).
// The active page is at localOffset 0. As user scrolls, localOffset goes from
// ~ -1 (page above) to 0 (active) to ~ +1 (page below). Layers translate by
// `localOffset * pageHeight * multiplier` so slower layers lag, faster layers
// lead, creating depth.
const double _kBackgroundParallax = 0.5;
const double _kTextParallax = 1.0;

class PageRenderer extends StatefulWidget {
  final PageData page;
  final int pageIndex;
  final ValueListenable<double>? scrollOffsetListenable;
  final Duration narrationPosition;
  final bool isActive;
  final String? heroTag;
  final void Function(String word, int globalIndex)? onWordTap;
  final void Function(String word, int globalIndex)? onWordLongPress;
  final Set<int> spokenWordIndices;
  final int? tappedWordIndex;
  final List<PronunciationHighlightPart> tappedWordHighlightParts;
  final int? activeTappedWordHighlightPartIndex;

  const PageRenderer({
    super.key,
    required this.page,
    this.pageIndex = 0,
    this.scrollOffsetListenable,
    required this.narrationPosition,
    required this.isActive,
    this.heroTag,
    this.onWordTap,
    this.onWordLongPress,
    this.spokenWordIndices = const {},
    this.tappedWordIndex,
    this.tappedWordHighlightParts = const [],
    this.activeTappedWordHighlightPartIndex,
  });

  @override
  State<PageRenderer> createState() => _PageRendererState();
}

class _PageRendererState extends State<PageRenderer> {
  static const OverlayLayoutEngine _overlayEngine = OverlayLayoutEngineImpl();

  Size? _sourceImageSize;

  @override
  void initState() {
    super.initState();
    _resolveImageDimensions();
  }

  @override
  void didUpdateWidget(covariant PageRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page.imageUrl != widget.page.imageUrl) {
      _sourceImageSize = null;
      _resolveImageDimensions();
    }
  }

  Future<void> _resolveImageDimensions() async {
    final imageUrl = widget.page.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return;
    }

    final completer = Completer<Size>();
    final stream = CachedNetworkImageProvider(
      imageUrl,
      cacheManager: ResilientCacheManager.instance,
    ).resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (image, _) {
        if (!completer.isCompleted) {
          completer.complete(
            Size(image.image.width.toDouble(), image.image.height.toDouble()),
          );
        }
        stream.removeListener(listener);
      },
      onError: (_, __) {
        if (!completer.isCompleted) {
          completer.complete(Size.zero);
        }
        stream.removeListener(listener);
      },
    );

    stream.addListener(listener);
    final size = await completer.future;
    if (!mounted) {
      return;
    }
    setState(() {
      _sourceImageSize = size;
    });
  }

  double _localOffsetFor(double scrollOffset) =>
      scrollOffset - widget.pageIndex;

  @override
  Widget build(BuildContext context) => _buildStandardPage();

  Widget _buildStandardPage() {
    final page = widget.page;
    final hasOverlay =
        page.overlay != null && page.overlay!.elements.isNotEmpty;
    final hasFallbackText =
        (page.textContent ?? '').trim().isNotEmpty &&
        (page.imageUrl ?? '').isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final container = Size(constraints.maxWidth, constraints.maxHeight);
        final sourceImageSize = _sourceImageSize;
        final imageRect = hasOverlay && sourceImageSize != null
            ? computeContainedImageRect(
                container: container,
                sourceImage: sourceImageSize,
              )
            : Rect.fromLTWH(0, 0, container.width, container.height);

        final activeWordIndex = computeActiveWordIndex(
          page.narrationTimestamps,
          widget.narrationPosition,
        );

        final Widget imageLayer =
            page.imageUrl != null && page.imageUrl!.isNotEmpty
            ? _buildPageImage()
            : const ColoredBox(color: Color(0xFFDDDDD4));

        // Overlay text is sized/positioned against the *contained* image rect,
        // which needs the resolved source-image dimensions. Until those arrive,
        // `imageRect` falls back to the full container (taller than the
        // letterboxed image), which would render the text oversized for one
        // frame and then snap to the correct size. Gate on `sourceImageSize` so
        // the text appears together with the illustration at the right scale.
        final Widget textLayer =
            hasOverlay &&
                page.overlay != null &&
                sourceImageSize != null &&
                imageRect != Rect.zero
            ? Positioned(
                left: imageRect.left,
                top: imageRect.top,
                width: imageRect.width,
                height: imageRect.height,
                child: OverlayTextLayer(
                  frame: _overlayEngine.build(
                    overlay: page.overlay!,
                    imageSize: imageRect.size,
                    activeWordIndex: activeWordIndex,
                    spokenWordIndices: widget.spokenWordIndices,
                    isActive: widget.isActive,
                    tappedWordIndex: widget.tappedWordIndex,
                    tappedWordHighlightParts: widget.tappedWordHighlightParts,
                    activeTappedWordHighlightPartIndex:
                        widget.activeTappedWordHighlightPartIndex,
                  ),
                  onWordTap: widget.onWordTap,
                  onWordLongPress: widget.onWordLongPress,
                ),
              )
            : (!hasOverlay && hasFallbackText)
            ? _buildFallbackText(page)
            : const SizedBox.shrink();

        return Stack(
          fit: StackFit.expand,
          children: [
            _parallaxLayer(
              multiplier: _kBackgroundParallax,
              pageHeight: container.height,
              child: imageLayer,
            ),
            // Text layer stays at neutral parallax (multiplier 1.0 = 0 shift)
            // and must remain a direct child of Stack so Positioned works.
            textLayer,
          ],
        );
      },
    );
  }

  /// Wraps [child] in a scroll-driven parallax transform. If no scroll
  /// listenable was provided, the child is rendered as-is (no extra rebuilds).
  ///
  /// Parallax range is bounded: the translation is `localOffset * pageHeight *
  /// (multiplier - 1.0)` relative to a neutral layer, then clamped so no layer
  /// ever exceeds ~30% of page height of vertical shift.
  Widget _parallaxLayer({
    required double multiplier,
    required double pageHeight,
    required Widget child,
  }) {
    final listenable = widget.scrollOffsetListenable;
    if (listenable == null) {
      return child;
    }
    return ValueListenableBuilder<double>(
      valueListenable: listenable,
      child: child,
      builder: (context, scrollOffset, child) {
        final localOffset = _localOffsetFor(scrollOffset);
        // Raw shift in logical pixels. At localOffset = 1, a layer with
        // multiplier = 1 shifts by pageHeight (one full page). With multiplier
        // = 0.5 the layer shifts half — producing the "slower" depth look.
        // We subtract `localOffset * pageHeight` (baseline page scroll) from
        // each layer so the neutral 1.0 layer has zero translation. The result
        // is a relative parallax offset vs. the base page motion.
        final relativeShift =
            localOffset * pageHeight * (multiplier - _kTextParallax);
        final bounded = relativeShift.clamp(
          -pageHeight * 0.3,
          pageHeight * 0.3,
        );
        return Transform.translate(offset: Offset(0, bounded), child: child!);
      },
    );
  }

  Widget _buildFallbackText(PageData page) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 112),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Color.fromRGBO(3, 8, 16, 0.56),
              Color.fromRGBO(2, 6, 12, 0.9),
            ],
            stops: [0, 0.33, 1],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child:
                DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(10, 18, 28, 0.52),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color.fromRGBO(255, 255, 255, 0.2),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, 0.24),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Text(
                          page.textContent ?? '',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.lora(
                            color: const Color(0xFFF8FAFC),
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            height: 1.38,
                            shadows: const [
                              Shadow(
                                blurRadius: 10,
                                offset: Offset(0, 2),
                                color: Color.fromRGBO(0, 0, 0, 0.35),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .animate(target: widget.isActive ? 1 : 0)
                    .fadeIn(
                      delay: 120.ms,
                      duration: 340.ms,
                      curve: Curves.easeOut,
                    )
                    .slideY(
                      begin: 0.08,
                      end: 0,
                      delay: 120.ms,
                      duration: 340.ms,
                      curve: Curves.easeOutCubic,
                    ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageImage() {
    final image = Image(
      image: CachedNetworkImageProvider(
        widget.page.imageUrl!,
        cacheManager: ResilientCacheManager.instance,
      ),
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
    );

    final heroTag = widget.heroTag;
    if (heroTag == null) {
      return image;
    }

    return Hero(tag: heroTag, child: image);
  }
}
