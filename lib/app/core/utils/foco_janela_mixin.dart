// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Mixin que preserva o foco do campo de texto ao fazer alt+tab e retornar.
///
/// Cobre dois cenários:
///   - alt+tab para outro programa e volta → window.onFocus
///   - troca de aba do Chrome e volta     → document.onVisibilityChange
///
/// Estratégia:
///   1. Rastreia o último FocusNode válido via FocusManager.addListener
///   2. Ao voltar à janela: chama requestFocus() sincronamente (mantém user-gesture)
///      e agenda um retry no próximo frame (addPostFrameCallback) como garantia
///
/// Uso:
/// ```dart
/// class _MinhaPageState extends State<MinhaPage> with FocoJanelaMixin {
///   @override
///   void initState() { super.initState(); iniciarFocoJanela(); }
///   @override
///   void dispose()   { descartarFocoJanela(); super.dispose(); }
/// }
/// ```
mixin FocoJanelaMixin<T extends StatefulWidget> on State<T> {
  FocusNode? _focoSalvo;
  StreamSubscription<html.Event>? _subFocus;
  StreamSubscription<html.Event>? _subVisibility;

  void _onFocusChange() {
    final atual = FocusManager.instance.primaryFocus;
    if (atual != null && atual.context != null) {
      _focoSalvo = atual;
    }
  }

  void _tentarRestaurarFoco() {
    final alvo = _focoSalvo;
    if (alvo == null || alvo.context == null || !mounted) return;

    // Imediato — dentro do event handler = mantém "user gesture" do browser
    alvo.requestFocus();

    // Retry no próximo frame — garante que o Flutter renderizou o campo
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && alvo.context != null) alvo.requestFocus();
    });
  }

  void iniciarFocoJanela() {
    FocusManager.instance.addListener(_onFocusChange);

    // alt+tab de outro programa de volta para o Chrome
    _subFocus = html.window.onFocus.listen((_) => _tentarRestaurarFoco());

    // troca de aba dentro do Chrome e volta para esta aba
    _subVisibility = html.document.onVisibilityChange.listen((_) {
      if (html.document.visibilityState == 'visible') {
        _tentarRestaurarFoco();
      }
    });
  }

  void descartarFocoJanela() {
    FocusManager.instance.removeListener(_onFocusChange);
    _subFocus?.cancel();
    _subVisibility?.cancel();
    _focoSalvo = null;
  }
}
