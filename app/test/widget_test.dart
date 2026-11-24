import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:p2pchat/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MyApp(identityLoader: () async => 'test-identity-id'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Secure identity ready: test-ide'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('secure identity initialization errors are shown', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MyApp(identityLoader: () async => throw StateError('creation failed')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Secure identity setup failed: Bad state: creation failed'),
      findsOneWidget,
    );
  });
}
