import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/cliente_model.dart';
import 'package:acoplan/app/core/client/models/pedido_tecnico_model.dart';
import 'package:acoplan/app/core/client/models/detalhamento_model.dart';
import 'package:acoplan/app/core/components/app_drop_down.dart';
import 'package:acoplan/app/core/components/app_scaffold.dart';
import 'package:acoplan/app/core/components/stream_out.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/pedido_tecnico/pedido_tecnico_controller.dart';
import 'package:acoplan/app/modules/pedido_tecnico/pedido_tecnico_view_model.dart';
import 'package:acoplan/app/modules/pedido_tecnico/pdf_pedido_tecnico.dart';
import 'package:acoplan/app/modules/pedido_tecnico/pdf_etiqueta_pedido_tecnico.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:printing/printing.dart';

enum _Sec { dadosGerais, elementos }

class PedidoTecnicoCreatePage extends StatefulWidget {
  final PedidoTecnicoModel? pedido;
  const PedidoTecnicoCreatePage({this.pedido, super.key});

  @override
  State<PedidoTecnicoCreatePage> createState() =>
      _PedidoTecnicoCreatePageState();
}

class _PedidoTecnicoCreatePageState
    extends State<PedidoTecnicoCreatePage> {
  _Sec _sel = _Sec.dadosGerais;

  // Seleções de contexto
  ClienteModel? _clienteSel;
  ObraModel? _obraSel;
  DetalhamentoModel? _detalhamentoSel;
  final _obsCtrl = TextEditingController();

  final Map<String, int> _elementosSelecionados = {};

  String _chave(ElementoModel e) => '${e.id}_${e.nome}';

  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    pedidoTecnicoCtrl.init(widget.pedido);

    // Se editando, restaurar seleções
    if (widget.pedido != null) {
      final p = widget.pedido!;
      _obsCtrl.text = p.observacao;
      _clienteSel = BackendClient.clientes.data
          .where((c) => c.id == p.clienteId)
          .firstOrNull;
      _obraSel =
          _clienteSel?.obras.where((o) => o.id == p.obraId).firstOrNull;
      _detalhamentoSel = BackendClient.detalhamentos.data
          .where((pl) => pl.id == p.detalhamentoId)
          .firstOrNull;
      for (final e in p.elementos) {
        _elementosSelecionados['${e.elementoId}_${e.elementoNome}'] = e.quantidadeSolicitada;
      }
    }
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Pedido Técnico'),
        content: Text(
            'Deseja realmente excluir o Pedido Técnico ${widget.pedido!.codigo}?\nEsta ação não poderá ser desfeita e os elementos voltarão a ficar disponíveis.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      await BackendClient.pedidosTecnicos.delete(widget.pedido!);
      if (mounted) {
        pop(context);
        NotificationService.showPositive(
          'Pedido excluído',
          'Os elementos voltaram a ficar disponíveis',
          position: NotificationPosition.bottom,
        );
      }
    }
  }

  void _gerarPdf({required bool completo}) async {
    if (widget.pedido == null) return;
    final pedido = widget.pedido!;
    final det = BackendClient.detalhamentos.data
        .where((p) => p.id == pedido.detalhamentoId)
        .firstOrNull;

    final pdfBytes = await PdfPedidoTecnico.gerar(
      pedido: pedido,
      detalhamento: det,
      completo: completo,
    );
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: completo
          ? 'PT-${pedido.codigo} - ${pedido.clienteNome} (Completo)'
          : 'PT-${pedido.codigo} - ${pedido.clienteNome} (Resumido)',
    );
  }

  void _gerarEtiqueta() async {
    if (widget.pedido == null) return;
    final pedido = widget.pedido!;
    final det = BackendClient.detalhamentos.data
        .where((p) => p.id == pedido.detalhamentoId)
        .firstOrNull;
    if (det == null) return;

    final formas = BackendClient.formas.data;
    final pdfBytes = await PdfEtiquetaPedidoTecnico.gerar(
      pedido: pedido,
      detalhamento: det,
      formasCadastradas: formas,
    );
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: '${pedido.identificador.isNotEmpty ? pedido.identificador : 'PT-${pedido.codigo}'} - Etiquetas',
    );
  }

  void _cancelarOuReabrir() {
    if (widget.pedido == null) return;
    final pedido = widget.pedido!;
    if (pedido.isAberto) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cancelar Pedido'),
          content: Text(
              'Cancelar o Pedido Técnico ${pedido.codigo}?\nOs elementos voltarão a ficar disponíveis.'),
          actions: [
            TextButton(
                onPressed: () => pop(ctx),
                child: const Text('Voltar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pending),
              onPressed: () {
                pop(ctx);
                pedidoTecnicoCtrl.cancelar(pedido.id);
                pop(context);
              },
              child: const Text('Cancelar Pedido',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reabrir Pedido'),
          content: Text('Reabrir o Pedido Técnico ${pedido.codigo}?'),
          actions: [
            TextButton(
                onPressed: () => pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success),
              onPressed: () {
                pop(ctx);
                pedidoTecnicoCtrl.reabrir(pedido.id);
                pop(context);
              },
              child: const Text('Reabrir',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  List<DetalhamentoModel> get _detalhamentosDaObra {
    if (_clienteSel == null || _obraSel == null) return [];
    return BackendClient.detalhamentos.data
        .where((p) =>
            p.clienteId == _clienteSel!.id &&
            p.obraId == _obraSel!.id)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      resizeAvoid: true,
      backgroundColor: AppColors.neutralLightest,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => pop(context),
          icon: Icon(Icons.arrow_back, color: AppColors.white),
        ),
        title: StreamOut(
          stream: pedidoTecnicoCtrl.formStream.listen,
          builder: (_, form) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                form.isEdit
                    ? widget.pedido!.identificador.isNotEmpty ? widget.pedido!.identificador : 'PT ${form.codigo}'
                    : 'Novo Pedido Técnico',
                style: AppCss.largeBold.setColor(AppColors.white),
              ),
              if (_clienteSel != null)
                Text(
                  '${_clienteSel!.nome} • ${_obraSel?.descricao ?? ''}',
                  style: AppCss.minimumRegular
                      .setColor(Colors.white60)
                      .setSize(11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryMain,
                AppColors.primaryMain.withValues(alpha: 0.85)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: widget.pedido != null
            ? [
                Tooltip(
                  message: widget.pedido!.isAberto
                      ? 'Cancelar Pedido'
                      : 'Reabrir Pedido',
                  child: IconButton(
                    icon: Icon(
                      widget.pedido!.isAberto
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                      color: Colors.white70,
                      size: 20,
                    ),
                    onPressed: _cancelarOuReabrir,
                  ),
                ),
                Tooltip(
                  message: 'Excluir Pedido',
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.white70, size: 20),
                    onPressed: _confirmDelete,
                  ),
                ),
                const SizedBox(width: 4),
              ]
            : null,
        elevation: 2,
      ),
      body: StreamOut(
        stream: pedidoTecnicoCtrl.formStream.listen,
        builder: (_, form) => Row(
          children: [
            _sidebar(form),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: ValueKey(_sel),
                  child: _sel == _Sec.dadosGerais
                      ? _dadosGerais(form)
                      : _elementosView(form),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══ SIDEBAR ═══════════════════════════════════════════
  Widget _sidebar(PedidoTecnicoCreateModel form) {
    Widget item(_Sec s, IconData ic, String tip,
        {bool habilitado = true}) {
      final on = _sel == s;
      final cor = !habilitado
          ? Colors.grey[350]!
          : on
              ? AppColors.primaryMain
              : Colors.grey[400]!;
      return Tooltip(
        message: habilitado ? tip : 'Salve os dados gerais primeiro',
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 300),
        child: InkWell(
          onTap: habilitado
              ? () => setState(() => _sel = s)
              : () => NotificationService.showNegative(
                    'Dados não salvos',
                    'Salve os dados gerais antes de selecionar elementos',
                    position: NotificationPosition.bottom,
                  ),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: on && habilitado
                  ? AppColors.primaryMain.withValues(alpha: 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: on && habilitado
                  ? Border.all(
                      color:
                          AppColors.primaryMain.withValues(alpha: 0.20))
                  : null,
            ),
            child: Stack(alignment: Alignment.center, children: [
              Icon(ic, size: 18, color: cor),
              if (!habilitado)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Icon(Icons.lock_outline,
                      size: 9, color: Colors.grey[400]),
                ),
            ]),
          ),
        ),
      );
    }

    final elementosHabilitado =
        form.isEdit || _detalhamentoSel != null;

    return Container(
      width: 60,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          Tooltip(
            message: form.isEdit
                ? 'Pedido ${form.codigo}'
                : 'Novo Pedido',
            preferBelow: false,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 14),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
                    blurRadius: 8,
                  )
                ],
              ),
              child: Center(
                child: Icon(Icons.assignment_outlined,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
          const SizedBox(height: 8),
          item(_Sec.dadosGerais, Icons.badge_outlined, 'Dados Gerais'),
          item(_Sec.elementos, Icons.check_box_outlined, 'Elementos',
              habilitado: elementosHabilitado),
          const Spacer(),
          // ── Ações de impressão (somente ao editar) ──
          if (form.isEdit) ...[
            const SizedBox(height: 4),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              height: 1,
              color: const Color(0xFFE2E8F0),
            ),
            const SizedBox(height: 4),
            _sidebarAction(
              tooltip: 'PDF Resumido',
              icon: Icons.summarize_outlined,
              color: Colors.deepOrange,
              onTap: () => _gerarPdf(completo: false),
            ),
            _sidebarAction(
              tooltip: 'PDF Completo',
              icon: Icons.picture_as_pdf_outlined,
              color: Colors.orange,
              onTap: () => _gerarPdf(completo: true),
            ),
            _sidebarAction(
              tooltip: 'Etiquetas',
              icon: Icons.label_outline,
              color: const Color(0xFF7C3AED),
              onTap: _gerarEtiqueta,
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _sidebarAction({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  // ═══ DADOS GERAIS ═════════════════════════════════════
  Widget _dadosGerais(PedidoTecnicoCreateModel form) {
    final clientes = BackendClient.clientes.data;
    final obras = _clienteSel?.obras ?? [];
    final detalhamentos = _detalhamentosDaObra;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(children: [
          Icon(Icons.badge_outlined,
              color: AppColors.primaryMain, size: 20),
          const SizedBox(width: 12),
          Text('DADOS GERAIS',
              style: AppCss.mediumBold
                  .setSize(16)
                  .setLetterSpacing(1)),
        ]),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[300]!, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cliente
              AppDropDown<ClienteModel?>(
                label: 'Cliente',
                item: _clienteSel,
                itens: clientes,
                itemLabel: (e) => e?.nome ?? 'Selecione um cliente',
                onSelect: (e) => setState(() {
                  _clienteSel = e;
                  _obraSel = null;
                  _detalhamentoSel = null;
                  _elementosSelecionados.clear();
                }),
              ),
              const SizedBox(height: 16),
              // Obra
              AppDropDown<ObraModel?>(
                label: 'Obra',
                item: _obraSel,
                itens: obras,
                itemLabel: (e) => e?.descricao ?? 'Selecione uma obra',
                onSelect: (e) => setState(() {
                  _obraSel = e;
                  _detalhamentoSel = null;
                  _elementosSelecionados.clear();
                }),
              ),
              const SizedBox(height: 16),
              // Planilha
              AppDropDown<DetalhamentoModel?>(
                label: 'Detalhamento',
                item: _detalhamentoSel,
                itens: detalhamentos,
                itemLabel: (e) =>
                    e != null ? 'Detalhamento ${e.codigo}' : 'Selecione um detalhamento',
                onSelect: (e) => setState(() {
                  _detalhamentoSel = e;
                  _elementosSelecionados.clear();
                }),
              ),
              const SizedBox(height: 16),
              // Observação
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Observação', style: AppCss.smallBold),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _obsCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Observações técnicas do pedido...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _detalhamentoSel != null
              ? () => setState(() => _sel = _Sec.elementos)
              : null,
          child: Container(
            height: 44,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _detalhamentoSel != null
                  ? AppColors.primaryMain
                  : Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'CONTINUAR → SELECIONAR ELEMENTOS',
                style: AppCss.minimumBold
                    .setColor(Colors.white)
                    .setSize(13)
                    .setLetterSpacing(1),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══ ELEMENTOS — PAINEL DUPLO ═══════════════════════════
  Widget _elementosView(PedidoTecnicoCreateModel form) {
    final detalhamento = _detalhamentoSel;
    if (detalhamento == null) {
      return const Center(child: Text('Selecione um detalhamento primeiro'));
    }

    final elementosVm =
        pedidoTecnicoCtrl.elementosComDisponibilidade(detalhamento);

    // Separar: esquerda mostra não-selecionados + parcialmente selecionados
    final disponiveis = <ElementoDetalhamentoViewModel>[];
    final bloqueados = <ElementoDetalhamentoViewModel>[];
    final selecionados = <ElementoDetalhamentoViewModel>[];

    for (final vm in elementosVm) {
      final qtdeSel = _elementosSelecionados['${vm.elemento.id}_${vm.elemento.nome}'];
      if (qtdeSel != null) {
        selecionados.add(vm);
        // Parcial → também aparece na esquerda
        if (qtdeSel < vm.elemento.quantidade) {
          disponiveis.add(vm);
        }
      } else {
        if (vm.estaDisponivel) {
          disponiveis.add(vm);
        } else {
          bloqueados.add(vm);
        }
      }
    }

    final totalSelecionados = selecionados.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ════ CONTAINER ESQUERDO ════
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFFCBD5E1), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _painelDisponiveis(
                    disponiveis, bloqueados, elementosVm),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // ════ CONTAINER DIREITO ════
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.primaryMain.withValues(alpha: 0.35),
                    width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryMain.withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _painelSelecionados(
                    selecionados, detalhamento, form, totalSelecionados),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══ PAINEL ESQUERDO — DISPONÍVEIS ════════════════════
  Widget _painelDisponiveis(
    List<ElementoDetalhamentoViewModel> disponiveis,
    List<ElementoDetalhamentoViewModel> bloqueados,
    List<ElementoDetalhamentoViewModel> todosVm,
  ) {
    final apenasDisponiveis = disponiveis
        .where((vm) => !_elementosSelecionados.containsKey(_chave(vm.elemento)))
        .toList();
    final parciais = disponiveis
        .where((vm) => _elementosSelecionados.containsKey(_chave(vm.elemento)))
        .toList();
    final totalDisp = apenasDisponiveis.length;
    final totalBloq = bloqueados.length;
    final totalParciais = parciais.length;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            border: const Border(bottom: BorderSide(color: Color(0xFFCBD5E1))),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                ),
                child: const Icon(Icons.inventory_2_outlined,
                    color: Color(0xFF10B981), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Elementos do Detalhamento',
                      style: AppCss.mediumBold.setSize(15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$totalDisp disponível(is)${totalParciais > 0 ? ' · $totalParciais parcial(is)' : ''}${totalBloq > 0 ? ' · $totalBloq bloqueado(s)' : ''}',
                      style: AppCss.minimumRegular
                          .setColor(Colors.grey[600]!)
                          .setSize(11),
                    ),
                  ],
                ),
              ),
              if (totalDisp > 0)
                InkWell(
                  onTap: () {
                    setState(() {
                      for (final vm in todosVm) {
                        if (vm.estaDisponivel &&
                            !_elementosSelecionados
                                .containsKey(_chave(vm.elemento))) {
                          _elementosSelecionados[_chave(vm.elemento)] =
                              vm.elemento.quantidade;
                        }
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryMain.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color:
                              AppColors.primaryMain.withValues(alpha: 0.20)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.select_all,
                            size: 16, color: AppColors.primaryMain),
                        const SizedBox(width: 5),
                        Text(
                          'Todos',
                          style: AppCss.minimumBold
                              .setColor(AppColors.primaryMain)
                              .setSize(12),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Lista
        Expanded(
          child: (totalDisp == 0 && totalBloq == 0 && totalParciais == 0)
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle,
                          size: 48,
                          color: const Color(0xFF10B981)
                              .withValues(alpha: 0.25)),
                      const SizedBox(height: 10),
                      Text(
                        'Todos os elementos\nforam selecionados',
                        textAlign: TextAlign.center,
                        style: AppCss.smallRegular
                            .setColor(Colors.grey[500]!)
                            .setSize(13),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(10),
                  children: [
                    if (totalDisp > 0) ...[
                      _secaoHeader(
                        icone: Icons.check_circle_outline,
                        cor: const Color(0xFF10B981),
                        titulo: 'Disponíveis',
                        contador: totalDisp,
                      ),
                      const SizedBox(height: 6),
                      ...apenasDisponiveis.map((vm) => Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: _tileDisponivel(vm),
                          )),
                    ],
                    if (totalParciais > 0) ...[
                      if (totalDisp > 0) const SizedBox(height: 10),
                      _secaoHeader(
                        icone: Icons.pie_chart_outline,
                        cor: AppColors.primaryMain,
                        titulo: 'Parcialmente alocado',
                        contador: totalParciais,
                      ),
                      const SizedBox(height: 6),
                      ...parciais.map((vm) => Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: _tileParcial(vm),
                          )),
                    ],
                    if (totalBloq > 0) ...[
                      if (totalDisp > 0 || totalParciais > 0)
                        const SizedBox(height: 10),
                      _secaoHeader(
                        icone: Icons.lock_outline,
                        cor: Colors.orange,
                        titulo: 'Em outro Pedido',
                        contador: totalBloq,
                      ),
                      const SizedBox(height: 6),
                      ...bloqueados.map((vm) => Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: _tileBloqueado(vm),
                          )),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  // ── Header de seção ────────────────────────────────────
  Widget _secaoHeader({
    required IconData icone,
    required Color cor,
    required String titulo,
    required int contador,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Row(
        children: [
          Icon(icone, size: 15, color: cor),
          const SizedBox(width: 6),
          Text(
            titulo.toUpperCase(),
            style: AppCss.minimumBold
                .setColor(cor)
                .setSize(11)
                .setLetterSpacing(0.8),
          ),
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$contador',
              style: AppCss.minimumBold.setColor(cor).setSize(11),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 1,
              color: cor.withValues(alpha: 0.20),
            ),
          ),
        ],
      ),
    );
  }

  // ═══ PAINEL DIREITO — SELECIONADOS ════════════════════
  Widget _painelSelecionados(
    List<ElementoDetalhamentoViewModel> selecionados,
    DetalhamentoModel detalhamento,
    PedidoTecnicoCreateModel form,
    int totalSelecionados,
  ) {
    double pesoTotal = 0;
    int qtdeTotal = 0;
    for (final vm in selecionados) {
      final elem = vm.elemento;
      final qtdeSol = _elementosSelecionados[_chave(elem)] ?? elem.quantidade;
      qtdeTotal += qtdeSol;
      if (elem.quantidade > 0) {
        pesoTotal += (elem.pesoTotal / elem.quantidade) * qtdeSol;
      }
    }

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.primaryMain.withValues(alpha: 0.12),
            border: Border(
                bottom: BorderSide(
                    color:
                        AppColors.primaryMain.withValues(alpha: 0.25))),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryMain.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color:
                          AppColors.primaryMain.withValues(alpha: 0.30)),
                ),
                child: Icon(Icons.assignment_turned_in_outlined,
                    color: AppColors.primaryMain, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedido Técnico',
                      style: AppCss.mediumBold
                          .setSize(15)
                          .setColor(AppColors.primaryMain),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$totalSelecionados elemento(s) · $qtdeTotal peça(s)',
                      style: AppCss.minimumRegular
                          .setColor(
                              AppColors.primaryMain.withValues(alpha: 0.65))
                          .setSize(11),
                    ),
                  ],
                ),
              ),
              if (selecionados.isNotEmpty)
                InkWell(
                  onTap: () =>
                      setState(() => _elementosSelecionados.clear()),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.red.withValues(alpha: 0.20)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.deselect,
                            size: 15, color: Colors.red[400]),
                        const SizedBox(width: 5),
                        Text(
                          'Limpar',
                          style: AppCss.minimumBold
                              .setColor(Colors.red[400]!)
                              .setSize(12),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Lista
        Expanded(
          child: selecionados.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app_outlined,
                          size: 48,
                          color: AppColors.primaryMain
                              .withValues(alpha: 0.15)),
                      const SizedBox(height: 10),
                      Text(
                        'Clique nos elementos\nà esquerda para\nadicioná-los ao pedido',
                        textAlign: TextAlign.center,
                        style: AppCss.smallRegular
                            .setColor(AppColors.primaryMain.withValues(alpha: 0.40))
                            .setSize(13),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(10),
                  itemCount: selecionados.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 5),
                  itemBuilder: (_, i) => _tileSelecionado(selecionados[i]),
                ),
        ),
        // Resumo + Botão
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryMain.withValues(alpha: 0.10),
            border: Border(
                top: BorderSide(
                    color:
                        AppColors.primaryMain.withValues(alpha: 0.20))),
          ),
          child: Column(
            children: [
              if (totalSelecionados > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.primaryMain
                            .withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    children: [
                      _resumoItem(
                        icone: Icons.widgets_outlined,
                        label: 'Elementos',
                        valor: '$qtdeTotal',
                      ),
                      Container(
                        width: 1,
                        height: 28,
                        color:
                            AppColors.primaryMain.withValues(alpha: 0.12),
                      ),
                      _resumoItem(
                        icone: Icons.scale_outlined,
                        label: 'Peso',
                        valor: '${pesoTotal.toStringAsFixed(1)} kg',
                        corValor: const Color(0xFF10B981),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              InkWell(
                onTap: (totalSelecionados > 0 && !_salvando)
                    ? _gerarPedido
                    : null,
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 44,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _salvando
                        ? AppColors.primaryMain.withValues(alpha: 0.70)
                        : totalSelecionados > 0
                            ? AppColors.primaryMain
                            : Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: (totalSelecionados > 0 && !_salvando)
                        ? [
                            BoxShadow(
                              color: AppColors.primaryMain
                                  .withValues(alpha: 0.30),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_salvando)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      else
                        const Icon(Icons.save_outlined,
                            color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _salvando
                            ? 'SALVANDO...'
                            : form.isEdit
                                ? 'SALVAR PEDIDO'
                                : 'GERAR PEDIDO TÉCNICO',
                        style: AppCss.minimumBold
                            .setColor(Colors.white)
                            .setSize(13)
                            .setLetterSpacing(0.8),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _resumoItem({
    required IconData icone,
    required String label,
    required String valor,
    Color? corValor,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icone, size: 15, color: corValor ?? AppColors.primaryMain.withValues(alpha: 0.50)),
          const SizedBox(height: 4),
          Text(
            valor,
            style: AppCss.mediumBold
                .setSize(16)
                .setColor(corValor ?? AppColors.primaryMain),
          ),
          Text(
            label,
            style: AppCss.minimumRegular
                .setColor(Colors.grey[500]!)
                .setSize(11),
          ),
        ],
      ),
    );
  }

  // ── Tile: Elemento Disponível ──────────────────────────
  Widget _tileDisponivel(ElementoDetalhamentoViewModel vm) {
    final elem = vm.elemento;
    return InkWell(
      onTap: () {
        if (elem.quantidade > 1) {
          _mostrarDialogQuantidade(elem);
        } else {
          setState(() {
            _elementosSelecionados[_chave(elem)] = elem.quantidade;
          });
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFCBD5E1)),
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
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color:
                        const Color(0xFF10B981).withValues(alpha: 0.30)),
              ),
              child: const Icon(Icons.add,
                  color: Color(0xFF10B981), size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    elem.nome.isEmpty ? 'Elemento' : elem.nome,
                    style: AppCss.smallBold.setSize(14),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Qtde: ${elem.quantidade}',
                          style: AppCss.minimumBold
                              .setColor(Colors.blueGrey[600]!)
                              .setSize(11),
                        ),
                      ),
                      if (elem.pesoTotal > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${elem.pesoTotal.toStringAsFixed(1)} kg',
                          style: AppCss.minimumBold
                              .setColor(const Color(0xFF10B981))
                              .setSize(12),
                        ),
                      ],
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

  // ── Tile: Parcialmente alocado (restante na esquerda) ──
  Widget _tileParcial(ElementoDetalhamentoViewModel vm) {
    final elem = vm.elemento;
    final qtdeSel = _elementosSelecionados[_chave(elem)] ?? 0;
    final restante = elem.quantidade - qtdeSel;

    return InkWell(
      onTap: () => _mostrarDialogQuantidade(
        elem,
        qtdeInicial: restante,
        qtdeMaxima: restante,
        somarAoExistente: true,
      ),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.primaryMain.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppColors.primaryMain.withValues(alpha: 0.30)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primaryMain.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.primaryMain.withValues(alpha: 0.30)),
              ),
              child: Icon(Icons.pie_chart_outline,
                  color: AppColors.primaryMain, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    elem.nome.isEmpty ? 'Elemento' : elem.nome,
                    style: AppCss.smallBold.setSize(14),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          '$restante restante(s)',
                          style: AppCss.minimumBold
                              .setColor(Colors.amber[800]!)
                              .setSize(10),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$qtdeSel de ${elem.quantidade} no pedido',
                        style: AppCss.minimumRegular
                            .setColor(Colors.grey[500]!)
                            .setSize(11),
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

  // ── Dialog de quantidade ───────────────────────────────
  Future<void> _mostrarDialogQuantidade(
    ElementoModel elem, {
    int? qtdeInicial,
    int? qtdeMaxima,
    bool somarAoExistente = false,
  }) async {
    final max = qtdeMaxima ?? elem.quantidade;
    int qtde = qtdeInicial ?? _elementosSelecionados[_chave(elem)] ?? elem.quantidade;
    if (qtde > max) qtde = max;
    final resultado = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final pesoUnit =
                elem.quantidade > 0 ? elem.pesoTotal / elem.quantidade : 0.0;
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.tune, color: AppColors.primaryMain, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      somarAoExistente
                          ? 'Adicionar ao pedido'
                          : 'Quantidade a produzir',
                      style: AppCss.smallBold.setSize(16),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    elem.nome,
                    style: AppCss.smallBold.setSize(14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    somarAoExistente
                        ? '$max peça(s) restante(s) de ${elem.quantidade}'
                        : 'Total no detalhamento: ${elem.quantidade}',
                    style: AppCss.minimumRegular
                        .setColor(Colors.grey[500]!)
                        .setSize(12),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _dialogBtn(
                        icone: Icons.remove,
                        ativo: qtde > 1,
                        onTap: () => setDialogState(() => qtde--),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 80,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primaryMain
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.primaryMain
                                  .withValues(alpha: 0.25)),
                        ),
                        child: Center(
                          child: Text(
                            '$qtde',
                            style: AppCss.smallBold
                                .setSize(22)
                                .setColor(AppColors.primaryMain),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _dialogBtn(
                        icone: Icons.add,
                        ativo: qtde < max,
                        onTap: () => setDialogState(() => qtde++),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'de $max',
                    style: AppCss.minimumRegular
                        .setColor(Colors.grey[400]!)
                        .setSize(12),
                  ),
                  if (pesoUnit > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${(pesoUnit * qtde).toStringAsFixed(2)} kg',
                      style: AppCss.smallBold
                          .setColor(const Color(0xFF10B981))
                          .setSize(14),
                    ),
                  ],
                  if (!somarAoExistente && qtde < max) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 14, color: Colors.amber[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${max - qtde} peça(s) ficará(ão) disponível(is) para outro pedido',
                              style: AppCss.minimumRegular
                                  .setColor(Colors.amber[800]!)
                                  .setSize(11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, qtde),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryMain,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(somarAoExistente
                      ? 'Adicionar $qtde'
                      : 'Produzir $qtde'),
                ),
              ],
            );
          },
        );
      },
    );
    if (resultado != null) {
      setState(() {
        if (somarAoExistente) {
          final existente = _elementosSelecionados[_chave(elem)] ?? 0;
          _elementosSelecionados[_chave(elem)] = existente + resultado;
        } else {
          _elementosSelecionados[_chave(elem)] = resultado;
        }
      });
    }
  }

  Widget _dialogBtn({
    required IconData icone,
    required bool ativo,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: ativo ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: ativo
              ? AppColors.primaryMain.withValues(alpha: 0.10)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ativo
                ? AppColors.primaryMain.withValues(alpha: 0.25)
                : Colors.grey[200]!,
          ),
        ),
        child: Icon(icone,
            size: 18,
            color: ativo ? AppColors.primaryMain : Colors.grey[300]),
      ),
    );
  }

  // ── Tile: Elemento Bloqueado ───────────────────────────
  Widget _tileBloqueado(ElementoDetalhamentoViewModel vm) {
    final elem = vm.elemento;
    return Tooltip(
      message: 'Em uso no Pedido Técnico ${vm.codigoPedidoOcupante}',
      preferBelow: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: Colors.orange.withValues(alpha: 0.30)),
        ),
        child: Opacity(
          opacity: 0.65,
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lock_outline,
                    color: Colors.orange, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      elem.nome.isEmpty ? 'Elemento' : elem.nome,
                      style: AppCss.smallBold
                          .setSize(13)
                          .setColor(Colors.grey[700]!),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'PT ${vm.codigoPedidoOcupante}',
                            style: AppCss.minimumBold
                                .setColor(Colors.orange)
                                .setSize(10),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Qtde: ${elem.quantidade}',
                          style: AppCss.minimumRegular
                              .setColor(Colors.grey[500]!)
                              .setSize(11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tile: Elemento Selecionado ─────────────────────────
  Widget _tileSelecionado(ElementoDetalhamentoViewModel vm) {
    final elem = vm.elemento;
    final qtdeSolicitada = _elementosSelecionados[_chave(elem)] ?? elem.quantidade;
    final pesoUnitario =
        elem.quantidade > 0 ? elem.pesoTotal / elem.quantidade : 0.0;
    final pesoParcial = pesoUnitario * qtdeSolicitada;
    final isParcial = qtdeSolicitada < elem.quantidade;

    return InkWell(
      onTap: () {
        if (elem.quantidade > 1) {
          _mostrarDialogQuantidade(elem);
        } else {
          setState(() => _elementosSelecionados.remove(_chave(elem)));
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.primaryMain.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryMain.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => setState(() {
              _elementosSelecionados.remove(_chave(elem));
            }),
            borderRadius: BorderRadius.circular(8),
            child: Tooltip(
              message: 'Remover do pedido',
              preferBelow: false,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryMain,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryMain.withValues(alpha: 0.30),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Icon(Icons.check,
                    color: Colors.white, size: 17),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  elem.nome.isEmpty ? 'Elemento' : elem.nome,
                  style: AppCss.smallBold.setSize(14),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isParcial
                            ? Colors.amber.withValues(alpha: 0.18)
                            : AppColors.primaryMain
                                .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isParcial
                              ? Colors.amber.withValues(alpha: 0.35)
                              : AppColors.primaryMain
                                  .withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        'Qtde: $qtdeSolicitada',
                        style: AppCss.minimumBold
                            .setColor(isParcial
                                ? Colors.amber[800]!
                                : AppColors.primaryMain)
                            .setSize(11),
                      ),
                    ),
                    if (pesoParcial > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${pesoParcial.toStringAsFixed(1)} kg',
                        style: AppCss.minimumBold
                            .setColor(const Color(0xFF10B981))
                            .setSize(12),
                      ),
                    ],
                    // Botão editar qtde (se > 1)
                    if (elem.quantidade > 1) ...[
                      const Spacer(),
                      InkWell(
                        onTap: () => _mostrarDialogQuantidade(elem),
                        borderRadius: BorderRadius.circular(6),
                        child: Tooltip(
                          message: 'Alterar quantidade',
                          preferBelow: false,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.primaryMain
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                  color: AppColors.primaryMain
                                      .withValues(alpha: 0.20)),
                            ),
                            child: Icon(Icons.edit_outlined,
                                size: 14, color: AppColors.primaryMain),
                          ),
                        ),
                      ),
                    ],
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

  Future<void> _gerarPedido() async {
    final detalhamento = _detalhamentoSel;
    if (detalhamento == null || _salvando) return;

    setState(() => _salvando = true);

    try {
      final form = pedidoTecnicoCtrl.form;
      form.clienteId = _clienteSel?.id ?? '';
      form.clienteNome = _clienteSel?.nome ?? '';
      form.obraId = _obraSel?.id ?? '';
      form.obraNome = _obraSel?.descricao ?? '';
      form.obraPrefixo = _obraSel?.prefixo ?? '';
      form.detalhamentoId = detalhamento.id;
      form.detalhamentoCodigo = detalhamento.codigo;
      form.observacao = _obsCtrl.text.trim();
      form.elementosSelecionados = detalhamento.elementos
          .expand((e) {
            return e.todosNomes.map((nome) => ElementoModel(
                  id: e.id,
                  nome: nome,
                  quantidade: e.quantidade,
                  pesoTotal: e.pesoTotal,
                  posicoes: e.posicoes,
                  elementosEquivalentes: const [],
                ));
          })
          .where((e) => _elementosSelecionados.containsKey(_chave(e)))
          .map((e) => ElementoSelecionadoModel.fromElementoModel(
                e,
                quantidadeSolicitada: _elementosSelecionados[_chave(e)],
              ))
          .toList();

      pedidoTecnicoCtrl.formStream.update();

      final ok = await pedidoTecnicoCtrl.salvar();
      if (ok && mounted) pop(context);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }
}
