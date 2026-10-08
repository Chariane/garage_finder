import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'controllers/auth_controller.dart';
import 'controllers/garage_controller.dart';
import 'core/database/garage_database.dart';
import 'core/localization/app_localizations.dart';
import 'providers/theme_provider.dart';
import 'repositories/garage_repository.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  SupabaseClient? supabaseClient;
  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    try {
      await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
      supabaseClient = Supabase.instance.client;
    } catch (error) {
      debugPrint('Supabase initialization failed: $error');
    }
  }

  final GarageRepository localRepository = kIsWeb
      ? InMemoryGarageRepository()
      : SqfliteGarageRepository(GarageDatabase());
  final repository = supabaseClient == null
      ? localRepository
      : SupabaseGarageRepository(
          client: supabaseClient,
          local: localRepository,
        );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthController(supabaseClient)),
        ChangeNotifierProvider(
          create: (_) => GarageController(repository: repository)..load(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp.router(
      title: 'Garage Finder',
      routerConfig: router,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      locale: themeProvider.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
    );
  }
}
