import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/bitola_model.dart';
import 'package:acoplan/app/core/dialogs/confirm_dialog.dart';
import 'package:acoplan/app/core/extensions/string_ext.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/bitola/bitola_view_model.dart';
import 'package:flutter/material.dart';

final bitolaCtrl = BitolaController();

class BitolaController {
  static final BitolaController _instance = BitolaController._();
  BitolaController._();
  factory BitolaController() => _instance;

  final AppStream<BitolaModel?> bitolaStream = AppStream<BitolaModel?>.seed(null);
  BitolaModel? get produto => bitolaStream.value;

  final AppStream<BitolaUtils> utilsStream = AppStream<BitolaUtils>.seed(BitolaUtils());
  BitolaUtils get utils => utilsStream.value;

  void onInit() {
    utilsStream.add(BitolaUtils());
    BackendClient.bitolas.listen();
  }

  final AppStream<BitolaCreateModel> formStream = AppStream<BitolaCreateModel>();
  BitolaCreateModel get form => formStream.value;

  void init(BitolaModel? produto) {
    formStream.add(
      produto != null ? BitolaCreateModel.edit(produto) : BitolaCreateModel(),
    );
  }

  List<BitolaModel> getProdutosFiltered(
    String search,
    List<BitolaModel> produtos,
  ) {
    if (search.length < 3) return produtos;
    List<BitolaModel> filtered = [];
    for (final produto in produtos) {
      if (produto.toString().toCompare.contains(search.toCompare)) {
        filtered.add(produto);
      }
    }
    return filtered;
  }

  Future<void> onConfirm(BuildContext context, BitolaModel? produto) async {
    try {
      onValid(produto);
      if (form.isEdit) {
        final edit = form.toBitolaModel();
        await BackendClient.bitolas.update(edit);
      } else {
        await BackendClient.bitolas.add(form.toBitolaModel());
      }
      await BackendClient.bitolas.fetch();
      if (context.mounted) pop(context);
      NotificationService.showPositive(
        'Bitola ${form.isEdit ? 'Editada' : 'Adicionada'}',
        'Operação realizada com sucesso',
      );
    } catch (e) {
      NotificationService.showNegative('Erro', e.toString());
    }
  }

  Future<void> onDelete(BuildContext context, BitolaModel produto) async {
    final confirmar = await showConfirmDialog(
      'Deseja excluir a bitola?',
      'A bitola "${produto.nome}" será removida permanentemente.',
    );
    if (!confirmar) return;
    try {
      await BackendClient.bitolas.delete(produto);
      if (context.mounted) pop(context);
      NotificationService.showPositive(
        'Bitola Excluída',
        'Operação realizada com sucesso',
      );
    } catch (e) {
      NotificationService.showNegative('Erro', e.toString());
    }
  }

  void onValid(BitolaModel? produto) {
    String nomeForm = form.nome.text.trim();
    if (nomeForm.length < 2) {
      throw Exception('Nome deve conter no mínimo 3 caracteres');
    }
    final produtos = BackendClient.bitolas.data;
    if (form.isEdit) {
      if (produtos.any((e) =>
          e.nome.trim().toLowerCase() == nomeForm.toLowerCase() &&
          e.id.toString().trim() != form.id.toString().trim())) {
        throw Exception('Já existe uma bitola com esse nome');
      }
    } else {
      if (produtos.any(
          (e) => e.nome.trim().toLowerCase() == nomeForm.toLowerCase())) {
        throw Exception('Já existe uma bitola com esse nome');
      }
    }
  }

  /// Persiste a nova ordem de classificação das bitolas após o usuário arrastar
  Future<void> onReorder(List<BitolaModel> reordered) async {
    for (int i = 0; i < reordered.length; i++) {
      final updated = reordered[i].copyWith(sortIndex: i);
      await BackendClient.bitolas.update(updated);
    }
    await BackendClient.bitolas.fetch();
  }
}
