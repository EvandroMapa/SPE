
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

  /// Desconto de dobra (multiplicador × diâmetro).
  /// Gerado automaticamente = fatorDobra × 2, mas editável.
  double descontoDobra = 0.0;
  bool descontoManual = false; // true = usuário editou manualmente

  /// Recalcula descontoDobra automaticamente (se não foi editado manualmente)
  void recalcularDesconto() {
    if (!descontoManual) {
      descontoDobra = fatorDobra * 2.0;
    }
  }

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
    descontoDobra = forma.descontoDobra;
    // Se já tem desconto salvo diferente do auto, é manual
    descontoManual = forma.descontoDobra > 0 && 
        (forma.descontoDobra - forma.fatorDobra * 2.0).abs() > 0.01;
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

  FormaModel toFormaModel() {
    // Se não foi manual, recalcula antes de salvar
    if (!descontoManual) {
      descontoDobra = fatorDobra * 2.0;
    }
    return FormaModel(
      id: id,
      codigo: codigo.text,
      descricao: descricao.text,
      imagem: imagem,
      rotacao: rotacao,
      itens: itens,
      fatorDobra: fatorDobra,
      descontoDobra: descontoDobra,
    );
  }
}
