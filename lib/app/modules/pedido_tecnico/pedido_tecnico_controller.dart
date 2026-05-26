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
    final ocupados = BackendClient.pedidosTecnicos.elementosEmPedidoAberto;
    // Se estamos editando um pedido, desconsiderar os elementos do próprio pedido
    final pedidoAtualId = form.id;

    final lista = <ElementoDetalhamentoViewModel>[];

    for (final elem in detalhamento.elementos) {
      for (final nome in elem.todosNomes) {
        // Clonar o elemento com o nome específico e remover equivalentes
        final elemClonado = ElementoModel(
          id: elem.id,
          nome: nome,
          quantidade: elem.quantidade,
          pesoTotal: elem.pesoTotal,
          posicoes: elem.posicoes,
          elementosEquivalentes: const [],
        );

        final chave = '${elem.id}_$nome';
        final pedidoOcupante = ocupados[chave];
        final pertenceAoPedidoAtual =
            pedidoAtualId != null && pedidoOcupante?.id == pedidoAtualId;

        if (pedidoOcupante != null && !pertenceAoPedidoAtual) {
          lista.add(ElementoDetalhamentoViewModel(
            elemento: elemClonado,
            disponibilidade: DisponibilidadeElemento.emPedido,
            codigoPedidoOcupante: pedidoOcupante.codigo,
          ));
        } else {
          lista.add(ElementoDetalhamentoViewModel(
            elemento: elemClonado,
            disponibilidade: DisponibilidadeElemento.disponivel,
          ));
        }
      }
    }

    return lista;
  }

  // ── Salvar (criar ou atualizar) ───────────────────────
  Future<bool> salvar() async {
    if (form.detalhamentoId.isEmpty) {
      NotificationService.showNegative(
        'Selecione um detalhamento',
        'Escolha o detalhamento antes de gerar o pedido',
        position: NotificationPosition.bottom,
      );
      return false;
    }
    if (form.elementosSelecionados.isEmpty) {
      NotificationService.showNegative(
        'Nenhum elemento selecionado',
        'Selecione ao menos um elemento para o pedido',
        position: NotificationPosition.bottom,
      );
      return false;
    }
    try {
      final model = form.toPedidoTecnicoModel();
      if (form.isEdit) {
        await BackendClient.pedidosTecnicos.atualizar(model);
        await BackendClient.pedidosTecnicos
            .atualizarElementos(model.id, model.elementos);
        NotificationService.showPositive(
          'Pedido atualizado',
          '${model.elementos.length} elemento(s) no pedido ${model.codigo}',
          position: NotificationPosition.bottom,
        );
      } else {
        await BackendClient.pedidosTecnicos.criar(model);
        NotificationService.showPositive(
          'Pedido criado',
          '${model.elementos.length} elemento(s) cadastrado(s)',
          position: NotificationPosition.bottom,
        );
      }
      return true;
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao salvar',
        e.toString(),
        position: NotificationPosition.bottom,
      );
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
