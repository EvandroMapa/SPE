import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:acoplan/app/modules/detalhamento_ia/preparacao/dxf_geometria.dart';
import 'package:acoplan/app/modules/detalhamento_ia/preparacao/models/elemento_preparado.dart';

/// Painter que renderiza o conteúdo DXF no canvas.
///
/// Renderiza geometria (linhas, arcos, círculos), textos
/// posicionados e sobreposições interativas (seleção, bounding boxes).
class DxfCanvasPainter extends CustomPainter {
  final DxfGeometria geometria;
  final List<ElementoPreparado> elementos;
  final Rect? selecaoAtual;
  final String? elementoSelecionado;
  final Set<int> textosDestacados; // índices de textos dentro da seleção
  final Matrix4 transform;

  // Regex para classificar textos
  static final _reElemento = RegExp(r'^[VPLEBSC]\d+$', caseSensitive: false);
  static final _rePosicao = RegExp(r'(\d+)\s*N(\d+)\s*[øφ∅]');
  static final _reSecao = RegExp(r'SE[CÇ][AÃ]O\s+[A-Z]\s*-\s*[A-Z]', caseSensitive: false);

  DxfCanvasPainter({
    required this.geometria,
    this.elementos = const [],
    this.selecaoAtual,
    this.elementoSelecionado,
    this.textosDestacados = const {},
    required this.transform,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.transform(transform.storage);
    _desenharGeometria(canvas);
    _desenharBoundingBoxes(canvas);
    _desenharTextos(canvas);
    _desenharSelecao(canvas);
    canvas.restore();
  }

  /// Layers a ocultar (carimbo, moldura, defpoints).
  static final _layersOcultos = {
    'FORMATO', 'G-ANNO-TTLB', 'G-ANNO-TTLB-MEDM', 'Defpoints', '0', '04',
  };
  static bool _isLayerOculto(String layer) {
    if (_layersOcultos.contains(layer)) return true;
    if (layer.startsWith('PENA-')) return true;
    return false;
  }

  /// Desenha linhas, arcos e círculos do DXF.
  void _desenharGeometria(Canvas canvas) {
    final paintLinha = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final paintArco = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Linhas
    for (final l in geometria.linhas) {
      if (_isLayerOculto(l.layer)) continue;
      canvas.drawLine(
        Offset(l.x1, -l.y1),
        Offset(l.x2, -l.y2),
        paintLinha,
      );
    }

    // Arcos
    for (final a in geometria.arcos) {
      if (_isLayerOculto(a.layer)) continue;
      final rect = Rect.fromCircle(
        center: Offset(a.cx, -a.cy),
        radius: a.raio,
      );
      final inicioRad = -a.anguloFim * pi / 180; // inverter por causa do Y
      final fimRad = -a.anguloInicio * pi / 180;
      canvas.drawArc(rect, inicioRad, fimRad - inicioRad, false, paintArco);
    }

    // Círculos
    for (final c in geometria.circulos) {
      if (_isLayerOculto(c.layer)) continue;
      canvas.drawCircle(
        Offset(c.cx, -c.cy),
        c.raio,
        paintArco,
      );
    }
  }

  /// Desenha bounding boxes dos elementos já definidos.
  void _desenharBoundingBoxes(Canvas canvas) {
    for (final elem in elementos) {
      final isSelecionado = elem.nome == elementoSelecionado;
      final rect = Rect.fromLTRB(
        elem.boundingBox.left,
        -elem.boundingBox.bottom, // Y invertido
        elem.boundingBox.right,
        -elem.boundingBox.top,
      );

      // Preenchimento semi-transparente
      final paintFill = Paint()
        ..color = elem.cor.withValues(alpha: isSelecionado ? 0.15 : 0.06)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, paintFill);

      // Contorno
      final paintBorda = Paint()
        ..color = elem.cor.withValues(alpha: isSelecionado ? 0.8 : 0.4)
        ..strokeWidth = isSelecionado ? 1.5 : 0.8
        ..style = PaintingStyle.stroke;
      canvas.drawRect(rect, paintBorda);

      // Label do elemento
      final tp = TextPainter(
        text: TextSpan(
          text: '${elem.nome} (${elem.posicoes.length})',
          style: TextStyle(
            color: elem.cor,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(rect.left + 2, rect.top + 1));
    }
  }

  // Textos nativos de coordenadas/eixos a ignorar
  static final _textosDescarte = {'X', 'Y', 'Z', 'x', 'y', 'z'};

  /// Desenha textos do DXF com cores por tipo.
  void _desenharTextos(Canvas canvas) {
    for (int i = 0; i < geometria.textos.length; i++) {
      final t = geometria.textos[i];
      final conteudo = t.conteudo.trim();

      // Ignorar marcadores de eixo nativos do DXF
      if (_textosDescarte.contains(conteudo)) continue;

      // Ignorar textos de layers ocultos (carimbo/moldura)
      if (_isLayerOculto(t.layer)) continue;

      final isDestacado = textosDestacados.contains(i);

      // Determinar cor e estilo por tipo de conteúdo
      Color cor;
      double fontSize;
      FontWeight peso;

      if (_reElemento.hasMatch(conteudo)) {
        // Rótulo de elemento (V101, P1)
        cor = const Color(0xFFDC2626); // vermelho forte
        fontSize = (t.altura * 1.0).clamp(8, 40);
        peso = FontWeight.bold;
      } else if (_rePosicao.hasMatch(conteudo)) {
        // Descrição de posição (2 N35 ø12.5 C=415)
        cor = const Color(0xFF2563EB); // azul forte
        fontSize = (t.altura * 0.9).clamp(6, 30);
        peso = FontWeight.w600;
      } else if (_reSecao.hasMatch(conteudo)) {
        // SEÇÃO A-A
        cor = const Color(0xFF059669); // verde forte
        fontSize = (t.altura * 0.9).clamp(7, 32);
        peso = FontWeight.w600;
      } else {
        // Outros textos
        cor = const Color(0xFF1F2937); // quase preto
        fontSize = (t.altura * 0.8).clamp(5, 24);
        peso = FontWeight.normal;
      }

      // Destaque se dentro da seleção
      if (isDestacado) {
        cor = const Color(0xFFF59E0B); // amarelo
        peso = FontWeight.bold;

        // Fundo highlight
        final tp2 = TextPainter(
          text: TextSpan(
            text: conteudo,
            style: TextStyle(fontSize: fontSize),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();

        final bgRect = Rect.fromLTWH(
          t.x - 1,
          -t.y - fontSize - 1,
          tp2.width + 2,
          fontSize + 2,
        );
        canvas.drawRect(
          bgRect,
          Paint()..color = const Color(0xFFFEF3C7).withValues(alpha: 0.8),
        );
      }

      // Verificar se pertence a algum elemento
      for (final elem in elementos) {
        if (elem.boundingBox.contains(Offset(t.x, t.y))) {
          cor = elem.cor;
          break;
        }
      }

      final tp = TextPainter(
        text: TextSpan(
          text: conteudo,
          style: TextStyle(
            color: cor,
            fontSize: fontSize,
            fontWeight: peso,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(t.x, -t.y - fontSize));
    }
  }

  /// Desenha o retângulo de seleção atual.
  void _desenharSelecao(Canvas canvas) {
    if (selecaoAtual == null) return;

    final rect = Rect.fromLTRB(
      selecaoAtual!.left,
      selecaoAtual!.top,
      selecaoAtual!.right,
      selecaoAtual!.bottom,
    );

    // Preenchimento
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF3B82F6).withValues(alpha: 0.08)
        ..style = PaintingStyle.fill,
    );

    // Borda pontilhada
    final paintBorda = Paint()
      ..color = const Color(0xFF3B82F6).withValues(alpha: 0.6)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Desenha como borda sólida (pontilhado é complexo sem Path dash)
    canvas.drawRect(rect, paintBorda);
  }

  @override
  bool shouldRepaint(covariant DxfCanvasPainter oldDelegate) {
    return oldDelegate.transform != transform ||
        oldDelegate.selecaoAtual != selecaoAtual ||
        oldDelegate.elementoSelecionado != elementoSelecionado ||
        oldDelegate.textosDestacados != textosDestacados ||
        oldDelegate.elementos != elementos;
  }
}
