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

      for (final nome in elem.todosNomes) {
        final chave = '${elem.id}_$nome';
        final qtdAlocada = alocados[chave] ?? 0;
        final qtdRestante = elem.quantidade - qtdAlocada;

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
      if (form.isEdit) {
        await BackendClient.pedidosTecnicos.atualizar(model);
        await BackendClient.pedidosTecnicos
            .atualizarElementos(model.id, model.elementos);
        if (!auto) {
          NotificationService.showPositive(
            'Pedido atualizado',
            '${model.elementos.length} elemento(s) no pedido ${model.codigo}',
            position: NotificationPosition.bottom,
          );
        }
      } else {
        final createdModel = await BackendClient.pedidosTecnicos.criar(model);
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
