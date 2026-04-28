import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/planilha_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/planilha/planilha_view_model.dart';
import 'package:flutter/material.dart';

final planilhaCtrl = PlanilhaController();

class PlanilhaController {
  static final PlanilhaController _instance = PlanilhaController._();
  PlanilhaController._();
  factory PlanilhaController() => _instance;

  final AppStream<List<PlanilhaModel>> planilhasStream = BackendClient.planilhas.dataStream;
  List<PlanilhaModel> get planilhas => planilhasStream.value;

  final AppStream<PlanilhaCreateModel> formStream = AppStream<PlanilhaCreateModel>();
  PlanilhaCreateModel get form => formStream.value;

  /// ID real da planilha no banco (UUID, 36 chars)
  String? _planilhaDbId;
  String? get planilhaDbId => _planilhaDbId;

  void init(PlanilhaModel? planilha) {
    if (planilha != null) {
      _planilhaDbId = planilha.id;
      final createModel = PlanilhaCreateModel.edit(planilha);

      // Restaurar referências
      final clientes = BackendClient.clientes.data;
      final cliente = clientes.where((c) => c.id == planilha.clienteId).firstOrNull;
      createModel.clienteSelecionado = cliente;
      if (cliente != null) {
        createModel.obraSelecionada = cliente.obras.where((o) => o.id == planilha.obraId).firstOrNull;
      }

      // Restaurar bitola/forma nas posições
      final bitolas = BackendClient.produtos.data;
      final formas = BackendClient.formas.data;
      for (final elem in createModel.elementos) {
        final elemOriginal = planilha.elementos.where((e) => e.id == elem.id).firstOrNull;
        if (elemOriginal != null) {
          for (int i = 0; i < elem.posicoes.length; i++) {
            final posOrig = elemOriginal.posicoes[i];
            elem.posicoes[i].bitolaSelecionada = bitolas.where((b) => b.id == posOrig.bitolaId).firstOrNull;
            elem.posicoes[i].formaSelecionada = formas.where((f) => f.id == posOrig.formaId).firstOrNull;
          }
        }
      }

      formStream.add(createModel);
    } else {
      _planilhaDbId = null;
      final proximoCodigo = planilhas.isEmpty
          ? 1
          : planilhas.map((p) => p.codigo).reduce((a, b) => a > b ? a : b) + 1;
      final f = PlanilhaCreateModel();
      f.codigo = proximoCodigo;
      formStream.add(f);
    }
  }

  // ── Salvar/atualizar dados gerais da planilha ────────────
  Future<void> salvarDadosGerais() async {
    try {
      if (form.clienteSelecionado == null) throw Exception('Selecione um cliente');
      if (form.obraSelecionada == null) throw Exception('Selecione uma obra');

      final model = form.toPlanilhaModel();

      if (_planilhaDbId != null) {
        // Atualizar existente
        final atualizado = model.copyWith(id: _planilhaDbId);
        await BackendClient.planilhas.atualizarPlanilha(atualizado);
      } else {
        // Criar nova
        _planilhaDbId = await BackendClient.planilhas.criarPlanilha(model);
        form.isEdit = true;
      }

      NotificationService.showPositive('Sucesso', 'Planilha salva');
    } catch (e) {
      NotificationService.showNegative('Erro', e.toString());
    }
  }

  /// Garante que a planilha existe no banco antes de operar elementos
  Future<bool> _garantirPlanilha() async {
    if (_planilhaDbId != null) return true;
    try {
      if (form.clienteSelecionado == null || form.obraSelecionada == null) {
        NotificationService.showNegative('Atenção', 'Preencha cliente e obra antes de adicionar elementos');
        return false;
      }
      final model = form.toPlanilhaModel();
      _planilhaDbId = await BackendClient.planilhas.criarPlanilha(model);
      form.isEdit = true;
      return true;
    } catch (e) {
      NotificationService.showNegative('Erro', e.toString());
      return false;
    }
  }

  // ── Elemento: adicionar ──────────────────────────────────
  Future<String?> adicionarElemento(ElementoCreateModel elemCreate) async {
    try {
      if (!await _garantirPlanilha()) return null;
      final elemModel = elemCreate.toElementoModel();
      final elemDbId = await BackendClient.planilhas.adicionarElemento(elemModel, _planilhaDbId!);
      return elemDbId;
    } catch (e) {
      NotificationService.showNegative('Erro', e.toString());
      return null;
    }
  }

  // ── Elemento: excluir ────────────────────────────────────
  Future<void> excluirElemento(String elementoId) async {
    try {
      await BackendClient.planilhas.excluirElemento(elementoId);
    } catch (e) {
      NotificationService.showNegative('Erro', e.toString());
    }
  }

  // ── Posição: adicionar ───────────────────────────────────
  Future<String?> adicionarPosicao(PosicaoCreateModel posCreate, String elementoId) async {
    try {
      final posModel = posCreate.toPosicaoModel();
      final posDbId = await BackendClient.planilhas.adicionarPosicao(posModel, elementoId);
      return posDbId;
    } catch (e) {
      NotificationService.showNegative('Erro', e.toString());
      return null;
    }
  }

  // ── Posição: atualizar (comprimentos) ────────────────────
  Future<void> adicionarPosicaoAtualizada(PosicaoCreateModel posCreate, String elementoId) async {
    try {
      final posModel = posCreate.toPosicaoModel();
      await BackendClient.planilhas.atualizarPosicao(posModel, elementoId);
    } catch (e) {
      NotificationService.showNegative('Erro', e.toString());
    }
  }

  // ── Posição: excluir ─────────────────────────────────────
  Future<void> excluirPosicao(String posicaoId) async {
    try {
      await BackendClient.planilhas.excluirPosicao(posicaoId);
    } catch (e) {
      NotificationService.showNegative('Erro', e.toString());
    }
  }

  // ── Excluir planilha inteira ─────────────────────────────
  Future<void> onDelete(BuildContext context, PlanilhaModel planilha) async {
    try {
      await BackendClient.planilhas.delete(planilha);
      if (context.mounted) pop(context);
      NotificationService.showPositive('Sucesso', 'Planilha excluída');
    } catch (e) {
      NotificationService.showNegative('Erro', e.toString());
    }
  }

  // ── Atualizar peso total da planilha ────────────────────
  Future<void> atualizarPesoTotal(double pesoTotal) async {
    final planilhaId = form.id;
    if (planilhaId.length != 36) return;
    try {
      await BackendClient.planilhas.atualizarPesoTotal(planilhaId, pesoTotal);
    } catch (_) {}
  }
}
