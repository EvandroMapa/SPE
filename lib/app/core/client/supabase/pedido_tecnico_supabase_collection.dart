import 'dart:developer';
import 'package:acoplan/app/core/client/models/pedido_tecnico_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/supabase_service.dart';

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
          .select()
          .order('codigo', ascending: false);
      final pedidos = List<Map<String, dynamic>>.from(response);

      final items = <PedidoTecnicoModel>[];
      for (final p in pedidos) {
        final pedidoId = p['id'] as String;
        final elementosRaw = List<Map<String, dynamic>>.from(
          await SupabaseService.client
              .from('pedido_tecnico_elementos')
              .select()
              .eq('pedido_id', pedidoId),
        );
        items.add(PedidoTecnicoModel.fromSupabaseMap(p, elementosRaw));
      }
      dataStream.add(items);
    } catch (e) {
      log('Supabase Error (PedidoTecnico.start): $e');
    }
  }

  bool _isListen = false;
  Future<void> listen() async {
    if (_isListen) return;
    _isListen = true;
    SupabaseService.client
        .from(name)
        .stream(primaryKey: ['id']).listen((_) => fetch());
  }

  // ── CRUD ──────────────────────────────────────────────

  /// Cria o pedido e seus vínculos de elementos. Retorna o UUID gerado.
  Future<String> criar(PedidoTecnicoModel model) async {
    final proximoCodigo = data.isEmpty
        ? 1
        : data.map((p) => p.codigo).reduce((a, b) => a > b ? a : b) + 1;
    final m = model.copyWith(codigo: proximoCodigo);
    final inserted = await SupabaseService.client
        .from(name)
        .insert(m.toSupabaseMap())
        .select()
        .single();
    final pedidoId = inserted['id'] as String;

    // Inserir elementos vinculados
    for (final elem in model.elementos) {
      await SupabaseService.client
          .from('pedido_tecnico_elementos')
          .insert(elem.toSupabaseMap(pedidoId));
    }
    await fetch();
    return pedidoId;
  }

  /// Atualiza dados gerais do pedido (sem alterar elementos)
  Future<void> atualizar(PedidoTecnicoModel model) async {
    await SupabaseService.client
        .from(name)
        .update(model.toSupabaseMap())
        .eq('id', model.id);
    await fetch();
  }

  /// Remove todos os elementos e reinserindo os novos
  Future<void> atualizarElementos(
      String pedidoId, List<PedidoTecnicoElementoModel> elementos) async {
    await SupabaseService.client
        .from('pedido_tecnico_elementos')
        .delete()
        .eq('pedido_id', pedidoId);
    for (final elem in elementos) {
      await SupabaseService.client
          .from('pedido_tecnico_elementos')
          .insert(elem.toSupabaseMap(pedidoId));
    }
    await fetch();
  }

  Future<void> cancelar(String pedidoId) async {
    await SupabaseService.client
        .from(name)
        .update({'status': 'cancelado'})
        .eq('id', pedidoId);
    await fetch();
  }

  Future<void> reabrir(String pedidoId) async {
    await SupabaseService.client
        .from(name)
        .update({'status': 'aberto'})
        .eq('id', pedidoId);
    await fetch();
  }

  Future<void> delete(PedidoTecnicoModel model) async {
    try {
      await SupabaseService.client
          .from('pedido_tecnico_elementos')
          .delete()
          .eq('pedido_id', model.id);
      await SupabaseService.client.from(name).delete().eq('id', model.id);
      await fetch();
    } catch (e) {
      log('Supabase Error (PedidoTecnico.delete): $e');
    }
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
}
