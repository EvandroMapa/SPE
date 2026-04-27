import 'package:acoplan/app/core/components/app_scaffold.dart';
import 'package:acoplan/app/core/components/empty_data.dart';
import 'package:acoplan/app/core/components/stream_out.dart';
import 'package:acoplan/app/core/client/models/cliente_model.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/cliente/cliente_controller.dart';
import 'package:acoplan/app/modules/cliente/ui/cliente_create_page.dart';
import 'package:flutter/material.dart';

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white, size: 20),
        backgroundColor: AppColors.primaryMain,
        title: Text('Clientes', style: AppCss.mediumBold.setColor(Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _openForm(null),
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
                hintText: 'Buscar cliente...',
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: StreamOut<List<ClienteModel>>(
              stream: clienteCtrl.clientesStream.listen,
              builder: (context, clientes) {
                final filtered = clientes.where((c) {
                  final query = _filter.toLowerCase();
                  return c.nome.toLowerCase().contains(query) ||
                      c.cnpj.contains(query);
                }).toList();

                if (filtered.isEmpty) {
                  return const EmptyData(message: 'Nenhum cliente encontrado');
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final cliente = filtered[index];
                    return ListTile(
                      title: Text(cliente.nome, style: AppCss.smallBold),
                      subtitle: Text(
                        'CNPJ: ${cliente.cnpj} | Tel: ${cliente.telefone} | Obras: ${cliente.obras.length}',
                        style: AppCss.minimumRegular,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _openForm(cliente),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                            onPressed: () => _confirmDelete(cliente),
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

  void _openForm(ClienteModel? cliente) async {
    await push(context, ClienteCreatePage(cliente: cliente));
  }

  void _confirmDelete(ClienteModel cliente) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Cliente'),
        content: Text('Deseja realmente excluir o cliente ${cliente.nome}?'),
        actions: [
          TextButton(onPressed: () => pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              pop(context);
              clienteCtrl.onDelete(context, cliente);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
