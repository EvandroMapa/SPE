import 'package:acoplan/app/app_controller.dart';
import 'package:acoplan/app/core/client/models/usuario_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:acoplan/app/core/services/supabase_service.dart';

final signCtrl = SignController();

class SignController {
  static final SignController _instance = SignController._();
  SignController._();
  factory SignController() => _instance;

  final AppStream<bool> loadingStream = AppStream.seed(false);
  final AppStream<bool> obscureStream = AppStream.seed(true);
  final AppStream<bool> keepConnectedStream = AppStream.seed(true);

  final usuarioStream = AppStream<UsuarioModel?>();

  Future<void> login(String email, String senha) async {
    loadingStream.add(true);
    try {
      if (email.isEmpty || senha.isEmpty) {
        throw Exception('Preencha todos os campos');
      }

      // Busca diretamente no Supabase (não depende do cache)
      final response = await SupabaseService.client
          .from('usuarios')
          .select()
          .eq('email', email)
          .eq('senha', senha)
          .maybeSingle();

      if (response == null) {
        throw Exception('Usuário ou senha inválidos');
      }

      final usuario = UsuarioModel.fromSupabaseMap(response);
      await appCtrl.setCurrentUser(usuario, keepConnectedStream.value);
    } catch (e) {
      NotificationService.showNegative('Erro ao entrar', e.toString());
    } finally {
      loadingStream.add(false);
    }
  }

  void logout() {
    appCtrl.logout();
  }
}
