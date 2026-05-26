import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:acoplan/app/core/client/models/detalhamento_model.dart';
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
      final response = await SupabaseService.client.from(name).select();
      final rows = List<Map<String, dynamic>>.from(response);

      final items = <DetalhamentoModel>[];
      for (final p in rows) {
        final detalhamentoId = p['id'] as String;
        final elementosRaw = List<Map<String, dynamic>>.from(
          await SupabaseService.client.from('elementos').select().eq('detalhamento_id', detalhamentoId),
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
        items.add(DetalhamentoModel.fromSupabaseMap(p, elementosRaw, posicoesRaw));
      }
      dataStream.add(items);
    } catch (e) { log('Supabase Error (Detalhamento.start): $e'); }
  }

  bool _isListen = false;
  Timer? _debounceTimer;
  Future<void> listen() async {
    if (_isListen) return; _isListen = true;
    SupabaseService.client.from(name).stream(primaryKey: ['id']).listen((data) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () { fetch(); });
    });
  }

  // ── Planilha CRUD ────────────────────────────────────────
  /// Cria detalhamento no banco e retorna com ID real (UUID)
  Future<String> criarDetalhamento(DetalhamentoModel model) async {
    final proximoCodigo = data.isEmpty
        ? 1
        : data.map((c) => c.codigo).reduce((a, b) => a > b ? a : b) + 1;
    final m = model.copyWith(codigo: proximoCodigo);
    final inserted = await SupabaseService.client
        .from(name).insert(m.toSupabaseMap()).select().single();
    await fetch();
    return inserted['id'] as String;
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

  Future<void> delete(DetalhamentoModel model) async {
    try {
      final elementosRaw = List<Map<String, dynamic>>.from(
        await SupabaseService.client.from('elementos').select('id').eq('detalhamento_id', model.id),
      );
      final elemIds = elementosRaw.map((e) => e['id'] as String).toList();
      if (elemIds.isNotEmpty) {
        await SupabaseService.client.from('posicoes').delete().inFilter('elemento_id', elemIds);
      }
      await SupabaseService.client.from('elementos').delete().eq('detalhamento_id', model.id);
      await SupabaseService.client.from(name).delete().eq('id', model.id);
      await fetch();
    } catch (e) { log('Supabase Error (Detalhamento.delete): $e'); }
  }

  // ── Elemento CRUD individual ─────────────────────────────
  /// Insere elemento e retorna o UUID gerado
  Future<String> adicionarElemento(ElementoModel elemento, String detalhamentoId) async {
    final map = elemento.toSupabaseMap(detalhamentoId);
    map.remove('id');
    final inserted = await SupabaseService.client
        .from('elementos').insert(map).select().single();
    await fetch();
    return inserted['id'] as String;
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
    await fetch();
    return inserted['id'] as String;
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
