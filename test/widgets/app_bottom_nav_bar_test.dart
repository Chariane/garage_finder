import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_finder/controllers/auth_controller.dart';
import 'package:garage_finder/core/localization/app_localizations.dart';
import 'package:garage_finder/widgets/app_bottom_nav_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class _TestAuthController extends AuthController {
  final bool signedIn;
  final bool garageOwner;

  _TestAuthController({required this.signedIn, required this.garageOwner})
    : super(null);

  @override
  bool get isSignedIn => signedIn;

  @override
  bool get isGarageOwner => garageOwner;
}

Widget _navigationApp(AuthController auth) {
  final router = GoRouter(
    initialLocation: auth.isGarageOwner ? '/owner' : '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainNavigationShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Text('Home page')),
          GoRoute(path: '/list', builder: (_, _) => const Text('Garage list')),
          GoRoute(path: '/owner', builder: (_, _) => const Text('Owner space')),
          GoRoute(
            path: '/activity',
            builder: (_, _) => const Text('Owner notifications'),
          ),
          GoRoute(
            path: '/garage/new',
            builder: (_, _) => const Text('Garage form'),
          ),
          GoRoute(
            path: '/favorites',
            builder: (_, _) => const Text('Favorite list'),
          ),
          GoRoute(path: '/form', builder: (_, _) => const Text('Garage form')),
          GoRoute(
            path: '/settings',
            builder: (_, _) => const Text('Settings page'),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  return ChangeNotifierProvider<AuthController>.value(
    value: auth,
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
    ),
  );
}

void main() {
  testWidgets('visitor does not see the garage add destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      _navigationApp(_TestAuthController(signedIn: false, garageOwner: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ajouter'), findsNothing);
    expect(find.text('Réglages'), findsOneWidget);
  });

  testWidgets('signed-in customer does not see the garage add destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      _navigationApp(_TestAuthController(signedIn: true, garageOwner: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ajouter'), findsNothing);
    expect(find.text('Réglages'), findsOneWidget);
  });

  testWidgets('garage owner workspace hides favorites and add tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      _navigationApp(_TestAuthController(signedIn: true, garageOwner: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Favoris'), findsNothing);
    expect(find.text('Ajouter'), findsNothing);
    expect(find.text('Espace garagiste'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    await tester.tap(find.text('Explorer'));
    await tester.pumpAndSettle();
    expect(find.text('Home page'), findsOneWidget);
    expect(find.text('Favoris'), findsOneWidget);
  });
}
