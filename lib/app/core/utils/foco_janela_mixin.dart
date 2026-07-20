// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'package:flutter/widgets.dart';

/// Mixin que preserva o foco do campo de texto ao fazer alt+tab e retornar.
///
/// Uso:
/// ```dart
/// class _MinhaPageState extends State<MinhaPage> with FocoJanelaMixin {
///   @override
///   void initState() {
///     super.initState();
///     iniciarFocoJanela();
///   }
///   @override
///   void dispose() {
///     descartarFocoJanela();
///     super.dispose();
///   }
/// }
/// ```
mixin FocoJanelaMixin<T extends StatefulWidget> on State<T> {
  FocusNode? _focoSalvo;
  StreamSubscription<html.Event>? _subBlur;
  StreamSubscription<html.Event>? _subFocus;

  /// Inicia os listeners de blur/focus da janela do browser.
  void iniciarFocoJanela() {
    // Salva o foco ativo quando o usuário sai da janela (alt+tab)
    _subBlur = html.window.onBlur.listen((_) {
      _focoSalvo = FocusManager.instance.primaryFocus;
    });

    // Restaura o foco quando o usuário volta para a janela
    _subFocus = html.window.onFocus.listen((_) {
      final alvo = _focoSalvo;
      if (alvo != null && alvo.context != null) {
        // Pequeno delay para o browser terminar de restaurar o foco da janela
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) alvo.requestFocus();
        });
      }
    });
  }

  /// Cancela os listeners. Chamar no dispose().
  void descartarFocoJanela() {
    _subBlur?.cancel();
    _subFocus?.cancel();
    _focoSalvo = null;
  }
}
