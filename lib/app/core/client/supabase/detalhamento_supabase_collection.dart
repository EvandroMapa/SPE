import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:acoplan/app/core/client/models/detalhamento_model.dart';
import 'package:acoplan/app/modules/dashboard/models/demanda_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/supabase_service.dart';

class DetalhamentoSupabaseCollection {
  static final DetalhamentoSupabaseCollection _instance = DetalhamentoSupabaseCollection._();
  DetalhamentoSupabaseCollection._() { dataStream = AppStream.seed([]); }
  factory DetalhamentoSupabaseCollection() => _instance;

  late final AppStream<List<DetalhamentoModel>> dataStream;
  final String name = 'detalhamentos';
  List<DetalhamentoModel> get data => dataStream.value;
  bool _isStarted = false;

  Future<void> fetch() async { _isStarted = false; await start(lock: false); _isStarted = true; }

  Future<void> start({bool lock = true}) async {
    if (_isStarted && lock) return;
    _isStarted = true;
    try {
      final response = await SupabaseService.client.from(name).select().order('codigo', ascending: false);
      final rows = List<Map<String, dynamic>>.from(response);

      final items = await Future.wait(rows.map((p) async {
        final detalhamentoId = p['id'] as String;
        final elementosRaw = List<Map<String, dynamic>>.from(
          await SupabaseService.client
              .from('elementos')
              .select()
              .eq('detalhamento_id', detalhamentoId)
              .order('created_at', ascending: true),
        );
        final elementoIds = elementosRaw.map((e) => e['id'] as String).toList();
        List<Map<String, dynamic>> posicoesRaw = [];
        if (elementoIds.isNotEmpty) {
          try {
            posicoesRaw = List<Map<String, dynamic>>.from(
              await SupabaseService.client
                  .from('posicoes')
                  .select()
                  .inFilter('elemento_id', elementoIds)
                  .order('created_at', ascending: true),
            );
          } catch (_) {
            posicoesRaw = List<Map<String, dynamic>>.from(
              await SupabaseService.client
                  .from('posicoes')
                  .select()
                  .inFilter('elemento_id', elementoIds),
            );
          }
        }
        return DetalhamentoModel.fromSupabaseMap(p, elementosRaw, posicoesRaw);
      }));
      final seenIds = <String>{};
      final uniqueItems = items.where((e) => seenIds.add(e.id)).toList();
      dataStream.add(uniqueItems);
    } catch (e) { log('Supabase Error (Detalhamento.start): $e'); }
  }

  bool _isListen = false;
  Timer? _debounceTimer;
  /// Pausa o fetch automático do Realtime por um período curto após saves locais
  DateTime _ultimoSaveLocal = DateTime.fromMillisecondsSinceEpoch(0);
  void pausarFetch() { _ultimoSaveLocal = DateTime.now(); }

  Future<void> listen() async {
    if (_isListen) return; _isListen = true;
    SupabaseService.client.from(name).stream(primaryKey: ['id']).listen((data) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        // Ignora fetch se houve save local nos últimos 3 segundos
        if (DateTime.now().difference(_ultimoSaveLocal).inMilliseconds < 3000) return;
        fetch();
      });
    });
  }

  // ── Planilha CRUD ────────────────────────────────────────
  /// Cria detalhamento no banco e retorna com ID real (UUID)
  Future<String> criarDetalhamento(DetalhamentoModel model) async {
    int proximoCodigo = 1;
    try {
      final res = await SupabaseService.client
          .from(name)
          .select('codigo')
          .order('codigo', ascending: false)
          .limit(1);
      final maxBanco = res.isNotEmpty ? (int.tryParse(res.first['codigo']?.toString() ?? '0') ?? 0) : 0;
      final maxMemoria = data.isEmpty
          ? 0
          : data.map((c) => c.codigo).reduce((a, b) => a > b ? a : b);
      proximoCodigo = (maxBanco > maxMemoria ? maxBanco : maxMemoria) + 1;
    } catch (_) {
      proximoCodigo = data.isEmpty
          ? 1
          : data.map((c) => c.codigo).reduce((a, b) => a > b ? a : b) + 1;
    }
    final m = model.copyWith(codigo: proximoCodigo);
    final inserted = await SupabaseService.client
        .from(name).insert(m.toSupabaseMap()).select().single();
    final newId = inserted['id'] as String;
    unawaited(fetch());
    return newId;
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
    await fetch();
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
      await fetch();
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
      await fetch();
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
      await fetch();
    }
  }

  Future<void> delete(DetalhamentoModel model) async {
    // 1. Atualização otimista imediata na memória e UI
    final listaAtualizada = data.where((d) => d.id != model.id).toList();
    dataStream.add(listaAtualizada);

    try {
      // 2. Desvincula qualquer demanda que aponte para este detalhamento
      try {
        await SupabaseService.client
            .from('demandas')
            .update({'detalhamento_id': null})
            .eq('detalhamento_id', model.id);
      } catch (_) {}

      // 3. Exclui posições dos elementos
      final elementosRaw = List<Map<String, dynamic>>.from(
        await SupabaseService.client.from('elementos').select('id').eq('detalhamento_id', model.id),
      );
      final elemIds = elementosRaw.map((e) => e['id'] as String).toList();
      if (elemIds.isNotEmpty) {
        await SupabaseService.client.from('posicoes').delete().inFilter('elemento_id', elemIds);
      }

      // 4. Exclui elementos e detalhamento
      await SupabaseService.client.from('elementos').delete().eq('detalhamento_id', model.id);
      await SupabaseService.client.from(name).delete().eq('id', model.id);
    } catch (e) {
      log('Supabase Error (Detalhamento.delete): $e');
      // Em caso de erro na exclusão remota, restaura o estado fazendo fetch
      await fetch();
      rethrow;
    }
  }

  // ── Elemento CRUD individual ─────────────────────────────
  /// Insere elemento e retorna o UUID gerado
  Future<String> adicionarElemento(ElementoModel elemento, String detalhamentoId) async {
    final map = elemento.toSupabaseMap(detalhamentoId);
    map.remove('id');
    final inserted = await SupabaseService.client
        .from('elementos').insert(map).select().single();
    final newId = inserted['id'] as String;
    unawaited(fetch());
    return newId;
  }

  Future<void> excluirElemento(String elementoId) async {
    await SupabaseService.client.from('posicoes').delete().eq('elemento_id', elementoId);
    await SupabaseService.client.from('elementos').delete().eq('id', elementoId);
    await fetch();
  }

  Future<void> atualizarElemento(ElementoModel elemento, String detalhamentoId) async {
    final map = elemento.toSupabaseMap(detalhamentoId);
    map.remove('id');
    await SupabaseService.client.from('elementos').update(map).eq('id', elemento.id);
    await fetch();
  }

  // ── Posição CRUD individual ──────────────────────────────
  /// Insere posição e retorna o UUID gerado
  Future<String> adicionarPosicao(PosicaoModel posicao, String elementoId) async {
    final map = posicao.toSupabaseMap(elementoId);
    map.remove('id');
    final inserted = await SupabaseService.client
        .from('posicoes').insert(map).select().single();
    final newId = inserted['id'] as String;
    unawaited(fetch());
    return newId;
  }

  /// Atualiza apenas a coluna 'ordem' de múltiplas posições (batch leve)
  Future<void> atualizarOrdemPosicoes(Map<String, int> ordemPorId) async {
    for (final entry in ordemPorId.entries) {
      final result = await SupabaseService.client
          .from('posicoes')
          .update({'ordem': entry.value})
          .eq('id', entry.key)
          .select('id, ordem')
          .maybeSingle();
      debugPrint('[atualizarOrdem] id=${entry.key.substring(0, 8)}... ordem=${entry.value} → result=$result');
    }
  }

  Future<void> atualizarPosicao(PosicaoModel posicao, String elementoId) async {
    final map = posicao.toSupabaseMap(elementoId);
    await SupabaseService.client.from('posicoes').update(map).eq('id', posicao.id);
    await fetch();
  }

  Future<void> excluirPosicao(String posicaoId) async {
    await SupabaseService.client.from('posicoes').delete().eq('id', posicaoId);
    await fetch();
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

  Future<void> atualizarPesoTotal(String detalhamentoId, double pesoTotal) async {
    await SupabaseService.client
        .from('detalhamentos')
        .update({'peso_total': pesoTotal})
        .eq('id', detalhamentoId);
    await fetch();
  }

  Future<void> atualizarPesoElemento(String elementoId, double pesoTotal) async {
    await SupabaseService.client
        .from('elementos')
        .update({'peso_total': pesoTotal})
        .eq('id', elementoId);
  }
}
