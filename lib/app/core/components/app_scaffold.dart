import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  final Widget body;
  final Widget? bottomNav;
  final Widget? fab;
  final PreferredSizeWidget? appBar;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final Widget? drawer;
  final bool resizeAvoid;
  final Color? backgroundColor;

  const AppScaffold({
    super.key,
    required this.body,
    this.bottomNav,
    this.fab,
    this.appBar,
    this.scaffoldKey,
    this.drawer,
    this.resizeAvoid = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      drawer: drawer,
      appBar: appBar,
      bottomNavigationBar: bottomNav,
      floatingActionButton: fab,
      resizeToAvoidBottomInset: resizeAvoid,
      backgroundColor: backgroundColor,
      body: body,
    );
  }
}
