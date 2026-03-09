import 'package:flutter/material.dart';

import '../theme/storia_colors.dart';
import 'sketch_card.dart';

class ParentSafetyBox extends StatelessWidget {
  const ParentSafetyBox({super.key});

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: StoriaColors.inkMuted,
      fontWeight: FontWeight.w800,
    );

    return SketchCard(
      color: Colors.white.withValues(alpha: 0.74),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: StoriaColors.sage.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: StoriaColors.sageDeep,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Built for family story time',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Parent sign-in, child-friendly reading, and calm audio controls keep the experience gentle and safe.',
                  style: bodyStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
