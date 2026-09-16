import 'dart:typed_data';
import 'package:acoplan/app/core/client/models/bitola_model.dart';
import 'package:acoplan/app/core/client/models/pedido_tecnico_model.dart';
import 'package:acoplan/app/core/client/models/detalhamento_model.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfPedidoTecnico {
  static List<BitolaModel> _produtos = [];

  static Future<Uint8List> gerar({
    required PedidoTecnicoModel pedido,
    DetalhamentoModel? detalhamento,
    required bool completo,
    List<BitolaModel> produtos = const [],
  }) async {
    _produtos = produtos;
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
                          'Nº ${pedido.detalhamentoCodigo}${detalhamento != null && detalhamento.descricao.isNotEmpty ? ' - ${detalhamento.descricao}' : ''}',
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
                              : '-',
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
                            : '-',
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
                          : '-',
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
                            'Qtde: ${elem.elementoQuantidade}  |  ${elemDetalhamento.posicoes.length} posicao(oes)  |  ${elem.pesoTotal > 0 ? '${elem.pesoTotal.toStringAsFixed(2)} kg' : '-'}',
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
                                  _celTbl(pos.posicao, estCelula,
                                      align: pw.Alignment.center),
                                  _celTbl(pos.bitolaNome, estCelula),
                                  _celTbl(pos.formaCodigo, estCelula),
                                  _celTbl('${pos.qtde}', estCelula,
                                      align: pw.Alignment.center),
                                  _celTbl(
                                    pos.comprimentoDeCorte > 0
                                        ? pos.comprimentoDeCorte.toStringAsFixed(1)
                                        : '-',
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

            // ── Resumo de Aço ──
            if (detalhamento != null) ...[
              pw.SizedBox(height: 24),
              pw.Text(
                'RESUMO DE AÇO',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: corPrimaria,
                  letterSpacing: 1,
                ),
              ),
              pw.SizedBox(height: 8),
              _buildResumoAco(
                pedido: pedido,
                detalhamento: detalhamento,
                corPrimaria: corPrimaria,
                corFundoCabecalho: corFundoCabecalho,
                corBorda: corBorda,
                corVerde: corVerde,
                estCabTbl: estCabTbl,
                estCelula: estCelula,
                estCelulaDestaque: estCelulaDestaque,
              ),
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

  // ── Relatório de Elementos (grid de cards) ───────────────────────────────
  static Future<Uint8List> gerarElementos({
    required PedidoTecnicoModel pedido,
    DetalhamentoModel? detalhamento,
    List<BitolaModel> produtos = const [],
  }) async {
    _produtos = produtos;
    final pdf = pw.Document();
    final fmtData = DateFormat('dd/MM/yyyy');
    final fmtHora = DateFormat('HH:mm');
    final agora = DateTime.now();

    const corPrimaria = PdfColor.fromInt(0xFF0F172A);
    const corFundoCabecalho = PdfColor.fromInt(0xFFF1F5F9);
    const corBorda = PdfColor.fromInt(0xFFE2E8F0);
    const corVerde = PdfColor.fromInt(0xFF10B981);
    const corSubcard = PdfColor.fromInt(0xFFF8FAFC);
    const corCinzaTexto = PdfColor.fromInt(0xFF64748B);
    const corCinzaClaro = PdfColor.fromInt(0xFF94A3B8);

    // ── Constrói um sub-card de posição (SEQ) ──
    pw.Widget buildOsCard(PosicaoModel pos, int qtdeSol, String seqLabel) {
      final qtdeTotal = pos.qtde * qtdeSol;
      // Bitola: usa só a parte antes do traço se for muito longa
      final bitola = pos.bitolaNome.length > 18
          ? pos.bitolaNome.substring(0, 17)
          : pos.bitolaNome;
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        decoration: pw.BoxDecoration(
          color: corSubcard,
          border: pw.Border.all(color: corBorda, width: 0.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
        ),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              'SEQ $seqLabel',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: corPrimaria,
              ),
            ),
            pw.SizedBox(height: 1),
            pw.Text(
              'Pos ${pos.posicao}',
              style: pw.TextStyle(fontSize: 6, color: corCinzaClaro),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              bitola,
              style: pw.TextStyle(fontSize: 7, color: corCinzaTexto),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              '× $qtdeTotal',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: corVerde,
              ),
            ),
          ],
        ),
      );
    }

    // ── Constrói um card de elemento ──
    pw.Widget buildElementCard(PedidoTecnicoElementoModel elem) {
      final elemDet = detalhamento?.elementos
          .where((e) => e.id == elem.elementoId)
          .firstOrNull;
      final posicoes = (elemDet?.posicoes ?? <PosicaoModel>[])
          .where((p) => p.qtde > 0)
          .toList();
      final qtdeSol = elem.quantidadeSolicitada;

      // Sub-cards em fileiras de 2, com SEQ calculado por índice
      final osRows = <pw.Widget>[];
      for (int i = 0; i < posicoes.length; i += 2) {
        final hasRight = i + 1 < posicoes.length;
        final seqL = elem.sequenciaDaPosicao(i);
        final seqR = elem.sequenciaDaPosicao(i + 1);
        final lblL = seqL != null ? '$seqL' : '—';
        final lblR = seqR != null ? '$seqR' : '—';
        osRows.add(pw.Row(
          children: [
            pw.Expanded(child: buildOsCard(posicoes[i], qtdeSol, lblL)),
            pw.SizedBox(width: 3),
            pw.Expanded(
              child: hasRight
                  ? buildOsCard(posicoes[i + 1], qtdeSol, lblR)
                  : pw.SizedBox(),
            ),
          ],
        ));
        if (i + 2 < posicoes.length) osRows.add(pw.SizedBox(height: 3));
      }

      return pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: corBorda, width: 0.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Header do card
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: const pw.BoxDecoration(
                color: corPrimaria,
                borderRadius: pw.BorderRadius.only(
                  topLeft: pw.Radius.circular(4),
                  topRight: pw.Radius.circular(4),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      elem.elementoNome,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                  pw.Text(
                    '× $qtdeSol',
                    style: pw.TextStyle(fontSize: 8, color: corCinzaClaro),
                  ),
                ],
              ),
            ),
            // Área dos sub-cards
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: posicoes.isEmpty
                  ? pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6),
                      child: pw.Text(
                        'Sem posições',
                        style: pw.TextStyle(fontSize: 7, color: PdfColors.grey),
                        textAlign: pw.TextAlign.center,
                      ),
                    )
                  : pw.Column(children: osRows),
            ),
          ],
        ),
      );
    }

    // ── Agrupa elementos em fileiras de 3 (ordenados por elemento + OS) ──
    final List<pw.Widget> linhas = [];
    final elems = List<PedidoTecnicoElementoModel>.from(pedido.elementos)
      ..sort((a, b) {
        final cmp = compararNatural(a.elementoNome, b.elementoNome);
        if (cmp != 0) return cmp;
        return (a.sequenciaInicio ?? 0).compareTo(b.sequenciaInicio ?? 0);
      });
    for (int i = 0; i < elems.length; i += 3) {
      final grupo = elems.sublist(i, (i + 3).clamp(0, elems.length));
      final rowCells = <pw.Widget>[];
      for (int j = 0; j < grupo.length; j++) {
        if (j > 0) rowCells.add(pw.SizedBox(width: 5));
        rowCells.add(pw.Expanded(child: buildElementCard(grupo[j])));
      }
      // Preenchimento para manter 3 colunas
      for (int j = grupo.length; j < 3; j++) {
        rowCells.add(pw.SizedBox(width: 5));
        rowCells.add(pw.Expanded(child: pw.SizedBox()));
      }
      linhas.add(pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: rowCells,
      ));
      linhas.add(pw.SizedBox(height: 6));
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        header: (_) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
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
                  pw.Text(
                    'PEDIDO TÉCNICO',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: corPrimaria,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Relatório de Elementos',
                    style: pw.TextStyle(fontSize: 9, color: corCinzaTexto),
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: corPrimaria,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      pedido.identificador.isNotEmpty
                          ? pedido.identificador
                          : 'PT ${pedido.codigo.toString().padLeft(4, '0')}',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.Text(
                      pedido.isAberto ? 'ABERTO' : 'CANCELADO',
                      style: pw.TextStyle(
                        fontSize: 7,
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
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            ),
            pw.Text(
              'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            ),
          ],
        ),
        build: (ctx) => [
          // Barra de informações
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            margin: const pw.EdgeInsets.only(bottom: 12),
            decoration: pw.BoxDecoration(
              color: corFundoCabecalho,
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: corBorda, width: 0.5),
            ),
            child: pw.Row(
              children: [
                _infoColElem('CLIENTE', pedido.clienteNome),
                pw.SizedBox(width: 10),
                _infoColElem('OBRA', pedido.obraNome),
                pw.SizedBox(width: 10),
                _infoColElem(
                    'DATA', fmtData.format(pedido.criadoEm.toLocal())),
                pw.SizedBox(width: 10),
                _infoColElem('ELEMENTOS', '${pedido.elementos.length}'),
                pw.SizedBox(width: 10),
                _infoColElem(
                  'PESO TOTAL',
                  pedido.pesoTotal > 0
                      ? '${pedido.pesoTotal.toStringAsFixed(2)} kg'
                      : '-',
                  corValor: corVerde,
                ),
              ],
            ),
          ),
          // Grid de cards
          ...linhas,
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _infoColElem(
    String label,
    String valor, {
    PdfColor? corValor,
  }) =>
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFF64748B),
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              valor,
              style: pw.TextStyle(
                fontSize: 8,
                color: corValor ?? const PdfColor.fromInt(0xFF0F172A),
                fontWeight:
                    corValor != null ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ],
        ),
      );

  // ── Massa linear (kg/m) ──────────────────────────────────────────────────
  /// Busca massaFinal real no cadastro de produtos, fallback para d²/162.
  static double _massaLinear(PosicaoModel pos) {
    final produto = _produtos.where((p) => p.id == pos.bitolaId).firstOrNull;
    if (produto != null && produto.massaFinal > 0) {
      return produto.massaFinal;
    }
    final str = pos.bitolaNome.split('-').first.replaceAll(RegExp(r'[^0-9.]'), '');
    final d = double.tryParse(str) ?? 0;
    return (d * d) / 162;
  }

  // ── Peso total de uma posição (peça a peça para variáveis) ──────────────
  static double _pesoTotalPosicao(PosicaoModel pos) {
    final w = _massaLinear(pos);
    if (w <= 0 || pos.qtde <= 0) return 0;

    final temVar = pos.variaveisConfig.isNotEmpty &&
        pos.variaveis.values.any((v) => v);

    if (!temVar) {
      final somaCm = pos.comprimentos.values.fold<double>(0.0, (s, v) => s + v);
      return (somaCm / 100.0) * w * pos.qtde;
    }

    double pesoTotal = 0;
    for (int peca = 0; peca < pos.qtde; peca++) {
      double somaCm = 0.0;
      for (final entry in pos.comprimentos.entries) {
        final trecho = entry.key;
        final isVar = pos.variaveis[trecho] ?? false;
        if (isVar) {
          final config = pos.variaveisConfig[trecho]
              ?? pos.variaveisConfig.values.firstOrNull;
          if (config != null && config.inicial > 0 && config.final_ > 0) {
            final expandidas = config.medidasExpandidas(pos.multiplicador);
            somaCm += peca < expandidas.length
                ? expandidas[peca].toDouble()
                : (expandidas.isNotEmpty ? expandidas.last.toDouble() : 0.0);
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

  // ── Resumo de Aço (tabela por bitola) ────────────────────────────────────
  static pw.Widget _buildResumoAco({
    required PedidoTecnicoModel pedido,
    required DetalhamentoModel detalhamento,
    required PdfColor corPrimaria,
    required PdfColor corFundoCabecalho,
    required PdfColor corBorda,
    required PdfColor corVerde,
    required pw.TextStyle estCabTbl,
    required pw.TextStyle estCelula,
    required pw.TextStyle estCelulaDestaque,
  }) {
    // Só considerar elementos que fazem parte do pedido
    final resumoPeso = <String, double>{};
    final resumoComp = <String, double>{}; // cm

    for (final elem in pedido.elementos) {
      final elemDet = detalhamento.elementos
          .where((e) => e.id == elem.elementoId)
          .firstOrNull;
      if (elemDet == null) continue;

      final qtdeElem = elem.quantidadeSolicitada;

      for (final pos in elemDet.posicoes) {
        final bitola = pos.bitolaNome.split('-').first.trim();
        final compUnit = pos.comprimentos.values.fold<double>(0.0, (s, v) => s + v);
        final compTotalCm = compUnit * pos.qtde * qtdeElem;
        final pesoTotal = _pesoTotalPosicao(pos) * qtdeElem;

        resumoPeso[bitola] = (resumoPeso[bitola] ?? 0) + pesoTotal;
        resumoComp[bitola] = (resumoComp[bitola] ?? 0) + compTotalCm;
      }
    }

    final bitolasOrdenadas = resumoPeso.keys.toList()..sort();
    double pesoTotalGeral = 0;

    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
      },
      border: pw.TableBorder.all(color: corBorda, width: 0.5),
      children: [
        // Cabeçalho
        pw.TableRow(
          decoration: pw.BoxDecoration(color: corPrimaria),
          children: [
            _celTbl('BITOLA', estCabTbl),
            _celTbl('COMPR. TOTAL', estCabTbl, align: pw.Alignment.center),
            _celTbl('PESO TOTAL', estCabTbl, align: pw.Alignment.center),
          ],
        ),
        // Linhas por bitola
        ...bitolasOrdenadas.asMap().entries.map((entry) {
          final i = entry.key;
          final b = entry.value;
          final peso = resumoPeso[b] ?? 0;
          final compM = (resumoComp[b] ?? 0) / 100;
          pesoTotalGeral += peso;
          final bg = i % 2 == 0
              ? PdfColors.white
              : const PdfColor.fromInt(0xFFF8FAFC);
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              _celTbl(b, estCelulaDestaque),
              _celTbl('${compM.toStringAsFixed(2)} m', estCelula,
                  align: pw.Alignment.center),
              _celTbl('${peso.toStringAsFixed(2)} kg', estCelula,
                  align: pw.Alignment.center),
            ],
          );
        }),
        // Totalizador
        pw.TableRow(
          decoration: pw.BoxDecoration(color: corFundoCabecalho),
          children: [
            _celTbl('TOTAL GERAL', estCelulaDestaque),
            _celTbl('', estCelula),
            _celTbl(
              '${pesoTotalGeral.toStringAsFixed(2)} kg',
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
    );
  }
}
