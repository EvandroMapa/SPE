import 'dart:math' as math;
import 'dart:typed_data';
import 'package:acoplan/app/core/client/models/forma_model.dart';
import 'package:acoplan/app/core/client/models/pedido_tecnico_model.dart';
import 'package:acoplan/app/core/client/models/detalhamento_model.dart';
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
        pdf.addPage(pw.Page(
          pageFormat: _formato,
          margin: pw.EdgeInsets.zero,
          build: (_) => _buildEtiqueta(pedido: pedido, elem: elem, elemDetalhamento: elemDetalhamento, pos: pos, formaDef: formaDef),
        ));
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
    final compUnit = pos.comprimentos.values.fold<int>(0, (s, v) => s + v);
    final compCorte = pos.comprimentoDeCorte > 0 ? pos.comprimentoDeCorte : compUnit;

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
            child: pw.Text(id, style: _sTarjaId),
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
                pw.Text('${elem.elementoQuantidade} pc', style: _sTarjaValor),
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
                _col('PEÇAS', '${pos.qtde} pc'),
                pw.Container(width: 0.8, height: 28, color: _corPreto),
                _col('BITOLA', bitolaStr),
                pw.Container(width: 0.8, height: 28, color: _corPreto),
                _col('FORMA', pos.formaCodigo),
              ]),
              pw.Container(margin: const pw.EdgeInsets.symmetric(vertical: 3), height: 0.8, color: _corPreto),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
                _col('C. UNITÁRIO', '$compUnit cm'),
                pw.Container(width: 0.8, height: 22, color: _corPreto),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                  pw.Text('C. DE CORTE', style: _sLabel),
                  pw.SizedBox(height: 2),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: pw.BoxDecoration(color: _corPreto, borderRadius: pw.BorderRadius.circular(3)),
                    child: pw.Text('$compCorte cm', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _corBranco)),
                  ),
                ]),
              ]),
            ]),
          ),
          pw.SizedBox(height: 3),

          // 5 ── TRECHOS
          if (pos.comprimentos.isNotEmpty) ...[
            _boxBranca(radius: 5, vPad: 3,
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('TRECHOS  (* = variável)', style: _sLabel),
                pw.SizedBox(height: 2),
                pw.Text(trechosStr, style: _sTrechoLinha),
                ..._variaveisExpandidas(pos),
              ]),
            ),
            pw.SizedBox(height: 3),
          ],

          // 6 ── DESENHO — altura fixa para garantir caber no box
          pw.Container(
            height: 175,
            decoration: pw.BoxDecoration(
              color: _corBranco,
              borderRadius: pw.BorderRadius.circular(5),
              border: pw.Border.all(color: _corPreto, width: 0.8),
            ),
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: formaDef == null || formaDef.itens.isEmpty
                  ? pw.Center(child: pw.Text('SEM DESENHO', style: _sMiniBold))
                  : _buildDesenhoForma(formaDef, pos.comprimentos),
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

  static List<pw.Widget> _variaveisExpandidas(PosicaoModel pos) {
    final result = <pw.Widget>[];
    for (final entry in pos.variaveis.entries.where((e) => e.value)) {
      final config = pos.variaveisConfig[entry.key] ?? pos.variaveisConfig.values.firstOrNull;
      if (config == null || config.inicial <= 0) continue;
      final expandidas = config.medidasExpandidas(pos.multiplicador);
      final medidasStr = expandidas.isNotEmpty ? expandidas.join(', ') : config.medidas.join(', ');
      result.add(pw.SizedBox(height: 2));
      result.add(pw.Text(
        '${entry.key}* ${pos.multiplicador > 1 ? '×${pos.multiplicador}  ' : ''}→ $medidasStr cm',
        style: _sMini,
      ));
    }
    return result;
  }

  // ── Desenho da forma — labels desenhados NO canvas para coordenadas corretas
  static pw.Widget _buildDesenhoForma(FormaModel forma, Map<String, int> medidas) {
    if (forma.itens.isEmpty) return pw.SizedBox();

    final itens = forma.itens.map((it) => FormaItemModel(
      trecho: it.trecho,
      comprimento: medidas[it.trecho] ?? it.comprimento,
      angulo: it.angulo,
      orientacao: it.orientacao,
      tipo: it.tipo,
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

    // Tamanho fixo — deve ser menor que o container (175pt) menos padding(5*2) e border(~2)
    const double cW = 213;
    const double cH = 161;

    final pad = math.min(cW, cH) * 0.18;
      final dw = cW - pad * 2, dh = cH - pad * 2;
      final lw = mxX - mnX, lh = mxY - mnY;
      final esc = (lw == 0 && lh == 0) ? 1.0 : math.min(dw / (lw == 0 ? 1 : lw), dh / (lh == 0 ? 1 : lh));
      final ox = (cW - lw * esc) / 2 - mnX * esc;
      final oy = (cH - lh * esc) / 2 - mnY * esc;

      // Canvas PDF: y=0 em baixo, y cresce para cima
      // Mapeamos modelo (y up) → canvas (y up): sem inversão
      PdfPoint toCanvas(PdfPoint p) => PdfPoint(p.x * esc + ox, p.y * esc + oy);
      final display = pts.map(toCanvas).toList();

      // Centróide no espaço canvas
      final centX = display.map((p) => p.x).reduce((a, b) => a + b) / display.length;
      final centY = display.map((p) => p.y).reduce((a, b) => a + b) / display.length;

      // Dados dos labels: calculados em espaço canvas
      final labels = <({double x, double y, String texto})>[];
      for (var i = 0; i < display.length - 1; i++) {
        final p1 = display[i], p2 = display[i + 1];
        final midX = (p1.x + p2.x) / 2;
        final midY = (p1.y + p2.y) / 2;
        final dx = p2.x - p1.x, dy = p2.y - p1.y;
        final len = math.sqrt(dx * dx + dy * dy);
        if (len < 1) continue;
        // Perpendicular no espaço canvas (y up)
        final nx1 = -dy / len, ny1 = dx / len;
        final nx2 = dy / len, ny2 = -dx / len;
        final outX = midX - centX, outY = midY - centY;
        final dot1 = nx1 * outX + ny1 * outY;
        final dirX = dot1 >= 0 ? nx1 : nx2;
        final dirY = dot1 >= 0 ? ny1 : ny2;
        final isCirculo = i < itens.length && itens[i].tipo == 'circulo';
        final dist = isCirculo ? 14.0 : 11.0;
        final lx = (midX + dirX * dist).clamp(2.0, cW - 14.0);
        final ly = (midY + dirY * dist).clamp(4.0, cH - 2.0);
        labels.add((x: lx, y: ly, texto: itens[i].comprimento.toString()));
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
                canvas.setLineWidth(2.0);
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
              },
            ),
          ),
          // Labels via pw.Positioned — em canvas PDF y=0 embaixo; top = cH - canvasY
          for (final lbl in labels)
            pw.Positioned(
              left: lbl.x.clamp(1.0, cW - 14.0),
              top: (cH - lbl.y - 4).clamp(1.0, cH - 10.0),
              child: pw.Text(lbl.texto,
                  style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: _corPreto)),
            ),
        ]),
      );
  }
}
