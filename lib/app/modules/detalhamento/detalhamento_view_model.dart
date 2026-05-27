import 'package:acoplan/app/core/client/models/cliente_model.dart';
import 'package:acoplan/app/core/client/models/forma_model.dart';
import 'package:acoplan/app/core/client/models/detalhamento_model.dart';
import 'package:acoplan/app/core/client/models/bitola_model.dart';
import 'package:acoplan/app/core/client/models/trecho_variavel_config.dart';
import 'package:acoplan/app/core/models/text_controller.dart';
import 'package:acoplan/app/core/services/hash_service.dart';

class DetalhamentoCreateModel {
  final String id;
  int codigo = 0;
  ClienteModel? clienteSelecionado;
  ObraModel? obraSelecionada;
  List<ElementoCreateModel> elementos = [];
  late bool isEdit;

  DetalhamentoCreateModel()
      : id = HashService.get,
        isEdit = false;

  DetalhamentoCreateModel.edit(DetalhamentoModel detalhamento)
      : id = detalhamento.id,
        isEdit = true {
    codigo = detalhamento.codigo;
    elementos = detalhamento.elementos
        .map((e) => ElementoCreateModel.fromModel(e))
        .toList();
  }

  DetalhamentoModel toDetalhamentoModel() => DetalhamentoModel(
        id: id,
        codigo: codigo,
        clienteId: clienteSelecionado?.id ?? '',
        clienteNome: clienteSelecionado?.nome ?? '',
        obraId: obraSelecionada?.id ?? '',
        obraNome: obraSelecionada?.descricao ?? '',
        elementos: elementos.map((e) => e.toElementoModel()).toList(),
      );
}

class ElementoCreateModel {
  String id;
  TextController nome = TextController();
  TextController quantidade = TextController();
  List<PosicaoCreateModel> posicoes = [];
  List<String> elementosEquivalentes = [];

  ElementoCreateModel() : id = HashService.get;

  ElementoCreateModel.fromModel(ElementoModel modelo) : id = modelo.id {
    nome.text = modelo.nome;
    quantidade.text = modelo.quantidade > 0 ? modelo.quantidade.toString() : '';
    posicoes = modelo.posicoes
        .map((p) => PosicaoCreateModel.fromModel(p))
        .toList();
    elementosEquivalentes = List.from(modelo.elementosEquivalentes);
  }

  /// Peso total = soma dos pesos das posições (a ser calculado futuramente)
  double get pesoTotal => 0; // TODO: calcular a partir das posições

  ElementoModel toElementoModel() => ElementoModel(
        id: id,
        nome: nome.text,
        quantidade: int.tryParse(quantidade.text) ?? 0,
        pesoTotal: pesoTotal,
        posicoes: posicoes.map((p) => p.toPosicaoModel()).toList(),
        elementosEquivalentes: List.from(elementosEquivalentes),
      );
}

class PosicaoCreateModel {
  String id;
  TextController posicao = TextController();
  BitolaModel? bitolaSelecionada;
  FormaModel? formaSelecionada;
  TextController qtde = TextController();
  Map<String, int> comprimentos = {};
  Map<String, bool> variaveis = {};
  Map<String, TrechoVariavelConfig> variaveisConfig = {};
  int multiplicador = 1;
  int comprimentoDeCorte = 0;
  int ordem = 0; // índice para ordenação persistida

  /// Recalcula comprimentoDeCorte usando descontoDobra da forma e diâmetro da bitola.
  /// Fórmula: soma_trechos − descontoDobra × diâmetro_cm
  /// O descontoDobra é configurado na forma (editável), padrão = fatorDobra × 2.
  void calcularComprimentoDeCorte() {
    final somaCm = comprimentos.values.fold(0, (s, v) => s + v);
    final diametroCm = (bitolaSelecionada?.diametro ?? 0) / 10.0;
    final desconto = formaSelecionada?.descontoDobra ?? 0.0;
    comprimentoDeCorte = (somaCm - desconto * diametroCm).round().clamp(0, somaCm);
  }

  PosicaoCreateModel() : id = HashService.get;

  PosicaoCreateModel.fromModel(PosicaoModel modelo) : id = modelo.id {
    posicao.text = modelo.posicao > 0 ? modelo.posicao.toString() : '';
    qtde.text = modelo.qtde > 0 ? modelo.qtde.toString() : '';
    comprimentos = Map<String, int>.from(modelo.comprimentos);
    variaveis = Map<String, bool>.from(modelo.variaveis);
    variaveisConfig = modelo.variaveisConfig.map((k, v) => MapEntry(k, v.copyWith()));
    multiplicador = modelo.multiplicador;
    comprimentoDeCorte = modelo.comprimentoDeCorte;
    ordem = modelo.ordem;
  }

  PosicaoModel toPosicaoModel() => PosicaoModel(
        id: id,
        posicao: int.tryParse(posicao.text) ?? 0,
        bitolaId: bitolaSelecionada?.id ?? '',
        bitolaNome: bitolaSelecionada?.label ?? '',
        formaId: formaSelecionada?.id ?? '',
        formaCodigo: formaSelecionada?.codigo ?? '',
        qtde: int.tryParse(qtde.text) ?? 0,
        comprimentos: comprimentos,
        variaveis: variaveis,
        variaveisConfig: variaveisConfig,
        multiplicador: multiplicador,
        comprimentoDeCorte: comprimentoDeCorte,
        ordem: ordem,
      );
}
