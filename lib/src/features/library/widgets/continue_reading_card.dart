import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/resilient_cache_manager.dart';
import '../../../core/theme/storia_colors.dart';
import '../../../core/widgets/sketch_card.dart';
import '../../progress/domain/continue_reading_item.dart';

class ContinueReadingCard extends StatelessWidget {
  const ContinueReadingCard({
    super.key,
    required this.item,
    required this.onResume,
    required this.onPlay,
  });

  final ContinueReadingItem item;
  final VoidCallback onResume;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final progress = item.progress;

    return SketchCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 64,
              height: 88,
              child: item.book.coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: item.book.coverUrl!,
                      cacheManager: ResilientCacheManager.instance,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: StoriaColors.paperAlt),
                      errorWidget: (_, __, ___) => _coverPlaceholder(),
                    )
                  : _coverPlaceholder(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Continue Reading',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: StoriaColors.sage,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: StoriaColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Page ${progress.currentPage} of ${progress.totalPages}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: StoriaColors.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: (progress.progressPercent.clamp(0, 100)) / 100,
                    backgroundColor: StoriaColors.paperAlt,
                    valueColor: const AlwaysStoppedAnimation(StoriaColors.sage),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: onResume,
                      style: FilledButton.styleFrom(
                        backgroundColor: StoriaColors.ink,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(96, 44),
                      ),
                      child: const Text('Resume'),
                    ),
                    if (onPlay != null)
                      OutlinedButton.icon(
                        onPressed: onPlay,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: StoriaColors.ink,
                          minimumSize: const Size(88, 44),
                          side: const BorderSide(color: StoriaColors.line),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      color: StoriaColors.paperAlt,
      child: const Center(
        child: Icon(
          Icons.menu_book_rounded,
          color: StoriaColors.inkMuted,
          size: 28,
        ),
      ),
    );
  }
}
