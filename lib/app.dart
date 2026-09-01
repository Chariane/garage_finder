import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'screens/list_screen.dart';
import 'screens/detail_screen.dart';
import 'screens/form_screen.dart';
import 'widgets/app_bottom_nav_bar.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return MainNavigationShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/list',
          builder: (context, state) => const ListScreen(),
        ),
        GoRoute(
          path: '/detail/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return DetailScreen(garageId: id);
          },
        ),
        GoRoute(
          path: '/form',
          builder: (context, state) => const FormScreen(),
        ),
      ],
    ),
  ],
);
