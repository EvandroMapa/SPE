import 'package:acoplan/app/core/client/models/cliente_model.dart';
import 'package:acoplan/app/core/components/app_drop_down.dart';
import 'package:acoplan/app/core/components/app_field.dart';
import 'package:acoplan/app/core/components/app_scaffold.dart';
import 'package:acoplan/app/core/components/done_button.dart';
import 'package:acoplan/app/core/components/h.dart';
import 'package:acoplan/app/core/components/stream_out.dart';
import 'package:acoplan/app/core/dialogs/confirm_dialog.dart';
import 'package:acoplan/app/core/enums/obra_status.dart';
import 'package:acoplan/app/core/models/endereco_model.dart';
import 'package:acoplan/app/core/models/text_controller.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/endereco/endereco_create_page.dart';
import 'package:acoplan/app/modules/obra/obra_controller.dart';
import 'package:acoplan/app/modules/obra/obra_view_model.dart';
import 'package:flutter/material.dart';

class ObraCreatePage extends StatefulWidget {
  final ObraModel? obra;
  final EnderecoModel? endereco;
  const ObraCreatePage({this.obra, this.endereco, super.key});

  @override
  State<ObraCreatePage> createState() => _ObraCreatePageState();
}

class _ObraCreatePageState extends State<ObraCreatePage> {
  String _initialSnapshot = '';

  String _snapshot(ObraCreateModel form) =>
      '${form.descricao.text}|${form.telefoneFixo.text}|${form.status?.index}|${form.endereco?.name}';

  @override
  void initState() {
    obraCtrl.init(widget.obra, widget.endereco);
    _initialSnapshot = _snapshot(obraCtrl.form);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      resizeAvoid: true,
      backgroundColor: const Color(0xFFCBD5E1),
      appBar: AppBar(
        leading: IconButton(
          onPressed: () async {
            final isDirty = _snapshot(obraCtrl.form) != _initialSnapshot;
            if (isDirty) {
              if (await showConfirmDialog(
                'Deseja realmente sair?',
                'Os dados da obra serão perdidos.',
              )) {
                pop(context);
              }
            } else {
              pop(context);
            }
          },
          icon: Icon(Icons.arrow_back, color: AppColors.white),
        ),
        title: Text(
          '${obraCtrl.form.isEdit ? 'Editar' : 'Adicionar'} Obra',
          style: AppCss.largeBold.setColor(AppColors.white),
        ),
        actions: [
          IconLoadingButton(() async => await obraCtrl.onConfirm(context)),
        ],
        backgroundColor: AppColors.primaryMain,
      ),
      body: StreamOut(
        stream: obraCtrl.formStream.listen,
        builder: (_, form) => body(form),
      ),
    );
  }

  Widget body(ObraCreateModel form) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[400]!, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.construction_outlined,
                      color: AppColors.primaryMain),
                  const SizedBox(width: 12),
                  Text('DADOS DA OBRA', style: AppCss.mediumBold.setSize(16)),
                ],
              ),
              const SizedBox(height: 24),
              AppField(
                label: 'Descrição',
                controller: form.descricao,
                onChanged: (_) => obraCtrl.formStream.update(),
              ),
              const H(16),
              AppField(
                label: 'Telefone Fixo',
                required: false,
                controller: form.telefoneFixo,
                onChanged: (_) => obraCtrl.formStream.update(),
              ),
              const H(16),
              AppDropDown<ObraStatus?>(
                label: 'Status',
                item: form.status,
                itens: ObraStatus.values,
                itemLabel: (e) => e?.label ?? 'Selecione um status',
                onSelect: (e) {
                  form.status = e;
                  obraCtrl.formStream.update();
                },
              ),
              const H(16),
              InkWell(
                onTap: () async {
                  final endereco = await push(
                    context,
                    EnderecoCreatePage(endereco: form.endereco),
                  );
                  if (endereco != null) {
                    form.endereco = endereco;
                    obraCtrl.formStream.update();
                  }
                },
                child: IgnorePointer(
                  child: AppField(
                    label: 'Endereço',
                    required: false,
                    suffixIconSize: 12,
                    suffixIcon: Icons.arrow_forward_ios,
                    controller: TextController(
                      text: form.endereco?.name.toString() ?? '',
                    ),
                    onChanged: (_) => obraCtrl.formStream.update(),
                  ),
                ),
              ),
            ],
          ),
        ),
        const H(24),
        if (form.isEdit) _buildDeleteButton(),
      ],
    );
  }

  Widget _buildDeleteButton() {
    return InkWell(
      onTap: () async {
        if (!await showConfirmDialog(
          'Excluir obra?',
          'Todos os dados da obra serão apagados do sistema',
        )) {
          return;
        }
        Navigator.pop(context, obraDeleteObj);
      },
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withAlpha(100), width: 1.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: AppColors.error),
            const SizedBox(width: 8),
            Text(
              'EXCLUIR OBRA',
              style: AppCss.mediumBold.setColor(AppColors.error).setSize(14),
            ),
          ],
        ),
      ),
    );
  }
}
