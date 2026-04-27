
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
                              ElevatedButton.icon(
                                focusNode: _focoBotaoAdicionar,
                                onPressed: () => formaCtrl.adicionarItem(),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('ADICIONAR'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryMain.withValues(alpha: 0.1),
                                  foregroundColor: AppColors.primaryMain,
                                  elevation: 0,
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
                      child: _buildImagePicker(formulario),
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



  Widget _buildImagePicker(FormaCriarModel formulario) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Visualização / Desenho', style: AppCss.smallBold),
            if (formulario.imagem.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  // Lógica para limpar imagem e voltar para o desenho técnico
                  formulario.imagem = '';
                  formaCtrl.formularioStream.update();
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('DESENHO TÉCNICO', style: TextStyle(fontSize: 10)),
              ),
          ],
        ),
        const H(8),
        InkWell(
          onTap: () {
            // Aqui entraria o seletor de imagem se o usuário quiser substituir o desenho por uma foto
          },
          child: formulario.imagem.isEmpty
              ? FormaPreviewWidget(
                  itens: formulario.itens,
                  height: 400,
                  onChanged: () => formaCtrl.formularioStream.update(),
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
        const H(8),
        Center(
          child: TextButton.icon(
            onPressed: () {
              // Aqui chamaria o seletor de imagem real
            },
            icon: const Icon(Icons.camera_alt_outlined, size: 18),
            label: const Text('SUBSTITUIR POR FOTO/ARQUIVO'),
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
              Expanded(child: Text('Compr.', style: AppCss.minimumBold)),
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
                      initialValue: item.comprimento.toString(),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (val) {
                        item.comprimento = int.tryParse(val) ?? 0;
                        formaCtrl.formularioStream.update();
                      },
                      decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      focusNode: item.focusNode,
                      initialValue: item.angulo.toString(),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (val) {
                        item.angulo = double.tryParse(val) ?? 0;
                        formaCtrl.formularioStream.update();
                      },
                      onFieldSubmitted: (_) => _focoBotaoAdicionar.requestFocus(),
                      decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                    ),
                  ),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: item.orientacao,
                        isDense: true,
                        items: ['Horário', 'Anti-horário']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e, style: AppCss.minimumRegular)))
                            .toList(),
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
