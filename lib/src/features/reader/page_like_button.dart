import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/storia_colors.dart';
import '../../data/analytics_repository.dart';
import '../../data/providers.dart';

typedef PageLikesKey = ({String? childId, String bookId});

/// Like counts per page id for one reader and book.
///
/// ponytail: device-local (SharedPreferences) plus an analytics event per tap
/// burst. Add a synced table when likes must follow a child across devices or
/// feed a "favorite pages" shelf.
final pageLikesProvider = StateNotifierProvider.autoDispose
    .family<PageLikesNotifier, Map<String, int>, PageLikesKey>(
      (ref, key) => PageLikesNotifier(key),
    );

typedef GuestLikeReporter =
    Future<void> Function({
      required String bookId,
      required int pageNumber,
      required int likes,
    });

/// Counts likes from readers who have not signed up.
///
/// Sends the book, page number and like count only. No account, device or
/// session identifier goes with it: these readers have no parent consent.
final guestLikeReporterProvider = Provider<GuestLikeReporter>((ref) {
  return ({required bookId, required pageNumber, required likes}) async {
    // Only catalog books have numeric ids; the bundled sample is not counted.
    if (!RegExp(r'^[1-9]\d*$').hasMatch(bookId)) return;
    try {
      final base = ref
          .read(apiBaseUrlProvider)
          .trim()
          .replaceFirst(RegExp(r'/+$'), '');
      await ref
          .read(analyticsHttpClientProvider)
          .post(
            Uri.parse('$base/api/analytics/guest-likes'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'bookId': bookId,
              'pageNumber': pageNumber,
              'likes': likes,
            }),
          );
    } catch (_) {
      // Counting is best effort and must never disturb reading.
    }
  };
});

class PageLikesNotifier extends StateNotifier<Map<String, int>> {
  PageLikesNotifier(PageLikesKey key)
    // Hashed so the preference key never exposes a child identifier.
    : _storageKey =
          'page_likes.v1.${sha256.convert(utf8.encode(jsonEncode([key.childId, key.bookId])))}',
      super(const {}) {
    _ready = _load();
  }

  final String _storageKey;
  late final Future<void> _ready;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || !mounted) return;
      final stored = jsonDecode(raw);
      if (stored is! Map) return;
      // Taps that landed before the read finished are added on top.
      final merged = <String, int>{
        for (final entry in stored.entries)
          if (entry.value is int) '${entry.key}': entry.value as int,
      };
      state.forEach((id, count) => merged[id] = (merged[id] ?? 0) + count);
      state = merged;
    } catch (_) {
      // Likes are a nicety; unreadable storage just starts from zero.
    }
  }

  Future<void> like(String pageId) async {
    state = {...state, pageId: (state[pageId] ?? 0) + 1};
    // Never write before the stored counts are merged in, or they are lost.
    await _ready;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(state));
    } catch (_) {
      // Keep the in-memory count; the next tap retries the write.
    }
  }
}

/// Heart button a reader can tap as many times as they like on a page.
///
/// Must be a direct child of the reader [Stack].
class PageLikeButton extends ConsumerStatefulWidget {
  const PageLikeButton({
    super.key,
    required this.childId,
    required this.bookId,
    required this.pageId,
    required this.pageNumber,
    required this.trackAnalytics,
    this.countGuestLikes = false,
    this.repeatable = true,
  });

  /// Null for guest and sample readers, who share one local tally.
  final String? childId;
  final String bookId;
  final String pageId;
  final int pageNumber;

  /// Signed-in reader: send like events tied to the child profile.
  final bool trackAnalytics;

  /// Reader without an account: add to the anonymous per-page counter.
  final bool countGuestLikes;

  /// Signed-in kids can like a page again and again. Readers without an
  /// account get one like per page, so anonymous counts stay meaningful.
  final bool repeatable;

  @override
  ConsumerState<PageLikeButton> createState() => _PageLikeButtonState();
}

class _PageLikeButtonState extends ConsumerState<PageLikeButton> {
  static const _size = 56.0;
  static const _maxFloaters = 12;

  final _floaters = <int>[];
  int _taps = 0;

  // One analytics event per burst of taps, not one per tap.
  AnalyticsRepository? _analytics;
  GuestLikeReporter? _guestReporter;
  Timer? _flushTimer;
  int _pendingLikes = 0;
  int _pendingTotal = 0;

  PageLikesKey get _key => (childId: widget.childId, bookId: widget.bookId);

  @override
  void didUpdateWidget(PageLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageId != widget.pageId) {
      _flush(pageId: oldWidget.pageId, pageNumber: oldWidget.pageNumber);
    }
  }

  @override
  void dispose() {
    _flush(pageId: widget.pageId, pageNumber: widget.pageNumber);
    super.dispose();
  }

  void _like() {
    if (!widget.repeatable &&
        (ref.read(pageLikesProvider(_key))[widget.pageId] ?? 0) > 0) {
      return;
    }
    HapticFeedback.lightImpact();
    final notifier = ref.read(pageLikesProvider(_key).notifier);
    unawaited(notifier.like(widget.pageId));

    if (widget.trackAnalytics || widget.countGuestLikes) {
      if (widget.trackAnalytics) {
        _analytics ??= ref.read(analyticsRepositoryProvider);
      } else {
        _guestReporter ??= ref.read(guestLikeReporterProvider);
      }
      _pendingLikes++;
      _pendingTotal = ref.read(pageLikesProvider(_key))[widget.pageId] ?? 0;
      _flushTimer?.cancel();
      _flushTimer = Timer(
        const Duration(milliseconds: 1200),
        () => _flush(pageId: widget.pageId, pageNumber: widget.pageNumber),
      );
    }

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    setState(() {
      _taps++;
      if (reduceMotion) return;
      if (_floaters.length >= _maxFloaters) _floaters.removeAt(0);
      _floaters.add(_taps);
    });
  }

  void _flush({required String pageId, required int pageNumber}) {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_pendingLikes == 0) return;
    unawaited(
      _analytics?.track(
        AnalyticsEventType.pageInteracted,
        bookId: widget.bookId,
        pageId: pageId,
        pageNumber: pageNumber,
        metadata: {
          'interactionType': 'page_liked',
          'likes': _pendingLikes,
          'totalLikes': _pendingTotal,
        },
      ),
    );
    unawaited(
      _guestReporter?.call(
        bookId: widget.bookId,
        pageNumber: pageNumber,
        likes: _pendingLikes,
      ),
    );
    _pendingLikes = 0;
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(
      pageLikesProvider(_key).select((likes) => likes[widget.pageId] ?? 0),
    );
    final liked = count > 0;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      right: 16,
      // Sits level with the audio dial (120px, same base inset).
      bottom: math.max(28.0, safeBottom + 12.0) + 14,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                button: true,
                label: 'Love this page',
                value: count == 1 ? '1 like' : '$count likes',
                hint: widget.repeatable
                    ? 'Tap as many times as you like'
                    : (liked ? 'You love this page' : 'Tap to love this page'),
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Material(
                      color: const Color.fromRGBO(10, 15, 25, 0.35),
                      shape: const CircleBorder(
                        side: BorderSide(
                          color: Color.fromRGBO(255, 255, 255, 0.28),
                        ),
                      ),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _like,
                        child: SizedBox(
                          width: _size,
                          height: _size,
                          // Re-keyed per tap so every like pops again.
                          child: TweenAnimationBuilder<double>(
                            key: ValueKey(_taps),
                            tween: Tween(begin: _taps == 0 ? 1 : 1.45, end: 1),
                            duration: const Duration(milliseconds: 420),
                            curve: Curves.elasticOut,
                            builder: (context, scale, child) =>
                                Transform.scale(scale: scale, child: child),
                            child: Icon(
                              liked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: liked ? StoriaColors.heart : Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 18,
                child: liked && widget.repeatable
                    ? ExcludeSemantics(
                        child: Text(
                          count > 999 ? '999+' : '$count',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 6),
                            ],
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
          for (final id in _floaters)
            _FloatingHeart(
              key: ValueKey(id),
              seed: id,
              onDone: () {
                if (mounted) setState(() => _floaters.remove(id));
              },
            ),
        ],
      ),
    );
  }
}

class _FloatingHeart extends StatelessWidget {
  const _FloatingHeart({super.key, required this.seed, required this.onDone});

  final int seed;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final random = math.Random(seed);
    final drift = (random.nextDouble() - 0.5) * 70;
    final rise = 130 + random.nextDouble() * 70;
    final size = 20 + random.nextDouble() * 14;

    return Positioned(
      top: 8,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child:
              Icon(
                    Icons.favorite_rounded,
                    color: StoriaColors.heart,
                    size: size,
                  )
                  .animate(onComplete: (_) => onDone())
                  .move(
                    begin: Offset.zero,
                    end: Offset(drift, -rise),
                    duration: 900.ms,
                    curve: Curves.easeOutCubic,
                  )
                  .scaleXY(begin: 0.5, end: 1.2, duration: 900.ms)
                  .rotate(
                    begin: 0,
                    end: (random.nextDouble() - 0.5) * 0.12,
                    duration: 900.ms,
                  )
                  .fadeOut(delay: 450.ms, duration: 450.ms),
        ),
      ),
    );
  }
}
