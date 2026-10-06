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
      final model = form.toUsuarioModel();
      final senha = form.senha.text;
      final usuarios = BackendClient.usuarios;

      if (form.isEdit) {
        final original = usuarios.getById(model.id);
        var authId = model.authUserId;
        if (authId.isEmpty) {
          // Usuário ainda sem login (não migrado): precisa de senha
          if (senha.isEmpty) {
            throw Exception('Defina uma senha para que este usuário possa entrar.');
          }
          authId = await usuarios.definirLogin(email: model.email, senha: senha);
        } else if (senha.isNotEmpty ||
            original.email.trim().toLowerCase() != model.email.trim().toLowerCase()) {
          await usuarios.definirLogin(email: model.email, senha: senha, authUserId: authId);
        }
        await usuarios.update(model.copyWith(authUserId: authId));
      } else {
        if (senha.length < 6) {
          throw Exception('Informe uma senha com pelo menos 6 caracteres');
        }
        final authId = await usuarios.definirLogin(email: model.email, senha: senha);
        try {
          await usuarios.add(model.copyWith(authUserId: authId));
        } catch (_) {
          await usuarios.removerLogin(authId); // não deixa login órfão
          rethrow;
        }
      }

      if (context.mounted) pop(context);
      NotificationService.showPositive(
        'Usuário ${form.isEdit ? 'Editado' : 'Adicionado'}',
        'Operação realizada com sucesso',
      );
    } catch (e) {
      NotificationService.showNegative('Erro ao salvar', mensagemErro(e));
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
      NotificationService.showNegative('Erro ao excluir', mensagemErro(e));
    }
  }
}
