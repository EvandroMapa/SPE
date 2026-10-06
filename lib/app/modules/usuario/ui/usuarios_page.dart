import 'package:acoplan/app/app_controller.dart';
import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/usuario_model.dart';
import 'package:acoplan/app/core/components/app_scaffold.dart';
import 'package:acoplan/app/core/components/cadastro/cadastro_lista.dart';
import 'package:acoplan/app/core/components/empty_data.dart';
import 'package:acoplan/app/core/components/stream_out.dart';
import 'package:acoplan/app/core/dialogs/confirm_dialog.dart';
import 'package:acoplan/app/core/models/text_controller.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/usuario/ui/usuario_create_page.dart';
import 'package:acoplan/app/modules/usuario/usuario_controller.dart';
import 'package:flutter/material.dart';

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key});

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  final TextController _busca = TextController();

  @override
  void initState() {
    setWebTitle('Usuários');
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: AppColors.neutralLightest,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Usuários', style: AppCss.largeBold.setSize(18).setColor(Colors.white)),
        actions: [CadastroBotaoNovo('Novo usuário', onTap: () => _abrir(null))],
      ),
      body: StreamOut<List<UsuarioModel>>(
        stream: usuarioCtrl.usuariosStream.listen,
        builder: (context, todos) {
          final q = _busca.text.trim().toLowerCase();
          final usuarios = todos
              .where((u) => q.isEmpty || u.nome.toLowerCase().contains(q) || u.email.toLowerCase().contains(q))
              .toList()
            ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
          return Column(
            children: [
              CadastroBusca(
                hint: 'Buscar por nome ou e-mail',
                controller: _busca,
                contador: usuarios.length == 1 ? '1 usuário' : '${usuarios.length} usuários',
                onChanged: () => setState(() {}),
              ),
              Expanded(
                child: usuarios.isEmpty
                    ? const EmptyData(message: 'Nenhum usuário encontrado')
                    : CadastroLista(
                        onRefresh: () => BackendClient.usuarios.fetch(),
                        itens: usuarios.map(_linha).toList(),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _linha(UsuarioModel user) {
    final euMesmo = user.id == appCtrl.usuario?.id;
    final semLogin = user.authUserId.isEmpty;
    return CadastroLinha(
      onTap: () => _abrir(user),
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.neutralLightest, borderRadius: BorderRadius.circular(8)),
        child: Text(
          user.nome.trim().isNotEmpty ? user.nome.trim()[0].toUpperCase() : '?',
          style: AppCss.mediumBold.setSize(16).setColor(AppColors.neutralDark),
        ),
      ),
      titulo: user.nome.trim().isEmpty ? 'Sem nome' : user.nome.trim(),
      selos: [
        if (user.tipo != null) CadastroSelo(user.tipo!.nome),
        if (euMesmo) const CadastroSelo('Você', cor: AppColors.statusProduzindo),
        // Usuário sem login no Supabase Auth não consegue entrar
        if (semLogin) const CadastroSelo('Sem login', cor: AppColors.statusCritico),
      ],
      pares: [('E-mail', user.email)],
      trailing: CadastroMenu([
        CadastroAcao(Icons.edit_outlined, semLogin ? 'Definir login' : 'Editar usuário', () => _abrir(user)),
        if (!euMesmo)
          CadastroAcao(Icons.delete_outline, 'Excluir usuário', () => _excluir(user), destrutiva: true),
      ]),
    );
  }

  void _abrir(UsuarioModel? user) {
    usuarioCtrl.init(user);
    showDialog(context: context, builder: (_) => const UsuarioFormDialog());
  }

  Future<void> _excluir(UsuarioModel user) async {
    if (await showConfirmDialog('Excluir usuário', 'O usuário ${user.nome} perderá o acesso ao sistema.') &&
        mounted) {
      usuarioCtrl.onDelete(context, user);
    }
  }
}
