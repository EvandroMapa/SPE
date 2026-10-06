import 'package:acoplan/app/core/components/app_field.dart';
import 'package:acoplan/app/core/components/h.dart';
import 'package:acoplan/app/core/components/w.dart';
import 'package:acoplan/app/core/models/text_controller.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:flutter/material.dart';

// Peças comuns das listas de cadastro (clientes, bitolas, fabricantes,
// equipamentos): busca com contador, linha do item e a lista.

/// Campo de busca com o total de itens ao lado
class CadastroBusca extends StatelessWidget {
  final TextController controller;
  final String hint;
  final String contador;
  final VoidCallback onChanged;

  /// Atalhos ao lado da busca (ex.: "Mostrar inativos")
  final List<Widget> acoes;

  const CadastroBusca({
    required this.controller,
    required this.hint,
    required this.contador,
    required this.onChanged,
    this.acoes = const [],
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: AppField(
              hint: hint,
              controller: controller,
              suffixIcon: Icons.search,
              onChanged: (_) => onChanged(),
            ),
          ),
          for (final acao in acoes) ...[const W(10), acao],
          const W(12),
          Text(
            contador,
            style: AppCss.minimumBold
                .setSize(12.5)
                .setColor(AppColors.neutralMedium),
          ),
        ],
      ),
    );
  }
}

/// Ícone quadrado à esquerda do cartão
class CadastroIcone extends StatelessWidget {
  final IconData icon;
  const CadastroIcone(this.icon, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.neutralLightest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: AppColors.neutralDark),
    );
  }
}

/// Selo pequeno ao lado do título (código, ramo...). Com [cor], fica
/// num tom dessa cor (ex.: "Inativo" em vermelho)
class CadastroSelo extends StatelessWidget {
  final String texto;
  final Color? cor;
  const CadastroSelo(this.texto, {this.cor, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cor?.withValues(alpha: 0.12) ?? AppColors.neutralLightest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: AppCss.minimumBold
            .setSize(11)
            .setColor(cor ?? AppColors.neutralDark),
      ),
    );
  }
}

/// Amostra de cor à esquerda da linha (etapas, etiquetas)
class CadastroCor extends StatelessWidget {
  final Color cor;
  const CadastroCor(this.cor, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.neutralLightest,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: cor,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
        ),
      ),
    );
  }
}

/// Botão "Novo ..." escrito, para a barra de cima das telas de cadastro
class CadastroBotaoNovo extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const CadastroBotaoNovo(this.label, {required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.primaryMain,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          minimumSize: const Size(0, 36),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: AppCss.minimumBold.setSize(13),
        ),
        onPressed: onTap,
        icon: const Icon(Icons.add, size: 18),
        label: Text(label),
      ),
    );
  }
}

/// Ação do menu ⋮ da linha
class CadastroAcao {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destrutiva;
  const CadastroAcao(this.icon, this.label, this.onTap,
      {this.destrutiva = false});
}

/// Menu ⋮ da linha (editar, excluir...), sem o fundo escuro do tema
class CadastroMenu extends StatelessWidget {
  final List<CadastroAcao> acoes;
  const CadastroMenu(this.acoes, {super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Mais ações',
      position: PopupMenuPosition.under,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      onSelected: (i) => acoes[i].onTap(),
      itemBuilder: (_) => [
        for (int i = 0; i < acoes.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Row(children: [
              Icon(acoes[i].icon,
                  size: 18,
                  color: acoes[i].destrutiva
                      ? AppColors.error
                      : AppColors.neutralDark),
              const SizedBox(width: 10),
              Text(acoes[i].label,
                  style: TextStyle(
                      color: acoes[i].destrutiva ? AppColors.error : null)),
            ]),
          ),
      ],
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: Icon(Icons.more_vert, color: AppColors.neutralMedium),
      ),
    );
  }
}

/// Linha de um item da lista: ícone, título com selos, pares
/// "rótulo valor" e, à direita, a seta ou um menu de ações
class CadastroLinha extends StatelessWidget {
  final Widget? leading;
  final String titulo;
  final List<Widget> selos;

  /// Pares (rótulo, valor); os de valor vazio não aparecem
  final List<(String, String)> pares;
  final Widget? trailing;
  final VoidCallback? onTap;

  const CadastroLinha({
    required this.titulo,
    this.leading,
    this.selos = const [],
    this.pares = const [],
    this.trailing,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final visiveis = pares.where((p) => p.$2.trim().isNotEmpty).toList();
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            border:
                Border(bottom: BorderSide(color: AppColors.neutralLightest)),
          ),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const W(12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(titulo, style: AppCss.largeBold.setSize(15)),
                        ...selos,
                      ],
                    ),
                    if (visiveis.isNotEmpty) ...[
                      const H(4),
                      Wrap(
                        spacing: 14,
                        runSpacing: 2,
                        children: [
                          for (final (rotulo, valor) in visiveis)
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '$rotulo ',
                                    style: AppCss.minimumRegular
                                        .setSize(12.5)
                                        .setColor(AppColors.neutralMedium),
                                  ),
                                  TextSpan(
                                    text: valor.trim(),
                                    style: AppCss.minimumRegular
                                        .setSize(12.5)
                                        .setColor(AppColors.neutralDark),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const W(8),
              trailing ??
                  Icon(Icons.chevron_right,
                      size: 20, color: AppColors.neutralMedium),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lista corrida das linhas, de ponta a ponta
class CadastroLista extends StatelessWidget {
  final List<Widget> itens;
  final Future<void> Function()? onRefresh;

  const CadastroLista({required this.itens, this.onRefresh, super.key});

  @override
  Widget build(BuildContext context) {
    final lista = ListView.builder(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: itens.length,
      itemBuilder: (_, i) => itens[i],
    );
    if (onRefresh == null) return lista;
    return RefreshIndicator(onRefresh: onRefresh!, child: lista);
  }
}
