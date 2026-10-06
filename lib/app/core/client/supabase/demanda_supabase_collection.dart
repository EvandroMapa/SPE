import 'dart:async';
import 'dart:developer';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/supabase_service.dart';
import 'package:acoplan/app/modules/dashboard/models/demanda_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DemandaSupabaseCollection {
  static final DemandaSupabaseCollection _instance =
      DemandaSupabaseCollection._();
  DemandaSupabaseCollection._() {
    dataStream = AppStream.seed([]);
  }
  factory DemandaSupabaseCollection() => _instance;

  late final AppStream<List<DemandaModel>> dataStream;
  final String name = 'demandas';
  List<DemandaModel> get data => dataStream.value;
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
          .order('ordem', ascending: true);
      final rows = List<Map<String, dynamic>>.from(response);
      final items = rows.map((r) => DemandaModel.fromSupabaseMap(r)).toList();
      dataStream.add(items);
    } catch (e) {
      log('Supabase Notice (Demanda.start): $e');
    }
  }

  bool _isListen = false;
  Timer? _debounce;
  Future<void> listen() async {
    if (_isListen) return;
    _isListen = true;
    SupabaseService.client
        .channel('spe-demandas')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: name,
          callback: (_) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 500), fetch);
          },
        )
        .subscribe();
  }

  void _substituirLocal(DemandaModel model) {
    final list = List<DemandaModel>.from(data);
    final idx = list.indexWhere((d) => d.id == model.id);
    if (idx != -1) {
      list[idx] = model;
    } else {
      list.add(model);
    }
    dataStream.add(list);
  }

  // ── CRUD ──────────────────────────────────────────────
  // Todos os métodos lançam exceção em caso de erro — quem chama decide como
  // avisar o usuário (nada de "sucesso" local quando o banco recusou).

  /// Cria a demanda. O código sequencial é gerado pelo banco.
  Future<DemandaModel> criar(DemandaModel model) async {
    final inserted = await SupabaseService.client
        .from(name)
        .insert(model.copyWith(codigo: 0).toSupabaseMap())
        .select()
        .single();
    final novo = DemandaModel.fromSupabaseMap(inserted);
    _substituirLocal(novo);
    return novo;
  }

  Future<void> atualizar(DemandaModel model) async {
    await SupabaseService.client
        .from(name)
        .update(model.toSupabaseMap())
        .eq('id', model.id);
    _substituirLocal(model);
  }

  /// Atualiza apenas a ordem de várias demandas (em paralelo, sem recarregar tudo).
  Future<void> atualizarOrdens(Map<String, int> ordemPorId) async {
    await Future.wait(ordemPorId.entries.map((e) =>
        SupabaseService.client.from(name).update({'ordem': e.value}).eq('id', e.key)));
    dataStream.add(data
        .map((d) => ordemPorId.containsKey(d.id) ? d.copyWith(ordem: ordemPorId[d.id]) : d)
        .toList());
  }

  Future<void> delete(String id) async {
    await SupabaseService.client.from(name).delete().eq('id', id);
    dataStream.add(data.where((d) => d.id != id).toList());
  }
}
