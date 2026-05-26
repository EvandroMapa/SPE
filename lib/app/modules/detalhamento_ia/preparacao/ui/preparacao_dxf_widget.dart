import 'dart:convert';
import 'dart:typed_data';
import 'package:acoplan/app/core/components/stream_out.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/modules/detalhamento_ia/preparacao/models/elemento_preparado.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acoplan/app/modules/detalhamento_ia/preparacao/preparacao_dxf_controller.dart';
import 'package:acoplan/app/modules/detalhamento_ia/preparacao/ui/dxf_canvas_widget.dart';
import 'package:acoplan/app/modules/detalhamento_ia/preparacao/ui/pdf_canvas_widget.dart';
import 'package:acoplan/app/modules/detalhamento_ia/preparacao/ui/painel_elementos_widget.dart';
import 'package:acoplan/app/modules/detalhamento_ia/preparacao/ui/dialog_confirmar_elemento.dart';
import 'package:overlay_support/overlay_support.dart';

/// Widget do Container 2 — Preparação do Arquivo.
///
/// Contém o canvas DXF com o painel de elementos lateral.
class PreparacaoDxfWidget extends StatelessWidget {
  final VoidCallback? onImportar;

  const PreparacaoDxfWidget({super.key, this.onImportar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header do container
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primaryMain,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('2', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Preparação do Arquivo', style: AppCss.mediumBold.setColor(const Color(0xFF1E293B))),
                    StreamOut(
                      stream: preparacaoDxfCtrl.stateStream.listen,
                      builder: (_, state) {
                        final nome = state.nomeArquivo ?? '';
                        return Text(
                          nome.isNotEmpty ? nome : 'Visualize e associe elementos',
                          style: AppCss.minimumRegular.setColor(Colors.grey[500]!).setSize(12),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Canvas + Painel
          Expanded(
            child: StreamOut(
              stream: preparacaoDxfCtrl.stateStream.listen,
              builder: (_, state) {
                if (state.carregando) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Carregando arquivo...'),
                      ],
                    ),
                  );
                }

                if (state.erro != null) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                        const SizedBox(height: 12),
                        Text(state.erro!, style: TextStyle(color: Colors.red[700])),
                      ],
                    ),
                  );
                }

                if (state.geometria == null && !state.isPdf) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.upload_file, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('Selecione um arquivo PDF ou DXF', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  );
                }

                // PDF: mostra o canvas de PDF + painel lateral
                if (state.isPdf) {
                  return Row(
                    children: [
                      Expanded(
                        child: PdfCanvasWidget(
                          pdfBytes: state.pdfBytes!,
                          onSelecaoConcluida: (regiao, pagina, imagemPagina) {
                            _onSelecaoPdf(context, regiao, pagina, imagemPagina);
                          },
                        ),
                      ),
                      // Painel lateral
                      PainelElementosWidget(
                        elementos: state.elementos,
                        elementoSelecionado: state.elementoSelecionado,
                        totalPosicoes: preparacaoDxfCtrl.totalPosicoes,
                        onAutoDetectar: null, // Sem auto-detecção no PDF
                        onImportar: onImportar,
                        onElementoClicado: (nome) {
                          preparacaoDxfCtrl.selecionarElemento(
                            state.elementoSelecionado == nome ? null : nome,
                          );
                        },
                        onRemoverElemento: (nome) {
                          preparacaoDxfCtrl.removerElemento(nome);
                          NotificationService.showNeutral(
                            'Elemento removido',
                            nome,
                            position: NotificationPosition.bottom,
                          );
                        },
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    // Canvas
                    Expanded(
                      child: DxfCanvasWidget(
                        geometria: state.geometria!,
                        elementos: state.elementos,
                        elementoSelecionado: state.elementoSelecionado,
                        onSelecaoConcluida: (regiao, indices) {
                          _onSelecaoConcluida(context, regiao, indices);
                        },
                        onElementoClicado: (nome) {
                          preparacaoDxfCtrl.selecionarElemento(nome);
                        },
                      ),
                    ),

                    // Painel lateral
                    PainelElementosWidget(
                      elementos: state.elementos,
                      elementoSelecionado: state.elementoSelecionado,
                      totalPosicoes: preparacaoDxfCtrl.totalPosicoes,
                      onAutoDetectar: () {
                        preparacaoDxfCtrl.autoDetectar();
                        NotificationService.showPositive(
                          'Auto-detecção concluída',
                          '${state.elementos.length} elementos encontrados',
                          position: NotificationPosition.bottom,
                        );
                      },
                      onImportar: onImportar,
                      onElementoClicado: (nome) {
                        preparacaoDxfCtrl.selecionarElemento(
                          state.elementoSelecionado == nome ? null : nome,
                        );
                      },
                      onRemoverElemento: (nome) {
                        preparacaoDxfCtrl.removerElemento(nome);
                        NotificationService.showNeutral(
                          'Elemento removido',
                          nome,
                          position: NotificationPosition.bottom,
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _onSelecaoConcluida(BuildContext context, Rect regiao, List<int> indices) async {
    final resultado = preparacaoDxfCtrl.processarSelecao(regiao, indices);

    final nome = await DialogConfirmarElemento.mostrar(
      context,
      nomeSugerido: resultado.nomeSugerido,
      posicoes: resultado.posicoes,
    );

    if (nome != null && nome.isNotEmpty) {
      preparacaoDxfCtrl.confirmarElemento(nome, regiao, resultado.posicoes);
      NotificationService.showPositive(
        'Elemento confirmado',
        '$nome — ${resultado.posicoes.length} posições',
        position: NotificationPosition.bottom,
      );
    }
  }

  void _onSelecaoPdf(BuildContext context, Rect regiao, int pagina, Uint8List imagemPagina) async {
    final nomeController = TextEditingController();

    final nome = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.crop, color: AppColors.primaryMain, size: 22),
            const SizedBox(width: 8),
            const Text('Nomear Elemento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Região selecionada na página $pagina',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nomeController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Nome do elemento',
                hintText: 'Ex: V1, P2, L3...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nomeController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (nome == null || nome.isEmpty) return;

    // Adicionar elemento no painel (sem posições por enquanto)
    preparacaoDxfCtrl.adicionarElementoPdf(nome, regiao, pagina);

    // Enviar imagem da página ao Gemini para extrair posições
    if (!context.mounted) return;

    debugPrint('=== imagemPagina: ${imagemPagina.length} bytes ===');

    NotificationService.showNeutral(
      'Processando com IA...',
      'Extraindo posições de $nome',
      position: NotificationPosition.bottom,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('gemini_api_key') ?? '';
      if (apiKey.isEmpty) {
        NotificationService.showNegative(
          'Chave API não configurada',
          'Vá em Configurações para informar a chave do Gemini',
          position: NotificationPosition.bottom,
        );
        return;
      }

      final prompt = '''
Você é um engenheiro estrutural especialista em leitura de projetos e detalhamento de armaduras (ferragens).
Analise com extrema atenção esta imagem de projeto estrutural.

Procure o elemento "$nome" e extraia TODAS as suas posições de armadura (barras de ferro).

Procure nas tabelas de ferro (Relação de Aço, Tabela de Ferros, Resumo de Aço) e também nas anotações diretamente nos desenhos das vigas/pilares/lajes.

Padrões comuns que você pode encontrar:
- "4 N1 ø10.0 C=350" → 4 barras, posição N1, bitola 10mm, comprimento 350cm
- "2 N35 ø12.5 C=415" → 2 barras, posição N35, bitola 12.5mm, comprimento 415cm
- "N12 c/15" → estribo ou distribuição a cada 15cm
- "4φ10 N1 C=350" → mesmo formato alternativo

Para cada posição encontrada, extraia:
- posicao: número da posição (apenas o número, ex: "1", "35")
- quantidade: quantas barras
- bitola_mm: diâmetro em mm
- forma_codigo: "R" para reta, ou código se houver (F1, F2, etc.)
- comprimento: comprimento total em cm

Retorne APENAS JSON válido:
{
  "posicoes": [
    {
      "posicao": "1",
      "quantidade": 4,
      "bitola_mm": 10.0,
      "forma_codigo": "R",
      "comprimento": 350
    }
  ]
}

Se não encontrar posições para "$nome", retorne: {"posicoes": []}
''';

      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
      );

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/png', imagemPagina),
        ])
      ];

      final response = await model.generateContent(content);
      final jsonStr = response.text ?? '';

      debugPrint('=== GEMINI RESPONSE para $nome ===');
      debugPrint(jsonStr);
      debugPrint('=== FIM RESPONSE ===');

      if (jsonStr.isNotEmpty) {
        final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
        final posicoesJson = parsed['posicoes'] as List? ?? [];

        final posicoes = posicoesJson.map<PosicaoPreparada>((p) {
          final m = p as Map<String, dynamic>;
          return PosicaoPreparada(
            posicao: m['posicao']?.toString() ?? '',
            quantidade: (m['quantidade'] as num?)?.toInt() ?? 1,
            bitolaMm: (m['bitola_mm'] as num?)?.toDouble() ?? 10.0,
            formaCodigo: m['forma_codigo']?.toString() ?? 'R',
            comprimentos: m['comprimento'] != null
                ? {'C': (m['comprimento'] as num).toInt()}
                : {},
            x: 0,
            y: 0,
          );
        }).toList();

        preparacaoDxfCtrl.atualizarPosicoesPdfList(nome, posicoes);

        if (context.mounted) {
          if (posicoes.isEmpty) {
            NotificationService.showNegative(
              'Nenhuma posição encontrada',
              '$nome — verifique o console para detalhes',
              position: NotificationPosition.bottom,
            );
          } else {
            NotificationService.showPositive(
              'Posições encontradas',
              '$nome — ${posicoes.length} posições detectadas',
              position: NotificationPosition.bottom,
            );
          }
        }
      }
    } catch (e) {
      // Parar spinner em caso de erro
      final idx = preparacaoDxfCtrl.state.elementos.indexWhere((el) => el.nome == nome);
      if (idx >= 0) {
        preparacaoDxfCtrl.state.elementos[idx].processandoIa = false;
        preparacaoDxfCtrl.stateStream.add(preparacaoDxfCtrl.state);
      }
      if (context.mounted) {
        NotificationService.showNegative(
          'Erro ao processar',
          e.toString().length > 80 ? e.toString().substring(0, 80) : e.toString(),
          position: NotificationPosition.bottom,
        );
      }
    }
  }
}
