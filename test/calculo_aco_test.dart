import 'dart:convert';

import 'package:acoplan/app/core/calculo/calculo_aco.dart';
import 'package:acoplan/app/core/client/models/bitola_model.dart';
import 'package:acoplan/app/core/client/models/detalhamento_model.dart';
import 'package:acoplan/app/core/client/models/pedido_tecnico_model.dart';
import 'package:acoplan/app/core/client/models/trecho_variavel_config.dart';
import 'package:flutter_test/flutter_test.dart';

final bitolas = [
  BitolaModel(id: 'b10', nome: '10.0', descricao: 'CA50', massaFinal: 0.617, diametro: 10),
  BitolaModel(id: 'b8sem', nome: '8.0', descricao: 'CA50', massaFinal: 0, diametro: 8),
];

PosicaoModel pos({
  String bitolaId = 'b10',
  String bitolaNome = '10.0 - CA50',
  int qtde = 1,
  Map<String, double> comprimentos = const {'T1': 100},
  Map<String, bool> variaveis = const {},
  Map<String, TrechoVariavelConfig> variaveisConfig = const {},
  int multiplicador = 1,
}) =>
    PosicaoModel(
      id: 'p',
      posicao: '1',
      bitolaId: bitolaId,
      bitolaNome: bitolaNome,
      formaId: '',
      formaCodigo: '',
      qtde: qtde,
      comprimentos: comprimentos,
      variaveis: variaveis,
      variaveisConfig: variaveisConfig,
      multiplicador: multiplicador,
    );

void main() {
  group('massaLinear', () {
    test('usa a massa cadastrada da bitola', () {
      expect(CalculoAco.massaLinearPosicao(pos(), bitolas), 0.617);
    });

    test('bitola sem massa cadastrada cai na fórmula d²/162', () {
      final m = CalculoAco.massaLinearPosicao(pos(bitolaId: 'b8sem', bitolaNome: '8.0 - CA50'), bitolas);
      expect(m, closeTo(64 / 162, 1e-9));
    });

    test('bitola desconhecida usa o diâmetro do nome', () {
      final m = CalculoAco.massaLinearPosicao(pos(bitolaId: 'x', bitolaNome: '12.5 - CA50'), bitolas);
      expect(m, closeTo(12.5 * 12.5 / 162, 1e-9));
    });
  });

  group('posição sem trechos variáveis', () {
    test('peso = soma dos trechos × massa × qtde', () {
      final p = pos(qtde: 4, comprimentos: {'T1': 30, 'T2': 120, 'T3': 30});
      expect(CalculoAco.pesoPosicao(p, bitolas), closeTo(1.8 * 0.617 * 4, 1e-9));
      expect(CalculoAco.comprimentoTotalPosicao(p), 720);
    });

    test('quantidade zero não pesa', () {
      expect(CalculoAco.pesoPosicao(pos(qtde: 0), bitolas), 0);
      expect(CalculoAco.comprimentosPorPeca(pos(qtde: 0)), isEmpty);
    });
  });

  group('trechos variáveis', () {
    test('calcula peça a peça com multiplicador', () {
      final config = TrechoVariavelConfig(inicial: 100, final_: 200)..gerarLinear(6, multiplicador: 2);
      final p = pos(
        qtde: 6,
        comprimentos: {'T1': 10, 'T2': 150},
        variaveis: {'T2': true},
        variaveisConfig: {'T2': config},
        multiplicador: 2,
      );
      // medidas [100,150,200] × 2 → [100,100,150,150,200,200] + 10 fixo
      expect(CalculoAco.comprimentosPorPeca(p), [110, 110, 160, 160, 210, 210]);
      expect(CalculoAco.comprimentoTotalPosicao(p), 960);
      expect(CalculoAco.pesoPosicao(p, bitolas), closeTo(9.6 * 0.617, 1e-9));
    });

    test('peças além da lista repetem a última medida', () {
      final config = TrechoVariavelConfig(inicial: 100, final_: 200, medidas: [100, 200]);
      final p = pos(qtde: 3, comprimentos: {'T1': 0}, variaveis: {'T1': true}, variaveisConfig: {'T1': config});
      expect(CalculoAco.comprimentosPorPeca(p), [100, 200, 200]);
    });

    test('trecho variável sem config própria usa a do líder do grupo', () {
      final lider = TrechoVariavelConfig(inicial: 50, final_: 60, medidas: [50, 60]);
      final p = pos(
        qtde: 2,
        comprimentos: {'T1': 0, 'T3': 0},
        variaveis: {'T1': true, 'T3': true},
        variaveisConfig: {'T1': lider},
      );
      expect(CalculoAco.comprimentosPorPeca(p), [100, 120]);
    });

    test('config incompleta usa o valor fixo do trecho', () {
      final p = pos(
        qtde: 2,
        comprimentos: {'T1': 80},
        variaveis: {'T1': true},
        variaveisConfig: {'T1': TrechoVariavelConfig(inicial: 0, final_: 100)},
      );
      expect(CalculoAco.comprimentosPorPeca(p), [80, 80]);
    });
  });

  group('elemento e detalhamento', () {
    final elem = ElementoModel(
      id: 'e1',
      nome: 'V101',
      quantidade: 2,
      pesoTotal: -999, // valor gravado no banco é ignorado
      posicoes: [pos(qtde: 2, comprimentos: {'T1': 100})],
      elementosEquivalentes: const [EquivalenteModel(nome: 'V105', quantidade: 3)],
    );

    test('peso unitário e total (pai + equivalentes)', () {
      expect(CalculoAco.pesoUnitarioElemento(elem, bitolas), closeTo(2 * 0.617, 1e-9));
      expect(CalculoAco.pesoTotalElemento(elem, bitolas), closeTo(5 * 2 * 0.617, 1e-9));
      expect(elem.calcularPesoTotal(bitolas), CalculoAco.pesoTotalElemento(elem, bitolas));
    });

    test('peso do detalhamento soma os elementos', () {
      final det = DetalhamentoModel(
        id: 'd', codigo: 1, clienteId: '', clienteNome: '', obraId: '', obraNome: '',
        elementos: [elem, elem],
      );
      expect(det.pesoCalculado(bitolas), closeTo(2 * 5 * 2 * 0.617, 1e-9));
    });
  });

  group('snapshot do pedido', () {
    final elemOriginal = ElementoModel(
      id: 'e1',
      nome: 'V101',
      quantidade: 2,
      pesoTotal: 0,
      posicoes: [pos(qtde: 2, comprimentos: {'T1': 100})],
    );
    final elemEditado = ElementoModel(
      id: 'e1',
      nome: 'V101',
      quantidade: 2,
      pesoTotal: 0,
      posicoes: [pos(qtde: 9, comprimentos: {'T1': 999})],
    );
    final outro = ElementoModel(id: 'e2', nome: 'P1', quantidade: 1, pesoTotal: 0, posicoes: const []);
    DetalhamentoModel det(List<ElementoModel> elementos) => DetalhamentoModel(
          id: 'd', codigo: 1, clienteId: '', clienteNome: '', obraId: '', obraNome: '', elementos: elementos);

    PedidoTecnicoModel pedido(Map<String, dynamic>? snapshot) => PedidoTecnicoModel(
          id: 'p', codigo: 1, identificador: 'X.001', detalhamentoId: 'd', detalhamentoCodigo: 1,
          clienteId: '', clienteNome: '', obraId: '', obraNome: '', status: 'aberto', observacao: '',
          criadoEm: DateTime(2026),
          elementos: [
            PedidoTecnicoElementoModel(
              id: '', pedidoId: 'p', elementoId: 'e1', elementoNome: 'V101', elementoQuantidade: 2,
              pesoTotal: 0, elementoSnapshot: snapshot),
          ],
        );

    test('reimpressão usa o elemento como estava quando o pedido foi salvo', () {
      final efetivo = pedido(elemOriginal.toMap()).detalhamentoDoPedido(det([elemEditado, outro]))!;
      final e1 = efetivo.elementos.firstWhere((e) => e.id == 'e1');
      expect(e1.posicoes.single.qtde, 2);
      expect(e1.posicoes.single.comprimentos['T1'], 100);
      expect(efetivo.elementos.map((e) => e.id), ['e1', 'e2']);
    });

    test('pedido antigo (sem snapshot) usa o detalhamento atual', () {
      final atual = det([elemEditado]);
      expect(pedido(null).detalhamentoDoPedido(atual), same(atual));
    });

    test('elemento excluído do detalhamento continua no pedido pelo snapshot', () {
      final efetivo = pedido(elemOriginal.toMap()).detalhamentoDoPedido(det([outro]))!;
      expect(efetivo.elementos.map((e) => e.id), containsAll(['e1', 'e2']));
    });

    test('snapshot sobrevive ao JSON do banco', () {
      final row = pedido(elemOriginal.toMap()).elementos.single.toSupabaseMap('p');
      final json = jsonDecode(jsonEncode(row)) as Map<String, dynamic>;
      final lido = PedidoTecnicoElementoModel.fromSupabaseMap(json);
      expect(lido.elementoDoSnapshot!.posicoes.single.comprimentos['T1'], 100);
    });
  });
}
