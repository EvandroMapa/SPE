import 'package:acoplan/app/core/components/drawer/app_drawer.dart';
import 'package:acoplan/app/core/components/stream_out.dart';
import 'package:acoplan/app/core/enums/app_module.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/modules/base/base_controller.dart';
import 'package:flutter/material.dart';

class BasePage extends StatelessWidget {
  const BasePage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamOut<AppModule>(
      stream: baseCtrl.moduleStream.listen,
      builder: (context, module) {
        return Scaffold(
          backgroundColor: AppColors.neutralLightest,
          appBar: AppBar(
            backgroundColor: const Color(0xFF1A2233),
            iconTheme: const IconThemeData(color: Colors.white),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module.label,
                  style: AppCss.mediumBold.setSize(16).setColor(Colors.white),
                ),
                Text(
                  'SPE',
                  style: AppCss.minimumRegular.setColor(Colors.white60),
                ),
              ],
            ),
            actions: [
              StreamOut<List<Widget>>(
                stream: baseCtrl.appBarActionsStream.listen,
                builder: (_, actions) =>
                    Row(mainAxisSize: MainAxisSize.min, children: actions),
              ),
              const SizedBox(width: 8),
            ],
          ),
          drawer: const AppDrawerMenu(),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: KeyedSubtree(
              key: ValueKey(module),
              child: module.widget,
            ),
          ),
        );
      },
    );
  }
}
