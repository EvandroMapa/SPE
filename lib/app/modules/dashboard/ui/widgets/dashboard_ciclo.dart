part of '../dashboard_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Demanda → Etapas → Detalhamentos
// A demanda (Kanban) é dividida em etapas (Sapatas, Vigas baldrame...). Cada
// detalhamento cobre uma ou mais etapas e pode ganhar/perder etapas depois.
// Única trava: pedido técnico só com a demanda em Finalizado / Liberado.
// ─────────────────────────────────────────────────────────────────────────────

String _formatarPeso(double kg) => kg >= 1000
    ? '${NumberFormat('#,##0.00', 'pt_BR').format(kg / 1000)} t'
    : '${NumberFormat('#,##0.0', 'pt_BR').format(kg)} kg';

Color _corEtapaKanban(DemandaEtapa e) {
  switch (e) {
    case DemandaEtapa.aguardandoFila:
      return AppColors.statusAguardando;
    case DemandaEtapa.emProducao:
      return AppColors.statusProduzindo;
    case DemandaEtapa.aguardandoCorrecao:
    case DemandaEtapa.corrigindo:
      return AppColors.statusAtencao;
    case DemandaEtapa.finalizadoLiberado:
      return AppColors.statusPronto;
  }
}

/// Selo pequeno e colorido
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
          if (icon != null) ...[
            Icon(icon, size: 10, color: cor),
            const SizedBox(width: 3),
          ],
          Text(
            texto.toUpperCase(),
            style: AppCss.minimumBold.setSize(9).setColor(cor),
          ),
        ],
      ),
    );
  }
}

// ── Etapas e detalhamentos da demanda ───────────────────────────────────────

Future<void> _abrirEtapasDemanda(
  BuildContext context,
  DemandaModel demanda,
) async {
  await showDialog(
    context: context,
    builder: (_) => _EtapasDialog(demandaId: demanda.id),
  );
}

class _EtapasDialog extends StatefulWidget {
  final String demandaId;
  const _EtapasDialog({required this.demandaId});

  @override
  State<_EtapasDialog> createState() => _EtapasDialogState();
}

class _EtapasDialogState extends State<_EtapasDialog> {
  final _novaEtapa = TextEditingController();
  final Set<String> _marcadas = {};

  @override
  void dispose() {
    _novaEtapa.dispose();
    super.dispose();
  }

  Future<void> _adicionar(DemandaModel demanda) async {
    final nome = _novaEtapa.text.trim();
    if (nome.isEmpty) return;
    if (await demandaCtrl.adicionarEtapa(demanda, nome)) _novaEtapa.clear();
  }

  Future<void> _criarDetalhamento(
    DemandaModel demanda,
    List<DemandaEtapaModel> etapas,
  ) async {
    final criado = await demandaCtrl.criarDetalhamento(demanda, etapas);
    if (criado == null || !mounted) return;
    setState(_marcadas.clear);
    NotificationService.showPositive(
      'Detalhamento ${criado.codigo} criado',
      'Cobre: ${etapas.map((e) => e.nome).join(', ')}',
      position: NotificationPosition.bottom,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DemandaModel>>(
      stream: demandaCtrl.demandasStream.listen,
      builder: (context, _) => StreamBuilder<List<DetalhamentoModel>>(
        stream: BackendClient.detalhamentos.dataStream.listen,
        builder: (context, _) {
          final demanda = demandaCtrl.demandas
              .where((d) => d.id == widget.demandaId)
              .firstOrNull;
          if (demanda == null) return const SizedBox.shrink();
          final detalhamentos = demandaCtrl.obterDetalhamentosDaDemanda(
            demanda,
          );
          final semDetalhamento = demanda.etapas
              .where((e) => !e.temDetalhamento)
              .toList();
          _marcadas.removeWhere(
            (id) => !semDetalhamento.any((e) => e.id == id),
          );
          final marcadas = semDetalhamento
              .where((e) => _marcadas.contains(e.id))
              .toList();

          return Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _cabecalho(context, demanda),
                  Divider(height: 1, color: AppColors.neutralLight),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                      children: [
                        const CadastroSubtitulo('Etapas da demanda'),
                        if (demanda.etapas.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Divida a demanda nas partes que serão detalhadas (ex.: Sapatas, Vigas baldrame, Vigas).',
                              style: AppCss.minimumRegular
                                  .setSize(12.5)
                                  .setColor(AppColors.neutralMedium),
                            ),
                          ),
                        for (final e in demanda.etapas)
                          _linhaEtapa(e, detalhamentos),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _novaEtapa,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  hintText: 'Nova etapa (ex.: Vigas baldrame)',
                                ),
                                onSubmitted: (_) => _adicionar(demanda),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => _adicionar(demanda),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Adicionar'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const CadastroSubtitulo('Detalhamentos'),
                        if (detalhamentos.isEmpty)
                          Text(
                            'Nenhum detalhamento ainda. Marque as etapas acima e crie um detalhamento para elas.',
                            style: AppCss.minimumRegular
                                .setSize(12.5)
                                .setColor(AppColors.neutralMedium),
                          ),
                        for (final d in detalhamentos)
                          _linhaDetalhamento(context, d, demanda),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: AppColors.neutralLight),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          semDetalhamento.isEmpty
                              ? (demanda.etapas.isEmpty
                                    ? 'Cadastre as etapas para criar detalhamentos.'
                                    : 'Todas as etapas já têm detalhamento.')
                              : marcadas.isEmpty
                              ? 'Marque as etapas que o novo detalhamento vai cobrir.'
                              : '${marcadas.length} etapa(s) marcada(s)',
                          style: AppCss.minimumRegular
                              .setSize(12)
                              .setColor(AppColors.neutralMedium),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (semDetalhamento.length > 1)
                              TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: AppColors.neutralDark,
                                ),
                                onPressed: () => setState(() {
                                  if (marcadas.length ==
                                      semDetalhamento.length) {
                                    _marcadas.clear();
                                  } else {
                                    _marcadas.addAll(
                                      semDetalhamento.map((e) => e.id),
                                    );
                                  }
                                }),
                                child: Text(
                                  marcadas.length == semDetalhamento.length
                                      ? 'Desmarcar'
                                      : 'Marcar todas',
                                ),
                              ),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primaryMain,
                              ),
                              onPressed: marcadas.isEmpty
                                  ? null
                                  : () => _criarDetalhamento(demanda, marcadas),
                              icon: const Icon(
                                Icons.note_add_outlined,
                                size: 18,
                              ),
                              label: const Text('Criar detalhamento'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _cabecalho(BuildContext context, DemandaModel demanda) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Etapas e detalhamentos • D-${demanda.codigo}',
                  style: AppCss.largeBold.setSize(16),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${demanda.obraNome} • ${demanda.clienteNome}',
                        overflow: TextOverflow.ellipsis,
                        style: AppCss.minimumRegular
                            .setSize(12)
                            .setColor(AppColors.neutralMedium),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _SeloCiclo(
                      demanda.etapa.label,
                      _corEtapaKanban(demanda.etapa),
                    ),
                  ],
                ),
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
    );
  }

  /// Linha da etapa: marcar (se livre), detalhamento que a cobre, renomear/remover
  Widget _linhaEtapa(
    DemandaEtapaModel e,
    List<DetalhamentoModel> detalhamentos,
  ) {
    final det = detalhamentos
        .where((d) => d.id == e.detalhamentoId)
        .firstOrNull;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neutralLight),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: e.temDetalhamento
                ? Icon(
                    Icons.check_circle,
                    size: 18,
                    color: AppColors.statusPronto,
                  )
                : Checkbox(
                    value: _marcadas.contains(e.id),
                    activeColor: AppColors.primaryMain,
                    onChanged: (v) => setState(
                      () => v == true
                          ? _marcadas.add(e.id)
                          : _marcadas.remove(e.id),
                    ),
                  ),
          ),
          Expanded(
            child: Text(e.nome, style: AppCss.minimumBold.setSize(13.5)),
          ),
          // Em qual detalhamento está (pode mudar: detalhamento ganha/perde etapas)
          PopupMenuButton<String>(
            tooltip: 'Mudar o detalhamento desta etapa',
            color: Colors.white,
            position: PopupMenuPosition.under,
            onSelected: (v) =>
                demandaCtrl.vincularEtapa(e, v.isEmpty ? null : v),
            itemBuilder: (_) => [
              for (final d in detalhamentos)
                PopupMenuItem(
                  value: d.id,
                  child: Text('Detalhamento ${d.codigo}'),
                ),
              const PopupMenuItem(value: '', child: Text('Sem detalhamento')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: det != null
                    ? AppColors.statusPronto.withValues(alpha: 0.08)
                    : AppColors.neutralLightest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    det != null
                        ? 'Detalhamento ${det.codigo}'
                        : 'Sem detalhamento',
                    style: AppCss.minimumBold
                        .setSize(11.5)
                        .setColor(
                          det != null
                              ? AppColors.statusPronto
                              : AppColors.neutralMedium,
                        ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 16,
                    color: AppColors.neutralMedium,
                  ),
                ],
              ),
            ),
          ),
          CadastroMenu([
            CadastroAcao(Icons.edit_outlined, 'Renomear', () => _renomear(e)),
            CadastroAcao(
              Icons.delete_outline,
              'Remover etapa',
              () => _remover(e),
              destrutiva: true,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _linhaDetalhamento(
    BuildContext context,
    DetalhamentoModel d,
    DemandaModel demanda,
  ) {
    final etapas = demanda.etapas
        .where((e) => e.detalhamentoId == d.id)
        .map((e) => e.nome)
        .toList();
    final kg = d.pesoCalculado(BackendClient.bitolas.data);
    return CadastroLinha(
      onTap: () => push(context, DetalhamentoCreatePage(detalhamento: d)),
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.neutralLightest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${d.codigo}',
          style: AppCss.smallBold.setColor(AppColors.neutralDark),
        ),
      ),
      titulo: etapas.isEmpty
          ? (d.descricao.isNotEmpty ? d.descricao : 'Detalhamento ${d.codigo}')
          : etapas.join(' + '),
      pares: [
        ('Desenho', d.desenho),
        ('Elementos', '${d.elementos.length}'),
        ('Peso', d.elementos.isEmpty ? '' : _formatarPeso(kg)),
        ('Responsável', d.funcionarioNome),
      ],
      trailing: Icon(
        Icons.open_in_new,
        size: 18,
        color: AppColors.neutralMedium,
      ),
    );
  }

  Future<void> _renomear(DemandaEtapaModel e) async {
    final ctrl = TextEditingController(text: e.nome);
    final nome = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Renomear etapa'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (nome != null) await demandaCtrl.renomearEtapa(e, nome);
  }

  Future<void> _remover(DemandaEtapaModel e) async {
    if (await showConfirmDialog(
      'Remover etapa?',
      e.temDetalhamento
          ? 'A etapa "${e.nome}" sai da demanda e do detalhamento. O detalhamento e o que já foi lançado nele continuam.'
          : 'A etapa "${e.nome}" será removida da demanda.',
    )) {
      await demandaCtrl.removerEtapa(e);
    }
  }
}

// ── Histórico ───────────────────────────────────────────────────────────────

class _HistoricoDemanda extends StatelessWidget {
  final String demandaId;
  const _HistoricoDemanda({required this.demandaId});

  String _descricao(DemandaEvento e) {
    if (e.tipo == 'etapa_vinculo') {
      String cod(String? id) =>
          BackendClient.detalhamentos.data
              .where((d) => d.id == id)
              .map((d) => '${d.codigo}')
              .firstOrNull ??
          '?';
      if (e.para == null || e.para!.isEmpty) {
        return 'Etapa ${e.motivo} saiu do detalhamento ${cod(e.de)}';
      }
      return 'Etapa ${e.motivo} → detalhamento ${cod(e.para)}';
    }
    return e.descricao;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("dd/MM/yy 'às' HH:mm", 'pt_BR');
    return FutureBuilder<List<DemandaEvento>>(
      future: BackendClient.demandas.eventos(demandaId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final eventos = (snap.data ?? const <DemandaEvento>[]).reversed
            .toList();
        if (eventos.isEmpty) {
          return Text(
            'Sem registros ainda.',
            style: AppCss.minimumRegular
                .setSize(12)
                .setColor(AppColors.neutralMedium),
          );
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
                      decoration: BoxDecoration(
                        color: AppColors.neutralMedium,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _descricao(e),
                            style: AppCss.minimumBold.setSize(12.5),
                          ),
                          if (e.motivo.isNotEmpty && e.tipo != 'etapa_vinculo')
                            Text(
                              e.motivo,
                              style: AppCss.minimumRegular
                                  .setSize(12)
                                  .setColor(AppColors.neutralDark),
                            ),
                          Text(
                            '${fmt.format(e.criadoEm)} • ${e.usuarioNome}',
                            style: AppCss.minimumRegular
                                .setSize(11)
                                .setColor(AppColors.neutralMedium),
                          ),
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
