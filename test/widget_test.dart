import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark_sales/features/auth/domain/session_state.dart';
import 'package:spark_sales/features/auth/presentation/login_screen.dart';
import 'package:spark_sales/features/auth/presentation/session_controller.dart';
import 'package:spark_sales/features/settings/presentation/disclosure_screen.dart';

void main() {
  testWidgets('permission denial explains that synchronization cannot run', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PermissionDeniedNotice())),
    );

    expect(
      find.textContaining('Call synchronization cannot run'),
      findsOneWidget,
    );
  });

  testWidgets('login validates email and password before submitting', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(_SignedOutSession.new),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'not-an-email');
    await tester.enterText(find.byType(TextFormField).at(1), '');
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(find.textContaining('Administrator'), findsNothing);
  });
}

class _SignedOutSession extends SessionController {
  @override
  Future<SessionState> build() async => const SessionState.signedOut();
}
