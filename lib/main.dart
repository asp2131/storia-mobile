import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/core/resilient_cache_manager.dart';
import 'src/data/providers.dart';
import 'src/features/child/data/child_profile_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    authOptions: const FlutterAuthClientOptions(),
  );

  // Eagerly initialise the image cache manager so stale SQLite lock files
  // are cleaned up before any widget tries to load a cached image.
  await ResilientCacheManager.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        currentChildProfileIdProvider.overrideWith(
          (ref) => ref.watch(activeChildProfileIdProvider),
        ),
      ],
      child: const StoriaApp(),
    ),
  );
}
