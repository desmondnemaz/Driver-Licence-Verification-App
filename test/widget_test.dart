import 'package:flutter_test/flutter_test.dart';
import 'package:driver_license_verifier_app/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Initialize dummy Supabase for testing to prevent initialization errors
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'dummyAnonKey',
    );

    // Build our app and trigger a frame.
    await tester.pumpWidget(const DriverVerifierApp());
    
    // Wait for animations to finish to avoid pending timer errors.
    await tester.pumpAndSettle();

    // Verify that the main title is displayed.
    expect(find.textContaining('Zimbabwe Driver License'), findsOneWidget);
    expect(find.text('Select your role to continue'), findsOneWidget);

    // Verify role cards exist.
    expect(find.text('VID Officer'), findsOneWidget);
    expect(find.text('Police Officer'), findsOneWidget);
    expect(find.text('System Admin'), findsOneWidget);
  });
}
