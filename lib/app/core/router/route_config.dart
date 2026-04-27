import 'package:acoplan/app/app_controller.dart';
import 'package:acoplan/app/app_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RouteConfig {
  static late RouterConfig<Object> config;
  
  static void setConfig() {
    config = GoRouter(
      initialLocation: '/',
      navigatorKey: appCtrl.key,
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => const NoTransitionPage(child: HomePage()),
        ),
      ],
    );
  }
}
