
import 'package:acoplan/app/core/client/models/forma_model.dart';
import 'package:acoplan/app/core/models/text_controller.dart';
import 'package:acoplan/app/core/services/hash_service.dart';

class FormaUtils {
  final TextController search = TextController();
}

class FormaCriarModel {
  final String id;
  TextController codigo = TextController();
  TextController descricao = TextController();
  String imagem = '';
  double rotacao = 0;
  List<FormaItemModel> itens = [];
  late bool is_edicao;

  /// fatorDobra calculado dinamicamente dos itens.
  double get fatorDobra => FormaModel.calcularFatorDobra(itens);

  FormaCriarModel()
      : id = HashService.get,
        is_edicao = false;

  FormaCriarModel.editar(FormaModel forma)
      : id = forma.id,
        is_edicao = true {
    codigo.text = forma.codigo;
    descricao.text = forma.descricao;
    imagem = forma.imagem;
    rotacao = forma.rotacao;
    itens = forma.itens
        .map((e) => FormaItemModel(
              trecho: e.trecho,
              comprimento: e.comprimento,
              angulo: e.angulo,
              orientacao: e.orientacao,
              tipo: e.tipo,
              grupoSimetria: e.grupoSimetria,
            ))
        .toList();
  }

  FormaModel toFormaModel() => FormaModel(
        id: id,
        codigo: codigo.text,
        descricao: descricao.text,
        imagem: imagem,
        rotacao: rotacao,
        itens: itens,
        fatorDobra: fatorDobra, // calculado dos itens ao salvar
      );
}
