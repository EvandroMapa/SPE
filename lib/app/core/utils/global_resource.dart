import 'package:acoplan/app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const String empty = '';

BuildContext get contextGlobal => AppController().context;

Future<dynamic> push([dynamic a, dynamic b]) async {
  Widget? widget;
  BuildContext? context;
  if (a != null) {
    if (a is Widget) { widget = a; } else if (a is BuildContext) { context = a; }
  }
  if (b != null) {
    if (b is Widget) { widget = b; } else if (b is BuildContext) { context = b; }
  }
  final result = await Navigator.push(
    context ?? contextGlobal,
    MaterialPageRoute(builder: (_) => widget ?? Container()),
  );
  return result;
}

void pop([BuildContext? context]) => Navigator.pop(context ?? contextGlobal);

void pops(BuildContext context, int length) {
  for (var i = 0; i < length; i++) { Navigator.pop(context); }
}

bool kIsLayoutMobile = true;

void setWebTitle(String title) {
  SystemChrome.setApplicationSwitcherDescription(
    ApplicationSwitcherDescription(label: title),
  );
}
