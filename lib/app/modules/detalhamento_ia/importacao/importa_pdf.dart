import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:acoplan/app/modules/detalhamento_ia/importacao/importacao_resultado.dart';

/// Importação de projetos via PDF usando IA (Google Gemini).
class ImportaPdf {
  /// Processa um PDF e retorna o JSON com os elementos estruturais.
  /// [onProgresso] é chamado a cada chunk recebido da IA com (jsonParcial, elementosEncontrados).
  static Future<ImportacaoResultado> processar(
    Uint8List pdfBytes, {
    void Function(String jsonParcial, int elementosEncontrados)? onProgresso,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('gemini_api_key') ?? '';

    if (apiKey.isEmpty) {
      throw Exception(
          'Chave da API do Gemini não configurada. Vá em Configurações > Configurações Gerais para informar a chave.');
    }

    final prompt = '''
Você é um engenheiro estrutural especialista em leitura de projetos e detalhamento de armaduras (ferragens).
Analise com extrema atenção a planta estrutural em PDF fornecida. Procure por tabelas de ferro (Relação de Aço, Tabela de Ferros, Relação de Armaduras) ou representações de elementos estruturais (como vigas, pilares, blocos, sapatas, lajes) e suas respectivas posições de barras de ferro (N1, N2, N3, etc.).

Mesmo que a tabela esteja em formato de desenho vetorial ou imagem, leia as anotações e rótulos detalhadamente.

Sua saída deve ser ESTRITAMENTE um JSON válido no formato abaixo:
{
  "elementos": [
    {
      "nome": "V1",
      "quantidade": 1,
      "equivalentes": ["V2", "V3"],
      "posicoes": [
        {
          "posicao": "1",
          "quantidade": 4,
          "bitola_mm": 10.0,
          "forma_codigo": "F1",
          "comprimentos": {
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

    String rawResult = '';
    int elementosEncontrados = 0;

    Future<void> consumeStream(Stream<GenerateContentResponse> stream) async {
      await for (final chunk in stream) {
        if (chunk.text != null) {
          rawResult += chunk.text!;
          elementosEncontrados =
              RegExp(r'"nome"\s*:').allMatches(rawResult).length;
          onProgresso?.call(rawResult, elementosEncontrados);
        }
      }
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
      );
      final stream = model.generateContentStream(content);
      await consumeStream(stream);
    } catch (e) {
      try {
        final modelFlash = GenerativeModel(
          model: 'gemini-2.0-flash',
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
          ),
        );
        final stream = modelFlash.generateContentStream(content);
        await consumeStream(stream);
      } catch (flashError) {
        String detalheErro = '';
        try {
          final dio = Dio();
          final dioRes = await dio.get(
              'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey');
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
        throw Exception(
            'Falha ao acessar os modelos Gemini (2.5-flash e 2.0-flash).$detalheErro');
      }
    }

    if (rawResult.isEmpty) {
      throw Exception('A IA não retornou nenhum dado.');
    }

    return ImportacaoResultado(
      jsonBruto: rawResult,
      totalElementos: elementosEncontrados,
      tipo: TipoImportacao.pdf,
    );
  }
}
