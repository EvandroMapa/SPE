import 'package:acoplan/app/core/components/app_scaffold.dart';
import 'package:acoplan/app/core/components/empty_data.dart';
import 'package:acoplan/app/core/components/stream_out.dart';
import 'package:acoplan/app/core/client/models/usuario_model.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/usuario/usuario_controller.dart';
import 'package:acoplan/app/modules/usuario/ui/usuario_create_page.dart';
import 'package:flutter/material.dart';

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key});

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white, size: 20),
        backgroundColor: AppColors.primaryMain,
        title: Text('Usuários', style: AppCss.mediumBold.setColor(Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _openCreateUser(null),
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
                hintText: 'Buscar usuário...',
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
            child: StreamOut<List<UsuarioModel>>(
              stream: usuarioCtrl.usuariosStream.listen,
              builder: (context, usuarios) {
                final filtered = usuarios.where((u) {
                  final query = _filter.toLowerCase();
                  return u.nome.toLowerCase().contains(query) ||
                      u.email.toLowerCase().contains(query);
                }).toList();

                if (filtered.isEmpty) {
                  return const EmptyData(message: 'Nenhum usuário encontrado');
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = filtered[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryMain.withValues(alpha: 0.1),
                        child: Text(
                          user.nome.isNotEmpty ? user.nome[0].toUpperCase() : '?',
                          style: AppCss.smallBold.setColor(AppColors.primaryMain),
                        ),
                      ),
                      title: Text(user.nome, style: AppCss.smallBold),
                      subtitle: Text(user.email, style: AppCss.minimumRegular),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _openCreateUser(user),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                            onPressed: () => _confirmDelete(user),
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

  void _openCreateUser(UsuarioModel? user) {
    usuarioCtrl.init(user);
    push(context, const UsuarioCreatePage());
  }

  void _confirmDelete(UsuarioModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Usuário'),
        content: Text('Deseja realmente excluir o usuário ${user.nome}?'),
        actions: [
          TextButton(onPressed: () => pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              pop(context);
              usuarioCtrl.onDelete(context, user);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
