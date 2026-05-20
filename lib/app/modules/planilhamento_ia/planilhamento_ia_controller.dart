import 'dart:typed_data';
import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/cliente_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:acoplan/app/modules/planilha/planilha_controller.dart';
import 'package:acoplan/app/modules/planilha/planilha_view_model.dart';
import 'package:acoplan/app/modules/planilha/ui/planilha_create_page.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';

enum IaStatus {
  idle,
  uploading,
  analyzing,
  success,
  error
}

class PlanilhamentoIaState {
  ClienteModel? clienteSelecionado;
  ObraModel? obraSelecionada;
  IaStatus status = IaStatus.idle;
  String? fileName;
  Uint8List? fileBytes;
  String errorMessage = '';
  String rawResult = '';

  PlanilhamentoIaState copyWith({
    ClienteModel? clienteSelecionado,
    ObraModel? obraSelecionada,
    IaStatus? status,
    String? fileName,
    Uint8List? fileBytes,
    String? errorMessage,
    String? rawResult,
  }) {
    final s = PlanilhamentoIaState();
    s.clienteSelecionado = clienteSelecionado ?? this.clienteSelecionado;
    s.obraSelecionada = obraSelecionada ?? this.obraSelecionada;
    s.status = status ?? this.status;
    s.fileName = fileName ?? this.fileName;
    s.fileBytes = fileBytes ?? this.fileBytes;
    s.errorMessage = errorMessage ?? this.errorMessage;
    s.rawResult = rawResult ?? this.rawResult;
    return s;
  }
}

final planilhamentoIaCtrl = PlanilhamentoIaController();

class PlanilhamentoIaController {
  static final PlanilhamentoIaController _instance = PlanilhamentoIaController._();
  PlanilhamentoIaController._();
  factory PlanilhamentoIaController() => _instance;

  final AppStream<PlanilhaIaModel> planilhasStream = AppStream<PlanilhaIaModel>();

  final AppStream<PlanilhamentoIaState> stateStream = AppStream<PlanilhamentoIaState>.seed(PlanilhamentoIaState());
  PlanilhamentoIaState get state => stateStream.value;

  void init() {
    stateStream.add(PlanilhamentoIaState());
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
        state.fileName = result.files.single.name;
        state.fileBytes = result.files.single.bytes;
        state.status = IaStatus.analyzing;
        stateStream.update();

        // Simulação do backend removida, chamando Gemini real
        await _processFileGemini(state.fileBytes!);

      }
    } catch (e) {
      state.status = IaStatus.error;
      state.errorMessage = e.toString();
      stateStream.update();
      NotificationService.showNegative('Erro ao selecionar arquivo', state.errorMessage);
    }
  }

  void reset() {
    stateStream.add(PlanilhamentoIaState());
  }

  void limparUpload() {
    state.fileName = null;
    state.fileBytes = null;
    state.status = IaStatus.idle;
    state.rawResult = '';
    state.errorMessage = '';
    stateStream.update();
  }

  Future<void> _processFileGemini(Uint8List pdfBytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('gemini_api_key') ?? '';
      
      if (apiKey.isEmpty) {
        throw Exception('Chave da API do Gemini não configurada. Vá em Configurações > Configurações Gerais para informar a chave.');
      }

      final prompt = '''
Você é um engenheiro estrutural especialista em leitura de projetos e detalhamento de armaduras (ferragens).
Analise com extrema atenção a planta estrutural em PDF fornecida. Procure por tabelas de ferro (Relação de Aço, Tabela de Ferros, Relação de Armaduras) ou representações de elementos estruturais (como vigas, pilares, blocos, sapatas, lajes) e suas respectivas posições de barras de ferro (N1, N2, N3, etc.).

Mesmo que a tabela esteja em formato de desenho vetorial ou imagem, leia as anotações e rótulos detalhadamente.

Sua saída deve ser ESTRITAMENTE um JSON válido no formato abaixo:
{
  "elementos": [
    {
      "nome": "V1", // Nome do elemento (ex: V1, Viga 1, P1, Pilar 1, Sapata S1)
      "quantidade": 1, // Quantidade de elementos iguais (padrão é 1 se não especificado)
      "equivalentes": ["V2", "V3"], // Rótulos/nomes de outros elementos idênticos a este que compartilham o mesmo detalhamento
      "posicoes": [
        {
          "posicao": "1", // Apenas o número da posição (ex: se for N1, retorne "1")
          "quantidade": 4, // Quantidade de barras nesta posição para cada elemento
          "bitola_mm": 10.0, // Bitola do ferro em milímetros (ex: 5.0, 6.3, 8.0, 10.0, 12.5, 16.0, 20.0)
          "forma_codigo": "F1", // Código da forma/dobra (ex: F1, F2, F3, Estribo, Gancho, Reta ou similar)
          "comprimentos": { // Mapa com as dimensões de cada trecho do ferro dobrado (A, B, C, D...) em centímetros (cm)
            "A": 100,
            "B": 50
          }
        }
      ]
    }
  ]
}

Regras importantes de extração:
1. Se houver tabelas de "Relação de Aço" ou "Lista de Ferros" no desenho, extraia todas as linhas dela.
2. Identifique os elementos associados a cada lista de ferros. Geralmente, as tabelas indicam a qual viga ou pilar pertencem.
3. Se não encontrar nenhuma tabela estruturada, faça uma varredura visual/textual nas vigas e pilares desenhados e tente extrair as posições (ex: 4 N1 ø10.0 C=350, 2 N2 ø12.5 C=420) e agrupe-as no respectivo elemento (Viga V1, Viga V2, etc.).
4. Se encontrar as dimensões detalhadas de dobra do ferro (A, B, C...), adicione-as no mapa "comprimentos".
5. Garanta que o JSON seja perfeitamente válido e siga estritamente essa estrutura. Se absolutamente nada for encontrado, retorne uma lista vazia, mas tente ao máximo extrair os dados.
''';

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('application/pdf', pdfBytes),
        ])
      ];

      GenerateContentResponse response;
      try {
        final model = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
          ),
        );
        response = await model.generateContent(content);
      } catch (e) {
        try {
          // Fallback para gemini-2.0-flash
          final modelFlash = GenerativeModel(
            model: 'gemini-2.0-flash',
            apiKey: apiKey,
            generationConfig: GenerationConfig(
              responseMimeType: 'application/json',
            ),
          );
          response = await modelFlash.generateContent(content);
        } catch (flashError) {
          // Se falhar em ambos, fazemos uma requisição direta para obter o erro detalhado da API da Google
          String detalheErro = '';
          try {
            final dio = Dio();
            final dioRes = await dio.get('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey');
            detalheErro = '\nModelos disponíveis: ${dioRes.data}';
          } catch (dioErr) {
            if (dioErr is DioException && dioErr.response != null) {
              final errorData = dioErr.response?.data;
              if (errorData is Map && errorData['error'] != null) {
                final errMsg = errorData['error']['message'];
                final errStatus = errorData['error']['status'];
                detalheErro = '\nDetalhe da Google: [$errStatus] $errMsg';
              } else {
                detalheErro = '\nErro da Google: ${dioErr.response?.data}';
              }
            } else {
              detalheErro = '\nErro de rede: ${dioErr.toString()}';
            }
          }
          throw Exception('Falha ao acessar os modelos Gemini (2.5-flash e 2.0-flash).$detalheErro');
        }
      }
      
      if (response.text == null || response.text!.isEmpty) {
        throw Exception('A IA não retornou nenhum dado.');
      }

      state.rawResult = response.text!;
      state.status = IaStatus.success;
      stateStream.update();
      NotificationService.showPositive('Leitura concluída', 'JSON extraído com sucesso. Verifique o resultado na tela.');

    } catch (e) {
      state.status = IaStatus.error;
      state.errorMessage = e.toString();
      stateStream.update();
      NotificationService.showNegative('Erro na IA', state.errorMessage);
    }
  }

  void importarPlanilha(BuildContext context) {
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

      planilhaCtrl.init(null);
      planilhaCtrl.form.clienteSelecionado = state.clienteSelecionado;
      planilhaCtrl.form.obraSelecionada = state.obraSelecionada;

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
          pos.bitolaSelecionada = BackendClient.produtos.data.where((b) => b.diametro == bitolaMm * 10).firstOrNull;

          final formaCodigo = posMap['forma_codigo']?.toString() ?? '';
          pos.formaSelecionada = BackendClient.formas.data.where((f) => f.codigo.toLowerCase() == formaCodigo.toLowerCase()).firstOrNull;

          final comprimentosMap = posMap['comprimentos'] as Map? ?? {};
          for (final entry in comprimentosMap.entries) {
            pos.comprimentos[entry.key.toString()] = int.tryParse(entry.value?.toString() ?? '0') ?? 0;
          }
          
          if (pos.formaSelecionada != null) {
             pos.calcularComprimentoDeCorte();
          }

          elem.posicoes.add(pos);
        }

        planilhaCtrl.form.elementos.add(elem);
      }

      planilhaCtrl.formStream.update();
      limparUpload();
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PlanilhaCreatePage(skipInit: true)));

    } catch (e) {
      NotificationService.showNegative('Erro ao importar JSON', e.toString());
    }
  }

  Future<bool> importarParaPlanilhaAtual(BuildContext context) async {
    try {
      if (state.rawResult.isEmpty) {
        throw Exception('Nenhum dado para importar.');
      }

      if (planilhaCtrl.form.elementos.isNotEmpty) {
        final bool? limpar = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Planilha já possui elementos'),
            content: const Text(
              'Esta planilha já possui elementos cadastrados. Deseja limpar os elementos existentes e substituí-los pelos dados extraídos da IA?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Limpar e Importar'),
              ),
            ],
          ),
        );
        if (limpar != true) {
          return false;
        }
        planilhaCtrl.form.elementos.clear();
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
          pos.bitolaSelecionada = BackendClient.produtos.data.where((b) => b.diametro == bitolaMm * 10).firstOrNull;

          final formaCodigo = posMap['forma_codigo']?.toString() ?? '';
          pos.formaSelecionada = BackendClient.formas.data.where((f) => f.codigo.toLowerCase() == formaCodigo.toLowerCase()).firstOrNull;

          final comprimentosMap = posMap['comprimentos'] as Map? ?? {};
          for (final entry in comprimentosMap.entries) {
            pos.comprimentos[entry.key.toString()] = int.tryParse(entry.value?.toString() ?? '0') ?? 0;
          }
          
          if (pos.formaSelecionada != null) {
             pos.calcularComprimentoDeCorte();
          }

          elem.posicoes.add(pos);
        }

        planilhaCtrl.form.elementos.add(elem);
      }

      planilhaCtrl.formStream.update();
      limparUpload();
      NotificationService.showPositive('Importação Concluída', '${elementos.length} elementos importados com sucesso.');
      return true;
    } catch (e) {
      NotificationService.showNegative('Erro ao importar JSON', e.toString());
      return false;
    }
  }
}

class PlanilhaIaModel {} // Placeholder para os resultados
