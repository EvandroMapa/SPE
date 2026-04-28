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
                final filtered = formas.where((u) {
                  final query = _filter.toLowerCase();
                  return u.codigo.toLowerCase().contains(query) ||
                      u.descricao.toLowerCase().contains(query);
                }).toList();

                // Ordenação numérica: converte para int para comparar corretamente (ex: 1, 2, 10)
                filtered.sort((a, b) {
                  final n1 = int.tryParse(a.codigo) ?? 0;
                  final n2 = int.tryParse(b.codigo) ?? 0;
                  return n1.compareTo(n2);
                });

                if (filtered.isEmpty) {
                  return const EmptyData(message: 'Nenhuma forma encontrada');
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final forma = filtered[index];
                    return ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primaryMain.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.architecture, color: AppColors.primaryMain),
                      ),
                      title: Text(forma.codigo, style: AppCss.smallBold),
                      subtitle: Text(forma.descricao, style: AppCss.minimumRegular),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _openCreateForma(forma),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                            onPressed: () => _confirmDelete(forma),
                          ),
                        ],
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
          TextButton(onPressed: () => pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              pop(context);
              formaCtrl.excluir(context, forma);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
