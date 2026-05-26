import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:acoplan/app/modules/detalhamento_ia/preparacao/models/elemento_preparado.dart';

/// Dialog para confirmar/nomear um elemento após seleção no canvas.
class DialogConfirmarElemento extends StatefulWidget {
  final String? nomeSugerido;
  final List<PosicaoPreparada> posicoes;

  const DialogConfirmarElemento({
    super.key,
    this.nomeSugerido,
    required this.posicoes,
  });

  /// Mostra o dialog e retorna o nome confirmado, ou null se cancelado.
  static Future<String?> mostrar(
    BuildContext context, {
    String? nomeSugerido,
    required List<PosicaoPreparada> posicoes,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (_) => DialogConfirmarElemento(
        nomeSugerido: nomeSugerido,
        posicoes: posicoes,
      ),
    );
  }

  @override
  State<DialogConfirmarElemento> createState() => _DialogConfirmarElementoState();
}

class _DialogConfirmarElementoState extends State<DialogConfirmarElemento> {
  late final TextEditingController _nomeCtrl;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController(text: widget.nomeSugerido ?? '');
    // Selecionar todo o texto para facilitar edição
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _nomeCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _nomeCtrl.text.length,
      );
    });
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _confirmar() {
    final nome = _nomeCtrl.text.trim().toUpperCase();
    if (nome.isEmpty) return;
    Navigator.pop(context, nome);
  }

  @override
  Widget build(BuildContext context) {
    final posicoes = widget.posicoes;
    final nomes = posicoes.map((p) => 'N${p.posicao}').join(', ');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryMain.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.crop_free, size: 20, color: AppColors.primaryMain),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nomear Elemento',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '${posicoes.length} posição${posicoes.length != 1 ? 'ões' : ''} encontrada${posicoes.length != 1 ? 's' : ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.normal),
              ),
            ],
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campo de nome
          TextField(
            controller: _nomeCtrl,
            focusNode: _focusNode,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Nome do elemento',
              hintText: 'Ex: V101',
              prefixIcon: const Icon(Icons.label_outline, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.primaryMain, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
            onSubmitted: (_) => _confirmar(),
          ),
          const SizedBox(height: 12),

          // Lista de posições encontradas
          if (posicoes.isNotEmpty) ...[
            Text(
              'Posições encontradas:',
              style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              constraints: const BoxConstraints(maxHeight: 120),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: posicoes.map((p) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        '${p.quantidade} N${p.posicao} ø${p.bitolaMm} C=${p.comprimentos['A'] ?? '?'}',
                        style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],

          if (posicoes.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nenhuma posição de armadura encontrada nesta seleção.',
                      style: TextStyle(fontSize: 11, color: Colors.orange[800]),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _confirmar,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryMain,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
