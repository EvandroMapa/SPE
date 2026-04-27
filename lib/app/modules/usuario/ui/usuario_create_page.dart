import 'package:acoplan/app/core/components/app_scaffold.dart';
import 'package:acoplan/app/core/components/h.dart';
import 'package:acoplan/app/core/components/stream_out.dart';
import 'package:acoplan/app/core/client/models/usuario_tipo_model.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/modules/usuario/usuario_controller.dart';
import 'package:acoplan/app/modules/usuario/usuario_tipo_controller.dart';
import 'package:acoplan/app/modules/usuario/usuario_view_model.dart';
import 'package:flutter/material.dart';

class UsuarioCreatePage extends StatelessWidget {
  const UsuarioCreatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamOut<UsuarioCreateModel>(
      stream: usuarioCtrl.formStream.listen,
      builder: (context, form) {
        return AppScaffold(
          appBar: AppBar(
            iconTheme: const IconThemeData(color: Colors.white, size: 20),
            backgroundColor: AppColors.primaryMain,
            title: Text(
              form.isEdit ? 'Editar Usuário' : 'Novo Usuário',
              style: AppCss.mediumBold.setColor(Colors.white),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildField('Nome', form.nome, Icons.person_outline),
                const H(16),
                _buildField('E-mail', form.email, Icons.email_outlined),
                const H(16),
                _buildField('Senha', form.senha, Icons.lock_outline, obscure: true),
                const H(24),
                Text('Perfil de Acesso', style: AppCss.smallBold),
                const H(8),
                StreamOut<List<UsuarioTipoModel>>(
                  stream: usuarioTipoCtrl.tiposStream.listen,
                  builder: (context, tipos) {
                    return DropdownButtonFormField<String>(
                      initialValue: form.usuarioTipoId.isEmpty ? null : form.usuarioTipoId,
                      items: tipos.map((t) => DropdownMenuItem(value: t.id, child: Text(t.nome))).toList(),
                      onChanged: (val) => form.usuarioTipoId = val ?? '',
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                    );
                  },
                ),
                const H(40),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => usuarioCtrl.onConfirm(context),
                    child: const Text('SALVAR'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildField(String label, dynamic controller, IconData icon, {bool obscure = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppCss.smallBold),
        const H(8),
        TextField(
          controller: controller.controller,
          obscureText: obscure,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20),
          ),
        ),
      ],
    );
  }
}
