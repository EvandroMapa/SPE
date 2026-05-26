import 'dart:developer';
import 'package:acoplan/app/core/client/models/bitola_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/supabase_service.dart';

class BitolaSupabaseCollection {
  static final BitolaSupabaseCollection _instance = BitolaSupabaseCollection._();
  BitolaSupabaseCollection._() { dataStream = AppStream.seed([]); }
  factory BitolaSupabaseCollection() => _instance;

  late final AppStream<List<BitolaModel>> dataStream;
  final String name = 'bitolas';
  List<BitolaModel> get data => dataStream.value;
  bool _isStarted = false;

  Future<void> fetch() async { _isStarted = false; await start(lock: false); _isStarted = true; }

  Future<void> start({bool lock = true}) async {
    if (_isStarted && lock) return; _isStarted = true;
    try {
      final response = await SupabaseService.client.from(name).select();
      final items = List<Map<String, dynamic>>.from(response).map((e) => BitolaModel.fromSupabaseMap(e)).toList();
      dataStream.add(items);
    } catch (e) { log('Supabase Error (Bitola.start): $e'); }
  }

  bool _isListen = false;
  Future<void> listen() async {
    if (_isListen) return; _isListen = true;
    SupabaseService.client.from(name).stream(primaryKey: ['id']).listen((data) {
      final items = data.map((e) => BitolaModel.fromSupabaseMap(e)).toList();
      dataStream.add(items);
    });
  }

  Future<BitolaModel?> add(BitolaModel model) async {
    try { await SupabaseService.client.from(name).insert(model.toSupabaseMap()); await fetch(); return model; }
    catch (e) { log('Supabase Error (Bitola.add): $e'); return null; }
  }

  Future<BitolaModel?> update(BitolaModel model) async {
    try { await SupabaseService.client.from(name).update(model.toSupabaseMap()).eq('id', model.id); await fetch(); return model; }
    catch (e) { log('Supabase Error (Bitola.update): $e'); return null; }
  }

  Future<void> delete(BitolaModel model) async {
    try { await SupabaseService.client.from(name).delete().eq('id', model.id); await fetch(); }
    catch (e) { log('Supabase Error (Bitola.delete): $e'); }
  }
}
