import 'dart:async';
import 'dart:developer';
import 'package:acoplan/app/core/calculo/calculo_aco.dart';
import 'package:acoplan/app/core/client/models/detalhamento_model.dart';
import 'package:acoplan/app/core/client/supabase/bitola_supabase_collection.dart';
import 'package:acoplan/app/modules/dashboard/models/demanda_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DetalhamentoSupabaseCollection {
  static final DetalhamentoSupabaseCollection _instance = DetalhamentoSupabaseCollection._();
  DetalhamentoSupabaseCollection._() { dataStream = AppStream.seed([]); }
  factory DetalhamentoSupabaseCollection() => _instance;

  late final AppStream<List<DetalhamentoModel>> dataStream;
  final String name = 'detalhamentos';
  List<DetalhamentoModel> get data => dataStream.value;
  bool _isStarted = false;

  /// Detalhamento + elementos + posições numa única consulta.
  static const String _select = '*, elementos(*, posicoes(*))';

  Future<void> fetch() async { _isStarted = false; await start(lock: false); _isStarted = true; }

  Future<void> start({bool lock = true}) async {
    if (_isStarted && lock) return;
    _isStarted = true;
    try {
      final response = await SupabaseService.client.from(name).select(_select).order('codigo', ascending: false);
      final items = List<Map<String, dynamic>>.from(response).map(_fromRow).toList();
      dataStream.add(items);
    } catch (e) { log('Supabase Error (Detalhamento.start): $e'); }
  }

  /// Recarrega apenas um detalhamento (1 requisição) e atualiza a lista em memória.
  Future<void> recarregar(String detalhamentoId) async {
    try {
      final row = await SupabaseService.client.from(name).select(_select).eq('id', detalhamentoId).maybeSingle();
      final list = List<DetalhamentoModel>.from(data);
      final idx = list.indexWhere((d) => d.id == detalhamentoId);
      if (row == null) {
        if (idx != -1) list.removeAt(idx);
      } else {
        final model = _fromRow(row);
        if (idx != -1) {
          list[idx] = model;
        } else {
          list.add(model);
          list.sort((a, b) => b.codigo.compareTo(a.codigo));
        }
      }
      dataStream.add(list);
    } catch (e) {
      log('Supabase Error (Detalhamento.recarregar): $e');
    }
  }

  static int _porCriacao(Map<String, dynamic> a, Map<String, dynamic> b) {
    final da = DateTime.tryParse(a['created_at']?.toString() ?? '');
    final db = DateTime.tryParse(b['created_at']?.toString() ?? '');
    if (da == null || db == null) return 0;
    return da.compareTo(db);
  }

  /// Converte a linha (com elementos/posições aninhados) no model e recalcula
  /// os pesos a partir das posições — `peso_total` gravado no banco pode estar
  /// desatualizado (ex: plugin do AutoCAD grava valores de controle).
  DetalhamentoModel _fromRow(Map<String, dynamic> row) {
    final elementosRaw = List<Map<String, dynamic>>.from(row['elementos'] as List? ?? const [])
      ..sort(_porCriacao);
    final posicoesRaw = elementosRaw
        .expand((e) => List<Map<String, dynamic>>.from(e['posicoes'] as List? ?? const []))
        .toList()
      ..sort(_porCriacao);
    final det = DetalhamentoModel.fromSupabaseMap(row, elementosRaw, posicoesRaw);

    final bitolas = BitolaSupabaseCollection().data;
    final elementos = det.elementos
        .map((e) => ElementoModel(
              id: e.id,
              nome: e.nome,
              quantidade: e.quantidade,
              pesoTotal: CalculoAco.pesoTotalElemento(e, bitolas),
              posicoes: e.posicoes,
              elementosEquivalentes: e.elementosEquivalentes,
            ))
        .toList();
    return det.copyWith(
      elementos: elementos,
      pesoTotal: elementos.fold<double>(0, (s, e) => s + e.pesoTotal),
    );
  }

  // ── Realtime ─────────────────────────────────────────────
  bool _isListen = false;
  Timer? _debounceTimer;
  final Set<String> _pendentes = {};
  bool _recarregarTudo = false;

  /// Ignora eventos do Realtime por um período curto após saves locais
  /// (o próprio save já recarrega o detalhamento).
  DateTime _ultimoSaveLocal = DateTime.fromMillisecondsSinceEpoch(0);
  void pausarFetch() { _ultimoSaveLocal = DateTime.now(); }

  String? _detalhamentoDoElemento(String elementoId) {
    for (final d in data) {
      if (d.elementos.any((e) => e.id == elementoId)) return d.id;
    }
    return null;
  }

  String? _detalhamentoDaPosicao(String posicaoId) {
    for (final d in data) {
      for (final e in d.elementos) {
        if (e.posicoes.any((p) => p.id == posicaoId)) return d.id;
      }
    }
    return null;
  }

  void _agendar(String? detalhamentoId) {
    if (detalhamentoId == null || detalhamentoId.isEmpty) {
      _recarregarTudo = true;
    } else {
      _pendentes.add(detalhamentoId);
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (DateTime.now().difference(_ultimoSaveLocal).inMilliseconds < 3000) {
        _pendentes.clear();
        _recarregarTudo = false;
        return;
      }
      final ids = Set<String>.from(_pendentes);
      final tudo = _recarregarTudo || ids.length > 10;
      _pendentes.clear();
      _recarregarTudo = false;
      if (tudo) {
        fetch();
      } else {
        for (final id in ids) {
          recarregar(id);
        }
      }
    });
  }

  Future<void> listen() async {
    if (_isListen) return; _isListen = true;
    String? texto(Map<String, dynamic> m, String k) {
      final v = m[k]?.toString();
      return (v == null || v.isEmpty) ? null : v;
    }

    SupabaseService.client
        .channel('spe-detalhamentos')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: name,
          callback: (p) => _agendar(texto(p.newRecord, 'id') ?? texto(p.oldRecord, 'id')),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'elementos',
          callback: (p) {
            final det = texto(p.newRecord, 'detalhamento_id');
            if (det != null) return _agendar(det);
            final elemId = texto(p.oldRecord, 'id');
            if (elemId != null) {
              final dono = _detalhamentoDoElemento(elemId);
              if (dono != null) _agendar(dono);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'posicoes',
          callback: (p) {
            final elemId = texto(p.newRecord, 'elemento_id');
            if (elemId != null) {
              // Elemento recém-criado por outro cliente ainda não está em memória
              return _agendar(_detalhamentoDoElemento(elemId));
            }
            final posId = texto(p.oldRecord, 'id');
            if (posId != null) {
              final dono = _detalhamentoDaPosicao(posId);
              if (dono != null) _agendar(dono);
            }
          },
        )
        .subscribe();
  }

  // ── Planilha CRUD ────────────────────────────────────────
  /// Cria detalhamento no banco e retorna com ID real (UUID).
  /// O código sequencial é gerado pelo banco.
  Future<String> criarDetalhamento(DetalhamentoModel model) async {
    final inserted = await SupabaseService.client
        .from(name).insert(model.copyWith(codigo: 0).toSupabaseInsertMap()).select('id').single();
    final newId = inserted['id'] as String;
    await recarregar(newId);
    return newId;
  }

  // ── Ciclo Demanda → Projeto (regras no banco) ─────────────
  /// Orçamento aprovado pelo cliente vira projeto.
  Future<void> converterOrcamentoEmProjeto(String detalhamentoId) async {
    await SupabaseService.client.rpc('converter_orcamento_em_projeto',
        params: {'p_detalhamento_id': detalhamentoId});
    await recarregar(detalhamentoId);
  }

  /// Cliente desistiu: cancela o projeto e os pedidos técnicos abertos dele.
  /// Retorna quantos pedidos foram cancelados.
  Future<int> cancelarProjeto(String detalhamentoId, String motivo) async {
    final n = await SupabaseService.client.rpc('cancelar_projeto',
        params: {'p_detalhamento_id': detalhamentoId, 'p_motivo': motivo});
    await recarregar(detalhamentoId);
    return (n as num?)?.toInt() ?? 0;
  }

  Future<bool> estaVinculadoAPedido(String detalhamentoId) async {
    try {
      final res = await SupabaseService.client
          .from('pedido_tecnico_elementos')
          .select('elemento_id, elementos!inner(detalhamento_id)')
          .eq('elementos.detalhamento_id', detalhamentoId)
          .limit(1);
      return res.isNotEmpty;
    } catch (e) {
      log('Supabase Error (Detalhamento.estaVinculado): $e');
      return false;
    }
  }

  Future<void> atualizarDetalhamento(DetalhamentoModel model) async {
    await SupabaseService.client.from(name).update(model.toSupabaseMap()).eq('id', model.id);
    await recarregar(model.id);
  }

  Future<void> atualizarEtapaKanban(String detalhamentoId, String novaEtapa) async {
    final list = List<DetalhamentoModel>.from(data);
    final idx = list.indexWhere((d) => d.id == detalhamentoId);
    if (idx != -1) {
      final etapaEnum = DemandaEtapa.values.firstWhere(
        (e) => e.name == novaEtapa,
        orElse: () => list[idx].etapaKanban,
      );
      list[idx] = list[idx].copyWith(etapaKanban: etapaEnum);
      dataStream.add(list);
    }

    try {
      await SupabaseService.client
          .from(name)
          .update({'etapa_kanban': novaEtapa})
          .eq('id', detalhamentoId);
    } catch (e) {
      log('Supabase Error (atualizarEtapaKanban): $e');
      await recarregar(detalhamentoId);
    }
  }

  Future<void> arquivarDetalhamento(String detalhamentoId) async {
    final list = List<DetalhamentoModel>.from(data);
    final idx = list.indexWhere((d) => d.id == detalhamentoId);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(isArquivado: true);
      dataStream.add(list);
    }

    try {
      await SupabaseService.client
          .from(name)
          .update({'is_arquivado': true})
          .eq('id', detalhamentoId);
    } catch (e) {
      log('Supabase Error (arquivarDetalhamento): $e');
      await recarregar(detalhamentoId);
    }
  }

  /// Desarquiva o projeto mantendo a situação (não mexe na etapa).
  Future<void> desarquivarProjeto(String detalhamentoId) async {
    final list = List<DetalhamentoModel>.from(data);
    final idx = list.indexWhere((d) => d.id == detalhamentoId);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(isArquivado: false);
      dataStream.add(list);
    }
    try {
      await SupabaseService.client.from(name).update({'is_arquivado': false}).eq('id', detalhamentoId);
    } catch (e) {
      log('Supabase Error (desarquivarProjeto): $e');
      await recarregar(detalhamentoId);
    }
  }

  Future<void> desarquivarDetalhamento(String detalhamentoId) async {
    final list = List<DetalhamentoModel>.from(data);
    final idx = list.indexWhere((d) => d.id == detalhamentoId);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(
        isArquivado: false,
        etapaKanban: DemandaEtapa.finalizadoLiberado,
      );
      dataStream.add(list);
    }

    try {
      await SupabaseService.client
          .from(name)
          .update({
            'is_arquivado': false,
            'etapa_kanban': 'finalizadoLiberado',
          })
          .eq('id', detalhamentoId);
    } catch (e) {
      log('Supabase Error (desarquivarDetalhamento): $e');
      await recarregar(detalhamentoId);
    }
  }

  /// Exclui o detalhamento. Elementos e posições são removidos pelo banco
  /// (ON DELETE CASCADE) e demandas vinculadas são desvinculadas (SET NULL),
  /// tudo numa única operação atômica.
  Future<void> delete(DetalhamentoModel model) async {
    // Atualização otimista imediata na memória e UI
    dataStream.add(data.where((d) => d.id != model.id).toList());
    try {
      await SupabaseService.client.from(name).delete().eq('id', model.id);
    } catch (e) {
      log('Supabase Error (Detalhamento.delete): $e');
      await recarregar(model.id);
      rethrow;
    }
  }

  // ── Elemento CRUD individual ─────────────────────────────
  /// Insere elemento e retorna o UUID gerado
  Future<String> adicionarElemento(ElementoModel elemento, String detalhamentoId) async {
    final map = elemento.toSupabaseMap(detalhamentoId);
    map.remove('id');
    final inserted = await SupabaseService.client
        .from('elementos').insert(map).select('id').single();
    final newId = inserted['id'] as String;
    await recarregar(detalhamentoId);
    return newId;
  }

  /// Exclui o elemento (posições são removidas em cascata pelo banco).
  Future<void> excluirElemento(String elementoId) async {
    final detId = _detalhamentoDoElemento(elementoId);
    await SupabaseService.client.from('elementos').delete().eq('id', elementoId);
    if (detId != null) await recarregar(detId);
  }

  Future<void> atualizarElemento(ElementoModel elemento, String detalhamentoId) async {
    final map = elemento.toSupabaseMap(detalhamentoId);
    map.remove('id');
    await SupabaseService.client.from('elementos').update(map).eq('id', elemento.id);
    await recarregar(detalhamentoId);
  }

  // ── Posição CRUD individual ──────────────────────────────
  Future<String?> _detalhamentoDoElementoNoBanco(String elementoId) async {
    final emMemoria = _detalhamentoDoElemento(elementoId);
    if (emMemoria != null) return emMemoria;
    final row = await SupabaseService.client
        .from('elementos').select('detalhamento_id').eq('id', elementoId).maybeSingle();
    return row?['detalhamento_id']?.toString();
  }

  /// Insere posição e retorna o UUID gerado
  Future<String> adicionarPosicao(PosicaoModel posicao, String elementoId) async {
    final map = posicao.toSupabaseMap(elementoId);
    map.remove('id');
    final inserted = await SupabaseService.client
        .from('posicoes').insert(map).select('id').single();
    final newId = inserted['id'] as String;
    final detId = await _detalhamentoDoElementoNoBanco(elementoId);
    if (detId != null) await recarregar(detId);
    return newId;
  }

  /// Atualiza apenas a coluna 'ordem' de múltiplas posições (em paralelo)
  Future<void> atualizarOrdemPosicoes(Map<String, int> ordemPorId) async {
    await Future.wait(ordemPorId.entries.map((entry) => SupabaseService.client
        .from('posicoes')
        .update({'ordem': entry.value})
        .eq('id', entry.key)));
  }

  Future<void> atualizarPosicao(PosicaoModel posicao, String elementoId) async {
    final map = posicao.toSupabaseMap(elementoId);
    await SupabaseService.client.from('posicoes').update(map).eq('id', posicao.id);
    final detId = await _detalhamentoDoElementoNoBanco(elementoId);
    if (detId != null) await recarregar(detId);
  }

  Future<void> excluirPosicao(String posicaoId) async {
    final detId = _detalhamentoDaPosicao(posicaoId);
    await SupabaseService.client.from('posicoes').delete().eq('id', posicaoId);
    if (detId != null) await recarregar(detId);
  }

  // ── Métodos batch (mantidos para compatibilidade) ────────
  Future<DetalhamentoModel?> add(DetalhamentoModel model) async {
    final id = await criarDetalhamento(model);
    return model.copyWith(id: id);
  }

  Future<DetalhamentoModel?> update(DetalhamentoModel model) async {
    await atualizarDetalhamento(model);
    return model;
  }

  /// Grava o peso calculado (para consumidores externos). O app sempre
  /// recalcula o peso a partir das posições, então não precisa recarregar.
  Future<void> atualizarPesoTotal(String detalhamentoId, double pesoTotal) async {
    await SupabaseService.client
        .from('detalhamentos')
        .update({'peso_total': pesoTotal})
        .eq('id', detalhamentoId);
  }

  Future<void> atualizarPesoElemento(String elementoId, double pesoTotal) async {
    await SupabaseService.client
        .from('elementos')
        .update({'peso_total': pesoTotal})
        .eq('id', elementoId);
  }
}
