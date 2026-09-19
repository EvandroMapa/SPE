import 'dart:async';
import 'package:acoplan/app/app_controller.dart';
import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/detalhamento_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/hash_service.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/dashboard/models/demanda_model.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

final demandaCtrl = DemandaController();

class DemandaController {
  static final DemandaController _instance = DemandaController._();
  DemandaController._() {
    _initStream();
  }
  factory DemandaController() => _instance;

  final AppStream<List<DemandaModel>> demandasStream =
      AppStream<List<DemandaModel>>.seed([]);

  List<DemandaModel> get demandas => demandasStream.value;

  StreamSubscription? _sub;

  void dispose() {
    _sub?.cancel();
  }

  void _initStream() {
    // Sincroniza com BackendClient.demandas.dataStream
    _sub = BackendClient.demandas.dataStream.listen.listen((lista) {
      demandasStream.add(List<DemandaModel>.from(lista));
    });

    if (BackendClient.demandas.data.isNotEmpty) {
      demandasStream.add(List<DemandaModel>.from(BackendClient.demandas.data));
    }
  }

  /// Adiciona nova demanda (apenas na coluna Aguardando na Fila)
  Future<DemandaModel> adicionarDemanda({
    required String clienteNome,
    String clienteId = '',
    String clienteTelefone = '',
    String clienteEndereco = '',
    required String obraNome,
    String obraId = '',
    required String etapaProjeto,
    String caminhoPastaRede = '',
    required String solicitanteComercial,
    String prioridade = 'normal',
  }) async {
    final list = List<DemandaModel>.from(demandas);
    final proximoCodigo = list.isEmpty
        ? 1
        : list.map((d) => d.codigo).reduce((a, b) => a > b ? a : b) + 1;

    final fila =
        list.where((d) => d.etapa == DemandaEtapa.aguardandoFila).toList();
    final proximaOrdem = fila.isEmpty
        ? 1
        : fila.map((d) => d.ordem).reduce((a, b) => a > b ? a : b) + 1;

    final usuarioLogado = appCtrl.usuario;

    final nova = DemandaModel(
      id: HashService.get,
      ordem: proximaOrdem,
      codigo: proximoCodigo,
      clienteId: clienteId,
      clienteNome: clienteNome,
      clienteTelefone: clienteTelefone,
      clienteEndereco: clienteEndereco,
      obraId: obraId,
      obraNome: obraNome,
      etapaProjeto: etapaProjeto,
      caminhoPastaRede: caminhoPastaRede,
      solicitanteComercial: solicitanteComercial,
      criadoPorId: usuarioLogado?.id ?? '',
      criadoPorNome: usuarioLogado?.nome.isNotEmpty == true
          ? usuarioLogado!.nome
          : solicitanteComercial,
      etapa: DemandaEtapa.aguardandoFila,
      prioridade: prioridade,
      isArquivado: false,
      criadoEm: DateTime.now(),
    );

    // Salva no Supabase via Collection
    final criado = await BackendClient.demandas.criar(nova);
    final finalDemanda = criado ?? nova;

    if (!demandas.any((d) => d.id == finalDemanda.id)) {
      list.add(finalDemanda);
      demandasStream.add(list);
    }
    return finalDemanda;
  }

  /// Retorna todos os detalhamentos vinculados a esta demanda (relação 1 -> N)
  List<DetalhamentoModel> obterDetalhamentosDaDemanda(DemandaModel demanda) {
    return BackendClient.detalhamentos.data
        .where((d) =>
            d.demandaId == demanda.id ||
            (demanda.detalhamentoId != null && d.id == demanda.detalhamentoId))
        .toList();
  }

  /// Gera um Detalhamento Técnico no Supabase para a demanda especificada (suporta ramificações 1 -> N)
  Future<DetalhamentoModel?> gerarDetalhamentoParaDemanda(
    BuildContext context,
    DemandaModel demanda, {
    String? complementoPavimento,
    String? desenho,
  }) async {
    final usuarioLogado = appCtrl.usuario;

    final pavimentoFinal = (complementoPavimento != null &&
            complementoPavimento.trim().isNotEmpty)
        ? '${demanda.etapaProjeto} - ${complementoPavimento.trim()}'
        : demanda.etapaProjeto;

    // 1. Cria o detalhamento no Supabase
    final novoDetalhamentoModel = DetalhamentoModel(
      id: HashService.get,
      codigo: 0, // calculado pelo Supabase
      clienteId: demanda.clienteId,
      clienteNome: demanda.clienteNome,
      obraId: demanda.obraId,
      obraNome: demanda.obraNome,
      desenho: desenho?.trim() ?? '',
      pavimento: pavimentoFinal,
      funcionarioId: usuarioLogado?.id ?? '',
      funcionarioNome: usuarioLogado?.nome ?? '',
      etapaKanban: DemandaEtapa.emProducao,
      prioridade: demanda.prioridade,
      demandaId: demanda.id,
      isArquivado: false,
      elementos: const [],
    );

    String novoId = '';
    try {
      novoId = await BackendClient.detalhamentos
          .criarDetalhamento(novoDetalhamentoModel);
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao gerar detalhamento',
        e.toString(),
        position: NotificationPosition.bottom,
      );
      return null;
    }

    // 2. Atualiza a demanda vinculando o detalhamento e avançando para Em Produção se estava na Fila
    final novaEtapa = demanda.etapa == DemandaEtapa.aguardandoFila
        ? DemandaEtapa.emProducao
        : demanda.etapa;

    final demandaAtualizada = demanda.copyWith(
      detalhamentoId: demanda.detalhamentoId ?? novoId,
      etapa: novaEtapa,
    );

    await BackendClient.demandas.atualizar(demandaAtualizada);

    final list = List<DemandaModel>.from(demandas);
    final idx = list.indexWhere((d) => d.id == demanda.id);
    if (idx != -1) {
      list[idx] = demandaAtualizada;
      demandasStream.add(list);
    }

    NotificationService.showPositive(
      'Detalhamento Criado',
      'Nova ramificação vinculada à demanda. Etapa: ${novaEtapa.label}.',
      position: NotificationPosition.bottom,
    );

    return BackendClient.detalhamentos.data
        .where((d) => d.id == novoId)
        .firstOrNull;
  }

  /// Sobe um item na fila manual
  void subirNaFila(String id) {
    final list = List<DemandaModel>.from(demandas);
    final fila = list
        .where((d) => d.etapa == DemandaEtapa.aguardandoFila)
        .toList()
      ..sort((a, b) => a.ordem.compareTo(b.ordem));

    final index = fila.indexWhere((d) => d.id == id);
    if (index > 0) {
      final itemAtual = fila[index];
      final itemAcima = fila[index - 1];

      final tempOrdem = itemAtual.ordem;
      itemAtual.ordem = itemAcima.ordem;
      itemAcima.ordem = tempOrdem;

      BackendClient.demandas.atualizar(itemAtual);
      BackendClient.demandas.atualizar(itemAcima);
      demandasStream.add(list);
    }
  }

  /// Desce um item na fila manual
  void descerNaFila(String id) {
    final list = List<DemandaModel>.from(demandas);
    final fila = list
        .where((d) => d.etapa == DemandaEtapa.aguardandoFila)
        .toList()
      ..sort((a, b) => a.ordem.compareTo(b.ordem));

    final index = fila.indexWhere((d) => d.id == id);
    if (index >= 0 && index < fila.length - 1) {
      final itemAtual = fila[index];
      final itemAbaixo = fila[index + 1];

      final tempOrdem = itemAtual.ordem;
      itemAtual.ordem = itemAbaixo.ordem;
      itemAbaixo.ordem = tempOrdem;

      BackendClient.demandas.atualizar(itemAtual);
      BackendClient.demandas.atualizar(itemAbaixo);
      demandasStream.add(list);
    }
  }

  /// Reordena a fila inteira a partir de uma lista ordenada de IDs
  void reordenarFila(List<String> idsEmOrdem) {
    final list = List<DemandaModel>.from(demandas);
    for (int i = 0; i < idsEmOrdem.length; i++) {
      final id = idsEmOrdem[i];
      final index = list.indexWhere((d) => d.id == id);
      if (index != -1) {
        list[index] = list[index].copyWith(ordem: i + 1);
        BackendClient.demandas.atualizar(list[index]);
      }
    }
    demandasStream.add(list);
  }

  /// Transiciona de etapa no Kanban com validação de trava de integridade
  bool moverEtapa(
    BuildContext context,
    String id,
    DemandaEtapa novaEtapa, {
    String? motivoCorrecao,
  }) {
    final list = List<DemandaModel>.from(demandas);
    final index = list.indexWhere((d) => d.id == id);
    if (index == -1) return false;

    final d = list[index];

    // REGRA DE TRAVA: Se está em Liberado e possui Pedido Técnico emitido em qualquer detalhamento, NÃO pode sair de Liberado
    if (d.etapa == DemandaEtapa.finalizadoLiberado &&
        novaEtapa != DemandaEtapa.finalizadoLiberado) {
      final vinculados = obterDetalhamentosDaDemanda(d);
      final temPedidos = vinculados.any((det) => BackendClient.pedidosTecnicos.data
          .any((p) => p.detalhamentoId == det.id));

      if (temPedidos) {
        _mostrarDialogoBloqueioPedido(context);
        return false;
      }
    }

    final atualizada = d.copyWith(
      etapa: novaEtapa,
      motivoCorrecao: motivoCorrecao ?? d.motivoCorrecao,
    );
    list[index] = atualizada;
    demandasStream.add(list);

    BackendClient.demandas.atualizar(atualizada);

    // Sincroniza a etapa em todos os detalhamentos vinculados
    final vinculados = obterDetalhamentosDaDemanda(d);
    for (final det in vinculados) {
      BackendClient.detalhamentos
          .atualizarEtapaKanban(det.id, novaEtapa.name);
    }

    return true;
  }

  /// Diálogo informativo de bloqueio (Diretriz 4.3)
  void _mostrarDialogoBloqueioPedido(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, size: 40, color: Colors.orange[700]),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Detalhamento com Pedido Vinculado',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'Este detalhamento já possui Pedido(s) Técnico(s) gerado(s) (total ou parcial).\n\n'
          'Para garantir a rastreabilidade e integridade das ordens de produção emitidas, ele não pode ser movido da coluna Liberado.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              foregroundColor: Colors.white,
            ),
            onPressed: () => pop(ctx),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  /// Arquivar demanda (e todos os seus detalhamentos vinculados)
  Future<void> arquivarDemanda(String id) async {
    final list = List<DemandaModel>.from(demandas);
    final index = list.indexWhere((d) => d.id == id);
    if (index != -1) {
      final atualizada = list[index].copyWith(isArquivado: true);
      list[index] = atualizada;
      demandasStream.add(list);

      await BackendClient.demandas.atualizar(atualizada);

      final vinculados = obterDetalhamentosDaDemanda(atualizada);
      final detIds = <String>{
        ...vinculados.map((d) => d.id),
        if (atualizada.detalhamentoId != null && atualizada.detalhamentoId!.isNotEmpty)
          atualizada.detalhamentoId!,
      };
      for (final detId in detIds) {
        await BackendClient.detalhamentos.arquivarDetalhamento(detId);
      }

      NotificationService.showPositive(
        'Demanda Arquivada',
        'A demanda e seus detalhamentos foram arquivados.',
        position: NotificationPosition.bottom,
      );
    }
  }

  /// Desarquivar demanda (retorna SEMPRE para Liberado)
  Future<void> desarquivarDemanda(String id) async {
    final list = List<DemandaModel>.from(demandas);
    final index = list.indexWhere((d) => d.id == id);
    if (index != -1) {
      final atualizada = list[index].copyWith(
        isArquivado: false,
        etapa: DemandaEtapa.finalizadoLiberado,
      );
      list[index] = atualizada;
      demandasStream.add(list);

      await BackendClient.demandas.atualizar(atualizada);

      final vinculados = obterDetalhamentosDaDemanda(atualizada);
      final detIds = <String>{
        ...vinculados.map((d) => d.id),
        if (atualizada.detalhamentoId != null && atualizada.detalhamentoId!.isNotEmpty)
          atualizada.detalhamentoId!,
      };
      for (final detId in detIds) {
        await BackendClient.detalhamentos.desarquivarDetalhamento(detId);
      }

      NotificationService.showPositive(
        'Demanda Desarquivada',
        'A demanda e seus detalhamentos retornaram para Liberado.',
        position: NotificationPosition.bottom,
      );
    }
  }

  /// Atualiza os dados cadastrais da demanda
  Future<void> atualizarDemanda(DemandaModel demandaAtualizada) async {
    final list = List<DemandaModel>.from(demandas);
    final idx = list.indexWhere((d) => d.id == demandaAtualizada.id);
    if (idx != -1) {
      list[idx] = demandaAtualizada;
      demandasStream.add(list);
    }
    await BackendClient.demandas.atualizar(demandaAtualizada);

    // Sincroniza dados cadastrais básicos em detalhamentos vinculados se existirem
    final vinculados = obterDetalhamentosDaDemanda(demandaAtualizada);
    for (final det in vinculados) {
      if (det.clienteNome != demandaAtualizada.clienteNome ||
          det.obraNome != demandaAtualizada.obraNome) {
        final detAtualizado = det.copyWith(
          clienteNome: demandaAtualizada.clienteNome,
          obraNome: demandaAtualizada.obraNome,
          prioridade: demandaAtualizada.prioridade,
        );
        await BackendClient.detalhamentos
            .atualizarDetalhamento(detAtualizado);
      }
    }
  }

  /// Verifica se a demanda pode ser excluída (regra: somente se não tiver detalhamento vinculado)
  bool podeExcluirDemanda(DemandaModel demanda) {
    return obterDetalhamentosDaDemanda(demanda).isEmpty;
  }

  /// Excluir demanda
  Future<void> excluirDemanda(String id) async {
    final list = List<DemandaModel>.from(demandas)..removeWhere((d) => d.id == id);
    demandasStream.add(list);
    await BackendClient.demandas.delete(id);
  }
}

