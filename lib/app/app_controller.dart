import 'package:acoplan/app/app_repository.dart';
import 'package:acoplan/app/core/client/models/usuario_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/modules/usuario/usuario_controller.dart';
import 'package:flutter/material.dart';

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
    final user = await AppRepository.get();
    if (user != null) {
      usuarioStream.add(user);
      usuarioCtrl.usuarioStream.add(user);
    }
  }

  Future<void> setCurrentUser(UsuarioModel user, bool keepConnected) async {
    usuarioStream.add(user);
    usuarioCtrl.usuarioStream.add(user);
    if (keepConnected) {
      await AppRepository.add(user);
    }
  }

  void logout() {
    usuarioStream.add(null);
    usuarioCtrl.usuarioStream.add(null);
    AppRepository.removeUser();
  }
}
