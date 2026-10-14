import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:snapchef/src/app.dart';

void main() {
  testWidgets('App boots and shows the SnapChef shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SnapChefApp()));

    // Let the stubbed ingredient future resolve.
    await tester.pump(const Duration(milliseconds: 500));

    // The app bar title and the three navigation tabs should be present.
    expect(find.textContaining('SnapChef'), findsWidgets);
    expect(find.text('Ingredients'), findsWidgets);
    expect(find.text('Recipes'), findsWidgets);
    expect(find.text('Account'), findsWidgets);
  });
}
