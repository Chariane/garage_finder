import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:garage_finder/controllers/garage_controller.dart';
import 'package:garage_finder/controllers/auth_controller.dart';
import 'package:garage_finder/main.dart' show MyApp;
import 'package:garage_finder/providers/theme_provider.dart';
import 'package:garage_finder/repositories/garage_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController(null)),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) =>
              GarageController(repository: InMemoryGarageRepository())..load(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}
