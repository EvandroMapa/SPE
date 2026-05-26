import 'package:acoplan/app/app_repository.dart';
import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/usuario_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
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

  Future<void> onInit() async {
    final cachedUser = await AppRepository.get();
    if (cachedUser != null) {
      final dbUser = BackendClient.usuarios.getById(cachedUser.id);
      final finalUser = dbUser.id.isNotEmpty ? dbUser : cachedUser;
      usuarioStream.add(finalUser);
      usuarioCtrl.usuarioStream.add(finalUser);
    }
    
    // Sincroniza a chave de API global a partir do Supabase
    await syncGlobalApiKey();
  }

  Future<void> setCurrentUser(UsuarioModel user, bool keepConnected) async {
    usuarioStream.add(user);
    usuarioCtrl.usuarioStream.add(user);
    if (keepConnected) {
      await AppRepository.add(user);
    }
    
    // Sincroniza a chave de API global a partir do Supabase ao logar
    await syncGlobalApiKey();
  }

  void logout() {
    usuarioStream.add(null);
    usuarioCtrl.usuarioStream.add(null);
    AppRepository.removeUser();
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
}
