import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:garage_finder/app.dart';
import 'package:garage_finder/controllers/auth_controller.dart';
import 'package:garage_finder/controllers/garage_controller.dart';
import 'package:garage_finder/core/localization/app_localizations.dart';
import 'package:garage_finder/providers/theme_provider.dart';
import 'package:garage_finder/repositories/garage_repository.dart';
import 'package:provider/provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester) async {
    for (var frame = 0; frame < 200; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (!tester.binding.hasScheduledFrame) return;
    }
    fail('The UI did not settle within 20 seconds.');
  }

  Future<GarageController> seededController() async {
    final controller = GarageController(repository: InMemoryGarageRepository());
    await controller.load();
    return controller;
  }

  Widget app(GarageController controller) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthController(null)),
      ChangeNotifierProvider<GarageController>.value(value: controller),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    ),
  );

  testWidgets('user searches a garage, opens details and saves it', (
    tester,
  ) async {
    final controller = await seededController();
    router.go('/list');
    await tester.pumpWidget(app(controller));
    await settle(tester);
    final target = controller.garages.first;
    await tester.enterText(find.byType(TextField).first, target.name);
    await settle(tester);
    await tester.tap(find.text(target.name).first);
    await settle(tester);
    expect(find.text(target.name), findsWidgets);
    await tester.tap(find.byTooltip('Ajouter aux favoris'));
    await settle(tester);
    expect(controller.isFavorite(target.id), isTrue);
  });

  testWidgets('new garage remains available after navigating to the list', (
    tester,
  ) async {
    final controller = await seededController();
    final template = controller.garages.first;
    final added = template.copyWith(
      id: 'integration-added',
      name: 'Garage Intégration',
    );
    await controller.addGarage(added);
    router.go('/list');
    await tester.pumpWidget(app(controller));
    await settle(tester);
    expect(find.text('Garage Intégration'), findsOneWidget);
  });
}
