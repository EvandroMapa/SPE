import 'dart:typed_data';
import 'package:acoplan/app/core/client/models/pedido_tecnico_model.dart';
import 'package:acoplan/app/core/client/models/detalhamento_model.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfPedidoTecnico {
  static Future<Uint8List> gerar({
    required PedidoTecnicoModel pedido,
    DetalhamentoModel? detalhamento,
    required bool completo,
  }) async {
    final pdf = pw.Document();
    final fmtData = DateFormat('dd/MM/yyyy');
    final fmtHora = DateFormat('HH:mm');
    final agora = DateTime.now();

    // ── Cores ──
    const corPrimaria = PdfColor.fromInt(0xFF0F172A);
    const corFundoCabecalho = PdfColor.fromInt(0xFFF1F5F9);
    const corBorda = PdfColor.fromInt(0xFFE2E8F0);
    const corVerde = PdfColor.fromInt(0xFF10B981);

    // ── Estilos ──
    final estTitulo = pw.TextStyle(
      fontSize: 18,
      fontWeight: pw.FontWeight.bold,
      color: corPrimaria,
    );
    final estSubtitulo = pw.TextStyle(
      fontSize: 11,
      color: const PdfColor.fromInt(0xFF64748B),
    );
    final estLabel = pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      color: const PdfColor.fromInt(0xFF64748B),
    );
    final estValor = pw.TextStyle(
      fontSize: 10,
      color: corPrimaria,
    );
    final estCabTbl = pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    );
    final estCelula = pw.TextStyle(fontSize: 9, color: corPrimaria);
    final estCelulaDestaque = pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      color: corPrimaria,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (_) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: corBorda, width: 1),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('PEDIDO TÉCNICO', style: estTitulo),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    completo ? 'Relatório Completo' : 'Relatório Resumido',
                    style: estSubtitulo,
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: pw.BoxDecoration(
                  color: corPrimaria,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'PT ${pedido.codigo.toString().padLeft(4, '0')}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.Text(
                      pedido.isAberto ? 'ABERTO' : 'CANCELADO',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: pedido.isAberto
                            ? const PdfColor.fromInt(0xFF6EE7B7)
                            : PdfColors.grey400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Gerado em ${fmtData.format(agora)} às ${fmtHora.format(agora)}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
        build: (ctx) {
          return [
            // ── Informações do pedido ──
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: corFundoCabecalho,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: corBorda),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _infoLinhasPdf(
                            'Cliente', pedido.clienteNome, estLabel, estValor),
                        pw.SizedBox(height: 6),
                        _infoLinhasPdf(
                            'Obra', pedido.obraNome, estLabel, estValor),
                        pw.SizedBox(height: 6),
                        _infoLinhasPdf(
                          'Detalhamento',
                          'Nº ${pedido.detalhamentoCodigo}',
                          estLabel,
                          estValor,
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _infoLinhasPdf(
                          'Data',
                          fmtData.format(pedido.criadoEm.toLocal()),
                          estLabel,
                          estValor,
                        ),
                        pw.SizedBox(height: 6),
                        _infoLinhasPdf(
                          'Elementos',
                          '${pedido.elementos.length}',
                          estLabel,
                          estValor,
                        ),
                        pw.SizedBox(height: 6),
                        _infoLinhasPdf(
                          'Peso Total',
                          pedido.pesoTotal > 0
                              ? '${pedido.pesoTotal.toStringAsFixed(2)} kg'
                              : '—',
                          estLabel,
                          pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: corVerde,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (pedido.observacao.isNotEmpty)
                    pw.Expanded(
                      child: _infoLinhasPdf(
                        'Observação',
                        pedido.observacao,
                        estLabel,
                        estValor,
                      ),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // ── Título da tabela ──
            pw.Row(children: [
              pw.Text(
                'ELEMENTOS DO PEDIDO',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: corPrimaria,
                  letterSpacing: 1,
                ),
              ),
            ]),
            pw.SizedBox(height: 8),

            // ── Tabela de elementos (resumida) ──
            pw.Table(
              columnWidths: completo
                  ? {
                      0: const pw.FixedColumnWidth(30),
                      1: const pw.FlexColumnWidth(3),
                      2: const pw.FixedColumnWidth(50),
                      3: const pw.FixedColumnWidth(50),
                      4: const pw.FixedColumnWidth(60),
                    }
                  : {
                      0: const pw.FixedColumnWidth(30),
                      1: const pw.FlexColumnWidth(4),
                      2: const pw.FixedColumnWidth(60),
                      3: const pw.FixedColumnWidth(70),
                    },
              border: pw.TableBorder.all(
                color: corBorda,
                width: 0.5,
              ),
              children: [
                // Cabeçalho
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: corPrimaria),
                  children: [
                    _celTbl('#', estCabTbl, align: pw.Alignment.center),
                    _celTbl('ELEMENTO', estCabTbl),
                    _celTbl('QTDE', estCabTbl, align: pw.Alignment.center),
                    if (completo)
                      _celTbl('POSIÇÕES', estCabTbl,
                          align: pw.Alignment.center),
                    _celTbl('PESO (kg)', estCabTbl,
                        align: pw.Alignment.center),
                  ],
                ),
                // Linhas
                ...pedido.elementos.asMap().entries.map((entry) {
                  final i = entry.key;
                  final elem = entry.value;
                  final bg = i % 2 == 0
                      ? PdfColors.white
                      : const PdfColor.fromInt(0xFFF8FAFC);

                  // Posições do detalhamento para esse elemento
                  final elemDetalhamento = detalhamento?.elementos
                      .where((e) => e.id == elem.elementoId)
                      .firstOrNull;
                  final nPosicoes = elemDetalhamento?.posicoes.length ?? 0;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: bg),
                    children: [
                      _celTbl('${i + 1}', estCelula,
                          align: pw.Alignment.center),
                      _celTbl(elem.elementoNome, estCelulaDestaque),
                      _celTbl('${elem.elementoQuantidade}', estCelula,
                          align: pw.Alignment.center),
                      if (completo)
                        _celTbl('$nPosicoes', estCelula,
                            align: pw.Alignment.center),
                      _celTbl(
                        elem.pesoTotal > 0
                            ? elem.pesoTotal.toStringAsFixed(2)
                            : '—',
                        pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: elem.pesoTotal > 0 ? corVerde : corPrimaria,
                        ),
                        align: pw.Alignment.center,
                      ),
                    ],
                  );
                }),
                // Totalizador
                pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: corFundoCabecalho),
                  children: [
                    _celTbl('', estCelula),
                    _celTbl('TOTAL', estCelulaDestaque),
                    _celTbl(
                      pedido.elementos
                          .fold(0, (s, e) => s + e.elementoQuantidade)
                          .toString(),
                      estCelulaDestaque,
                      align: pw.Alignment.center,
                    ),
                    if (completo) _celTbl('', estCelula),
                    _celTbl(
                      pedido.pesoTotal > 0
                          ? '${pedido.pesoTotal.toStringAsFixed(2)} kg'
                          : '—',
                      pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: corVerde,
                      ),
                      align: pw.Alignment.center,
                    ),
                  ],
                ),
              ],
            ),

            // ── Detalhes de posições (só relatório completo) ──
            if (completo && detalhamento != null) ...[
              pw.SizedBox(height: 24),
              pw.Text(
                'DETALHAMENTO POR ELEMENTO',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: corPrimaria,
                  letterSpacing: 1,
                ),
              ),
              pw.SizedBox(height: 10),
              ...pedido.elementos.map((elem) {
                final elemDetalhamento = detalhamento.elementos
                    .where((e) => e.id == elem.elementoId)
                    .firstOrNull;
                if (elemDetalhamento == null) return pw.SizedBox();

                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: pw.BoxDecoration(
                        color: corPrimaria,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Row(
                        mainAxisAlignment:
                            pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            elem.elementoNome,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.Text(
                            'Qtde: ${elem.elementoQuantidade}  •  ${elemDetalhamento.posicoes.length} posição(ões)  •  ${elem.pesoTotal > 0 ? '${elem.pesoTotal.toStringAsFixed(2)} kg' : '—'}',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey300,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (elemDetalhamento.posicoes.isNotEmpty)
                      pw.Table(
                        columnWidths: {
                          0: const pw.FixedColumnWidth(40),
                          1: const pw.FixedColumnWidth(80),
                          2: const pw.FixedColumnWidth(60),
                          3: const pw.FixedColumnWidth(40),
                          4: const pw.FlexColumnWidth(1),
                        },
                        border: pw.TableBorder.all(
                            color: corBorda, width: 0.5),
                        children: [
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(
                                color: corFundoCabecalho),
                            children: [
                              _celTbl('POS.', estLabel,
                                  align: pw.Alignment.center),
                              _celTbl('BITOLA', estLabel),
                              _celTbl('FORMA', estLabel),
                              _celTbl('QTDE', estLabel,
                                  align: pw.Alignment.center),
                              _celTbl('C. CORTE (cm)', estLabel,
                                  align: pw.Alignment.center),
                            ],
                          ),
                          ...elemDetalhamento.posicoes.map((pos) =>
                              pw.TableRow(
                                children: [
                                  _celTbl('${pos.posicao}', estCelula,
                                      align: pw.Alignment.center),
                                  _celTbl(pos.bitolaNome, estCelula),
                                  _celTbl(pos.formaCodigo, estCelula),
                                  _celTbl('${pos.qtde}', estCelula,
                                      align: pw.Alignment.center),
                                  _celTbl(
                                    pos.comprimentoDeCorte > 0
                                        ? pos.comprimentoDeCorte.toStringAsFixed(1)
                                        : '—',
                                    estCelula,
                                    align: pw.Alignment.center,
                                  ),
                                ],
                              )),
                        ],
                      ),
                    pw.SizedBox(height: 12),
                  ],
                );
              }),
            ],

            // ── Assinatura ──
            pw.SizedBox(height: 30),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _assinatura('Responsável Técnico', corBorda),
                _assinatura('Aprovação', corBorda),
                _assinatura('Recebimento', corBorda),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _infoLinhasPdf(
    String label,
    String valor,
    pw.TextStyle estLabel,
    pw.TextStyle estValor,
  ) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label.toUpperCase(), style: estLabel),
          pw.SizedBox(height: 2),
          pw.Text(valor, style: estValor),
        ],
      );

  static pw.Widget _celTbl(
    String texto,
    pw.TextStyle estilo, {
    pw.Alignment align = pw.Alignment.centerLeft,
  }) =>
      pw.Padding(
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: pw.Align(
          alignment: align,
          child: pw.Text(texto, style: estilo),
        ),
      );

  static pw.Widget _assinatura(String titulo, PdfColor corBorda) =>
      pw.Column(
        children: [
          pw.Container(
            width: 150,
            height: 1,
            color: corBorda,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            titulo,
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey600,
            ),
          ),
        ],
      );
}
