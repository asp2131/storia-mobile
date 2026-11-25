import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/parental_gate.dart';
import 'book_links.dart';

/// The clipboard receives only a public book URL, never account/profile data.
Future<void> copyBookLink(BuildContext context, String bookId) async {
  if (!BookLinks.isValidId(bookId)) return;
  final passed = await ParentalGate.verify(context);
  if (!context.mounted || !passed) return;

  final link = BookLinks.forBook(bookId).toString();
  try {
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Book link copied. Ready to share!')),
    );
  } catch (_) {
    if (!context.mounted) return;
    // Some browsers deny clipboard access after an asynchronous parent gate.
    // Keep the actual link selectable so sharing is still possible.
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share this story'),
        content: SelectableText(link),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
