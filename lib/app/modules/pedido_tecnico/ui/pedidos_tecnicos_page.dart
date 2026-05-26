import 'package:acoplan/app/core/client/models/pedido_tecnico_model.dart';
import 'package:acoplan/app/core/components/app_scaffold.dart';
import 'package:acoplan/app/core/components/empty_data.dart';
import 'package:acoplan/app/core/components/stream_out.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/pedido_tecnico/pedido_tecnico_controller.dart';
import 'package:acoplan/app/modules/pedido_tecnico/ui/pedido_tecnico_create_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PedidosTecnicosPage extends StatefulWidget {
  const PedidosTecnicosPage({super.key});

  @override
  State<PedidosTecnicosPage> createState() => _PedidosTecnicosPageState();
}

class _PedidosTecnicosPageState extends State<PedidosTecnicosPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = '';
  String _statusFiltro = 'todos'; // 'todos' | 'aberto' | 'cancelado'

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white, size: 20),
        backgroundColor: AppColors.primaryMain,
        title: Text('Pedidos Técnicos',
            style: AppCss.mediumBold.setColor(Colors.white)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryMain,
                AppColors.primaryMain.withValues(alpha: 0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            tooltip: 'Novo Pedido Técnico',
            onPressed: () => _openForm(null),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Barra de filtros ──────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() => _filter = val),
                    decoration: InputDecoration(
                      hintText: 'Buscar por cliente, obra ou código...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _filtroStatusChip('Todos', 'todos'),
                const SizedBox(width: 6),
                _filtroStatusChip('Abertos', 'aberto'),
                const SizedBox(width: 6),
                _filtroStatusChip('Cancelados', 'cancelado'),
              ],
            ),
          ),
          const Divider(height: 1),
          // ── Lista ─────────────────────────────────────────
          Expanded(
            child: StreamOut<List<PedidoTecnicoModel>>(
              stream: pedidoTecnicoCtrl.pedidosStream.listen,
              builder: (context, pedidos) {
                final filtered = pedidos.where((p) {
                  final query = _filter.toLowerCase();
                  final matchText =
                      p.clienteNome.toLowerCase().contains(query) ||
                          p.obraNome.toLowerCase().contains(query) ||
                          p.codigo.toString().contains(query) ||
                          p.identificador.toLowerCase().contains(query) ||
                          p.detalhamentoCodigo.toString().contains(query);
                  final matchStatus = _statusFiltro == 'todos' ||
                      p.status == _statusFiltro;
                  return matchText && matchStatus;
                }).toList();

                if (filtered.isEmpty) {
                  return const EmptyData(
                      message: 'Nenhum pedido técnico encontrado');
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return _PedidoCard(
                      pedido: filtered[index],
                      onTap: () => _openForm(filtered[index]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filtroStatusChip(String label, String valor) {
    final on = _statusFiltro == valor;
    return GestureDetector(
      onTap: () => setState(() => _statusFiltro = valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: on
              ? AppColors.primaryMain.withValues(alpha: 0.10)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: on
                ? AppColors.primaryMain.withValues(alpha: 0.40)
                : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: AppCss.minimumBold.setSize(12).setColor(
              on ? AppColors.primaryMain : Colors.grey[600]!),
        ),
      ),
    );
  }

  void _openForm(PedidoTecnicoModel? pedido) async {
    await push(context, PedidoTecnicoCreatePage(pedido: pedido));
  }
}

// ─────────────────────────────────────────────────────────────
// Card do pedido na lista
// ─────────────────────────────────────────────────────────────
class _PedidoCard extends StatelessWidget {
  final PedidoTecnicoModel pedido;
  final VoidCallback onTap;

  const _PedidoCard({
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
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
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
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12)),
              border: Border(
                  bottom: BorderSide(
                      color:
                          AppColors.primaryMain.withValues(alpha: 0.10))),
            ),
            child: Row(
              children: [
                // Número do pedido
                Container(
                  width: 44,
                  height: 44,
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
                        color:
                            AppColors.primaryMain.withValues(alpha: 0.30),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
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
                                  color: statusColor
                                      .withValues(alpha: 0.30)),
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
                      Text(
                        'Det. ${pedido.detalhamentoCodigo} • ${fmt.format(pedido.criadoEm.toLocal())}',
                        style: AppCss.minimumRegular
                            .setColor(Colors.grey[500]!)
                            .setSize(11),
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
                          Icons.person_outline, pedido.clienteNome),
                      const SizedBox(height: 6),
                      _infoRow(
                          Icons.location_on_outlined, pedido.obraNome),
                      if (pedido.observacao.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _infoRow(Icons.notes_outlined,
                            pedido.observacao,
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
                          ? '${pedido.pesoTotal.toStringAsFixed(2)} kg'
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

  Widget _infoRow(IconData icon, String text, {bool italic = false}) =>
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
                    fontStyle:
                        italic ? FontStyle.italic : FontStyle.normal,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );

  Widget _statChip(IconData icon, String label, Color color) =>
      Container(
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
            Text(label,
                style:
                    AppCss.minimumBold.setColor(color).setSize(11)),
          ],
        ),
      );
}
