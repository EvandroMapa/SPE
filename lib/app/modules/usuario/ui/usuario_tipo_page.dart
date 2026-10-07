import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/usuario_tipo_model.dart';
import 'package:acoplan/app/core/components/app_scaffold.dart';
import 'package:acoplan/app/core/components/cadastro/cadastro_form.dart';
import 'package:acoplan/app/core/components/cadastro/cadastro_lista.dart';
import 'package:acoplan/app/core/components/empty_data.dart';
import 'package:acoplan/app/core/components/stream_out.dart';
import 'package:acoplan/app/core/dialogs/confirm_dialog.dart';
import 'package:acoplan/app/core/enums/app_module.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/usuario/usuario_tipo_controller.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

class UsuarioTipoPage extends StatefulWidget {
  const UsuarioTipoPage({super.key});

  @override
  State<UsuarioTipoPage> createState() => _UsuarioTipoPageState();
}

class _UsuarioTipoPageState extends State<UsuarioTipoPage> {
  @override
  void initState() {
    setWebTitle('Perfis de acesso');
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: AppColors.neutralLightest,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Perfis de acesso', style: AppCss.largeBold.setSize(18).setColor(Colors.white)),
        actions: [CadastroBotaoNovo('Novo perfil', onTap: () => _abrir(null))],
      ),
      body: StreamOut<List<UsuarioTipoModel>>(
        stream: usuarioTipoCtrl.tiposStream.listen,
        builder: (context, tipos) {
          if (tipos.isEmpty) return const EmptyData(message: 'Nenhum perfil cadastrado');
          final ordenados = [...tipos]..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: CadastroLista(
              onRefresh: () => BackendClient.usuarioTipos.fetch(),
              itens: ordenados.map(_linha).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _linha(UsuarioTipoModel tipo) {
    final usuarios = BackendClient.usuarios.data.where((u) => u.usuarioTipoId == tipo.id).length;
    return CadastroLinha(
      onTap: () => _abrir(tipo),
      leading: const CadastroIcone(Symbols.badge),
      titulo: tipo.nome,
      pares: [
        ('Usuários', usuarios == 0 ? 'nenhum' : '$usuarios'),
        ('Criado em', DateFormat('dd/MM/yyyy').format(tipo.createdAt)),
      ],
      trailing: CadastroMenu([
        CadastroAcao(Icons.edit_outlined, 'Editar perfil', () => _abrir(tipo)),
        CadastroAcao(Icons.delete_outline, 'Excluir perfil', () => _excluir(tipo), destrutiva: true),
      ]),
    );
  }

  void _abrir(UsuarioTipoModel? tipo) {
    usuarioTipoCtrl.init(tipo);
    showDialog(
      context: context,
      builder: (dialogContext) => StreamOut<UsuarioTipoCreateModel>(
        stream: usuarioTipoCtrl.formStream.listen,
        builder: (_, form) => CadastroDialog(
          icon: Symbols.badge,
          titulo: form.isEdit ? 'Editar perfil' : 'Novo perfil',
          largura: 480,
          onSalvar: () => usuarioTipoCtrl.onConfirm(dialogContext),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: form.nome,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nome do perfil', hintText: 'Ex.: Detalhista'),
              ),
              const SizedBox(height: 18),
              const CadastroSubtitulo('Áreas que este perfil enxerga'),
              for (final area in AppArea.values)
                CadastroOpcao(
                  titulo: area.label,
                  explicacao: area.descricao,
                  valor: form.modulos == null || form.modulos!.contains(area.name),
                  onChanged: (v) {
                    final atual = form.modulos ?? AppArea.values.map((a) => a.name).toList();
                    form.modulos = v
                        ? {...atual, area.name}.toList()
                        : atual.where((n) => n != area.name).toList();
                    usuarioTipoCtrl.formStream.update();
                  },
                ),
              const SizedBox(height: 4),
              Text(
                'O perfil Administrador sempre enxerga tudo.',
                style: AppCss.minimumRegular.setSize(11.5).setColor(AppColors.neutralMedium),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _excluir(UsuarioTipoModel tipo) async {
    if (await showConfirmDialog('Excluir perfil', 'Deseja realmente excluir o perfil ${tipo.nome}?') && mounted) {
      usuarioTipoCtrl.onDelete(context, tipo);
    }
  }
}
