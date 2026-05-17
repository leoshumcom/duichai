import 'package:flutter_test/flutter_test.dart';

import 'package:duichai/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DuichaiApp());
    expect(find.text('堆柴'), findsOneWidget);
  });
}
