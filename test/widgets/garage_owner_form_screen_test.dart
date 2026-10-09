import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_finder/controllers/auth_controller.dart';
import 'package:garage_finder/core/localization/app_localizations.dart';
import 'package:garage_finder/screens/garage_owner_form_screen.dart';
import 'package:provider/provider.dart';

class _GarageOwnerAuthController extends AuthController {
  _GarageOwnerAuthController() : super(null);

  @override
  bool get isConfigured => true;

  @override
  bool get isSignedIn => true;

  @override
  bool get isGarageOwner => true;
}

void main() {
  testWidgets('garage form opens without eagerly initializing geocoding', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: _GarageOwnerAuthController(),
        child: MaterialApp(
          home: const GarageOwnerFormScreen(),
          locale: const Locale('fr'),
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
    await tester.pumpAndSettle();

    expect(find.text('Ajouter mon garage'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
