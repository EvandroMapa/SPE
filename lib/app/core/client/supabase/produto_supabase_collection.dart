import 'dart:developer';
import 'package:acoplan/app/core/client/models/produto_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/supabase_service.dart';

class ProdutoSupabaseCollection {
  static final ProdutoSupabaseCollection _instance = ProdutoSupabaseCollection._();
  ProdutoSupabaseCollection._() { dataStream = AppStream.seed([]); }
  factory ProdutoSupabaseCollection() => _instance;

  late final AppStream<List<ProdutoModel>> dataStream;
  final String name = 'produtos';
  List<ProdutoModel> get data => dataStream.value;
  bool _isStarted = false;

  Future<void> fetch() async { _isStarted = false; await start(lock: false); _isStarted = true; }

  Future<void> start({bool lock = true}) async {
    if (_isStarted && lock) return; _isStarted = true;
    try {
      final response = await SupabaseService.client.from(name).select();
      final items = List<Map<String, dynamic>>.from(response).map((e) => ProdutoModel.fromSupabaseMap(e)).toList();
      dataStream.add(items);
    } catch (e) { log('Supabase Error (Produto.start): $e'); }
  }

  bool _isListen = false;
  Future<void> listen() async {
    if (_isListen) return; _isListen = true;
    SupabaseService.client.from(name).stream(primaryKey: ['id']).listen((data) {
      final items = data.map((e) => ProdutoModel.fromSupabaseMap(e)).toList();
      dataStream.add(items);
    });
  }

  Future<ProdutoModel?> add(ProdutoModel model) async {
    try { await SupabaseService.client.from(name).insert(model.toSupabaseMap()); await fetch(); return model; }
    catch (e) { log('Supabase Error (Produto.add): $e'); return null; }
  }

  Future<ProdutoModel?> update(ProdutoModel model) async {
    try { await SupabaseService.client.from(name).update(model.toSupabaseMap()).eq('id', model.id); await fetch(); return model; }
    catch (e) { log('Supabase Error (Produto.update): $e'); return null; }
  }

  Future<void> delete(ProdutoModel model) async {
    try { await SupabaseService.client.from(name).delete().eq('id', model.id); await fetch(); }
    catch (e) { log('Supabase Error (Produto.delete): $e'); }
  }
}
