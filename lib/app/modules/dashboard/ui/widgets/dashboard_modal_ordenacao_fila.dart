part of '../dashboard_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modal Interativo de Ordenação da Fila de Entrada
// ─────────────────────────────────────────────────────────────────────────────
class _ModalOrdenacaoFila extends StatefulWidget {
  final List<DemandaModel> filaInicial;
  final ValueChanged<List<DemandaModel>> onSalvar;

  const _ModalOrdenacaoFila({
    required this.filaInicial,
    required this.onSalvar,
  });

  @override
  State<_ModalOrdenacaoFila> createState() => _ModalOrdenacaoFilaState();
}

class _ModalOrdenacaoFilaState extends State<_ModalOrdenacaoFila> {
  late List<DemandaModel> _lista;

  @override
  void initState() {
    super.initState();
    _lista = List.from(widget.filaInicial);
  }

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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 620,
        height: 580,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho do Modal
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Icon(Icons.drag_indicator_rounded,
                      size: 22, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ordenação - Aguardando Detalhamento',
                        style: AppCss.mediumBold
                            .setSize(18)
                            .setColor(const Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Clique e arraste qualquer card para definir a prioridade de produção.',
                        style: AppCss.minimumRegular
                            .setSize(12)
                            .setColor(const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  splashRadius: 20,
                  tooltip: 'Fechar',
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),

            // Lista 100% Arrastável (Drag and Drop limpo e espaçoso)
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: _lista.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _lista.removeAt(oldIndex);
                    _lista.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final item = _lista[index];
                  final prioridadeColor = _corPrioridade(item.prioridade);

                  return ReorderableDragStartListener(
                    key: ValueKey(item.id),
                    index: index,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Ícone de arraste
                            const Icon(Icons.drag_indicator_rounded,
                                size: 20, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 10),

                            // Posição numérica da ordem (#1, #2...)
                            Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFFBFDBFE)),
                              ),
                              child: Text(
                                '#${index + 1}',
                                style: AppCss.mediumBold
                                    .setSize(12)
                                    .setColor(const Color(0xFF2563EB)),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Dados da demanda (Obra, Etapa, Cliente, Prioridade)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          item.obraNome,
                                          style: AppCss.smallBold
                                              .setSize(14)
                                              .setColor(
                                                  const Color(0xFF0F172A)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: prioridadeColor.withValues(
                                              alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          item.prioridade.toUpperCase(),
                                          style: AppCss.minimumBold
                                              .setSize(9)
                                              .setColor(prioridadeColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          item.etapaProjeto,
                                          style: AppCss.minimumBold
                                              .setSize(11)
                                              .setColor(
                                                  const Color(0xFF334155)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          '•  ${item.clienteNome}',
                                          style: AppCss.minimumRegular
                                              .setSize(11)
                                              .setColor(
                                                  const Color(0xFF64748B)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Dica visual de arraste
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Arrastar',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.unfold_more_rounded,
                                      size: 16, color: Color(0xFF94A3B8)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 14),

            // Rodapé do Modal com Ações
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    widget.onSalvar(_lista);
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.check_rounded,
                      size: 16, color: Colors.white),
                  label: const Text('Salvar Ordenação'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
