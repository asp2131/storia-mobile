import 'package:flutter/services.dart' show rootBundle;

import 'aac_board.dart';

class AacBoardLoader {
  const AacBoardLoader({this.assetPath = 'assets/aac/demo_board.json'});
  final String assetPath;

  Future<AacBoard> load() async {
    final source = await rootBundle.loadString(assetPath);
    return AacBoard.fromJsonString(source);
  }
}
