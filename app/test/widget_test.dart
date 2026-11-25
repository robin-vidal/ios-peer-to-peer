import 'package:flutter_test/flutter_test.dart';
import 'package:p2pchat/main.dart';

void main() {
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
