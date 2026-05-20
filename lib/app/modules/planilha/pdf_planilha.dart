import 'dart:math' as math;
import 'dart:typed_data';
import 'package:acoplan/app/core/client/models/forma_model.dart';
import 'package:acoplan/app/core/client/models/planilha_model.dart';
import 'package:acoplan/app/core/client/models/produto_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfPlanilha {
  static List<ProdutoModel> _produtos = [];

  static Future<Uint8List> gerarRelatorio(PlanilhaModel planilha, List<FormaModel> formasCadastradas, List<ProdutoModel> produtos) async {
    _produtos = produtos;
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Cabeçalho
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Planilha ${planilha.codigo}', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Obra: ${planilha.obraNome}', style: const pw.TextStyle(fontSize: 14)),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Cliente: ${planilha.clienteNome}', style: const pw.TextStyle(fontSize: 14)),
            pw.Text('Peso Total: ${planilha.pesoTotal.toStringAsFixed(2)} kg', style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 20),

            // Elementos
            ...planilha.elementos.map((elem) {
              // Calcular pesos usando lógica precisa (peça a peça para variáveis)
              double pesoUnitarioElem = 0;
              for (var pos in elem.posicoes) {
                pesoUnitarioElem += _pesoTotalPosicao(pos);
              }
              final pesoTotalElem = pesoUnitarioElem * elem.quantidade;

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: double.infinity,
                    margin: const pw.EdgeInsets.only(top: 10, bottom: 15),
                    padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blueGrey50,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(color: PdfColors.blueGrey200, width: 1),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Elemento', style: pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey600, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(elem.nome, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                            pw.Row(
                              children: [
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: const pw.BoxDecoration(
                                    color: PdfColors.white,
                                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                                  ),
                                  child: pw.Text('Peso Unit: ${pesoUnitarioElem.toStringAsFixed(2)} kg  |  Peso Total: ${pesoTotalElem.toStringAsFixed(2)} kg', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                                ),
                                pw.SizedBox(width: 8),
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: const pw.BoxDecoration(
                                    color: PdfColors.blueGrey800,
                                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                                  ),
                                  child: pw.Text('Qtde: ${elem.quantidade}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Posições do elemento
                  ...elem.posicoes.map((pos) {
                    final bitolaStr = pos.bitolaNome.split('-').first.trim();
                    final formaStr = pos.formaCodigo;
                    final compUnitario = pos.comprimentos.values.fold<int>(0, (sum, val) => sum + val);
                    final compCorte = pos.comprimentoDeCorte > 0 ? pos.comprimentoDeCorte : compUnitario;

                    // Peso da posição (peça a peça para variáveis)
                    final pesoTotalPos = _pesoTotalPosicao(pos);
                    
                    pw.Widget buildColumn(String title, String value, {bool isBold = false}) {
                      return pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(title, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                          pw.SizedBox(height: 4),
                          pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: isBold ? PdfColors.black : PdfColors.grey900)),
                        ],
                      );
                    }
                    
                    final formaDef = formasCadastradas.where((f) => f.codigo == formaStr).firstOrNull;

                    return pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
                        ),
                      ),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          // Esquerda: Informações
                          pw.Expanded(
                            flex: 6,
                            child: pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(vertical: 8),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Row(
                                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      buildColumn('Posição', pos.posicao.toString(), isBold: true),
                                      buildColumn('Bitola', bitolaStr),
                                      buildColumn('Qtde', pos.qtde.toString()),
                                      buildColumn('Compr. Unit', '$compUnitario'),
                                      buildColumn('Compr. Corte', '$compCorte'),
                                      buildColumn('Peso Total', '${pesoTotalPos.toStringAsFixed(2)} kg'),
                                    ],
                                  ),
                                  pw.SizedBox(height: 6),
                                  pw.Text(
                                    pos.comprimentos.entries.map((e) => '${e.key}=${e.value}').join('  '),
                                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                                  ),
                                  // Linhas de variáveis por trecho
                                  ...pos.variaveis.entries
                                      .where((e) => e.value) // apenas trechos variáveis
                                      .map((e) {
                                    final trecho = e.key;
                                    // Busca config: própria ou do líder
                                    final config = pos.variaveisConfig[trecho]
                                        ?? pos.variaveisConfig.values.firstOrNull;
                                    if (config == null || config.inicial <= 0) return pw.SizedBox();
                                    final expandidas = config.medidasExpandidas(pos.multiplicador);
                                    final medidasStr = expandidas.isNotEmpty
                                        ? expandidas.join(', ')
                                        : config.medidas.join(', ');
                                    return pw.Padding(
                                      padding: const pw.EdgeInsets.only(top: 3),
                                      child: pw.Row(
                                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                                        children: [
                                          pw.Container(
                                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: pw.BoxDecoration(
                                              color: PdfColors.orange50,
                                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                                              border: pw.Border.all(color: PdfColors.orange200, width: 0.5),
                                            ),
                                            child: pw.Text('$trecho var', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900)),
                                          ),
                                          pw.SizedBox(width: 6),
                                          pw.Text(
                                            '${pos.multiplicador > 1 ? 'x${pos.multiplicador}  ' : ''}$medidasStr',
                                            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                          // Separador
                          pw.Container(
                            width: 1,
                            height: 90,
                            color: PdfColors.grey300,
                            margin: const pw.EdgeInsets.symmetric(horizontal: 16),
                          ),
                          // Direita: Forma
                          pw.Expanded(
                            flex: 4,
                            child: pw.Container(
                              height: 90,
                              alignment: pw.Alignment.center,
                              child: pw.Column(
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                children: [
                                  pw.Text('Forma $formaStr', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                                  pw.SizedBox(height: 4),
                                  pw.Container(
                                    height: 70,
                                    width: double.infinity,
                                    margin: const pw.EdgeInsets.symmetric(horizontal: 4),
                                    child: formaDef == null || formaDef.itens.isEmpty
                                        ? pw.Center(child: pw.Text('SEM DESENHO', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)))
                                        : _buildDesenhoForma(formaDef, pos.comprimentos),
                                  ),
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    );
                  }).toList(),
                  pw.SizedBox(height: 10),
                ],
              );
            }).toList(),

            // QUADRO DE AÇO
            pw.SizedBox(height: 20),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColors.grey300, width: 1),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('QUADRO DE AÇO / RESUMO DE MATERIAL', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                  pw.SizedBox(height: 10),
                  _buildQuadroAco(planilha),
                ],
              )
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildQuadroAco(PlanilhaModel planilha) {
    final resumoAco = <String, double>{};
    final compAco = <String, int>{}; // em cm

    for (var elem in planilha.elementos) {
      for (var pos in elem.posicoes) {
        final bitola = pos.bitolaNome.split('-').first.trim();
        final compUnit = pos.comprimentos.values.fold<int>(0, (sum, val) => sum + val);
        final compTotalCm = compUnit * pos.qtde * elem.quantidade;
        final pesoTotal = _pesoTotalPosicao(pos) * elem.quantidade;

        resumoAco[bitola] = (resumoAco[bitola] ?? 0) + pesoTotal;
        compAco[bitola] = (compAco[bitola] ?? 0) + compTotalCm;
      }
    }

    final bitolasOrdenadas = resumoAco.keys.toList()..sort();
    double pesoTotalGeral = 0;

    final rows = bitolasOrdenadas.map((b) {
      final peso = resumoAco[b] ?? 0;
      final compM = (compAco[b] ?? 0) / 100;
      pesoTotalGeral += peso;
      
      return pw.TableRow(
        children: [
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(b, style: const pw.TextStyle(fontSize: 10))),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${compM.toStringAsFixed(2)} m', style: const pw.TextStyle(fontSize: 10))),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${peso.toStringAsFixed(2)} kg', style: const pw.TextStyle(fontSize: 10))),
        ]
      );
    }).toList();

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('BITOLA', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('COMPR. TOTAL', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('PESO TOTAL', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
          ]
        ),
        ...rows,
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('TOTAL GERAL', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${pesoTotalGeral.toStringAsFixed(2)} kg', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
          ]
        ),
      ]
    );
  }

  /// Massa linear (kg/m) a partir da bitola — busca massaFinal real no cadastro,
  /// fallback para fórmula (d²/162) se não encontrado.
  static double _massaLinear(PosicaoModel pos) {
    // Buscar produto cadastrado pelo bitolaId
    final produto = _produtos.where((p) => p.id == pos.bitolaId).firstOrNull;
    if (produto != null && produto.massaFinal > 0) {
      return produto.massaFinal;
    }
    // Fallback: fórmula genérica
    final str = pos.bitolaNome.split('-').first.replaceAll(RegExp(r'[^0-9.]'), '');
    final d = double.tryParse(str) ?? 0;
    return (d * d) / 162;
  }

  /// Peso total de uma posição (todas as peças).
  /// Se tem trechos variáveis: calcula peça a peça.
  /// Se não tem variável: peso unitário × quantidade.
  static double _pesoTotalPosicao(PosicaoModel pos) {
    final w = _massaLinear(pos);
    if (w <= 0 || pos.qtde <= 0) return 0;

    // Verifica se tem algum trecho variável
    final temVar = pos.variaveisConfig.isNotEmpty &&
        pos.variaveis.values.any((v) => v);

    if (!temVar) {
      final somaCm = pos.comprimentos.values.fold<int>(0, (s, v) => s + v);
      return (somaCm / 100.0) * w * pos.qtde;
    }

    // Peça a peça
    double pesoTotal = 0;
    for (int peca = 0; peca < pos.qtde; peca++) {
      int somaCm = 0;
      for (final entry in pos.comprimentos.entries) {
        final trecho = entry.key;
        final isVar = pos.variaveis[trecho] ?? false;
        if (isVar) {
          // Busca config: própria ou do líder do grupo
          final config = pos.variaveisConfig[trecho]
              ?? pos.variaveisConfig.values.firstOrNull;
          if (config != null && config.inicial > 0 && config.final_ > 0) {
            final expandidas = config.medidasExpandidas(pos.multiplicador);
            somaCm += peca < expandidas.length
                ? expandidas[peca]
                : (expandidas.isNotEmpty ? expandidas.last : 0);
          } else {
            somaCm += entry.value;
          }
        } else {
          somaCm += entry.value;
        }
      }
      pesoTotal += (somaCm / 100.0) * w;
    }
    return pesoTotal;
  }

  static pw.Widget _buildDesenhoForma(FormaModel forma, Map<String, int> medidas) {
    if (forma.itens.isEmpty) return pw.SizedBox();

    // 1. Aplicar medidas e gerar pontos de modelo
    final itens = forma.itens.map((it) {
      final m = medidas[it.trecho] ?? it.comprimento;
      return FormaItemModel(
        trecho: it.trecho,
        comprimento: m,
        angulo: it.angulo,
        orientacao: it.orientacao,
        tipo: it.tipo,
      );
    }).toList();

    final pts = <PdfPoint>[const PdfPoint(0, 0)];
    double a = forma.rotacao;
    for (final it in itens) {
      final r = a * math.pi / 180;
      final last = pts.last;
      if (it.tipo == 'circulo') {
        final chord = 2 * it.comprimento * math.sin(10 * math.pi / 180);
        pts.add(PdfPoint(last.x + chord * math.cos(r), last.y + chord * math.sin(r)));
      } else {
        pts.add(PdfPoint(last.x + it.comprimento * math.cos(r), last.y + it.comprimento * math.sin(r)));
      }
      a += it.orientacao == 'Horário' ? it.angulo : -it.angulo;
    }

    // 2. Bounding Box e Escala (tamanho fixo do container: 110 x 70)
    const double width = 110;
    const double height = 70;

    List<PdfPoint> ptsBox = List.from(pts);
    for (var i = 0; i < itens.length && i < pts.length - 1; i++) {
      if (itens[i].tipo == 'circulo') {
        final raio = itens[i].comprimento.toDouble();
        final cx = pts[i + 1].x - pts[i].x;
        final cy = pts[i + 1].y - pts[i].y;
        final chordLen = math.sqrt(cx * cx + cy * cy);
        if (chordLen < 1) continue;
        final perpX = -cy / chordLen;
        final perpY = cx / chordLen;
        const sweepRad = 340 * math.pi / 180;
        final offset = raio * math.cos(sweepRad / 2);
        final midX = (pts[i].x + pts[i + 1].x) / 2;
        final midY = (pts[i].y + pts[i + 1].y) / 2;
        final centroX = midX + perpX * offset;
        final centroY = midY + perpY * offset;
        ptsBox.add(PdfPoint(centroX + raio, centroY));
        ptsBox.add(PdfPoint(centroX - raio, centroY));
        ptsBox.add(PdfPoint(centroX, centroY + raio));
        ptsBox.add(PdfPoint(centroX, centroY - raio));
      }
    }

    double mnX = ptsBox[0].x, mxX = ptsBox[0].x, mnY = ptsBox[0].y, mxY = ptsBox[0].y;
    for (final p in ptsBox) {
      if (p.x < mnX) mnX = p.x; if (p.x > mxX) mxX = p.x;
      if (p.y < mnY) mnY = p.y; if (p.y > mxY) mxY = p.y;
    }

    // Padding maior para as legendas não ficarem cortadas nas bordas
    final pad = math.min(width, height) * 0.22;
    final dw = width - pad * 2;
    final dh = height - pad * 2;
    final lw = mxX - mnX, lh = mxY - mnY;
    final esc = (lw == 0 && lh == 0) ? 1.0 : math.min(dw / (lw == 0 ? 1 : lw), dh / (lh == 0 ? 1 : lh));
    final ox = (width - lw * esc) / 2 - mnX * esc;
    final oy = (height - lh * esc) / 2 - mnY * esc;

    // toTela: replica o comportamento do cadastro (Flutter y-down → PDF canvas y-up flip)
    PdfPoint toTela(PdfPoint p) => PdfPoint(p.x * esc + ox, height - (p.y * esc + oy));
    final display = pts.map(toTela).toList();

    // 3. Criar os widgets de Legenda posicionados
    final centX = display.map((p) => p.x).reduce((a, b) => a + b) / display.length;
    final centY = display.map((p) => p.y).reduce((a, b) => a + b) / display.length;

    final legendas = <pw.Widget>[];
    for (var i = 0; i < display.length - 1; i++) {
       final p1 = display[i];
       final p2 = display[i+1];
       final midX = (p1.x + p2.x) / 2;
       final midY = (p1.y + p2.y) / 2;

       final dx = p2.x - p1.x;
       final dy = p2.y - p1.y;
       final len = math.sqrt(dx * dx + dy * dy);
       if (len < 1) continue;

       // Duas normais perpendiculares ao segmento
       final nx1 = -dy / len;  final ny1 = dx / len;
       final nx2 =  dy / len;  final ny2 = -dx / len;

       // Dot com vetor centróide→mid: escolhe a normal que aponta para FORA (positivo)
       final outX = midX - centX;
       final outY = midY - centY;
       final dot1 = nx1 * outX + ny1 * outY;
       final dirX = dot1 >= 0 ? nx1 : nx2;
       final dirY = dot1 >= 0 ? ny1 : ny2;

       final isCirculo = i < itens.length && itens[i].tipo == 'circulo';
       final dist = isCirculo ? 13.0 : 10.0;

       // toTela já produz coordenadas de tela (y=0 no topo, y cresce para baixo).
       // pw.Positioned.top usa a mesma convenção → topY = posição direta, sem inversão.
       final lx = (midX + dirX * dist - 5).clamp(0.5, width - 13.0);
       final topY = (midY + dirY * dist - 3).clamp(0.5, height - 9.0);
       legendas.add(
         pw.Positioned(
           left: lx,
           top: topY,
           child: pw.Text(
             itens[i].comprimento.toString(),
             style: pw.TextStyle(fontSize: 5, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)
           )
         )
       );
    }

    // 4. Retornar um Stack
    return pw.SizedBox(
      width: width,
      height: height,
      child: pw.Stack(
        children: [
          pw.Positioned.fill(
            child: pw.CustomPaint(
              painter: (canvas, size) {
                canvas.setStrokeColor(PdfColors.blueGrey900);
                canvas.setLineWidth(1.5);
                canvas.setLineJoin(PdfLineJoin.round);
                canvas.setLineCap(PdfLineCap.round);

                for (var i = 0; i < display.length - 1; i++) {
                  final isCirculo = i < itens.length && itens[i].tipo == 'circulo';
                  if (isCirculo) {
                    final cx = display[i + 1].x - display[i].x;
                    final cy = display[i + 1].y - display[i].y;
                    final chordLen = math.sqrt(cx * cx + cy * cy);
                    if (chordLen < 1) {
                      canvas.drawLine(display[i].x, display[i].y, display[i+1].x, display[i+1].y);
                      continue;
                    }
                    final perpX = -cy / chordLen;
                    final perpY = cx / chordLen;
                    final rScreen = itens[i].comprimento * esc;
                    final offsetS = rScreen * math.cos(170 * math.pi / 180);
                    final mx = (display[i].x + display[i + 1].x) / 2;
                    final my = (display[i].y + display[i + 1].y) / 2;
                    canvas.drawEllipse(mx + perpX * offsetS, my + perpY * offsetS, rScreen, rScreen);
                  } else {
                    canvas.drawLine(display[i].x, display[i].y, display[i+1].x, display[i+1].y);
                  }
                }
                canvas.strokePath();
              }
            )
          ),
          ...legendas,
        ]
      )
    );
  }
}
