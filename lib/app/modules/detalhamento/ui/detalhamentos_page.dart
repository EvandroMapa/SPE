import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/components/app_scaffold.dart';
import 'package:acoplan/app/core/components/empty_data.dart';
import 'package:acoplan/app/core/components/stream_out.dart';
import 'package:acoplan/app/core/client/models/cliente_model.dart';
import 'package:acoplan/app/core/client/models/detalhamento_model.dart';
import 'package:acoplan/app/core/client/models/pedido_tecnico_model.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/detalhamento/detalhamento_controller.dart';
import 'package:acoplan/app/modules/detalhamento/detalhamento_view_model.dart';
import 'package:acoplan/app/modules/detalhamento/ui/detalhamento_create_page.dart';
import 'package:acoplan/app/modules/detalhamento/pdf_detalhamento.dart';
import 'package:acoplan/app/modules/forma/forma_controller.dart';
import 'package:acoplan/app/modules/pedido_tecnico/pedido_tecnico_controller.dart';
import 'package:acoplan/app/modules/pedido_tecnico/ui/pedido_tecnico_create_page.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

class DetalhamentosPage extends StatefulWidget {
  const DetalhamentosPage({super.key});

  @override
  State<DetalhamentosPage> createState() => _DetalhamentosPageState();
}

class _DetalhamentosPageState extends State<DetalhamentosPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = '';
  final Set<String> _expandidos = {};
  String? _selecionadoId;

  // Ordenação
  String _ordenarPor = 'codigo'; // 'codigo' | 'cliente' | 'obra' | 'peso' | 'elementos'
  bool _ordenarAsc = false; // false = mais recentes primeiro

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white, size: 20),
        backgroundColor: AppColors.primaryMain,
        title: Text('Projetos',
            style: AppCss.mediumBold.setColor(Colors.white)),
        actions: [
          Tooltip(
            message: 'Duplicar projeto selecionado',
            child: IconButton(
              icon: Icon(Icons.copy_outlined,
                  color: _selecionadoId != null
                      ? Colors.white
                      : Colors.white38),
              onPressed: _selecionadoId != null ? _duplicar : null,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _openForm(null),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Busca ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _filter = val),
              decoration: InputDecoration(
                hintText: 'Buscar por cliente, obra ou código...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _filter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _filter = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          // ── Chips de ordenação ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ordenarChip('Código', 'codigo', Icons.tag),
                  const SizedBox(width: 6),
                  _ordenarChip('Cliente', 'cliente', Icons.person_outline),
                  const SizedBox(width: 6),
                  _ordenarChip('Obra', 'obra', Icons.business_outlined),
                  const SizedBox(width: 6),
                  _ordenarChip('Peso', 'peso', Icons.scale_outlined),
                  const SizedBox(width: 6),
                  _ordenarChip('Elementos', 'elementos', Icons.layers_outlined),
                ],
              ),
            ),
          ),
          // ── Lista ──
          Expanded(
            child: StreamOut<List<DetalhamentoModel>>(
              stream: detalhamentoCtrl.detalhamentosStream.listen,
              builder: (context, detalhamentos) {
                // Filtrar
                var filtered = detalhamentos.where((p) {
                  final query = _filter.toLowerCase();
                  return p.clienteNome.toLowerCase().contains(query) ||
                      p.obraNome.toLowerCase().contains(query) ||
                      p.codigo.toString().contains(query);
                }).toList();

                // Ordenar
                filtered.sort((a, b) {
                  int cmp;
                  switch (_ordenarPor) {
                    case 'cliente':
                      cmp = a.clienteNome.toLowerCase().compareTo(b.clienteNome.toLowerCase());
                      break;
                    case 'obra':
                      cmp = a.obraNome.toLowerCase().compareTo(b.obraNome.toLowerCase());
                      break;
                    case 'peso':
                      cmp = a.pesoTotal.compareTo(b.pesoTotal);
                      break;
                    case 'elementos':
                      cmp = a.elementos.length.compareTo(b.elementos.length);
                      break;
                    default: // codigo
                      cmp = a.codigo.compareTo(b.codigo);
                  }
                  return _ordenarAsc ? cmp : -cmp;
                });

                if (filtered.isEmpty) {
                  return const EmptyData(
                      message: 'Nenhum detalhamento encontrado');
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final detalhamento = filtered[index];
                    return _DetalhamentoCard(
                      detalhamento: detalhamento,
                      pedidosVinculados: pedidoTecnicoCtrl.pedidos
                          .where((p) => p.detalhamentoId == detalhamento.id)
                          .toList(),
                      expandido: _expandidos.contains(detalhamento.id),
                      selecionado: _selecionadoId == detalhamento.id,
                      onSelecionar: () => setState(() {
                        _selecionadoId = _selecionadoId == detalhamento.id
                            ? null
                            : detalhamento.id;
                      }),
                      onToggleExpand: () => setState(() {
                        if (_expandidos.contains(detalhamento.id)) {
                          _expandidos.remove(detalhamento.id);
                        } else {
                          _expandidos.add(detalhamento.id);
                        }
                      }),
                      onEditar: () => _openForm(detalhamento),
                      onPdf: () => _gerarPDF(detalhamento),
                      onExcluir: () => _confirmDelete(detalhamento),
                      onAbrirPedido: (p) => push(context, PedidoTecnicoCreatePage(pedido: p)),
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

  Widget _ordenarChip(String label, String campo, IconData icone) {
    final selecionado = _ordenarPor == campo;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_ordenarPor == campo) {
            _ordenarAsc = !_ordenarAsc;
          } else {
            _ordenarPor = campo;
            _ordenarAsc = campo == 'cliente' || campo == 'obra'; // texto = asc, números = desc
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selecionado
              ? AppColors.primaryMain.withValues(alpha: 0.10)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selecionado
                ? AppColors.primaryMain.withValues(alpha: 0.40)
                : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone,
                size: 13,
                color: selecionado ? AppColors.primaryMain : Colors.grey[500]),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppCss.minimumBold.setSize(12).setColor(
                    selecionado ? AppColors.primaryMain : Colors.grey[600]!,
                  ),
            ),
            if (selecionado) ...[
              const SizedBox(width: 3),
              Icon(
                _ordenarAsc ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: AppColors.primaryMain,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openForm(DetalhamentoModel? detalhamento) async {
    if (detalhamento != null) {
      final estaVinculada = await BackendClient.detalhamentos.estaVinculadoAPedido(detalhamento.id);
      if (estaVinculada) {
        if (!mounted) return;
        NotificationService.showNeutral('Modo de Visualização', 'Este detalhamento está em um Pedido Técnico e não pode ser alterado.', position: NotificationPosition.bottom);
        await push(context, DetalhamentoCreatePage(detalhamento: detalhamento, isReadOnly: true));
        return;
      }
    }
    if (!mounted) return;
    await push(context, DetalhamentoCreatePage(detalhamento: detalhamento));
  }

  void _duplicar() {
    final original = detalhamentoCtrl.detalhamentos
        .where((d) => d.id == _selecionadoId)
        .firstOrNull;
    if (original == null) return;

    // Buscar cliente e obra do original
    ClienteModel? clienteOriginal;
    ObraModel? obraOriginal;
    for (final c in BackendClient.clientes.data) {
      if (c.id == original.clienteId) {
        clienteOriginal = c;
        for (final o in c.obras) {
          if (o.id == original.obraId) {
            obraOriginal = o;
            break;
          }
        }
        break;
      }
    }

    // Próximo código
    final proximoCodigo = detalhamentoCtrl.detalhamentos.isEmpty
        ? 1
        : detalhamentoCtrl.detalhamentos.map((p) => p.codigo).reduce((a, b) => a > b ? a : b) + 1;

    // Iniciar form vazio com dados pré-preenchidos
    detalhamentoCtrl.init(null);
    final form = detalhamentoCtrl.form;
    form.codigo = proximoCodigo;
    form.clienteSelecionado = clienteOriginal;
    form.obraSelecionada = obraOriginal;

    // Copiar elementos e posições
    form.elementos = original.elementos
        .map((e) => ElementoCreateModel.fromModel(e))
        .toList();

    detalhamentoCtrl.formStream.update();

    setState(() => _selecionadoId = null);
    push(context, DetalhamentoCreatePage(skipInit: true));
  }

  void _gerarPDF(DetalhamentoModel detalhamento) async {
    final pdfBytes = await PdfDetalhamento.gerarRelatorio(detalhamento, formaCtrl.formas, BackendClient.bitolas.data);
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'Detalhamento ${detalhamento.codigo} - ${detalhamento.clienteNome}',
    );
  }

  void _confirmDelete(DetalhamentoModel detalhamento) async {
    final estaVinculada = await BackendClient.detalhamentos.estaVinculadoAPedido(detalhamento.id);
    if (estaVinculada) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(Icons.info_outline, size: 40, color: Colors.orange[700]),
          title: Text('Exclusão Bloqueada', textAlign: TextAlign.center, style: AppCss.mediumBold),
          content: Text(
            'Este detalhamento não pode ser excluído pois possui elementos vinculados a um Pedido Técnico.\n\nRemova os elementos do pedido antes de excluir.',
            style: AppCss.smallRegular,
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryMain),
              onPressed: () => pop(context),
              child: Text('Entendi', style: AppCss.smallBold.setColor(Colors.white)),
            ),
          ],
        ),
      );
      return;
    }
    
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Detalhamento'),
        content: Text('Deseja realmente excluir o detalhamento ${detalhamento.codigo}?'),
        actions: [
          TextButton(onPressed: () => pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              pop(context);
              detalhamentoCtrl.onDelete(context, detalhamento);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Card do detalhamento na lista
// ─────────────────────────────────────────────────────────────
class _DetalhamentoCard extends StatelessWidget {
  final DetalhamentoModel detalhamento;
  final List<PedidoTecnicoModel> pedidosVinculados;
  final bool expandido;
  final bool selecionado;
  final VoidCallback onSelecionar;
  final VoidCallback onToggleExpand;
  final VoidCallback onEditar;
  final VoidCallback onPdf;
  final VoidCallback onExcluir;
  final void Function(PedidoTecnicoModel) onAbrirPedido;

  const _DetalhamentoCard({
    required this.detalhamento,
    required this.pedidosVinculados,
    required this.expandido,
    required this.selecionado,
    required this.onSelecionar,
    required this.onToggleExpand,
    required this.onEditar,
    required this.onPdf,
    required this.onExcluir,
    required this.onAbrirPedido,
  });

  @override
  Widget build(BuildContext context) {
    final temPedidos = pedidosVinculados.isNotEmpty;
    final fmt = DateFormat('dd/MM/yyyy');

    return GestureDetector(
      onTap: onSelecionar,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selecionado
              ? const Color(0xFFEFF6FF)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selecionado
                ? AppColors.primaryMain.withValues(alpha: 0.50)
                : Colors.grey[200]!,
            width: selecionado ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: selecionado
                  ? AppColors.primaryMain.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: selecionado ? 8 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
          // ── Conteúdo principal ──
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
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
                // Busca o código do cliente e prefixo da obra em memória
                String prefixo = '';
                int codigoCliente = 0;
                for (final c in BackendClient.clientes.data) {
                  if (c.id == detalhamento.clienteId) {
                    codigoCliente = c.codigo;
                  }
                  for (final o in c.obras) {
                    if (o.id == detalhamento.obraId) {
                      prefixo = o.prefixo;
                      break;
                    }
                  }
                  if (prefixo.isNotEmpty && codigoCliente > 0) break;
                }
                final codStr = codigoCliente > 0 ? '$codigoCliente - ' : '';
                return Text(
                  prefixo.isNotEmpty
                      ? '$codStr${detalhamento.clienteNome} - $prefixo'
                      : '$codStr${detalhamento.clienteNome}',
                  style: AppCss.smallBold.setSize(14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                if (detalhamento.obraNome.isNotEmpty)
                  Text(
                    detalhamento.obraNome,
                    style: AppCss.minimumRegular.setColor(Colors.grey[600]!).setSize(12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 3),
                Row(children: [
                  Icon(Icons.layers_outlined, size: 12, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    '${detalhamento.elementos.length} elemento(s)',
                    style: AppCss.minimumBold.setColor(Colors.grey[600]!).setSize(11),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.scale_outlined,
                      size: 12,
                      color: detalhamento.pesoTotal > 0
                          ? const Color(0xFF10B981)
                          : Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    detalhamento.pesoTotal > 0
                        ? '${detalhamento.pesoTotal.toStringAsFixed(2)} kg'
                        : 'Sem peso',
                    style: AppCss.minimumBold
                        .setColor(detalhamento.pesoTotal > 0
                            ? const Color(0xFF10B981)
                            : Colors.grey[400]!)
                        .setSize(11),
                  ),
                ]),
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
                              ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                              : const Color(0xFF3B82F6).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF3B82F6)
                                .withValues(alpha: expandido ? 0.35 : 0.15),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.assignment_outlined,
                                size: 14,
                                color: const Color(0xFF3B82F6)),
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
                              child: Icon(Icons.expand_more,
                                  size: 14,
                                  color: const Color(0xFF3B82F6)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (temPedidos) const SizedBox(width: 8),
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
                      child: const Icon(Icons.picture_as_pdf_outlined,
                          size: 18, color: Colors.orange),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Editar',
                  child: InkWell(
                    onTap: onEditar,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primaryMain.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.edit_outlined,
                          size: 18, color: AppColors.primaryMain),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Excluir',
                  child: InkWell(
                    onTap: onExcluir,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.delete_outline,
                          size: 18, color: AppColors.error),
                    ),
                  ),
                ),
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
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(Icons.assignment_outlined,
                                  size: 13, color: Colors.grey[500]),
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
                          final statusLabel =
                              p.isAberto ? 'ABERTO' : 'CANCELADO';
                          return InkWell(
                            onTap: () => onAbrirPedido(p),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.assignment_outlined,
                                      size: 14,
                                      color: AppColors.primaryMain),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      p.identificador.isNotEmpty
                                          ? p.identificador
                                          : 'PT ${p.codigo}',
                                      style:
                                          AppCss.minimumBold.setSize(12),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: statusColor
                                          .withValues(alpha: 0.12),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      border: Border.all(
                                          color: statusColor
                                              .withValues(alpha: 0.30)),
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
                                  Icon(Icons.chevron_right,
                                      size: 14, color: Colors.grey[350]),
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
