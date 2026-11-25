import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/core/resilient_cache_manager.dart';
import 'src/core/widgets/gate_lockout.dart';
import 'src/data/analytics_repository.dart';
import 'src/data/providers.dart';
import 'src/features/child/data/child_profile_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await dotenv.load(fileName: '.env.client');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    authOptions: const FlutterAuthClientOptions(),
  );

  // Eagerly initialise the image cache manager so stale SQLite lock files
  // are cleaned up before any widget tries to load a cached image.
  await ResilientCacheManager.getInstance();

  // Load any persisted parental-gate lockout so a force-quit doesn't evade it.
  await GateLockout.instance.loadFromPrefs();

  final anonId = await loadAnonId();

  runApp(
    ProviderScope(
      overrides: [
        anonIdProvider.overrideWithValue(anonId),
        currentChildProfileIdProvider.overrideWith(
          (ref) => ref.watch(activeChildProfileIdProvider),
        ),
      ],
      child: const StoriaApp(),
    ),
  );
}
