
import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/produto_model.dart';
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
                const H(24),
                _SimulacaoCorte(formulario: formulario),
                const H(24),

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
              SizedBox(width: 64, child: Center(child: Text('Grupo', style: AppCss.minimumBold))),
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
                   // ── Dropdown Grupo de Simetria ───────────────────
                  SizedBox(
                    width: 64,
                    child: Center(
                      child: _GrupoBadge(
                        value: item.grupoSimetria,
                        onChanged: (g) {
                          item.grupoSimetria = g;
                          formaCtrl.formularioStream.update();
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

// ── Widget de Simulação de Comprimento de Corte ──────────────────────────────
class _SimulacaoCorte extends StatefulWidget {
  final FormaCriarModel formulario;
  const _SimulacaoCorte({required this.formulario});

  @override
  State<_SimulacaoCorte> createState() => _SimulacaoCorteState();
}

class _SimulacaoCorteState extends State<_SimulacaoCorte> {
  ProdutoModel? _bitolaSelecionada;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fator = widget.formulario.fatorDobra;
    final dMm = _bitolaSelecionada?.diametro ?? 0.0;
    final dCm = dMm / 10.0;
    final desconto = fator * 2.0 * dCm; // 2d por dobra de 90°
    final refTotal = 100.0;
    final corteRef = (refTotal - desconto).clamp(0.0, refTotal);
    final dobrasCount = widget.formulario.itens.length <= 1
        ? 0
        : widget.formulario.itens
            .take(widget.formulario.itens.length - 1)
            .where((i) => i.angulo > 0)
            .length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.content_cut, size: 16, color: const Color(0xFF0369A1)),
            const SizedBox(width: 8),
            Text('SIMULAÇÃO DE COMPRIMENTO DE CORTE',
                style: AppCss.minimumBold.setColor(const Color(0xFF0369A1)).setSize(12)),
          ]),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Coluna esquerda: informações da forma
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _infoRow('Dobras detectadas', '$dobrasCount dobra${dobrasCount != 1 ? 's' : ''}'),
              const SizedBox(height: 8),
              _infoRow('Fator de dobra', fator.toStringAsFixed(2),
                  sub: '= Σ(ângulo ÷ 90°)'),
            ])),
            const SizedBox(width: 24),
            // Coluna direita: simulação com bitola
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Bitola para teste:', style: AppCss.minimumBold.setSize(12)),
              const SizedBox(height: 6),
              Builder(builder: (context) {
                final bitolas = BackendClient.produtos.data
                  ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
                if (bitolas.isEmpty) {
                  return Text('Nenhuma bitola cadastrada',
                      style: AppCss.minimumRegular.setColor(Colors.grey[400]!));
                }
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ProdutoModel>(
                      value: _bitolaSelecionada,
                      hint: Text('Selecionar...', style: AppCss.minimumRegular.setSize(12)),
                      isDense: true,
                      isExpanded: true,
                      style: AppCss.smallBold.setColor(const Color(0xFF0369A1)),
                      items: bitolas.map((b) => DropdownMenuItem(
                        value: b,
                        child: Text(
                          'ø${b.nome}mm${b.diametro > 0 ? '' : ' ⚠️'}',
                          style: AppCss.smallRegular.setSize(13),
                        ),
                      )).toList(),
                      onChanged: (val) => setState(() => _bitolaSelecionada = val),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
              if (dMm > 0) ...[
                _infoRow('Desconto por dobra (2×d)', '${(2.0 * dCm).toStringAsFixed(2)} cm'),
                const SizedBox(height: 4),
                _infoRow('Desconto total', '${desconto.toStringAsFixed(2)} cm',
                    color: const Color(0xFFF59E0B)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0369A1).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Icon(Icons.straighten, size: 14, color: const Color(0xFF0369A1)),
                    const SizedBox(width: 6),
                    Text('100cm  →  ', style: AppCss.minimumRegular.setSize(12)),
                    Text('${corteRef.toStringAsFixed(1)}cm de corte',
                        style: AppCss.minimumBold.setColor(const Color(0xFF0369A1)).setSize(13)),
                  ]),
                ),
              ],
            ])),
          ]),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {String? sub, Color? color}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppCss.minimumRegular.setColor(Colors.grey[600]!).setSize(11)),
      const SizedBox(height: 2),
      Text(value,
          style: AppCss.smallBold.setColor(color ?? const Color(0xFF0369A1)).setSize(14)),
      if (sub != null)
        Text(sub, style: AppCss.minimumRegular.setColor(Colors.grey[400]!).setSize(10)),
    ]);
  }
}


// -- Widget Badge Grupo de Simetria -------------------------------------------
class _GrupoBadge extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;
  const _GrupoBadge({required this.value, required this.onChanged});

  static const _grupos = ['', 'A', 'B', 'C', 'D'];

  static Color _cor(String g) {
    switch (g) {
      case 'A': return const Color(0xFF6366F1);
      case 'B': return const Color(0xFFF59E0B);
      case 'C': return const Color(0xFF10B981);
      case 'D': return const Color(0xFFEC4899);
      default:  return Colors.grey.shade400;
    }
  }

  void _ciclar() {
    final idx = _grupos.indexOf(value);
    onChanged(_grupos[(idx + 1) % _grupos.length]);
  }

  @override
  Widget build(BuildContext context) {
    final cor = _cor(value);
    return Tooltip(
      message: value.isEmpty
          ? 'Sem grupo - clique para vincular trechos'
          : 'Grupo ${value} - trechos vinculados compartilham comprimento',
      child: GestureDetector(
        onTap: _ciclar,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: value.isEmpty ? Colors.transparent : cor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: value.isEmpty ? Colors.grey.shade300 : cor,
              width: value.isEmpty ? 1.0 : 1.5,
            ),
          ),
          child: Center(
            child: Text(
              value.isEmpty ? '�' : value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: value.isEmpty ? FontWeight.normal : FontWeight.bold,
                color: cor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
