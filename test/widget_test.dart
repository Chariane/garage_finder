import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:garage_finder/main.dart';
import 'package:garage_finder/providers/theme_provider.dart';

void main() {
  testWidgets('Garage Finder home renders primary actions', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const MyApp(),
      ),
    );

    expect(find.text('Garage Finder'), findsWidgets);
    expect(find.text('Trouver'), findsOneWidget);
    expect(find.byIcon(Icons.manage_search_rounded), findsOneWidget);
    expect(find.byIcon(Icons.add_business_rounded), findsOneWidget);
  });
}
