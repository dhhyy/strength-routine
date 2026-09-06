import 'package:flutter_test/flutter_test.dart';

import 'package:strength_routine/main.dart';

void main() {
  testWidgets('앱이 오늘 루틴 화면을 렌더한다', (WidgetTester tester) async {
    await tester.pumpWidget(const StrengthApp());
    expect(find.text('백스쿼트'), findsOneWidget);
  });
}
