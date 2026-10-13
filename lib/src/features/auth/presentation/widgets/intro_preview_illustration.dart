import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/loratone_entry_colors.dart';
import '../../data/intro_preview_image_provider.dart';
import 'story_entry_widgets.dart';

class IntroPreviewIllustration extends ConsumerWidget {
  const IntroPreviewIllustration({super.key, required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(introPreviewImageProvider(imageUrl))
      .when(
        data: (image) => Image(
          image: image,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          gaplessPlayback: true,
        ),
        loading: () => const ColoredBox(color: LoratoneEntryColors.sky),
        error: (_, _) => StoryEntryMessage(
          message: 'The illustration could not load.',
          onRetry: () => ref.invalidate(introPreviewImageProvider(imageUrl)),
        ),
      );
}
