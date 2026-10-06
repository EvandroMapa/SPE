import 'package:shared_preferences/shared_preferences.dart';

class AppRepository {
  /// Remove o usuário que versões antigas guardavam no armazenamento local
  /// (incluindo a senha). A sessão agora é mantida pelo Supabase Auth.
  static Future<void> removeUser() async {
    final sharedPrefs = await SharedPreferences.getInstance();
    sharedPrefs.remove('usuario');
  }

  static Future<bool> getManterConectado() async {
    final sharedPrefs = await SharedPreferences.getInstance();
    return sharedPrefs.getBool('manter_conectado') ?? true;
  }

  static Future<void> setManterConectado(bool value) async {
    final sharedPrefs = await SharedPreferences.getInstance();
    await sharedPrefs.setBool('manter_conectado', value);
  }

  static Future<void> clear() async {
    final sharedPrefs = await SharedPreferences.getInstance();
    sharedPrefs.clear();
  }
}
