import 'package:flutter/material.dart';

abstract final class StoriaMotion {
  static const quick = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 420);

  static const emphasized = Cubic(0.22, 1, 0.36, 1);
}
