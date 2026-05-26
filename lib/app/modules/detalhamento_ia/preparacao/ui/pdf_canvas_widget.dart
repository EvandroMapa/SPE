import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';

/// Widget para exibir PDF com zoom/pan (scroll) e seleção retangular (Shift+drag).
class PdfCanvasWidget extends StatefulWidget {
  final Uint8List pdfBytes;
  final int paginaAtual;
  final void Function(int pagina)? onPaginaMudou;
  final void Function(Rect regiao, int pagina, Uint8List imagemPagina)? onSelecaoConcluida;

  const PdfCanvasWidget({
    super.key,
    required this.pdfBytes,
    this.paginaAtual = 1,
    this.onPaginaMudou,
    this.onSelecaoConcluida,
  });

  @override
  State<PdfCanvasWidget> createState() => _PdfCanvasWidgetState();
}

class _PdfCanvasWidgetState extends State<PdfCanvasWidget> {
  final TransformationController _transformController = TransformationController();
  PdfDocument? _documento;
  int _totalPaginas = 0;
  int _paginaAtual = 1;
  Uint8List? _imagemPagina;
  bool _carregando = true;
  String? _erro;

  // Seleção retangular
  bool _shiftPressionado = false;
  bool _selecionando = false;
  Offset? _selecaoInicio;
  Offset? _selecaoFim;

  @override
  void initState() {
    super.initState();
    _paginaAtual = widget.paginaAtual;
    _carregarPdf();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  bool _onKey(KeyEvent event) {
    final isShift = event.logicalKey == LogicalKeyboardKey.shiftLeft ||
                    event.logicalKey == LogicalKeyboardKey.shiftRight;
    if (isShift) {
      setState(() => _shiftPressionado = event is KeyDownEvent || event is KeyRepeatEvent);
    }
    return false;
  }

  Future<void> _carregarPdf() async {
    try {
      setState(() { _carregando = true; _erro = null; });
      _documento = await PdfDocument.openData(widget.pdfBytes);
      _totalPaginas = _documento!.pagesCount;
      await _renderizarPagina();
    } catch (e) {
      setState(() { _erro = 'Erro ao abrir PDF: $e'; _carregando = false; });
    }
  }

  Future<void> _renderizarPagina() async {
    if (_documento == null) return;
    try {
      setState(() => _carregando = true);
      final page = await _documento!.getPage(_paginaAtual);
      final pageImage = await page.render(
        width: page.width * 3,
        height: page.height * 3,
        format: PdfPageImageFormat.png,
        quality: 100,
      );
      await page.close();
      if (mounted) {
        setState(() {
          _imagemPagina = pageImage?.bytes;
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _erro = 'Erro ao renderizar página: $e'; _carregando = false; });
    }
  }

  void _irParaPagina(int pagina) {
    if (pagina < 1 || pagina > _totalPaginas) return;
    setState(() => _paginaAtual = pagina);
    widget.onPaginaMudou?.call(pagina);
    _renderizarPagina();
  }

  void _onPanStart(DragStartDetails details) {
    if (_shiftPressionado) {
      setState(() {
        _selecionando = true;
        _selecaoInicio = details.localPosition;
        _selecaoFim = details.localPosition;
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_selecionando) {
      setState(() => _selecaoFim = details.localPosition);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_selecionando && _selecaoInicio != null && _selecaoFim != null) {
      final regiao = Rect.fromPoints(_selecaoInicio!, _selecaoFim!);
      if (regiao.width > 10 && regiao.height > 10 && _imagemPagina != null) {
        widget.onSelecaoConcluida?.call(regiao, _paginaAtual, _imagemPagina!);
      }
      setState(() {
        _selecionando = false;
        _selecaoInicio = null;
        _selecaoFim = null;
      });
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _transformController.dispose();
    _documento?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        color: const Color(0xFFF8FAFC),
        child: Stack(
          children: [
            // PDF com zoom/pan via InteractiveViewer
            if (_carregando)
              const Center(child: CircularProgressIndicator())
            else if (_erro != null)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                    const SizedBox(height: 12),
                    Text(_erro!, style: TextStyle(color: Colors.red[700], fontSize: 12)),
                  ],
                ),
              )
            else if (_imagemPagina != null)
              InteractiveViewer(
                transformationController: _transformController,
                minScale: 0.5,
                maxScale: 8.0,
                child: Center(
                  child: Image.memory(
                    _imagemPagina!,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),

            // Overlay de seleção (só quando Shift pressionado)
            if (_shiftPressionado || _selecionando)
              Positioned.fill(
                child: GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: Container(color: Colors.transparent),
                ),
              ),

            // Retângulo de seleção
            if (_selecionando && _selecaoInicio != null && _selecaoFim != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _SelecaoPainter(
                      inicio: _selecaoInicio!,
                      fim: _selecaoFim!,
                    ),
                  ),
                ),
              ),

            // Dica de Shift
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _shiftPressionado
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.85)
                      : Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _shiftPressionado ? Icons.crop_free : Icons.crop,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _shiftPressionado ? 'Arraste para selecionar' : 'Shift + Arrastar para selecionar',
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.9)),
                    ),
                  ],
                ),
              ),
            ),

            // Toolbar inferior
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
                      final center = context.size != null
                          ? Offset(context.size!.width / 2, context.size!.height / 2)
                          : Offset.zero;
                      matrix.translate(center.dx, center.dy);
                      matrix.scale(1.3, 1.3);
                      matrix.translate(-center.dx, -center.dy);
                      _transformController.value = matrix;
                    }),
                    _toolbarBtn(Icons.zoom_out, 'Zoom -', () {
                      final matrix = _transformController.value.clone();
                      final center = context.size != null
                          ? Offset(context.size!.width / 2, context.size!.height / 2)
                          : Offset.zero;
                      matrix.translate(center.dx, center.dy);
                      matrix.scale(0.7, 0.7);
                      matrix.translate(-center.dx, -center.dy);
                      _transformController.value = matrix;
                    }),
                    Container(width: 1, height: 20, color: const Color(0xFFE2E8F0)),
                    _toolbarBtn(Icons.fit_screen, 'Encaixar', () {
                      _transformController.value = Matrix4.identity();
                    }),
                    if (_totalPaginas > 1) ...[
                      Container(width: 1, height: 20, color: const Color(0xFFE2E8F0)),
                      _toolbarBtn(Icons.chevron_left, 'Página anterior', () => _irParaPagina(_paginaAtual - 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '$_paginaAtual / $_totalPaginas',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500),
                        ),
                      ),
                      _toolbarBtn(Icons.chevron_right, 'Próxima página', () => _irParaPagina(_paginaAtual + 1)),
                    ],
                  ],
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
}

/// Painter do retângulo de seleção.
class _SelecaoPainter extends CustomPainter {
  final Offset inicio;
  final Offset fim;

  _SelecaoPainter({required this.inicio, required this.fim});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromPoints(inicio, fim);

    final paintFundo = Paint()..color = Colors.black.withValues(alpha: 0.3);
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, paintFundo);
    canvas.drawRect(rect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    final paintBorda = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(rect, paintBorda);

    final paintCanto = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    const t = 12.0;
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(t, 0), paintCanto);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, t), paintCanto);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(-t, 0), paintCanto);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(0, t), paintCanto);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(t, 0), paintCanto);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(0, -t), paintCanto);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(-t, 0), paintCanto);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(0, -t), paintCanto);
  }

  @override
  bool shouldRepaint(_SelecaoPainter oldDelegate) =>
      inicio != oldDelegate.inicio || fim != oldDelegate.fim;
}
