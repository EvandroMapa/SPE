import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/usuario_tipo_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:flutter/material.dart';

final usuarioTipoCtrl = UsuarioTipoController();

class UsuarioTipoController {
  static final UsuarioTipoController _instance = UsuarioTipoController._();
  UsuarioTipoController._();
  factory UsuarioTipoController() => _instance;

  final AppStream<List<UsuarioTipoModel>> tiposStream =
      BackendClient.usuarioTipos.dataStream;
  List<UsuarioTipoModel> get tipos => tiposStream.value;

  final AppStream<UsuarioTipoCreateModel> formStream =
      AppStream<UsuarioTipoCreateModel>();
  UsuarioTipoCreateModel get form => formStream.value;

  void init(UsuarioTipoModel? tipo) {
    formStream.add(
      tipo != null
          ? UsuarioTipoCreateModel.edit(tipo)
          : UsuarioTipoCreateModel(),
    );
  }

  Future<void> onConfirm(BuildContext context) async {
    try {
      if (form.nome.text.trim().isEmpty) {
        throw Exception('O nome do tipo é obrigatório');
      }

      if (form.isEdit) {
        await BackendClient.usuarioTipos.update(form.toModel());
      } else {
        await BackendClient.usuarioTipos.add(form.toModel());
      }

      pop(context);
      NotificationService.showPositive(
        'Perfil de Usuário ${form.isEdit ? 'Editado' : 'Adicionado'}',
        'Operação realizada com sucesso',
      );
    } catch (e) {
      NotificationService.showNegative('Erro ao salvar', e.toString());
    }
  }

  Future<void> onDelete(BuildContext context, UsuarioTipoModel tipo) async {
    try {
      final usuariosComEsteTipo =
          BackendClient.usuarios.data.where((u) => u.usuarioTipoId == tipo.id);
      if (usuariosComEsteTipo.isNotEmpty) {
        throw Exception(
            'Não é possível excluir um perfil que possui usuários vinculados.');
      }

      await BackendClient.usuarioTipos.delete(tipo);
      NotificationService.showPositive('Perfil Excluído', '');
    } catch (e) {
      NotificationService.showNegative('Erro ao excluir', e.toString());
    }
  }
}

class UsuarioTipoCreateModel {
  final String id;
  final TextEditingController nome = TextEditingController();
  bool isPermitirElementos = false;
  bool isPermitirEditarElementos = false;
  bool isOperador = false;
  bool isArmador = false;
  bool isEdit = false;

  UsuarioTipoCreateModel()
      : id = '',
        isEdit = false;

  UsuarioTipoCreateModel.edit(UsuarioTipoModel m)
      : id = m.id,
        isEdit = true {
    nome.text = m.nome;
    isPermitirElementos = m.isPermitirElementos;
    isPermitirEditarElementos = m.isPermitirEditarElementos;
    isOperador = m.isOperador;
    isArmador = m.isArmador;
  }

  UsuarioTipoModel toModel() => UsuarioTipoModel(
        id: id,
        nome: nome.text.trim(),
        isPermitirElementos: isPermitirElementos,
        isPermitirEditarElementos: isPermitirEditarElementos,
        isOperador: isOperador,
        isArmador: isArmador,
        createdAt: DateTime.now(),
      );
}
