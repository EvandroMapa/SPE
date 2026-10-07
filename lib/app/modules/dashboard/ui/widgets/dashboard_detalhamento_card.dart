part of '../dashboard_page.dart';

// ─────────────────────────────────────────────────────────────
// Card de Detalhamento no Dashboard
// ─────────────────────────────────────────────────────────────
class _DashboardDetalhamentoCard extends StatelessWidget {
  final DetalhamentoModel detalhamento;
  final List<PedidoTecnicoModel> pedidosVinculados;
  final bool expandido;
  final bool selecionado;
  final VoidCallback onSelecionar;
  final VoidCallback onToggleExpand;
  final VoidCallback onEditar;
  final VoidCallback onPdf;
  final VoidCallback? onExcluir;
  final void Function(PedidoTecnicoModel) onAbrirPedido;
  final VoidCallback? onGerarPedido;
  final VoidCallback onArquivar;

  /// Demanda de origem (ex: "D-12"), se veio do Kanban
  final String? origem;

  const _DashboardDetalhamentoCard({
    required this.detalhamento,
    required this.pedidosVinculados,
    required this.expandido,
    required this.selecionado,
    required this.onSelecionar,
    required this.onToggleExpand,
    required this.onEditar,
    required this.onPdf,
    this.onExcluir,
    required this.onAbrirPedido,
    this.onGerarPedido,
    required this.onArquivar,
    this.origem,
  });

  @override
  Widget build(BuildContext context) {
    final temPedidos = pedidosVinculados.isNotEmpty;
    final fmt = DateFormat('dd/MM/yyyy');
    // Tela estreita: ações no menu ⋮ para não espremer cliente/obra
    final estreito = MediaQuery.sizeOf(context).width < 700;

    return GestureDetector(
      onTap: onSelecionar,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selecionado ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selecionado
                ? AppColors.primaryMain.withValues(alpha: 0.50)
                : const Color(0xFFE2E8F0),
            width: selecionado ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: selecionado
                  ? AppColors.primaryMain.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.02),
              blurRadius: selecionado ? 8 : 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Conteúdo principal ──
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryMain.withValues(alpha: 0.15),
                      AppColors.primaryMain.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    detalhamento.codigo.toString(),
                    style: AppCss.smallBold
                        .setColor(AppColors.primaryMain)
                        .setSize(15),
                  ),
                ),
              ),
              title: Builder(
                builder: (context) {
                  String prefixo = '';
                  for (final c in BackendClient.clientes.data) {
                    if (c.id == detalhamento.clienteId) {
                      for (final o in c.obras) {
                        if (o.id == detalhamento.obraId) {
                          prefixo = o.prefixo;
                          break;
                        }
                      }
                      break;
                    }
                  }
                  final nomeExibicao = prefixo.isNotEmpty
                      ? '${detalhamento.clienteNome} - $prefixo'
                      : (detalhamento.clienteNome.isNotEmpty
                            ? detalhamento.clienteNome
                            : 'Cliente não informado');

                  // Quebra a linha em tela estreita (selos não estouram)
                  return Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        nomeExibicao,
                        style: AppCss.smallBold.setSize(14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Coluna da demanda no Kanban (o fluxo do detalhamento)
                      if (demandaCtrl.demandaDoDetalhamento(detalhamento)
                          case final dem?)
                        _SeloCiclo(
                          dem.etapa.label,
                          _corEtapaKanban(dem.etapa),
                          icon: dem.liberadaParaPedido ? Icons.lock_open : null,
                        ),
                      if (origem != null) ...[
                        Tooltip(
                          message: 'Veio da demanda $origem',
                          child: _SeloCiclo(origem!, AppColors.neutralMedium),
                        ),
                      ],
                    ],
                  );
                },
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Builder(
                    builder: (context) {
                      final d = detalhamento.desenho.trim();
                      final p = detalhamento.pavimento.trim();
                      String linhaDesenhoPavimento;
                      if (d.isNotEmpty && p.isNotEmpty) {
                        linhaDesenhoPavimento = '$d - $p';
                      } else if (d.isNotEmpty) {
                        linhaDesenhoPavimento = d;
                      } else if (p.isNotEmpty) {
                        linhaDesenhoPavimento = p;
                      } else {
                        linhaDesenhoPavimento = detalhamento.obraNome;
                      }
                      if (linhaDesenhoPavimento.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        linhaDesenhoPavimento,
                        style: AppCss.minimumRegular
                            .setColor(Colors.grey[600]!)
                            .setSize(12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                  const SizedBox(height: 3),
                  // Quebra a linha em tela estreita (antes estourava)
                  Wrap(
                    spacing: 12,
                    runSpacing: 2,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.layers_outlined,
                            size: 12,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${detalhamento.elementos.length} elemento(s)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppCss.minimumBold
                                  .setColor(Colors.grey[600]!)
                                  .setSize(11),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.scale_outlined,
                            size: 12,
                            color: detalhamento.pesoTotal > 0
                                ? AppColors.statusPronto
                                : Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              detalhamento.pesoTotal > 0
                                  ? (detalhamento.pesoTotal >= 1000
                                        ? '${NumberFormat('#,##0.00', 'pt_BR').format(detalhamento.pesoTotal / 1000)} t'
                                        : '${NumberFormat('#,##0.00', 'pt_BR').format(detalhamento.pesoTotal)} kg')
                                  : 'Sem peso',
                              style: AppCss.minimumBold
                                  .setColor(
                                    detalhamento.pesoTotal > 0
                                        ? AppColors.statusPronto
                                        : Colors.grey[400]!,
                                  )
                                  .setSize(11),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Badge de pedidos vinculados
                  if (temPedidos)
                    Tooltip(
                      message:
                          '${pedidosVinculados.length} pedido(s) técnico(s)',
                      child: InkWell(
                        onTap: onToggleExpand,
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: expandido
                                ? const Color(
                                    0xFF3B82F6,
                                  ).withValues(alpha: 0.15)
                                : const Color(
                                    0xFF3B82F6,
                                  ).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(
                                0xFF3B82F6,
                              ).withValues(alpha: expandido ? 0.35 : 0.15),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.assignment_outlined,
                                size: 14,
                                color: Color(0xFF3B82F6),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${pedidosVinculados.length}',
                                style: AppCss.minimumBold
                                    .setColor(const Color(0xFF3B82F6))
                                    .setSize(12),
                              ),
                              const SizedBox(width: 2),
                              AnimatedRotation(
                                turns: expandido ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: const Icon(
                                  Icons.expand_more,
                                  size: 14,
                                  color: Color(0xFF3B82F6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (temPedidos) const SizedBox(width: 8),
                  if (!estreito) ...[
                    Tooltip(
                      message: 'Gerar PDF',
                      child: InkWell(
                        onTap: onPdf,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 18,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (onGerarPedido != null) ...[
                      Tooltip(
                        message: 'Emitir Pedido Técnico',
                        child: InkWell(
                          onTap: onGerarPedido,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF059669,
                              ).withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.post_add_outlined,
                              size: 18,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Tooltip(
                      message: 'Editar',
                      child: InkWell(
                        onTap: onEditar,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primaryMain.withValues(
                              alpha: 0.10,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: AppColors.primaryMain,
                          ),
                        ),
                      ),
                    ),
                  ],
                  // Excluir no menu, longe de um clique acidental (padrão PCP)
                  CadastroMenu([
                    if (estreito) ...[
                      CadastroAcao(
                        Icons.picture_as_pdf_outlined,
                        'Gerar PDF',
                        onPdf,
                      ),
                      if (onGerarPedido != null)
                        CadastroAcao(
                          Icons.post_add_outlined,
                          'Emitir pedido técnico',
                          onGerarPedido!,
                        ),
                      CadastroAcao(
                        Icons.edit_outlined,
                        'Editar detalhamento',
                        onEditar,
                      ),
                    ],
                    CadastroAcao(
                      detalhamento.isArquivado
                          ? Icons.unarchive_outlined
                          : Icons.inventory_2_outlined,
                      detalhamento.isArquivado ? 'Desarquivar' : 'Arquivar',
                      onArquivar,
                    ),
                    if (onExcluir != null)
                      CadastroAcao(
                        Icons.delete_outline,
                        'Excluir detalhamento',
                        onExcluir!,
                        destrutiva: true,
                      ),
                  ]),
                ],
              ),
            ),
            // ── Lista de pedidos vinculados (expansível) ──
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: temPedidos
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.assignment_outlined,
                                  size: 13,
                                  color: Colors.grey[500],
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'PEDIDOS TÉCNICOS',
                                  style: AppCss.minimumBold
                                      .setColor(Colors.grey[500]!)
                                      .setSize(10)
                                      .setLetterSpacing(0.8),
                                ),
                              ],
                            ),
                          ),
                          ...pedidosVinculados.map((p) {
                            final statusColor = p.isAberto
                                ? const Color(0xFF10B981)
                                : Colors.grey[400]!;
                            final statusLabel = p.isAberto
                                ? 'ABERTO'
                                : 'CANCELADO';
                            return InkWell(
                              onTap: () => onAbrirPedido(p),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.assignment_outlined,
                                      size: 14,
                                      color: AppColors.primaryMain,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        p.identificador.isNotEmpty
                                            ? p.identificador
                                            : 'PT ${p.codigo}',
                                        style: AppCss.minimumBold.setSize(12),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: statusColor.withValues(
                                            alpha: 0.30,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        statusLabel,
                                        style: AppCss.minimumBold
                                            .setColor(statusColor)
                                            .setSize(9),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      fmt.format(p.criadoEm.toLocal()),
                                      style: AppCss.minimumRegular
                                          .setColor(Colors.grey[400]!)
                                          .setSize(10),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.chevron_right,
                                      size: 14,
                                      color: Colors.grey[350],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
              crossFadeState: expandido
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }
}
