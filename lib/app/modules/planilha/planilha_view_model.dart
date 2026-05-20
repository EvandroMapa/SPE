import 'package:acoplan/app/core/client/models/cliente_model.dart';
import 'package:acoplan/app/core/client/models/forma_model.dart';
import 'package:acoplan/app/core/client/models/planilha_model.dart';
import 'package:acoplan/app/core/client/models/produto_model.dart';
import 'package:acoplan/app/core/client/models/trecho_variavel_config.dart';
import 'package:acoplan/app/core/models/text_controller.dart';
import 'package:acoplan/app/core/services/hash_service.dart';

class PlanilhaCreateModel {
  final String id;
  int codigo = 0;
  ClienteModel? clienteSelecionado;
  ObraModel? obraSelecionada;
  List<ElementoCreateModel> elementos = [];
  late bool isEdit;

  PlanilhaCreateModel()
      : id = HashService.get,
        isEdit = false;

  PlanilhaCreateModel.edit(PlanilhaModel planilha)
      : id = planilha.id,
        isEdit = true {
    codigo = planilha.codigo;
    elementos = planilha.elementos
        .map((e) => ElementoCreateModel.fromModel(e))
        .toList();
  }

  PlanilhaModel toPlanilhaModel() => PlanilhaModel(
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
  ProdutoModel? bitolaSelecionada;
  FormaModel? formaSelecionada;
  TextController qtde = TextController();
  Map<String, int> comprimentos = {};
  Map<String, bool> variaveis = {};
  Map<String, TrechoVariavelConfig> variaveisConfig = {};
  int multiplicador = 1; // multiplicador da posição
  int comprimentoDeCorte = 0; // cm — base para cálculo de corte

  /// Recalcula comprimentoDeCorte usando fatorDobra da forma e diâmetro da bitola.
  /// Fórmula: soma_trechos − fatorDobra × 2 × diâmetro_cm
  /// Cada dobra de 90° desconta 1d de cada segmento adjacente = 2d por dobra no total.
  /// Exemplo: U 600×50×50cm + bitola 12,5mm (1,25cm):
  ///   fator=2 → 700 − 2×2×1,25 = 700 − 5 = 695cm ✓
  void calcularComprimentoDeCorte() {
    final somaCm = comprimentos.values.fold(0, (s, v) => s + v);
    final diametroCm = (bitolaSelecionada?.diametro ?? 0) / 10.0;
    final fator = formaSelecionada?.fatorDobra ?? 0.0;
    comprimentoDeCorte = (somaCm - fator * 2.0 * diametroCm).round().clamp(0, somaCm);
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
      );
}
