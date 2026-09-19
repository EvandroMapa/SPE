import 'package:acoplan/app/app_controller.dart';
import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/cliente_model.dart';
import 'package:acoplan/app/core/client/models/detalhamento_model.dart';
import 'package:acoplan/app/core/client/models/pedido_tecnico_model.dart';
import 'package:acoplan/app/core/components/app_scaffold.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/dashboard/demanda_controller.dart';
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

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = '';
  int _activeTab = 0; // 0 = Demandas (Kanban), 1 = Projetos, 2 = Pedidos
  String _prioridadeFiltro = 'todas'; // 'todas' | 'alta' | 'urgente'

  // Estados da Aba 2 (Projetos / Detalhamentos)
  final Set<String> _expandidosDetalhamentos = {};
  String? _selecionadoDetalhamentoId;
  String _ordenarProjetosPor = 'codigo'; // 'codigo' | 'cliente' | 'obra' | 'peso' | 'elementos'
  bool _ordenarProjetosAsc = false;

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

  void _abrirNovoPedidoParaDemanda(DemandaModel demanda) {
    final vinculados = demandaCtrl.obterDetalhamentosDaDemanda(demanda);
    final det = vinculados.firstOrNull ??
        (demanda.detalhamentoId != null && demanda.detalhamentoId!.isNotEmpty
            ? BackendClient.detalhamentos.data
                .where((d) => d.id == demanda.detalhamentoId)
                .firstOrNull
            : null);

    push(
      context,
      PedidoTecnicoCreatePage(
        pedido: null,
        detalhamentoInicial: det,
        clienteIdInicial: det?.clienteId.isNotEmpty == true ? det!.clienteId : demanda.clienteId,
        obraIdInicial: det?.obraId.isNotEmpty == true ? det!.obraId : demanda.obraId,
        detalhamentoIdInicial: det?.id.isNotEmpty == true ? det!.id : demanda.detalhamentoId,
      ),
    );
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
        onSalvar: (demanda) {
          demandaCtrl.adicionarDemanda(
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
          await demandaCtrl.atualizarDemanda(demandaAtualizada);
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
    final detalhamentos = demandaCtrl.obterDetalhamentosDaDemanda(demanda);

    // Regra 2: Bloqueia exclusão se houver detalhamento vinculado (Diretriz 4.3)
    if (detalhamentos.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.info_outline, size: 40, color: Colors.orange[700]),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Não é possível excluir a demanda',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            'Esta demanda possui ${detalhamentos.length} detalhamento(s) vinculado(s).\n\n'
            'Para excluir a demanda, é necessário primeiro desvincular ou excluir os detalhamentos associados a ela.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMain,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
      return;
    }

    // Se não houver detalhamento vinculado: confirmação prévia (Diretriz 4.2)
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
      await demandaCtrl.excluirDemanda(demanda.id);
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
        onGerarDetalhamento: ({complementoPavimento, desenho}) async {
          Navigator.pop(ctx);
          final novoDet = await demandaCtrl.gerarDetalhamentoParaDemanda(
            context,
            demanda,
            complementoPavimento: complementoPavimento,
            desenho: desenho,
          );
          if (novoDet != null && mounted) {
            _abrirProjeto(novoDet);
          }
        },
        onAbrirDetalhamento: (det) {
          Navigator.pop(ctx);
          _abrirProjeto(det);
        },
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

                  var filteredDetalhamentos = uniqueDetalhamentos.where((p) {
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
                      // ── Barra Superior Única: As 3 Abas Dividindo a Largura (Compactas: 38px) ──
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: _StageTabCard(
                                index: 0,
                                currentIndex: _activeTab,
                                badgeColor: const Color(0xFF2563EB),
                                icon: Icons.view_kanban_rounded,
                                title: '1. Demandas de Detalhamento',
                                count: filteredDemandas.length,
                                onTap: () => setState(() {
                                  _activeTab = 0;
                                  _searchCtrl.clear();
                                  _filter = '';
                                }),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StageTabCard(
                                index: 1,
                                currentIndex: _activeTab,
                                badgeColor: const Color(0xFF0D9488),
                                icon: Icons.architecture_rounded,
                                title: '2. PROJETOS - DETALHAMENTO',
                                count: filteredDetalhamentos.length,
                                onTap: () => setState(() {
                                  _activeTab = 1;
                                  _searchCtrl.clear();
                                  _filter = '';
                                }),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StageTabCard(
                                index: 2,
                                currentIndex: _activeTab,
                                badgeColor: const Color(0xFF6366F1),
                                icon: Icons.receipt_long_rounded,
                                title: '3. Pedidos Técnicos',
                                count: filteredPedidos.length,
                                onTap: () => setState(() {
                                  _activeTab = 2;
                                  _searchCtrl.clear();
                                  _filter = '';
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Linha Única de Ações, Filtros e Busca (Compacta: 38px) ──
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: Row(
                          children: [
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
                                label: const Text('Novo Projeto'),
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
                                message: 'Duplicar projeto selecionado',
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
                            const Spacer(),

                            // Campo de Busca compacto
                            SizedBox(
                              width: 280,
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
                                          ? 'Buscar projetos por código, obra...'
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
                              ),
                            ),
                          ],
                        ),
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
                        'Nenhuma etapa aqui',
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
                        onExcluir: () => _tentarExcluirDemanda(context, item),
                        onPlanilhar: () async {
                          final novoDet = await demandaCtrl
                              .gerarDetalhamentoParaDemanda(context, item);
                          if (novoDet != null && mounted) {
                            _abrirProjeto(novoDet);
                          }
                        },
                        onMover: (novaEtapa) =>
                            demandaCtrl.moverEtapa(context, item.id, novaEtapa),
                        onArquivar: () =>
                            demandaCtrl.arquivarDemanda(item.id),
                        onGerarPedido: () => _abrirNovoPedidoParaDemanda(item),
                        onAbrirDetalhamento: _abrirProjeto,
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
          title: 'Nenhum projeto encontrado',
          subtitle: 'Inicie um novo detalhamento de peças de aço.',
          actionLabel: '+ Criar Projeto',
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
          onGerarPedido: () => _abrirNovoPedidoParaDetalhamento(detalhamento),
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

// ─────────────────────────────────────────────────────────────────────────────
// Card de Aba Compacto (Dividindo todo o espaço, altura: 38px)
// ─────────────────────────────────────────────────────────────────────────────
class _StageTabCard extends StatefulWidget {
  final int index;
  final int currentIndex;
  final Color badgeColor;
  final IconData icon;
  final String title;
  final int count;
  final VoidCallback onTap;

  const _StageTabCard({
    required this.index,
    required this.currentIndex,
    required this.badgeColor,
    required this.icon,
    required this.title,
    required this.count,
    required this.onTap,
  });

  @override
  State<_StageTabCard> createState() => _StageTabCardState();
}

class _StageTabCardState extends State<_StageTabCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.index == widget.currentIndex;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF0F172A)
                  : (_isHovered
                      ? widget.badgeColor.withValues(alpha: 0.5)
                      : const Color(0xFFCBD5E1)),
              width: 1.0,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: isSelected ? Colors.white : widget.badgeColor,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.title,
                  style: AppCss.smallBold.setSize(13).setColor(
                        isSelected ? Colors.white : const Color(0xFF0F172A),
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? widget.badgeColor
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.count.toString(),
                  style: AppCss.minimumBold.setSize(11).setColor(
                        isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card de Demanda no Kanban
// ─────────────────────────────────────────────────────────────────────────────
class _DemandaCard extends StatelessWidget {
  final DemandaModel demanda;
  final bool isFilaManual;
  final VoidCallback onTap;
  final VoidCallback? onEditar;
  final VoidCallback? onExcluir;
  final VoidCallback onPlanilhar;
  final void Function(DemandaEtapa) onMover;
  final VoidCallback onArquivar;
  final VoidCallback onGerarPedido;
  final void Function(DetalhamentoModel)? onAbrirDetalhamento;

  const _DemandaCard({
    required this.demanda,
    required this.isFilaManual,
    required this.onTap,
    this.onEditar,
    this.onExcluir,
    required this.onPlanilhar,
    required this.onMover,
    required this.onArquivar,
    required this.onGerarPedido,
    this.onAbrirDetalhamento,
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

    // Detalhamentos vinculados e integridade de pedidos técnicos (1 para N)
    final detalhamentos = demandaCtrl.obterDetalhamentosDaDemanda(demanda);
    final detVinculado = detalhamentos.firstOrNull;
    final temPedidos = detalhamentos.any((det) =>
        BackendClient.pedidosTecnicos.data
            .any((p) => p.detalhamentoId == det.id));
    final alocados = BackendClient.pedidosTecnicos.quantidadesAlocadas(null);
    final estaTotalmenteAtendido = detalhamentos.isNotEmpty &&
        detalhamentos.every((det) => det.estaTotalmenteAtendido(alocados));

    // Alerta visual de esgotamento/arquivamento na coluna Liberado
    final isAlertaArquivar = demanda.etapa == DemandaEtapa.finalizadoLiberado &&
        estaTotalmenteAtendido;

    final cardBgColor =
        isAlertaArquivar ? const Color(0xFFFEF3C7) : Colors.white;
    final cardBorderColor = isAlertaArquivar
        ? const Color(0xFFF59E0B)
        : const Color(0xFFE2E8F0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: cardBorderColor,
            width: isAlertaArquivar ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isAlertaArquivar
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.02),
              blurRadius: isAlertaArquivar ? 6 : 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha Superior: Ordem/Código, Prioridade e Badge 100% Atendido
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (isFilaManual) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
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
                    Text(
                      'D-${demanda.codigo}',
                      style: AppCss.minimumBold
                          .setSize(10)
                          .setColor(const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (isAlertaArquivar) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 9, color: Colors.white),
                            SizedBox(width: 2),
                            Text(
                              '100% ATENDIDO',
                              style: TextStyle(
                                fontSize: 7.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
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
                          hoverColor:
                              const Color(0xFF2563EB).withValues(alpha: 0.12),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB)
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: const Color(0xFF2563EB)
                                    .withValues(alpha: 0.20),
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
                          hoverColor: AppColors.error.withValues(alpha: 0.12),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.20),
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
              ],
            ),
            const SizedBox(height: 5),

            // Obra / Projeto Principal (Destaque)
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
                color: isAlertaArquivar
                    ? Colors.white.withValues(alpha: 0.7)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isAlertaArquivar
                      ? const Color(0xFFFDE68A)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.layers_outlined,
                      size: 11, color: Color(0xFF64748B)),
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

            // Assinatura do Criador e Status do Detalhamento
            Row(
              children: [
                const Icon(Icons.person_outline_rounded,
                    size: 11, color: Color(0xFF64748B)),
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
                    message: 'Caminho de rede informado (clique para abrir)',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF2563EB).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.folder_shared_outlined,
                          size: 10, color: Color(0xFF2563EB)),
                    ),
                  ),
                ],
              ],
            ),

            // Ramificações em Detalhamento (1 -> N)
            if (detalhamentos.isNotEmpty) ...[
              const SizedBox(height: 5),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCCFBF1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_tree_outlined,
                                size: 11, color: Color(0xFF0D9488)),
                            const SizedBox(width: 3),
                            Text(
                              detalhamentos.length == 1
                                  ? '1 Detalhamento'
                                  : '${detalhamentos.length} Detalhamentos',
                              style: AppCss.minimumBold
                                  .setSize(9)
                                  .setColor(const Color(0xFF0F766E)),
                            ),
                          ],
                        ),
                        Text(
                          '${detalhamentos.fold<double>(0, (prev, e) => prev + e.pesoTotal).toStringAsFixed(0)} kg',
                          style: AppCss.minimumBold
                              .setSize(8.5)
                              .setColor(const Color(0xFF115E59)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        ...detalhamentos.map((det) {
                          final label =
                              det.codigo > 0 ? '#${det.codigo}' : 'Det';
                          final infoTooltip =
                              '${det.desenho.isNotEmpty ? det.desenho : (det.pavimento.isNotEmpty ? det.pavimento : 'Detalhamento')}\n${det.pesoTotal.toStringAsFixed(1)} kg • ${det.elementos.length} elementos\n(Clique para abrir prancha)';
                          return Tooltip(
                            message: infoTooltip,
                            waitDuration: const Duration(milliseconds: 300),
                            child: InkWell(
                              onTap: () => onAbrirDetalhamento?.call(det),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: const Color(0xFF99F6E4)),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.architecture_rounded,
                                        size: 9, color: Color(0xFF0D9488)),
                                    const SizedBox(width: 2.5),
                                    Text(
                                      label,
                                      style: AppCss.minimumBold
                                          .setSize(8.5)
                                          .setColor(const Color(0xFF0F766E)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        Tooltip(
                          message:
                              'Ramificar novo detalhamento para esta demanda',
                          waitDuration: const Duration(milliseconds: 300),
                          child: InkWell(
                            onTap: onPlanilhar,
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D9488)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: const Color(0xFF0D9488)
                                        .withValues(alpha: 0.25)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_rounded,
                                      size: 9.5, color: Color(0xFF0D9488)),
                                  Text(
                                    'Novo',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0D9488),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // Motivo de correção se houver
            if (demanda.motivoCorrecao != null &&
                demanda.motivoCorrecao!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
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

            // ── Rodapé: Ações de transição de etapa ──
            _buildAcoesEtapa(
              context,
              detVinculado: detVinculado,
              temPedidos: temPedidos,
              estaTotalmenteAtendido: estaTotalmenteAtendido,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcoesEtapa(
    BuildContext context, {
    required DetalhamentoModel? detVinculado,
    required bool temPedidos,
    required bool estaTotalmenteAtendido,
  }) {
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
                  borderRadius: BorderRadius.circular(6)),
              textStyle:
                  const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
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
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    backgroundColor: const Color(0xFFF8FAFC),
                    foregroundColor: const Color(0xFF475569),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_rounded, size: 12),
                      SizedBox(width: 3),
                      Flexible(
                        child: Text('Aguard. Det.',
                            style: TextStyle(
                                fontSize: 9.5, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis),
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
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text('P/ Correção',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis),
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
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  backgroundColor: const Color(0xFFF8FAFC),
                  foregroundColor: const Color(0xFF475569),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_rounded, size: 12),
                    SizedBox(width: 3),
                    Flexible(
                      child: Text('Produção',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis),
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
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text('Corrigindo',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis),
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
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  backgroundColor: const Color(0xFFF8FAFC),
                  foregroundColor: const Color(0xFF475569),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_rounded, size: 12),
                    SizedBox(width: 3),
                    Flexible(
                      child: Text('Aguardando',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis),
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
                    '${demanda.obraNome} pronta para pedido.',
                    position: NotificationPosition.bottom,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text('Finalizar',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis),
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
        // Caso esteja 100% atendido: Alerta de esgotamento e botão para arquivar
        if (estaTotalmenteAtendido) {
          return Row(
            children: [
              if (temPedidos) ...[
                Tooltip(
                  message:
                      'Detalhamento protegido: pedidos técnicos vinculados',
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.lock_outline_rounded,
                        size: 14, color: Colors.orange[800]),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onArquivar,
                  icon: const Icon(Icons.inventory_2_outlined,
                      size: 13, color: Colors.white),
                  label: const Text('Arquivar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    textStyle: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          );
        }

        // Fluxo normal da coluna Liberado: Retorno (se permitido) ou Criar Pedido
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  if (temPedidos) {
                    // Trava de integridade! Dispara moverEtapa que abre o modal informativo 4.3
                    onMover(DemandaEtapa.corrigindo);
                  } else {
                    onMover(DemandaEtapa.corrigindo);
                    NotificationService.showNeutral(
                      'Demanda Retornada',
                      '${demanda.obraNome} retornou para Corrigindo.',
                      position: NotificationPosition.bottom,
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  side: BorderSide(
                    color: temPedidos
                        ? const Color(0xFFFDBA74)
                        : const Color(0xFFCBD5E1),
                  ),
                  backgroundColor: temPedidos
                      ? const Color(0xFFFFF7ED)
                      : const Color(0xFFF8FAFC),
                  foregroundColor: temPedidos
                      ? const Color(0xFFC2410C)
                      : const Color(0xFF475569),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      temPedidos
                          ? Icons.lock_outline_rounded
                          : Icons.arrow_back_rounded,
                      size: 12,
                    ),
                    const SizedBox(width: 3),
                    const Flexible(
                      child: Text(
                        'Corrigindo',
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold),
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
                onPressed: onGerarPedido,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text('+ Pedido',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis),
                    ),
                    SizedBox(width: 3),
                    Icon(Icons.arrow_forward_rounded, size: 12),
                  ],
                ),
              ),
            ),
          ],
        );
    }
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
            Text('Informe o motivo ou ajuste necessário:',
                style: AppCss.minimumRegular),
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
                backgroundColor: const Color(0xFFD97706)),
            onPressed: () {
              Navigator.pop(ctx);
              demandaCtrl.moverEtapa(
                context,
                demanda.id,
                DemandaEtapa.aguardandoCorrecao,
                motivoCorrecao: motivoCtrl.text.trim(),
              );
            },
            child: const Text('Confirmar Envio',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Modal de Criação / Edição de Demanda Comercial
// ─────────────────────────────────────────────────────────────────────────────
class _DemandaFormDialog extends StatefulWidget {
  final DemandaModel? demanda;
  final void Function(DemandaModel) onSalvar;

  const _DemandaFormDialog({this.demanda, required this.onSalvar});

  @override
  State<_DemandaFormDialog> createState() => _DemandaFormDialogState();
}

class _DemandaFormDialogState extends State<_DemandaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _clienteNomeCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _enderecoCtrl = TextEditingController();
  final _obraNomeCtrl = TextEditingController();
  final _etapaProjetoCtrl = TextEditingController();
  final _caminhoPastaRedeCtrl = TextEditingController();
  final _solicitanteCtrl = TextEditingController();
  String _prioridade = 'normal';

  ClienteModel? _clienteSelecionado;
  ObraModel? _obraSelecionada;

  bool get _isEdicao => widget.demanda != null;

  @override
  void initState() {
    super.initState();
    if (_isEdicao) {
      final d = widget.demanda!;
      _clienteNomeCtrl.text = d.clienteNome;
      _telefoneCtrl.text = d.clienteTelefone;
      _enderecoCtrl.text = d.clienteEndereco;
      _obraNomeCtrl.text = d.obraNome;
      _etapaProjetoCtrl.text = d.etapaProjeto;
      _caminhoPastaRedeCtrl.text = d.caminhoPastaRede;
      _solicitanteCtrl.text = d.solicitanteComercial;
      _prioridade = d.prioridade;

      final clientes = BackendClient.clientes.data;
      if (d.clienteId.isNotEmpty) {
        _clienteSelecionado =
            clientes.where((c) => c.id == d.clienteId).firstOrNull;
      } else if (d.clienteNome.isNotEmpty) {
        _clienteSelecionado = clientes
            .where((c) => c.nome.toLowerCase() == d.clienteNome.toLowerCase())
            .firstOrNull;
      }

      if (_clienteSelecionado != null) {
        if (d.obraId.isNotEmpty) {
          _obraSelecionada = _clienteSelecionado!.obras
              .where((o) => o.id == d.obraId)
              .firstOrNull;
        } else if (d.obraNome.isNotEmpty) {
          _obraSelecionada = _clienteSelecionado!.obras.where((o) {
            final desc = o.descricao.isNotEmpty ? o.descricao : o.identificador;
            return desc.toLowerCase() == d.obraNome.toLowerCase();
          }).firstOrNull;
        }
      }
    } else {
      final usuarioLogado = appCtrl.usuario;
      if (usuarioLogado != null && usuarioLogado.nome.isNotEmpty) {
        _solicitanteCtrl.text = usuarioLogado.nome;
      }
    }
  }

  @override
  void dispose() {
    _clienteNomeCtrl.dispose();
    _telefoneCtrl.dispose();
    _enderecoCtrl.dispose();
    _obraNomeCtrl.dispose();
    _etapaProjetoCtrl.dispose();
    _caminhoPastaRedeCtrl.dispose();
    _solicitanteCtrl.dispose();
    super.dispose();
  }

  Future<void> _colarCaminhoClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = (data?.text?.replaceAll('"', '') ?? '').trim();
      if (text.isNotEmpty) {
        setState(() {
          _caminhoPastaRedeCtrl.text = text;
        });
        NotificationService.showPositive(
          'Caminho Colado',
          text,
          position: NotificationPosition.bottom,
        );
      } else {
        NotificationService.showPending(
          'Área de Transferência Vazia',
          'Copie o caminho da pasta no Explorer antes de colar.',
          position: NotificationPosition.bottom,
        );
      }
    } catch (_) {
      NotificationService.showNegative(
        'Permissão Negada',
        'Não foi possível ler a área de transferência. Use Ctrl+V no campo.',
        position: NotificationPosition.bottom,
      );
    }
  }

  Future<void> _selecionarPasta() async {
    try {
      // 1. No Desktop (Windows nativo): abre diálogo nativo de seleção de pasta
      if (!kIsWeb) {
        final String? selectedDirectory =
            await FilePicker.getDirectoryPath(
          dialogTitle: 'Selecione a pasta do projeto',
        );

        if (selectedDirectory == null || selectedDirectory.trim().isEmpty) return;

        setState(() {
          _caminhoPastaRedeCtrl.text = selectedDirectory.trim();
        });

        NotificationService.showPositive(
          'Pasta Selecionada',
          selectedDirectory.trim(),
          position: NotificationPosition.bottom,
        );
        return;
      }

      // 2. No Web (onde o navegador restringe o path absoluto por segurança do sandbox):
      final FilePickerResult? result = await FilePicker.pickFiles(
        dialogTitle: 'Selecione qualquer arquivo dentro da pasta do projeto',
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final PlatformFile file = result.files.single;

      if (file.path != null && file.path!.trim().isNotEmpty) {
        final fullPath = file.path!.trim();
        final ultimoSeparador = fullPath.lastIndexOf(RegExp(r'[\\/]'));
        final pasta = ultimoSeparador > 0
            ? fullPath.substring(0, ultimoSeparador)
            : fullPath;

        setState(() {
          _caminhoPastaRedeCtrl.text = pasta;
        });

        NotificationService.showPositive(
          'Pasta Selecionada',
          pasta,
          position: NotificationPosition.bottom,
        );
        return;
      }

      String valorFinal = file.name;
      try {
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        final text = (data?.text?.replaceAll('"', '') ?? '').trim();
        final bool pareceCaminho = text.contains('\\') ||
            text.contains('/') ||
            (text.length >= 2 && text[1] == ':') ||
            text.startsWith(r'\\');
        if (pareceCaminho) {
          valorFinal = text;
        }
      } catch (_) {}

      setState(() {
        _caminhoPastaRedeCtrl.text = valorFinal;
      });

      NotificationService.showPositive(
        'Arquivo / Pasta Selecionado',
        valorFinal,
        position: NotificationPosition.bottom,
      );
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao abrir seletor',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientes = BackendClient.clientes.data;
    final usuarioLogado = appCtrl.usuario;
    final nomeCriador = _isEdicao
        ? (widget.demanda!.criadoPorNome.isNotEmpty
            ? widget.demanda!.criadoPorNome
            : widget.demanda!.solicitanteComercial)
        : (usuarioLogado?.nome.isNotEmpty == true
            ? usuarioLogado!.nome
            : (_solicitanteCtrl.text.isNotEmpty
                ? _solicitanteCtrl.text
                : 'Usuário Atual'));

    final titulo = _isEdicao
        ? 'Editar Demanda D-${widget.demanda!.codigo}'
        : 'Nova Demanda (Aguardando Detalhamento)';
    final subtitulo = _isEdicao
        ? 'Atualize os dados e informações cadastrais da demanda.'
        : 'Cadastre a solicitação na fila de aguardando detalhamento. O detalhamento técnico será gerado posteriormente pelo projetista responsável.';
    final icone = _isEdicao ? Icons.edit_note_rounded : Icons.add_task_rounded;
    final iconeCor = _isEdicao ? const Color(0xFF2563EB) : const Color(0xFF0F172A);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 580,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                            color: iconeCor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icone, size: 20, color: iconeCor),
                        ),
                        const SizedBox(width: 10),
                        Text(titulo, style: AppCss.largeBold.setSize(18)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitulo,
                  style: AppCss.minimumRegular.setColor(const Color(0xFF64748B)),
                ),
                const SizedBox(height: 18),

                // Cliente (Seleção ou Digitação)
                if (clientes.isNotEmpty) ...[
                  DropdownButtonFormField<ClienteModel>(
                    decoration: InputDecoration(
                      labelText: 'Cliente',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                    initialValue: _clienteSelecionado,
                    items: clientes.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text(c.nome, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _clienteSelecionado = val;
                        _obraSelecionada = null;
                        if (val != null) {
                          _clienteNomeCtrl.text = val.nome;
                          _telefoneCtrl.text = val.telefone;
                          final end = val.endereco;
                          final partesEnd = [
                            end.logradouro,
                            if (end.numero.isNotEmpty) end.numero,
                            if (end.bairro.isNotEmpty) end.bairro,
                            if (end.localidade.isNotEmpty)
                              '${end.localidade}/${end.estado}',
                          ].where((p) => p.isNotEmpty).join(', ');
                          _enderecoCtrl.text = partesEnd;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // Telefone e Endereço do Cliente
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        controller: _telefoneCtrl,
                        decoration: InputDecoration(
                          labelText: 'Telefone do Cliente',
                          hintText: '(00) 00000-0000',
                          prefixIcon: const Icon(Icons.phone_outlined, size: 16),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 6,
                      child: TextFormField(
                        controller: _enderecoCtrl,
                        decoration: InputDecoration(
                          labelText: 'Endereço do Cliente',
                          hintText: 'Rua, número, cidade...',
                          prefixIcon: const Icon(Icons.location_on_outlined, size: 16),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Obra do Cliente
                if (_clienteSelecionado != null &&
                    _clienteSelecionado!.obras.isNotEmpty) ...[
                  DropdownButtonFormField<ObraModel>(
                    decoration: InputDecoration(
                      labelText: 'Obra / Projeto',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                    key: ValueKey(_clienteSelecionado?.id ?? 'nenhum'),
                    initialValue: _obraSelecionada,
                    items: _clienteSelecionado!.obras.map((o) {
                      final labelObra = o.descricao.isNotEmpty
                          ? o.descricao
                          : (o.identificador.isNotEmpty
                              ? o.identificador
                              : 'Obra sem nome');
                      return DropdownMenuItem(
                        value: o,
                        child: Text(labelObra, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _obraSelecionada = val;
                        if (val != null) {
                          _obraNomeCtrl.text = val.descricao.isNotEmpty
                              ? val.descricao
                              : val.identificador;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  TextFormField(
                    controller: _obraNomeCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nome da Obra / Projeto',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Informe a obra' : null,
                  ),
                  const SizedBox(height: 12),
                ],

                // Etapa Específica do Projeto
                TextFormField(
                  controller: _etapaProjetoCtrl,
                  decoration: InputDecoration(
                    labelText: 'Etapa do Projeto / Pavimento',
                    hintText: 'Ex: 1º Pavimento Tipo - Vigas e Lajes, Fundações...',
                    prefixIcon: const Icon(Icons.layers_outlined, size: 16),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Informe a etapa da obra'
                      : null,
                ),
                const SizedBox(height: 12),

                // Caminho da Pasta do Projeto na Rede / Computador
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _caminhoPastaRedeCtrl,
                        decoration: InputDecoration(
                          labelText:
                              'Caminho da Pasta do Projeto (Rede / Local)',
                          hintText:
                              r'Ex: \\servidor\projetos\obras\edificio_jardins ou C:\Projetos',
                          prefixIcon: const Icon(Icons.folder_shared_outlined,
                              size: 16),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_caminhoPastaRedeCtrl.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear_rounded,
                                      size: 16),
                                  onPressed: () => setState(
                                      () => _caminhoPastaRedeCtrl.clear()),
                                  tooltip: 'Limpar caminho',
                                ),
                              IconButton(
                                icon: const Icon(Icons.content_paste_rounded,
                                    size: 16),
                                onPressed: _colarCaminhoClipboard,
                                tooltip: 'Colar da área de transferência',
                              ),
                            ],
                          ),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _selecionarPasta,
                        icon: const Icon(Icons.folder_open_rounded, size: 16),
                        label: const Text('Navegar Pasta'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Solicitante Comercial e Prioridade
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: TextFormField(
                        controller: _solicitanteCtrl,
                        decoration: InputDecoration(
                          labelText: 'Solicitante Comercial',
                          hintText: 'Ex: Carlos',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Informe o solicitante'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Prioridade',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                        initialValue: _prioridade,
                        items: const [
                          DropdownMenuItem(
                              value: 'normal', child: Text('Normal')),
                          DropdownMenuItem(
                              value: 'alta', child: Text('Alta')),
                          DropdownMenuItem(
                              value: 'urgente', child: Text('Urgente')),
                        ],
                        onChanged: (val) =>
                            setState(() => _prioridade = val ?? 'normal'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Assinatura do Criador (Informativo)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_outlined,
                          size: 16, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Demanda assinada por: $nomeCriador',
                          style: AppCss.minimumBold
                              .setSize(11.5)
                              .setColor(const Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Botões
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState?.validate() == true) {
                          final clienteNome = _clienteSelecionado?.nome ??
                              _clienteNomeCtrl.text.trim();
                          final obraNome = _obraSelecionada != null
                              ? (_obraSelecionada!.descricao.isNotEmpty
                                  ? _obraSelecionada!.descricao
                                  : _obraSelecionada!.identificador)
                              : _obraNomeCtrl.text.trim();

                          if (_isEdicao) {
                            final demandaAtualizada = widget.demanda!.copyWith(
                              clienteId: _clienteSelecionado?.id ??
                                  widget.demanda!.clienteId,
                              clienteNome: clienteNome.isNotEmpty
                                  ? clienteNome
                                  : widget.demanda!.clienteNome,
                              clienteTelefone: _telefoneCtrl.text.trim(),
                              clienteEndereco: _enderecoCtrl.text.trim(),
                              obraId: _obraSelecionada?.id ??
                                  widget.demanda!.obraId,
                              obraNome: obraNome.isNotEmpty
                                  ? obraNome
                                  : widget.demanda!.obraNome,
                              etapaProjeto: _etapaProjetoCtrl.text.trim(),
                              caminhoPastaRede:
                                  _caminhoPastaRedeCtrl.text.trim(),
                              solicitanteComercial:
                                  _solicitanteCtrl.text.trim(),
                              prioridade: _prioridade,
                            );
                            widget.onSalvar(demandaAtualizada);
                          } else {
                            final nova = DemandaModel(
                              id: '',
                              ordem: 0,
                              codigo: 0,
                              clienteId: _clienteSelecionado?.id ?? '',
                              clienteNome: clienteNome.isNotEmpty
                                  ? clienteNome
                                  : 'Cliente não informado',
                              clienteTelefone: _telefoneCtrl.text.trim(),
                              clienteEndereco: _enderecoCtrl.text.trim(),
                              obraId: _obraSelecionada?.id ?? '',
                              obraNome: obraNome.isNotEmpty
                                  ? obraNome
                                  : 'Obra não informada',
                              etapaProjeto: _etapaProjetoCtrl.text.trim(),
                              caminhoPastaRede:
                                  _caminhoPastaRedeCtrl.text.trim(),
                              solicitanteComercial:
                                  _solicitanteCtrl.text.trim(),
                              etapa: DemandaEtapa.aguardandoFila,
                              prioridade: _prioridade,
                              criadoPorId: usuarioLogado?.id ?? '',
                              criadoPorNome: nomeCriador,
                              criadoEm: DateTime.now(),
                            );
                            widget.onSalvar(nova);
                          }
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(_isEdicao ? 'Salvar Alterações' : 'Cadastrar na Fila'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modal de Detalhes da Demanda (Visualização, Contato, Pasta de Rede e Geração)
// ─────────────────────────────────────────────────────────────────────────────
class _DemandaDetalhesDialog extends StatelessWidget {
  final DemandaModel demanda;
  final VoidCallback? onEditar;
  final VoidCallback? onExcluir;
  final Future<void> Function({String? complementoPavimento, String? desenho})
      onGerarDetalhamento;
  final void Function(DetalhamentoModel detalhamento) onAbrirDetalhamento;

  const _DemandaDetalhesDialog({
    required this.demanda,
    this.onEditar,
    this.onExcluir,
    required this.onGerarDetalhamento,
    required this.onAbrirDetalhamento,
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

  void _abrirModalNovoDetalhamento(BuildContext context) {
    final desenhoCtrl = TextEditingController();
    final complementoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_tree_outlined,
                  size: 20, color: Color(0xFF0D9488)),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Nova Ramificação de Detalhamento',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Criar um novo detalhamento técnico vinculado à demanda ${demanda.obraNome} (${demanda.etapaProjeto}).',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: desenhoCtrl,
                decoration: InputDecoration(
                  labelText: 'Identificação / Prancha / Desenho (Opcional)',
                  hintText: 'Ex: DWG-01, Vigas V1 a V15, Bloco B',
                  prefixIcon: const Icon(Icons.architecture_rounded, size: 18),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: complementoCtrl,
                decoration: InputDecoration(
                  labelText: 'Complemento da Etapa / Pavimento (Opcional)',
                  hintText: 'Ex: Baldrame, Laje Superior, Trecho 2',
                  prefixIcon: const Icon(Icons.layers_outlined, size: 18),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              onGerarDetalhamento(
                complementoPavimento: complementoCtrl.text,
                desenho: desenhoCtrl.text,
              );
            },
            child: const Text('Criar Detalhamento'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prioridadeColor = _corPrioridade(demanda.prioridade);
    final detalhamentos = demandaCtrl.obterDetalhamentosDaDemanda(demanda);
    final totalPesoDemanda =
        detalhamentos.fold<double>(0, (sum, item) => sum + item.pesoTotal);
    final totalElementosDemanda =
        detalhamentos.fold<int>(0, (sum, item) => sum + item.elementos.length);

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
              const SizedBox(height: 20),

              // ── Bloco 4: RAMIFICAÇÕES EM DETALHAMENTO (1 -> N) ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_tree_outlined,
                          size: 16, color: Color(0xFF0D9488)),
                      const SizedBox(width: 6),
                      Text(
                        'RAMIFICAÇÕES EM DETALHAMENTO (${detalhamentos.length})',
                        style: AppCss.minimumBold
                            .setSize(11)
                            .setColor(const Color(0xFF0D9488))
                            .setLetterSpacing(0.8),
                      ),
                    ],
                  ),
                  if (detalhamentos.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => _abrirModalNovoDetalhamento(context),
                      icon: const Icon(Icons.add_rounded, size: 14),
                      label: const Text('Novo Detalhamento'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        side: const BorderSide(color: Color(0xFF0D9488)),
                        foregroundColor: const Color(0xFF0D9488),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                        textStyle: AppCss.minimumBold.setSize(11),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              if (detalhamentos.isEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 18, color: Color(0xFF1D4ED8)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Nenhum detalhamento técnico iniciado para esta demanda ainda.',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1D4ED8)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _abrirModalNovoDetalhamento(context),
                          icon: const Icon(Icons.architecture_rounded,
                              size: 18, color: Colors.white),
                          label:
                              const Text('Gerar Primeiro Detalhamento Técnico'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      // Resumo total da Demanda
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(9),
                            topRight: Radius.circular(9),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${detalhamentos.length} ${detalhamentos.length == 1 ? 'prancha/detalhamento vinculado' : 'pranchas/detalhamentos vinculados'}',
                              style: AppCss.minimumBold
                                  .setSize(11)
                                  .setColor(const Color(0xFF475569)),
                            ),
                            Text(
                              'Total: $totalElementosDemanda elem. • ${totalPesoDemanda.toStringAsFixed(1)} kg',
                              style: AppCss.minimumBold
                                  .setSize(11)
                                  .setColor(const Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: detalhamentos.length,
                        separatorBuilder: (_, _) => const Divider(
                            height: 1, color: Color(0xFFE2E8F0)),
                        itemBuilder: (context, index) {
                          final det = detalhamentos[index];
                          final temPedidos = BackendClient.pedidosTecnicos.data
                              .any((p) => p.detalhamentoId == det.id);

                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D9488)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                      Icons.architecture_rounded,
                                      size: 20,
                                      color: Color(0xFF0D9488)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Detalhamento #${det.codigo}',
                                            style: AppCss.smallBold
                                                .setSize(13)
                                                .setColor(
                                                    const Color(0xFF0F172A)),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0F172A)
                                                  .withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              det.etapaKanban.label,
                                              style: AppCss.minimumBold
                                                  .setSize(8.5)
                                                  .setColor(
                                                      const Color(0xFF0F172A)),
                                            ),
                                          ),
                                          if (temPedidos) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF2563EB)
                                                    .withValues(alpha: 0.10),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'PEDIDO EMITIDO',
                                                style: AppCss.minimumBold
                                                    .setSize(8.5)
                                                    .setColor(const Color(
                                                        0xFF2563EB)),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        det.desenho.isNotEmpty
                                            ? '${det.desenho} • ${det.pavimento}'
                                            : det.pavimento,
                                        style: AppCss.minimumBold
                                            .setSize(11.5)
                                            .setColor(
                                                const Color(0xFF334155)),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${det.elementos.length} elementos armados • ${det.pesoTotal.toStringAsFixed(1)} kg de aço${det.funcionarioNome.isNotEmpty ? ' • Resp: ${det.funcionarioNome}' : ''}',
                                        style: AppCss.minimumRegular
                                            .setSize(10.5)
                                            .setColor(
                                                const Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () => onAbrirDetalhamento(det),
                                  icon: const Icon(Icons.open_in_new_rounded,
                                      size: 14, color: Colors.white),
                                  label: const Text('Abrir'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFF0D9488),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(6)),
                                    textStyle: AppCss.minimumBold.setSize(11),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

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
  final VoidCallback onExcluir;
  final void Function(PedidoTecnicoModel) onAbrirPedido;
  final VoidCallback? onGerarPedido;

  const _DashboardDetalhamentoCard({
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
    this.onGerarPedido,
  });

  @override
  Widget build(BuildContext context) {
    final temPedidos = pedidosVinculados.isNotEmpty;
    final fmt = DateFormat('dd/MM/yyyy');

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

                  Color corEtapa(DemandaEtapa etapa) {
                    switch (etapa) {
                      case DemandaEtapa.aguardandoFila:
                        return const Color(0xFF3B82F6);
                      case DemandaEtapa.emProducao:
                        return const Color(0xFF0D9488);
                      case DemandaEtapa.aguardandoCorrecao:
                        return const Color(0xFFD97706);
                      case DemandaEtapa.corrigindo:
                        return const Color(0xFFEA580C);
                      case DemandaEtapa.finalizadoLiberado:
                        return const Color(0xFF059669);
                    }
                  }

                  return Row(
                    children: [
                      Flexible(
                        child: Text(
                          nomeExibicao,
                          style: AppCss.smallBold.setSize(14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: corEtapa(detalhamento.etapaKanban)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: corEtapa(detalhamento.etapaKanban)
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          detalhamento.etapaKanban.label,
                          style: AppCss.minimumBold
                              .setSize(9.5)
                              .setColor(corEtapa(detalhamento.etapaKanban)),
                        ),
                      ),
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
                  Row(
                    children: [
                      Icon(Icons.layers_outlined,
                          size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        '${detalhamento.elementos.length} elemento(s)',
                        style: AppCss.minimumBold
                            .setColor(Colors.grey[600]!)
                            .setSize(11),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.scale_outlined,
                        size: 12,
                        color: detalhamento.pesoTotal > 0
                            ? const Color(0xFF10B981)
                            : Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        detalhamento.pesoTotal > 0
                            ? (detalhamento.pesoTotal >= 1000
                                ? '${(detalhamento.pesoTotal / 1000).toStringAsFixed(2)} t'
                                : '${NumberFormat('#,##0.00', 'pt_BR').format(detalhamento.pesoTotal)} kg')
                            : 'Sem peso',
                        style: AppCss.minimumBold
                            .setColor(detalhamento.pesoTotal > 0
                                ? const Color(0xFF10B981)
                                : Colors.grey[400]!)
                            .setSize(11),
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
                                ? const Color(0xFF3B82F6)
                                    .withValues(alpha: 0.15)
                                : const Color(0xFF3B82F6)
                                    .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF3B82F6).withValues(
                                  alpha: expandido ? 0.35 : 0.15),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.assignment_outlined,
                                  size: 14, color: Color(0xFF3B82F6)),
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
                                child: const Icon(Icons.expand_more,
                                    size: 14, color: Color(0xFF3B82F6)),
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
                            color: const Color(0xFF059669).withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.post_add_outlined,
                              size: 18, color: Color(0xFF059669)),
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
                          color: AppColors.primaryMain
                              .withValues(alpha: 0.10),
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
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
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
                                        style: AppCss.minimumBold
                                            .setSize(12),
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
