import 'dart:math' as math;
import 'package:acoplan/app/core/client/models/forma_model.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:flutter/material.dart';

class FormaPainter extends CustomPainter {
  final List<Offset> pts;
  final int? sel;        // índice sendo arrastado (laranja escuro)
  final int? ativo;      // extremidade ativa persistente (verde/destaque)
  final List<String> legendas;
  final bool mostrarLegenda;
  final List<FormaItemModel> itens;
  final bool mostrarVertices;
  FormaPainter({
    required this.pts,
    this.sel,
    this.ativo,
    this.legendas = const [],
    this.mostrarLegenda = true,
    this.itens = const [],
    this.mostrarVertices = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.length < 2) return;
    final linha = Paint()
      ..color = AppColors.primaryMain
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Desenha cada segmento individualmente (linear ou círculo)
    for (var i = 0; i < pts.length - 1; i++) {
      final isCirculo = i < itens.length && itens[i].tipo == 'circulo';
      if (isCirculo) {
        // Arco de 340°: comprimento = raio; os dois pts são os extremos do gap de 20°
        const sweepRad = 340 * math.pi / 180;
        const halfGapRad = 10 * math.pi / 180; // metade do gap (20°/2)
        final chord = (pts[i + 1] - pts[i]).distance;
        if (chord < 1) continue;
        // r = chord / (2 * sin(halfGap))
        final raio = chord / (2 * math.sin(halfGapRad));
        // Vetor da corda e perpendicular (esquerda)
        final cx = pts[i + 1].dx - pts[i].dx;
        final cy = pts[i + 1].dy - pts[i].dy;
        final chordLen = math.sqrt(cx * cx + cy * cy);
        final perpX = -cy / chordLen;
        final perpY =  cx / chordLen;
        // Para sweep > π, centro fica do lado OPOSTO ao arco
        // offset = r * cos(sweep/2) = r * cos(175°) ≈ -r*0.996
        final offset = raio * math.cos(sweepRad / 2); // negativo para 350°
        final midX = (pts[i].dx + pts[i + 1].dx) / 2;
        final midY = (pts[i].dy + pts[i + 1].dy) / 2;
        final centro = Offset(midX + perpX * offset, midY + perpY * offset);
        final anguloInicio = math.atan2(pts[i].dy - centro.dy, pts[i].dx - centro.dx);
        canvas.drawArc(
          Rect.fromCircle(center: centro, radius: raio),
          anguloInicio,
          sweepRad,
          false,
          linha,
        );
      } else {
        canvas.drawLine(pts[i], pts[i + 1], linha);
      }
    }

    // Linhas divisórias perpendiculares no ponto FINAL de cada trecho marcado
    if (itens.isNotEmpty) {
      final divisoriaPaint = Paint()
        ..color = AppColors.primaryMain
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      for (var i = 0; i < pts.length - 1 && i < itens.length; i++) {
        if (!itens[i].linhaDivisoria) continue;
        final p1 = pts[i];
        final p2 = pts[i + 1]; // ponto final do trecho
        final dx = p2.dx - p1.dx;
        final dy = p2.dy - p1.dy;
        final len = math.sqrt(dx * dx + dy * dy);
        if (len < 1) continue;
        // Normal perpendicular (rotação 90°)
        final nx = -dy / len;
        final ny =  dx / len;
        const half = 25.0; // 25px de cada lado = 50px total
        canvas.drawLine(
          Offset(p2.dx + nx * half, p2.dy + ny * half),
          Offset(p2.dx - nx * half, p2.dy - ny * half),
          divisoriaPaint,
        );
      }
    }

    // Vértices
    if (mostrarVertices) {
      for (var i = 0; i < pts.length; i++) {
        final isDragging = i == sel;
        final isExtremidade = i == 0 || i == pts.length - 1;
        final isAtivo = isExtremidade && i == ativo && !isDragging;

        if (isDragging) {
          canvas.drawCircle(pts[i], 11, Paint()..color = Colors.orange.withValues(alpha: 0.3));
          canvas.drawCircle(pts[i], 7, Paint()..color = Colors.orange);
        } else if (isAtivo) {
          canvas.drawCircle(pts[i], 11, Paint()..color = Colors.green.withValues(alpha: 0.25));
          canvas.drawCircle(pts[i], 7, Paint()..color = Colors.green);
          canvas.drawCircle(pts[i], 11,
              Paint()
                ..color = Colors.green
                ..strokeWidth = 2
                ..style = PaintingStyle.stroke);
        }
      }
    }

    // Legendas
    if (mostrarLegenda && legendas.isNotEmpty) {
      for (var i = 0; i < pts.length - 1 && i < legendas.length; i++) {
        // Para círculo: legenda no pico do arco (lado oposto ao gap)
        // Para linear: ponto médio do segmento
        final Offset meio;
        if (i < itens.length && itens[i].tipo == 'circulo') {
          const sweepRad = 340 * math.pi / 180;
          const halfGapRad = 10 * math.pi / 180;
          final chord = (pts[i + 1] - pts[i]).distance;
          if (chord < 1) {
            meio = Offset((pts[i].dx + pts[i + 1].dx) / 2, (pts[i].dy + pts[i + 1].dy) / 2);
          } else {
            final raio = chord / (2 * math.sin(halfGapRad));
            final cx = pts[i + 1].dx - pts[i].dx;
            final cy = pts[i + 1].dy - pts[i].dy;
            final chordLen = math.sqrt(cx * cx + cy * cy);
            final perpX = -cy / chordLen;
            final perpY =  cx / chordLen;
            final offset = raio * math.cos(sweepRad / 2); // negativo → centro no lado oposto
            final midX = (pts[i].dx + pts[i + 1].dx) / 2;
            final midY = (pts[i].dy + pts[i + 1].dy) / 2;
            final centro = Offset(midX + perpX * offset, midY + perpY * offset);
            final anguloInicio = math.atan2(pts[i].dy - centro.dy, pts[i].dx - centro.dx);
            final peakAngle = anguloInicio + sweepRad / 2;
            meio = Offset(centro.dx + raio * math.cos(peakAngle), centro.dy + raio * math.sin(peakAngle));
          }
        } else {
          meio = Offset((pts[i].dx + pts[i + 1].dx) / 2, (pts[i].dy + pts[i + 1].dy) / 2);
        }
        final label = legendas[i];
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final pad = const EdgeInsets.symmetric(horizontal: 5, vertical: 2);
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: meio, width: tp.width + pad.horizontal, height: tp.height + pad.vertical),
          const Radius.circular(6),
        );
        canvas.drawRRect(rect, Paint()..color = AppColors.primaryMain);
        tp.paint(canvas, meio - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant FormaPainter old) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Estado público para acesso via GlobalKey<FormaPreviewState>
// ─────────────────────────────────────────────────────────────────────────────

class FormaPreviewWidget extends StatefulWidget {
  final List<FormaItemModel> itens;
  final double height;
  final VoidCallback? onChanged;
  final double rotacaoExterna;
  final bool mostrarLegenda;
  final List<String>? legendasCustom;
  final bool mostrarVertices;
  const FormaPreviewWidget({
    super.key,
    required this.itens,
    this.height = 400,
    this.onChanged,
    this.rotacaoExterna = 0,
    this.mostrarLegenda = true,
    this.legendasCustom,
    this.mostrarVertices = true,
  });

  @override
  State<FormaPreviewWidget> createState() => FormaPreviewState();
}

class FormaPreviewState extends State<FormaPreviewWidget> {
  // Transform síncrono — atribuído diretamente no build()
  double _esc = 1, _ox = 0, _oy = 0;

  // Drag state
  int? _idx;
  List<Offset>? _drag;

  // ── Ponto ativo (extremidade selecionada) ────────────────────────────────
  // Só pode ser 0 (primeiro) ou pts.length-1 (último).
  // null = sem seleção ainda.
  int? _pontoAtivo;

  // ── Controle de auto-ajuste ──────────────────────────────────────────────
  bool _bloqueiaAutoAjuste = false;

  // Rotação base do primeiro segmento em graus (0 = horizontal →)
  double _rotacaoBase = 0;

  // Snapshot dos itens para detectar digitação vs mouse
  String _snapshotItens = '';
  bool _acabouDeArrastar = false;
  Size _ultimoTamanho = Size.zero;

  // ── API pública (usada pelo botão + via GlobalKey) ────────────────────────
  /// Chame antes de adicionar um trecho via controller.
  /// Se a extremidade ativa for o INÍCIO, inverte a cadeia primeiro.
  void prepararAdicionarTrecho() {
    final temCirculo = widget.itens.any((it) => it.tipo == 'circulo');
    if (_pontoAtivo == 0 && widget.itens.isNotEmpty && !temCirculo) {
      _reverterCadeia();
    }
    if (_pontoAtivo == 0 && temCirculo) _pontoAtivo = widget.itens.length;

    if (temCirculo) {
      // Libera auto-ajuste para o canvas incluir o novo segmento na visão
      _drag = null;
      _bloqueiaAutoAjuste = false;
    } else {
      _bloqueiaAutoAjuste = true;
    }
    _acabouDeArrastar = true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  String _gerarSnapshot() {
    return widget.itens.map((e) => '${e.trecho}|${e.comprimento}|${e.angulo}|${e.orientacao}').join(';');
  }

  @override
  void initState() {
    super.initState();
    _snapshotItens = _gerarSnapshot();
    _rotacaoBase = widget.rotacaoExterna;
    if (widget.itens.isNotEmpty) {
      _pontoAtivo = widget.itens.length;
    }
  }

  @override
  void didUpdateWidget(covariant FormaPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final novoSnapshot = _gerarSnapshot();

    if (widget.rotacaoExterna != oldWidget.rotacaoExterna) {
      _rotacaoBase = widget.rotacaoExterna;
      _drag = null;
      _bloqueiaAutoAjuste = false;
      _acabouDeArrastar = true; // Marca como arrastado para não resetar no próximo frame
      _snapshotItens = novoSnapshot;
      return;
    }

    if (_drag != null && widget.itens.length + 1 != _drag!.length) {
      _drag = null;
      _bloqueiaAutoAjuste = false;
      _rotacaoBase = 0;
      _acabouDeArrastar = false;
      _snapshotItens = novoSnapshot;
      // Ao mudar qtd de itens (ex: botão +), ativo = último
      if (widget.itens.isNotEmpty) {
        _pontoAtivo = widget.itens.length; // = pts.length - 1 após rebuild
      }
      return;
    }

    if (novoSnapshot != _snapshotItens) {
      if (_idx == null && !_acabouDeArrastar) {
        _bloqueiaAutoAjuste = false;
        _rotacaoBase = widget.rotacaoExterna;
        _drag = null;
      }
      _acabouDeArrastar = false;
      _snapshotItens = novoSnapshot;
    }
  }

  // ── Modelo → pontos (model coords) ───────────────────────────────────────
  List<Offset> _modelPts(List<FormaItemModel> itens) {
    final pts = <Offset>[Offset.zero];
    double a = _rotacaoBase;
    for (final it in itens) {
      final r = a * math.pi / 180;
      final last = pts.last;
      if (it.tipo == 'circulo') {
        // comprimento = raio; corda do gap de 20° = 2r*sin(10°)
        final chord = 2 * it.comprimento * math.sin(10 * math.pi / 180);
        pts.add(Offset(last.dx + chord * math.cos(r), last.dy + chord * math.sin(r)));
      } else {
        pts.add(Offset(last.dx + it.comprimento * math.cos(r), last.dy + it.comprimento * math.sin(r)));
      }
      a += it.orientacao == 'Horário' ? it.angulo : -it.angulo;
    }
    return pts;
  }

  // ── Pontos extras para bounding-box (inclui extensão completa dos arcos) ──
  List<Offset> _ptsParaBBox(List<Offset> mPts) {
    final result = List<Offset>.from(mPts);
    for (var i = 0; i < widget.itens.length && i < mPts.length - 1; i++) {
      if (widget.itens[i].tipo == 'circulo') {
        // comprimento = raio; calcula o centro do arco de 350°
        final raio = widget.itens[i].comprimento.toDouble();
        final cx = mPts[i + 1].dx - mPts[i].dx;
        final cy = mPts[i + 1].dy - mPts[i].dy;
        final chordLen = math.sqrt(cx * cx + cy * cy);
        if (chordLen < 1) continue;
        final perpX = -cy / chordLen;
        final perpY =  cx / chordLen;
        const sweepRad = 340 * math.pi / 180;
        final offset = raio * math.cos(sweepRad / 2); // negativo para 340°
        final midX = (mPts[i].dx + mPts[i + 1].dx) / 2;
        final midY = (mPts[i].dy + mPts[i + 1].dy) / 2;
        final centroX = midX + perpX * offset;
        final centroY = midY + perpY * offset;
        // Adiciona os 4 extremos cardinais do círculo
        result.add(Offset(centroX + raio, centroY));
        result.add(Offset(centroX - raio, centroY));
        result.add(Offset(centroX, centroY + raio));
        result.add(Offset(centroX, centroY - raio));
      }
    }
    return result;
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

  List<Offset> _toTela(List<Offset> pts) =>
      pts.map((p) => Offset(p.dx * _esc + _ox, p.dy * _esc + _oy)).toList();

  // ── Inverter a cadeia ─────────────────────────────────────────────────────
  /// Inverte a ordem dos pontos, recalculando ângulos e comprimentos.
  /// Faz o ponto 0 virar o último e vice-versa.
  void _reverterCadeia() {
    if (widget.itens.isEmpty) return;

    final mPts = _modelPts(widget.itens);
    final rev = mPts.reversed.toList();

    // Nova rotação base = direção do 1º segmento invertido
    if (rev.length >= 2) {
      final v0 = rev[1] - rev[0];
      _rotacaoBase = math.atan2(v0.dy, v0.dx) * 180 / math.pi;
    }

    final n = widget.itens.length;
    // Gera novos itens na ordem invertida
    final novos = List.generate(n, (i) {
      final itemOriginal = widget.itens[n - 1 - i];
      final v = rev[i + 1] - rev[i];
      double angulo = 0;
      String orientacao = 'Horário';
      if (i < n - 1) {
        final vNext = rev[i + 2] - rev[i + 1];
        final d1 = math.atan2(v.dy, v.dx) * 180 / math.pi;
        final d2 = math.atan2(vNext.dy, vNext.dx) * 180 / math.pi;
        var delta = d2 - d1;
        while (delta > 180) { delta -= 360; }
        while (delta < -180) { delta += 360; }
        angulo = delta.abs().roundToDouble();
        orientacao = delta >= 0 ? 'Horário' : 'Anti-horário';
      }
      // Para círculo: preserva o raio original (não calcula da corda)
      final comp = itemOriginal.tipo == 'circulo'
          ? itemOriginal.comprimento
          : v.distance.round().clamp(1, 99999);
      return FormaItemModel(
        trecho: 'T${i + 1}',
        comprimento: comp,
        angulo: angulo,
        orientacao: orientacao,
        tipo: itemOriginal.tipo,
      );
    });

    widget.itens.clear();
    widget.itens.addAll(novos);

    // Atualiza a origem (_ox, _oy) para a posição de tela do antigo ponto final
    // para que o desenho não pule.
    final antigoFinalModel = mPts.last;
    final antigoFinalTelaX = antigoFinalModel.dx * _esc + _ox;
    final antigoFinalTelaY = antigoFinalModel.dy * _esc + _oy;
    _ox = antigoFinalTelaX;
    _oy = antigoFinalTelaY;

    _drag = null;
    _bloqueiaAutoAjuste = true;
    _acabouDeArrastar = true;
    _snapshotItens = _gerarSnapshot();
    // Após inversão, o "antigo primeiro" agora é o último → ativo
    _pontoAtivo = widget.itens.length; // pts.length - 1 após rebuild
    widget.onChanged?.call();
    setState(() {});
  }

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

  /// Tap: se tocou numa extremidade → seleciona / inverte; senão → adiciona ponto
  void _tapped(Offset local) {
    if (widget.onChanged == null) return;
    final telaPts = _drag ?? _toTela(_modelPts(widget.itens));
    if (telaPts.isEmpty) { _addPontoEmVazio(local); return; }

    final lastIdx = telaPts.length - 1;
    const hitRadius = 28.0;

    // Calcula distância para cada extremidade
    final dist0    = (local - telaPts[0]).distance;
    final distLast = (local - telaPts[lastIdx]).distance;

    final hit0    = dist0    < hitRadius;
    final hitLast = distLast < hitRadius;

    if (hit0 || hitLast) {
      final tocouPrimeiro = hit0 && (!hitLast || dist0 <= distLast);

      if (tocouPrimeiro) {
        if (_pontoAtivo != 0) {
          // Círculo: NÃO reverter (reversão espelha o arco).
          // Apenas troca o ponto ativo.
          final temCirculo = widget.itens.any((it) => it.tipo == 'circulo');
          if (temCirculo) {
            setState(() { _pontoAtivo = 0; });
          } else {
            _reverterCadeia();
            setState(() {});
          }
        }
      } else {
        setState(() { _pontoAtivo = lastIdx; });
      }
      return;
    }

    // Tocou em área vazia → adiciona ponto
    final temCirculo = widget.itens.any((it) => it.tipo == 'circulo');
    if (_pontoAtivo == 0 && widget.itens.isNotEmpty) {
      if (temCirculo) {
        _prependPonto(local); // insere antes do círculo sem rotacionar o arco
        return;
      }
      _reverterCadeia();
    }
    _addPontoEmVazio(local);
  }

  // ── Insere segmento no INÍCIO da cadeia (usado quando pontoAtivo==0 com círculo) ──
  // O círculo permanece na mesma posição visual — sem rotação do arco.
  void _prependPonto(Offset local) {
    if (widget.onChanged == null) return;
    // Posição do antigo pts[0] na tela = origem do modelo (_ox, _oy)
    final origemTela = Offset(_ox, _oy);
    final dxTela = origemTela.dx - local.dx;
    final dyTela = origemTela.dy - local.dy;
    final distTela = math.sqrt(dxTela * dxTela + dyTela * dyTela);
    if (distTela < 10) return;
    final comprimento = (distTela / _esc).round().clamp(10, 99999);
    // Direção de local → antiga origem
    final novaDir = math.atan2(dyTela, dxTela) * 180 / math.pi;
    // Ângulo de giro entre novo T1 e o próximo item (círculo)
    var delta = _rotacaoBase - novaDir;
    while (delta > 180) { delta -= 360; }
    while (delta < -180) { delta += 360; }
    final novoItem = FormaItemModel(
      trecho: 'T1',
      comprimento: comprimento,
      angulo: delta.abs().roundToDouble(),
      orientacao: delta >= 0 ? 'Horário' : 'Anti-horário',
    );
    widget.itens.insert(0, novoItem);
    for (var i = 0; i < widget.itens.length; i++) {
      widget.itens[i].trecho = 'T${i + 1}';
    }
    // Reposiciona a origem do modelo para o novo ponto
    _ox = local.dx;
    _oy = local.dy;
    _rotacaoBase = novaDir;
    _drag = _toTela(_modelPts(widget.itens));
    _bloqueiaAutoAjuste = true;
    _acabouDeArrastar = true;
    _snapshotItens = _gerarSnapshot();
    _pontoAtivo = 0; // novo primeiro ponto ativo
    widget.onChanged?.call();
    setState(() {});
  }

  void _addPontoEmVazio(Offset local) {
    final telaPts = _drag ?? _toTela(_modelPts(widget.itens));
    // Ignora se clicou perto de qualquer ponto
    for (final p in telaPts) {
      if ((local - p).distance < 25) return;
    }

    final mPts = _modelPts(widget.itens);
    final ultimoM = mPts.isNotEmpty ? mPts.last : Offset.zero;
    final novoM = Offset((local.dx - _ox) / _esc, (local.dy - _oy) / _esc);
    final vetor = novoM - ultimoM;

    double dirAnterior = 0;
    if (mPts.length >= 2) {
      final v = mPts.last - mPts[mPts.length - 2];
      dirAnterior = math.atan2(v.dy, v.dx) * 180 / math.pi;
    }

    final dirNovo = math.atan2(vetor.dy, vetor.dx) * 180 / math.pi;
    var delta = dirNovo - dirAnterior;
    while (delta > 180) { delta -= 360; }
    while (delta < -180) { delta += 360; }

    final comp = vetor.distance.round().clamp(10, 99999);
    _addViaController(delta.abs().roundToDouble(), delta >= 0 ? 'Horário' : 'Anti-horário', comp, local);
  }

  void _addViaController(double angulo, String orientacao, [int comprimento = 150, Offset? posicaoTela]) {
    if (widget.itens.isNotEmpty) {
      widget.itens.last.angulo = angulo;
      widget.itens.last.orientacao = orientacao;
    }
    final proximoN = widget.itens.length + 1;
    widget.itens.add(FormaItemModel(
      trecho: 'T$proximoN',
      comprimento: comprimento,
      angulo: 0,
      orientacao: 'Horário',
    ));
    _bloqueiaAutoAjuste = true;
    _acabouDeArrastar = true;
    if (posicaoTela != null && _drag != null) {
      _drag!.add(posicaoTela);
    } else {
      _drag = _toTela(_modelPts(widget.itens));
    }
    _snapshotItens = _gerarSnapshot();
    // Novo trecho adicionado → ativo = último ponto
    _pontoAtivo = widget.itens.length; // pts.length - 1 após rebuild
    widget.onChanged?.call();
    setState(() {});
  }

  void _update(Offset local) {
    if (_idx == null || _drag == null) return;
    _drag![_idx!] = local;
    _commitDrag(_drag!);
    _acabouDeArrastar = true;
    _snapshotItens = _gerarSnapshot();
    widget.onChanged?.call();
    setState(() {});
  }

  void _end() {
    if (_drag != null) {
      _commitDrag(_drag!);
      _bloqueiaAutoAjuste = true;
      _acabouDeArrastar = true;
      _snapshotItens = _gerarSnapshot();
      widget.onChanged?.call();
    }
    // Após drag de extremidade, atualiza ativo se foi uma extremidade
    final lastIdx = widget.itens.isNotEmpty ? widget.itens.length : 0;
    if (_idx == 0) _pontoAtivo = 0;
    if (_idx == lastIdx) _pontoAtivo = lastIdx;
    setState(() { _idx = null; });
  }

  // ── Converte pontos de tela → modelo ─────────────────────────────────────
  void _commitDrag(List<Offset> telaPts) {
    final mPts = telaPts.map((p) => Offset((p.dx - _ox) / _esc, (p.dy - _oy) / _esc)).toList();
    if (mPts.length >= 2) {
      final v0 = mPts[1] - mPts[0];
      _rotacaoBase = math.atan2(v0.dy, v0.dx) * 180 / math.pi;
    }
    for (var i = 0; i < widget.itens.length; i++) {
      final v = mPts[i + 1] - mPts[i];
      // Círculo: comprimento = raio (não deve ser sobrescrito pela corda)
      if (widget.itens[i].tipo != 'circulo') {
        widget.itens[i].comprimento = v.distance.round().clamp(1, 99999);
      }
      if (i < widget.itens.length - 1) {
        final vNext = mPts[i + 2] - mPts[i + 1];
        final d1 = math.atan2(v.dy, v.dx) * 180 / math.pi;
        final d2 = math.atan2(vNext.dy, vNext.dx) * 180 / math.pi;
        var delta = d2 - d1;
        while (delta > 180) { delta -= 360; }
        while (delta < -180) { delta += 360; }
        widget.itens[i].angulo = delta.abs().roundToDouble();
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
              final mPts = _modelPts(widget.itens);

              final tamanhoMudou = _ultimoTamanho != Size.zero && _ultimoTamanho != size;
              _ultimoTamanho = size;

              final ({double esc, double ox, double oy}) t;
              if (_drag != null && !tamanhoMudou) {
                t = (esc: _esc, ox: _ox, oy: _oy);
              } else if (tamanhoMudou) {
                _drag = null;
                _bloqueiaAutoAjuste = false;
                t = _transform(_ptsParaBBox(mPts), size);
              } else if (_bloqueiaAutoAjuste) {
                t = (esc: _esc, ox: _ox, oy: _oy);
              } else {
                t = _transform(_ptsParaBBox(mPts), size);
              }

              _esc = t.esc; _ox = t.ox; _oy = t.oy;

              final display = _drag ?? _toTela(mPts);
              final legendas = widget.legendasCustom ?? widget.itens.map((e) => e.trecho).toList();

              // Normaliza _pontoAtivo para o range atual de pontos
              final maxIdx = display.isNotEmpty ? display.length - 1 : 0;
              final ativoNormalizado = _pontoAtivo != null
                  ? _pontoAtivo!.clamp(0, maxIdx)
                  : null;

              return GestureDetector(
                onTapUp: (d) => _tapped(d.localPosition),
                onPanStart: (d) => _start(d.localPosition),
                onPanUpdate: (d) => _update(d.localPosition),
                onPanEnd: (_) => _end(),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: FormaPainter(
                    pts: display,
                    sel: _idx,
                    ativo: ativoNormalizado,
                    legendas: legendas,
                    mostrarLegenda: widget.mostrarLegenda,
                    itens: widget.itens,
                    mostrarVertices: widget.mostrarVertices,
                  ),
                ),
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
