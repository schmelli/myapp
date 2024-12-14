import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const LegalIDEApp());

    // Verify that we have a login screen initially
    expect(find.byType(LoginScreen), findsOneWidget);

    // Enter login credentials
    await tester.enterText(
        find.byType(TextField).first, 'test@example.com');
    await tester.enterText(
        find.byType(TextField).last, 'password123');
    
    // Tap the login button
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    // After login, we should see the main layout
    expect(find.byType(MainLayout), findsOneWidget);
  });
}
