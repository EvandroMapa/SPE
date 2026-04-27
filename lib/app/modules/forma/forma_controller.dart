
import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/forma_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/forma/forma_view_model.dart';
import 'package:flutter/material.dart';

final formaCtrl = FormaController();

class FormaController {
  static final FormaController _instance = FormaController._();
  FormaController._();
  factory FormaController() => _instance;

  final AppStream<List<FormaModel>> formasStream =
      BackendClient.formas.dataStream;
  List<FormaModel> get formas => formasStream.value;

  final AppStream<FormaCriarModel> formularioStream =
      AppStream<FormaCriarModel>();
  FormaCriarModel get formulario => formularioStream.value;

  void inicializar(FormaModel? forma) {
    if (forma != null) {
      formularioStream.add(FormaCriarModel.editar(forma));
    } else {
      final novoForm = FormaCriarModel();
      // Sugerir o último número cadastrado + 1
      int maiorCodigo = 0;
      for (var f in formas) {
        final cod = int.tryParse(f.codigo) ?? 0;
        if (cod > maiorCodigo) maiorCodigo = cod;
      }
      novoForm.codigo.text = (maiorCodigo + 1).toString();
      formularioStream.add(novoForm);
    }
  }

  Future<void> confirmar(BuildContext context) async {
    try {
      if (formulario.codigo.text.isEmpty || formulario.descricao.text.isEmpty) {
        throw Exception('Código e descrição são obrigatórios');
      }

      if (formulario.is_edicao) {
        await BackendClient.formas.update(formulario.toFormaModel());
      } else {
        await BackendClient.formas.add(formulario.toFormaModel());
      }

      if (!context.mounted) return;
      pop(context);
      NotificationService.showPositive(
        'Forma ${formulario.is_edicao ? 'Editada' : 'Adicionada'}',
        'Operação realizada com sucesso',
      );
    } catch (e) {
      NotificationService.showNegative('Erro ao salvar', e.toString());
    }
  }

  Future<void> excluir(BuildContext context, FormaModel forma) async {
    try {
      await BackendClient.formas.delete(forma);
      NotificationService.showPositive('Forma Excluída', '');
    } catch (e) {
      NotificationService.showNegative('Erro ao excluir', e.toString());
    }
  }

  void adicionarItem() {
    final proximoN = formulario.itens.length + 1;
    final novoItem = FormaItemModel(
      trecho: 'T$proximoN',
      comprimento: proximoN * 10, // comprimento proporcional ao número do trecho
      angulo: 0,
      orientacao: 'Horário',
    );
    formulario.itens.add(novoItem);
    formularioStream.update();

    // Dar foco no campo de ângulo do novo item
    Future.delayed(const Duration(milliseconds: 100), () {
      novoItem.focusNode.requestFocus();
    });
  }

  void adicionarItemDoCanvas(double anguloRelativo, String orientacaoParam) {
    if (formulario.itens.isNotEmpty) {
      formulario.itens.last.angulo = anguloRelativo;
      formulario.itens.last.orientacao = orientacaoParam;
    }
    final proximoN = formulario.itens.length + 1;
    formulario.itens.add(FormaItemModel(
      trecho: 'T$proximoN',
      comprimento: proximoN * 10,
      angulo: 0,
      orientacao: 'Horário',
    ));
    formularioStream.update();
  }

  void removerItem(int index) {
    formulario.itens.removeAt(index);
    // Renumera em ordem numérica absoluta: T1, T2, T10...
    for (var i = 0; i < formulario.itens.length; i++) {
      formulario.itens[i].trecho = 'T${i + 1}';
    }
    formularioStream.update();
  }

}
