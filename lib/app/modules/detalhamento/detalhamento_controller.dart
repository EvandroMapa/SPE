import 'dart:async';
import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/detalhamento_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/detalhamento/detalhamento_view_model.dart';
import 'package:flutter/material.dart';

final detalhamentoCtrl = DetalhamentoController();

class DetalhamentoController {
  static final DetalhamentoController _instance = DetalhamentoController._();
  DetalhamentoController._();
  factory DetalhamentoController() => _instance;

  final AppStream<List<DetalhamentoModel>> detalhamentosStream = BackendClient.detalhamentos.dataStream;
  List<DetalhamentoModel> get detalhamentos => detalhamentosStream.value;

  final AppStream<DetalhamentoCreateModel> formStream = AppStream<DetalhamentoCreateModel>();
  DetalhamentoCreateModel get form => formStream.value;

  /// ID real da detalhamento no banco (UUID, 36 chars)
  String? _detalhamentoDbId;
  String? get detalhamentoDbId => _detalhamentoDbId;
  StreamSubscription? _realtimeSub;

  void init(DetalhamentoModel? detalhamento) {
    if (detalhamento != null) {
      _detalhamentoDbId = detalhamento.id;
      _carregarForm(detalhamento);

      // Escutar Realtime: quando a collection atualizar, recarregar o form
      _realtimeSub?.cancel();
      _realtimeSub = detalhamentosStream.listen.listen((lista) {
        if (_detalhamentoDbId == null) return;
        final atualizado = lista.where((d) => d.id == _detalhamentoDbId).firstOrNull;
        if (atualizado != null) {
          _carregarForm(atualizado);
        }
      });
    } else {
      _detalhamentoDbId = null;
      _realtimeSub?.cancel();
      final proximoCodigo = detalhamentos.isEmpty
          ? 1
          : detalhamentos.map((p) => p.codigo).reduce((a, b) => a > b ? a : b) + 1;
      final f = DetalhamentoCreateModel();
      f.codigo = proximoCodigo;
      formStream.add(f);
    }
  }

  void _carregarForm(DetalhamentoModel detalhamento) {
    final createModel = DetalhamentoCreateModel.edit(detalhamento);

    // Restaurar referências
    final clientes = BackendClient.clientes.data;
    final cliente = clientes.where((c) => c.id == detalhamento.clienteId).firstOrNull;
    createModel.clienteSelecionado = cliente;
    if (cliente != null) {
      createModel.obraSelecionada = cliente.obras.where((o) => o.id == detalhamento.obraId).firstOrNull;
    }

    // Restaurar bitola/forma nas posições
    final bitolas = BackendClient.bitolas.data;
    final formas = BackendClient.formas.data;
    for (final elem in createModel.elementos) {
      final elemOriginal = detalhamento.elementos.where((e) => e.id == elem.id).firstOrNull;
      if (elemOriginal != null) {
        for (int i = 0; i < elem.posicoes.length; i++) {
          final posOrig = elemOriginal.posicoes[i];
          elem.posicoes[i].bitolaSelecionada = bitolas.where((b) => b.id == posOrig.bitolaId).firstOrNull;
          elem.posicoes[i].formaSelecionada = formas.where((f) => f.id == posOrig.formaId).firstOrNull;
        }
      }
    }

    formStream.add(createModel);
  }

  // ── Salvar/atualizar dados gerais do detalhamento ────────────
  /// Retorna `true` se foi criação nova (incluindo duplicação)
  Future<bool> salvarDadosGerais({bool silencioso = false}) async {
    try {
      if (form.clienteSelecionado == null) throw Exception('Selecione um cliente');
      if (form.obraSelecionada == null) throw Exception('Selecione uma obra');

      final model = form.toDetalhamentoModel();
      bool foiCriacao = false;

      if (_detalhamentoDbId != null) {
        // Atualizar existente
        final atualizado = model.copyWith(id: _detalhamentoDbId);
        await BackendClient.detalhamentos.atualizarDetalhamento(atualizado);
      } else {
        // Criar nova
        _detalhamentoDbId = await BackendClient.detalhamentos.criarDetalhamento(model);
        form.isEdit = true;
        foiCriacao = true;
      }

      formStream.update(); // reconstrói sidebar → desbloqueia aba Elementos
      if (!silencioso) {
        NotificationService.showPositive('Detalhamento salvo', 'Dados gerais registrados com sucesso');
      }
      return foiCriacao;
    } catch (e) {
      NotificationService.showNegative('Erro', e.toString());
      return false;
    }
  }

  /// Duplicação completa: salva dados gerais + todos os elementos e posições
  Future<bool> duplicarCompleto() async {
    try {
      // 1. Salvar dados gerais (cria o detalhamento no banco)
      final foiCriacao = await salvarDadosGerais(silencioso: true);
      if (!foiCriacao || _detalhamentoDbId == null) return false;

      // 2. Salvar todos os elementos e suas posições
      for (final elem in form.elementos) {
        final elemModel = elem.toElementoModel();
        final elemDbId = await BackendClient.detalhamentos.adicionarElemento(
          elemModel, _detalhamentoDbId!);
        if (elemDbId == null) continue;

        // Salvar posições do elemento
        for (final pos in elem.posicoes) {
          final posModel = pos.toPosicaoModel();
          await BackendClient.detalhamentos.adicionarPosicao(posModel, elemDbId);
        }
      }

      // 3. Atualizar peso total
      final pesoTotal = form.toDetalhamentoModel().pesoTotal;
      if (pesoTotal > 0) {
        await atualizarPesoTotal(pesoTotal);
      }

      return true;
    } catch (e) {
      NotificationService.showNegative('Erro ao duplicar', e.toString());
      return false;
    }
  }

  /// Garante que a detalhamento existe no banco antes de operar elementos
  Future<bool> _garantirDetalhamento() async {
    if (_detalhamentoDbId != null) return true;
    try {
      if (form.clienteSelecionado == null || form.obraSelecionada == null) {
        NotificationService.showNegative('Atenção', 'Preencha cliente e obra antes de adicionar elementos');
        return false;
      }
      final model = form.toDetalhamentoModel();
      _detalhamentoDbId = await BackendClient.detalhamentos.criarDetalhamento(model);
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
      if (!await _garantirDetalhamento()) return null;
      final elemModel = elemCreate.toElementoModel();
      final elemDbId = await BackendClient.detalhamentos.adicionarElemento(elemModel, _detalhamentoDbId!);
      return elemDbId;
    } catch (e) {
      NotificationService.showNegative('Erro', e.toString());
      return null;
    }
  }

  // ── Elemento: atualizar ──────────────────────────────────
  Future<void> atualizarElemento(ElementoCreateModel elemCreate) async {
    try {
      if (!await _garantirDetalhamento()) return;
      final elemModel = elemCreate.toElementoModel();
      await BackendClient.detalhamentos.atualizarElemento(elemModel, _detalhamentoDbId!);
    } catch (e) {
      NotificationService.showNegative('Erro', e.toString());
    }
  }

  // ── Elemento: excluir ────────────────────────────────────
  Future<void> excluirElemento(String elementoId) async {
    try {
      await BackendClient.detalhamentos.excluirElemento(elementoId);
    } catch (e) {
      NotificationService.showNegative('Erro', e.toString());
    }
  }

  // ── Posição: adicionar ───────────────────────────────────
  Future<String?> adicionarPosicao(PosicaoCreateModel posCreate, String elementoId) async {
    try {
      final posModel = posCreate.toPosicaoModel();
      final posDbId = await BackendClient.detalhamentos.adicionarPosicao(posModel, elementoId);
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
      await BackendClient.detalhamentos.atualizarPosicao(posModel, elementoId);
    } catch (e) {
      NotificationService.showNegative('Erro', e.toString());
    }
  }

  // ── Posição: excluir ─────────────────────────────────────
  Future<void> excluirPosicao(String posicaoId) async {
    try {
      await BackendClient.detalhamentos.excluirPosicao(posicaoId);
    } catch (e) {
      NotificationService.showNegative('Erro', e.toString());
    }
  }

  // ── Excluir detalhamento inteiro ─────────────────────────────
  Future<void> onDelete(BuildContext context, DetalhamentoModel detalhamento) async {
    try {
      await BackendClient.detalhamentos.delete(detalhamento);
      NotificationService.showPositive('Sucesso', 'Detalhamento excluído');
    } catch (e) {
      NotificationService.showNegative('Erro', e.toString());
    }
  }

  // ── Atualizar peso total do detalhamento ────────────────────
  Future<void> atualizarPesoTotal(double pesoTotal) async {
    final detalhamentoId = form.id;
    if (detalhamentoId.length != 36) return;
    try {
      await BackendClient.detalhamentos.atualizarPesoTotal(detalhamentoId, pesoTotal);
    } catch (_) {}
  }

  Future<void> atualizarPesoElemento(String elementoId, double pesoTotal) async {
    try {
      await BackendClient.detalhamentos.atualizarPesoElemento(elementoId, pesoTotal);
    } catch (_) {}
  }
}
