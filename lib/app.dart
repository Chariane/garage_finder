import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/account_screen.dart';
import 'screens/auth_callback_screen.dart';
import 'screens/detail_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/garage_owner_form_screen.dart';
import 'screens/home_screen.dart';
import 'screens/list_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/owner_dashboard_screen.dart';
import 'screens/activity_screen.dart';
import 'screens/service_request_screen.dart';
import 'screens/moderation_screen.dart';
import 'models/garage.dart';
import 'widgets/app_bottom_nav_bar.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainNavigationShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(path: '/list', builder: (context, state) => const ListScreen()),
        GoRoute(
          path: '/favorites',
          builder: (context, state) => const FavoritesScreen(),
        ),
        GoRoute(path: '/form', redirect: (context, state) => '/garage/new'),
        GoRoute(
          path: '/garage/new',
          builder: (context, state) => const GarageOwnerFormScreen(),
        ),
        GoRoute(
          path: '/garage/edit',
          builder: (context, state) =>
              GarageOwnerFormScreen(initialGarage: state.extra as Garage?),
        ),
        GoRoute(
          path: '/request/new',
          builder: (context, state) =>
              ServiceRequestScreen(garage: state.extra as Garage),
        ),
        GoRoute(
          path: '/account',
          builder: (context, state) => AccountScreen(
            startWithSignup: state.uri.queryParameters['mode'] == 'signup',
          ),
        ),
        GoRoute(
          path: '/auth/callback',
          builder: (context, state) => AuthCallbackScreen(uri: state.uri),
        ),
        GoRoute(
          path: '/owner',
          builder: (context, state) => const OwnerDashboardScreen(),
        ),
        GoRoute(
          path: '/activity',
          builder: (context, state) => const ActivityScreen(),
        ),
        GoRoute(
          path: '/moderation',
          builder: (context, state) => const ModerationScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/detail/:id',
          builder: (context, state) =>
              DetailScreen(garageId: state.pathParameters['id']!),
        ),
      ],
    ),
  ],
);
