
import 'dart:async';
import 'dart:developer';
import 'package:acoplan/app/core/client/models/forma_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/supabase_service.dart';

class FormaSupabaseCollection {
  static final FormaSupabaseCollection _instance = FormaSupabaseCollection._();
  FormaSupabaseCollection._() {
    dataStream = AppStream.seed([]);
  }
  factory FormaSupabaseCollection() => _instance;

  late final AppStream<List<FormaModel>> dataStream;
  final String name = 'formas';

  List<FormaModel> get data => dataStream.value;

  bool _isStarted = false;
  Timer? _streamDebounce;

  Future<void> fetch() async {
    _isStarted = false;
    await start(lock: false);
    _isStarted = true;
  }

  Future<void> start({bool lock = true}) async {
    if (_isStarted && lock) return;
    _isStarted = true;
    try {
      final response = await SupabaseService.client.from(name).select('*');
      final formas = List<Map<String, dynamic>>.from(response)
          .map((e) => FormaModel.fromSupabaseMap(e))
          .toList();
      dataStream.add(formas);
    } catch (e) {
      log('Supabase Error (Forma.start): $e');
    }
  }

  bool _isListen = false;
  Future<void> listen() async {
    if (_isListen) return;
    _isListen = true;
    SupabaseService.client
        .from(name)
        .stream(primaryKey: ['id']).listen((List<Map<String, dynamic>> data) {
      _streamDebounce?.cancel();
      _streamDebounce = Timer(const Duration(milliseconds: 500), () {
        start(lock: false);
      });
    });
  }

  FormaModel getById(String id) =>
      data.firstWhere((e) => e.id == id, orElse: () => FormaModel.empty());

  Future<FormaModel?> add(FormaModel model) async {
    try {
      await SupabaseService.client.from(name).insert(model.toSupabaseMap());
      await fetch();
      return model;
    } catch (e) {
      log('Supabase Error (Forma.add): $e');
      throw Exception('Falha ao adicionar: $e');
    }
  }

  Future<FormaModel?> update(FormaModel model) async {
    try {
      await SupabaseService.client
          .from(name)
          .update(model.toSupabaseMap())
          .eq('id', model.id);
      await fetch();
      return model;
    } catch (e) {
      log('Supabase Error (Forma.update): $e');
      throw Exception('Falha ao atualizar: $e');
    }
  }

  Future<void> delete(FormaModel model) async {
    try {
      await SupabaseService.client.from(name).delete().eq('id', model.id);
      await fetch();
    } catch (e) {
      log('Supabase Error (Forma.delete): $e');
    }
  }
}
