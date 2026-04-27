import 'dart:async';
import 'dart:developer';
import 'package:acoplan/app/core/client/models/usuario_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/supabase_service.dart';

class UsuarioSupabaseCollection {
  static final UsuarioSupabaseCollection _instance = UsuarioSupabaseCollection._();
  UsuarioSupabaseCollection._() {
    dataStream = AppStream.seed([]);
  }
  factory UsuarioSupabaseCollection() => _instance;

  late final AppStream<List<UsuarioModel>> dataStream;
  final String name = 'usuarios';

  List<UsuarioModel> get data => dataStream.value;

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
      final response = await SupabaseService.client.from(name).select('*, perfis(*)');
      final usuarios = List<Map<String, dynamic>>.from(response)
          .map((e) => UsuarioModel.fromSupabaseMap(e))
          .toList();
      dataStream.add(usuarios);
    } catch (e) {
      log('Supabase Error (Usuario.start): $e');
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

  UsuarioModel getById(String id) =>
      data.firstWhere((e) => e.id == id, orElse: () => UsuarioModel.empty());

  Future<UsuarioModel?> add(UsuarioModel model) async {
    try {
      await SupabaseService.client.from(name).insert(model.toSupabaseMap());
      await fetch();
      return model;
    } catch (e) {
      log('Supabase Error (Usuario.add): $e');
      throw Exception('Falha ao adicionar: $e');
    }
  }

  Future<UsuarioModel?> update(UsuarioModel model) async {
    try {
      await SupabaseService.client
          .from(name)
          .update(model.toSupabaseMap())
          .eq('id', model.id);
      await fetch();
      return model;
    } catch (e) {
      log('Supabase Error (Usuario.update): $e');
      throw Exception('Falha ao atualizar: $e');
    }
  }

  Future<void> delete(UsuarioModel model) async {
    try {
      await SupabaseService.client.from(name).delete().eq('id', model.id);
      await fetch();
    } catch (e) {
      log('Supabase Error (Usuario.delete): $e');
    }
  }
}
