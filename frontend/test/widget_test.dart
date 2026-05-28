import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qa_dashboard/main.dart';

void main() {
  testWidgets('App starts and shows login view', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const QADashboardApp());
    await tester.pumpAndSettle();

    expect(find.text('Welkom terug'), findsOneWidget);
    expect(find.text('Wachtwoord vergeten?'), findsOneWidget);
  });
}
