import 'dart:developer';
import 'package:acoplan/app/core/client/models/planilha_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/supabase_service.dart';

class PlanilhaSupabaseCollection {
  static final PlanilhaSupabaseCollection _instance = PlanilhaSupabaseCollection._();
  PlanilhaSupabaseCollection._() { dataStream = AppStream.seed([]); }
  factory PlanilhaSupabaseCollection() => _instance;

  late final AppStream<List<PlanilhaModel>> dataStream;
  final String name = 'planilhas';
  List<PlanilhaModel> get data => dataStream.value;
  bool _isStarted = false;

  Future<void> fetch() async { _isStarted = false; await start(lock: false); _isStarted = true; }

  Future<void> start({bool lock = true}) async {
    if (_isStarted && lock) return;
    _isStarted = true;
    try {
      final response = await SupabaseService.client.from(name).select();
      final planilhas = List<Map<String, dynamic>>.from(response);

      final items = <PlanilhaModel>[];
      for (final p in planilhas) {
        final planilhaId = p['id'] as String;
        final elementosRaw = List<Map<String, dynamic>>.from(
          await SupabaseService.client.from('elementos').select().eq('planilha_id', planilhaId),
        );
        final elementoIds = elementosRaw.map((e) => e['id'] as String).toList();
        List<Map<String, dynamic>> posicoesRaw = [];
        if (elementoIds.isNotEmpty) {
          posicoesRaw = List<Map<String, dynamic>>.from(
            await SupabaseService.client.from('posicoes').select().inFilter('elemento_id', elementoIds),
          );
        }
        items.add(PlanilhaModel.fromSupabaseMap(p, elementosRaw, posicoesRaw));
      }
      dataStream.add(items);
    } catch (e) { log('Supabase Error (Planilha.start): $e'); }
  }

  bool _isListen = false;
  Future<void> listen() async {
    if (_isListen) return; _isListen = true;
    SupabaseService.client.from(name).stream(primaryKey: ['id']).listen((data) { fetch(); });
  }

  // ── Planilha CRUD ────────────────────────────────────────
  /// Cria planilha no banco e retorna com ID real (UUID)
  Future<String> criarPlanilha(PlanilhaModel model) async {
    final proximoCodigo = data.isEmpty
        ? 1
        : data.map((c) => c.codigo).reduce((a, b) => a > b ? a : b) + 1;
    final m = model.copyWith(codigo: proximoCodigo);
    final inserted = await SupabaseService.client
        .from(name).insert(m.toSupabaseMap()).select().single();
    await fetch();
    return inserted['id'] as String;
  }

  Future<bool> estaVinculadaAPedido(String planilhaId) async {
    try {
      final res = await SupabaseService.client
          .from('pedido_tecnico_elementos')
          .select('elemento_id, elementos!inner(planilha_id)')
          .eq('elementos.planilha_id', planilhaId)
          .limit(1);
      return res.isNotEmpty;
    } catch (e) {
      log('Supabase Error (Planilha.estaVinculada): $e');
      return false;
    }
  }

  Future<void> atualizarPlanilha(PlanilhaModel model) async {
    await SupabaseService.client.from(name).update(model.toSupabaseMap()).eq('id', model.id);
    await fetch();
  }

  Future<void> delete(PlanilhaModel model) async {
    try {
      final elementosRaw = List<Map<String, dynamic>>.from(
        await SupabaseService.client.from('elementos').select('id').eq('planilha_id', model.id),
      );
      final elemIds = elementosRaw.map((e) => e['id'] as String).toList();
      if (elemIds.isNotEmpty) {
        await SupabaseService.client.from('posicoes').delete().inFilter('elemento_id', elemIds);
      }
      await SupabaseService.client.from('elementos').delete().eq('planilha_id', model.id);
      await SupabaseService.client.from(name).delete().eq('id', model.id);
      await fetch();
    } catch (e) { log('Supabase Error (Planilha.delete): $e'); }
  }

  // ── Elemento CRUD individual ─────────────────────────────
  /// Insere elemento e retorna o UUID gerado
  Future<String> adicionarElemento(ElementoModel elemento, String planilhaId) async {
    final map = elemento.toSupabaseMap(planilhaId);
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

  Future<void> atualizarElemento(ElementoModel elemento, String planilhaId) async {
    final map = elemento.toSupabaseMap(planilhaId);
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

  Future<void> atualizarPosicao(PosicaoModel posicao, String elementoId) async {
    final map = posicao.toSupabaseMap(elementoId);
    await SupabaseService.client.from('posicoes').update(map).eq('id', posicao.id);
  }

  Future<void> excluirPosicao(String posicaoId) async {
    await SupabaseService.client.from('posicoes').delete().eq('id', posicaoId);
    await fetch();
  }

  // ── Métodos batch (mantidos para compatibilidade) ────────
  Future<PlanilhaModel?> add(PlanilhaModel model) async {
    final id = await criarPlanilha(model);
    return model.copyWith(id: id);
  }

  Future<PlanilhaModel?> update(PlanilhaModel model) async {
    await atualizarPlanilha(model);
    return model;
  }

  Future<void> atualizarPesoTotal(String planilhaId, double pesoTotal) async {
    await SupabaseService.client
        .from('planilhas')
        .update({'peso_total': pesoTotal})
        .eq('id', planilhaId);
    await fetch();
  }

  Future<void> atualizarPesoElemento(String elementoId, double pesoTotal) async {
    await SupabaseService.client
        .from('elementos')
        .update({'peso_total': pesoTotal})
        .eq('id', elementoId);
  }
}
