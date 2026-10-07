import 'package:acoplan/app/app_controller.dart';
import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/cliente_model.dart';
import 'package:acoplan/app/core/client/models/detalhamento_model.dart';
import 'package:acoplan/app/core/client/models/pedido_tecnico_model.dart';
import 'package:acoplan/app/core/components/app_scaffold.dart';
import 'package:acoplan/app/core/components/cadastro/cadastro_form.dart';
import 'package:acoplan/app/core/components/cadastro/cadastro_lista.dart';
import 'package:acoplan/app/core/components/cliente_busca_field.dart';
import 'package:acoplan/app/core/dialogs/confirm_dialog.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/dashboard/demanda_controller.dart';
import 'package:acoplan/app/modules/dashboard/ui/demanda_etapa_cor.dart';
import 'package:acoplan/app/modules/dashboard/models/demanda_model.dart';
import 'package:acoplan/app/modules/detalhamento/detalhamento_controller.dart';
import 'package:acoplan/app/modules/detalhamento/detalhamento_view_model.dart';
import 'package:acoplan/app/modules/detalhamento/pdf_detalhamento.dart';
import 'package:acoplan/app/modules/detalhamento/ui/detalhamento_create_page.dart';
import 'package:acoplan/app/modules/forma/forma_controller.dart';
import 'package:acoplan/app/modules/pedido_tecnico/ui/pedido_tecnico_create_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:printing/printing.dart';

part 'widgets/dashboard_demanda_card.dart';
part 'widgets/dashboard_demanda_form_dialog.dart';
part 'widgets/dashboard_demanda_detalhes_dialog.dart';
part 'widgets/dashboard_modal_arquivados.dart';
part 'widgets/dashboard_modal_ordenacao_fila.dart';
part 'widgets/dashboard_detalhamento_card.dart';
part 'widgets/dashboard_pedido_card.dart';
part 'widgets/dashboard_ciclo.dart';

/// Demandas (aba 0), Detalhamentos (aba 1) e Pedidos técnicos (aba 2).
/// Cada aba é aberta como uma área própria pelo menu.
class DashboardPage extends StatefulWidget {
  final int aba;
  const DashboardPage({this.aba = 0, super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = '';
  late final int _activeTab = widget.aba; // 0 = Demandas (Kanban), 1 = Detalhamentos, 2 = Pedidos
  String _prioridadeFiltro = 'todas'; // 'todas' | 'alta' | 'urgente'

  // Estados da Aba 2 (Projetos / Detalhamentos)
  final Set<String> _expandidosDetalhamentos = {};
  String? _selecionadoDetalhamentoId;
  String _ordenarProjetosPor = 'codigo'; // 'codigo' | 'cliente' | 'obra' | 'peso' | 'elementos'
  bool _ordenarProjetosAsc = false;

  // Detalhamentos: 'ativos' | 'arquivados'
  String _situacaoFiltroProjetos = 'ativos';

  // Estados da Aba 3 (Pedidos Técnicos)
  String _statusFiltroPedido = 'todos'; // 'todos' | 'aberto' | 'cancelado'

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _abrirNovoProjeto() {
    push(context, const DetalhamentoCreatePage(detalhamento: null));
  }

  void _abrirNovoPedido() {
    push(context, const PedidoTecnicoCreatePage(pedido: null));
  }


  void _abrirNovoPedidoParaDetalhamento(DetalhamentoModel detalhamento) {
    push(
      context,
      PedidoTecnicoCreatePage(
        pedido: null,
        detalhamentoInicial: detalhamento,
        clienteIdInicial: detalhamento.clienteId,
        obraIdInicial: detalhamento.obraId,
        detalhamentoIdInicial: detalhamento.id,
      ),
    );
  }

  void _abrirProjeto(DetalhamentoModel detalhamento) async {
    final estaVinculada =
        await BackendClient.detalhamentos.estaVinculadoAPedido(detalhamento.id);
    if (estaVinculada) {
      if (!mounted) return;
      NotificationService.showNeutral(
        'Modo de Visualização',
        'Este detalhamento está em um Pedido Técnico e não pode ser alterado.',
        position: NotificationPosition.bottom,
      );
      await push(context,
          DetalhamentoCreatePage(detalhamento: detalhamento, isReadOnly: true));
      return;
    }
    if (!mounted) return;
    await push(context, DetalhamentoCreatePage(detalhamento: detalhamento));
  }

  void _abrirPedido(PedidoTecnicoModel pedido) {
    push(context, PedidoTecnicoCreatePage(pedido: pedido));
  }

  void _duplicarProjeto() {
    final original = BackendClient.detalhamentos.data
        .where((d) => d.id == _selecionadoDetalhamentoId)
        .firstOrNull;
    if (original == null) return;

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

    final todosDet = BackendClient.detalhamentos.data;
    final proximoCodigo = todosDet.isEmpty
        ? 1
        : todosDet.map((p) => p.codigo).reduce((a, b) => a > b ? a : b) + 1;

    detalhamentoCtrl.init(null);
    final form = detalhamentoCtrl.form;
    form.codigo = proximoCodigo;
    form.clienteSelecionado = clienteOriginal;
    form.obraSelecionada = obraOriginal;

    form.elementos = original.elementos
        .map((e) => ElementoCreateModel.fromModel(e))
        .toList();

    detalhamentoCtrl.formStream.update();

    setState(() => _selecionadoDetalhamentoId = null);
    push(context, const DetalhamentoCreatePage(skipInit: true));
  }

  void _gerarPdfProjeto(DetalhamentoModel detalhamento) async {
    final pdfBytes = await PdfDetalhamento.gerarRelatorio(
      detalhamento,
      formaCtrl.formas,
      BackendClient.bitolas.data,
    );
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'Detalhamento ${detalhamento.codigo} - ${detalhamento.clienteNome}',
    );
  }

  void _confirmarExclusaoProjeto(DetalhamentoModel detalhamento) async {
    final estaVinculada =
        await BackendClient.detalhamentos.estaVinculadoAPedido(detalhamento.id);
    if (estaVinculada) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(Icons.info_outline, size: 40, color: Colors.orange[700]),
          title: Text('Exclusão Bloqueada',
              textAlign: TextAlign.center, style: AppCss.mediumBold),
          content: Text(
            'Este detalhamento não pode ser excluído pois possui elementos vinculados a um Pedido Técnico.\n\nRemova os elementos do pedido antes de excluir.',
            style: AppCss.smallRegular,
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryMain),
              onPressed: () => pop(context),
              child:
                  Text('Entendi', style: AppCss.smallBold.setColor(Colors.white)),
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
        content: Text(
            'Deseja realmente excluir o detalhamento ${detalhamento.codigo}?'),
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

  void _dialogNovaDemanda() {
    showDialog(
      context: context,
      builder: (ctx) => _DemandaFormDialog(
        onSalvar: (demanda) async {
          final criada = await demandaCtrl.adicionarDemanda(
            clienteNome: demanda.clienteNome,
            clienteId: demanda.clienteId,
            clienteTelefone: demanda.clienteTelefone,
            clienteEndereco: demanda.clienteEndereco,
            obraNome: demanda.obraNome,
            obraId: demanda.obraId,
            etapaProjeto: demanda.etapaProjeto,
            caminhoPastaRede: demanda.caminhoPastaRede,
            solicitanteComercial: demanda.solicitanteComercial,
            prioridade: demanda.prioridade,
          );
          if (criada == null) return;
          NotificationService.showPositive(
            'Demanda Cadastrada',
            '${demanda.obraNome} (${demanda.etapaProjeto}) adicionada em Aguardando Detalhamento.',
            position: NotificationPosition.bottom,
          );
        },
      ),
    );
  }

  void _dialogEditarDemanda(DemandaModel demanda) {
    showDialog(
      context: context,
      builder: (ctx) => _DemandaFormDialog(
        demanda: demanda,
        onSalvar: (demandaAtualizada) async {
          if (!await demandaCtrl.atualizarDemanda(demandaAtualizada)) return;
          NotificationService.showPositive(
            'Demanda Atualizada',
            'Demanda D-${demandaAtualizada.codigo} (${demandaAtualizada.obraNome}) salva com sucesso.',
            position: NotificationPosition.bottom,
          );
        },
      ),
    );
  }

  Future<void> _tentarExcluirDemanda(
    BuildContext context,
    DemandaModel demanda, {
    VoidCallback? onExcluido,
  }) async {
    // Confirmação prévia de ação destrutiva (Diretriz 4.2)
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Demanda'),
        content: Text(
          'Deseja realmente excluir a demanda D-${demanda.codigo} (${demanda.obraNome})?\n\n'
          'Esta ação é irreversível.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmou == true) {
      if (!await demandaCtrl.excluirDemanda(demanda.id)) return;
      onExcluido?.call();
      NotificationService.showPositive(
        'Demanda Excluída',
        'A demanda D-${demanda.codigo} foi excluída com sucesso.',
        position: NotificationPosition.bottom,
      );
    }
  }

  void _abrirDialogDetalhesDemanda(DemandaModel demanda) {
    showDialog(
      context: context,
      builder: (ctx) => _DemandaDetalhesDialog(
        demanda: demanda,
        onEditar: () => _dialogEditarDemanda(demanda),
        onExcluir: () => _tentarExcluirDemanda(
          context,
          demanda,
          onExcluido: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  void _abrirModalArquivados(List<DemandaModel> arquivados) {
    showDialog(
      context: context,
      builder: (ctx) => _ModalArquivadosDialog(
        arquivados: List.from(arquivados),
        onDesarquivar: (id) async {
          await demandaCtrl.desarquivarDemanda(id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<List<DemandaModel>>(
        stream: demandaCtrl.demandasStream.listen,
        builder: (context, snapDemandas) {
          return StreamBuilder<List<DetalhamentoModel>>(
            stream: BackendClient.detalhamentos.dataStream.listen,
            builder: (context, snapDetalhamentos) {
              return StreamBuilder<List<PedidoTecnicoModel>>(
                stream: BackendClient.pedidosTecnicos.dataStream.listen,
                builder: (context, snapPedidos) {
                  final demandas = snapDemandas.data ?? demandaCtrl.demandas;
                  final detalhamentos = snapDetalhamentos.data ??
                      BackendClient.detalhamentos.data;
                  final pedidos = snapPedidos.data ??
                      BackendClient.pedidosTecnicos.data;

                  final q = _filter.trim().toLowerCase();

                  // Separar demandas ativas e arquivadas
                  final demandasAtivas =
                      demandas.where((d) => !d.isArquivado).toList();
                  final demandasArquivadas =
                      demandas.where((d) => d.isArquivado).toList();

                  // Filtrar demandas ativas
                  final filteredDemandas = demandasAtivas.where((d) {
                    if (_prioridadeFiltro != 'todas' &&
                        d.prioridade != _prioridadeFiltro) {
                      return false;
                    }
                    if (q.isEmpty) return true;
                    return d.obraNome.toLowerCase().contains(q) ||
                        d.clienteNome.toLowerCase().contains(q) ||
                        d.etapaProjeto.toLowerCase().contains(q) ||
                        d.solicitanteComercial.toLowerCase().contains(q);
                  }).toList();

                  // Deduplica e filtra detalhamentos
                  final seenIds = <String>{};
                  final uniqueDetalhamentos =
                      detalhamentos.where((d) => seenIds.add(d.id)).toList();

                  final contagemSituacao = <String, int>{
                    'ativos': uniqueDetalhamentos.where((d) => !d.isArquivado).length,
                    'arquivados': uniqueDetalhamentos.where((d) => d.isArquivado).length,
                  };
                  var filteredDetalhamentos = uniqueDetalhamentos.where((p) {
                    if (p.isArquivado != (_situacaoFiltroProjetos == 'arquivados')) return false;
                    if (q.isEmpty) return true;
                    return p.codigo.toString().contains(q) ||
                        p.clienteNome.toLowerCase().contains(q) ||
                        p.obraNome.toLowerCase().contains(q) ||
                        p.desenho.toLowerCase().contains(q) ||
                        p.pavimento.toLowerCase().contains(q);
                  }).toList();

                  // Ordenar detalhamentos
                  filteredDetalhamentos.sort((a, b) {
                    int cmp;
                    switch (_ordenarProjetosPor) {
                      case 'cliente':
                        cmp = a.clienteNome
                            .toLowerCase()
                            .compareTo(b.clienteNome.toLowerCase());
                        break;
                      case 'obra':
                        cmp = a.obraNome
                            .toLowerCase()
                            .compareTo(b.obraNome.toLowerCase());
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
                    return _ordenarProjetosAsc ? cmp : -cmp;
                  });

                  // Filtrar pedidos
                  final filteredPedidos = pedidos.where((p) {
                    final matchStatus = _statusFiltroPedido == 'todos' ||
                        (_statusFiltroPedido == 'aberto'
                            ? p.isAberto
                            : !p.isAberto);
                    if (!matchStatus) return false;
                    if (q.isEmpty) return true;
                    return p.codigo.toString().contains(q) ||
                        p.identificador.toLowerCase().contains(q) ||
                        p.clienteNome.toLowerCase().contains(q) ||
                        p.obraNome.toLowerCase().contains(q) ||
                        p.detalhamentoCodigo.toString().contains(q) ||
                        (BackendClient.detalhamentos.data
                                .where((d) => d.id == p.detalhamentoId)
                                .firstOrNull
                                ?.descricao
                                .toLowerCase()
                                .contains(q) ??
                            false);
                  }).toList();

                  return Column(
                    children: [
                      // Cada aba agora é uma área própria do menu (Demandas,
                      // Detalhamentos, Pedidos técnicos): sem barra de abas.
                      Container(color: Colors.white, height: 10),

                      // ── Linha Única de Ações, Filtros e Busca (Compacta: 38px) ──
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: LayoutBuilder(builder: (context, cons) {
                          final acoes = <Widget>[
                            if (_activeTab == 0) ...[
                              ElevatedButton.icon(
                                onPressed: _dialogNovaDemanda,
                                icon: const Icon(Icons.add_rounded,
                                    size: 16, color: Colors.white),
                                label: const Text('Nova Demanda'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                  textStyle: AppCss.smallBold.setSize(12),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                height: 18,
                                width: 1,
                                color: const Color(0xFFE2E8F0),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Prioridade:',
                                style: AppCss.minimumBold
                                    .setSize(11)
                                    .setColor(const Color(0xFF64748B)),
                              ),
                              const SizedBox(width: 6),
                              _filtroPrioridadeChip('Todas', 'todas'),
                              const SizedBox(width: 4),
                              _filtroPrioridadeChip('Alta', 'alta'),
                              const SizedBox(width: 4),
                              _filtroPrioridadeChip('Urgente', 'urgente'),
                              const SizedBox(width: 12),
                              Container(
                                height: 18,
                                width: 1,
                                color: const Color(0xFFE2E8F0),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _abrirModalArquivados(demandasArquivadas),
                                icon: const Icon(Icons.inventory_2_outlined,
                                    size: 14, color: Color(0xFF475569)),
                                label: Text(
                                  demandasArquivadas.isEmpty
                                      ? 'Arquivados'
                                      : 'Arquivados (${demandasArquivadas.length})',
                                  style: AppCss.smallBold
                                      .setSize(12)
                                      .setColor(const Color(0xFF475569)),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  side: const BorderSide(
                                      color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ] else if (_activeTab == 1) ...[
                              ElevatedButton.icon(
                                onPressed: _abrirNovoProjeto,
                                icon: const Icon(Icons.add_rounded,
                                    size: 16, color: Colors.white),
                                label: const Text('Novo detalhamento'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                  textStyle: AppCss.smallBold.setSize(12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Tooltip(
                                message: 'Duplicar detalhamento selecionado',
                                child: OutlinedButton.icon(
                                  onPressed: _selecionadoDetalhamentoId != null
                                      ? _duplicarProjeto
                                      : null,
                                  icon: Icon(
                                    Icons.copy_outlined,
                                    size: 14,
                                    color: _selecionadoDetalhamentoId != null
                                        ? AppColors.primaryMain
                                        : Colors.grey[400],
                                  ),
                                  label: Text(
                                    'Duplicar',
                                    style: AppCss.smallBold
                                        .setSize(12)
                                        .setColor(
                                          _selecionadoDetalhamentoId != null
                                              ? AppColors.primaryMain
                                              : Colors.grey[400]!,
                                        ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    side: BorderSide(
                                      color: _selecionadoDetalhamentoId != null
                                          ? AppColors.primaryMain
                                              .withValues(alpha: 0.4)
                                          : Colors.grey[300]!,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                height: 18,
                                width: 1,
                                color: const Color(0xFFE2E8F0),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Ordenar:',
                                style: AppCss.minimumBold
                                    .setSize(11)
                                    .setColor(const Color(0xFF64748B)),
                              ),
                              const SizedBox(width: 6),
                              _ordenarProjetoChip(
                                  'Código', 'codigo', Icons.tag),
                              const SizedBox(width: 4),
                              _ordenarProjetoChip('Cliente', 'cliente',
                                  Icons.person_outline),
                              const SizedBox(width: 4),
                              _ordenarProjetoChip(
                                  'Obra', 'obra', Icons.business_outlined),
                              const SizedBox(width: 4),
                              _ordenarProjetoChip(
                                  'Peso', 'peso', Icons.scale_outlined),
                              const SizedBox(width: 4),
                              _ordenarProjetoChip('Elementos', 'elementos',
                                  Icons.layers_outlined),
                              const SizedBox(width: 12),
                              Container(height: 18, width: 1, color: const Color(0xFFE2E8F0)),
                              const SizedBox(width: 12),
                              for (final (rotulo, valor) in [
                                ('Ativos', 'ativos'),
                                ('Arquivados', 'arquivados'),
                              ]) ...[
                                _filtroSituacaoChip(rotulo, valor, contagemSituacao[valor] ?? 0),
                                const SizedBox(width: 4),
                              ],
                            ] else if (_activeTab == 2) ...[
                              ElevatedButton.icon(
                                onPressed: _abrirNovoPedido,
                                icon: const Icon(Icons.add_rounded,
                                    size: 16, color: Colors.white),
                                label: const Text('Novo Pedido'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                  textStyle: AppCss.smallBold.setSize(12),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                height: 18,
                                width: 1,
                                color: const Color(0xFFE2E8F0),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Status:',
                                style: AppCss.minimumBold
                                    .setSize(11)
                                    .setColor(const Color(0xFF64748B)),
                              ),
                              const SizedBox(width: 6),
                              _filtroStatusPedidoChip('Todos', 'todos'),
                              const SizedBox(width: 4),
                              _filtroStatusPedidoChip('Abertos', 'aberto'),
                              const SizedBox(width: 4),
                              _filtroStatusPedidoChip(
                                  'Cancelados', 'cancelado'),
                            ],
                          ];
                          Widget busca(double? largura) => SizedBox(
                              width: largura,
                              height: 34,
                              child: TextField(
                                controller: _searchCtrl,
                                onChanged: (val) =>
                                    setState(() => _filter = val),
                                style: AppCss.minimumRegular.setSize(12),
                                decoration: InputDecoration(
                                  hintText: _activeTab == 0
                                      ? 'Buscar por obra, cliente ou etapa...'
                                      : (_activeTab == 1
                                          ? 'Buscar detalhamentos por código, obra...'
                                          : 'Buscar por localizador, obra...'),
                                  hintStyle: AppCss.minimumRegular
                                      .setSize(12)
                                      .setColor(const Color(0xFF94A3B8)),
                                  prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      size: 16,
                                      color: Color(0xFF94A3B8)),
                                  suffixIcon: _filter.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(
                                              Icons.close_rounded,
                                              size: 14,
                                              color: Color(0xFF94A3B8)),
                                          padding: EdgeInsets.zero,
                                          onPressed: () {
                                            _searchCtrl.clear();
                                            setState(() => _filter = '');
                                          },
                                        )
                                      : null,
                                  isDense: true,
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 6, horizontal: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF2563EB),
                                        width: 1.5),
                                  ),
                                ),
                              ));
                          // Tela larga: tudo numa linha. Estreita: ações roláveis e
                          // busca embaixo (antes estourava a largura).
                          if (cons.maxWidth >= 1000) {
                            return Row(children: [...acoes, const Spacer(), busca(280)]);
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(children: acoes),
                              ),
                              const SizedBox(height: 8),
                              busca(null),
                            ],
                          );
                        }),
                      ),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),

                      // ── Conteúdo da Aba Ativa ────────────────────────
                      Expanded(
                        child: IndexedStack(
                          index: _activeTab,
                          children: [
                            // ── ABA 1: KANBAN DE DEMANDAS (5 COLUNAS) ─
                            _buildKanbanTab(filteredDemandas),

                            // ── ABA 2: PROJETOS PLANILHADOS ───────────
                            _buildProjetosTab(
                                filteredDetalhamentos, pedidos),

                            // ── ABA 3: PEDIDOS TÉCNICOS ───────────────
                            _buildPedidosTab(filteredPedidos),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ABA 1: KANBAN DE DEMANDAS (5 COLUNAS)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildKanbanTab(List<DemandaModel> demandas) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // As 5 colunas cabem na tela dividindo 100% da largura útil sem scroll
        final useExpanded = constraints.maxWidth >= 600;

        final colunas = [
          // Coluna 1: Aguardando detalhamento (ordenação manual)
          _buildKanbanColumn(
            titulo: '1. Aguardando detalhamento',
            subtitulo: 'Fila de entrada (manual)',
            corAcento: const Color(0xFF3B82F6),
            badgeIcon: Icons.format_list_numbered_rounded,
            demandas: demandas
                .where((d) => d.etapa == DemandaEtapa.aguardandoFila)
                .toList()
              ..sort((a, b) => a.ordem.compareTo(b.ordem)),
            isFilaManual: true,
            onNovaDemanda: _dialogNovaDemanda,
            onAbrirOrdenacao: () {
              final filaAtual = demandas
                  .where((d) => d.etapa == DemandaEtapa.aguardandoFila)
                  .toList()
                ..sort((a, b) => a.ordem.compareTo(b.ordem));
              _abrirDialogOrdenacaoFila(filaAtual);
            },
          ),

          // Coluna 2: Em produção
          _buildKanbanColumn(
            titulo: '2. Em produção',
            subtitulo: 'Detalhamento ativo',
            corAcento: const Color(0xFF0D9488),
            badgeIcon: Icons.pending_actions_rounded,
            demandas: demandas
                .where((d) => d.etapa == DemandaEtapa.emProducao)
                .toList(),
          ),

          // Coluna 3: Aguardando correção
          _buildKanbanColumn(
            titulo: '3. Aguardando correção',
            subtitulo: 'Revisão técnica',
            corAcento: const Color(0xFFD97706),
            badgeIcon: Icons.pause_circle_outline_rounded,
            demandas: demandas
                .where((d) => d.etapa == DemandaEtapa.aguardandoCorrecao)
                .toList(),
          ),

          // Coluna 4: Corrigindo
          _buildKanbanColumn(
            titulo: '4. Corrigindo',
            subtitulo: 'Ajuste de armação',
            corAcento: const Color(0xFFEA580C),
            badgeIcon: Icons.build_circle_outlined,
            demandas: demandas
                .where((d) => d.etapa == DemandaEtapa.corrigindo)
                .toList(),
          ),

          // Coluna 5: Finalizado / Liberado
          _buildKanbanColumn(
            titulo: '5. Finalizado / Liberado',
            subtitulo: 'Pronto p/ Pedido',
            corAcento: const Color(0xFF059669),
            badgeIcon: Icons.check_circle_outline_rounded,
            demandas: demandas
                .where((d) => d.etapa == DemandaEtapa.finalizadoLiberado)
                .toList(),
          ),
        ];

        if (useExpanded) {
          // As 5 colunas dividem 100% da tela sem scroll horizontal
          return Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < colunas.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: colunas[i]),
                ],
              ],
            ),
          );
        }

        // Fallback apenas para telas ultra-estreitas (< 600px)
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < colunas.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                SizedBox(width: 220, child: colunas[i]),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _filtroPrioridadeChip(String label, String valor) {
    final on = _prioridadeFiltro == valor;
    return InkWell(
      onTap: () => setState(() => _prioridadeFiltro = valor),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: on
              ? const Color(0xFF0F172A)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: AppCss.minimumBold.setSize(11).setColor(
                on ? Colors.white : const Color(0xFF64748B),
              ),
        ),
      ),
    );
  }

  Widget _ordenarProjetoChip(String label, String campo, IconData icone) {
    final selecionado = _ordenarProjetosPor == campo;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_ordenarProjetosPor == campo) {
            _ordenarProjetosAsc = !_ordenarProjetosAsc;
          } else {
            _ordenarProjetosPor = campo;
            _ordenarProjetosAsc = campo == 'cliente' || campo == 'obra';
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selecionado
              ? const Color(0xFF0D9488).withValues(alpha: 0.12)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selecionado
                ? const Color(0xFF0D9488).withValues(alpha: 0.40)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone,
                size: 12,
                color: selecionado
                    ? const Color(0xFF0D9488)
                    : const Color(0xFF64748B)),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppCss.minimumBold.setSize(11).setColor(
                    selecionado
                        ? const Color(0xFF0D9488)
                        : const Color(0xFF64748B),
                  ),
            ),
            if (selecionado) ...[
              const SizedBox(width: 3),
              Icon(
                _ordenarProjetosAsc ? Icons.arrow_upward : Icons.arrow_downward,
                size: 11,
                color: const Color(0xFF0D9488),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filtroSituacaoChip(String label, String valor, int total) {
    final on = _situacaoFiltroProjetos == valor;
    final cor = AppColors.statusProduzindo;
    return InkWell(
      onTap: () => setState(() => _situacaoFiltroProjetos = valor),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: on ? cor.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: on ? cor.withValues(alpha: 0.40) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          '$label ($total)',
          style: AppCss.minimumBold.setSize(11).setColor(on ? cor : const Color(0xFF64748B)),
        ),
      ),
    );
  }

  Widget _filtroStatusPedidoChip(String label, String valor) {
    final on = _statusFiltroPedido == valor;
    return InkWell(
      onTap: () => setState(() => _statusFiltroPedido = valor),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: on
              ? const Color(0xFF6366F1).withValues(alpha: 0.15)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: on
                ? const Color(0xFF6366F1).withValues(alpha: 0.40)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: AppCss.minimumBold.setSize(11).setColor(
                on ? const Color(0xFF6366F1) : const Color(0xFF64748B),
              ),
        ),
      ),
    );
  }

  Widget _buildKanbanColumn({
    required String titulo,
    required String subtitulo,
    required Color corAcento,
    required IconData badgeIcon,
    required List<DemandaModel> demandas,
    bool isFilaManual = false,
    VoidCallback? onNovaDemanda,
    VoidCallback? onAbrirOrdenacao,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho da Coluna (Compacto para caber na tela sem scroll)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                bottom: BorderSide(
                    color: corAcento.withValues(alpha: 0.35), width: 2),
              ),
            ),
            child: Row(
              children: [
                Icon(badgeIcon, size: 15, color: corAcento),
                const SizedBox(width: 5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              titulo,
                              style: AppCss.smallBold
                                  .setSize(12)
                                  .setColor(const Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: corAcento.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              demandas.length.toString(),
                              style: AppCss.minimumBold
                                  .setSize(9)
                                  .setColor(corAcento),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitulo,
                        style: AppCss.minimumRegular
                            .setSize(9)
                            .setColor(const Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (onNovaDemanda != null) ...[
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Adicionar nova demanda na fila',
                    child: InkWell(
                      onTap: onNovaDemanda,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
                if (onAbrirOrdenacao != null) ...[
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Reordenar fila (arrastar)',
                    child: InkWell(
                      onTap: onAbrirOrdenacao,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Icon(
                          Icons.swap_vert_rounded,
                          size: 16,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Lista de Cartões da Coluna
          Expanded(
            child: demandas.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Nenhuma demanda aqui',
                        style: AppCss.minimumRegular
                            .setSize(11)
                            .setColor(const Color(0xFF94A3B8)),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 6),
                    itemCount: demandas.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = demandas[index];
                      return _DemandaCard(
                        demanda: item,
                        isFilaManual: isFilaManual,
                        onTap: () => _abrirDialogDetalhesDemanda(item),
                        onEditar: () => _dialogEditarDemanda(item),
                        // Demanda com planilha ou desfecho não é excluída (só arquivada)
                        onExcluir: item.desfecho != null ||
                                demandaCtrl.obterDetalhamentosDaDemanda(item).isNotEmpty
                            ? null
                            : () => _tentarExcluirDemanda(context, item),
                        onMover: (novaEtapa) =>
                            demandaCtrl.moverEtapa(context, item.id, novaEtapa),
                        onArquivar: () =>
                            demandaCtrl.arquivarDemanda(item.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ABA 2: PROJETOS PLANILHADOS (DETALHAMENTOS)
  // ─────────────────────────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────────────────
  // ABA 2: PROJETOS PLANILHADOS (DETALHAMENTOS)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildProjetosTab(
      List<DetalhamentoModel> list, List<PedidoTecnicoModel> todosPedidos) {
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: _buildEmptyTab(
          icon: Icons.architecture_outlined,
          title: 'Nenhum detalhamento encontrado',
          subtitle: 'Inicie um novo detalhamento de peças de aço.',
          actionLabel: '+ Novo detalhamento',
          onAction: _abrirNovoProjeto,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final detalhamento = list[index];
        final pedidosVinculados = todosPedidos
            .where((p) => p.detalhamentoId == detalhamento.id)
            .toList();
        final expandido = _expandidosDetalhamentos.contains(detalhamento.id);
        final selecionado = _selecionadoDetalhamentoId == detalhamento.id;

        return _DashboardDetalhamentoCard(
          detalhamento: detalhamento,
          pedidosVinculados: pedidosVinculados,
          expandido: expandido,
          selecionado: selecionado,
          onSelecionar: () => setState(() {
            _selecionadoDetalhamentoId =
                _selecionadoDetalhamentoId == detalhamento.id
                    ? null
                    : detalhamento.id;
          }),
          onToggleExpand: () => setState(() {
            if (_expandidosDetalhamentos.contains(detalhamento.id)) {
              _expandidosDetalhamentos.remove(detalhamento.id);
            } else {
              _expandidosDetalhamentos.add(detalhamento.id);
            }
          }),
          onEditar: () => _abrirProjeto(detalhamento),
          onPdf: () => _gerarPdfProjeto(detalhamento),
          onExcluir: () => _confirmarExclusaoProjeto(detalhamento),
          onAbrirPedido: _abrirPedido,
          // Única trava: pedido técnico só com a demanda em Finalizado / Liberado
          onGerarPedido: demandaCtrl.detalhamentoLiberadoParaPedido(detalhamento)
              ? () => _abrirNovoPedidoParaDetalhamento(detalhamento)
              : null,
          onArquivar: () => detalhamento.isArquivado
              ? BackendClient.detalhamentos.desarquivarProjeto(detalhamento.id)
              : BackendClient.detalhamentos.arquivarDetalhamento(detalhamento.id),
          origem: demandaCtrl.demandas
              .where((d) => d.id == detalhamento.demandaId)
              .map((d) => 'D-${d.codigo}')
              .firstOrNull,
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ABA 3: PEDIDOS TÉCNICOS (PRODUTO FINAL / FÁBRICA)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPedidosTab(List<PedidoTecnicoModel> list) {
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: _buildEmptyTab(
          icon: Icons.receipt_long_outlined,
          title: 'Nenhum pedido técnico encontrado',
          subtitle: 'Ordens emitidas para corte e dobra aparecerão aqui.',
          actionLabel: '+ Novo Pedido',
          onAction: _abrirNovoPedido,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final pedido = list[index];
        return _DashboardPedidoCard(
          pedido: pedido,
          onTap: () => _abrirPedido(pedido),
        );
      },
    );
  }

  Widget _buildEmptyTab({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 40, color: const Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(title, style: AppCss.mediumBold.setSize(16)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: AppCss.minimumRegular
                    .setSize(13)
                    .setColor(const Color(0xFF64748B))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirDialogOrdenacaoFila(List<DemandaModel> fila) {
    if (fila.isEmpty) {
      NotificationService.showNeutral(
        'Fila Vazia',
        'Não há demandas aguardando detalhamento para ordenar.',
        position: NotificationPosition.bottom,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => _ModalOrdenacaoFila(
        filaInicial: fila,
        onSalvar: (novasDemandas) {
          demandaCtrl.reordenarFila(novasDemandas.map((d) => d.id).toList());
          NotificationService.showPositive(
            'Fila Reordenada',
            'A ordem de prioridade da fila foi salva com sucesso.',
            position: NotificationPosition.bottom,
          );
        },
      ),
    );
  }
}
