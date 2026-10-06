import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/forma_model.dart';
import 'package:acoplan/app/core/components/cadastro/cadastro_lista.dart';
import 'package:acoplan/app/core/components/empty_data.dart';
import 'package:acoplan/app/core/components/stream_out.dart';
import 'package:acoplan/app/core/models/text_controller.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/base/base_controller.dart';
import 'package:acoplan/app/modules/forma/forma_controller.dart';
import 'package:acoplan/app/modules/forma/ui/forma_create_page.dart';
import 'package:acoplan/app/modules/forma/ui/forma_preview_widget.dart';
import 'package:flutter/material.dart';

class FormasPage extends StatefulWidget {
  const FormasPage({super.key});

  @override
  State<FormasPage> createState() => _FormasPageState();
}

class _FormasPageState extends State<FormasPage> {
  final TextController _busca = TextController();

  @override
  void initState() {
    super.initState();
    setWebTitle('Formas');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      baseCtrl.appBarActionsStream.add([
        CadastroBotaoNovo('Nova forma', onTap: () => _abrir(null)),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamOut<List<FormaModel>>(
      stream: formaCtrl.formasStream.listen,
      builder: (context, todas) {
        final q = _busca.text.trim().toLowerCase();
        final formas = todas
            .where((f) => q.isEmpty || f.codigo.toLowerCase().contains(q) || f.descricao.toLowerCase().contains(q))
            .toList()
          ..sort((a, b) => (int.tryParse(a.codigo) ?? 0).compareTo(int.tryParse(b.codigo) ?? 0));

        return Container(
          color: AppColors.neutralLightest,
          child: Column(
            children: [
              CadastroBusca(
                hint: 'Buscar por código ou descrição',
                controller: _busca,
                contador: formas.length == 1 ? '1 forma' : '${formas.length} formas',
                onChanged: () => setState(() {}),
              ),
              Expanded(
                child: formas.isEmpty
                    ? EmptyData(message: q.isEmpty ? 'Nenhuma forma cadastrada' : 'Nenhuma forma encontrada')
                    : CadastroLista(
                        onRefresh: () => BackendClient.formas.fetch(),
                        itens: formas.map(_linha).toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _linha(FormaModel forma) {
    final dobras = forma.itens.length <= 1
        ? 0
        : forma.itens.take(forma.itens.length - 1).where((i) => i.angulo > 0).length;
    return CadastroLinha(
      onTap: () => _abrir(forma),
      // Miniatura do desenho: reconhecer a forma de relance
      leading: Container(
        width: 72,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.neutralLightest,
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: forma.itens.isEmpty
            ? Icon(Icons.polyline_outlined, size: 20, color: AppColors.neutralMedium)
            : IgnorePointer(
                child: FormaPreviewWidget(
                  itens: forma.itens,
                  height: 44,
                  mostrarLegenda: false,
                  mostrarVertices: false,
                  rotacaoExterna: forma.rotacao,
                ),
              ),
      ),
      titulo: 'Forma ${forma.codigo}',
      selos: [
        CadastroSelo(
          dobras == 0 ? 'Reta' : '$dobras dobra${dobras == 1 ? '' : 's'}',
          cor: dobras == 0 ? null : AppColors.statusAtencao,
        ),
      ],
      pares: [
        ('Descrição', forma.descricao),
        ('Trechos', '${forma.itens.length}'),
        ('Fator de dobra', forma.fatorDobra > 0 ? forma.fatorDobra.toStringAsFixed(2).replaceAll('.', ',') : ''),
        ('Desconto', forma.descontoDobra > 0 ? '${forma.descontoDobra.toStringAsFixed(1).replaceAll('.', ',')} × ø' : ''),
      ],
      trailing: CadastroMenu([
        CadastroAcao(Icons.edit_outlined, 'Editar forma', () => _abrir(forma)),
        CadastroAcao(Icons.content_copy_outlined, 'Duplicar', () => _duplicar(forma)),
        CadastroAcao(Icons.delete_outline, 'Excluir forma', () => _excluir(forma), destrutiva: true),
      ]),
    );
  }

  void _abrir(FormaModel? forma) {
    formaCtrl.inicializar(forma);
    push(context, FormaCreatePage());
  }

  ButtonStyle get _estiloCancelar => OutlinedButton.styleFrom(
        foregroundColor: AppColors.neutralDark,
        side: BorderSide(color: AppColors.neutralLight),
      );

  void _excluir(FormaModel forma) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Excluir forma', style: AppCss.largeBold),
        content: Text('Deseja realmente excluir a forma ${forma.codigo}?'),
        actions: [
          OutlinedButton(style: _estiloCancelar, onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(dialogContext);
              formaCtrl.excluir(context, forma);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  void _duplicar(FormaModel forma) {
    final maior = formaCtrl.formas.fold<int>(0, (m, f) {
      final cod = int.tryParse(f.codigo) ?? 0;
      return cod > m ? cod : m;
    });
    final ctrl = TextEditingController(text: '${maior + 1}');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Duplicar forma ${forma.codigo}', style: AppCss.largeBold),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Código da cópia', prefixIcon: Icon(Icons.tag)),
        ),
        actions: [
          OutlinedButton(style: _estiloCancelar, onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryMain),
            onPressed: () {
              Navigator.pop(dialogContext);
              formaCtrl.duplicar(context, forma, ctrl.text);
            },
            child: const Text('Duplicar'),
          ),
        ],
      ),
    );
  }
}
