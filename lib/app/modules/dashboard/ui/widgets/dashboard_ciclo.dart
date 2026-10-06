part of '../dashboard_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Ciclo Demanda → Projeto: planilhas da demanda, desfecho, cancelamento de
// projeto e histórico. As regras valem no banco (migração 04); aqui é a tela.
// ─────────────────────────────────────────────────────────────────────────────

Color _corSituacao(DetalhamentoSituacao s) {
  switch (s) {
    case DetalhamentoSituacao.planejamento:
      return AppColors.statusProduzindo;
    case DetalhamentoSituacao.orcamento:
      return AppColors.statusAtencao;
    case DetalhamentoSituacao.projeto:
      return AppColors.statusPronto;
    case DetalhamentoSituacao.cancelado:
      return AppColors.statusCritico;
  }
}

Color _corDesfecho(DemandaDesfecho d) {
  switch (d) {
    case DemandaDesfecho.projeto:
      return AppColors.statusPronto;
    case DemandaDesfecho.orcamento:
      return AppColors.statusAtencao;
    case DemandaDesfecho.desistencia:
      return AppColors.statusCritico;
  }
}

String _formatarPeso(double kg) => kg >= 1000
    ? '${NumberFormat('#,##0.00', 'pt_BR').format(kg / 1000)} t'
    : '${NumberFormat('#,##0.0', 'pt_BR').format(kg)} kg';

/// Selo pequeno e colorido (situação/desfecho)
class _SeloCiclo extends StatelessWidget {
  final String texto;
  final Color cor;
  final IconData? icon;
  const _SeloCiclo(this.texto, this.cor, {this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 10, color: cor), const SizedBox(width: 3)],
          Text(texto.toUpperCase(), style: AppCss.minimumBold.setSize(9).setColor(cor)),
        ],
      ),
    );
  }
}

// ── Planilhas da demanda ───────────────────────────────────────────────────

Future<void> _abrirPlanilhasDemanda(BuildContext context, DemandaModel demanda) async {
  final planilhas = demandaCtrl.obterDetalhamentosDaDemanda(demanda);
  // Uma planilha só e nada a decidir: abre direto no editor
  if (planilhas.length == 1 && !demandaCtrl.podeCriarPlanilha(demanda)) {
    await push(context, DetalhamentoCreatePage(detalhamento: planilhas.first));
    return;
  }
  await showDialog(context: context, builder: (_) => _PlanilhasDialog(demandaId: demanda.id));
}

class _PlanilhasDialog extends StatelessWidget {
  final String demandaId;
  const _PlanilhasDialog({required this.demandaId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DetalhamentoModel>>(
      stream: BackendClient.detalhamentos.dataStream.listen,
      builder: (context, _) {
        final demanda = demandaCtrl.demandas.where((d) => d.id == demandaId).firstOrNull ??
            BackendClient.demandas.data.where((d) => d.id == demandaId).firstOrNull;
        if (demanda == null) return const SizedBox.shrink();
        final planilhas = demandaCtrl.obterDetalhamentosDaDemanda(demanda);
        final bitolas = BackendClient.bitolas.data;
        final podeCriar = demandaCtrl.podeCriarPlanilha(demanda);

        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Planilhas da demanda D-${demanda.codigo}', style: AppCss.largeBold.setSize(16)),
                            Text('${demanda.obraNome} • ${demanda.etapaProjeto}',
                                style: AppCss.minimumRegular.setSize(12).setColor(AppColors.neutralMedium)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fechar',
                        style: IconButton.styleFrom(backgroundColor: Colors.transparent),
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: AppColors.neutralMedium),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: AppColors.neutralLight),
                Flexible(
                  child: planilhas.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Nenhuma planilha ainda. Crie a primeira para começar o detalhamento.',
                            textAlign: TextAlign.center,
                            style: AppCss.minimumRegular.setColor(AppColors.neutralMedium),
                          ),
                        )
                      : ListView(
                          shrinkWrap: true,
                          children: [
                            for (final p in planilhas)
                              CadastroLinha(
                                onTap: () => push(context, DetalhamentoCreatePage(detalhamento: p)),
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.neutralLightest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('${p.codigo}', style: AppCss.smallBold.setColor(AppColors.neutralDark)),
                                ),
                                titulo: p.descricao.isNotEmpty ? p.descricao : 'Detalhamento ${p.codigo}',
                                selos: [_SeloCiclo(p.situacao.label, _corSituacao(p.situacao))],
                                pares: [
                                  ('Elementos', '${p.elementos.length}'),
                                  ('Peso', p.elementos.isEmpty ? '' : _formatarPeso(p.pesoCalculado(bitolas))),
                                ],
                                trailing: Icon(Icons.open_in_new, size: 18, color: AppColors.neutralMedium),
                              ),
                          ],
                        ),
                ),
                Divider(height: 1, color: AppColors.neutralLight),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          podeCriar
                              ? 'Uma demanda pode ter várias planilhas (ex.: uma por pavimento).'
                              : (demanda.travada
                                  ? 'Demanda já virou projeto: novas planilhas não são permitidas.'
                                  : 'Demanda encerrada.'),
                          style: AppCss.minimumRegular.setSize(11.5).setColor(AppColors.neutralMedium),
                        ),
                      ),
                      if (podeCriar)
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: AppColors.primaryMain),
                          onPressed: () => _novaPlanilha(context, demanda),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Nova planilha'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _novaPlanilha(BuildContext context, DemandaModel demanda) async {
    final complemento = TextEditingController();
    final desenho = TextEditingController();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => CadastroDialog(
        icon: Icons.note_add_outlined,
        titulo: 'Nova planilha',
        largura: 460,
        onSalvar: () async => Navigator.pop(ctx, true),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Etapa: ${demanda.etapaProjeto}', style: AppCss.minimumBold.setSize(13)),
            const SizedBox(height: 12),
            TextField(
              controller: complemento,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Complemento (opcional)',
                hintText: 'Ex.: Vigas, Pilares, 2º pavimento',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: desenho,
              decoration: const InputDecoration(labelText: 'Desenho (opcional)', hintText: 'Ex.: E-03'),
            ),
          ],
        ),
      ),
    );
    if (confirmar != true) return;
    final criada = await demandaCtrl.criarPlanilha(
      demanda,
      complementoPavimento: complemento.text,
      desenho: desenho.text,
    );
    if (criada != null && context.mounted) {
      await push(context, DetalhamentoCreatePage(detalhamento: criada));
    }
  }
}

// ── Desfecho da demanda (em Finalizado) ─────────────────────────────────────

Future<void> _abrirDesfecho(BuildContext context, DemandaModel demanda) async {
  await showDialog(context: context, builder: (_) => _DesfechoDialog(demanda: demanda));
}

class _DesfechoDialog extends StatefulWidget {
  final DemandaModel demanda;
  const _DesfechoDialog({required this.demanda});

  @override
  State<_DesfechoDialog> createState() => _DesfechoDialogState();
}

class _DesfechoDialogState extends State<_DesfechoDialog> {
  DemandaDesfecho? _escolha;
  final _motivo = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final demanda = widget.demanda;
    final planilhas = demandaCtrl
        .obterDetalhamentosDaDemanda(demanda)
        .where((p) => p.situacao == DetalhamentoSituacao.planejamento || p.situacao == DetalhamentoSituacao.orcamento)
        .toList();
    final bitolas = BackendClient.bitolas.data;
    final peso = planilhas.fold<double>(0, (s, p) => s + p.pesoCalculado(bitolas));
    final opcoes = [
      (DemandaDesfecho.projeto, Icons.task_alt, 'Liberar como projeto',
          'As planilhas vão para Projetos e podem gerar pedido técnico. A demanda não volta mais de coluna.'),
      if (demanda.desfecho != DemandaDesfecho.orcamento)
        (DemandaDesfecho.orcamento, Icons.request_quote_outlined, 'Só orçamento',
            'Fica guardado como orçamento. Se o cliente aprovar, vira projeto com um clique.'),
      (DemandaDesfecho.desistencia, Icons.block, 'Cliente desistiu',
          'Encerra a demanda: as planilhas são canceladas e a demanda é arquivada.'),
    ];

    return CadastroDialog(
      icon: Icons.flag_outlined,
      titulo: 'Desfecho da demanda D-${demanda.codigo}',
      largura: 560,
      onSalvar: () async {
        if (_escolha == null) {
          NotificationService.showNegative('Escolha o desfecho', 'Selecione uma das opções.',
              position: NotificationPosition.bottom);
          return;
        }
        final navigator = Navigator.of(context);
        if (await demandaCtrl.definirDesfecho(demanda, _escolha!, _motivo.text)) {
          navigator.pop();
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${demanda.obraNome} • ${demanda.etapaProjeto}\n'
            '${planilhas.length} planilha(s)${planilhas.isEmpty ? '' : ' • ${_formatarPeso(peso)}'}',
            style: AppCss.minimumRegular.setSize(12.5).setColor(AppColors.neutralDark),
          ),
          if (planilhas.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Sem planilha: só é possível encerrar como desistência. Crie uma planilha para liberar como projeto ou orçamento.',
              style: AppCss.minimumRegular.setSize(12).setColor(AppColors.statusAtencao),
            ),
          ],
          const SizedBox(height: 14),
          for (final (valor, icone, titulo, texto) in opcoes) ...[
            _opcao(valor, icone, titulo, texto, habilitada: planilhas.isNotEmpty || valor == DemandaDesfecho.desistencia),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 6),
          TextField(
            controller: _motivo,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: _escolha == DemandaDesfecho.desistencia ? 'Motivo da desistência (obrigatório)' : 'Observação (opcional)',
            ),
          ),
        ],
      ),
    );
  }

  Widget _opcao(DemandaDesfecho valor, IconData icone, String titulo, String texto, {required bool habilitada}) {
    final selecionada = _escolha == valor;
    final cor = _corDesfecho(valor);
    return Opacity(
      opacity: habilitada ? 1 : 0.45,
      child: InkWell(
        onTap: habilitada ? () => setState(() => _escolha = valor) : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selecionada ? cor.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selecionada ? cor : AppColors.neutralLight, width: selecionada ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Icon(icone, color: cor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: AppCss.minimumBold.setSize(14)),
                    const SizedBox(height: 2),
                    Text(texto, style: AppCss.minimumRegular.setSize(12).setColor(AppColors.neutralMedium)),
                  ],
                ),
              ),
              Icon(selecionada ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selecionada ? cor : AppColors.neutralMedium),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Projeto: cancelar (desistência) e converter orçamento ───────────────────

Future<void> _cancelarProjeto(BuildContext context, DetalhamentoModel det) async {
  final abertos = BackendClient.pedidosTecnicos.data
      .where((p) => p.detalhamentoId == det.id && p.isAberto)
      .toList();
  final motivo = TextEditingController();
  await showDialog(
    context: context,
    builder: (ctx) => CadastroDialog(
      icon: Icons.block,
      titulo: 'Cancelar ${det.situacao == DetalhamentoSituacao.orcamento ? 'orçamento' : 'projeto'} ${det.codigo}',
      largura: 500,
      onSalvar: () async {
        if (motivo.text.trim().isEmpty) {
          NotificationService.showNegative('Informe o motivo', 'O motivo do cancelamento é obrigatório.',
              position: NotificationPosition.bottom);
          return;
        }
        try {
          final n = await BackendClient.detalhamentos.cancelarProjeto(det.id, motivo.text.trim());
          if (n > 0) await BackendClient.pedidosTecnicos.fetch();
          NotificationService.showPositive(
            'Cancelado',
            n > 0 ? '${det.labelExibicao} e $n pedido(s) técnico(s) cancelados.' : '${det.labelExibicao} cancelado.',
            position: NotificationPosition.bottom,
          );
          if (ctx.mounted) Navigator.pop(ctx);
        } catch (e) {
          NotificationService.showNegative('Não foi possível cancelar', mensagemErro(e),
              position: NotificationPosition.bottom);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${det.clienteNome} • ${det.descricao}', style: AppCss.minimumBold.setSize(13)),
          const SizedBox(height: 10),
          if (abertos.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.statusCritico.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Atenção: ${abertos.length} pedido(s) técnico(s) aberto(s) também serão cancelados: '
                '${abertos.map((p) => p.identificador.isNotEmpty ? p.identificador : 'PT ${p.codigo}').join(', ')}.',
                style: AppCss.minimumRegular.setSize(12.5).setColor(AppColors.statusCritico),
              ),
            ),
          if (abertos.isNotEmpty) const SizedBox(height: 10),
          Text('O cancelamento não pode ser desfeito. O projeto continua consultável em "Cancelados".',
              style: AppCss.minimumRegular.setSize(12).setColor(AppColors.neutralMedium)),
          const SizedBox(height: 12),
          TextField(
            controller: motivo,
            autofocus: true,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Motivo (obrigatório)', hintText: 'Ex.: cliente fechou com outro fornecedor'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _converterOrcamento(BuildContext context, DetalhamentoModel det) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Converter em projeto?', style: AppCss.largeBold),
      content: Text(
        'O orçamento ${det.labelExibicao} vira projeto e passa a poder gerar pedido técnico. '
        'Isso não pode ser desfeito.',
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.statusPronto),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Converter'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await BackendClient.detalhamentos.converterOrcamentoEmProjeto(det.id);
    await BackendClient.demandas.fetch();
    NotificationService.showPositive('Convertido em projeto', '${det.labelExibicao} já pode gerar pedido técnico.',
        position: NotificationPosition.bottom);
  } catch (e) {
    NotificationService.showNegative('Não foi possível converter', mensagemErro(e), position: NotificationPosition.bottom);
  }
}

// ── Histórico ───────────────────────────────────────────────────────────────

class _HistoricoDemanda extends StatelessWidget {
  final String demandaId;
  const _HistoricoDemanda({required this.demandaId});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("dd/MM/yy 'às' HH:mm", 'pt_BR');
    return FutureBuilder<List<DemandaEvento>>(
      future: BackendClient.demandas.eventos(demandaId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final eventos = (snap.data ?? const <DemandaEvento>[]).reversed.toList();
        if (eventos.isEmpty) {
          return Text('Sem registros ainda.', style: AppCss.minimumRegular.setSize(12).setColor(AppColors.neutralMedium));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final e in eventos)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: AppColors.neutralMedium, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.descricao, style: AppCss.minimumBold.setSize(12.5)),
                          if (e.motivo.isNotEmpty)
                            Text(e.motivo, style: AppCss.minimumRegular.setSize(12).setColor(AppColors.neutralDark)),
                          Text('${fmt.format(e.criadoEm)} • ${e.usuarioNome}',
                              style: AppCss.minimumRegular.setSize(11).setColor(AppColors.neutralMedium)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
