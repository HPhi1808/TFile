import 'package:flutter_test/flutter_test.dart';

import 'package:tfile_frontend/main.dart';

void main() {
  testWidgets('App boots', (WidgetTester tester) async {
    await tester.pumpWidget(const TFileApp());
    await tester.pump();
    expect(find.byType(TFileApp), findsOneWidget);
  });
}
