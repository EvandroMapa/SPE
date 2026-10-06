import 'package:acoplan/app/core/calculo/calculo_aco.dart';
import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/cliente_model.dart';
import 'package:acoplan/app/core/client/models/forma_model.dart';
import 'package:acoplan/app/core/client/models/detalhamento_model.dart';
import 'package:acoplan/app/core/client/models/bitola_model.dart';
import 'package:acoplan/app/core/client/models/trecho_variavel_config.dart';
import 'package:acoplan/app/core/client/models/usuario_model.dart';
import 'package:acoplan/app/core/models/text_controller.dart';
import 'package:acoplan/app/core/services/hash_service.dart';

class DetalhamentoCreateModel {
  String id;
  int codigo = 0;
  ClienteModel? clienteSelecionado;
  ObraModel? obraSelecionada;
  List<ElementoCreateModel> elementos = [];
  late bool isEdit;
  String desenho = '';
  String pavimento = '';
  UsuarioModel? funcionarioSelecionado;

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
    desenho = detalhamento.desenho;
    pavimento = detalhamento.pavimento;
  }

  DetalhamentoModel toDetalhamentoModel() => DetalhamentoModel(
        id: id,
        codigo: codigo,
        clienteId: clienteSelecionado?.id ?? '',
        clienteNome: clienteSelecionado?.nome ?? '',
        obraId: obraSelecionada?.id ?? '',
        obraNome: obraSelecionada?.descricao ?? '',
        elementos: elementos.map((e) => e.toElementoModel()).toList(),
        desenho: desenho,
        pavimento: pavimento,
        funcionarioId: funcionarioSelecionado?.id ?? '',
        funcionarioNome: funcionarioSelecionado?.nome ?? '',
      );
}

class ElementoCreateModel {
  String id;
  TextController nome = TextController();
  TextController quantidade = TextController();
  List<PosicaoCreateModel> posicoes = [];
  List<EquivalenteModel> elementosEquivalentes = [];

  ElementoCreateModel() : id = HashService.get;

  ElementoCreateModel.fromModel(ElementoModel modelo) : id = modelo.id {
    nome.text = modelo.nome;
    quantidade.text = modelo.quantidade > 0 ? modelo.quantidade.toString() : '';
    posicoes = modelo.posicoes
        .map((p) => PosicaoCreateModel.fromModel(p))
        .toList();
    elementosEquivalentes = List.from(modelo.elementosEquivalentes);
  }

  /// Quantidade do pai + soma das quantidades dos equivalentes.
  int get quantidadeTotal =>
      (int.tryParse(quantidade.text) ?? 0) +
      elementosEquivalentes.fold<int>(0, (s, e) => s + e.quantidade);

  /// Peso de 1 unidade do elemento (soma dos pesos das posições).
  double pesoUnitario([Iterable<BitolaModel>? bitolas]) {
    final b = bitolas ?? BackendClient.bitolas.data;
    return posicoes.fold<double>(0, (s, p) => s + p.pesoTotal(b));
  }

  /// Peso total do elemento (pai + equivalentes).
  double get pesoTotal => pesoUnitario() * quantidadeTotal;

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
  Map<String, double> comprimentos = {};
  Map<String, bool> variaveis = {};
  Map<String, TrechoVariavelConfig> variaveisConfig = {};
  int multiplicador = 1;
  double comprimentoDeCorte = 0;
  int ordem = 0; // índice para ordenação persistida
  /// Snapshot do descontoDobra capturado no momento em que a forma foi selecionada.
  /// null = registro antigo (fallback para o valor atual da forma).
  double? descontoDobraSnapshot;
  /// Snapshot completo da forma (desenho, ângulos, rotação) no momento da seleção.
  /// null = registro antigo. Usado em relatórios futuros.
  Map<String, dynamic>? formaSnapshot;

  /// Recalcula comprimentoDeCorte usando descontoDobra da forma e diâmetro da bitola.
  /// Usa o snapshot armazenado; se null (registro antigo), usa o valor atual da forma.
  /// Fórmula: soma_trechos − descontoDobra × diâmetro_cm
  void calcularComprimentoDeCorte() {
    final somaCm = comprimentos.values.fold(0.0, (s, v) => s + v);
    final diametroCm = (bitolaSelecionada?.diametro ?? 0) / 10.0;
    final desconto = descontoDobraSnapshot ?? formaSelecionada?.descontoDobra ?? 0.0;
    final resultado = somaCm - desconto * diametroCm;
    // 1 casa decimal, não pode ser negativo nem maior que a soma
    comprimentoDeCorte = double.parse(resultado.clamp(0.0, somaCm).toStringAsFixed(1));
  }

  PosicaoCreateModel() : id = HashService.get;

  /// Peso de 1 peça sem considerar variação (soma dos trechos × massa linear).
  double pesoPeca([Iterable<BitolaModel>? bitolas]) {
    final m = toPosicaoModel();
    return CalculoAco.somaTrechos(m) / 100.0 *
        CalculoAco.massaLinearPosicao(m, bitolas ?? BackendClient.bitolas.data);
  }

  /// Peso de todas as peças da posição (1 unidade do elemento).
  double pesoTotal([Iterable<BitolaModel>? bitolas]) =>
      CalculoAco.pesoPosicao(toPosicaoModel(), bitolas ?? BackendClient.bitolas.data);

  bool get temTrechoVariavel => CalculoAco.temTrechoVariavel(toPosicaoModel());

  PosicaoCreateModel.fromModel(PosicaoModel modelo) : id = modelo.id {
    posicao.text = modelo.posicao;
    qtde.text = modelo.qtde > 0 ? modelo.qtde.toString() : '';
    comprimentos = Map<String, double>.from(modelo.comprimentos);
    variaveis = Map<String, bool>.from(modelo.variaveis);
    variaveisConfig = modelo.variaveisConfig.map((k, v) => MapEntry(k, v.copyWith()));
    multiplicador = modelo.multiplicador;
    comprimentoDeCorte = (modelo.comprimentoDeCorte as num).toDouble();
    ordem = modelo.ordem;
    // Restaura o snapshot armazenado — preserva o valor histórico da forma
    descontoDobraSnapshot = modelo.descontoDobraSnapshot;
    formaSnapshot = modelo.formaSnapshot != null
        ? Map<String, dynamic>.from(modelo.formaSnapshot!)
        : null;
  }

  PosicaoModel toPosicaoModel() => PosicaoModel(
        id: id,
        posicao: posicao.text.trim(),
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
        descontoDobraSnapshot: descontoDobraSnapshot,
        formaSnapshot: formaSnapshot,
      );
}
