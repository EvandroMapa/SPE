import 'dart:developer';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/supabase_service.dart';
import 'package:acoplan/app/modules/dashboard/models/demanda_model.dart';

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
  Future<void> listen() async {
    if (_isListen) return;
    _isListen = true;
    try {
      SupabaseService.client
          .from(name)
          .stream(primaryKey: ['id']).listen((_) => fetch(), onError: (e) {
        log('Supabase Realtime Notice (Demandas): $e');
      });
    } catch (e) {
      log('Supabase Listen Error (Demandas): $e');
    }
  }

  // ── CRUD ──────────────────────────────────────────────

  Future<DemandaModel?> criar(DemandaModel model) async {
    try {
      int proximoCodigo = 1;
      if (data.isNotEmpty) {
        proximoCodigo =
            data.map((d) => d.codigo).reduce((a, b) => a > b ? a : b) + 1;
      }
      final m = model.copyWith(codigo: proximoCodigo);
      final mapInsert = m.toSupabaseMap();
      final inserted = await SupabaseService.client
          .from(name)
          .insert(mapInsert)
          .select()
          .single();
      final novo = DemandaModel.fromSupabaseMap(inserted);
      await fetch();
      return novo;
    } catch (e) {
      log('Supabase Error (Demanda.criar): $e');
      // Fallback local caso tabela não exista no banco ainda
      final list = List<DemandaModel>.from(data);
      final proximoCodigo = list.isEmpty
          ? 1
          : list.map((d) => d.codigo).reduce((a, b) => a > b ? a : b) + 1;
      final novo = model.copyWith(codigo: proximoCodigo);
      list.add(novo);
      dataStream.add(list);
      return novo;
    }
  }

  Future<void> atualizar(DemandaModel model) async {
    try {
      await SupabaseService.client
          .from(name)
          .update(model.toSupabaseMap())
          .eq('id', model.id);
      await fetch();
    } catch (e) {
      log('Supabase Error (Demanda.atualizar): $e');
      final list = List<DemandaModel>.from(data);
      final idx = list.indexWhere((d) => d.id == model.id);
      if (idx != -1) {
        list[idx] = model;
        dataStream.add(list);
      }
    }
  }

  Future<void> delete(String id) async {
    try {
      await SupabaseService.client.from(name).delete().eq('id', id);
      await fetch();
    } catch (e) {
      log('Supabase Error (Demanda.delete): $e');
      final list = List<DemandaModel>.from(data)..removeWhere((d) => d.id == id);
      dataStream.add(list);
    }
  }
}
