import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:acoplan/app/modules/detalhamento_ia/preparacao/dxf_geometria.dart';
import 'package:acoplan/app/modules/detalhamento_ia/preparacao/models/elemento_preparado.dart';
import 'package:acoplan/app/modules/detalhamento_ia/preparacao/ui/dxf_canvas_painter.dart';

/// Widget interativo para visualizar e selecionar regiões no DXF.
///
/// Suporta:
/// - Pan (arrastar com botão esquerdo)
/// - Zoom (scroll do mouse)
/// - Seleção retangular (Shift + drag)
class DxfCanvasWidget extends StatefulWidget {
  final DxfGeometria geometria;
  final List<ElementoPreparado> elementos;
  final String? elementoSelecionado;
  final void Function(Rect regiao, List<int> textosIndices)? onSelecaoConcluida;
  final void Function(String nome)? onElementoClicado;

  const DxfCanvasWidget({
    super.key,
    required this.geometria,
    this.elementos = const [],
    this.elementoSelecionado,
    this.onSelecaoConcluida,
    this.onElementoClicado,
  });

  @override
  State<DxfCanvasWidget> createState() => _DxfCanvasWidgetState();
}

class _DxfCanvasWidgetState extends State<DxfCanvasWidget> {
  final _transformController = TransformationController();
  
  // Estado da seleção
  Offset? _selecaoInicio; // em coordenadas do canvas (DXF)
  Offset? _selecaoFim;
  bool _selecionando = false;
  Set<int> _textosDestacados = {};
  
  // Estado do zoom
  double _zoomAtual = 1.0;

  @override
  void initState() {
    super.initState();
    // Ajustar view inicial após o layout
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitToView());
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  /// Ajusta o zoom/pan para mostrar o elemento selecionado ou todo o desenho.
  void _fitToView() {
    // 1) Se tem elemento selecionado, zoom nele
    if (widget.elementoSelecionado != null) {
      final elem = widget.elementos.where((e) => e.nome == widget.elementoSelecionado).firstOrNull;
      if (elem != null) {
        _fitToRect(elem.boundingBox);
        return;
      }
    }
    // 2) Se tem elementos detectados, zoom na união de todos
    if (widget.elementos.isNotEmpty) {
      Rect uniao = widget.elementos.first.boundingBox;
      for (final e in widget.elementos.skip(1)) {
        uniao = uniao.expandToInclude(e.boundingBox);
      }
      _fitToRect(uniao);
      return;
    }
    // 3) Bbox inteligente: descarta layers de carimbo/moldura
    _fitToRect(_calcularBboxInteligente());
  }

  /// Layers a ignorar no cálculo do bounding box (carimbo, moldura, defpoints).
  static final _layersIgnorados = {
    'FORMATO',
    'G-ANNO-TTLB',
    'G-ANNO-TTLB-MEDM',
    'Defpoints',
    '0',
    '04',
  };

  /// Verifica se um layer deve ser ignorado (carimbo, moldura, etc).
  static bool _isLayerIgnorado(String layer) {
    if (_layersIgnorados.contains(layer)) return true;
    // Layers PENA-* são linhas de moldura
    if (layer.startsWith('PENA-')) return true;
    return false;
  }

  /// Calcula bounding box ignorando layers de carimbo/moldura.
  Rect _calcularBboxInteligente() {
    final geo = widget.geometria;
    double xMin = double.infinity, yMin = double.infinity;
    double xMax = double.negativeInfinity, yMax = double.negativeInfinity;
    int pontos = 0;

    void expandir(double x, double y) {
      if (x < xMin) xMin = x;
      if (x > xMax) xMax = x;
      if (y < yMin) yMin = y;
      if (y > yMax) yMax = y;
      pontos++;
    }

    // Coordenadas de linhas (exceto layers ignorados)
    for (final l in geo.linhas) {
      if (_isLayerIgnorado(l.layer)) continue;
      expandir(l.x1, l.y1);
      expandir(l.x2, l.y2);
    }
    // Coordenadas de textos (exceto layers ignorados)
    for (final t in geo.textos) {
      if (_isLayerIgnorado(t.layer)) continue;
      expandir(t.x, t.y);
    }
    // Arcos
    for (final a in geo.arcos) {
      if (_isLayerIgnorado(a.layer)) continue;
      expandir(a.cx - a.raio, a.cy - a.raio);
      expandir(a.cx + a.raio, a.cy + a.raio);
    }

    if (pontos < 2) return geo.boundingBox;
    return Rect.fromLTRB(xMin, yMin, xMax, yMax);
  }

  /// Enquadra um retângulo (em coordenadas DXF) na tela.
  void _fitToRect(Rect bbox) {
    if (!mounted) return;
    final size = context.size;
    if (size == null || size.isEmpty) return;
    if (bbox.isEmpty || bbox.width <= 0 || bbox.height <= 0) return;

    final drawWidth = bbox.width;
    final drawHeight = bbox.height;

    // Preencher a tela com margem
    final margin = 40.0;
    final scaleX = (size.width - margin * 2) / drawWidth;
    final scaleY = (size.height - margin * 2) / drawHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    // Centro do bbox em coordenadas do canvas (Y invertido)
    final centerX = bbox.left + drawWidth / 2;
    final centerY = -(bbox.top + drawHeight / 2); // Y invertido

    final matrix = Matrix4.identity()
      ..translate(size.width / 2, size.height / 2)
      ..scale(scale, scale)
      ..translate(-centerX, -centerY);

    _transformController.value = matrix;
    _zoomAtual = scale;
  }

  @override
  void didUpdateWidget(covariant DxfCanvasWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-enquadrar quando o elemento selecionado mudar
    if (oldWidget.elementoSelecionado != widget.elementoSelecionado && widget.elementoSelecionado != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitToView());
    }
  }

  /// Converte coordenadas de tela para coordenadas DXF.
  Offset _telaParaDxf(Offset posicaoTela) {
    final matrix = Matrix4.inverted(_transformController.value);
    final ponto = MatrixUtils.transformPoint(matrix, posicaoTela);
    return Offset(ponto.dx, ponto.dy);
  }

  /// Atualiza os textos destacados (dentro da seleção atual).
  void _atualizarDestacados() {
    if (_selecaoInicio == null || _selecaoFim == null) {
      _textosDestacados = {};
      return;
    }

    final selecao = Rect.fromPoints(_selecaoInicio!, _selecaoFim!);
    final novosDestacados = <int>{};

    for (int i = 0; i < widget.geometria.textos.length; i++) {
      final t = widget.geometria.textos[i];
      // Coordenadas do texto no canvas (Y invertido)
      final ponto = Offset(t.x, -t.y);
      if (selecao.contains(ponto)) {
        novosDestacados.add(i);
      }
    }

    _textosDestacados = novosDestacados;
  }

  /// Retorna o retângulo de seleção em coordenadas do canvas.
  Rect? get _selecaoRect {
    if (_selecaoInicio == null || _selecaoFim == null) return null;
    return Rect.fromPoints(_selecaoInicio!, _selecaoFim!);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA), // fundo claro (papel)
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Canvas principal
            Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  // Zoom com scroll
                  final delta = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
                  final focalPoint = event.localPosition;

                  final matrix = _transformController.value.clone();
                  final focalDxf = MatrixUtils.transformPoint(
                    Matrix4.inverted(matrix),
                    focalPoint,
                  );

                  matrix
                    ..translate(focalDxf.dx, focalDxf.dy)
                    ..scale(delta, delta)
                    ..translate(-focalDxf.dx, -focalDxf.dy);

                  _transformController.value = matrix;
                  _zoomAtual *= delta;
                }
              },
              child: GestureDetector(
                onPanStart: (details) {
                  // Verificar se Shift está pressionado para seleção
                  if (HardwareKeyboard.instance.logicalKeysPressed
                      .any((key) => key == LogicalKeyboardKey.shiftLeft || key == LogicalKeyboardKey.shiftRight)) {
                    _selecionando = true;
                    _selecaoInicio = _telaParaDxf(details.localPosition);
                    _selecaoFim = _selecaoInicio;
                    setState(() {});
                  }
                },
                onPanUpdate: (details) {
                  if (_selecionando) {
                    _selecaoFim = _telaParaDxf(details.localPosition);
                    _atualizarDestacados();
                    setState(() {});
                  } else {
                    // Pan normal
                    final matrix = _transformController.value.clone();
                    matrix.translate(
                      details.delta.dx / _zoomAtual,
                      details.delta.dy / _zoomAtual,
                    );
                    _transformController.value = matrix;
                  }
                },
                onPanEnd: (details) {
                  if (_selecionando && _selecaoInicio != null && _selecaoFim != null) {
                    final selecao = Rect.fromPoints(_selecaoInicio!, _selecaoFim!);
                    if (selecao.width > 5 && selecao.height > 5) {
                      widget.onSelecaoConcluida?.call(selecao, _textosDestacados.toList());
                    }
                    _selecionando = false;
                    _selecaoInicio = null;
                    _selecaoFim = null;
                    _textosDestacados = {};
                    setState(() {});
                  }
                },
                child: AnimatedBuilder(
                  animation: _transformController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: DxfCanvasPainter(
                        geometria: widget.geometria,
                        elementos: widget.elementos,
                        selecaoAtual: _selecaoRect,
                        elementoSelecionado: widget.elementoSelecionado,
                        textosDestacados: _textosDestacados,
                        transform: _transformController.value,
                      ),
                      size: Size.infinite,
                    );
                  },
                ),
              ),
            ),

            // Toolbar flutuante (zoom controls)
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _toolbarBtn(Icons.zoom_in, 'Zoom +', () {
                      final matrix = _transformController.value.clone();
                      matrix.scale(1.2, 1.2);
                      _transformController.value = matrix;
                      _zoomAtual *= 1.2;
                    }),
                    _toolbarBtn(Icons.zoom_out, 'Zoom -', () {
                      final matrix = _transformController.value.clone();
                      matrix.scale(0.8, 0.8);
                      _transformController.value = matrix;
                      _zoomAtual *= 0.8;
                    }),
                    Container(width: 1, height: 20, color: const Color(0xFFE2E8F0)),
                    _toolbarBtn(Icons.fit_screen, 'Encaixar', _fitToView),
                  ],
                ),
              ),
            ),

            // Indicador de instrução
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      _selecionando
                          ? 'Solte para confirmar a seleção'
                          : 'Shift + arrastar para selecionar região',
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),

            // Painel de debug (layers e stats)
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                width: 280,
                constraints: const BoxConstraints(maxHeight: 300),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text('🔍 Debug DXF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey[800])),
                          const Spacer(),
                          InkWell(
                            onTap: () {
                              final txt = _gerarTextoDebug();
                              Clipboard.setData(ClipboardData(text: txt));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.copy, size: 12, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text('Copiar', style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Builder(builder: (_) {
                        final bbOriginal = widget.geometria.boundingBox;
                        final bbFiltrado = _calcularBboxInteligente();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BBox Original: ${bbOriginal.left.toStringAsFixed(0)}, ${bbOriginal.top.toStringAsFixed(0)} → ${bbOriginal.right.toStringAsFixed(0)}, ${bbOriginal.bottom.toStringAsFixed(0)}',
                              style: TextStyle(fontSize: 9, color: Colors.red[400], fontFamily: 'monospace'),
                            ),
                            Text(
                              'BBox Filtrado: ${bbFiltrado.left.toStringAsFixed(0)}, ${bbFiltrado.top.toStringAsFixed(0)} → ${bbFiltrado.right.toStringAsFixed(0)}, ${bbFiltrado.bottom.toStringAsFixed(0)}',
                              style: TextStyle(fontSize: 9, color: Colors.green[600], fontFamily: 'monospace', fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Linhas: ${widget.geometria.linhas.length} | Textos: ${widget.geometria.textos.length} | Arcos: ${widget.geometria.arcos.length}',
                              style: TextStyle(fontSize: 9, color: Colors.grey[600], fontFamily: 'monospace'),
                            ),
                          ],
                        );
                      }),
                      const Divider(height: 8),
                      Text('Layers (por linhas):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.grey[700])),
                      ..._contarLayersLinhas().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '  ${e.key}: ${e.value} linhas',
                          style: TextStyle(fontSize: 9, color: Colors.grey[600], fontFamily: 'monospace'),
                        ),
                      )),
                      const Divider(height: 8),
                      Text('Layers (por textos):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.grey[700])),
                      ..._contarLayersTextos().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '  ${e.key}: ${e.value} textos',
                          style: TextStyle(fontSize: 9, color: Colors.grey[600], fontFamily: 'monospace'),
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbarBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: Colors.grey[700]),
        ),
      ),
    );
  }

  Map<String, int> _contarLayersLinhas() {
    final contagem = <String, int>{};
    for (final l in widget.geometria.linhas) {
      contagem[l.layer] = (contagem[l.layer] ?? 0) + 1;
    }
    // Ordenar por quantidade (decrescente)
    final sorted = contagem.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }

  Map<String, int> _contarLayersTextos() {
    final contagem = <String, int>{};
    for (final t in widget.geometria.textos) {
      contagem[t.layer] = (contagem[t.layer] ?? 0) + 1;
    }
    final sorted = contagem.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }

  String _gerarTextoDebug() {
    final bb = widget.geometria.boundingBox;
    final bbF = _calcularBboxInteligente();
    final buf = StringBuffer();
    buf.writeln('=== DEBUG DXF ===');
    buf.writeln('BBox Original: ${bb.left.toStringAsFixed(1)}, ${bb.top.toStringAsFixed(1)} → ${bb.right.toStringAsFixed(1)}, ${bb.bottom.toStringAsFixed(1)}');
    buf.writeln('BBox Filtrado: ${bbF.left.toStringAsFixed(1)}, ${bbF.top.toStringAsFixed(1)} → ${bbF.right.toStringAsFixed(1)}, ${bbF.bottom.toStringAsFixed(1)}');
    buf.writeln('Linhas: ${widget.geometria.linhas.length} | Textos: ${widget.geometria.textos.length} | Arcos: ${widget.geometria.arcos.length} | Círculos: ${widget.geometria.circulos.length}');
    buf.writeln('');
    buf.writeln('--- Layers (linhas) ---');
    for (final e in _contarLayersLinhas().entries) {
      buf.writeln('  ${e.key}: ${e.value}');
    }
    buf.writeln('');
    buf.writeln('--- Layers (textos) ---');
    for (final e in _contarLayersTextos().entries) {
      buf.writeln('  ${e.key}: ${e.value}');
    }
    return buf.toString();
  }
}
