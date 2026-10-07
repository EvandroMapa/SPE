import 'dart:async';
import 'package:acoplan/app/app_controller.dart';
import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/detalhamento_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/hash_service.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
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

  /// Detalhamentos da demanda — uma demanda pode ter vários.
  List<DetalhamentoModel> obterDetalhamentosDaDemanda(DemandaModel demanda) {
    return BackendClient.detalhamentos.data
        .where((d) =>
            d.demandaId == demanda.id ||
            (demanda.detalhamentoId != null && d.id == demanda.detalhamentoId))
        .toList()
      ..sort((a, b) => a.codigo.compareTo(b.codigo));
  }

  DemandaModel? demandaDoDetalhamento(DetalhamentoModel det) {
    if (det.demandaId == null || det.demandaId!.isEmpty) return null;
    return demandas.where((d) => d.id == det.demandaId).firstOrNull;
  }

  /// Etapas da demanda cobertas por este detalhamento.
  List<DemandaEtapaModel> etapasDoDetalhamento(DetalhamentoModel det) {
    final demanda = demandaDoDetalhamento(det);
    if (demanda == null) return const [];
    return demanda.etapas.where((e) => e.detalhamentoId == det.id).toList();
  }

  /// Única trava do fluxo: pedido técnico só com a demanda em Finalizado /
  /// Liberado. Detalhamento sem demanda (avulso/antigo) não tem trava.
  /// O banco aplica a mesma regra (migração 05).
  bool detalhamentoLiberadoParaPedido(DetalhamentoModel det) {
    if (det.isArquivado) return false;
    final demanda = demandaDoDetalhamento(det);
    return demanda == null || demanda.liberadaParaPedido;
  }

  // ── Etapas da demanda ─────────────────────────────────────

  Future<bool> adicionarEtapa(DemandaModel demanda, String nome) async {
    final n = nome.trim();
    if (n.isEmpty) return false;
    final ordem = demanda.etapas.isEmpty ? 1 : demanda.etapas.map((e) => e.ordem).reduce((a, b) => a > b ? a : b) + 1;
    return _persistir(() => BackendClient.demandas.adicionarEtapa(demanda.id, n, ordem));
  }

  Future<bool> renomearEtapa(DemandaEtapaModel etapa, String nome) async {
    final n = nome.trim();
    if (n.isEmpty || n == etapa.nome) return false;
    final ok = await _persistir(() => BackendClient.demandas.atualizarEtapa(etapa.id, {'nome': n}));
    if (ok && etapa.temDetalhamento) await _sincronizarPavimento(etapa.detalhamentoId!);
    return ok;
  }

  Future<bool> removerEtapa(DemandaEtapaModel etapa) async {
    final ok = await _persistir(() => BackendClient.demandas.removerEtapa(etapa.id));
    if (ok && etapa.temDetalhamento) await _sincronizarPavimento(etapa.detalhamentoId!);
    return ok;
  }

  /// Move a etapa para outro detalhamento (ou tira de qualquer um, com null).
  Future<bool> vincularEtapa(DemandaEtapaModel etapa, String? detalhamentoId) async {
    if (etapa.detalhamentoId == detalhamentoId) return true;
    final anterior = etapa.detalhamentoId;
    final ok = await _persistir(
        () => BackendClient.demandas.atualizarEtapa(etapa.id, {'detalhamento_id': detalhamentoId}));
    if (ok) {
      if (anterior != null && anterior.isNotEmpty) await _sincronizarPavimento(anterior);
      if (detalhamentoId != null) await _sincronizarPavimento(detalhamentoId);
    }
    return ok;
  }

  /// O "pavimento" do detalhamento passa a listar as etapas que ele cobre.
  Future<void> _sincronizarPavimento(String detalhamentoId) async {
    final det = BackendClient.detalhamentos.data.where((d) => d.id == detalhamentoId).firstOrNull;
    if (det == null) return;
    final nomes = etapasDoDetalhamento(det).map((e) => e.nome).toList();
    if (nomes.isEmpty) return;
    final texto = nomes.join(' + ');
    if (texto == det.pavimento) return;
    try {
      await BackendClient.detalhamentos.atualizarDetalhamento(det.copyWith(pavimento: texto));
    } catch (_) {}
  }

  /// Cria um detalhamento cobrindo as [etapas] escolhidas (uma, várias ou
  /// todas). Se a demanda estava na fila, ela vai para Em produção.
  Future<DetalhamentoModel?> criarDetalhamento(
    DemandaModel demanda,
    List<DemandaEtapaModel> etapas, {
    String? desenho,
  }) async {
    if (etapas.isEmpty) {
      NotificationService.showNegative('Escolha as etapas', 'Marque ao menos uma etapa para o detalhamento.',
          position: NotificationPosition.bottom);
      return null;
    }
    final usuarioLogado = appCtrl.usuario;
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
        pavimento: etapas.map((e) => e.nome).join(' + '),
        funcionarioId: usuarioLogado?.id ?? '',
        funcionarioNome: usuarioLogado?.nome ?? '',
        etapaKanban: DemandaEtapa.emProducao,
        prioridade: demanda.prioridade,
        demandaId: demanda.id,
        elementos: const [],
      ));
    } catch (e) {
      NotificationService.showNegative('Erro ao criar detalhamento', mensagemErro(e),
          position: NotificationPosition.bottom);
      return null;
    }

    await _persistir(() async {
      for (final e in etapas) {
        await BackendClient.demandas.atualizarEtapa(e.id, {'detalhamento_id': novoId});
      }
    });

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
  /// Move a demanda de coluna. Sair de Finalizado com pedido técnico já
  /// emitido pede confirmação.
  Future<bool> moverEtapa(
    BuildContext context,
    String id,
    DemandaEtapa novaEtapa, {
    String? motivoCorrecao,
  }) async {
    final list = List<DemandaModel>.from(demandas);
    final index = list.indexWhere((d) => d.id == id);
    if (index == -1) return false;
    final d = list[index];

    // Finalizar exige conteúdo: ao menos um elemento com ao menos uma posição
    // nos detalhamentos da demanda
    if (novaEtapa == DemandaEtapa.finalizadoLiberado && d.etapa != DemandaEtapa.finalizadoLiberado) {
      final temConteudo = obterDetalhamentosDaDemanda(d)
          .any((det) => det.elementos.any((el) => el.posicoes.isNotEmpty));
      if (!temConteudo) {
        NotificationService.showNegative(
          'Demanda sem detalhamento preenchido',
          'Para finalizar, a demanda precisa de ao menos um elemento com ao menos uma posição.',
          position: NotificationPosition.bottom,
        );
        return false;
      }
    }

    if (d.etapa == DemandaEtapa.finalizadoLiberado && novaEtapa != DemandaEtapa.finalizadoLiberado) {
      final idsDet = obterDetalhamentosDaDemanda(d).map((e) => e.id).toSet();
      final pedidos = BackendClient.pedidosTecnicos.data
          .where((p) => idsDet.contains(p.detalhamentoId) && p.isAberto)
          .toList();
      if (pedidos.isNotEmpty) {
        final continuar = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: Colors.white,
                title: const Text('Demanda com pedido técnico emitido'),
                content: Text(
                  '${pedidos.length} pedido(s) técnico(s) já foram emitidos desta demanda '
                  '(${pedidos.map((p) => p.identificador.isNotEmpty ? p.identificador : 'PT ${p.codigo}').join(', ')}).\n\n'
                  'Os pedidos continuam valendo como foram emitidos. Voltar a demanda para '
                  '"${novaEtapa.label}" mesmo assim?',
                ),
                actions: [
                  OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Não')),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Voltar mesmo assim'),
                  ),
                ],
              ),
            ) ??
            false;
        if (!continuar) return false;
      }
    }

    final atualizada = d.copyWith(
      etapa: novaEtapa,
      motivoCorrecao: motivoCorrecao ?? d.motivoCorrecao,
    );
    list[index] = atualizada;
    demandasStream.add(list);

    return _persistir(() => BackendClient.demandas.atualizar(atualizada));
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

