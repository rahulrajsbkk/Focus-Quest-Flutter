// Basic smoke test for the FocusQuest app.

import 'package:flutter_quest/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FocusQuest app loads successfully', (WidgetTester tester) async {
    // Build our app wrapped in ProviderScope and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    // Just pump a single frame - don't wait for async operations to settle
    // because they may involve platform channels that aren't mocked
    await tester.pump();

    // Verify that the app title is displayed
    expect(find.text('FocusQuest'), findsOneWidget);

    // Verify the FAB for creating new quests is visible
    expect(find.text('New Quest'), findsOneWidget);
  });
}
