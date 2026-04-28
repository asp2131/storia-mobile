import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:storia_kids/src/features/child/presentation/add_child_screen.dart';

GoRouter _router() {
  return GoRouter(
    initialLocation: '/profiles/new',
    routes: [
      GoRoute(
        path: '/profiles/new',
        builder: (context, state) => const AddChildScreen(),
      ),
      GoRoute(
        path: '/profiles/select',
        builder: (context, state) => const Scaffold(body: Text('Choose')),
      ),
      GoRoute(
        path: '/library',
        builder: (context, state) => const Scaffold(body: Text('Library')),
      ),
    ],
  );
}

void main() {
  testWidgets('validates display name and age band before submit', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: _router())),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save child profile'));
    await tester.tap(find.text('Save child profile'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a display name.'), findsOneWidget);
    expect(find.text('Choose an age band.'), findsOneWidget);
  });
}
