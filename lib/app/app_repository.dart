import 'dart:convert';
import 'package:acoplan/app/core/client/models/usuario_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppRepository {
  static Future<bool> add(UsuarioModel usuario) async {
    final sharedPrefs = await SharedPreferences.getInstance();
    sharedPrefs.setString('usuario', usuario.toJson());
    return true;
  }

  static Future<UsuarioModel?> get() async {
    final sharedPrefs = await SharedPreferences.getInstance();
    final usuario = sharedPrefs.getString('usuario');
    if (usuario == null) return null;
    final map = jsonDecode(usuario);
    return UsuarioModel.fromMap(map);
  }

  static Future<void> removeUser() async {
    final sharedPrefs = await SharedPreferences.getInstance();
    sharedPrefs.remove('usuario');
  }

  static Future<void> clear() async {
    final sharedPrefs = await SharedPreferences.getInstance();
    sharedPrefs.clear();
  }
}
