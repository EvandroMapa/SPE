import 'dart:ui' show Rect;

/// Linha extraída do DXF.
class DxfLinha {
  final double x1, y1, x2, y2;
  final String layer;
  DxfLinha({required this.x1, required this.y1, required this.x2, required this.y2, required this.layer});
}

/// Arco extraído do DXF.
class DxfArco {
  final double cx, cy, raio, anguloInicio, anguloFim;
  final String layer;
  DxfArco({required this.cx, required this.cy, required this.raio, required this.anguloInicio, required this.anguloFim, required this.layer});
}

/// Círculo extraído do DXF.
class DxfCirculo {
  final double cx, cy, raio;
  final String layer;
  DxfCirculo({required this.cx, required this.cy, required this.raio, required this.layer});
}

/// Texto extraído do DXF.
class DxfTexto {
  final String tipo; // TEXT ou MTEXT
  final String layer;
  final double x;
  final double y;
  final double altura;
  final String conteudo;
  DxfTexto({
    required this.tipo,
    required this.layer,
    required this.x,
    required this.y,
    this.altura = 10,
    required this.conteudo,
  });
}

/// Geometria completa extraída de um arquivo DXF.
class DxfGeometria {
  final List<DxfLinha> linhas;
  final List<DxfArco> arcos;
  final List<DxfCirculo> circulos;
  final List<DxfTexto> textos;
  final Rect boundingBox;

  DxfGeometria({
    required this.linhas,
    required this.arcos,
    required this.circulos,
    required this.textos,
    required this.boundingBox,
  });

  /// Extrai geometria de um arquivo DXF.
  /// Se [apenasTextos] = true, pula LINE/ARC/CIRCLE/POLYLINE (muito mais rápido).
  static DxfGeometria extrair(String conteudoDxf, {bool apenasTextos = false}) {
    final linhasResult = <DxfLinha>[];
    final arcosResult = <DxfArco>[];
    final circulosResult = <DxfCirculo>[];
    final textosResult = <DxfTexto>[];

    double xMin = double.infinity;
    double yMin = double.infinity;
    double xMax = double.negativeInfinity;
    double yMax = double.negativeInfinity;

    void expandirBbox(double x, double y) {
      if (x < xMin) xMin = x;
      if (x > xMax) xMax = x;
      if (y < yMin) yMin = y;
      if (y > yMax) yMax = y;
    }

    final linhas = conteudoDxf.split('\n');
    int i = 0;

    while (i < linhas.length - 1) {
      final code = linhas[i].trim();
      final val = linhas[i + 1].trim();

      if (code == '0') {
        // Verificar se é entidade válida (não de Paper Space)
        final isPaperSpace = _isPaperSpace(linhas, i + 2);
        
        switch (val) {
          case 'LINE':
            if (apenasTextos || isPaperSpace) { i = _pular(linhas, i + 2); }
            else { i = _parseLine(linhas, i + 2, linhasResult, expandirBbox); }
            break;
          case 'ARC':
            if (apenasTextos || isPaperSpace) { i = _pular(linhas, i + 2); }
            else { i = _parseArc(linhas, i + 2, arcosResult, expandirBbox); }
            break;
          case 'CIRCLE':
            if (apenasTextos || isPaperSpace) { i = _pular(linhas, i + 2); }
            else { i = _parseCircle(linhas, i + 2, circulosResult, expandirBbox); }
            break;
          case 'LWPOLYLINE':
            if (apenasTextos || isPaperSpace) { i = _pular(linhas, i + 2); }
            else { i = _parsePolyline(linhas, i + 2, linhasResult, expandirBbox); }
            break;
          case 'TEXT':
          case 'MTEXT':
            if (isPaperSpace) { i = _pular(linhas, i + 2); }
            else { i = _parseText(linhas, i + 2, val, textosResult, expandirBbox); }
            break;
          default:
            i += 2;
        }
      } else {
        i += 2;
      }
    }

    // Fallback se nenhuma geometria encontrada
    if (xMin == double.infinity) {
      xMin = 0;
      yMin = 0;
      xMax = 1000;
      yMax = 1000;
    }

    return DxfGeometria(
      linhas: linhasResult,
      arcos: arcosResult,
      circulos: circulosResult,
      textos: textosResult,
      boundingBox: Rect.fromLTRB(xMin, yMin, xMax, yMax),
    );
  }

  /// Verifica se a entidade pertence ao Paper Space (layout).
  /// Analisa os group codes da entidade sem avançar o cursor.
  /// Group code 67 = 1 → Paper Space
  /// Group code 410 != 'Model' → Paper Space layout
  static bool _isPaperSpace(List<String> linhas, int inicio) {
    int j = inicio;
    while (j < linhas.length - 1) {
      final c = linhas[j].trim();
      final v = linhas[j + 1].trim();
      if (c == '0') break; // próxima entidade
      if (c == '67' && v == '1') return true; // paper space flag
      if (c == '410' && v != 'Model') return true; // layout name
      j += 2;
    }
    return false;
  }

  /// Pula uma entidade (avança até o próximo code 0).
  static int _pular(List<String> linhas, int inicio) {
    int j = inicio;
    while (j < linhas.length - 1) {
      if (linhas[j].trim() == '0') break;
      j += 2;
    }
    return j;
  }

  /// Parseia uma entidade LINE.
  static int _parseLine(
    List<String> linhas,
    int inicio,
    List<DxfLinha> resultado,
    void Function(double, double) expandirBbox,
  ) {
    String layer = '';
    double x1 = 0, y1 = 0, x2 = 0, y2 = 0;

    int j = inicio;
    while (j < linhas.length - 1) {
      final c = linhas[j].trim();
      final v = linhas[j + 1].trim();
      if (c == '0') break;
      switch (c) {
        case '8': layer = v;
        case '10': x1 = double.tryParse(v) ?? 0;
        case '20': y1 = double.tryParse(v) ?? 0;
        case '11': x2 = double.tryParse(v) ?? 0;
        case '21': y2 = double.tryParse(v) ?? 0;
      }
      j += 2;
    }

    resultado.add(DxfLinha(x1: x1, y1: y1, x2: x2, y2: y2, layer: layer));
    expandirBbox(x1, y1);
    expandirBbox(x2, y2);
    return j;
  }

  /// Parseia uma entidade ARC.
  static int _parseArc(
    List<String> linhas,
    int inicio,
    List<DxfArco> resultado,
    void Function(double, double) expandirBbox,
  ) {
    String layer = '';
    double cx = 0, cy = 0, raio = 0, angInicio = 0, angFim = 360;

    int j = inicio;
    while (j < linhas.length - 1) {
      final c = linhas[j].trim();
      final v = linhas[j + 1].trim();
      if (c == '0') break;
      switch (c) {
        case '8': layer = v;
        case '10': cx = double.tryParse(v) ?? 0;
        case '20': cy = double.tryParse(v) ?? 0;
        case '40': raio = double.tryParse(v) ?? 0;
        case '50': angInicio = double.tryParse(v) ?? 0;
        case '51': angFim = double.tryParse(v) ?? 360;
      }
      j += 2;
    }

    resultado.add(DxfArco(cx: cx, cy: cy, raio: raio, anguloInicio: angInicio, anguloFim: angFim, layer: layer));
    expandirBbox(cx - raio, cy - raio);
    expandirBbox(cx + raio, cy + raio);
    return j;
  }

  /// Parseia uma entidade CIRCLE.
  static int _parseCircle(
    List<String> linhas,
    int inicio,
    List<DxfCirculo> resultado,
    void Function(double, double) expandirBbox,
  ) {
    String layer = '';
    double cx = 0, cy = 0, raio = 0;

    int j = inicio;
    while (j < linhas.length - 1) {
      final c = linhas[j].trim();
      final v = linhas[j + 1].trim();
      if (c == '0') break;
      switch (c) {
        case '8': layer = v;
        case '10': cx = double.tryParse(v) ?? 0;
        case '20': cy = double.tryParse(v) ?? 0;
        case '40': raio = double.tryParse(v) ?? 0;
      }
      j += 2;
    }

    resultado.add(DxfCirculo(cx: cx, cy: cy, raio: raio, layer: layer));
    expandirBbox(cx - raio, cy - raio);
    expandirBbox(cx + raio, cy + raio);
    return j;
  }

  /// Parseia uma entidade LWPOLYLINE (converte em linhas entre vértices).
  static int _parsePolyline(
    List<String> linhas,
    int inicio,
    List<DxfLinha> resultado,
    void Function(double, double) expandirBbox,
  ) {
    String layer = '';
    int fechada = 0;
    final vertices = <({double x, double y})>[];
    double curX = 0, curY = 0;
    bool temX = false;

    int j = inicio;
    while (j < linhas.length - 1) {
      final c = linhas[j].trim();
      final v = linhas[j + 1].trim();
      if (c == '0') break;
      switch (c) {
        case '8': layer = v;
        case '70': fechada = int.tryParse(v) ?? 0;
        case '10':
          // Salvar vértice anterior se tinha X
          if (temX) {
            vertices.add((x: curX, y: curY));
          }
          curX = double.tryParse(v) ?? 0;
          curY = 0; // reset Y para este vértice
          temX = true;
        case '20':
          curY = double.tryParse(v) ?? 0;
      }
      j += 2;
    }

    // Último vértice
    if (temX) {
      vertices.add((x: curX, y: curY));
    }

    // Gerar linhas entre vértices consecutivos
    for (int k = 0; k < vertices.length - 1; k++) {
      final a = vertices[k];
      final b = vertices[k + 1];
      resultado.add(DxfLinha(x1: a.x, y1: a.y, x2: b.x, y2: b.y, layer: layer));
      expandirBbox(a.x, a.y);
    }

    // Fechar polígono se flag 1
    if ((fechada & 1) == 1 && vertices.length > 2) {
      final a = vertices.last;
      final b = vertices.first;
      resultado.add(DxfLinha(x1: a.x, y1: a.y, x2: b.x, y2: b.y, layer: layer));
    }

    // Expandir bbox do último vértice
    if (vertices.isNotEmpty) {
      expandirBbox(vertices.last.x, vertices.last.y);
    }

    return j;
  }

  /// Parseia uma entidade TEXT ou MTEXT.
  static int _parseText(
    List<String> linhas,
    int inicio,
    String tipo,
    List<DxfTexto> resultado,
    void Function(double, double) expandirBbox,
  ) {
    String layer = '';
    double x = 0, y = 0, altura = 10;
    String txt = '';

    int j = inicio;
    while (j < linhas.length - 1) {
      final c = linhas[j].trim();
      final v = linhas[j + 1].trim();
      if (c == '0') break;
      switch (c) {
        case '8': layer = v;
        case '10': x = double.tryParse(v) ?? 0;
        case '20': y = double.tryParse(v) ?? 0;
        case '40': altura = double.tryParse(v) ?? 10;
        case '1': txt = v;
      }
      j += 2;
    }

    if (txt.isNotEmpty) {
      resultado.add(DxfTexto(
        tipo: tipo,
        layer: layer,
        x: x,
        y: y,
        altura: altura,
        conteudo: txt,
      ));
      expandirBbox(x, y);
    }

    return j;
  }
}
