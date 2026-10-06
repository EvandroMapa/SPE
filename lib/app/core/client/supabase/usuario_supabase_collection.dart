import 'dart:async';
import 'dart:developer';
import 'package:acoplan/app/core/client/models/usuario_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UsuarioSupabaseCollection {
  static final UsuarioSupabaseCollection _instance = UsuarioSupabaseCollection._();
  UsuarioSupabaseCollection._() {
    dataStream = AppStream.seed([]);
  }
  factory UsuarioSupabaseCollection() => _instance;

  late final AppStream<List<UsuarioModel>> dataStream;
  final String name = 'usuarios';

  /// Colunas lidas — a coluna antiga `senha` nunca é baixada para o app.
  static const String _select =
      'id, nome, email, role, perfil_id, permission, deviceTokens, auth_user_id, perfis(*)';

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
      final response = await SupabaseService.client.from(name).select(_select);
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
    // Canal de eventos (e não .stream(), que faria um select * da tabela)
    SupabaseService.client
        .channel('spe-usuarios')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: name,
            callback: (_) {
              _streamDebounce?.cancel();
              _streamDebounce = Timer(const Duration(milliseconds: 500), () {
                start(lock: false);
              });
            })
        .subscribe();
  }

  UsuarioModel getById(String id) =>
      data.firstWhere((e) => e.id == id, orElse: () => UsuarioModel.empty());

  /// Usuário do SPE ligado ao login do Supabase Auth.
  Future<UsuarioModel?> buscarPorAuthId(String authUserId) async {
    final row = await SupabaseService.client
        .from(name)
        .select(_select)
        .eq('auth_user_id', authUserId)
        .maybeSingle();
    return row == null ? null : UsuarioModel.fromSupabaseMap(row);
  }

  /// Cria ou atualiza o login (Supabase Auth) de um usuário. Senha vazia
  /// mantém a atual. Retorna o auth_user_id.
  Future<String> definirLogin({
    required String email,
    required String senha,
    String? authUserId,
  }) async {
    final result = await SupabaseService.client.rpc('definir_login_usuario', params: {
      'p_email': email.trim().toLowerCase(),
      'p_senha': senha,
      'p_auth_user_id': (authUserId == null || authUserId.isEmpty) ? null : authUserId,
    });
    return result.toString();
  }

  Future<void> removerLogin(String authUserId) async {
    await SupabaseService.client.rpc('remover_login_usuario', params: {'p_auth_user_id': authUserId});
  }

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

  /// Exclui o usuário e o seu login. Lança exceção em caso de erro.
  Future<void> delete(UsuarioModel model) async {
    await SupabaseService.client.from(name).delete().eq('id', model.id);
    if (model.authUserId.isNotEmpty) await removerLogin(model.authUserId);
    await fetch();
  }
}
