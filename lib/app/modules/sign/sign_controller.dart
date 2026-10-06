import 'package:acoplan/app/app_controller.dart';
import 'package:acoplan/app/core/client/models/usuario_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:acoplan/app/core/services/supabase_service.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, AuthResponse;

final signCtrl = SignController();

class SignController {
  static final SignController _instance = SignController._();
  SignController._();
  factory SignController() => _instance;

  final AppStream<bool> loadingStream = AppStream.seed(false);
  final AppStream<bool> obscureStream = AppStream.seed(true);
  final AppStream<bool> keepConnectedStream = AppStream.seed(true);

  final usuarioStream = AppStream<UsuarioModel?>();

  Future<void> login(String email, String senha, {bool? keepConnected}) async {
    final manterConectado = keepConnected ?? keepConnectedStream.value;
    keepConnectedStream.add(manterConectado);
    loadingStream.add(true);
    try {
      if (email.isEmpty || senha.isEmpty) {
        throw Exception('Preencha todos os campos');
      }

      // Login pelo Supabase Auth (senha verificada no servidor, nunca lida pelo app)
      final auth = SupabaseService.client.auth;
      final AuthResponse res;
      try {
        res = await auth.signInWithPassword(email: email.trim().toLowerCase(), password: senha);
      } on AuthException catch (e) {
        if (e.code == 'invalid_credentials' || e.message.contains('Invalid login credentials')) {
          throw Exception('Usuário ou senha inválidos');
        }
        rethrow;
      }

      if (!await appCtrl.entrar(res.user!.id)) {
        await auth.signOut();
        throw Exception('Login sem cadastro de usuário no SPE. Fale com o administrador.');
      }
    } catch (e) {
      NotificationService.showNegative('Erro ao entrar', mensagemErro(e));
    } finally {
      loadingStream.add(false);
    }
  }

  Future<void> logout() => appCtrl.logout();
}
