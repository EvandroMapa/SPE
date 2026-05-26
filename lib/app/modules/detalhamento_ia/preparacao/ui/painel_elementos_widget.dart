import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:flutter/material.dart';
import 'package:acoplan/app/modules/detalhamento_ia/preparacao/models/elemento_preparado.dart';

/// Painel lateral com lista de elementos detectados/confirmados.
class PainelElementosWidget extends StatelessWidget {
  final List<ElementoPreparado> elementos;
  final String? elementoSelecionado;
  final int totalPosicoes;
  final VoidCallback? onAutoDetectar;
  final VoidCallback? onImportar;
  final void Function(String nome)? onElementoClicado;
  final void Function(String nome)? onRemoverElemento;

  const PainelElementosWidget({
    super.key,
    required this.elementos,
    this.elementoSelecionado,
    required this.totalPosicoes,
    this.onAutoDetectar,
    this.onImportar,
    this.onElementoClicado,
    this.onRemoverElemento,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border(left: BorderSide(color: const Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Botão auto-detectar
          _buildAutoDetectar(),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Lista de elementos
          Expanded(child: _buildListaElementos()),

          // Resumo
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          _buildResumo(),

          // Ações
          _buildAcoes(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryMain.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.layers, size: 16, color: AppColors.primaryMain),
          ),
          const SizedBox(width: 10),
          Text('Elementos', style: AppCss.mediumBold.setColor(const Color(0xFF1E293B))),
        ],
      ),
    );
  }

  Widget _buildAutoDetectar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onAutoDetectar,
          icon: const Icon(Icons.auto_awesome, size: 16),
          label: const Text('Auto-detectar', style: TextStyle(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryMain,
            side: BorderSide(color: AppColors.primaryMain.withValues(alpha: 0.3)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildListaElementos() {
    if (elementos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app, size: 40, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(
                'Nenhum elemento definido',
                style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Use "Auto-detectar" ou\nShift+arrastar no canvas',
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: elementos.length,
      itemBuilder: (context, index) {
        final elem = elementos[index];
        final isSelecionado = elem.nome == elementoSelecionado;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Material(
            color: isSelecionado
                ? elem.cor.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () => onElementoClicado?.call(elem.nome),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    // Cor do elemento
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: elem.cor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: elem.cor.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Nome
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            elem.nome,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelecionado ? elem.cor : const Color(0xFF334155),
                            ),
                          ),
                          if (elem.processandoIa)
                            Row(
                              children: [
                                SizedBox(
                                  width: 10, height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: elem.cor,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Analisando com IA...',
                                  style: TextStyle(fontSize: 11, color: elem.cor, fontStyle: FontStyle.italic),
                                ),
                              ],
                            )
                          else
                            Text(
                              '${elem.posicoes.length} posição${elem.posicoes.length != 1 ? 'ões' : ''}',
                              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                            ),
                        ],
                      ),
                    ),

                    // Ícone confirmado ou spinner
                    if (elem.processandoIa)
                      SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: elem.cor.withValues(alpha: 0.5),
                        ),
                      )
                    else if (elem.confirmado)
                      Icon(Icons.check_circle, size: 14, color: Colors.green[400]),

                    // Botão excluir
                    InkWell(
                      onTap: () => onRemoverElemento?.call(elem.nome),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 14, color: Colors.grey[400]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResumo() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _resumoItem('${elementos.length}', 'elementos'),
          Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
          _resumoItem('$totalPosicoes', 'posições'),
          Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
          _resumoItem(
            '${elementos.where((e) => e.confirmado).length}',
            'confirmados',
          ),
        ],
      ),
    );
  }

  Widget _resumoItem(String valor, String label) {
    return Column(
      children: [
        Text(valor, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildAcoes() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Importar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: elementos.isNotEmpty ? onImportar : null,
              icon: const Icon(Icons.file_download, size: 16),
              label: const Text('Importar →', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMain,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                disabledBackgroundColor: Colors.grey[300],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
