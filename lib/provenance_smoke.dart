import 'package:flutter/material.dart';
import 'src/core/theme/app_theme.dart';
import 'src/data/models.dart';
import 'src/features/library/game/book_preview_overlay.dart';

void main() => runApp(const ProvenanceSmoke());

class ProvenanceSmoke extends StatefulWidget {
  const ProvenanceSmoke({super.key});
  @override
  State<ProvenanceSmoke> createState() => _ProvenanceSmokeState();
}

class _ProvenanceSmokeState extends State<ProvenanceSmoke> {
  String status = 'human_created';
  double scale = 1;
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(
      body: SafeArea(
        child: Column(children: [
          Wrap(children: [
            for (final value in ['human_created', 'unspecified', 'ai_assisted_or_generated'])
              TextButton(onPressed: () => setState(() => status = value), child: Text(value)),
            TextButton(onPressed: () => setState(() => scale = scale == 1 ? 2 : 1), child: const Text('Toggle text scale')),
          ]),
          Expanded(child: LayoutBuilder(builder: (context, constraints) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: Stack(children: [
              BookPreviewOverlay(
                book: Book.fromLibraryJson({'id': 'smoke', 'title': 'The Illustrated Garden', 'author': 'Partnered Artist', 'artwork_provenance': status, 'pages': [{'count': 12}]}),
                onRead: () {}, onDismiss: () {},
                position: Offset(constraints.maxWidth / 2, 32),
              ),
            ]),
          ))),
        ]),
      ),
    ),
  );
}
