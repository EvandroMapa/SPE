import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/bitola_model.dart';
import 'package:acoplan/app/core/components/cadastro/cadastro_lista.dart';
import 'package:acoplan/app/core/components/empty_data.dart';
import 'package:acoplan/app/core/components/stream_out.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/bitola/bitola_controller.dart';
import 'package:acoplan/app/modules/bitola/bitola_view_model.dart';
import 'package:acoplan/app/modules/bitola/ui/bitola_create_page.dart';
import 'package:flutter/material.dart';

class BitolasPage extends StatefulWidget {
  const BitolasPage({super.key});

  @override
  State<BitolasPage> createState() => _BitolasPageState();
}

class _BitolasPageState extends State<BitolasPage> {
  @override
  void initState() {
    setWebTitle('Bitolas');
    BackendClient.bitolas.fetch();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamOut<List<BitolaModel>>(
      stream: BackendClient.bitolas.dataStream.listen,
      builder: (_, __) => StreamOut<BitolaUtils>(
        stream: bitolaCtrl.utilsStream.listen,
        builder: (_, utils) {
          final produtos =
              bitolaCtrl.getProdutosFiltered(utils.search.text, __).toList()
                ..sort((a, b) {
                  final cmp = a.sortIndex.compareTo(b.sortIndex);
                  if (cmp != 0) return cmp;
                  return a.nome.compareTo(b.nome);
                });
          return Container(
            color: AppColors.neutralLightest,
            child: Column(
              children: [
                CadastroBusca(
                  hint: 'Buscar bitola',
                  controller: utils.search,
                  contador: produtos.length == 1 ? '1 bitola' : '${produtos.length} bitolas',
                  onChanged: () => bitolaCtrl.utilsStream.update(),
                ),
                Expanded(
                  child: produtos.isEmpty
                      ? const EmptyData(message: 'Nenhuma bitola encontrada')
                      // A ordem é definida arrastando pela alça
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.only(bottom: 32),
                          buildDefaultDragHandles: false,
                          itemCount: produtos.length,
                          onReorder: (oldIndex, newIndex) {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final item = produtos.removeAt(oldIndex);
                            produtos.insert(newIndex, item);
                            bitolaCtrl.onReorder(produtos);
                          },
                          itemBuilder: (_, i) => _itemProdutoWidget(produtos[i], i),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _itemProdutoWidget(BitolaModel produto, int index) {
    String num(double v) => v.toString().replaceAll(RegExp(r'\.0$'), '').replaceAll('.', ',');
    return KeyedSubtree(
      key: ValueKey(produto.id),
      child: CadastroLinha(
        onTap: () => push(context, BitolaCreatePage(produto: produto)),
        leading: ReorderableDragStartListener(
          index: index,
          child: Tooltip(
            message: 'Arraste para mudar a ordem',
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.neutralLightest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.drag_indicator, size: 20, color: AppColors.neutralMedium),
            ),
          ),
        ),
        titulo: produto.nome.trim(),
        selos: [if (produto.diametro > 0) CadastroSelo('ø ${num(produto.diametro)} mm')],
        pares: [
          ('Descrição', produto.descricao),
          ('Massa', produto.massaFinal > 0 ? '${num(produto.massaFinal)} kg/m' : ''),
          ('Cód. financeiro', produto.codigoFinanceiro),
        ],
      ),
    );
  }
}
