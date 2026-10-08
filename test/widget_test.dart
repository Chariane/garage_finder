import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_finder/controllers/auth_controller.dart';
import 'package:garage_finder/controllers/garage_controller.dart';
import 'package:garage_finder/core/localization/app_localizations.dart';
import 'package:garage_finder/providers/theme_provider.dart';
import 'package:garage_finder/repositories/garage_repository.dart';
import 'package:garage_finder/screens/detail_screen.dart';
import 'package:garage_finder/screens/account_screen.dart';
import 'package:garage_finder/screens/favorites_screen.dart';
import 'package:garage_finder/screens/form_screen.dart';
import 'package:garage_finder/screens/home_screen.dart';
import 'package:garage_finder/screens/list_screen.dart';
import 'package:garage_finder/screens/moderation_screen.dart';
import 'package:garage_finder/screens/service_request_screen.dart';
import 'package:garage_finder/screens/settings_screen.dart';
import 'package:garage_finder/widgets/offline_data_banner.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<GarageController> controllerWithSeed() async {
  final controller = GarageController(repository: InMemoryGarageRepository());
  await controller.load();
  return controller;
}

Widget testApp(
  Widget screen,
  GarageController controller, {
  ThemeProvider? theme,
  AuthController? auth,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => auth ?? AuthController(null)),
      ChangeNotifierProvider<GarageController>.value(value: controller),
      ChangeNotifierProvider<ThemeProvider>.value(
        value: theme ?? ThemeProvider(),
      ),
    ],
    child: Consumer<ThemeProvider>(
      builder: (context, theme, _) => MaterialApp(
        locale: theme.locale,
        home: screen,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    ),
  );
}

Future<void> pumpTestApp(
  WidgetTester tester,
  Widget screen,
  GarageController controller, {
  ThemeProvider? theme,
  AuthController? auth,
}) async {
  await tester.pumpWidget(
    testApp(screen, controller, theme: theme, auth: auth),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('home presents the garage search action', (tester) async {
    final controller = await controllerWithSeed();
    await pumpTestApp(tester, const HomeScreen(), controller);
    expect(find.text('Trouver un garage'), findsWidgets);
    expect(find.text('Ateliers recommandés'), findsOneWidget);
  });

  testWidgets('account clearly indicates when Supabase is not configured', (
    tester,
  ) async {
    final controller = await controllerWithSeed();
    await pumpTestApp(tester, const AccountScreen(), controller);
    expect(
      find.text('Backend non configuré. Mode démonstration actif.'),
      findsOneWidget,
    );
  });

  testWidgets('account creation has separate customer and garage roles', (
    tester,
  ) async {
    final controller = await controllerWithSeed();
    final auth = AuthController(
      SupabaseClient(
        'https://garage-finder-test.supabase.co',
        'test-key',
        authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      ),
    );
    await pumpTestApp(tester, const AccountScreen(), controller, auth: auth);

    await tester.tap(find.text('Créer un compte'));
    await tester.pumpAndSettle();
    expect(find.text('Compte client'), findsOneWidget);
    expect(find.textContaining('La recherche est libre.'), findsOneWidget);

    await tester.tap(find.text('Garagiste'));
    await tester.pumpAndSettle();
    expect(find.text('Compte garagiste'), findsOneWidget);
    expect(
      find.textContaining('enregistrer et gérer tes garages'),
      findsOneWidget,
    );
    expect(find.text('Adresse complète du garage'), findsOneWidget);
    expect(tester.state<FormState>(find.byType(Form)).validate(), isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Nom trop court'), findsOneWidget);
    expect(find.text('Téléphone requis'), findsOneWidget);
    expect(find.text('Adresse requise'), findsOneWidget);
  });

  testWidgets('moderation screen denies access to non-moderators', (
    tester,
  ) async {
    final controller = await controllerWithSeed();
    await pumpTestApp(tester, const ModerationScreen(), controller);
    expect(
      find.text('Accès réservé à l’équipe de modération.'),
      findsOneWidget,
    );
  });

  testWidgets('garage list renders and searches the loaded data', (
    tester,
  ) async {
    final controller = await controllerWithSeed();
    await pumpTestApp(tester, const ListScreen(), controller);
    expect(find.byType(ListView), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).first,
      'no-such-workshop-943',
    );
    await tester.pump();
    expect(find.text('Aucun garage trouvé'), findsOneWidget);
  });

  testWidgets('garage list filters fit a narrow mobile screen', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = await controllerWithSeed();
    await pumpTestApp(tester, const ListScreen(), controller);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty favorites offers a path back to garages', (tester) async {
    final controller = await controllerWithSeed();
    await pumpTestApp(tester, const FavoritesScreen(), controller);
    expect(find.text('Aucun garage enregistré pour le moment'), findsOneWidget);
    expect(find.text('Garages'), findsOneWidget);
  });

  testWidgets('settings changes the application language to English', (
    tester,
  ) async {
    final controller = await controllerWithSeed();
    final theme = ThemeProvider();
    await pumpTestApp(tester, const SettingsScreen(), controller, theme: theme);
    await tester.tap(find.byType(DropdownButton<Locale>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    expect(theme.locale.languageCode, 'en');
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('garage detail toggles its persisted favorite state', (
    tester,
  ) async {
    final controller = await controllerWithSeed();
    final garage = controller.garages.first;
    await pumpTestApp(tester, DetailScreen(garageId: garage.id), controller);
    final favorite = find.byTooltip('Ajouter aux favoris');
    expect(favorite, findsOneWidget);
    await tester.tap(favorite);
    await tester.pumpAndSettle();
    expect(controller.isFavorite(garage.id), isTrue);
  });

  testWidgets('garage detail offers WhatsApp contact', (tester) async {
    final controller = await controllerWithSeed();
    await pumpTestApp(
      tester,
      DetailScreen(garageId: controller.garages.first.id),
      controller,
    );
    expect(find.text('Contacter sur WhatsApp'), findsOneWidget);
  });

  testWidgets('offline banner explains cache freshness', (tester) async {
    final controller = await controllerWithSeed();
    await pumpTestApp(
      tester,
      const Scaffold(body: OfflineDataBanner(lastUpdated: null)),
      controller,
    );
    expect(
      find.text('Mode hors ligne : données enregistrées sur cet appareil'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Aucune synchronisation récente'),
      findsOneWidget,
    );
  });

  testWidgets('garage form validates required fields', (tester) async {
    final controller = await controllerWithSeed();
    await pumpTestApp(tester, const FormScreen(), controller);
    await tester.ensureVisible(find.text('Enregistrer le garage'));
    await tester.tap(find.text('Enregistrer le garage'));
    await tester.pumpAndSettle();
    expect(find.text('Nom requis'), findsNWidgets(2));
  });

  testWidgets('roadside request explains when the backend is unavailable', (
    tester,
  ) async {
    final controller = await controllerWithSeed();
    await pumpTestApp(
      tester,
      ServiceRequestScreen(garage: controller.garages.first),
      controller,
    );
    expect(find.text('Demander un dépannage'), findsOneWidget);
    expect(
      find.text('Backend non configuré. Mode démonstration actif.'),
      findsOneWidget,
    );
  });
}
