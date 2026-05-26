import 'package:acoplan/app/core/client/models/bitola_model.dart';
import 'package:acoplan/app/core/extensions/text_controller_ext.dart';
import 'package:acoplan/app/core/models/text_controller.dart';
import 'package:acoplan/app/core/services/hash_service.dart';

class BitolaUtils {
  final TextController search = TextController();
}

class BitolaCreateModel {
  final String id;
  TextController nome = TextController();
  TextController descricao = TextController();
  TextController massaFinal = TextController.number();
  TextController codigoFinanceiro = TextController();
  TextController diametro = TextController(); // mm
  int sortIndex = 999;
  late bool isEdit;

  BitolaCreateModel()
      : id = HashService.get,
        isEdit = false;

  BitolaCreateModel.edit(BitolaModel bitola)
      : id = bitola.id,
        isEdit = true {
    nome.text = bitola.nome;
    descricao.text = bitola.descricao;
    massaFinal = TextController.number(value: bitola.massaFinal);
    codigoFinanceiro.text = bitola.codigoFinanceiro;
    diametro.text = bitola.diametro > 0 ? bitola.diametro.toString() : '';
    sortIndex = bitola.sortIndex;
  }

  BitolaModel toBitolaModel() => BitolaModel(
        id: id,
        nome: nome.text,
        descricao: descricao.text,
        massaFinal: massaFinal.doubleValue,
        codigoFinanceiro: codigoFinanceiro.text,
        sortIndex: sortIndex,
        diametro: double.tryParse(diametro.text.replaceAll(',', '.')) ?? 0.0,
      );
}
