// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'package:flutter/widgets.dart';

/// Mixin que preserva o foco do campo de texto ao fazer alt+tab e retornar.
///
/// Estratégia:
///   - Rastreia continuamente o FocusNode ativo via FocusManager.addListener
///   - Ao retornar à janela (window.onFocus) restaura o último nó salvo
///   - NÃO depende de window.onBlur (que dispara após o Flutter já ter limpado o foco)
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
  StreamSubscription<html.Event>? _subFocus;

  /// Chamado pelo FocusManager sempre que o primaryFocus muda.
  void _onFocusChange() {
    final atual = FocusManager.instance.primaryFocus;
    // Guarda apenas nós válidos (com contexto montado) — ignora quando
    // o Flutter limpa o foco ao sair da janela (primaryFocus vira null)
    if (atual != null && atual.context != null) {
      _focoSalvo = atual;
    }
  }

  /// Inicia o rastreamento de foco e o listener de retorno de janela.
  void iniciarFocoJanela() {
    // Rastrear continuamente qualquer mudança de foco
    FocusManager.instance.addListener(_onFocusChange);

    // Quando o usuário volta para a janela, restaurar o último campo ativo
    _subFocus = html.window.onFocus.listen((_) {
      final alvo = _focoSalvo;
      if (alvo != null && alvo.context != null) {
        // Delay: aguarda o browser terminar de restaurar o foco da janela
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted && (alvo.context != null)) {
            alvo.requestFocus();
          }
        });
      }
    });
  }

  /// Cancela os listeners. Chamar no dispose().
  void descartarFocoJanela() {
    FocusManager.instance.removeListener(_onFocusChange);
    _subFocus?.cancel();
    _focoSalvo = null;
  }
}
