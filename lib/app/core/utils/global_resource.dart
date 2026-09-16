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

/// Compara duas strings considerando blocos numéricos (ordenação natural).
/// Exemplo: "V1", "V2", "V10" em vez de "V1", "V10", "V2".
int compararNatural(String a, String b) {
  if (a == b) return 0;
  final regExp = RegExp(r'(\d+)|(\D+)');
  final matchesA = regExp.allMatches(a.toLowerCase()).map((m) => m.group(0)!).toList();
  final matchesB = regExp.allMatches(b.toLowerCase()).map((m) => m.group(0)!).toList();
  final len = matchesA.length < matchesB.length ? matchesA.length : matchesB.length;
  for (int i = 0; i < len; i++) {
    final tokenA = matchesA[i];
    final tokenB = matchesB[i];
    final numA = int.tryParse(tokenA);
    final numB = int.tryParse(tokenB);
    if (numA != null && numB != null) {
      final cmp = numA.compareTo(numB);
      if (cmp != 0) return cmp;
    } else {
      final cmp = tokenA.compareTo(tokenB);
      if (cmp != 0) return cmp;
    }
  }
  final cmpLen = matchesA.length.compareTo(matchesB.length);
  if (cmpLen != 0) return cmpLen;
  return a.compareTo(b);
}
