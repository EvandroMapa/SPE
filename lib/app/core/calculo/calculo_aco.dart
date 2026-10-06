import 'package:acoplan/app/core/client/models/bitola_model.dart';
import 'package:acoplan/app/core/client/models/detalhamento_model.dart';

/// Fonte única dos cálculos de aço (massa linear, comprimentos e pesos).
///
/// Todas as telas, PDFs e o resumo de aço do pedido devem usar esta classe,
/// para que o peso exibido seja sempre o mesmo em qualquer lugar.
///
/// Convenções:
/// - Comprimentos em cm, massa linear em kg/m, pesos em kg.
/// - O peso usa a SOMA DOS TRECHOS (medida externa), não o comprimento de
///   corte — decisão de negócio intencional.
/// - "Peso da posição" = todas as peças da posição para 1 unidade do elemento.
class CalculoAco {
  CalculoAco._();

  /// Massa linear (kg/m) da bitola. Usa a massa cadastrada; se não houver,
  /// cai na fórmula d²/162 extraída do nome da bitola (ex: "12.5 - CA50").
  static double massaLinear({
    required String bitolaId,
    required String bitolaNome,
    required Iterable<BitolaModel> bitolas,
  }) {
    for (final b in bitolas) {
      if (b.id == bitolaId) {
        if (b.massaFinal > 0) return b.massaFinal;
        break;
      }
    }
    final str = bitolaNome.split('-').first.replaceAll(RegExp(r'[^0-9.]'), '');
    final d = double.tryParse(str) ?? 0;
    return (d * d) / 162;
  }

  static double massaLinearPosicao(PosicaoModel pos, Iterable<BitolaModel> bitolas) =>
      massaLinear(bitolaId: pos.bitolaId, bitolaNome: pos.bitolaNome, bitolas: bitolas);

  static bool temTrechoVariavel(PosicaoModel pos) =>
      pos.variaveisConfig.isNotEmpty && pos.variaveis.values.any((v) => v);

  /// Soma simples dos trechos (cm) — comprimento de 1 peça sem variação.
  static double somaTrechos(PosicaoModel pos) =>
      pos.comprimentos.values.fold<double>(0.0, (s, v) => s + v);

  /// Comprimento (cm) de cada peça da posição, considerando trechos variáveis.
  ///
  /// Trecho variável sem config própria usa a config do líder do grupo de
  /// simetria (primeira config cadastrada). Se a lista expandida for menor que
  /// a quantidade, as peças excedentes repetem a última medida.
  static List<double> comprimentosPorPeca(PosicaoModel pos) {
    final qtde = pos.qtde;
    if (qtde <= 0) return const [];

    if (!temTrechoVariavel(pos)) {
      return List<double>.filled(qtde, somaTrechos(pos));
    }

    final expandidasPorTrecho = <String, List<int>>{};
    for (final trecho in pos.comprimentos.keys) {
      if (!(pos.variaveis[trecho] ?? false)) continue;
      final config = pos.variaveisConfig[trecho] ?? pos.variaveisConfig.values.firstOrNull;
      if (config == null || config.inicial <= 0 || config.final_ <= 0) continue;
      final expandidas = config.medidasExpandidas(pos.multiplicador);
      if (expandidas.isNotEmpty) expandidasPorTrecho[trecho] = expandidas;
    }

    return List<double>.generate(qtde, (peca) {
      double somaCm = 0.0;
      for (final entry in pos.comprimentos.entries) {
        final expandidas = expandidasPorTrecho[entry.key];
        if (expandidas == null) {
          somaCm += entry.value; // trecho fixo ou variável sem config válida
        } else {
          somaCm += (peca < expandidas.length ? expandidas[peca] : expandidas.last).toDouble();
        }
      }
      return somaCm;
    });
  }

  /// Comprimento total (cm) de todas as peças da posição (1 unidade do elemento).
  static double comprimentoTotalPosicao(PosicaoModel pos) =>
      comprimentosPorPeca(pos).fold<double>(0.0, (s, v) => s + v);

  /// Peso (kg) de todas as peças da posição para 1 unidade do elemento.
  static double pesoPosicao(PosicaoModel pos, Iterable<BitolaModel> bitolas) {
    final w = massaLinearPosicao(pos, bitolas);
    if (w <= 0 || pos.qtde <= 0) return 0;
    return comprimentoTotalPosicao(pos) / 100.0 * w;
  }

  /// Peso (kg) de 1 unidade do elemento = soma dos pesos das posições.
  static double pesoUnitarioElemento(ElementoModel elem, Iterable<BitolaModel> bitolas) =>
      elem.posicoes.fold<double>(0.0, (s, p) => s + pesoPosicao(p, bitolas));

  /// Peso (kg) do elemento considerando pai + equivalentes.
  static double pesoTotalElemento(ElementoModel elem, Iterable<BitolaModel> bitolas) =>
      pesoUnitarioElemento(elem, bitolas) * elem.quantidadeExpandida;

  /// Peso (kg) total do detalhamento.
  static double pesoTotalDetalhamento(DetalhamentoModel det, Iterable<BitolaModel> bitolas) =>
      det.elementos.fold<double>(0.0, (s, e) => s + pesoTotalElemento(e, bitolas));
}
