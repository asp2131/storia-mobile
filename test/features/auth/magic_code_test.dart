import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/features/auth/presentation/widgets/auth_social_buttons.dart';
import 'package:loratone/src/features/auth/presentation/widgets/magic_code_field.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;

void main() {
  group('normalizeMagicCode', () {
    test('strips spaces and separators from a pasted code', () {
      expect(normalizeMagicCode('123 456'), '123456');
      expect(normalizeMagicCode('123-456'), '123456');
      expect(normalizeMagicCode(' 123456\n'), '123456');
    });

    test('drops non-digits entirely', () {
      expect(normalizeMagicCode('abc123456'), '123456');
      expect(normalizeMagicCode('code: 000123'), '000123');
    });

    test('caps at six digits so a trailing paste cannot overflow', () {
      expect(normalizeMagicCode('12345678'), '123456');
    });

    test('leaves a short code short so the caller can reject it', () {
      expect(normalizeMagicCode('123'), '123');
      expect(normalizeMagicCode(''), '');
      expect(normalizeMagicCode('no digits here'), '');
    });

    test('preserves leading zeros', () {
      expect(normalizeMagicCode('000042'), '000042');
    });
  });

  group('MagicCodeField', () {
    Widget host({
      required TextEditingController controller,
      bool isVerifying = false,
      bool isBusy = false,
      VoidCallback? onVerify,
    }) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MagicCodeField(
            controller: controller,
            isVerifying: isVerifying,
            isBusy: isBusy,
            onVerify: onVerify ?? () {},
          ),
        ),
      ),
    );

    testWidgets('offers the code as a way past a broken link', (tester) async {
      await tester.pumpWidget(host(controller: TextEditingController()));

      expect(find.textContaining('6-digit'), findsOneWidget);
      expect(find.text('Verify Code'), findsOneWidget);
    });

    testWidgets('verifies on button tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(controller: TextEditingController(), onVerify: () => taps++),
      );

      await tester.tap(find.text('Verify Code'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('disables verification while another request is in flight', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          controller: TextEditingController(),
          isBusy: true,
          onVerify: () => taps++,
        ),
      );

      await tester.tap(find.text('Verify Code'), warnIfMissed: false);
      await tester.pump();

      expect(taps, 0);
    });
  });

  group('AuthSocialButtons', () {
    Widget host({required ValueChanged<OAuthProvider> onSelected, bool isBusy = false}) =>
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AuthSocialButtons(
                isBusy: isBusy,
                isSocialSubmitting: false,
                onProviderSelected: onSelected,
              ),
            ),
          ),
        );

    testWidgets('offers Apple on iOS', (tester) async {
      // Reset inside the body: the framework asserts foundation debug vars are
      // unset before addTearDown callbacks run.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final selected = <OAuthProvider>[];
      try {
        await tester.pumpWidget(host(onSelected: selected.add));

        expect(find.text('Continue with Apple'), findsOneWidget);
        // iOS keeps Apple as the native path rather than showing both.
        expect(find.text('Continue with Google'), findsNothing);

        await tester.tap(find.text('Continue with Apple'));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      expect(selected, [OAuthProvider.apple]);
    });

    testWidgets('offers Google on Android', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final selected = <OAuthProvider>[];
      try {
        await tester.pumpWidget(host(onSelected: selected.add));

        expect(find.text('Continue with Google'), findsOneWidget);
        expect(find.text('Continue with Apple'), findsNothing);

        await tester.tap(find.text('Continue with Google'));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      expect(selected, [OAuthProvider.google]);
    });

    testWidgets('ignores taps while another auth request is running', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final selected = <OAuthProvider>[];
      try {
        await tester.pumpWidget(host(onSelected: selected.add, isBusy: true));

        await tester.tap(
          find.text('Continue with Google'),
          warnIfMissed: false,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      expect(selected, isEmpty);
    });
  });
}
