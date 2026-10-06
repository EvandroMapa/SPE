import 'package:acoplan/app/core/client/models/usuario_tipo_model.dart';
import 'package:acoplan/app/core/components/app_field.dart';
import 'package:acoplan/app/core/components/cadastro/cadastro_form.dart';
import 'package:acoplan/app/core/components/h.dart';
import 'package:acoplan/app/core/components/stream_out.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/modules/usuario/usuario_controller.dart';
import 'package:acoplan/app/modules/usuario/usuario_tipo_controller.dart';
import 'package:acoplan/app/modules/usuario/usuario_view_model.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Janela de cadastro/edição de usuário (moldura CadastroDialog, como no PCP).
/// Abra com `usuarioCtrl.init(usuario)` antes.
class UsuarioFormDialog extends StatefulWidget {
  const UsuarioFormDialog({super.key});

  @override
  State<UsuarioFormDialog> createState() => _UsuarioFormDialogState();
}

class _UsuarioFormDialogState extends State<UsuarioFormDialog> {
  bool _senhaOculta = true;

  @override
  Widget build(BuildContext context) {
    return StreamOut<UsuarioCreateModel>(
      stream: usuarioCtrl.formStream.listen,
      builder: (context, form) {
        return CadastroDialog(
          icon: Symbols.person,
          titulo: form.isEdit ? 'Editar usuário' : 'Novo usuário',
          onSalvar: () => usuarioCtrl.onConfirm(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppField(label: 'Nome', controller: form.nome),
              const H(14),
              AppField(
                label: 'E-mail (login)',
                hint: 'nome@empresa.com.br',
                controller: form.email,
                type: TextInputType.emailAddress,
              ),
              const H(14),
              AppField(
                label: form.isEdit ? 'Nova senha' : 'Senha',
                hint: form.isEdit ? 'Deixe em branco para manter a atual' : 'Mínimo de 6 caracteres',
                controller: form.senha,
                obscure: _senhaOculta,
                suffixIcon: _senhaOculta ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                onSuffix: () => setState(() => _senhaOculta = !_senhaOculta),
              ),
              const H(18),
              const CadastroSubtitulo('Perfil de acesso'),
              StreamOut<List<UsuarioTipoModel>>(
                stream: usuarioTipoCtrl.tiposStream.listen,
                builder: (context, tipos) => DropdownButtonFormField<String>(
                  initialValue: tipos.any((t) => t.id == form.usuarioTipoId) ? form.usuarioTipoId : null,
                  hint: Text('Selecione o perfil', style: AppCss.minimumRegular.setColor(AppColors.neutralMedium)),
                  dropdownColor: Colors.white,
                  items: [for (final t in tipos) DropdownMenuItem(value: t.id, child: Text(t.nome))],
                  onChanged: (val) => form.usuarioTipoId = val ?? '',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
