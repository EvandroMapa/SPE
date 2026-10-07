part of '../dashboard_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Card de Demanda no Kanban
// ─────────────────────────────────────────────────────────────────────────────
class _DemandaCard extends StatelessWidget {
  final DemandaModel demanda;
  final bool isFilaManual;
  final VoidCallback onTap;
  final VoidCallback? onEditar;
  final VoidCallback? onExcluir;
  final void Function(DemandaEtapa) onMover;
  final VoidCallback onArquivar;

  const _DemandaCard({
    required this.demanda,
    required this.isFilaManual,
    required this.onTap,
    this.onEditar,
    this.onExcluir,
    required this.onMover,
    required this.onArquivar,
  });

  Color _corPrioridade(String prioridade) {
    switch (prioridade) {
      case 'urgente':
        return const Color(0xFFE11D48);
      case 'alta':
        return const Color(0xFFEA580C);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prioridadeColor = _corPrioridade(demanda.prioridade);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha Superior: Ordem/Código, Prioridade e Ações
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      if (isFilaManual) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Text(
                            '#${demanda.ordem}',
                            style: AppCss.minimumBold
                                .setSize(9.5)
                                .setColor(const Color(0xFF1D4ED8)),
                          ),
                        ),
                      ],
                      Flexible(
                        child: Text(
                          'D-${demanda.codigo}',
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: AppCss.minimumBold
                              .setSize(10)
                              .setColor(const Color(0xFF94A3B8)),
                        ),
                      ),
                    ],
                  ),
                ),
                // Encolhe em colunas estreitas em vez de estourar
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: prioridadeColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            demanda.prioridade.toUpperCase(),
                            style: AppCss.minimumBold
                                .setSize(8.5)
                                .setColor(prioridadeColor),
                          ),
                        ),
                        if (onEditar != null) ...[
                          const SizedBox(width: 4),
                          Tooltip(
                            message: 'Editar demanda',
                            waitDuration: const Duration(milliseconds: 300),
                            child: InkWell(
                              onTap: onEditar,
                              borderRadius: BorderRadius.circular(5),
                              hoverColor: const Color(
                                0xFF2563EB,
                              ).withValues(alpha: 0.12),
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF2563EB,
                                  ).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF2563EB,
                                    ).withValues(alpha: 0.20),
                                    width: 0.8,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.edit_outlined,
                                  size: 11.5,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (onExcluir != null) ...[
                          const SizedBox(width: 3),
                          Tooltip(
                            message: 'Excluir demanda',
                            waitDuration: const Duration(milliseconds: 300),
                            child: InkWell(
                              onTap: onExcluir,
                              borderRadius: BorderRadius.circular(5),
                              hoverColor: AppColors.error.withValues(
                                alpha: 0.12,
                              ),
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: AppColors.error.withValues(
                                      alpha: 0.20,
                                    ),
                                    width: 0.8,
                                  ),
                                ),
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 11.5,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),

            // Obra Principal
            Text(
              demanda.obraNome,
              style: AppCss.smallBold
                  .setSize(13)
                  .setColor(const Color(0xFF0F172A)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),

            // Etapa da Obra (Pavimento/Bloco/Vigas)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.layers_outlined,
                    size: 11,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      demanda.etapaProjeto,
                      style: AppCss.minimumBold
                          .setSize(10)
                          .setColor(const Color(0xFF334155)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Cliente e Solicitante Comercial
            Text(
              '${demanda.clienteNome} • ${demanda.solicitanteComercial}',
              style: AppCss.minimumRegular
                  .setSize(10)
                  .setColor(const Color(0xFF64748B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),

            // Assinatura do Criador
            Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 11,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    'Por: ${demanda.criadoPorNome.isNotEmpty ? demanda.criadoPorNome : demanda.solicitanteComercial}',
                    style: AppCss.minimumRegular
                        .setSize(9.5)
                        .setColor(const Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (demanda.caminhoPastaRede.isNotEmpty) ...[
                  Tooltip(
                    message: 'Caminho de rede informado',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.folder_shared_outlined,
                        size: 10,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // Planilhas (detalhamentos) da demanda
            _linhaEtapas(context),

            // Motivo de correção se houver
            if (demanda.motivoCorrecao != null &&
                demanda.motivoCorrecao!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Text(
                  demanda.motivoCorrecao!,
                  style: AppCss.minimumRegular
                      .setSize(9.5)
                      .setColor(const Color(0xFF92400E)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],

            const SizedBox(height: 6),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 6),

            // Rodapé: Ações de transição de etapa
            _buildAcoesEtapa(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAcoesEtapa(BuildContext context) {
    switch (demanda.etapa) {
      case DemandaEtapa.aguardandoFila:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.touch_app_rounded, size: 12),
            label: const Text('Abrir Demanda / Detalhes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              textStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );

      case DemandaEtapa.emProducao:
        return Row(
          children: [
            Expanded(
              child: Tooltip(
                message: 'Retornar para Aguardando Detalhamento',
                child: OutlinedButton(
                  onPressed: () {
                    onMover(DemandaEtapa.aguardandoFila);
                    NotificationService.showNeutral(
                      'Demanda Retornada',
                      '${demanda.obraNome} retornou para Aguardando Detalhamento.',
                      position: NotificationPosition.bottom,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 2,
                    ),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    backgroundColor: const Color(0xFFF8FAFC),
                    foregroundColor: const Color(0xFF475569),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_rounded, size: 12),
                      SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          'Aguard. Det.',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _dialogMoverCorrecao(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 2,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'P/ Correção',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 3),
                    Icon(Icons.arrow_forward_rounded, size: 12),
                  ],
                ),
              ),
            ),
          ],
        );

      case DemandaEtapa.aguardandoCorrecao:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  onMover(DemandaEtapa.emProducao);
                  NotificationService.showNeutral(
                    'Demanda Retornada',
                    '${demanda.obraNome} retornou para Em Produção.',
                    position: NotificationPosition.bottom,
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 2,
                  ),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  backgroundColor: const Color(0xFFF8FAFC),
                  foregroundColor: const Color(0xFF475569),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_rounded, size: 12),
                    SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        'Produção',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  onMover(DemandaEtapa.corrigindo);
                  NotificationService.showPositive(
                    'Iniciando Correção',
                    '${demanda.obraNome} em ajuste.',
                    position: NotificationPosition.bottom,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA580C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 2,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Corrigindo',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 3),
                    Icon(Icons.arrow_forward_rounded, size: 12),
                  ],
                ),
              ),
            ),
          ],
        );

      case DemandaEtapa.corrigindo:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  onMover(DemandaEtapa.aguardandoCorrecao);
                  NotificationService.showNeutral(
                    'Demanda Retornada',
                    '${demanda.obraNome} voltou para Aguardando Correção.',
                    position: NotificationPosition.bottom,
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 2,
                  ),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  backgroundColor: const Color(0xFFF8FAFC),
                  foregroundColor: const Color(0xFF475569),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_rounded, size: 12),
                    SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        'Aguardando',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  onMover(DemandaEtapa.finalizadoLiberado);
                  NotificationService.showPositive(
                    'Etapa Liberada',
                    '${demanda.obraNome} liberada/finalizada.',
                    position: NotificationPosition.bottom,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 2,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Finalizar',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 3),
                    Icon(Icons.arrow_forward_rounded, size: 12),
                  ],
                ),
              ),
            ),
          ],
        );

      case DemandaEtapa.finalizadoLiberado:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => onMover(DemandaEtapa.corrigindo),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  backgroundColor: const Color(0xFFF8FAFC),
                  foregroundColor: const Color(0xFF475569),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_rounded, size: 12),
                    SizedBox(width: 3),
                    Flexible(
                      child: Text('Corrigindo',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(child: _botaoArquivar()),
          ],
        );
    }
  }

  Widget _botaoArquivar() {
    return ElevatedButton.icon(
      onPressed: onArquivar,
      icon: const Icon(
        Icons.inventory_2_outlined,
        size: 13,
        color: Colors.white,
      ),
      label: const Text('Arquivar'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFD97706),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Etapas da demanda e quantas já têm detalhamento; abre a janela de
  /// etapas e detalhamentos.
  Widget _linhaEtapas(BuildContext context) {
    final etapas = demanda.etapas;
    final cobertas = etapas.where((e) => e.temDetalhamento).length;
    final dets = demandaCtrl.obterDetalhamentosDaDemanda(demanda).length;
    final vazia = etapas.isEmpty;
    final cor = vazia ? AppColors.statusProduzindo : AppColors.neutralDark;
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: InkWell(
        onTap: () => _abrirEtapasDemanda(context, demanda),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          decoration: BoxDecoration(
            color: vazia ? AppColors.statusProduzindo.withValues(alpha: 0.06) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color: vazia ? AppColors.statusProduzindo.withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
          ),
          child: vazia
              ? Row(
                  children: [
                    Icon(Icons.playlist_add, size: 12, color: cor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text('Definir etapas',
                          style: AppCss.minimumBold.setSize(10).setColor(cor)),
                    ),
                    Icon(Icons.chevron_right, size: 12, color: cor),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.checklist, size: 12, color: cor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '$cobertas/${etapas.length} etapa${etapas.length == 1 ? '' : 's'} • $dets detalhamento${dets == 1 ? '' : 's'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppCss.minimumBold.setSize(10).setColor(cor),
                          ),
                        ),
                        Icon(Icons.chevron_right, size: 12, color: cor),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 3,
                      runSpacing: 3,
                      children: [
                        for (final e in etapas)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: e.temDetalhamento
                                  ? AppColors.statusPronto.withValues(alpha: 0.10)
                                  : AppColors.neutralLightest,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              e.nome,
                              style: AppCss.minimumRegular.setSize(9).setColor(
                                  e.temDetalhamento ? AppColors.statusPronto : AppColors.neutralMedium),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  void _dialogMoverCorrecao(BuildContext context) {
    final motivoCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Enviar para Correção', style: AppCss.mediumBold),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informe o motivo ou ajuste necessário:',
              style: AppCss.minimumRegular,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: motivoCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText:
                    'Ex: Alteração de forma da viga V-12 / Mudança de fck...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              demandaCtrl.moverEtapa(
                context,
                demanda.id,
                DemandaEtapa.aguardandoCorrecao,
                motivoCorrecao: motivoCtrl.text.trim(),
              );
            },
            child: const Text(
              'Confirmar Envio',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
