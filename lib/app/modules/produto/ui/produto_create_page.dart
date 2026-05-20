import 'package:acoplan/app/core/client/models/produto_model.dart';
import 'package:acoplan/app/core/components/app_field.dart';
import 'package:acoplan/app/core/components/app_scaffold.dart';
import 'package:acoplan/app/core/components/done_button.dart';
import 'package:acoplan/app/core/components/h.dart';
import 'package:acoplan/app/core/components/stream_out.dart';
import 'package:acoplan/app/core/dialogs/confirm_dialog.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/produto/produto_controller.dart';
import 'package:acoplan/app/modules/produto/produto_view_model.dart';
import 'package:flutter/material.dart';

class ProdutoCreatePage extends StatefulWidget {
  final ProdutoModel? produto;
  const ProdutoCreatePage({this.produto, super.key});

  @override
  State<ProdutoCreatePage> createState() => _ProdutoCreatePageState();
}

class _ProdutoCreatePageState extends State<ProdutoCreatePage> {
  String _initialSnapshot = '';

  String _snapshot(ProdutoCreateModel form) =>
      '${form.nome.text}|${form.codigoFinanceiro.text}|${form.descricao.text}|${form.massaFinal.text}|${form.diametro.text}';

  @override
  void initState() {
    setWebTitle(widget.produto != null ? 'Editar Bitola' : 'Nova Bitola');
    produtoCtrl.init(widget.produto);
    _initialSnapshot = _snapshot(produtoCtrl.form);
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
            final isDirty = _snapshot(produtoCtrl.form) != _initialSnapshot;
            if (isDirty) {
              final confirm = await showConfirmDialog(
                'Deseja realmente sair?',
                widget.produto != null
                    ? 'A edição que realizou será perdida.'
                    : 'Os dados da bitola serão perdidos.',
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
          '${produtoCtrl.form.isEdit ? 'Editar' : 'Adicionar'} Bitola',
          style: AppCss.largeBold.setColor(AppColors.white),
        ),
        actions: [
          IconLoadingButton(
            () async => await produtoCtrl.onConfirm(context, widget.produto),
          ),
        ],
        backgroundColor: AppColors.primaryMain,
      ),
      body: StreamOut(
        stream: produtoCtrl.formStream.listen,
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

  Widget _buildSidebar(ProdutoCreateModel form) {
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
          _buildMenuItem(),
          const Spacer(),
          if (form.isEdit) _buildSidebarDelete(form),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSidebarPreview(ProdutoCreateModel form) {
    return Tooltip(
      message: form.nome.text.isEmpty ? 'Nova Bitola' : form.nome.text,
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

  Widget _buildMenuItem() {
    return Tooltip(
      message: 'Dados da Bitola',
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 300),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primaryMain.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.primaryMain.withValues(alpha: 0.20),
          ),
        ),
        child: Icon(
          Icons.inventory_2_outlined,
          size: 18,
          color: AppColors.primaryMain,
        ),
      ),
    );
  }

  Widget _buildSidebarDelete(ProdutoCreateModel form) {
    return Tooltip(
      message: 'Excluir ${form.nome.text}',
      preferBelow: false,
      child: InkWell(
        onTap: () => produtoCtrl.onDelete(context, widget.produto!),
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

  Widget _buildContent(ProdutoCreateModel form) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: KeyedSubtree(
        key: const ValueKey('dados_bitola'),
        child: _buildDadosBitola(form),
      ),
    );
  }

  Widget _buildDadosBitola(ProdutoCreateModel form) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Icon(Icons.inventory_2_outlined,
                color: AppColors.primaryMain, size: 20),
            const SizedBox(width: 12),
            Text('DADOS DA BITOLA',
                style: AppCss.mediumBold.setSize(16).setLetterSpacing(1)),
          ],
        ),
        const SizedBox(height: 24),
        Container(
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
                label: 'Nome',
                controller: form.nome,
                onChanged: (_) => produtoCtrl.formStream.update(),
              ),
              const H(16),
              AppField(
                label: 'Código Financeiro',
                controller: form.codigoFinanceiro,
                onChanged: (_) => produtoCtrl.formStream.update(),
              ),
              const H(16),
              AppField(
                label: 'Descrição',
                controller: form.descricao,
                onChanged: (_) => produtoCtrl.formStream.update(),
              ),
              const H(16),
              AppField(
                label: 'MASSA NOMINAL LINEAR (Kg/Metro)',
                controller: form.massaFinal,
                onChanged: (_) => produtoCtrl.formStream.update(),
                suffixText: 'Kg',
              ),
              const H(16),
              AppField(
                label: 'Diâmetro',
                controller: form.diametro,
                type: TextInputType.number,
                onChanged: (_) => produtoCtrl.formStream.update(),
                suffixText: 'mm',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
