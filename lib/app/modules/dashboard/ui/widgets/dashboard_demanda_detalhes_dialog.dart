part of '../dashboard_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modal de Detalhes da Demanda (Visualização, Contato, Pasta de Rede e Geração)
// ─────────────────────────────────────────────────────────────────────────────
class _DemandaDetalhesDialog extends StatelessWidget {
  final DemandaModel demanda;
  final VoidCallback? onEditar;
  final VoidCallback? onExcluir;

  const _DemandaDetalhesDialog({
    required this.demanda,
    this.onEditar,
    this.onExcluir,
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 650,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.assignment_outlined,
                        size: 24, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Demanda D-${demanda.codigo}',
                                style: AppCss.minimumBold
                                    .setSize(12)
                                    .setColor(const Color(0xFF64748B))),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: prioridadeColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                demanda.prioridade.toUpperCase(),
                                style: AppCss.minimumBold
                                    .setSize(9)
                                    .setColor(prioridadeColor),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A)
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                demanda.etapa.label,
                                style: AppCss.minimumBold
                                    .setSize(9)
                                    .setColor(const Color(0xFF0F172A)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          demanda.obraNome,
                          style: AppCss.largeBold
                              .setSize(17)
                              .setColor(const Color(0xFF0F172A)),
                        ),
                        Text(
                          demanda.etapaProjeto,
                          style: AppCss.smallBold
                              .setSize(13)
                              .setColor(const Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onEditar != null)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              size: 20, color: Color(0xFF2563EB)),
                          tooltip: 'Editar Demanda',
                          onPressed: () {
                            Navigator.pop(context);
                            onEditar?.call();
                          },
                        ),
                      if (onExcluir != null)
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded,
                              size: 20, color: AppColors.error),
                          tooltip: 'Excluir Demanda',
                          onPressed: onExcluir,
                        ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),

              // Bloco 1: Dados do Cliente
              Text('DADOS DO CLIENTE',
                  style: AppCss.minimumBold
                      .setSize(11)
                      .setColor(const Color(0xFF94A3B8))
                      .setLetterSpacing(0.8)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.business_outlined,
                            size: 15, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            demanda.clienteNome,
                            style: AppCss.smallBold
                                .setSize(13)
                                .setColor(const Color(0xFF0F172A)),
                          ),
                        ),
                      ],
                    ),
                    if (demanda.clienteTelefone.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined,
                              size: 15, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Text(
                            demanda.clienteTelefone,
                            style: AppCss.minimumBold
                                .setSize(12)
                                .setColor(const Color(0xFF334155)),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(
                                  text: demanda.clienteTelefone));
                              NotificationService.showPositive(
                                'Telefone Copiado',
                                demanda.clienteTelefone,
                                position: NotificationPosition.bottom,
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(Icons.copy_rounded,
                                  size: 13, color: Color(0xFF2563EB)),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (demanda.clienteEndereco.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 15, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              demanda.clienteEndereco,
                              style: AppCss.minimumRegular
                                  .setSize(12)
                                  .setColor(const Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Bloco 2: Caminho da Pasta de Rede
              Text('PASTA DO PROJETO NA REDE',
                  style: AppCss.minimumBold
                      .setSize(11)
                      .setColor(const Color(0xFF94A3B8))
                      .setLetterSpacing(0.8)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.folder_shared_outlined,
                            size: 16, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectableText(
                            demanda.caminhoPastaRede.isNotEmpty
                                ? demanda.caminhoPastaRede
                                : 'Nenhum caminho de rede informado',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: demanda.caminhoPastaRede.isNotEmpty
                                  ? const Color(0xFF0F172A)
                                  : Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (demanda.caminhoPastaRede.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(
                                  text: demanda.caminhoPastaRede));
                              NotificationService.showPositive(
                                'Caminho Copiado',
                                'Cole na barra do Windows Explorer para acessar os arquivos.',
                                position: NotificationPosition.bottom,
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, size: 14),
                            label: const Text('Copiar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF2563EB),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              elevation: 0,
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6)),
                              textStyle: AppCss.minimumBold.setSize(11),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Bloco 3: Assinatura e Registro
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_outlined,
                        size: 16, color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Criado e assinado por: ${demanda.criadoPorNome.isNotEmpty ? demanda.criadoPorNome : demanda.solicitanteComercial}',
                            style: AppCss.minimumBold
                                .setSize(11)
                                .setColor(const Color(0xFF334155)),
                          ),
                          Text(
                            'Registrado em: ${DateFormat('dd/MM/yyyy HH:mm').format(demanda.criadoEm)}',
                            style: AppCss.minimumRegular
                                .setSize(10)
                                .setColor(const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (demanda.motivoCorrecao != null &&
                  demanda.motivoCorrecao!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('HISTÓRICO / MOTIVO DE CORREÇÃO',
                    style: AppCss.minimumBold
                        .setSize(11)
                        .setColor(const Color(0xFFD97706))
                        .setLetterSpacing(0.8)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    demanda.motivoCorrecao!,
                    style: AppCss.minimumRegular
                        .setSize(12)
                        .setColor(const Color(0xFF92400E)),
                  ),
                ),
              ],

              // Etapas e detalhamentos da demanda
              const SizedBox(height: 16),
              _SecaoEtapas(demandaId: demanda.id),

              // Histórico completo (quem fez o quê e quando)
              const SizedBox(height: 12),
              Text('HISTÓRICO',
                  style: AppCss.minimumBold.setSize(11).setColor(const Color(0xFF64748B)).setLetterSpacing(0.8)),
              const SizedBox(height: 8),
              _HistoricoDemanda(demandaId: demanda.id),
            ],
          ),
        ),
      ),
    );
  }
}

/// Etapas da demanda com o detalhamento que cobre cada uma. Acompanha as
/// alterações feitas na janela de etapas sem precisar reabrir os detalhes.
class _SecaoEtapas extends StatelessWidget {
  final String demandaId;

  const _SecaoEtapas({required this.demandaId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DemandaModel>>(
      stream: demandaCtrl.demandasStream.listen,
      builder: (context, _) => StreamBuilder<List<DetalhamentoModel>>(
        stream: BackendClient.detalhamentos.dataStream.listen,
        builder: (context, _) {
          final demanda = demandaCtrl.demandas.where((d) => d.id == demandaId).firstOrNull;
          if (demanda == null) return const SizedBox.shrink();
          final etapas = [...demanda.etapas]..sort((a, b) => a.ordem.compareTo(b.ordem));
          final dets = demandaCtrl.obterDetalhamentosDaDemanda(demanda);
          final cobertas = etapas.where((e) => e.temDetalhamento).length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      etapas.isEmpty
                          ? 'ETAPAS E DETALHAMENTOS'
                          : 'ETAPAS ($cobertas/${etapas.length} em detalhamento • ${dets.length} detalhamento(s))',
                      style: AppCss.minimumBold.setSize(11).setColor(const Color(0xFF64748B)).setLetterSpacing(0.8),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: AppColors.statusProduzindo,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () => _abrirEtapasDemanda(context, demanda),
                    icon: Icon(etapas.isEmpty ? Icons.checklist : Icons.edit_outlined, size: 16),
                    label: Text(
                      etapas.isEmpty ? 'Definir etapas' : 'Gerenciar',
                      style: AppCss.minimumBold.setSize(12).setColor(AppColors.statusProduzindo),
                    ),
                  ),
                ],
              ),
              if (etapas.isEmpty)
                Text(
                  'Nenhuma etapa definida. Divida a demanda em partes (ex.: Sapatas, Vigas 0) para detalhar.',
                  style: AppCss.minimumRegular.setSize(12).setColor(AppColors.neutralMedium),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      for (final (i, e) in etapas.indexed) ...[
                        if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        _linhaEtapa(e, dets),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _linhaEtapa(DemandaEtapaModel etapa, List<DetalhamentoModel> dets) {
    final det = dets.where((d) => d.id == etapa.detalhamentoId).firstOrNull;
    final cor = det != null ? AppColors.statusPronto : AppColors.neutralMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(det != null ? Icons.check_circle : Icons.radio_button_unchecked, size: 16, color: cor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              etapa.nome,
              overflow: TextOverflow.ellipsis,
              style: AppCss.minimumBold.setSize(13).setColor(AppColors.black),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              det != null ? 'Detalhamento ${det.codigo}' : 'Sem detalhamento',
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: AppCss.minimumRegular.setSize(12).setColor(cor),
            ),
          ),
        ],
      ),
    );
  }
}
