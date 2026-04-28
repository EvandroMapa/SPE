
import 'package:acoplan/app/core/components/app_scaffold.dart';
import 'package:acoplan/app/core/components/h.dart';
import 'package:acoplan/app/core/components/stream_out.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/modules/forma/forma_controller.dart';
import 'package:acoplan/app/modules/forma/forma_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acoplan/app/modules/forma/ui/forma_preview_widget.dart';

class FormaCreatePage extends StatelessWidget {
  FormaCreatePage({super.key});

  final FocusNode _focoBotaoAdicionar = FocusNode();
  final GlobalKey<FormaPreviewState> _previewKey = GlobalKey<FormaPreviewState>();

  @override
  Widget build(BuildContext context) {
    return StreamOut<FormaCriarModel>(
      stream: formaCtrl.formularioStream.listen,
      builder: (context, formulario) {
        return AppScaffold(
          appBar: AppBar(
            iconTheme: const IconThemeData(color: Colors.white, size: 20),
            backgroundColor: AppColors.primaryMain,
            title: Text(
              formulario.is_edicao ? 'Editar Forma' : 'Nova Forma',
              style: AppCss.mediumBold.setColor(Colors.white),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Linha Superior: Código e Descrição ──────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 150,
                      child: _buildField('Código', formulario.codigo, Icons.tag, apenasNumeros: true),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildField('Descrição', formulario.descricao, Icons.description_outlined),
                    ),
                  ],
                ),
                const H(32),

                // ── Conteúdo Principal: Trechos (Esq) e Desenho (Dir) ────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Coluna da Esquerda: Trechos
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Itens / Trechos', style: AppCss.mediumBold),
                              IconButton(
                                focusNode: _focoBotaoAdicionar,
                                onPressed: () {
                                  _previewKey.currentState?.prepararAdicionarTrecho();
                                  formaCtrl.adicionarItem();
                                },
                                icon: const Icon(Icons.add, size: 20),
                                color: AppColors.primaryMain,
                                tooltip: 'Adicionar Trecho',
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.primaryMain.withValues(alpha: 0.1),
                                ),
                              ),
                            ],
                          ),
                          const H(16),
                          _buildItensTable(formulario),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    // Coluna da Direita: Desenho
                    Expanded(
                      flex: 1,
                      child: _buildImagePicker(context, formulario),
                    ),
                  ],
                ),
                const H(40),
                
                // ── Botão Salvar ──────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => formaCtrl.confirmar(context),
                    child: const Text('SALVAR CADASTRO'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildField(String label, dynamic controller, IconData icon, {bool apenasNumeros = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppCss.smallBold),
        const H(8),
        TextField(
          controller: controller.controller,
          keyboardType: apenasNumeros ? TextInputType.number : TextInputType.text,
          inputFormatters: apenasNumeros 
              ? [FilteringTextInputFormatter.digitsOnly] 
              : [],
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20),
          ),
        ),
      ],
    );
  }



  Widget _buildImagePicker(BuildContext context, FormaCriarModel formulario) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Visualização', style: AppCss.smallBold),
            Row(
              children: [
                // ── Formas Especiais ─────────────────────────────
                PopupMenuButton<String>(
                  tooltip: 'Formas Especiais',
                  offset: const Offset(0, 36),
                  onSelected: (val) {
                    if (val == 'circulo') formaCtrl.adicionarCirculo();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'circulo',
                      child: Row(
                        children: [
                          Icon(Icons.circle_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Círculo'),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primaryMain.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.primaryMain),
                  ),
                ),
                const SizedBox(width: 6),
                // ── Divisor visual ────────────────────────────────
                Container(width: 1, height: 24, color: Colors.grey[300]),
                const SizedBox(width: 6),
                // ── Rotação ───────────────────────────────────────
                IconButton(
                  onPressed: () => formaCtrl.rotacionarDesenho(-90),
                  icon: const Text('↺', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  tooltip: 'Girar 90° Anti-horário',
                  color: AppColors.primaryMain,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primaryMain.withValues(alpha: 0.08),
                    padding: const EdgeInsets.all(6),
                    minimumSize: const Size(34, 34),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => formaCtrl.rotacionarDesenho(90),
                  icon: const Text('↻', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  tooltip: 'Girar 90° Horário',
                  color: AppColors.primaryMain,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primaryMain.withValues(alpha: 0.08),
                    padding: const EdgeInsets.all(6),
                    minimumSize: const Size(34, 34),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => formaCtrl.toggleLegenda(),
                  icon: Icon(
                    formaCtrl.mostrarLegenda ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    size: 18,
                  ),
                  tooltip: formaCtrl.mostrarLegenda ? 'Ocultar legendas' : 'Mostrar legendas',
                  color: formaCtrl.mostrarLegenda ? AppColors.primaryMain : Colors.grey[400],
                  style: IconButton.styleFrom(
                    backgroundColor: formaCtrl.mostrarLegenda
                        ? AppColors.primaryMain.withValues(alpha: 0.08)
                        : Colors.grey[200],
                    padding: const EdgeInsets.all(6),
                    minimumSize: const Size(34, 34),
                  ),
                ),
                if (formulario.imagem.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  TextButton.icon(
                    onPressed: () {
                      formulario.imagem = '';
                      formaCtrl.formularioStream.update();
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('DESENHO TÉCNICO', style: TextStyle(fontSize: 10)),
                  ),
                ],
                if (formulario.itens.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(width: 1, height: 24, color: Colors.grey[300]),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Limpar Desenho',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Limpar Desenho'),
                            content: const Text('Deseja remover todos os trechos do desenho?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Limpar', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) formaCtrl.limparDesenho();
                      },
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const H(8),
        InkWell(
          onTap: () {},
          child: formulario.imagem.isEmpty
              ? FormaPreviewWidget(
                  key: _previewKey,
                  itens: formulario.itens,
                  height: 400,
                  onChanged: () => formaCtrl.formularioStream.update(),
                  rotacaoExterna: formaCtrl.rotacaoDesenho,
                  mostrarLegenda: formaCtrl.mostrarLegenda,
                )
              : Container(
                  height: 400,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Image.network(formulario.imagem, fit: BoxFit.contain),
                ),
        ),
      ],
    );
  }

  Widget _buildItensTable(FormaCriarModel formulario) {
    if (formulario.itens.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Center(
          child: Text(
            'Nenhum trecho adicionado',
            style: AppCss.smallRegular.setColor(Colors.grey[400]!),
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Row(
            children: [
              Expanded(child: Text('Trecho', style: AppCss.minimumBold)),
              Expanded(child: Text('Ângulo', style: AppCss.minimumBold)),
              Expanded(child: Text('Orientação', style: AppCss.minimumBold)),
              const SizedBox(width: 40),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: formulario.itens.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = formulario.itens[index];
            return Container(
              key: ValueKey('item_${item.trecho}'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  left: BorderSide(color: Colors.grey[200]!),
                  right: BorderSide(color: Colors.grey[200]!),
                  bottom: index == formulario.itens.length - 1 
                      ? BorderSide(color: Colors.grey[200]!) 
                      : BorderSide.none,
                ),
                borderRadius: index == formulario.itens.length - 1
                    ? const BorderRadius.vertical(bottom: Radius.circular(8))
                    : BorderRadius.zero,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        item.trecho,
                        style: AppCss.smallBold.setColor(AppColors.primaryMain),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      focusNode: item.focusNode,
                      controller: item.anguloController,
                      keyboardType: TextInputType.number,
                      onEditingComplete: () {
                        item.angulo = (int.tryParse(item.anguloController.text) ?? 0).toDouble();
                        formaCtrl.formularioStream.update();
                        _focoBotaoAdicionar.requestFocus();
                      },
                      decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                    ),
                  ),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: item.orientacao,
                        isDense: true,
                        items: [
                          DropdownMenuItem(value: 'Horário', child: Text('↻ Horário', style: AppCss.minimumRegular)),
                          DropdownMenuItem(value: 'Anti-horário', child: Text('↺ Anti-horário', style: AppCss.minimumRegular)),
                        ],
                        selectedItemBuilder: (_) => [
                          Text('↻', style: AppCss.smallBold.copyWith(fontSize: 18)),
                          Text('↺', style: AppCss.smallBold.copyWith(fontSize: 18)),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            item.orientacao = val;
                            formaCtrl.formularioStream.update();
                          }
                        },
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => formaCtrl.removerItem(index),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
