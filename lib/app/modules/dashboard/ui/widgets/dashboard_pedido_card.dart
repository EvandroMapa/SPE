part of '../dashboard_page.dart';

// ─────────────────────────────────────────────────────────────
// Card de Pedido Técnico no Dashboard
// ─────────────────────────────────────────────────────────────
class _DashboardPedidoCard extends StatelessWidget {
  final PedidoTecnicoModel pedido;
  final VoidCallback onTap;

  const _DashboardPedidoCard({
    required this.pedido,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusAberto = pedido.isAberto;
    final statusColor =
        statusAberto ? const Color(0xFF10B981) : Colors.grey[400]!;
    final statusLabel = statusAberto ? 'ABERTO' : 'CANCELADO';
    final fmt = DateFormat('dd/MM/yyyy');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryMain.withValues(alpha: 0.07),
                    AppColors.primaryMain.withValues(alpha: 0.02),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.primaryMain.withValues(alpha: 0.10),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryMain,
                          AppColors.primaryMain.withValues(alpha: 0.80),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryMain.withValues(alpha: 0.30),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.assignment_outlined,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              pedido.identificador.isNotEmpty
                                  ? pedido.identificador
                                  : 'PT ${pedido.codigo}',
                              style: AppCss.smallBold.setSize(14),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: statusColor.withValues(alpha: 0.30)),
                              ),
                              child: Text(
                                statusLabel,
                                style: AppCss.minimumBold
                                    .setColor(statusColor)
                                    .setSize(10),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Builder(
                          builder: (context) {
                            final det = BackendClient.detalhamentos.data
                                .where((d) => d.id == pedido.detalhamentoId)
                                .firstOrNull;
                            final detDesc = det?.descricao.isNotEmpty == true
                                ? ' • ${det!.descricao}'
                                : '';
                            return Text(
                              'Det. ${pedido.detalhamentoCodigo}$detDesc • ${fmt.format(pedido.criadoEm.toLocal())}',
                              style: AppCss.minimumRegular
                                  .setColor(Colors.grey[500]!)
                                  .setSize(11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ── Corpo ──
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoRow(
                            Icons.person_outline,
                            pedido.clienteNome.isNotEmpty
                                ? pedido.clienteNome
                                : 'Cliente não informado'),
                        const SizedBox(height: 6),
                        _infoRow(
                            Icons.location_on_outlined,
                            pedido.obraNome.isNotEmpty
                                ? pedido.obraNome
                                : 'Obra não informada'),
                        if (pedido.observacao.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _infoRow(Icons.notes_outlined, pedido.observacao,
                              italic: true),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _statChip(
                        Icons.layers_outlined,
                        '${pedido.elementos.fold<int>(0, (s, e) => s + e.quantidadeSolicitada)} elemento(s)',
                        AppColors.secondary,
                      ),
                      const SizedBox(height: 6),
                      _statChip(
                        Icons.scale_outlined,
                        pedido.pesoTotal > 0
                            ? (pedido.pesoTotal >= 1000
                                ? '${(pedido.pesoTotal / 1000).toStringAsFixed(2)} t'
                                : '${NumberFormat('#,##0.00', 'pt_BR').format(pedido.pesoTotal)} kg')
                            : 'Sem peso',
                        const Color(0xFF10B981),
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
  }

  static Widget _infoRow(IconData icon, String text, {bool italic = false}) =>
      Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[400]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: AppCss.minimumRegular
                  .setSize(12)
                  .setColor(Colors.grey[700]!)
                  .copyWith(
                    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );

  static Widget _statChip(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Text(label, style: AppCss.minimumBold.setColor(color).setSize(11)),
          ],
        ),
      );
}
