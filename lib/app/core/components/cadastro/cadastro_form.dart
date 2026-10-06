import 'package:acoplan/app/core/components/app_scaffold.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:flutter/material.dart';

// Moldura comum dos formulários de cadastro (bitola, equipamento,
// fabricante...): barra com o nome e um selo, "Salvar" escrito, "Excluir"
// no menu ⋮ e as seções em cartões com largura máxima.

class CadastroFormPage extends StatefulWidget {
  final String titulo;
  final String? selo;

  /// Volta (cada tela decide se pergunta antes de sair)
  final VoidCallback onVoltar;

  /// Null esconde o botão Salvar (sem permissão)
  final Future<void> Function()? onSalvar;

  /// Null esconde o menu ⋮ (cadastro novo ou sem permissão)
  final VoidCallback? onExcluir;
  final String rotuloExcluir;

  final List<Widget> secoes;

  const CadastroFormPage({
    required this.titulo,
    required this.onVoltar,
    required this.secoes,
    this.selo,
    this.onSalvar,
    this.onExcluir,
    this.rotuloExcluir = 'Excluir',
    super.key,
  });

  @override
  State<CadastroFormPage> createState() => _CadastroFormPageState();
}

class _CadastroFormPageState extends State<CadastroFormPage> {
  bool _salvando = false;

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await widget.onSalvar!();
    } catch (_) {}
    if (mounted) setState(() => _salvando = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      resizeAvoid: true,
      backgroundColor: AppColors.neutralLightest,
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onVoltar,
          icon: Icon(Icons.arrow_back, color: AppColors.white),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Flexible(
              child: Text(
                widget.titulo,
                overflow: TextOverflow.ellipsis,
                style: AppCss.largeBold.setColor(AppColors.white).setSize(18),
              ),
            ),
            if (widget.selo != null && widget.selo!.trim().isNotEmpty) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  widget.selo!.trim(),
                  style:
                      AppCss.minimumBold.setSize(11).setColor(AppColors.white),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (widget.onSalvar != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.primaryMain,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  textStyle: AppCss.minimumBold.setSize(13),
                ),
                onPressed: _salvando ? null : _salvar,
                icon: _salvando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check, size: 18),
                label: const Text('Salvar'),
              ),
            ),
          // Excluir longe de um clique acidental
          if (widget.onExcluir != null)
            PopupMenuButton<String>(
              tooltip: 'Mais ações',
              icon: Icon(Icons.more_vert, color: AppColors.white),
              onSelected: (_) => widget.onExcluir!(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'excluir',
                  child: Row(children: [
                    Icon(Icons.delete_outline,
                        size: 18, color: AppColors.error),
                    const SizedBox(width: 10),
                    Text(widget.rotuloExcluir,
                        style: TextStyle(color: AppColors.error)),
                  ]),
                ),
              ],
            )
          else
            const SizedBox(width: 8),
        ],
        backgroundColor: AppColors.primaryMain,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < widget.secoes.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    widget.secoes[i],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cartão de seção do formulário: ícone, título, texto de apoio opcional
class CadastroSecao extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String? apoio;
  final Widget child;

  const CadastroSecao({
    required this.icon,
    required this.titulo,
    required this.child,
    this.apoio,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutralLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: AppColors.neutralLightest)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.neutralMedium),
                const SizedBox(width: 8),
                Text(titulo, style: AppCss.minimumBold.setSize(14)),
                if (apoio != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      apoio!,
                      overflow: TextOverflow.ellipsis,
                      style: AppCss.minimumRegular
                          .setSize(12.5)
                          .setColor(AppColors.neutralMedium),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

/// Dois campos lado a lado em tela larga; um embaixo do outro no celular
class CadastroLinhaCampos extends StatelessWidget {
  final List<Widget> campos;
  final List<int>? flex;
  const CadastroLinhaCampos(this.campos, {this.flex, super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < campos.length; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                campos[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < campos.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(flex: flex?[i] ?? 1, child: campos[i]),
            ],
          ],
        );
      },
    );
  }
}

/// Opção de liga/desliga com título e explicação (mesmo visual em todos
/// os formulários)
class CadastroOpcao extends StatelessWidget {
  final String titulo;
  final String? explicacao;
  final bool valor;
  final ValueChanged<bool>? onChanged;

  const CadastroOpcao({
    required this.titulo,
    required this.valor,
    required this.onChanged,
    this.explicacao,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!valor),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: AppCss.minimumBold.setSize(13.5)),
                  if (explicacao != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      explicacao!,
                      style: AppCss.minimumRegular
                          .setSize(12.5)
                          .setColor(AppColors.neutralMedium),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              value: valor,
              onChanged: onChanged,
              activeTrackColor: AppColors.primaryMain,
            ),
          ],
        ),
      ),
    );
  }
}

/// Moldura padrão das janelas de cadastro (usuário, perfil...): cabeçalho
/// com ícone e título, conteúdo com rolagem e rodapé com Excluir à esquerda
/// e Cancelar / Salvar à direita
class CadastroDialog extends StatefulWidget {
  final IconData icon;
  final String titulo;
  final Widget child;
  final Future<void> Function() onSalvar;
  final VoidCallback? onExcluir;
  final String rotuloExcluir;
  final double largura;

  const CadastroDialog({
    required this.icon,
    required this.titulo,
    required this.child,
    required this.onSalvar,
    this.onExcluir,
    this.rotuloExcluir = 'Excluir',
    this.largura = 560,
    super.key,
  });

  @override
  State<CadastroDialog> createState() => _CadastroDialogState();
}

class _CadastroDialogState extends State<CadastroDialog> {
  bool _salvando = false;

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await widget.onSalvar();
    } catch (_) {}
    if (mounted) setState(() => _salvando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.largura),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.neutralLightest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icon,
                        size: 19, color: AppColors.neutralDark),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.titulo,
                        style: AppCss.largeBold.setSize(17)),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: AppColors.neutralMedium),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.neutralLight),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: widget.child,
              ),
            ),
            Divider(height: 1, color: AppColors.neutralLight),
            // Rodapé
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
              child: Row(
                children: [
                  if (widget.onExcluir != null)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: AppColors.error,
                      ),
                      onPressed: widget.onExcluir,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text(widget.rotuloExcluir),
                    ),
                  const Spacer(),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.neutralDark,
                      side: BorderSide(color: AppColors.neutralLight),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryMain,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _salvando ? null : _salvar,
                    icon: _salvando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const Text('Salvar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Título de grupo dentro de uma janela ou cartão
class CadastroSubtitulo extends StatelessWidget {
  final String texto;
  const CadastroSubtitulo(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(
        texto.toUpperCase(),
        style: AppCss.minimumBold
            .setSize(11.5)
            .setColor(AppColors.neutralMedium)
            .copyWith(letterSpacing: 0.8),
      ),
    );
  }
}
