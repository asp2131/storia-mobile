import 'package:cue/cue.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'routing/app_router.dart';

class StoriaApp extends ConsumerWidget {
  const StoriaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Loratone',
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(brightness: .dark),
      themeMode: .system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: kDebugMode
          ? (context, child) =>
                CueDebugTools(child: child ?? const SizedBox.shrink())
          : null,
    );
  }
}
