import 'dart:math' as math;
import 'package:acoplan/app/core/client/models/forma_model.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:flutter/material.dart';

class FormaPainter extends CustomPainter {
  final List<Offset> pts;
  final int? sel;
  FormaPainter({required this.pts, this.sel});

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.length < 2) return;
    final linha = Paint()
      ..color = AppColors.primaryMain
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 1; i < pts.length; i++) path.lineTo(pts[i].dx, pts[i].dy);
    canvas.drawPath(path, linha);
    for (var i = 0; i < pts.length; i++) {
      final r = i == sel ? 11.0 : 7.0;
      canvas.drawCircle(pts[i], r,
          Paint()..color = (i == sel ? Colors.orange : AppColors.primaryMain).withValues(alpha: i == sel ? 0.3 : 1));
      if (i == sel) canvas.drawCircle(pts[i], 7, Paint()..color = Colors.orange);
    }
  }

  @override
  bool shouldRepaint(covariant FormaPainter old) => true;
}

class FormaPreviewWidget extends StatefulWidget {
  final List<FormaItemModel> itens;
  final double height;
  final VoidCallback? onChanged;
  const FormaPreviewWidget({super.key, required this.itens, this.height = 400, this.onChanged});

  @override
  State<FormaPreviewWidget> createState() => _State();
}

class _State extends State<FormaPreviewWidget> {
  // Transform síncrono — atribuído diretamente no build()
  double _esc = 1, _ox = 0, _oy = 0;

  // Drag state
  int? _idx;
  List<Offset>? _drag; // pontos em coords de TELA durante o arrasto

  // ── Modelo → pontos (model coords) ───────────────────────────────────────
  List<Offset> _modelPts(List<FormaItemModel> itens) {
    final pts = <Offset>[Offset.zero];
    double a = 0;
    for (final it in itens) {
      final r = a * math.pi / 180;
      final last = pts.last;
      pts.add(Offset(last.dx + it.comprimento * math.cos(r), last.dy + it.comprimento * math.sin(r)));
      a += it.orientacao == 'Horário' ? it.angulo : -it.angulo;
    }
    return pts;
  }

  // ── Transform que cabe no canvas ─────────────────────────────────────────
  ({double esc, double ox, double oy}) _transform(List<Offset> pts, Size s) {
    if (pts.length < 2 || s.width == 0) return (esc: 1, ox: s.width / 2, oy: s.height / 2);
    double mnX = pts[0].dx, mxX = pts[0].dx, mnY = pts[0].dy, mxY = pts[0].dy;
    for (final p in pts) {
      if (p.dx < mnX) mnX = p.dx; if (p.dx > mxX) mxX = p.dx;
      if (p.dy < mnY) mnY = p.dy; if (p.dy > mxY) mxY = p.dy;
    }
    final pad = math.min(s.width, s.height) * 0.1;
    final dw = s.width - pad * 2, dh = s.height - pad * 2;
    final lw = mxX - mnX, lh = mxY - mnY;
    final esc = (lw == 0 && lh == 0) ? 1.0 : math.min(dw / (lw == 0 ? 1 : lw), dh / (lh == 0 ? 1 : lh));
    return (esc: esc, ox: (s.width - lw * esc) / 2 - mnX * esc, oy: (s.height - lh * esc) / 2 - mnY * esc);
  }

  // ── Model coords → tela ───────────────────────────────────────────────────
  List<Offset> _toTela(List<Offset> pts) =>
      pts.map((p) => Offset(p.dx * _esc + _ox, p.dy * _esc + _oy)).toList();

  // ── Gestos ───────────────────────────────────────────────────────────────
  void _start(Offset local) {
    if (widget.itens.isEmpty) return;
    final telaPts = _drag ?? _toTela(_modelPts(widget.itens));
    int? found; double menor = 25;
    for (var i = 0; i < telaPts.length; i++) {
      final d = (local - telaPts[i]).distance;
      if (d < menor) { menor = d; found = i; }
    }
    if (found != null) {
      setState(() { _idx = found; _drag = List<Offset>.from(telaPts); });
    }
  }

  /// Clique em área vazia → novo trecho a partir do último ponto
  void _addPonto(Offset local) {
    if (widget.onChanged == null) return;

    // Ignora se clicou perto de ponto existente
    final telaPts = _toTela(_modelPts(widget.itens));
    for (final p in telaPts) {
      if ((local - p).distance < 25) return;
    }

    // Direção absoluta do novo segmento (tela → modelo para calcular ângulo)
    final mPts = _modelPts(widget.itens);
    final ultimoM = mPts.isNotEmpty ? mPts.last : Offset.zero;
    final novoM = Offset((local.dx - _ox) / _esc, (local.dy - _oy) / _esc);
    final vetor = novoM - ultimoM;

    // Direção do último segmento existente
    double dirAnterior = 0;
    if (mPts.length >= 2) {
      final v = mPts.last - mPts[mPts.length - 2];
      dirAnterior = math.atan2(v.dy, v.dx) * 180 / math.pi;
    }

    final dirNovo = math.atan2(vetor.dy, vetor.dx) * 180 / math.pi;
    var delta = dirNovo - dirAnterior;
    while (delta > 180) { delta -= 360; }
    while (delta < -180) { delta += 360; }

    widget.onChanged!(); // Sinaliza para o controller adicionar via adicionarItemDoCanvas
    // Nota: chamamos via callback diferenciado abaixo
    _addViaController(delta.abs(), delta >= 0 ? 'Horário' : 'Anti-horário');
  }

  void _addViaController(double angulo, String orientacao) {
    if (widget.itens.isNotEmpty) {
      widget.itens.last.angulo = angulo;
      widget.itens.last.orientacao = orientacao;
    }
    final proximoN = widget.itens.length + 1;
    widget.itens.add(FormaItemModel(
      trecho: 'T$proximoN',
      comprimento: proximoN * 10,
      angulo: 0,
      orientacao: 'Horário',
    ));
    widget.onChanged?.call();
    setState(() {});
  }


  void _update(Offset local) {
    if (_idx == null || _drag == null) return;
    setState(() { _drag![_idx!] = local; });
  }

  void _end() {
    if (_drag != null) {
      _commitDrag(_drag!);
      widget.onChanged?.call();
    }
    setState(() { _idx = null; _drag = null; });
  }

  // ── Converte pontos de tela de volta ao modelo ────────────────────────────
  void _commitDrag(List<Offset> telaPts) {
    // Converte para model coords
    final mPts = telaPts.map((p) => Offset((p.dx - _ox) / _esc, (p.dy - _oy) / _esc)).toList();

    for (var i = 0; i < widget.itens.length; i++) {
      final v = mPts[i + 1] - mPts[i];
      widget.itens[i].comprimento = v.distance.round().clamp(1, 99999);

      if (i < widget.itens.length - 1) {
        final vNext = mPts[i + 2] - mPts[i + 1];
        final d1 = math.atan2(v.dy, v.dx) * 180 / math.pi;
        final d2 = math.atan2(vNext.dy, vNext.dx) * 180 / math.pi;
        var delta = d2 - d1;
        while (delta > 180) { delta -= 360; }
        while (delta < -180) { delta += 360; }
        widget.itens[i].angulo = delta.abs();
        widget.itens[i].orientacao = delta >= 0 ? 'Horário' : 'Anti-horário';
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Stack(
        children: [
          Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(12), child: CustomPaint(painter: _GridPainter()))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(builder: (_, c) {
              final size = Size(c.maxWidth, c.maxHeight);
              // Transform baseado nos pontos do MODELO (auto-ajuste fora do drag)
              // Durante o drag, o transform fica congelado (calculado pelo _drag)
              final mPts = _modelPts(widget.itens);
              final t = _drag == null
                  ? _transform(mPts, size)
                  : (esc: _esc, ox: _ox, oy: _oy); // congelado

              // Grava síncrono no build — sem setState
              _esc = t.esc; _ox = t.ox; _oy = t.oy;

              // Pontos a exibir: durante drag usa _drag (tela), senão converte modelo
              final display = _drag ?? _toTela(mPts);

              return GestureDetector(
                onTapUp: (d) => _addPonto(d.localPosition),
                onPanStart: (d) => _start(d.localPosition),
                onPanUpdate: (d) => _update(d.localPosition),
                onPanEnd: (_) => _end(),
                child: CustomPaint(size: Size.infinite, painter: FormaPainter(pts: display, sel: _idx)),
              );
            }),
          ),
          if (widget.itens.isEmpty)
            Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.architecture_rounded, color: Colors.grey[300], size: 64),
              const SizedBox(height: 16),
              Text('Inicie o desenho adicionando um trecho', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
            ])),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.grey[100]!..strokeWidth = 1;
    for (double i = 0; i < size.width; i += 20) canvas.drawLine(Offset(i, 0), Offset(i, size.height), p);
    for (double i = 0; i < size.height; i += 20) canvas.drawLine(Offset(0, i), Offset(size.width, i), p);
  }
  @override bool shouldRepaint(_) => false;
}
