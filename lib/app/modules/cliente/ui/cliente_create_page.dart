import 'package:acoplan/app/core/client/models/cliente_model.dart';
import 'package:acoplan/app/core/components/app_field.dart';
import 'package:acoplan/app/core/components/app_multiple_registers.dart';
import 'package:acoplan/app/core/components/app_scaffold.dart';
import 'package:acoplan/app/core/components/done_button.dart';
import 'package:acoplan/app/core/components/stream_out.dart';
import 'package:acoplan/app/core/dialogs/confirm_dialog.dart';
import 'package:acoplan/app/core/enums/obra_status.dart';
import 'package:acoplan/app/core/models/text_controller.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/cliente/cliente_controller.dart';
import 'package:acoplan/app/modules/cliente/cliente_view_model.dart';
import 'package:acoplan/app/modules/endereco/endereco_create_page.dart';
import 'package:acoplan/app/modules/obra/ui/obra_create_page.dart';
import 'package:cpf_cnpj_validator/cnpj_validator.dart';
import 'package:cpf_cnpj_validator/cpf_validator.dart';
import 'package:flutter/material.dart';

enum _ClienteSection { dadosGerais, obras }

extension _ClienteSectionExt on _ClienteSection {
  String get label => switch (this) {
        _ClienteSection.dadosGerais => 'Dados Gerais',
        _ClienteSection.obras => 'Obras',
      };

  IconData get icon => switch (this) {
        _ClienteSection.dadosGerais => Icons.badge_outlined,
        _ClienteSection.obras => Icons.construction_outlined,
      };
}

class ClienteCreatePage extends StatefulWidget {
  final ClienteModel? cliente;
  final bool isFromOrder;
  const ClienteCreatePage({this.cliente, this.isFromOrder = false, super.key});

  @override
  State<ClienteCreatePage> createState() => _ClienteCreatePageState();
}

class _ClienteCreatePageState extends State<ClienteCreatePage> {
  _ClienteSection _selected = _ClienteSection.dadosGerais;
  String _initialSnapshot = '';

  String _snapshot(ClienteCreateModel form) =>
      '${form.nome.text}|${form.telefone.text}|${form.cpf.text}|${form.endereco?.name}|${form.obras.length}';

  @override
  void initState() {
    setWebTitle(widget.cliente != null ? 'Editar Cliente' : 'Novo Cliente');
    clienteCtrl.init(widget.cliente);
    _initialSnapshot = _snapshot(clienteCtrl.form);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      resizeAvoid: true,
      backgroundColor: AppColors.neutralLightest,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () async {
            final isDirty = _snapshot(clienteCtrl.form) != _initialSnapshot;
            if (isDirty) {
              final confirm = await showConfirmDialog(
                'Deseja realmente sair?',
                widget.cliente != null
                    ? 'A edição que realizou será perdida.'
                    : 'Os dados do cliente serão perdidos.',
              );
              if (confirm && context.mounted) {
                pop(context);
              }
            } else {
              pop(context);
            }
          },
          icon: Icon(Icons.arrow_back, color: AppColors.white),
        ),
        title: Text(
          '${clienteCtrl.form.isEdit ? 'Editar' : 'Adicionar'} Cliente',
          style: AppCss.largeBold.setColor(AppColors.white),
        ),
        actions: [
          IconLoadingButton(
            () async => await clienteCtrl.onConfirm(
              context,
              widget.cliente,
              widget.isFromOrder,
            ),
          ),
        ],
        backgroundColor: AppColors.primaryMain,
      ),
      body: StreamOut(
        stream: clienteCtrl.formStream.listen,
        builder: (_, form) => Row(
          children: [
            _buildSidebar(form),
            Expanded(
              child: _buildContent(form),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(ClienteCreateModel form) {
    return Container(
      width: 60,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(
          right: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        children: [
          _buildSidebarPreview(form),
          const SizedBox(height: 8),
          ..._ClienteSection.values.map((section) => _buildMenuItem(section)),
          const Spacer(),
          if (form.isEdit)
            _buildSidebarDelete(form),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSidebarPreview(ClienteCreateModel form) {
    return Tooltip(
      message: form.nome.text.isEmpty ? 'Novo Cliente' : form.nome.text,
      preferBelow: false,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 14),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primaryMain,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryMain.withValues(alpha: 0.5),
              blurRadius: 8,
            ),
          ],
        ),
        child: Center(
          child: Text(
            form.nome.text.isEmpty ? '?' : form.nome.text[0].toUpperCase(),
            style: AppCss.mediumBold.setColor(AppColors.white).setSize(14),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(_ClienteSection section) {
    final isSelected = _selected == section;
    return Tooltip(
      message: section.label,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: () => setState(() => _selected = section),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryMain.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(
                    color: AppColors.primaryMain.withValues(alpha: 0.20))
                : null,
          ),
          child: Icon(
            section.icon,
            size: 18,
            color: isSelected ? AppColors.primaryMain : Colors.grey[400],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarDelete(ClienteCreateModel form) {
    return Tooltip(
      message: 'Excluir ${form.nome.text}',
      preferBelow: false,
      child: InkWell(
        onTap: () => clienteCtrl.onDelete(context, widget.cliente!),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.delete_outline, size: 18, color: AppColors.error),
        ),
      ),
    );
  }

  Widget _buildContent(ClienteCreateModel form) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: KeyedSubtree(
        key: ValueKey(_selected),
        child: _buildSectionContent(form),
      ),
    );
  }

  Widget _buildSectionContent(ClienteCreateModel form) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Icon(_selected.icon, color: AppColors.primaryMain, size: 20),
            const SizedBox(width: 12),
            Text(_selected.label.toUpperCase(),
                style: AppCss.mediumBold.setSize(16).setLetterSpacing(1)),
          ],
        ),
        const SizedBox(height: 24),
        switch (_selected) {
          _ClienteSection.dadosGerais => _buildDadosGerais(form),
          _ClienteSection.obras => _buildObras(form),
        },
      ],
    );
  }

  Widget _buildDadosGerais(ClienteCreateModel form) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppField(
            label: 'Código',
            controllerObj:
                TextEditingController(text: form.codigo.toString()),
            isDisable: true,
          ),
          const SizedBox(height: 16),
          AppField(
            label: 'Nome',
            controller: form.nome,
            onChanged: (_) => clienteCtrl.formStream.update(),
          ),
          const SizedBox(height: 16),
          AppField(
            label: 'Telefone',
            hint: '(00) 00000-000',
            controller: form.telefone,
            onChanged: (_) => clienteCtrl.formStream.update(),
          ),
          const SizedBox(height: 16),
          AppField(
            label: 'CPF/CNPJ',
            required: false,
            controller: form.cpf,
            onChanged: (value) {
              if (value.length == 11 && CPFValidator.isValid(form.cpf.text)) {
                form.cpf.updateMask('000.000.000-00');
              } else if (value.length == 14 &&
                  CNPJValidator.isValid(form.cpf.text)) {
                form.cpf.updateMask('00.000.000/0000-00');
              } else {
                form.cpf.updateMask('00000000000000000');
              }
              clienteCtrl.formStream.update();
            },
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final endereco = await push(
                context,
                EnderecoCreatePage(endereco: form.endereco),
              );
              if (endereco != null) {
                form.endereco = endereco;
                clienteCtrl.formStream.update();
              }
            },
            child: IgnorePointer(
              child: AppField(
                label: 'Endereço',
                required: false,
                suffixIconSize: 12,
                suffixIcon: Icons.arrow_forward_ios,
                controller: TextController(
                  text: form.endereco?.name ?? '',
                ),
                onChanged: (_) => clienteCtrl.formStream.update(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObras(ClienteCreateModel form) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppMultipleRegisters<ObraModel>(
            icon: Icons.business_outlined,
            title: 'Gerenciar Obras',
            createPage: ObraCreatePage(endereco: form.endereco, obrasIrmas: form.obras),
            onEdit: (obraForm) async {
              ObraModel? obra = await push(
                context,
                ObraCreatePage(obra: obraForm, obrasIrmas: form.obras),
              );
              if (obra != null) {
                final i =
                    form.obras.map((e) => e.id).toList().indexOf(obraForm.id);
                if (obra.id != 'delete') {
                  form.obras[i] = obra;
                } else {
                  form.obras.removeAt(i);
                }
              }
              clienteCtrl.formStream.update();
            },
            onAdd: (e) {
              form.obras.add(e);
              clienteCtrl.formStream.update();
            },
            itens: form.obras,
            titleBuilder: (e) => Row(
              children: [
                Expanded(
                  child: Text(
                    e.descricao,
                    style: AppCss.minimumBold.setSize(14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: e.status.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: e.status.color.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    e.status.label.toUpperCase(),
                    style:
                        AppCss.minimumBold.setSize(10).setColor(e.status.color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
