import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/reader_capabilities.dart';

/// Overridden only at trusted reader entry boundaries. Catalog remains the
/// default, so signed-in reading keeps its existing services and behavior.
final readerCapabilitiesProvider = Provider<ReaderCapabilities>(
  (ref) => const ReaderCapabilities(access: ReaderAccess.catalog),
  dependencies: const [],
);
