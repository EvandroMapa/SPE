import 'package:acoplan/app/core/client/models/bitola_model.dart';
import 'package:acoplan/app/core/components/app_field.dart';
import 'package:acoplan/app/core/components/cadastro/cadastro_form.dart';
import 'package:acoplan/app/core/components/h.dart';
import 'package:acoplan/app/core/components/stream_out.dart';
import 'package:acoplan/app/core/dialogs/confirm_dialog.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/bitola/bitola_controller.dart';
import 'package:acoplan/app/modules/bitola/bitola_view_model.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class BitolaCreatePage extends StatefulWidget {
  final BitolaModel? produto;
  const BitolaCreatePage({this.produto, super.key});

  @override
  State<BitolaCreatePage> createState() => _BitolaCreatePageState();
}

class _BitolaCreatePageState extends State<BitolaCreatePage> {
  String _initialSnapshot = '';

  String _snapshot(BitolaCreateModel form) =>
      '${form.nome.text}|${form.codigoFinanceiro.text}|${form.descricao.text}|${form.massaFinal.text}|${form.diametro.text}';

  @override
  void initState() {
    setWebTitle('Editar Bitola');
    bitolaCtrl.init(widget.produto);
    _initialSnapshot = _snapshot(bitolaCtrl.form);
    super.initState();
  }

  Future<void> _voltar() async {
    final isDirty = _snapshot(bitolaCtrl.form) != _initialSnapshot;
    if (!isDirty) {
      pop(context);
      return;
    }
    final confirm = await showConfirmDialog(
      'Deseja realmente sair?',
      widget.produto != null ? 'A edição que realizou será perdida.' : 'Os dados da bitola serão perdidos.',
    );
    if (confirm && mounted) pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return StreamOut<BitolaCreateModel>(
      stream: bitolaCtrl.formStream.listen,
      builder: (_, form) => CadastroFormPage(
        titulo: form.nome.text.trim().isEmpty ? 'Bitola' : form.nome.text.trim(),
        selo: form.diametro.text.trim().isEmpty ? null : 'ø ${form.diametro.text.trim()} mm',
        onVoltar: _voltar,
        onSalvar: () => bitolaCtrl.onConfirm(context, widget.produto),
        secoes: [
          CadastroSecao(
            icon: Symbols.stacks,
            titulo: 'Dados da bitola',
            apoio: 'Nome e diâmetro são fixos; a massa é usada no cálculo de peso.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CadastroLinhaCampos([
                  AppField(
                    label: 'Nome',
                    controller: form.nome,
                    onChanged: (_) => bitolaCtrl.formStream.update(),
                    isDisable: true,
                  ),
                  AppField(
                    label: 'Diâmetro',
                    controller: form.diametro,
                    type: TextInputType.number,
                    onChanged: (_) => bitolaCtrl.formStream.update(),
                    suffixText: 'mm',
                    isDisable: true,
                  ),
                ]),
                const H(14),
                CadastroLinhaCampos(
                  [
                    AppField(
                      label: 'Descrição',
                      hint: 'Ex.: VERGALHÃO 12,5 MM',
                      controller: form.descricao,
                      onChanged: (_) => bitolaCtrl.formStream.update(),
                    ),
                    AppField(
                      label: 'Massa nominal linear',
                      controller: form.massaFinal,
                      onChanged: (_) => bitolaCtrl.formStream.update(),
                      suffixText: 'kg/m',
                    ),
                  ],
                  flex: const [2, 1],
                ),
                const H(14),
                AppField(
                  label: 'Código financeiro',
                  controller: form.codigoFinanceiro,
                  onChanged: (_) => bitolaCtrl.formStream.update(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
