import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../resilient_cache_manager.dart';

/// A page illustration or audio reference in the reader: either a bundled
/// Flutter asset or a network resource. Parsing is explicit so asset paths
/// can never be handed to network APIs (and vice versa) by accident.
///
/// Sample content uses `asset:///assets/onboarding/sample/...`; catalog
/// content uses `https://...` URLs as before.
sealed class ReaderMediaSource {
  const ReaderMediaSource();

  /// Parses a reader media reference.
  ///
  /// - `null` / empty → [EmptyReaderMediaSource]
  /// - `asset:///<path>` → [AssetReaderMediaSource] (path must stay inside
  ///   the bundle — `..` segments are rejected)
  /// - `http(s)://...` → [NetworkReaderMediaSource]
  /// - anything else → ArgumentError (never guess).
  static ReaderMediaSource parse(String? source) {
    if (source == null || source.isEmpty) {
      return const EmptyReaderMediaSource();
    }
    if (source.startsWith('asset:///')) {
      final path = source.substring('asset:///'.length);
      if (path.isEmpty) {
        throw ArgumentError.value(source, 'source', 'empty asset path');
      }
      final segments = Uri.parse(path).pathSegments;
      final escapesBundle =
          segments.isEmpty ||
          segments.any((segment) => segment == '..' || segment == '.');
      if (escapesBundle || path.contains('../')) {
        throw ArgumentError.value(
          source,
          'source',
          'asset path must stay inside the bundle',
        );
      }
      return AssetReaderMediaSource(path);
    }
    final uri = Uri.tryParse(source);
    final isHttp =
        uri != null && (uri.isScheme('http') || uri.isScheme('https'));
    if (!isHttp) {
      throw ArgumentError.value(
        source,
        'source',
        'must be asset:/// or http(s)://',
      );
    }
    return NetworkReaderMediaSource(uri);
  }

  /// The Flutter asset path, or null when this is not a bundled asset.
  String? get assetPath;

  /// The network URI, or null when this is not a network resource.
  Uri? get uri;

  /// The raw reference string this source was parsed from.
  String get rawValue;
}

final class AssetReaderMediaSource extends ReaderMediaSource {
  const AssetReaderMediaSource(this.path);

  final String path;

  @override
  String get assetPath => path;

  @override
  Uri? get uri => null;

  @override
  String get rawValue => 'asset:///$path';
}

final class NetworkReaderMediaSource extends ReaderMediaSource {
  const NetworkReaderMediaSource(this.source);

  final Uri source;

  @override
  String? get assetPath => null;

  @override
  Uri get uri => source;

  @override
  String get rawValue => source.toString();
}

final class EmptyReaderMediaSource extends ReaderMediaSource {
  const EmptyReaderMediaSource();

  @override
  String? get assetPath => null;

  @override
  Uri? get uri => null;

  @override
  String get rawValue => '';
}

/// Uses bundled assets or the shared reader cache, preserving a single fetch
/// across rendering and image-readiness probes. Empty references have no image.
ImageProvider<Object>? imageProviderForReaderSource(
  String? source, {
  BaseCacheManager? cacheManager,
}) {
  final parsed = ReaderMediaSource.parse(source);
  switch (parsed) {
    case AssetReaderMediaSource():
      return AssetImage(parsed.assetPath);
    case NetworkReaderMediaSource():
      return CachedNetworkImageProvider(
        parsed.uri.toString(),
        cacheManager: cacheManager ?? ResilientCacheManager.instance,
      );
    case EmptyReaderMediaSource():
      return null;
  }
}
