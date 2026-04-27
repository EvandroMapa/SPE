import 'package:acoplan/app/app_controller.dart';
import 'package:acoplan/app/core/components/stream_out.dart';
import 'package:acoplan/app/core/client/models/usuario_model.dart';
import 'package:acoplan/app/core/router/route_config.dart';
import 'package:acoplan/app/core/utils/app_theme.dart';
import 'package:acoplan/app/modules/base/base_page.dart';
import 'package:acoplan/app/modules/sign/ui/sign_up_page.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return OverlaySupport.global(
      child: MaterialApp.router(
        title: 'SPE',
        theme: AppTheme.theme,
        debugShowCheckedModeBanner: false,
        routerConfig: RouteConfig.config,
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamOutNull<UsuarioModel>(
      stream: appCtrl.usuarioStream.listen,
      child: (context, user) {
        if (user == null) {
          return const SignUpPage();
        }
        return const BasePage();
      },
    );
  }
}
