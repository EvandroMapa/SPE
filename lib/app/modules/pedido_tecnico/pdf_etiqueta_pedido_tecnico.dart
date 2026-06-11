import 'dart:math' as math;
import 'dart:typed_data';
import 'package:acoplan/app/core/client/models/forma_model.dart';
import 'package:acoplan/app/core/client/models/pedido_tecnico_model.dart';
import 'package:acoplan/app/core/client/models/detalhamento_model.dart';
import 'package:acoplan/app/core/client/models/trecho_variavel_config.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Etiqueta 9 × 14 cm — impressora térmica — só preto/branco
class PdfEtiquetaPedidoTecnico {
  static const _corPreto = PdfColors.black;
  static const _corBranco = PdfColors.white;

  static final _formato = PdfPageFormat(
    9 * PdfPageFormat.cm,
    14 * PdfPageFormat.cm,
    marginAll: 0,
  );

  // ── Estilos ──────────────────────────────────────────────────────────────
  static final _sTarjaId = pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _corBranco, letterSpacing: 1.2);
  static final _sTarjaLabel = pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: _corBranco, letterSpacing: 0.7);
  static final _sTarjaValor = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _corBranco);
  static final _sTarjaGrande = pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _corBranco);
  static final _sLabel = pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: _corPreto, letterSpacing: 0.7);
  static final _sValor = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _corPreto);
  static final _sMini = pw.TextStyle(fontSize: 7, color: _corPreto);
  static final _sMiniBold = pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _corPreto);
  static final _sTrechoLinha = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _corPreto);

  // ── Gerador principal ────────────────────────────────────────────────────
  static Future<Uint8List> gerar({
    required PedidoTecnicoModel pedido,
    required DetalhamentoModel detalhamento,
    required List<FormaModel> formasCadastradas,
  }) async {
    final pdf = pw.Document();
    for (final elem in pedido.elementos) {
      final elemDetalhamento = detalhamento.elementos.where((e) => e.id == elem.elementoId).firstOrNull;
      if (elemDetalhamento == null) continue;
      for (final pos in elemDetalhamento.posicoes) {
        final formaDef = formasCadastradas.where((f) => f.codigo == pos.formaCodigo).firstOrNull;
        // Etiqueta principal
        pdf.addPage(pw.Page(
          pageFormat: _formato,
          margin: pw.EdgeInsets.zero,
          build: (_) => _buildEtiqueta(pedido: pedido, elem: elem, elemDetalhamento: elemDetalhamento, pos: pos, formaDef: formaDef),
        ));

        // Se tem trecho variável → DUAS etiquetas extras
        final temVar = pos.variaveis.values.any((v) => v) && pos.variaveisConfig.isNotEmpty;
        if (temVar) {
          // Etiqueta 2: trechos variáveis
          pdf.addPage(pw.Page(
            pageFormat: _formato,
            margin: pw.EdgeInsets.zero,
            build: (_) => _buildEtiquetaTrechosVar(
              pedido: pedido, elem: elem, elemDetalhamento: elemDetalhamento,
              pos: pos,
            ),
          ));
          // Etiqueta 3: comprimentos + comprimento de corte
          pdf.addPage(pw.Page(
            pageFormat: _formato,
            margin: pw.EdgeInsets.zero,
            build: (_) => _buildEtiquetaComprimentos(
              pedido: pedido, elem: elem, elemDetalhamento: elemDetalhamento,
              pos: pos,
            ),
          ));
        }
      }
    }
    return pdf.save();
  }

  // ── Layout ───────────────────────────────────────────────────────────────
  static pw.Widget _buildEtiqueta({
    required PedidoTecnicoModel pedido,
    required PedidoTecnicoElementoModel elem,
    required ElementoModel elemDetalhamento,
    required PosicaoModel pos,
    FormaModel? formaDef,
  }) {
    final id = pedido.identificador.isNotEmpty ? pedido.identificador : 'PT ${pedido.codigo.toString().padLeft(3, '0')}';
    final bitolaStr = pos.bitolaNome.split('-').first.trim();
    final compUnit = pos.comprimentos.values.fold<double>(0.0, (s, v) => s + v);
    final compCorteRaw = pos.comprimentoDeCorte > 0 ? pos.comprimentoDeCorte : compUnit.toDouble();

    // Verificar se tem variáveis para mostrar range
    final temVar = pos.variaveis.values.any((v) => v) && pos.variaveisConfig.isNotEmpty;
    String compUnitStr;
    String compCorteStr;
    if (temVar) {
      // Calcular min/max comprimento por peça
      int compMin = 999999; double compMax = 0;
      final desconto = pos.descontoDobraSnapshot ?? 0;
      final dCm = (double.tryParse(bitolaStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0) / 10.0;
      for (int peca = 0; peca < pos.qtde; peca++) {
        double soma = 0;
        for (final entry in pos.comprimentos.entries) {
          final trecho = entry.key;
          final isVar = pos.variaveis[trecho] ?? false;
          if (isVar) {
            final config = pos.variaveisConfig[trecho]
                ?? pos.variaveisConfig.values.firstOrNull;
            if (config != null && config.inicial > 0 && config.final_ > 0) {
              final expandidas = config.medidasExpandidas(pos.multiplicador);
              soma += peca < expandidas.length
                  ? expandidas[peca].toDouble()
                  : (expandidas.isNotEmpty ? expandidas.last.toDouble() : 0.0);
            } else {
              soma += entry.value;
            }
          } else {
            soma += entry.value;
          }
        }
        if (soma < compMin) compMin = soma.toInt();
        if (soma > compMax) compMax = soma;
      }
      compUnitStr = compMin == compMax ? '$compMin cm' : '$compMin var $compMax';
      if (pos.comprimentoDeCorte > 0) {
        final corteMin = (compMin - desconto * dCm).clamp(0, compMin.toDouble());
        final corteMax = (compMax - desconto * dCm).clamp(0, compMax.toDouble());
        final cMinStr = corteMin == corteMin.roundToDouble() ? corteMin.toInt().toString() : corteMin.toStringAsFixed(1);
        final cMaxStr = corteMax == corteMax.roundToDouble() ? corteMax.toInt().toString() : corteMax.toStringAsFixed(1);
        compCorteStr = cMinStr == cMaxStr ? '$cMinStr cm' : '$cMinStr var $cMaxStr';
      } else {
        compCorteStr = compUnitStr;
      }
    } else {
      compUnitStr = '$compUnit cm';
      compCorteStr = '${compCorteRaw == compCorteRaw.roundToDouble() ? compCorteRaw.toInt() : compCorteRaw.toStringAsFixed(1)} cm';
    }

    // Trechos: "A=30  B=40  C=86*"
    final trechosStr = pos.comprimentos.entries
        .map((e) => '${e.key}=${e.value}cm${(pos.variaveis[e.key] ?? false) ? '*' : ''}')
        .join('   ');

    return pw.Padding(
      padding: const pw.EdgeInsets.all(7),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // 1 ── IDENTIFICADOR
          _boxPreta(radius: 6, vPad: 5,
            child: pw.Center(child: pw.Text(id, style: _sTarjaId)),
          ),
          pw.SizedBox(height: 3),

          // 2 ── CLIENTE / OBRA
          _boxBranca(radius: 5, vPad: 4,
            child: pw.Row(children: [
              pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('CLIENTE', style: _sLabel),
                pw.Text(pedido.clienteNome, style: _sValor, maxLines: 1),
              ])),
              pw.Container(width: 0.8, height: 24, color: _corPreto),
              pw.SizedBox(width: 8),
              pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('OBRA', style: _sLabel),
                pw.Text(pedido.obraNome, style: _sValor, maxLines: 1),
              ])),
            ]),
          ),
          pw.SizedBox(height: 3),

          // 3 ── ELEMENTO
          _boxPreta(radius: 5, vPad: 4,
            child: pw.Row(children: [
              pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('ELEMENTO', style: _sTarjaLabel),
                pw.Text(elem.elementoNome.isEmpty ? '-' : elem.elementoNome, style: _sTarjaGrande, maxLines: 1),
              ])),
              pw.Container(width: 0.8, height: 24, color: _corBranco),
              pw.SizedBox(width: 8),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                pw.Text('QTDE', style: _sTarjaLabel),
                pw.Text('${elem.quantidadeSolicitada}', style: _sTarjaValor),
              ]),
            ]),
          ),
          pw.SizedBox(height: 3),

          // 4 ── POSIÇÃO
          _boxBranca(radius: 5, vPad: 4,
            child: pw.Column(children: [
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
                _col('POS', '${pos.posicao}', fontSize: 15),
                pw.Container(width: 0.8, height: 28, color: _corPreto),
                _colQtdeMult(pos),
                pw.Container(width: 0.8, height: 28, color: _corPreto),
                _col('BITOLA', bitolaStr),
                pw.Container(width: 0.8, height: 28, color: _corPreto),
                _col('FORMA', pos.formaCodigo),
              ]),
              pw.Container(margin: const pw.EdgeInsets.symmetric(vertical: 3), height: 0.8, color: _corPreto),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
                _col('C. UNITÁRIO', compUnitStr),
                pw.Container(width: 0.8, height: 22, color: _corPreto),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                  pw.Text('C. DE CORTE', style: _sLabel),
                  pw.SizedBox(height: 2),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: pw.BoxDecoration(color: _corPreto, borderRadius: pw.BorderRadius.circular(3)),
                    child: pw.Text(compCorteStr, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _corBranco)),
                  ),
                ]),
              ]),
            ]),
          ),
          pw.SizedBox(height: 3),



          // 6 ── DESENHO — expande para ocupar espaço restante
          pw.Expanded(
            child: pw.Container(
              decoration: pw.BoxDecoration(
                color: _corBranco,
                borderRadius: pw.BorderRadius.circular(5),
                border: pw.Border.all(color: _corPreto, width: 0.8),
              ),
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: formaDef == null || formaDef.itens.isEmpty
                    ? pw.Center(child: pw.Text('SEM DESENHO', style: _sMiniBold))
                    : _buildDesenhoForma(formaDef, pos.comprimentos, variaveis: pos.variaveis, variaveisConfig: pos.variaveisConfig),
              ),
            ),
          ),

          // 7 ── RODAPÉ
          pw.SizedBox(height: 3),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Det. ${pedido.detalhamentoCodigo}', style: _sMini),
            pw.Text(id, style: _sMiniBold),
          ]),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  static pw.Widget _boxPreta({required pw.Widget child, double radius = 5, double vPad = 6}) =>
      pw.Container(
        width: double.infinity,
        padding: pw.EdgeInsets.symmetric(horizontal: 10, vertical: vPad),
        decoration: pw.BoxDecoration(color: _corPreto, borderRadius: pw.BorderRadius.circular(radius)),
        child: child,
      );

  static pw.Widget _boxBranca({required pw.Widget child, double radius = 5, double vPad = 6}) =>
      pw.Container(
        width: double.infinity,
        padding: pw.EdgeInsets.symmetric(horizontal: 10, vertical: vPad),
        decoration: pw.BoxDecoration(
          color: _corBranco,
          borderRadius: pw.BorderRadius.circular(radius),
          border: pw.Border.all(color: _corPreto, width: 0.8),
        ),
        child: child,
      );

  static pw.Widget _col(String label, String valor, {double fontSize = 10}) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Text(label, style: _sLabel),
        pw.SizedBox(height: 2),
        pw.Text(valor, style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold, color: _corPreto)),
      ]);

  /// QTDE com multiplicador: mostra total e abaixo (mult × N) quando mult > 1
  static pw.Widget _colQtdeMult(PosicaoModel pos) {
    final mult = pos.multiplicador;
    final qtde = pos.qtde;
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
      pw.Text('QTDE', style: _sLabel),
      pw.SizedBox(height: 2),
      pw.Text('$qtde', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _corPreto)),
      if (mult > 1) ...[
        pw.SizedBox(height: 1),
        pw.Text('($mult x ${qtde ~/ mult})', style: pw.TextStyle(fontSize: 6, color: _corPreto)),
      ],
    ]);
  }

  static List<pw.Widget> _variaveisExpandidas(PosicaoModel pos) {
    final result = <pw.Widget>[];
    for (final entry in pos.variaveis.entries.where((e) => e.value)) {
      final config = pos.variaveisConfig[entry.key] ?? pos.variaveisConfig.values.firstOrNull;
      if (config == null || config.inicial <= 0) continue;
      final expandidas = config.medidasExpandidas(pos.multiplicador);
      final medidasStr = expandidas.isNotEmpty ? expandidas.join(', ') : config.medidas.join(', ');
      result.add(pw.SizedBox(height: 2));
      result.add(pw.Text(
        '${entry.key}* ${pos.multiplicador > 1 ? 'x${pos.multiplicador}  ' : ''}> $medidasStr cm',
        style: _sMini,
      ));
    }
    return result;
  }

  // ── Desenho da forma — labels desenhados NO canvas para coordenadas corretas
  static pw.Widget _buildDesenhoForma(FormaModel forma, Map<String, double> medidas, {Map<String, bool> variaveis = const {}, Map<String, TrechoVariavelConfig> variaveisConfig = const {}}) {
    if (forma.itens.isEmpty) return pw.SizedBox();

    // Usar comprimentos ORIGINAIS da forma para geometria fiel ao cadastro
    final itens = forma.itens.map((it) => FormaItemModel(
      trecho: it.trecho,
      comprimento: it.comprimento,
      angulo: it.angulo,
      orientacao: it.orientacao,
      tipo: it.tipo,
      linhaDivisoria: it.linhaDivisoria,
    )).toList();

    // Calcular pontos no espaço modelo
    final pts = <PdfPoint>[const PdfPoint(0, 0)];
    double ang = forma.rotacao;
    for (final it in itens) {
      final r = ang * math.pi / 180;
      final last = pts.last;
      if (it.tipo == 'circulo') {
        final chord = 2 * it.comprimento * math.sin(10 * math.pi / 180);
        pts.add(PdfPoint(last.x + chord * math.cos(r), last.y + chord * math.sin(r)));
      } else {
        pts.add(PdfPoint(last.x + it.comprimento * math.cos(r), last.y + it.comprimento * math.sin(r)));
      }
      ang += it.orientacao == 'Horário' ? it.angulo : -it.angulo;
    }

    // Bounding box (inclui círculos)
    final ptsBox = List<PdfPoint>.from(pts);
    for (var i = 0; i < itens.length && i < pts.length - 1; i++) {
      if (itens[i].tipo == 'circulo') {
        final cx = pts[i + 1].x - pts[i].x;
        final cy = pts[i + 1].y - pts[i].y;
        final cl = math.sqrt(cx * cx + cy * cy);
        if (cl < 1) continue;
        final px = -cy / cl, py = cx / cl;
        final offset = itens[i].comprimento * math.cos(170 * math.pi / 180);
        final mx = (pts[i].x + pts[i + 1].x) / 2;
        final my = (pts[i].y + pts[i + 1].y) / 2;
        final cX = mx + px * offset, cY = my + py * offset;
        final rd = itens[i].comprimento.toDouble();
        ptsBox.addAll([PdfPoint(cX + rd, cY), PdfPoint(cX - rd, cY), PdfPoint(cX, cY + rd), PdfPoint(cX, cY - rd)]);
      }
    }

    double mnX = ptsBox[0].x, mxX = ptsBox[0].x, mnY = ptsBox[0].y, mxY = ptsBox[0].y;
    for (final p in ptsBox) {
      if (p.x < mnX) mnX = p.x; if (p.x > mxX) mxX = p.x;
      if (p.y < mnY) mnY = p.y; if (p.y > mxY) mxY = p.y;
    }

    return pw.LayoutBuilder(
      builder: (context, constraints) {
        final cW = constraints!.maxWidth > 0 ? constraints.maxWidth : 200.0;
        final cH = constraints.maxHeight > 0 ? constraints.maxHeight : 150.0;

    final pad = math.min(cW, cH) * 0.12;
      final dw = cW - pad * 2, dh = cH - pad * 2;
      final lw = mxX - mnX, lh = mxY - mnY;
      final esc = (lw == 0 && lh == 0) ? 1.0 : math.min(dw / (lw == 0 ? 1 : lw), dh / (lh == 0 ? 1 : lh));
      final ox = (cW - lw * esc) / 2 - mnX * esc;
      final oy = (cH - lh * esc) / 2 - mnY * esc;

      // Canvas: Y-flip (modelo y-up → canvas y-down)
      PdfPoint toTela(PdfPoint p) => PdfPoint(p.x * esc + ox, cH - (p.y * esc + oy));
      final display = pts.map(toTela).toList();

      // Labels: sem Y-flip (para pw.Positioned y-down)
      PdfPoint toWidget(PdfPoint p) => PdfPoint(p.x * esc + ox, p.y * esc + oy);

      // Dados dos labels: calculados em espaço widget (para pw.Positioned)
      final labels = <({double x, double y, String texto})>[];
      for (var i = 0; i < pts.length - 1; i++) {
        final w1 = toWidget(pts[i]), w2 = toWidget(pts[i + 1]);
        final midX = (w1.x + w2.x) / 2;
        final midY = (w1.y + w2.y) / 2;
        final dx = w2.x - w1.x, dy = w2.y - w1.y;
        final len = math.sqrt(dx * dx + dy * dy);
        if (len < 1) continue;
        final trecho = itens[i].trecho;
        final isVar = variaveis[trecho] ?? false;
        String label;
        if (isVar) {
          final config = variaveisConfig[trecho] ?? variaveisConfig.values.firstOrNull;
          if (config != null && config.inicial > 0 && config.final_ > 0) {
            label = '${config.inicial} var ${config.final_}';
          } else {
            label = (medidas[trecho] ?? itens[i].comprimento).toString();
          }
        } else {
          label = (medidas[trecho] ?? itens[i].comprimento).toString();
        }
        final boxW = label.length * 2.5 + 5;
        const boxH = 7.0;
        final lx = (midX - boxW / 2).clamp(1.0, cW - boxW);
        final ly = (midY - boxH / 2).clamp(1.0, cH - boxH);
        labels.add((x: lx, y: ly, texto: label));
      }

      return pw.SizedBox(
        width: cW,
        height: cH,
        child: pw.Stack(children: [
          pw.Positioned.fill(
            child: pw.CustomPaint(
              painter: (canvas, size) {
                // Traços
                canvas.setStrokeColor(_corPreto);
                canvas.setLineWidth(1.4);
                canvas.setLineJoin(PdfLineJoin.round);
                canvas.setLineCap(PdfLineCap.round);
                for (var i = 0; i < display.length - 1; i++) {
                  final isCirculo = i < itens.length && itens[i].tipo == 'circulo';
                  if (isCirculo) {
                    final cx = display[i + 1].x - display[i].x;
                    final cy = display[i + 1].y - display[i].y;
                    final cl = math.sqrt(cx * cx + cy * cy);
                    if (cl < 1) { canvas.drawLine(display[i].x, display[i].y, display[i+1].x, display[i+1].y); continue; }
                    final px = -cy / cl, py = cx / cl;
                    final rScreen = itens[i].comprimento * esc;
                    final offsetS = rScreen * math.cos(170 * math.pi / 180);
                    final mx = (display[i].x + display[i + 1].x) / 2;
                    final my = (display[i].y + display[i + 1].y) / 2;
                    canvas.drawEllipse(mx + px * offsetS, my + py * offsetS, rScreen, rScreen);
                  } else {
                    canvas.drawLine(display[i].x, display[i].y, display[i+1].x, display[i+1].y);
                  }
                }
                canvas.strokePath();

                // Linhas divisórias
                for (var i = 0; i < display.length - 1 && i < itens.length; i++) {
                  if (!itens[i].linhaDivisoria) continue;
                  final p1d = display[i];
                  final p2d = display[i + 1];
                  final ddx = p2d.x - p1d.x;
                  final ddy = p2d.y - p1d.y;
                  final dlen = math.sqrt(ddx * ddx + ddy * ddy);
                  if (dlen < 1) continue;
                  final nx = -ddy / dlen;
                  final ny =  ddx / dlen;
                  const half = 8.0;
                  canvas.setStrokeColor(_corPreto);
                  canvas.setLineWidth(1.0);
                  canvas.drawLine(
                    p2d.x + nx * half, p2d.y + ny * half,
                    p2d.x - nx * half, p2d.y - ny * half,
                  );
                  canvas.strokePath();
                }
              },
            ),
          ),
          // Labels com box escuro e texto branco
          for (final lbl in labels)
            pw.Positioned(
              left: lbl.x,
              top: lbl.y,
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 0.5),
                decoration: pw.BoxDecoration(
                  color: _corPreto,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                ),
                child: pw.Text(lbl.texto,
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _corBranco)),
              ),
            ),
        ]),
      );
      },
    );
  }

  // ── Etiqueta 2: TRECHOS VARIÁVEIS ──────────────────────────────────────
  static pw.Widget _buildEtiquetaTrechosVar({
    required PedidoTecnicoModel pedido,
    required PedidoTecnicoElementoModel elem,
    required ElementoModel elemDetalhamento,
    required PosicaoModel pos,
  }) {
    final id = pedido.identificador.isNotEmpty ? pedido.identificador : 'PT ${pedido.codigo.toString().padLeft(3, '0')}';

    // Medidas expandidas por trecho variável
    final medidasPorTrecho = <String, List<int>>{};
    for (final entry in pos.variaveis.entries.where((e) => e.value)) {
      final trecho = entry.key;
      final config = pos.variaveisConfig[trecho]
          ?? pos.variaveisConfig.values.firstOrNull;
      if (config != null && config.inicial > 0) {
        medidasPorTrecho[trecho] = config.medidasExpandidas(pos.multiplicador);
      }
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.all(7),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // IDENTIFICADOR
          _boxPreta(radius: 6, vPad: 5,
            child: pw.Center(child: pw.Text(id, style: _sTarjaId)),
          ),
          pw.SizedBox(height: 3),

          // POS / BITOLA / FORMA / QTDE
          _boxBranca(radius: 5, vPad: 4,
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
              _col('POS', '${pos.posicao}', fontSize: 15),
              pw.Container(width: 0.8, height: 28, color: _corPreto),
              _col('BITOLA', pos.bitolaNome.split('-').first.trim()),
              pw.Container(width: 0.8, height: 28, color: _corPreto),
              _col('FORMA', pos.formaCodigo),
              pw.Container(width: 0.8, height: 28, color: _corPreto),
              _colQtdeMult(pos),
            ]),
          ),
          pw.SizedBox(height: 3),

          // Inscrição MEDIDAS VARIÁVEIS
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: pw.BoxDecoration(
              color: _corPreto,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(5),
                topRight: pw.Radius.circular(5),
              ),
            ),
            child: pw.Center(child: pw.Text('MEDIDAS VARIAVEIS', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _corBranco, letterSpacing: 1))),
          ),

          // Subtítulo: X peças de cada medida - N medidas
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: pw.BoxDecoration(
              color: _corBranco,
              border: pw.Border(
                left: pw.BorderSide(color: _corPreto, width: 0.8),
                right: pw.BorderSide(color: _corPreto, width: 0.8),
                bottom: pw.BorderSide(color: _corPreto, width: 0.5),
              ),
            ),
            child: pw.Text(
              '${pos.multiplicador} peca${pos.multiplicador > 1 ? 's' : ''} de cada medida - ${pos.qtde ~/ pos.multiplicador} medidas',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _corPreto),
              textAlign: pw.TextAlign.center,
            ),
          ),
          // Campo grande — trechos variáveis
          pw.Expanded(
            child: pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                color: _corBranco,
                borderRadius: const pw.BorderRadius.only(
                  bottomLeft: pw.Radius.circular(5),
                  bottomRight: pw.Radius.circular(5),
                ),
                border: pw.Border.all(color: _corPreto, width: 0.8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  ...medidasPorTrecho.entries.map((entry) {
                    final trecho = entry.key;
                    final medidas = entry.value;
                    return pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: pw.BoxDecoration(color: _corPreto, borderRadius: pw.BorderRadius.circular(3)),
                          child: pw.Text(trecho, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _corBranco)),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Wrap(
                          spacing: 4,
                          runSpacing: 3,
                          children: medidas.asMap().entries.map((m) {
                            return pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: _corPreto, width: 0.5),
                                borderRadius: pw.BorderRadius.circular(3),
                              ),
                              child: pw.Text(
                                '${m.value}',
                                style: const pw.TextStyle(fontSize: 7),
                              ),
                            );
                          }).toList(),
                        ),
                        pw.SizedBox(height: 4),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),

          // RODAPÉ
          pw.SizedBox(height: 3),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Pos ${pos.posicao}  |  ${pos.qtde} pecas', style: _sMini),
            pw.Text(id, style: _sMiniBold),
          ]),
        ],
      ),
    );
  }

  // ── Etiqueta 3: COMPRIMENTOS + CORTE POR PEÇA ──────────────────────────
  static pw.Widget _buildEtiquetaComprimentos({
    required PedidoTecnicoModel pedido,
    required PedidoTecnicoElementoModel elem,
    required ElementoModel elemDetalhamento,
    required PosicaoModel pos,
  }) {
    final id = pedido.identificador.isNotEmpty ? pedido.identificador : 'PT ${pedido.codigo.toString().padLeft(3, '0')}';

    // Comprimento total por peça
    final comprimentosPorPeca = <double>[];
    for (int peca = 0; peca < pos.qtde; peca++) {
      double soma = 0;
      for (final entry in pos.comprimentos.entries) {
        final trecho = entry.key;
        final isVar = pos.variaveis[trecho] ?? false;
        if (isVar) {
          final config = pos.variaveisConfig[trecho]
              ?? pos.variaveisConfig.values.firstOrNull;
          if (config != null && config.inicial > 0 && config.final_ > 0) {
            final expandidas = config.medidasExpandidas(pos.multiplicador);
            soma += peca < expandidas.length
                ? expandidas[peca].toDouble()
                : (expandidas.isNotEmpty ? expandidas.last.toDouble() : 0.0);
          } else {
            soma += entry.value;
          }
        } else {
          soma += entry.value;
        }
      }
      comprimentosPorPeca.add(soma);
    }

    // Desconto de dobra para comprimento de corte
    final desconto = pos.descontoDobraSnapshot ?? 0;
    final bitolaStr = pos.bitolaNome.split('-').first.replaceAll(RegExp(r'[^0-9.]'), '');
    final diametroCm = (double.tryParse(bitolaStr) ?? 0) / 10.0;
    final temCorte = pos.comprimentoDeCorte > 0;

    return pw.Padding(
      padding: const pw.EdgeInsets.all(7),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // IDENTIFICADOR
          _boxPreta(radius: 6, vPad: 5,
            child: pw.Center(child: pw.Text(id, style: _sTarjaId)),
          ),
          pw.SizedBox(height: 3),

          // POS / BITOLA / FORMA / QTDE
          _boxBranca(radius: 5, vPad: 4,
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
              _col('POS', '${pos.posicao}', fontSize: 15),
              pw.Container(width: 0.8, height: 28, color: _corPreto),
              _col('BITOLA', pos.bitolaNome.split('-').first.trim()),
              pw.Container(width: 0.8, height: 28, color: _corPreto),
              _col('FORMA', pos.formaCodigo),
              pw.Container(width: 0.8, height: 28, color: _corPreto),
              _colQtdeMult(pos),
            ]),
          ),
          pw.SizedBox(height: 3),

          // Inscrição COMPRIMENTOS
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: pw.BoxDecoration(
              color: _corPreto,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(5),
                topRight: pw.Radius.circular(5),
              ),
            ),
            child: pw.Center(child: pw.Text('COMPRIMENTOS', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _corBranco, letterSpacing: 1))),
          ),

          // Subtítulo: X peças de cada medida - N medidas
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: pw.BoxDecoration(
              color: _corBranco,
              border: pw.Border(
                left: pw.BorderSide(color: _corPreto, width: 0.8),
                right: pw.BorderSide(color: _corPreto, width: 0.8),
                bottom: pw.BorderSide(color: _corPreto, width: 0.5),
              ),
            ),
            child: pw.Text(
              '${pos.multiplicador} peca${pos.multiplicador > 1 ? 's' : ''} de cada medida - ${pos.qtde ~/ pos.multiplicador} medidas',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _corPreto),
              textAlign: pw.TextAlign.center,
            ),
          ),
          // Campo grande — comprimento + corte
          pw.Expanded(
            child: pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                color: _corBranco,
                borderRadius: const pw.BorderRadius.only(
                  bottomLeft: pw.Radius.circular(5),
                  bottomRight: pw.Radius.circular(5),
                ),
                border: pw.Border.all(color: _corPreto, width: 0.8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Comprimento por peça
                  pw.Center(child: pw.Text('COMPRIMENTO POR PECA', style: _sLabel)),
                  pw.SizedBox(height: 3),
                  pw.Wrap(
                    spacing: 4,
                    runSpacing: 3,
                    children: comprimentosPorPeca.asMap().entries.map((e) {
                      return pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: _corPreto, width: 0.5),
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                        child: pw.Text(
                          '${e.value}',
                          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                        ),
                      );
                    }).toList(),
                  ),

                  // Comprimento de corte por peça
                  if (temCorte) ...[
                    pw.Container(
                      margin: const pw.EdgeInsets.symmetric(vertical: 4),
                      height: 0.5,
                      color: _corPreto,
                    ),
                    pw.Center(child: pw.Text('C. DE CORTE POR PECA', style: _sLabel)),
                    pw.SizedBox(height: 3),
                    pw.Wrap(
                      spacing: 4,
                      runSpacing: 3,
                      children: comprimentosPorPeca.asMap().entries.map((e) {
                        final corte = (e.value - desconto * diametroCm).clamp(0, e.value.toDouble());
                        final corteStr = corte == corte.roundToDouble()
                            ? corte.toInt().toString()
                            : corte.toStringAsFixed(1);
                        return pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: pw.BoxDecoration(
                            color: _corPreto,
                            borderRadius: pw.BorderRadius.circular(3),
                          ),
                          child: pw.Text(
                            corteStr,
                            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _corBranco),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // RODAPÉ
          pw.SizedBox(height: 3),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Pos ${pos.posicao}  |  ${pos.qtde} pecas', style: _sMini),
            pw.Text(id, style: _sMiniBold),
          ]),
        ],
      ),
    );
  }
}
