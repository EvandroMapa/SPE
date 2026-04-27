import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/cliente_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/cliente/cliente_view_model.dart';
import 'package:flutter/material.dart';

final clienteCtrl = ClienteController();

class ClienteController {
  static final ClienteController _instance = ClienteController._();
  ClienteController._();
  factory ClienteController() => _instance;

  final AppStream<List<ClienteModel>> clientesStream = BackendClient.clientes.dataStream;
  List<ClienteModel> get clientes => clientesStream.value;

  final AppStream<ClienteCreateModel> formStream = AppStream<ClienteCreateModel>();
  ClienteCreateModel get form => formStream.value;

  void init(ClienteModel? cliente) {
    formStream.add(cliente != null ? ClienteCreateModel.edit(cliente) : ClienteCreateModel());
  }

  Future<void> onConfirm(BuildContext context, ClienteModel? clienteOriginal, bool isFromOrder) async {
    try {
      if (form.nome.text.isEmpty) throw Exception('Nome é obrigatório');

      if (form.isEdit) {
        await BackendClient.clientes.update(form.toClienteModel());
      } else {
        await BackendClient.clientes.add(form.toClienteModel());
      }

      pop(context);
      NotificationService.showPositive('Sucesso', 'Cliente ${form.isEdit ? 'editado' : 'adicionado'} com sucesso');
    } catch (e) {
      NotificationService.showNegative('Erro', e.toString());
    }
  }

  Future<void> onDelete(BuildContext context, ClienteModel cliente) async {
    try {
      await BackendClient.clientes.delete(cliente);
      NotificationService.showPositive('Sucesso', 'Cliente excluído');
    } catch (e) {
      NotificationService.showNegative('Erro', e.toString());
    }
  }
}
