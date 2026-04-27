import 'package:acoplan/app/app_controller.dart';
import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/usuario_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/usuario/usuario_view_model.dart';
import 'package:flutter/material.dart';

final usuarioCtrl = UsuarioController();

class UsuarioController {
  static final UsuarioController _instance = UsuarioController._();
  UsuarioController._();
  factory UsuarioController() => _instance;

  final AppStream<UsuarioModel?> usuarioStream = AppStream<UsuarioModel?>();
  UsuarioModel? get usuario => usuarioStream.valueOrNull;

  final AppStream<List<UsuarioModel>> usuariosStream =
      BackendClient.usuarios.dataStream;
  List<UsuarioModel> get usuarios => usuariosStream.value;

  final AppStream<UsuarioCreateModel> formStream =
      AppStream<UsuarioCreateModel>();
  UsuarioCreateModel get form => formStream.value;

  void init(UsuarioModel? user) {
    formStream.add(
      user != null ? UsuarioCreateModel.edit(user) : UsuarioCreateModel(),
    );
  }

  Future<void> onConfirm(BuildContext context) async {
    try {
      if (form.nome.text.isEmpty || form.email.text.isEmpty) {
        throw Exception('Nome e email são obrigatórios');
      }

      if (form.isEdit) {
        await BackendClient.usuarios.update(form.toUsuarioModel());
      } else {
        await BackendClient.usuarios.add(form.toUsuarioModel());
      }

      pop(context);
      NotificationService.showPositive(
        'Usuário ${form.isEdit ? 'Editado' : 'Adicionado'}',
        'Operação realizada com sucesso',
      );
    } catch (e) {
      NotificationService.showNegative('Erro ao salvar', e.toString());
    }
  }

  Future<void> onDelete(BuildContext context, UsuarioModel user) async {
    try {
      if (user.id == appCtrl.usuario?.id) {
        throw Exception('Você não pode excluir seu próprio usuário');
      }

      await BackendClient.usuarios.delete(user);
      NotificationService.showPositive('Usuário Excluído', '');
    } catch (e) {
      NotificationService.showNegative('Erro ao excluir', e.toString());
    }
  }
}
