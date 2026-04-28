import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/cliente_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/models/endereco_model.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:acoplan/app/modules/obra/obra_view_model.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

final obraCtrl = ObraController();

class ObraController {
  static final ObraController _instance = ObraController._();

  ObraController._();

  factory ObraController() => _instance;

  final AppStream<ObraCreateModel> formStream = AppStream<ObraCreateModel>();
  ObraCreateModel get form => formStream.value;

  /// Obras irmãs (do mesmo cliente) para validação local de duplicidade
  List<ObraModel> _obrasIrmas = [];

  void init(ObraModel? obra, EnderecoModel? enderecoModel, {List<ObraModel> obrasIrmas = const []}) {
    _obrasIrmas = obrasIrmas;
    formStream.add(
      obra != null ? ObraCreateModel.edit(obra) : ObraCreateModel(),
    );
    if (!form.isEdit) {
      form.endereco = enderecoModel;
      formStream.update();
    }
  }

  Future<void> onConfirm(value) async {
    try {
      onValid();
      Navigator.pop(value, formStream.value.toObraModel());
      NotificationService.showPositive(
        'Obra ${form.isEdit ? 'Editada' : 'Adicionada'}',
        'Operação realizada com sucesso',
        position: NotificationPosition.bottom,
      );
    } catch (e) {
      NotificationService.showNegative(
        'Erro',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }

  void onValid() {
    final identificador = form.identificador.text.trim();
    if (identificador.isEmpty) {
      throw Exception('Identificador é obrigatório');
    }
    if (identificador.length > 20) {
      throw Exception('Identificador deve ter no máximo 20 caracteres');
    }
    if (form.descricao.text.length < 2) {
      throw Exception('Descrição deve conter no mínimo 3 caracteres');
    }
    if (form.status == null) {
      throw Exception('Selecione um status para a obra');
    }

    // Validação de duplicidade — verifica todas as obras do sistema
    final todasObras = BackendClient.clientes.data
        .expand((c) => c.obras)
        .toList()
      ..addAll(_obrasIrmas);

    final duplicada = todasObras.any((o) =>
        o.identificador.trim().toLowerCase() == identificador.toLowerCase() &&
        o.id != form.id);

    if (duplicada) {
      throw Exception('Já existe uma obra com o identificador "$identificador"');
    }
  }
}
