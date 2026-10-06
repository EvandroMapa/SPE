import 'dart:async';
import 'dart:developer';
import 'package:acoplan/app/core/client/models/pedido_tecnico_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PedidoTecnicoSupabaseCollection {
  static final PedidoTecnicoSupabaseCollection _instance =
      PedidoTecnicoSupabaseCollection._();
  PedidoTecnicoSupabaseCollection._() {
    dataStream = AppStream.seed([]);
  }
  factory PedidoTecnicoSupabaseCollection() => _instance;

  late final AppStream<List<PedidoTecnicoModel>> dataStream;
  final String name = 'pedidos_tecnicos';
  List<PedidoTecnicoModel> get data => dataStream.value;
  bool _isStarted = false;

  /// Pedido + elementos numa única consulta.
  static const String _select = '*, pedido_tecnico_elementos(*)';

  Future<void> fetch() async {
    _isStarted = false;
    await start(lock: false);
    _isStarted = true;
  }

  Future<void> start({bool lock = true}) async {
    if (_isStarted && lock) return;
    _isStarted = true;
    try {
      final response = await SupabaseService.client
          .from(name)
          .select(_select)
          .order('codigo', ascending: false);
      dataStream.add(List<Map<String, dynamic>>.from(response)
          .map(PedidoTecnicoModel.fromSupabaseRow)
          .toList());
    } catch (e) {
      log('Supabase Error (PedidoTecnico.start): $e');
    }
  }

  bool _isListen = false;
  Timer? _debounce;
  Future<void> listen() async {
    if (_isListen) return;
    _isListen = true;
    void agendar(PostgresChangePayload _) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), fetch);
    }

    SupabaseService.client
        .channel('spe-pedidos-tecnicos')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: name, callback: agendar)
        .onPostgresChanges(
            event: PostgresChangeEvent.all, schema: 'public', table: 'pedido_tecnico_elementos', callback: agendar)
        .subscribe();
  }

  void _substituirLocal(PedidoTecnicoModel pedido) {
    final list = List<PedidoTecnicoModel>.from(data);
    final idx = list.indexWhere((p) => p.id == pedido.id);
    if (idx != -1) {
      list[idx] = pedido;
    } else {
      list.add(pedido);
      list.sort((a, b) => b.codigo.compareTo(a.codigo));
    }
    dataStream.add(list);
  }

  // ── CRUD ──────────────────────────────────────────────

  /// Cria ou atualiza o pedido e seus elementos numa única transação no banco
  /// (RPC `salvar_pedido_tecnico`). O banco gera código e sequencial do
  /// identificador e valida o saldo de peças — lança exceção se não houver saldo.
  Future<PedidoTecnicoModel> salvar(PedidoTecnicoModel model) async {
    final pedidoMap = model.toSupabaseMap();
    final elementos = model.elementos.map((e) => e.toSupabaseMap('')..remove('pedido_id')).toList();
    final result = await SupabaseService.client.rpc(
      'salvar_pedido_tecnico',
      params: {'p_pedido': pedidoMap, 'p_elementos': elementos},
    );
    final salvo = PedidoTecnicoModel.fromSupabaseRow(Map<String, dynamic>.from(result as Map));
    _substituirLocal(salvo);
    return salvo;
  }

  Future<void> _atualizarStatus(String pedidoId, String status) async {
    await SupabaseService.client.from(name).update({'status': status}).eq('id', pedidoId);
    final atual = data.where((p) => p.id == pedidoId).firstOrNull;
    if (atual != null) _substituirLocal(atual.copyWith(status: status));
  }

  Future<void> cancelar(String pedidoId) => _atualizarStatus(pedidoId, 'cancelado');

  Future<void> reabrir(String pedidoId) => _atualizarStatus(pedidoId, 'aberto');

  /// Exclui o pedido (os elementos vinculados são removidos em cascata pelo banco).
  /// Lança exceção em caso de erro.
  Future<void> delete(PedidoTecnicoModel model) async {
    await SupabaseService.client.from(name).delete().eq('id', model.id);
    dataStream.add(data.where((p) => p.id != model.id).toList());
  }

  /// Retorna mapa: elementoId -> PedidoTecnicoModel (pedido aberto)
  /// Usado para saber quais elementos já estão em algum pedido aberto.
  Map<String, PedidoTecnicoModel> get elementosEmPedidoAberto {
    final mapa = <String, PedidoTecnicoModel>{};
    for (final pedido in data) {
      if (!pedido.isAberto) continue;
      for (final elem in pedido.elementos) {
        mapa['${elem.elementoId}_${elem.elementoNome}'] = pedido;
      }
    }
    return mapa;
  }

  /// Retorna mapa: elementoId -> Lista de PedidoTecnicoModel (pedidos abertos)
  Map<String, List<PedidoTecnicoModel>> get elementosEmPedidosAbertos {
    final mapa = <String, List<PedidoTecnicoModel>>{};
    for (final pedido in data) {
      if (!pedido.isAberto) continue;
      for (final elem in pedido.elementos) {
        final chave = '${elem.elementoId}_${elem.elementoNome}';
        mapa.putIfAbsent(chave, () => []).add(pedido);
      }
    }
    return mapa;
  }

  /// Retorna a quantidade total solicitada de cada elemento considerando
  /// todos os pedidos abertos (exceto o pedido atual, se fornecido).
  Map<String, int> quantidadesAlocadas(String? pedidoIgnoradoId) {
    final mapa = <String, int>{};
    for (final pedido in data) {
      if (!pedido.isAberto) continue;
      if (pedidoIgnoradoId != null && pedido.id == pedidoIgnoradoId) continue;

      for (final elem in pedido.elementos) {
        final chave = '${elem.elementoId}_${elem.elementoNome}';
        mapa[chave] = (mapa[chave] ?? 0) + elem.quantidadeSolicitada;
      }
    }
    return mapa;
  }

  /// Quantidade alocada em pedidos abertos por nome (pai/equivalente) de um elemento.
  Map<String, int> alocadoPorNome(String elementoId) {
    final mapa = <String, int>{};
    for (final pedido in data) {
      if (!pedido.isAberto) continue;
      for (final elem in pedido.elementos) {
        if (elem.elementoId != elementoId) continue;
        mapa[elem.elementoNome] = (mapa[elem.elementoNome] ?? 0) + elem.quantidadeSolicitada;
      }
    }
    return mapa;
  }
}
