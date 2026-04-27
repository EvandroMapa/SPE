import 'package:acoplan/app/core/components/app_scaffold.dart';
import 'package:acoplan/app/core/components/empty_data.dart';
import 'package:acoplan/app/core/components/stream_out.dart';
import 'package:acoplan/app/core/client/models/usuario_tipo_model.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/usuario/usuario_tipo_controller.dart';
import 'package:flutter/material.dart';

class UsuarioTipoPage extends StatefulWidget {
  const UsuarioTipoPage({super.key});

  @override
  State<UsuarioTipoPage> createState() => _UsuarioTipoPageState();
}

class _UsuarioTipoPageState extends State<UsuarioTipoPage> {
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white, size: 20),
        backgroundColor: AppColors.primaryMain,
        title: Text('Perfis de Acesso', style: AppCss.mediumBold.setColor(Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _openCreateTipo(null),
          ),
        ],
      ),
      body: StreamOut<List<UsuarioTipoModel>>(
        stream: usuarioTipoCtrl.tiposStream.listen,
        builder: (context, tipos) {
          if (tipos.isEmpty) {
            return const EmptyData(message: 'Nenhum perfil encontrado');
          }

          return ListView.separated(
            itemCount: tipos.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final tipo = tipos[index];
              return ListTile(
                title: Text(tipo.nome, style: AppCss.smallBold),
                subtitle: Text(
                  'Criado em: ${tipo.createdAt.day}/${tipo.createdAt.month}/${tipo.createdAt.year}',
                  style: AppCss.minimumRegular,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _openCreateTipo(tipo),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                      onPressed: () => _confirmDelete(tipo),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openCreateTipo(UsuarioTipoModel? tipo) {
    usuarioTipoCtrl.init(tipo);
    showDialog(
      context: context,
      builder: (context) => _UsuarioTipoFormDialog(),
    );
  }

  void _confirmDelete(UsuarioTipoModel tipo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Perfil'),
        content: Text('Deseja realmente excluir o perfil ${tipo.nome}?'),
        actions: [
          TextButton(onPressed: () => pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              pop(context);
              usuarioTipoCtrl.onDelete(context, tipo);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _UsuarioTipoFormDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamOut<UsuarioTipoCreateModel>(
      stream: usuarioTipoCtrl.formStream.listen,
      builder: (context, form) {
        return AlertDialog(
          title: Text(form.isEdit ? 'Editar Perfil' : 'Novo Perfil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: form.nome,
                decoration: const InputDecoration(labelText: 'Nome do Perfil'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => pop(context), child: const Text('Cancelar')),
            TextButton(onPressed: () => usuarioTipoCtrl.onConfirm(context), child: const Text('Salvar')),
          ],
        );
      },
    );
  }
}
