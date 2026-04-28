import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/produto_model.dart';
import 'package:acoplan/app/core/dialogs/confirm_dialog.dart';
import 'package:acoplan/app/core/extensions/string_ext.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/produto/produto_view_model.dart';
import 'package:flutter/material.dart';

final produtoCtrl = ProdutoController();

class ProdutoController {
  static final ProdutoController _instance = ProdutoController._();
  ProdutoController._();
  factory ProdutoController() => _instance;

  final AppStream<ProdutoModel?> produtoStream = AppStream<ProdutoModel?>.seed(null);
  ProdutoModel? get produto => produtoStream.value;

  final AppStream<ProdutoUtils> utilsStream = AppStream<ProdutoUtils>.seed(ProdutoUtils());
  ProdutoUtils get utils => utilsStream.value;

  void onInit() {
    utilsStream.add(ProdutoUtils());
    BackendClient.produtos.listen();
  }

  final AppStream<ProdutoCreateModel> formStream = AppStream<ProdutoCreateModel>();
  ProdutoCreateModel get form => formStream.value;

  void init(ProdutoModel? produto) {
    formStream.add(
      produto != null ? ProdutoCreateModel.edit(produto) : ProdutoCreateModel(),
    );
  }

  List<ProdutoModel> getProdutosFiltered(
    String search,
    List<ProdutoModel> produtos,
  ) {
    if (search.length < 3) return produtos;
    List<ProdutoModel> filtered = [];
    for (final produto in produtos) {
      if (produto.toString().toCompare.contains(search.toCompare)) {
        filtered.add(produto);
      }
    }
    return filtered;
  }

  Future<void> onConfirm(BuildContext context, ProdutoModel? produto) async {
    try {
      onValid(produto);
      if (form.isEdit) {
        final edit = form.toProdutoModel();
        await BackendClient.produtos.update(edit);
      } else {
        await BackendClient.produtos.add(form.toProdutoModel());
      }
      await BackendClient.produtos.fetch();
      if (context.mounted) pop(context);
      NotificationService.showPositive(
        'Bitola ${form.isEdit ? 'Editada' : 'Adicionada'}',
        'Operação realizada com sucesso',
      );
    } catch (e) {
      NotificationService.showNegative('Erro', e.toString());
    }
  }

  Future<void> onDelete(BuildContext context, ProdutoModel produto) async {
    final confirmar = await showConfirmDialog(
      'Deseja excluir a bitola?',
      'A bitola "${produto.nome}" será removida permanentemente.',
    );
    if (!confirmar) return;
    try {
      await BackendClient.produtos.delete(produto);
      if (context.mounted) pop(context);
      NotificationService.showPositive(
        'Bitola Excluída',
        'Operação realizada com sucesso',
      );
    } catch (e) {
      NotificationService.showNegative('Erro', e.toString());
    }
  }

  void onValid(ProdutoModel? produto) {
    String nomeForm = form.nome.text.trim();
    if (nomeForm.length < 2) {
      throw Exception('Nome deve conter no mínimo 3 caracteres');
    }
    final produtos = BackendClient.produtos.data;
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
  Future<void> onReorder(List<ProdutoModel> reordered) async {
    for (int i = 0; i < reordered.length; i++) {
      final updated = reordered[i].copyWith(sortIndex: i);
      await BackendClient.produtos.update(updated);
    }
    await BackendClient.produtos.fetch();
  }
}
