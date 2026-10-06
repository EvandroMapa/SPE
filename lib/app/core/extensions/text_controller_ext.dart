import 'package:acoplan/app/core/models/text_controller.dart';
import 'package:flutter_masked_text2/flutter_masked_text2.dart';
import 'package:intl/intl.dart';

extension TextControllerExt on TextController {
  double get doubleValue {
    // Campo com máscara numérica: o texto tem separador de milhar ("1.234,567")
    final c = controller;
    if (c is MoneyMaskedTextController) return c.numberValue;
    return double.tryParse(text.replaceAll(',', '.')) ?? 0;
  }
  int get intValue => int.tryParse(text) ?? 0;
  DateTime get ddMMyyyy {
    try {
      final format = DateFormat('dd/MM/yyyy');
      return format.parse(text);
    } catch (e) {
      return DateTime.now();
    }
  }

  String get labelValue =>
      doubleValue.toString().replaceAll('.0', '');
}
