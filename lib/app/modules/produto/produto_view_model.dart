import 'package:acoplan/app/core/client/models/produto_model.dart';
import 'package:acoplan/app/core/extensions/text_controller_ext.dart';
import 'package:acoplan/app/core/models/text_controller.dart';
import 'package:acoplan/app/core/services/hash_service.dart';

class ProdutoUtils {
  final TextController search = TextController();
}

class ProdutoCreateModel {
  final String id;
  TextController nome = TextController();
  TextController descricao = TextController();
  TextController massaFinal = TextController.number();
  TextController codigoFinanceiro = TextController();
  int sortIndex = 999;
  late bool isEdit;

  ProdutoCreateModel()
      : id = HashService.get,
        isEdit = false;

  ProdutoCreateModel.edit(ProdutoModel produto)
      : id = produto.id,
        isEdit = true {
    nome.text = produto.nome;
    descricao.text = produto.descricao;
    massaFinal = TextController.number(value: produto.massaFinal);
    codigoFinanceiro.text = produto.codigoFinanceiro;
    sortIndex = produto.sortIndex;
  }

  ProdutoModel toProdutoModel() => ProdutoModel(
        id: id,
        nome: nome.text,
        descricao: descricao.text,
        massaFinal: massaFinal.doubleValue,
        codigoFinanceiro: codigoFinanceiro.text,
        sortIndex: sortIndex,
      );
}
