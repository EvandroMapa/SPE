import 'dart:async';
import 'package:acoplan/app/app_controller.dart';
import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/detalhamento_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/hash_service.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:acoplan/app/core/services/supabase_service.dart';
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

  /// Executa uma gravação no banco. Em caso de erro avisa o usuário e
  /// recarrega as demandas para desfazer a atualização otimista da tela.
  Future<bool> _persistir(Future<void> Function() gravar) async {
    try {
      await gravar();
      return true;
    } catch (e) {
      NotificationService.showNegative(
        'Não foi possível salvar a demanda',
        mensagemErro(e),
        position: NotificationPosition.bottom,
      );
      await BackendClient.demandas.fetch();
      return false;
    }
  }

  /// Adiciona nova demanda (apenas na coluna Aguardando na Fila).
  /// Retorna null se não foi possível salvar.
  Future<DemandaModel?> adicionarDemanda({
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
    final fila =
        list.where((d) => d.etapa == DemandaEtapa.aguardandoFila).toList();
    final proximaOrdem = fila.isEmpty
        ? 1
        : fila.map((d) => d.ordem).reduce((a, b) => a > b ? a : b) + 1;

    final usuarioLogado = appCtrl.usuario;

    final nova = DemandaModel(
      id: HashService.get,
      ordem: proximaOrdem,
      codigo: 0, // gerado pelo banco
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

    // Salva no Supabase via Collection (a collection atualiza a lista)
    DemandaModel? criada;
    await _persistir(() async => criada = await BackendClient.demandas.criar(nova));
    return criada;
  }

  /// Planilhas (detalhamentos) da demanda — uma demanda pode ter várias.
  List<DetalhamentoModel> obterDetalhamentosDaDemanda(DemandaModel demanda) {
    return BackendClient.detalhamentos.data
        .where((d) =>
            d.demandaId == demanda.id ||
            (demanda.detalhamentoId != null && d.id == demanda.detalhamentoId))
        .toList()
      ..sort((a, b) => a.codigo.compareTo(b.codigo));
  }

  /// Pode criar planilha nova? Não depois que virou projeto ou foi encerrada.
  bool podeCriarPlanilha(DemandaModel demanda) =>
      demanda.desfecho != DemandaDesfecho.projeto && demanda.desfecho != DemandaDesfecho.desistencia;

  /// Cria uma planilha (detalhamento em planejamento) dentro da demanda.
  /// Se a demanda estava na fila, ela passa para Em detalhamento.
  Future<DetalhamentoModel?> criarPlanilha(
    DemandaModel demanda, {
    String? complementoPavimento,
    String? desenho,
  }) async {
    if (!podeCriarPlanilha(demanda)) {
      NotificationService.showNegative(
        'Não é possível criar planilha',
        demanda.travada ? 'Esta demanda já virou projeto.' : 'Esta demanda foi encerrada.',
        position: NotificationPosition.bottom,
      );
      return null;
    }
    final usuarioLogado = appCtrl.usuario;
    final pavimentoFinal = (complementoPavimento != null && complementoPavimento.trim().isNotEmpty)
        ? '${demanda.etapaProjeto} - ${complementoPavimento.trim()}'
        : demanda.etapaProjeto;

    String novoId;
    try {
      novoId = await BackendClient.detalhamentos.criarDetalhamento(DetalhamentoModel(
        id: HashService.get,
        codigo: 0, // gerado pelo banco
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
        situacao: DetalhamentoSituacao.planejamento,
        elementos: const [],
      ));
    } catch (e) {
      NotificationService.showNegative('Erro ao criar planilha', mensagemErro(e),
          position: NotificationPosition.bottom);
      return null;
    }

    // Histórico (falha aqui não impede o trabalho)
    try {
      await SupabaseService.client.rpc('spe_registrar_evento', params: {
        'p_demanda_id': demanda.id,
        'p_detalhamento_id': novoId,
        'p_tipo': 'planilha_criada',
        'p_motivo': pavimentoFinal,
      });
    } catch (_) {}

    var atualizada = demanda;
    if (demanda.detalhamentoId == null || demanda.detalhamentoId!.isEmpty) {
      atualizada = atualizada.copyWith(detalhamentoId: novoId);
    }
    if (demanda.etapa == DemandaEtapa.aguardandoFila) {
      atualizada = atualizada.copyWith(etapa: DemandaEtapa.emProducao);
    }
    if (!identical(atualizada, demanda)) {
      await _persistir(() => BackendClient.demandas.atualizar(atualizada));
    }

    return BackendClient.detalhamentos.data.where((d) => d.id == novoId).firstOrNull;
  }

  /// Decide o destino da demanda em Finalizado.
  Future<bool> definirDesfecho(DemandaModel demanda, DemandaDesfecho desfecho, String motivo) async {
    try {
      await BackendClient.demandas.definirDesfecho(demanda.id, desfecho, motivo);
      await BackendClient.detalhamentos.fetch();
      NotificationService.showPositive(
        switch (desfecho) {
          DemandaDesfecho.projeto => 'Liberado como projeto',
          DemandaDesfecho.orcamento => 'Marcado como orçamento',
          DemandaDesfecho.desistencia => 'Demanda encerrada',
        },
        switch (desfecho) {
          DemandaDesfecho.projeto => '${demanda.obraNome}: as planilhas estão na aba Projetos.',
          DemandaDesfecho.orcamento => '${demanda.obraNome}: pode virar projeto quando o cliente aprovar.',
          DemandaDesfecho.desistencia => '${demanda.obraNome} foi arquivada como desistência.',
        },
        position: NotificationPosition.bottom,
      );
      return true;
    } catch (e) {
      NotificationService.showNegative('Não foi possível definir o desfecho', mensagemErro(e),
          position: NotificationPosition.bottom);
      return false;
    }
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

      _persistir(() => BackendClient.demandas.atualizarOrdens({
            itemAtual.id: itemAcima.ordem,
            itemAcima.id: itemAtual.ordem,
          }));
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

      _persistir(() => BackendClient.demandas.atualizarOrdens({
            itemAtual.id: itemAbaixo.ordem,
            itemAbaixo.id: itemAtual.ordem,
          }));
    }
  }

  /// Reordena a fila inteira a partir de uma lista ordenada de IDs
  void reordenarFila(List<String> idsEmOrdem) {
    final list = List<DemandaModel>.from(demandas);
    final novasOrdens = <String, int>{};
    for (int i = 0; i < idsEmOrdem.length; i++) {
      final id = idsEmOrdem[i];
      final index = list.indexWhere((d) => d.id == id);
      if (index != -1 && list[index].ordem != i + 1) {
        list[index] = list[index].copyWith(ordem: i + 1);
        novasOrdens[id] = i + 1;
      }
    }
    demandasStream.add(list);
    // Atualiza só o que mudou, em paralelo, sem recarregar a fila a cada item
    if (novasOrdens.isNotEmpty) {
      _persistir(() => BackendClient.demandas.atualizarOrdens(novasOrdens));
    }
  }

  /// Transiciona de etapa no Kanban de forma independente
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
    // Virou projeto: não volta de coluna (o banco também bloqueia)
    if (d.travada && novaEtapa != d.etapa) {
      NotificationService.showNeutral(
        'Demanda travada',
        'Esta demanda já virou projeto e não pode mudar de coluna. Você pode arquivá-la.',
        position: NotificationPosition.bottom,
      );
      return false;
    }
    final atualizada = d.copyWith(
      etapa: novaEtapa,
      motivoCorrecao: motivoCorrecao ?? d.motivoCorrecao,
    );
    list[index] = atualizada;
    demandasStream.add(list);

    _persistir(() => BackendClient.demandas.atualizar(atualizada));
    return true;
  }

  /// Arquivar demanda
  Future<void> arquivarDemanda(String id) async {
    final list = List<DemandaModel>.from(demandas);
    final index = list.indexWhere((d) => d.id == id);
    if (index != -1) {
      final atualizada = list[index].copyWith(isArquivado: true);
      list[index] = atualizada;
      demandasStream.add(list);

      if (!await _persistir(() => BackendClient.demandas.atualizar(atualizada))) return;

      NotificationService.showPositive(
        'Demanda Arquivada',
        'A demanda foi arquivada com sucesso.',
        position: NotificationPosition.bottom,
      );
    }
  }

  /// Desarquivar demanda (retorna para Liberado)
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

      if (!await _persistir(() => BackendClient.demandas.atualizar(atualizada))) return;

      NotificationService.showPositive(
        'Demanda Desarquivada',
        'A demanda retornou para Liberado.',
        position: NotificationPosition.bottom,
      );
    }
  }

  /// Atualiza os dados cadastrais da demanda. Retorna false se não salvou.
  Future<bool> atualizarDemanda(DemandaModel demandaAtualizada) async {
    final list = List<DemandaModel>.from(demandas);
    final idx = list.indexWhere((d) => d.id == demandaAtualizada.id);
    if (idx != -1) {
      list[idx] = demandaAtualizada;
      demandasStream.add(list);
    }
    return _persistir(() => BackendClient.demandas.atualizar(demandaAtualizada));
  }

  /// Verifica se a demanda pode ser excluída
  bool podeExcluirDemanda(DemandaModel demanda) {
    return true;
  }

  /// Excluir demanda. Retorna false se não foi possível excluir.
  Future<bool> excluirDemanda(String id) async {
    final list = List<DemandaModel>.from(demandas)..removeWhere((d) => d.id == id);
    demandasStream.add(list);
    return _persistir(() => BackendClient.demandas.delete(id));
  }
}

