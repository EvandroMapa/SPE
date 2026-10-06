import 'package:acoplan/app/app_repository.dart';
import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/usuario_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/models/service_model.dart';
import 'package:acoplan/app/core/services/supabase_service.dart';
import 'package:acoplan/app/modules/usuario/usuario_controller.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appCtrl = AppController();

class AppController {
  static final AppController _instance = AppController._();
  AppController._();
  factory AppController() => _instance;

  final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
  BuildContext get context => key.currentContext!;

  final AppStream<UsuarioModel?> usuarioStream = AppStream<UsuarioModel?>.seed(null);
  UsuarioModel? get usuario => usuarioStream.valueOrNull;

  final AppStream<bool> etiquetaRotacao180Stream = AppStream<bool>.seed(false);
  bool get etiquetaRotacao180 => etiquetaRotacao180Stream.value;

  /// Restaura a sessão do Supabase Auth (se houver) ao abrir o app.
  Future<void> onInit() async {
    // Versões antigas guardavam o usuário (com senha) no armazenamento local
    await AppRepository.removeUser();

    final auth = SupabaseService.client.auth;
    final authUser = auth.currentUser;
    if (authUser == null) return;

    // "Manter conectado" desmarcado: a sessão não sobrevive a reabrir o app
    if (!await AppRepository.getManterConectado()) {
      await auth.signOut();
      return;
    }
    if (!await entrar(authUser.id)) await auth.signOut();
  }

  /// Carrega o usuário do SPE ligado ao login [authUserId] e os dados do app.
  /// Retorna false se não houver usuário cadastrado para esse login.
  Future<bool> entrar(String authUserId) async {
    final usuario = await BackendClient.usuarios.buscarPorAuthId(authUserId);
    if (usuario == null) return false;

    // Com RLS, os dados só podem ser carregados depois de autenticar
    await Service.initAplicationServices();

    usuarioStream.add(usuario);
    usuarioCtrl.usuarioStream.add(usuario);

    // Sincroniza a chave de API global e configurações gerais a partir do Supabase
    await syncGlobalApiKey();
    await syncEtiquetaRotacao180();
    return true;
  }

  Future<void> logout() async {
    usuarioStream.add(null);
    usuarioCtrl.usuarioStream.add(null);
    await SupabaseService.client.auth.signOut();
    // NOTA: Como a chave de API é uma configuração global do app,
    // nós NÃO removemos o 'gemini_api_key' no logout para que o app continue configurado.
  }

  Future<void> syncGlobalApiKey() async {
    try {
      final response = await SupabaseService.client
          .from('configuracoes')
          .select('valor')
          .eq('chave', 'gemini_api_key')
          .maybeSingle();
          
      if (response != null) {
        final dbApiKey = response['valor'] as String;
        if (dbApiKey.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          final localApiKey = prefs.getString('gemini_api_key') ?? '';
          if (dbApiKey != localApiKey) {
            await prefs.setString('gemini_api_key', dbApiKey);
          }
        }
      } else {
        // Se a chave não existir no banco, mas existir localmente, podemos fazer o upload dela
        final prefs = await SharedPreferences.getInstance();
        final localApiKey = prefs.getString('gemini_api_key') ?? '';
        if (localApiKey.isNotEmpty) {
          await saveGlobalApiKey(localApiKey);
        }
      }
    } catch (e) {
      // Ignora silenciosamente caso a tabela 'configuracoes' ainda não exista no Supabase
    }
  }

  Future<void> saveGlobalApiKey(String apiKey) async {
    try {
      await SupabaseService.client.from('configuracoes').upsert({
        'chave': 'gemini_api_key',
        'valor': apiKey.trim(),
      });
    } catch (e) {
      // Ignora silenciosamente caso a tabela 'configuracoes' ainda não exista no Supabase
    }
  }

  Future<void> syncEtiquetaRotacao180() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localVal = prefs.getBool('etiqueta_rotacao_180') ?? false;
      etiquetaRotacao180Stream.add(localVal);

      final response = await SupabaseService.client
          .from('configuracoes')
          .select('valor')
          .eq('chave', 'etiqueta_rotacao_180')
          .maybeSingle();

      if (response != null) {
        final dbVal = response['valor'] == 'true';
        if (dbVal != localVal) {
          await prefs.setBool('etiqueta_rotacao_180', dbVal);
          etiquetaRotacao180Stream.add(dbVal);
        }
      }
    } catch (e) {
      // Ignora silenciosamente caso a tabela 'configuracoes' ainda não exista no Supabase
    }
  }

  Future<void> saveEtiquetaRotacao180(bool valor) async {
    etiquetaRotacao180Stream.add(valor);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('etiqueta_rotacao_180', valor);
      await SupabaseService.client.from('configuracoes').upsert({
        'chave': 'etiqueta_rotacao_180',
        'valor': valor ? 'true' : 'false',
      });
    } catch (e) {
      // Ignora silenciosamente caso a tabela 'configuracoes' ainda não exista no Supabase
    }
  }
}
