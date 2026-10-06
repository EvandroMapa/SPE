part of '../dashboard_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modal de Demandas / Detalhamentos Arquivados (Com Ação de Desarquivar)
// ─────────────────────────────────────────────────────────────────────────────
class _ModalArquivadosDialog extends StatefulWidget {
  final List<DemandaModel> arquivados;
  final Future<void> Function(String) onDesarquivar;

  const _ModalArquivadosDialog({
    required this.arquivados,
    required this.onDesarquivar,
  });

  @override
  State<_ModalArquivadosDialog> createState() => _ModalArquivadosDialogState();
}

class _ModalArquivadosDialogState extends State<_ModalArquivadosDialog> {
  String _filtro = '';

  @override
  Widget build(BuildContext context) {
    final q = _filtro.trim().toLowerCase();
    final filtrados = widget.arquivados.where((d) {
      if (q.isEmpty) return true;
      return d.obraNome.toLowerCase().contains(q) ||
          d.clienteNome.toLowerCase().contains(q) ||
          d.etapaProjeto.toLowerCase().contains(q) ||
          d.codigo.toString().contains(q);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 680,
        height: 520,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.inventory_2_outlined,
                          size: 20, color: Color(0xFFD97706)),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Detalhamentos Arquivados',
                            style: AppCss.largeBold.setSize(18)),
                        Text('Itens concluídos ou esgotados',
                            style: AppCss.minimumRegular
                                .setColor(const Color(0xFF64748B))),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Campo de Busca
            TextField(
              decoration: InputDecoration(
                hintText: 'Buscar por obra, cliente ou código...',
                prefixIcon: const Icon(Icons.search, size: 18),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _filtro = v),
            ),
            const SizedBox(height: 14),

            // Lista de Itens Arquivados
            Expanded(
              child: filtrados.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 36, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text('Nenhum item arquivado',
                              style: AppCss.smallBold
                                  .setColor(const Color(0xFF94A3B8))),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtrados.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = filtrados[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('D-${item.codigo}',
                                    style: AppCss.minimumBold
                                        .setSize(10)
                                        .setColor(const Color(0xFF475569))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.obraNome,
                                        style: AppCss.smallBold.setSize(13)),
                                    Text('${item.etapaProjeto} • ${item.clienteNome}',
                                        style: AppCss.minimumRegular
                                            .setSize(11)
                                            .setColor(const Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await widget.onDesarquivar(item.id);
                                  setState(() {
                                    widget.arquivados
                                        .removeWhere((d) => d.id == item.id);
                                  });
                                },
                                icon: const Icon(Icons.unarchive_outlined,
                                    size: 14),
                                label: const Text('Desarquivar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  textStyle: AppCss.minimumBold.setSize(11),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
