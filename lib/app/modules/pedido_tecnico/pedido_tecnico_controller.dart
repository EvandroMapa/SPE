import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/pedido_tecnico_model.dart';
import 'package:acoplan/app/core/client/models/detalhamento_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/pedido_tecnico/pedido_tecnico_view_model.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

final pedidoTecnicoCtrl = PedidoTecnicoController();

class PedidoTecnicoController {
  static final PedidoTecnicoController _instance =
      PedidoTecnicoController._();
  PedidoTecnicoController._();
  factory PedidoTecnicoController() => _instance;

  final AppStream<List<PedidoTecnicoModel>> pedidosStream =
      BackendClient.pedidosTecnicos.dataStream;

  List<PedidoTecnicoModel> get pedidos => pedidosStream.value;

  final AppStream<PedidoTecnicoCreateModel> formStream =
      AppStream<PedidoTecnicoCreateModel>();

  PedidoTecnicoCreateModel get form => formStream.value;

  // ── Inicializar formulário ─────────────────────────────
  void init(PedidoTecnicoModel? pedido) {
    if (pedido != null) {
      formStream.add(PedidoTecnicoCreateModel.fromPedido(pedido));
    } else {
      formStream.add(PedidoTecnicoCreateModel());
    }
  }

  // ── Retorna elementos do detalhamento com disponibilidade ─
  List<ElementoDetalhamentoViewModel> elementosComDisponibilidade(
      DetalhamentoModel detalhamento) {
    final ocupados = BackendClient.pedidosTecnicos.elementosEmPedidosAbertos;
    final alocados = BackendClient.pedidosTecnicos.quantidadesAlocadas(form.id);
    final pedidoAtualId = form.id;
    final bitolas = BackendClient.bitolas.data;

    final lista = <ElementoDetalhamentoViewModel>[];

    for (final elem in detalhamento.elementos) {
      // Calcular peso unitário (1 peça) a partir das posições
      // Usa o valor do banco se disponível, senão calcula on-the-fly
      final pesoUnitCalculado = elem.calcularPesoUnitario(bitolas);
      final pesoUnit = elem.pesoTotal > 0 && elem.quantidade > 0
          ? elem.pesoTotal / elem.quantidade
          : pesoUnitCalculado;

      // Itera sobre [pai, ...equivalentes] com a quantidade correta de cada um
      final todosEntries = <({String nome, int qtdeTotal})>[
        (nome: elem.nome, qtdeTotal: elem.quantidade),
        ...elem.elementosEquivalentes.map((e) => (nome: e.nome, qtdeTotal: e.quantidade)),
      ];

      for (final entry in todosEntries) {
        final nome = entry.nome;
        final qtdeElemento = entry.qtdeTotal;
        final chave = '${elem.id}_$nome';
        final qtdAlocada = alocados[chave] ?? 0;
        final qtdRestante = qtdeElemento - qtdAlocada;

        // 1. Tile de Disponível (para a quantidade livre ou que o pedido atual está manipulando)
        if (qtdRestante > 0) {
          final elemClonado = ElementoModel(
            id: elem.id,
            nome: nome,
            quantidade: qtdRestante,
            pesoTotal: pesoUnit * qtdRestante,
            posicoes: elem.posicoes,
            elementosEquivalentes: const [],
          );
          lista.add(ElementoDetalhamentoViewModel(
            elemento: elemClonado,
            disponibilidade: DisponibilidadeElemento.disponivel,
          ));
        }

        // 2. Tiles Bloqueados (um para cada OUTRO pedido que segurou pedaços desse elemento)
        final pedidosOcupantes = ocupados[chave] ?? [];
        for (final p in pedidosOcupantes) {
          if (pedidoAtualId != null && p.id == pedidoAtualId) continue;
          
          int qtdeNoPedido = 0;
          for (final eNoPedido in p.elementos) {
            if ('${eNoPedido.elementoId}_${eNoPedido.elementoNome}' == chave) {
              qtdeNoPedido = eNoPedido.quantidadeSolicitada;
              break;
            }
          }

          if (qtdeNoPedido > 0) {
            final elemClonado = ElementoModel(
              id: elem.id,
              nome: nome,
              quantidade: qtdeNoPedido,
              pesoTotal: pesoUnit * qtdeNoPedido,
              posicoes: elem.posicoes,
              elementosEquivalentes: const [],
            );
            lista.add(ElementoDetalhamentoViewModel(
              elemento: elemClonado,
              disponibilidade: DisponibilidadeElemento.emPedido,
              identificadorPedidoOcupante: p.identificador,
            ));
          }
        }
      }
    }

    return lista;
  }

  // ── Salvar (criar ou atualizar) ───────────────────────
  Future<bool> salvar({bool auto = false}) async {
    if (form.detalhamentoId.isEmpty) {
      if (!auto) {
        NotificationService.showNegative(
          'Selecione um detalhamento',
          'Escolha o detalhamento antes de gerar o pedido',
          position: NotificationPosition.bottom,
        );
      }
      return false;
    }
    try {
      final model = form.toPedidoTecnicoModel();

      // Calcular resumo de aço (totais por bitola e elemento)
      final resumoAco = _calcularResumoAco(model);
      final modelComResumo = model.copyWith(resumoAco: resumoAco);

      if (form.isEdit) {
        await BackendClient.pedidosTecnicos.atualizar(modelComResumo);
        await BackendClient.pedidosTecnicos
            .atualizarElementos(modelComResumo.id, modelComResumo.elementos,
                resumoAco: resumoAco);
        if (!auto) {
          NotificationService.showPositive(
            'Pedido atualizado',
            '${model.elementos.length} elemento(s) no pedido ${model.codigo}',
            position: NotificationPosition.bottom,
          );
        }
      } else {
        final createdModel =
            await BackendClient.pedidosTecnicos.criar(modelComResumo);
        form.id = createdModel.id;
        form.codigo = createdModel.codigo;
        form.identificador = createdModel.identificador;
        formStream.update();
        if (!auto) {
          NotificationService.showPositive(
            'Pedido criado',
            '${model.elementos.length} elemento(s) cadastrado(s)',
            position: NotificationPosition.bottom,
          );
        }
      }
      return true;
    } catch (e) {
      if (!auto) {
        NotificationService.showNegative(
          'Erro ao salvar',
          e.toString(),
          position: NotificationPosition.bottom,
        );
      }
      return false;
    }
  }

  /// Calcula o resumo de aço do pedido técnico:
  /// - Peso total por bitola (para importação no PCP)
  /// - Peso total por elemento (corrigido, sem inflação de equivalentes)
  /// Usa a MESMA lógica de calcularPesoUnitario (com variáveis peça a peça),
  /// acumulando por bitolaNome, garantindo Σ bitolas == Σ elementos.
  Map<String, dynamic> _calcularResumoAco(PedidoTecnicoModel pedido) {
    final detalhamento = BackendClient.detalhamentos.data
        .where((d) => d.id == pedido.detalhamentoId)
        .firstOrNull;
    if (detalhamento == null) return {};

    final bitolas = BackendClient.bitolas.data;
    final resumoBitolas = <String, Map<String, double>>{};
    final resumoElementos = <String, Map<String, dynamic>>{};

    for (final elem in pedido.elementos) {
      final elemDet = detalhamento.elementos
          .where((e) => e.id == elem.elementoId)
          .firstOrNull;
      if (elemDet == null) continue;

      final qtdeElem = elem.quantidadeSolicitada;
      double pesoElemento = 0;

      // Calcular peso por posição (mesma lógica de calcularPesoUnitario)
      for (final pos in elemDet.posicoes) {
        final bitolaNome = pos.bitolaNome;

        // Massa linear da bitola
        final bitolaModel =
            bitolas.where((b) => b.id == pos.bitolaId).firstOrNull;
        double massaLinear;
        if (bitolaModel != null && bitolaModel.massaFinal > 0) {
          massaLinear = bitolaModel.massaFinal;
        } else {
          final str =
              pos.bitolaNome.split('-').first.replaceAll(RegExp(r'[^0-9.]'), '');
          final d = double.tryParse(str) ?? 0;
          massaLinear = (d * d) / 162;
        }
        if (massaLinear <= 0) continue;

        // ── Peso unitário desta posição (1 unidade do elemento) ──
        // Mesma lógica de calcularPesoUnitario: trata variáveis peça a peça
        double pesoPosUnit = 0;
        final temVar = pos.variaveisConfig.isNotEmpty &&
            pos.variaveis.values.any((v) => v);

        if (!temVar) {
          final somaCm =
              pos.comprimentos.values.fold<double>(0.0, (s, v) => s + v);
          pesoPosUnit = (somaCm / 100.0) * massaLinear * pos.qtde;
        } else {
          // Calcula peça a peça (cada peça pode ter comprimento diferente)
          for (int peca = 0; peca < pos.qtde; peca++) {
            double somaCm = 0.0;
            for (final entry in pos.comprimentos.entries) {
              final trecho = entry.key;
              final isVar = pos.variaveis[trecho] ?? false;
              if (isVar) {
                final config = pos.variaveisConfig[trecho] ??
                    pos.variaveisConfig.values.firstOrNull;
                if (config != null &&
                    config.inicial > 0 &&
                    config.final_ > 0) {
                  final expandidas =
                      config.medidasExpandidas(pos.multiplicador);
                  somaCm += peca < expandidas.length
                      ? expandidas[peca].toDouble()
                      : (expandidas.isNotEmpty ? expandidas.last.toDouble() : 0.0);
                } else {
                  somaCm += entry.value;
                }
              } else {
                somaCm += entry.value;
              }
            }
            pesoPosUnit += (somaCm / 100.0) * massaLinear;
          }
        }

        // Peso total da posição = unitário × qtde do elemento
        final pesoPosTotal = pesoPosUnit * qtdeElem;
        pesoElemento += pesoPosTotal;

        // Comprimento total (sem variáveis — valor de referência)
        final somaCmRef =
            pos.comprimentos.values.fold<double>(0.0, (s, v) => s + v);
        final compM = (somaCmRef * pos.qtde * qtdeElem) / 100.0;

        // Acumular por bitola
        final atual = resumoBitolas[bitolaNome];
        resumoBitolas[bitolaNome] = {
          'peso': (atual?['peso'] ?? 0) + pesoPosTotal,
          'comprimento_m': (atual?['comprimento_m'] ?? 0) + compM,
        };
      }

      // Peso do elemento = soma dos pesos das posições (consistente com bitolas)
      resumoElementos[elem.elementoNome] = {
        'peso': double.parse(pesoElemento.toStringAsFixed(2)),
        'qtde': qtdeElem,
        'elemento_id': elem.elementoId,
      };
    }

    // Arredondar bitolas para 2 casas
    for (final key in resumoBitolas.keys) {
      resumoBitolas[key] = {
        'peso': double.parse(
            (resumoBitolas[key]!['peso']!).toStringAsFixed(2)),
        'comprimento_m': double.parse(
            (resumoBitolas[key]!['comprimento_m']!).toStringAsFixed(2)),
      };
    }

    final pesoTotal = resumoBitolas.values
        .fold<double>(0, (s, v) => s + (v['peso'] ?? 0));

    return {
      'bitolas': resumoBitolas,
      'elementos': resumoElementos,
      'peso_total': double.parse(pesoTotal.toStringAsFixed(2)),
    };
  }

  // ── Excluir ───────────────────────────────────────────
  Future<void> onDelete(BuildContext context, PedidoTecnicoModel pedido) async {
    try {
      await BackendClient.pedidosTecnicos.delete(pedido);
      NotificationService.showPositive(
        'Pedido excluído',
        'Os elementos voltaram a ficar disponíveis',
        position: NotificationPosition.bottom,
      );
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao excluir',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }

  // ── Cancelar / reabrir ───────────────────────────────
  Future<void> cancelar(String pedidoId) async {
    try {
      await BackendClient.pedidosTecnicos.cancelar(pedidoId);
      NotificationService.showNeutral(
        'Pedido cancelado',
        'Os elementos estão disponíveis novamente',
        position: NotificationPosition.bottom,
      );
    } catch (e) {
      NotificationService.showNegative('Erro', e.toString(),
          position: NotificationPosition.bottom);
    }
  }

  Future<void> reabrir(String pedidoId) async {
    try {
      await BackendClient.pedidosTecnicos.reabrir(pedidoId);
      NotificationService.showPositive(
        'Pedido reaberto',
        'Status alterado para aberto',
        position: NotificationPosition.bottom,
      );
    } catch (e) {
      NotificationService.showNegative('Erro', e.toString(),
          position: NotificationPosition.bottom);
    }
  }
}
