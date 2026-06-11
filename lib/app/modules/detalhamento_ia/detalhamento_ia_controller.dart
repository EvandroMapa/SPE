import 'dart:typed_data';
import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/cliente_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:acoplan/app/modules/detalhamento_ia/importacao/importacao_resultado.dart';
import 'package:acoplan/app/modules/detalhamento_ia/importacao/importa_pdf.dart';
import 'package:acoplan/app/modules/detalhamento_ia/importacao/importa_dxf.dart';
import 'package:acoplan/app/modules/detalhamento_ia/preparacao/preparacao_dxf_controller.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:acoplan/app/modules/detalhamento/detalhamento_controller.dart';
import 'package:acoplan/app/modules/detalhamento/detalhamento_view_model.dart';
import 'package:acoplan/app/modules/detalhamento/ui/detalhamento_create_page.dart';
import 'package:flutter/material.dart';

enum IaStatus {
  idle,
  uploading,
  analyzing,
  preparando, // DXF: módulo de preparação visual aberto
  success,
  importing,
  error
}

class DetalhamentoIaState {
  ClienteModel? clienteSelecionado;
  ObraModel? obraSelecionada;
  IaStatus status = IaStatus.idle;
  String? fileName;
  Uint8List? fileBytes;
  String errorMessage = '';
  String rawResult = '';
  int elementosEncontrados = 0;
  int elementosImportados = 0;
  int totalParaImportar = 0;
  TipoImportacao tipoImportacao = TipoImportacao.pdf;
  List<String> avisos = [];

  DetalhamentoIaState copyWith({
    ClienteModel? clienteSelecionado,
    ObraModel? obraSelecionada,
    IaStatus? status,
    String? fileName,
    Uint8List? fileBytes,
    String? errorMessage,
    String? rawResult,
  }) {
    final s = DetalhamentoIaState();
    s.clienteSelecionado = clienteSelecionado ?? this.clienteSelecionado;
    s.obraSelecionada = obraSelecionada ?? this.obraSelecionada;
    s.status = status ?? this.status;
    s.fileName = fileName ?? this.fileName;
    s.fileBytes = fileBytes ?? this.fileBytes;
    s.errorMessage = errorMessage ?? this.errorMessage;
    s.rawResult = rawResult ?? this.rawResult;
    s.elementosEncontrados = this.elementosEncontrados;
    s.tipoImportacao = this.tipoImportacao;
    s.avisos = this.avisos;
    return s;
  }
}

final detalhamentoIaCtrl = DetalhamentoIaController();

class DetalhamentoIaController {
  static final DetalhamentoIaController _instance = DetalhamentoIaController._();
  DetalhamentoIaController._();
  factory DetalhamentoIaController() => _instance;

  final AppStream<DetalhamentoIaModel> detalhamentosStream = AppStream<DetalhamentoIaModel>();

  final AppStream<DetalhamentoIaState> stateStream = AppStream<DetalhamentoIaState>.seed(DetalhamentoIaState());
  DetalhamentoIaState get state => stateStream.value;

  void init() {
    stateStream.add(DetalhamentoIaState());
  }

  void setCliente(ClienteModel? cliente) {
    state.clienteSelecionado = cliente;
    state.obraSelecionada = null; // reseta a obra
    stateStream.update();
  }

  void setObra(ObraModel? obra) {
    state.obraSelecionada = obra;
    stateStream.update();
  }

  void setTipoImportacao(TipoImportacao tipo) {
    state.tipoImportacao = tipo;
    stateStream.update();
  }

  /// Extensões permitidas conforme o tipo de importação selecionado.
  List<String> get _extensoesPermitidas {
    switch (state.tipoImportacao) {
      case TipoImportacao.pdf:
        return ['pdf'];
      case TipoImportacao.dxf:
        return ['dxf'];
    }
  }

  Future<void> pickFile() async {
    if (state.clienteSelecionado == null || state.obraSelecionada == null) {
      NotificationService.showNegative('Atenção', 'Selecione um cliente e uma obra antes de anexar o projeto.');
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final nomeArquivo = result.files.single.name;

        state.tipoImportacao = TipoImportacao.pdf;

        state.fileName = nomeArquivo;
        state.fileBytes = result.files.single.bytes;
        state.status = IaStatus.analyzing;
        state.rawResult = '';
        state.elementosEncontrados = 0;
        state.avisos = [];
        stateStream.update();

        switch (state.tipoImportacao) {
          case TipoImportacao.pdf:
            // PDF abre o módulo de preparação visual
            state.status = IaStatus.preparando;
            stateStream.update();
            preparacaoDxfCtrl.carregarPdf(state.fileBytes!, nomeArquivo);
            break;
          case TipoImportacao.dxf:
            // Setar status preparando ANTES do parse (para a UI mostrar o spinner)
            state.status = IaStatus.preparando;
            stateStream.update();
            // DXF abre o módulo de preparação visual (async para não travar UI)
            final conteudo = utf8.decode(state.fileBytes!, allowMalformed: true);
            await preparacaoDxfCtrl.carregarDxf(conteudo, nomeArquivo);
            break;
        }
      }
    } catch (e) {
      state.status = IaStatus.error;
      state.errorMessage = e.toString();
      stateStream.update();
      NotificationService.showNegative('Erro ao selecionar arquivo', state.errorMessage);
    }
  }

  /// Processamento via PDF + IA (Google Gemini).
  Future<void> _processarPdf(Uint8List pdfBytes) async {
    try {
      final resultado = await ImportaPdf.processar(
        pdfBytes,
        onProgresso: (jsonParcial, elementosEncontrados) {
          state.rawResult = jsonParcial;
          state.elementosEncontrados = elementosEncontrados;
          stateStream.update();
        },
      );

      state.rawResult = resultado.jsonBruto;
      state.elementosEncontrados = resultado.totalElementos;
      state.avisos = resultado.avisos;
      state.status = IaStatus.success;
      stateStream.update();
      NotificationService.showPositive('Leitura concluída', 'JSON extraído com sucesso via IA.');
    } catch (e) {
      state.status = IaStatus.error;
      state.errorMessage = e.toString();
      stateStream.update();
      NotificationService.showNegative('Erro na IA', state.errorMessage);
    }
  }

  /// Processamento via DXF (parser determinístico).
  void _processarDxf(Uint8List dxfBytes) {
    try {
      final conteudo = utf8.decode(dxfBytes, allowMalformed: true);

      final resultado = ImportaDxf.processar(conteudo);

      state.rawResult = resultado.jsonBruto;
      state.elementosEncontrados = resultado.totalElementos;
      state.avisos = resultado.avisos;
      state.status = IaStatus.success;
      stateStream.update();

      if (resultado.avisos.isNotEmpty) {
        NotificationService.showNeutral(
          'Parser DXF concluído',
          '${resultado.totalElementos} elementos encontrados. ${resultado.avisos.length} aviso(s).',
        );
      } else {
        NotificationService.showPositive(
          'Parser DXF concluído',
          '${resultado.totalElementos} elementos extraídos com sucesso.',
        );
      }
    } catch (e) {
      state.status = IaStatus.error;
      state.errorMessage = e.toString();
      stateStream.update();
      NotificationService.showNegative('Erro no parser DXF', state.errorMessage);
    }
  }

  /// Importa dados da preparação visual (Container 2 → Container 3).
  void importarDaPreparacao() {
    try {
      final resultado = preparacaoDxfCtrl.exportarParaImportacao();

      state.rawResult = resultado.jsonBruto;
      state.elementosEncontrados = resultado.totalElementos;
      state.avisos = resultado.avisos;
      state.tipoImportacao = TipoImportacao.dxf;
      state.status = IaStatus.success;
      stateStream.update();

      NotificationService.showPositive(
        'Preparação concluída',
        '${resultado.totalElementos} elementos prontos para importação.',
      );
    } catch (e) {
      state.status = IaStatus.error;
      state.errorMessage = e.toString();
      stateStream.update();
      NotificationService.showNegative('Erro na preparação', state.errorMessage);
    }
  }

  void reset() {
    stateStream.add(DetalhamentoIaState());
  }

  void limparUpload() {
    state.fileName = null;
    state.fileBytes = null;
    state.status = IaStatus.idle;
    state.rawResult = '';
    state.errorMessage = '';
    state.avisos = [];
    stateStream.update();
  }

  void importarDetalhamento(BuildContext context) {
    try {
      if (state.rawResult.isEmpty) {
        throw Exception('Nenhum dado para importar.');
      }

      String jsonText = state.rawResult.trim();
      if (jsonText.startsWith('```json')) {
        jsonText = jsonText.substring(7);
      } else if (jsonText.startsWith('```')) {
        jsonText = jsonText.substring(3);
      }
      if (jsonText.endsWith('```')) {
        jsonText = jsonText.substring(0, jsonText.length - 3);
      }

      final data = jsonDecode(jsonText);
      final elementos = data['elementos'] as List? ?? [];

      detalhamentoCtrl.init(null);
      detalhamentoCtrl.form.clienteSelecionado = state.clienteSelecionado;
      detalhamentoCtrl.form.obraSelecionada = state.obraSelecionada;

      for (final elMap in elementos) {
        final elem = ElementoCreateModel();
        elem.nome.text = elMap['nome']?.toString() ?? 'Elemento';
        elem.quantidade.text = elMap['quantidade']?.toString() ?? '1';
        elem.elementosEquivalentes = (elMap['equivalentes'] as List?)?.map((e) => e.toString()).toList() ?? [];

        final posicoes = elMap['posicoes'] as List? ?? [];
        for (final posMap in posicoes) {
          final pos = PosicaoCreateModel();
          pos.posicao.text = posMap['posicao']?.toString() ?? '';
          pos.qtde.text = posMap['quantidade']?.toString() ?? '1';

          final bitolaMm = double.tryParse(posMap['bitola_mm']?.toString() ?? '0') ?? 0;
          pos.bitolaSelecionada = BackendClient.bitolas.data.where((b) => b.diametro == bitolaMm * 10).firstOrNull;

          final formaCodigo = posMap['forma_codigo']?.toString() ?? '';
          pos.formaSelecionada = BackendClient.formas.data.where((f) => f.codigo.toLowerCase() == formaCodigo.toLowerCase()).firstOrNull;
          pos.descontoDobraSnapshot = pos.formaSelecionada?.descontoDobra;
          pos.formaSnapshot = pos.formaSelecionada?.toSnapshot();

          final comprimentosMap = posMap['comprimentos'] as Map? ?? {};
          for (final entry in comprimentosMap.entries) {
            pos.comprimentos[entry.key.toString()] = double.tryParse(entry.value?.toString() ?? '0') ?? 0.0;
          }
          
          if (pos.formaSelecionada != null) {
             pos.calcularComprimentoDeCorte();
          }

          elem.posicoes.add(pos);
        }

        detalhamentoCtrl.form.elementos.add(elem);
      }

      detalhamentoCtrl.formStream.update();
      limparUpload();
      Navigator.push(context, MaterialPageRoute(builder: (_) => const DetalhamentoCreatePage(skipInit: true)));

    } catch (e) {
      NotificationService.showNegative('Erro ao importar JSON', e.toString());
    }
  }

  /// Conta quantos elementos serão importados a partir do JSON bruto.
  int _contarElementosDoJson() {
    try {
      String jsonText = state.rawResult.trim();
      if (jsonText.startsWith('```json')) jsonText = jsonText.substring(7);
      if (jsonText.startsWith('```')) jsonText = jsonText.substring(3);
      if (jsonText.endsWith('```')) jsonText = jsonText.substring(0, jsonText.length - 3);
      final data = jsonDecode(jsonText);
      return (data['elementos'] as List?)?.length ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> importarParaDetalhamentoAtual(BuildContext context) async {
    try {
      if (state.rawResult.isEmpty) {
        throw Exception('Nenhum dado para importar.');
      }

      final qtdNovos = _contarElementosDoJson();

      // ── Mudar para estado de importação (spinner + contador) ──
      state.status = IaStatus.importing;
      state.elementosImportados = 0;
      state.totalParaImportar = qtdNovos;
      stateStream.update();

      // ── Excluir elementos existentes do banco ─────────────
      final qtdExistentes = detalhamentoCtrl.form.elementos.length;
      if (qtdExistentes > 0) {
        for (final elem in List.from(detalhamentoCtrl.form.elementos)) {
          if (elem.id.length == 36) {
            await detalhamentoCtrl.excluirElemento(elem.id);
          }
        }
        detalhamentoCtrl.form.elementos.clear();
      }

      // ── Parse do JSON ─────────────────────────────────────
      String jsonText = state.rawResult.trim();
      if (jsonText.startsWith('```json')) jsonText = jsonText.substring(7);
      if (jsonText.startsWith('```')) jsonText = jsonText.substring(3);
      if (jsonText.endsWith('```')) jsonText = jsonText.substring(0, jsonText.length - 3);

      final data = jsonDecode(jsonText);
      final elementos = data['elementos'] as List? ?? [];

      // ── Carregar localmente SEM salvar no banco ───────────
      for (final elMap in elementos) {
        final elem = ElementoCreateModel();
        elem.nome.text = elMap['nome']?.toString() ?? 'Elemento';
        elem.quantidade.text = elMap['quantidade']?.toString() ?? '1';
        elem.elementosEquivalentes = (elMap['equivalentes'] as List?)?.map((e) => e.toString()).toList() ?? [];

        final posicoes = elMap['posicoes'] as List? ?? [];
        for (final posMap in posicoes) {
          final pos = PosicaoCreateModel();
          pos.posicao.text = posMap['posicao']?.toString() ?? '';
          pos.qtde.text = posMap['quantidade']?.toString() ?? '1';

          final bitolaMm = double.tryParse(posMap['bitola_mm']?.toString() ?? '0') ?? 0;
          pos.bitolaSelecionada = BackendClient.bitolas.data.where((b) => b.diametro == bitolaMm * 10).firstOrNull;

          final formaCodigo = posMap['forma_codigo']?.toString() ?? '';
          pos.formaSelecionada = BackendClient.formas.data.where((f) => f.codigo.toLowerCase() == formaCodigo.toLowerCase()).firstOrNull;
          pos.descontoDobraSnapshot = pos.formaSelecionada?.descontoDobra;
          pos.formaSnapshot = pos.formaSelecionada?.toSnapshot();

          final comprimentosMap = posMap['comprimentos'] as Map? ?? {};
          for (final entry in comprimentosMap.entries) {
            pos.comprimentos[entry.key.toString()] = double.tryParse(entry.value?.toString() ?? '0') ?? 0.0;
          }

          if (pos.formaSelecionada != null) {
            pos.calcularComprimentoDeCorte();
          }

          elem.posicoes.add(pos);
        }

        detalhamentoCtrl.form.elementos.add(elem);

        // Atualizar progresso
        state.elementosImportados++;
        stateStream.update();

        // Pequeno delay para a UI atualizar o contador
        await Future.delayed(const Duration(milliseconds: 30));
      }

      detalhamentoCtrl.formStream.update();
      limparUpload();
      NotificationService.showPositive('Elementos carregados', '${elementos.length} elementos prontos para revisão.');
      return true;
    } catch (e) {
      state.status = IaStatus.error;
      state.errorMessage = 'Erro ao importar: ${e.toString()}';
      stateStream.update();
      NotificationService.showNegative('Erro ao importar', e.toString());
      return false;
    }
  }
}

class DetalhamentoIaModel {} // Placeholder para os resultados
