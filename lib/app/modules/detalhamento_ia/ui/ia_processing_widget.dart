import 'dart:async';
import 'dart:convert';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/modules/detalhamento_ia/detalhamento_ia_controller.dart';
import 'package:flutter/material.dart';

/// Widget exibido durante o processamento da IA.
/// Mostra frases rotativas de "varredura" e, quando concluído,
/// anima um contador de elementos encontrados.
class IaProcessingWidget extends StatefulWidget {
  final DetalhamentoIaState state;
  final String? fileName;

  const IaProcessingWidget({
    required this.state,
    this.fileName,
    super.key,
  });

  @override
  State<IaProcessingWidget> createState() => _IaProcessingWidgetState();
}

class _IaProcessingWidgetState extends State<IaProcessingWidget>
    with TickerProviderStateMixin {
  // ── Frases de varredura rotativas ───────────────────────
  static const _frases = [
    '📄  Lendo estrutura do PDF...',
    '🔍  Localizando tabelas de ferro...',
    '📐  Identificando elementos estruturais...',
    '⚙️   Extraindo bitolas e formas...',
    '📊  Mapeando posições de barras...',
    '🧮  Calculando comprimentos de corte...',
    '🏗️   Agrupando vigas e pilares...',
    '✅  Finalizando extração de dados...',
  ];

  int _fraseIndex = 0;
  Timer? _fraseTimer;

  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 0,
    )..forward();

    _iniciarFrasesRotativas();
  }

  @override
  void didUpdateWidget(IaProcessingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.status == IaStatus.success && _fraseTimer?.isActive == true) {
      _fraseTimer?.cancel();
    }
  }

  void _iniciarFrasesRotativas() {
    _fraseTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (mounted) {
        setState(() {
          _fraseIndex = (_fraseIndex + 1) % _frases.length;
        });
      }
    });
  }

  int _contarElementosTotais(String rawResult) {
    try {
      String json = rawResult.trim();
      if (json.startsWith('```json')) json = json.substring(7);
      if (json.startsWith('```')) json = json.substring(3);
      if (json.endsWith('```')) json = json.substring(0, json.length - 3);

      final data = jsonDecode(json);
      final elementos = data['elementos'] as List? ?? [];
      return elementos.length;
    } catch (_) {
      return widget.state.elementosEncontrados;
    }
  }

  @override
  void dispose() {
    _fraseTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool concluido = widget.state.status == IaStatus.success;
    final int elementosTotais = concluido ? _contarElementosTotais(widget.state.rawResult) : widget.state.elementosEncontrados;

    return FadeTransition(
      opacity: _fadeController,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Ícone / spinner ──────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: concluido
                  ? _buildCheckIcon()
                  : _buildSpinner(key: const ValueKey('spinner')),
            ),
            const SizedBox(height: 28),

            // ── Título ───────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: concluido
                  ? Text(
                      'Projeto processado! ✨',
                      key: const ValueKey('titulo_concluido'),
                      style: AppCss.largeBold.setColor(const Color(0xFF1E293B)),
                    )
                  : Text(
                      'Lendo projeto com IA...',
                      key: const ValueKey('titulo_loading'),
                      style: AppCss.largeBold.setColor(const Color(0xFF1E293B)),
                    ),
            ),
            const SizedBox(height: 16),

            // ── Contador de elementos ─────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: concluido
                  ? _buildContador(elementosTotais, finalizado: true)
                  : widget.state.elementosEncontrados > 0
                      ? _buildContador(widget.state.elementosEncontrados, finalizado: false)
                      : _buildFraseRotativa(),
            ),
            const SizedBox(height: 12),

            // ── Nome do arquivo ──────────────────────────
            if (widget.fileName != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.picture_as_pdf_outlined,
                        size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      widget.fileName!,
                      style: AppCss.minimumRegular
                          .setColor(const Color(0xFF64748B))
                          .setSize(12),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpinner({Key? key}) {
    return Container(
      key: key,
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.primaryMain.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.primaryMain,
            strokeWidth: 3,
          ),
          Icon(
            Icons.auto_awesome,
            size: 28,
            color: AppColors.primaryMain.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckIcon() {
    return Container(
      key: const ValueKey('check'),
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check_circle_outline,
          color: Color(0xFF10B981), size: 40),
    );
  }

  Widget _buildFraseRotativa() {
    return AnimatedSwitcher(
      key: const ValueKey('frases'),
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: Text(
        _frases[_fraseIndex],
        key: ValueKey(_fraseIndex),
        style: AppCss.smallRegular
            .setColor(const Color(0xFF475569))
            .setSize(14),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildContador(int qtdElementos, {required bool finalizado}) {
    return Column(
      key: ValueKey('contador_$finalizado'),
      children: [
        // Chips de informação
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _infoChip(
              Icons.view_list_outlined,
              '$qtdElementos',
              finalizado ? 'elementos extraídos' : 'elementos lidos...',
              const Color(0xFF6366F1),
            ),
            if (finalizado && qtdElementos > 0) ...[
              const SizedBox(width: 10),
              _infoChip(
                Icons.check_circle_outline,
                'Pronto!',
                'Revise e confirme',
                const Color(0xFF10B981),
              ),
            ],
          ],
        ),
        // Barra indicadora de Streaming
        if (!finalizado && qtdElementos > 0) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: 260,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                backgroundColor: const Color(0xFFE2E8F0),
                color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Recebendo dados da IA em tempo real...',
            style: AppCss.minimumRegular
                .setColor(Colors.grey[500]!)
                .setSize(12),
          ),
        ],
      ],
    );
  }

  Widget _infoChip(
      IconData icon, String valor, String label, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cor),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                valor,
                style: AppCss.smallBold.setColor(cor).setSize(16),
              ),
              Text(
                label,
                style: AppCss.minimumRegular
                    .setColor(cor.withValues(alpha: 0.8))
                    .setSize(11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
