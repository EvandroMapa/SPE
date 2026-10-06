import 'package:acoplan/app/core/calculo/calculo_aco.dart';
import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/pedido_tecnico_model.dart';
import 'package:acoplan/app/core/client/models/detalhamento_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/pedido_tecnico/pedido_tecnico_view_model.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

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
      // Peso unitário (1 peça) sempre calculado a partir das posições
      final pesoUnit = CalculoAco.pesoUnitarioElemento(elem, bitolas);

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

      // ── Calcular sequenciaInicio por elemento ──────────────────────────────
      // Ordena os elementos por nome (ordem natural: V1, V2, V10...) para garantir
      // sequência coerente com o relatório e etiquetas, e acumula o contador pelas
      // posições (com qtde > 0).
      final detalhamento = BackendClient.detalhamentos.data
          .where((d) => d.id == form.detalhamentoId)
          .firstOrNull;

      final elementosOrdenados = List<PedidoTecnicoElementoModel>.from(model.elementos)
        ..sort((a, b) => compararNatural(a.elementoNome, b.elementoNome));

      int seq = 1;
      final elementosComSeq = elementosOrdenados.map((elem) {
        final ini = seq;
        final elemDet = detalhamento?.elementos
            .where((e) => e.id == elem.elementoId)
            .firstOrNull;
        final numPos = elemDet?.posicoes.where((p) => p.qtde > 0).length ?? 0;
        seq += numPos > 0 ? numPos : 1; // reserva ao menos 1 slot mesmo sem posições
        return PedidoTecnicoElementoModel(
          id: elem.id,
          pedidoId: elem.pedidoId,
          elementoId: elem.elementoId,
          elementoNome: elem.elementoNome,
          elementoQuantidade: elem.elementoQuantidade,
          quantidadeSolicitada: elem.quantidadeSolicitada,
          pesoTotal: elem.pesoTotal,
          sequenciaInicio: ini,
          // Snapshot do elemento: reimpressões futuras não mudam se o
          // detalhamento for editado depois.
          elementoSnapshot: elemDet?.toMap(),
        );
      }).toList();

      // Editar não reabre um pedido cancelado
      final statusAtual = form.isEdit
          ? pedidos.where((p) => p.id == form.id).firstOrNull?.status
          : null;
      final modelComSeq = model.copyWith(
        elementos: elementosComSeq,
        status: statusAtual ?? model.status,
      );
      // ──────────────────────────────────────────────────────────────────────

      // Calcular resumo de aço (totais por bitola e elemento)
      final resumoAco = _calcularResumoAco(modelComSeq);
      final modelFinal = modelComSeq.copyWith(resumoAco: resumoAco);

      // Pedido + elementos gravados numa única transação (RPC), com
      // validação de saldo de peças feita pelo banco.
      final salvo = await BackendClient.pedidosTecnicos.salvar(modelFinal);
      if (form.isEdit) {
        if (!auto) {
          NotificationService.showPositive(
            'Pedido atualizado',
            '${modelFinal.elementos.length} elemento(s) no pedido ${modelFinal.codigo}',
            position: NotificationPosition.bottom,
          );
        }
      } else {
        form.id = salvo.id;
        form.codigo = salvo.codigo;
        form.identificador = salvo.identificador;
        formStream.update();
        if (!auto) {
          NotificationService.showPositive(
            'Pedido criado',
            '${modelFinal.elementos.length} elemento(s) cadastrado(s)',
            position: NotificationPosition.bottom,
          );
        }
      }
      return true;
    } catch (e) {
      // Erros de regra de negócio (ex: saldo insuficiente) aparecem mesmo no auto-save
      final regraNegocio = e is PostgrestException && e.code == 'P0001';
      if (!auto || regraNegocio) {
        NotificationService.showNegative(
          'Erro ao salvar',
          mensagemErro(e),
          position: NotificationPosition.bottom,
        );
      }
      return false;
    }
  }

  /// Calcula o resumo de aço do pedido técnico:
  /// - Peso total por bitola (para importação no PCP)
  /// - Peso total por elemento (corrigido, sem inflação de equivalentes)
  /// Usa CalculoAco (com variáveis peça a peça), acumulando por bitolaNome,
  /// garantindo Σ bitolas == Σ elementos.
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

      for (final pos in elemDet.posicoes) {
        final bitolaNome = pos.bitolaNome;
        if (CalculoAco.massaLinearPosicao(pos, bitolas) <= 0) continue;

        // Peso e comprimento consideram trechos variáveis peça a peça
        final pesoPosTotal = CalculoAco.pesoPosicao(pos, bitolas) * qtdeElem;
        pesoElemento += pesoPosTotal;
        final compM = CalculoAco.comprimentoTotalPosicao(pos) * qtdeElem / 100.0;

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
        mensagemErro(e),
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
