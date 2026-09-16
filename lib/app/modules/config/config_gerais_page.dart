import 'package:acoplan/app/app_controller.dart';
import 'package:acoplan/app/core/components/app_scaffold.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

class ConfigGeraisPage extends StatefulWidget {
  const ConfigGeraisPage({super.key});

  @override
  State<ConfigGeraisPage> createState() => _ConfigGeraisPageState();
}

class _ConfigGeraisPageState extends State<ConfigGeraisPage> {
  late bool _rotacionar180Inicial;
  late bool _rotacionar180;

  bool _salvando = false;

  bool get _temAlteracoes => _rotacionar180 != _rotacionar180Inicial;

  @override
  void initState() {
    super.initState();
    _rotacionar180Inicial = appCtrl.etiquetaRotacao180;
    _rotacionar180 = _rotacionar180Inicial;
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await appCtrl.saveEtiquetaRotacao180(_rotacionar180);

      _rotacionar180Inicial = _rotacionar180;

      NotificationService.showPositive(
        'Configurações Salvas',
        'Parâmetros atualizados com sucesso.',
        position: NotificationPosition.bottom,
      );
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao Salvar',
        'Não foi possível salvar a configuração: $e',
        position: NotificationPosition.bottom,
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _confirmarSaidaSemSalvar() async {
    final descartar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 28),
            const SizedBox(width: 8),
            Text('Alterações não salvas', style: AppCss.mediumBold),
          ],
        ),
        content: Text(
          'Você fez alterações nas configurações que ainda não foram salvas.\nDeseja descartar as alterações e sair?',
          style: AppCss.smallRegular,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Continuar Editando', style: AppCss.smallBold.setColor(Colors.grey[700]!)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              foregroundColor: Colors.white,
            ),
            child: Text('Descartar e Sair', style: AppCss.smallBold.setColor(Colors.white)),
          ),
        ],
      ),
    );

    if (descartar == true && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_temAlteracoes && !_salvando,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_salvando) return;
        await _confirmarSaidaSemSalvar();
      },
      child: AppScaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            onPressed: () async {
              if (_temAlteracoes) {
                await _confirmarSaidaSemSalvar();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          backgroundColor: AppColors.primaryMain,
          title: Text(
            'Configurações Gerais',
            style: AppCss.mediumBold.setColor(Colors.white),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              children: [
                // ── Header ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C4A6E),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.settings_suggest_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Configurações Gerais',
                              style: AppCss.mediumBold.setColor(Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Defina parâmetros de funcionamento e impressão do sistema.',
                              style: AppCss.minimumRegular.setColor(
                                Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Seção: Impressão de Etiquetas Térmicas ──
                Row(
                  children: [
                    Icon(Icons.print_outlined, color: AppColors.primaryMain, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Etiquetas Térmicas (8,7 × 13,7 cm)',
                      style: AppCss.smallBold,
                    ),
                    if (_temAlteracoes) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.orange.shade400, width: 0.8),
                        ),
                        child: Text(
                          'Alterações não salvas',
                          style: AppCss.minimumBold.setColor(Colors.orange.shade800),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Escolha a orientação de saída para as etiquetas na impressora térmica.',
                  style: AppCss.minimumRegular.setColor(Colors.grey[600]!),
                ),
                const SizedBox(height: 16),

                // Opções de orientação
                Row(
                  children: [
                    // Opção 1: Original (0°)
                    Expanded(
                      child: _buildCardOrientacao(
                        titulo: 'Original (0°)',
                        descricao: 'Orientação padrão da bobina (cabeçalho no início).',
                        icone: Icons.arrow_upward_rounded,
                        selecionado: !_rotacionar180,
                        onTap: () {
                          setState(() => _rotacionar180 = false);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Opção 2: Giro de 180°
                    Expanded(
                      child: _buildCardOrientacao(
                        titulo: 'Giro de 180°',
                        descricao: 'Orientação invertida (cabeça para baixo ao sair).',
                        icone: Icons.screen_rotation_rounded,
                        selecionado: _rotacionar180,
                        onTap: () {
                          setState(() => _rotacionar180 = true);
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Botão Salvar
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 180,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: (_salvando || !_temAlteracoes) ? null : _salvar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryMain,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        disabledForegroundColor: Colors.grey[500],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: _salvando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 20),
                      label: Text(
                        _salvando ? 'Salvando...' : 'Salvar',
                        style: AppCss.smallBold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardOrientacao({
    required String titulo,
    required String descricao,
    required IconData icone,
    required bool selecionado,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selecionado
              ? AppColors.primaryMain.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selecionado ? AppColors.primaryMain : Colors.grey[300]!,
            width: selecionado ? 2 : 1,
          ),
          boxShadow: [
            if (selecionado)
              BoxShadow(
                color: AppColors.primaryMain.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selecionado
                        ? AppColors.primaryMain.withValues(alpha: 0.15)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icone,
                    color: selecionado ? AppColors.primaryMain : Colors.grey[600],
                    size: 20,
                  ),
                ),
                const Spacer(),
                if (selecionado)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.primaryMain,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    ),
                  )
                else
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey[400]!, width: 1.5),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              titulo,
              style: AppCss.smallBold.setColor(
                selecionado ? AppColors.primaryMain : AppColors.neutralDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              descricao,
              style: AppCss.minimumRegular.setColor(Colors.grey[600]!),
            ),
          ],
        ),
      ),
    );
  }
}
