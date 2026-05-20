import 'package:acoplan/app/core/components/app_scaffold.dart';
import 'package:acoplan/app/core/components/empty_data.dart';
import 'package:acoplan/app/core/components/stream_out.dart';
import 'package:acoplan/app/core/client/models/forma_model.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/forma/forma_controller.dart';
import 'package:acoplan/app/modules/forma/ui/forma_create_page.dart';
import 'package:flutter/material.dart';

class FormasPage extends StatefulWidget {
  const FormasPage({super.key});

  @override
  State<FormasPage> createState() => _FormasPageState();
}

class _FormasPageState extends State<FormasPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white, size: 20),
        backgroundColor: AppColors.primaryMain,
        title: Text('Formas', style: AppCss.mediumBold.setColor(Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _openCreateForma(null),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _filter = val),
              decoration: InputDecoration(
                hintText: 'Buscar forma...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _filter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _filter = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: StreamOut<List<FormaModel>>(
              stream: formaCtrl.formasStream.listen,
              builder: (context, formas) {
                final filtered = formas.where((f) {
                  final query = _filter.toLowerCase();
                  return f.codigo.toLowerCase().contains(query) ||
                      f.descricao.toLowerCase().contains(query);
                }).toList();

                filtered.sort((a, b) {
                  final n1 = int.tryParse(a.codigo) ?? 0;
                  final n2 = int.tryParse(b.codigo) ?? 0;
                  return n1.compareTo(n2);
                });

                if (filtered.isEmpty) {
                  return const EmptyData(message: 'Nenhuma forma encontrada');
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final forma = filtered[index];
                    final temDobras = forma.fatorDobra > 0;
                    final dobrasCount = forma.itens.length <= 1
                        ? 0
                        : forma.itens
                            .take(forma.itens.length - 1)
                            .where((i) => i.angulo > 0)
                            .length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[200]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryMain.withValues(alpha: 0.15),
                                AppColors.primaryMain.withValues(alpha: 0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              forma.codigo,
                              style: AppCss.smallBold
                                  .setColor(AppColors.primaryMain)
                                  .setSize(15),
                            ),
                          ),
                        ),
                        title: Text(
                          'Forma ${forma.codigo}',
                          style: AppCss.smallBold.setSize(14),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              forma.descricao.isEmpty ? 'Sem descrição' : forma.descricao,
                              style: AppCss.minimumRegular.setSize(11),
                            ),
                            const SizedBox(height: 3),
                            Row(children: [
                              Icon(
                                Icons.content_cut,
                                size: 12,
                                color: temDobras
                                    ? const Color(0xFFF59E0B)
                                    : Colors.grey[400],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                temDobras
                                    ? 'Fator dobra: ${forma.fatorDobra.toStringAsFixed(2)}  •  $dobrasCount dobra(s)'
                                    : 'Sem dobras',
                                style: AppCss.minimumBold
                                    .setColor(temDobras
                                        ? const Color(0xFFF59E0B)
                                        : Colors.grey[400]!)
                                    .setSize(11),
                              ),
                            ]),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tooltip(
                              message: 'Editar',
                              child: InkWell(
                                onTap: () => _openCreateForma(forma),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryMain
                                        .withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.edit_outlined,
                                      size: 18, color: AppColors.primaryMain),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: 'Excluir',
                              child: InkWell(
                                onTap: () => _confirmDelete(forma),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.delete_outline,
                                      size: 18, color: AppColors.error),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openCreateForma(FormaModel? forma) {
    formaCtrl.inicializar(forma);
    push(context, FormaCreatePage());
  }

  void _confirmDelete(FormaModel forma) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Forma'),
        content: Text('Deseja realmente excluir a forma ${forma.codigo}?'),
        actions: [
          TextButton(
            onPressed: () => pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              pop(context);
              formaCtrl.excluir(context, forma);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
