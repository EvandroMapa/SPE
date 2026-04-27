import 'dart:developer';
import 'package:acoplan/app/core/client/models/usuario_tipo_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/supabase_service.dart';

class UsuarioTipoSupabaseCollection {
  static final UsuarioTipoSupabaseCollection _instance = UsuarioTipoSupabaseCollection._();
  UsuarioTipoSupabaseCollection._() {
    dataStream = AppStream.seed([]);
  }
  factory UsuarioTipoSupabaseCollection() => _instance;

  late final AppStream<List<UsuarioTipoModel>> dataStream;
  final String name = 'perfis';

  List<UsuarioTipoModel> get data => dataStream.value;

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
      final response = await SupabaseService.client.from(name).select();
      final tipos = List<Map<String, dynamic>>.from(response)
          .map((e) => UsuarioTipoModel.fromSupabaseMap(e))
          .toList();
      dataStream.add(tipos);
    } catch (e) {
      log('Supabase Error (UsuarioTipo.start): $e');
    }
  }

  bool _isListen = false;
  Future<void> listen() async {
    if (_isListen) return;
    _isListen = true;
    SupabaseService.client
        .from(name)
        .stream(primaryKey: ['id']).listen((List<Map<String, dynamic>> data) {
      final tipos = data.map((e) => UsuarioTipoModel.fromSupabaseMap(e)).toList();
      dataStream.add(tipos);
    });
  }

  Future<UsuarioTipoModel?> add(UsuarioTipoModel model) async {
    try {
      await SupabaseService.client.from(name).insert(model.toSupabaseMap());
      await fetch();
      return model;
    } catch (e) {
      log('Supabase Error (UsuarioTipo.add): $e');
      throw Exception('Falha ao adicionar: $e');
    }
  }

  Future<UsuarioTipoModel?> update(UsuarioTipoModel model) async {
    try {
      await SupabaseService.client
          .from(name)
          .update(model.toSupabaseMap())
          .eq('id', model.id);
      await fetch();
      return model;
    } catch (e) {
      log('Supabase Error (UsuarioTipo.update): $e');
      throw Exception('Falha ao atualizar: $e');
    }
  }

  Future<void> delete(UsuarioTipoModel model) async {
    try {
      await SupabaseService.client.from(name).delete().eq('id', model.id);
      await fetch();
    } catch (e) {
      log('Supabase Error (UsuarioTipo.delete): $e');
    }
  }
}
