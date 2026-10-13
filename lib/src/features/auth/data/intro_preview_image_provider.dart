import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/resilient_cache_manager.dart';

final introPreviewCacheManagerProvider = Provider<BaseCacheManager>(
  (ref) => ResilientCacheManager.instance,
);

/// Retain the featured illustration's encoded bytes across route remounts.
/// A fresh decoded frame can then be produced even after Flutter evicts it.
/// Unlike the web network-image stream, these bytes belong to the app scope.
final introPreviewImageProvider = FutureProvider.family<MemoryImage, String>((
  ref,
  url,
) async {
  final cache = ref.watch(introPreviewCacheManagerProvider);
  final file = await cache.getSingleFile(url);
  return MemoryImage(await file.readAsBytes());
});
