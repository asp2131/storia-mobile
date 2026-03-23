import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/resilient_cache_manager.dart';
import '../../data/models.dart';
import 'overlay/overlay_text_layer.dart';
import 'overlay/text_overlay_utils.dart';

class PageRenderer extends StatefulWidget {
  final PageData page;
  final Duration narrationPosition;
  final bool isActive;
  final String? heroTag;
  final void Function(String word, int globalIndex)? onWordTap;
  final Set<int> spokenWordIndices;

  const PageRenderer({
    super.key,
    required this.page,
    required this.narrationPosition,
    required this.isActive,
    this.heroTag,
    this.onWordTap,
    this.spokenWordIndices = const {},
  });

  @override
  State<PageRenderer> createState() => _PageRendererState();
}

class _PageRendererState extends State<PageRenderer> {
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

  @override
  Widget build(BuildContext context) {
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

        return Stack(
          fit: StackFit.expand,
          children: [
            if (page.imageUrl != null && page.imageUrl!.isNotEmpty)
              _buildPageImage(hasOverlay)
            else
              const ColoredBox(color: Color(0xFFDDDDD4)),
            if (hasOverlay && page.overlay != null && imageRect != Rect.zero)
              Positioned(
                left: imageRect.left,
                top: imageRect.top,
                width: imageRect.width,
                height: imageRect.height,
                child: OverlayTextLayer(
                  overlay: page.overlay!,
                  imageSize: imageRect.size,
                  activeWordIndex: activeWordIndex,
                  spokenWordIndices: widget.spokenWordIndices,
                  isActive: widget.isActive,
                  onWordTap: widget.onWordTap,
                ),
              ),
            if (!hasOverlay && hasFallbackText)
              Align(
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
                                    color: const Color.fromRGBO(
                                      255,
                                      255,
                                      255,
                                      0.2,
                                    ),
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
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    14,
                                    16,
                                    14,
                                  ),
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
              ),
          ],
        );
      },
    );
  }

  Widget _buildPageImage(bool hasOverlay) {
    final image = Image(
      image: CachedNetworkImageProvider(
        widget.page.imageUrl!,
        cacheManager: ResilientCacheManager.instance,
      ),
      fit: hasOverlay ? BoxFit.contain : .cover,
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
