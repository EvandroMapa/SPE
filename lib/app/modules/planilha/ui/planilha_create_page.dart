import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/cliente_model.dart';
import 'package:acoplan/app/core/client/models/forma_model.dart';
import 'package:acoplan/app/core/client/models/planilha_model.dart';
import 'package:acoplan/app/core/client/models/produto_model.dart';
import 'package:acoplan/app/core/components/app_drop_down.dart';
import 'package:acoplan/app/core/components/app_field.dart';
import 'package:acoplan/app/core/components/app_scaffold.dart';
import 'package:acoplan/app/core/components/stream_out.dart';
import 'package:acoplan/app/core/dialogs/confirm_dialog.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/core/models/text_controller.dart';
import 'package:acoplan/app/modules/planilha/planilha_controller.dart';
import 'package:acoplan/app/modules/planilha/planilha_view_model.dart';
import 'package:acoplan/app/modules/forma/ui/forma_preview_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _Sec { dadosGerais, elementos }

class PlanilhaCreatePage extends StatefulWidget {
  final PlanilhaModel? planilha;
  const PlanilhaCreatePage({this.planilha, super.key});
  @override
  State<PlanilhaCreatePage> createState() => _PlanilhaCreatePageState();
}

class _PlanilhaCreatePageState extends State<PlanilhaCreatePage> {
  _Sec _sel = _Sec.dadosGerais;
  int _elemIdx = -1;

  // IDs reais do banco para cada elemento (indexado pela posição na lista)
  final Map<int, String> _elementoDbIds = {};

  // Posição selecionada (para mostrar desenho da forma)
  FormaModel? _formaSelecionada;
  PosicaoCreateModel? _posicaoSelecionada;

  // Controllers dos comprimentos dos trechos
  List<TextEditingController> _compCtrls = [];
  List<FocusNode> _compFns = [];

  void _atualizarCompCtrls(FormaModel? forma, {PosicaoCreateModel? posicao}) {
    for (final c in _compCtrls) { c.dispose(); }
    for (final f in _compFns) { f.dispose(); }
    _posicaoSelecionada = posicao;
    if (forma == null) { _compCtrls = []; _compFns = []; return; }
    _compCtrls = List.generate(forma.itens.length, (i) {
      final trecho = forma.itens[i].trecho;
      final valor = posicao?.comprimentos[trecho];
      return TextEditingController(text: valor != null ? valor.toString() : '');
    });
    _compFns = List.generate(forma.itens.length, (_) => FocusNode());
  }

  // ── Cálculos de peso ──────────────────────────────────────
  /// Peso unitário de uma posição = soma comprimentos (cm→m) × massa linear (kg/m)
  double _pesoUnitPosicao(PosicaoCreateModel pos) {
    if (pos.bitolaSelecionada == null) return 0;
    final massaLinear = pos.bitolaSelecionada!.massaFinal; // kg/m
    final somaCm = pos.comprimentos.values.fold<int>(0, (s, v) => s + v);
    return (somaCm / 100.0) * massaLinear;
  }

  /// Peso total de uma posição = peso unitário × quantidade
  double _pesoTotalPosicao(PosicaoCreateModel pos) {
    final qtde = int.tryParse(pos.qtde.text) ?? 1;
    return _pesoUnitPosicao(pos) * qtde;
  }

  /// Peso unitário de um elemento = somatório dos pesos totais das posições
  double _pesoUnitElemento(ElementoCreateModel elem) {
    return elem.posicoes.fold<double>(0, (s, p) => s + _pesoTotalPosicao(p));
  }

  /// Peso total de um elemento = peso unitário × quantidade do elemento
  double _pesoTotalElemento(ElementoCreateModel elem) {
    final qtde = int.tryParse(elem.quantidade.text) ?? 1;
    return _pesoUnitElemento(elem) * qtde;
  }

  String _formatPeso(double v) => v > 0 ? v.toStringAsFixed(2) : '-';

  /// Peso total da planilha = soma dos pesos totais de todos os elementos
  double _pesoTotalPlanilha(PlanilhaCreateModel form) {
    return form.elementos.fold<double>(0, (s, e) => s + _pesoTotalElemento(e));
  }

  /// Atualiza peso total da planilha no banco
  Future<void> _atualizarPesoTotal(PlanilhaCreateModel form) async {
    final peso = _pesoTotalPlanilha(form);
    await planilhaCtrl.atualizarPesoTotal(peso);
  }

  // Elemento form
  final TextController _eNome = TextController();
  final TextController _eQtde = TextController();

  // Posição form
  final TextController _pNum = TextController();
  final TextController _pQtde = TextController();
  final _bitolaCtrl = TextEditingController();
  final _formaCtrl = TextEditingController();
  final _fnBitola = FocusNode();
  final _fnForma = FocusNode();
  ProdutoModel? _pBitola;
  FormaModel? _pForma;


  @override
  void initState() {
    setWebTitle(widget.planilha != null ? 'Editar Planilha' : 'Nova Planilha');
    planilhaCtrl.init(widget.planilha);
    // Preencher IDs do banco para elementos existentes
    if (widget.planilha != null) {
      for (int i = 0; i < planilhaCtrl.form.elementos.length; i++) {
        _elementoDbIds[i] = planilhaCtrl.form.elementos[i].id;
      }
    }
    super.initState();
  }

  @override
  void dispose() {
    _fnBitola.dispose();
    _fnForma.dispose();
    _bitolaCtrl.dispose();
    _formaCtrl.dispose();
    for (final c in _compCtrls) { c.dispose(); }
    for (final f in _compFns) { f.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      resizeAvoid: true,
      backgroundColor: AppColors.neutralLightest,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => pop(context),
          icon: Icon(Icons.arrow_back, color: AppColors.white),
        ),
        title: StreamOut(
          stream: planilhaCtrl.formStream.listen,
          builder: (_, form) {
            final pesoTotal = _pesoTotalPlanilha(form);
            return Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${form.isEdit ? 'Editar' : 'Nova'} Planilha ${form.codigo}',
                    style: AppCss.largeBold.setColor(AppColors.white),
                  ),
                  Text(
                    '${form.clienteSelecionado?.nome ?? ''} ${form.obraSelecionada != null ? '• ${form.obraSelecionada!.descricao}' : ''}',
                    style: AppCss.minimumRegular.setColor(Colors.white60).setSize(11),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ],
              )),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.scale_outlined, size: 16, color: Colors.white.withValues(alpha: 0.9)),
                  const SizedBox(width: 6),
                  Text(
                    pesoTotal > 0 ? '${pesoTotal.toStringAsFixed(2)} kg' : '— kg',
                    style: AppCss.smallBold.setColor(Colors.white).setSize(13),
                  ),
                ]),
              ),
            ]);
          },
        ),
        actions: const [],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryMain, AppColors.primaryMain.withValues(alpha: 0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 2,
      ),
      body: StreamOut(
        stream: planilhaCtrl.formStream.listen,
        builder: (_, form) => Row(children: [_sidebar(form), Expanded(child: _content(form))]),
      ),
    );
  }

  // ═══ SIDEBAR ═══════════════════════════════════════════
  Widget _sidebar(PlanilhaCreateModel form) {
    Widget item(_Sec s, IconData ic, String tip) {
      final on = _sel == s;
      return Tooltip(message: tip, preferBelow: false, waitDuration: const Duration(milliseconds: 300),
        child: InkWell(onTap: () => setState(() => _sel = s), borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), width: 36, height: 36,
            decoration: BoxDecoration(
              color: on ? AppColors.primaryMain.withValues(alpha: 0.10) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: on ? Border.all(color: AppColors.primaryMain.withValues(alpha: 0.20)) : null,
            ),
            child: Icon(ic, size: 18, color: on ? AppColors.primaryMain : Colors.grey[400]),
          ),
        ),
      );
    }
    return Container(width: 60, height: double.infinity,
      decoration: const BoxDecoration(color: Color(0xFFF1F5F9), border: Border(right: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Column(children: [
        Tooltip(message: 'Planilha ${form.codigo}', preferBelow: false,
          child: Container(margin: const EdgeInsets.symmetric(vertical: 14), width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.primaryMain, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.primaryMain.withValues(alpha: 0.5), blurRadius: 8)]),
            child: Center(child: Text(form.codigo.toString(), style: AppCss.mediumBold.setColor(AppColors.white).setSize(14))),
          ),
        ),
        const SizedBox(height: 8),
        item(_Sec.dadosGerais, Icons.badge_outlined, 'Dados Gerais'),
        item(_Sec.elementos, Icons.view_list_outlined, 'Elementos'),
        const Spacer(),
        if (form.isEdit) Tooltip(message: 'Excluir Planilha ${form.codigo}', preferBelow: false,
          child: InkWell(onTap: () => planilhaCtrl.onDelete(context, widget.planilha!), borderRadius: BorderRadius.circular(8),
            child: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.delete_outline, size: 18, color: AppColors.error)),
          ),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _content(PlanilhaCreateModel form) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 200),
    child: KeyedSubtree(key: ValueKey(_sel),
      child: _sel == _Sec.dadosGerais ? _dadosGerais(form) : _elemLayout(form)),
  );

  // ═══ DADOS GERAIS ══════════════════════════════════════
  Widget _dadosGerais(PlanilhaCreateModel form) {
    final clientes = BackendClient.clientes.data;
    final obras = form.clienteSelecionado?.obras ?? [];
    return ListView(padding: const EdgeInsets.all(24), children: [
      Row(children: [Icon(Icons.badge_outlined, color: AppColors.primaryMain, size: 20), const SizedBox(width: 12),
        Text('DADOS GERAIS', style: AppCss.mediumBold.setSize(16).setLetterSpacing(1))]),
      const SizedBox(height: 24),
      Container(padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!, width: 1.0),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AppField(label: 'Planilha', controllerObj: TextEditingController(text: form.codigo.toString()), isDisable: true),
          const SizedBox(height: 16),
          AppDropDown<ClienteModel?>(label: 'Cliente', item: form.clienteSelecionado, itens: clientes,
            itemLabel: (e) => e?.nome ?? 'Selecione um cliente',
            onSelect: (e) { form.clienteSelecionado = e; form.obraSelecionada = null; planilhaCtrl.formStream.update(); }),
          const SizedBox(height: 16),
          AppDropDown<ObraModel?>(label: 'Obra', item: form.obraSelecionada, itens: obras,
            itemLabel: (e) => e?.descricao ?? 'Selecione uma obra',
            onSelect: (e) { form.obraSelecionada = e; planilhaCtrl.formStream.update(); }),
        ]),
      ),
      const SizedBox(height: 16),
      InkWell(
        onTap: () => planilhaCtrl.salvarDadosGerais(),
        child: Container(
          height: 44, width: double.infinity,
          decoration: BoxDecoration(color: AppColors.primaryMain, borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text('SALVAR DADOS GERAIS', style: AppCss.minimumBold.setColor(Colors.white).setSize(13).setLetterSpacing(1))),
        ),
      ),
    ]);
  }

  // ═══ 3 COLUNAS ═════════════════════════════════════════
  Widget _elemLayout(PlanilhaCreateModel form) {
    final eSel = _elemIdx >= 0 && _elemIdx < form.elementos.length ? form.elementos[_elemIdx] : null;
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(width: 300, child: _col1(form)),
      Container(width: 1, color: const Color(0xFFE2E8F0)),
      SizedBox(width: 300, child: eSel != null ? _col2(eSel) : _empty('Selecione um elemento\npara ver suas posições', Icons.touch_app_outlined)),
      Container(width: 1, color: const Color(0xFFE2E8F0)),
      Expanded(child: _col3()),
    ]);
  }

  Widget _empty(String msg, IconData ic) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(
      width: 64, height: 64,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        shape: BoxShape.circle,
      ),
      child: Icon(ic, size: 32, color: Colors.grey[350]),
    ),
    const SizedBox(height: 16),
    Text(msg, textAlign: TextAlign.center, style: AppCss.minimumRegular.setColor(Colors.grey[400]!).setSize(12)),
  ]));

  Widget _hdr(String t, IconData ic, String? badge) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [AppColors.primaryMain.withValues(alpha: 0.08), AppColors.primaryMain.withValues(alpha: 0.02)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      border: Border(bottom: BorderSide(color: AppColors.primaryMain.withValues(alpha: 0.12))),
    ),
    child: Row(children: [
      Icon(ic, color: AppColors.primaryMain, size: 16), const SizedBox(width: 8),
      Expanded(child: Text(t, style: AppCss.minimumBold.setColor(AppColors.primaryMain).setSize(11).setLetterSpacing(0.8), maxLines: 1, overflow: TextOverflow.ellipsis)),
      if (badge != null) Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primaryMain.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(badge, style: AppCss.minimumBold.setColor(AppColors.primaryMain).setSize(10)),
      ),
    ]),
  );

  // ── COL 1: Elementos ───────────────────────────────────
  Widget _col1(PlanilhaCreateModel form) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _hdr('ELEMENTOS', Icons.layers_outlined, '${form.elementos.length}'),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Expanded(flex: 3, child: AppField(label: 'Nome', controller: _eNome,
            onEditingComplete: () {
              if (_eNome.text.trim().isEmpty) return;
              _eQtde.text = '1';
              _eQtde.focus.requestFocus();
              _eQtde.controller.selection = TextSelection(baseOffset: 0, extentOffset: 1);
            }, onChanged: (_) {})),
          const SizedBox(width: 8),
          Expanded(child: AppField(label: 'Qtde', type: TextInputType.number, controller: _eQtde,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onEditingComplete: () => _addElem(form), onChanged: (_) {})),
          const SizedBox(width: 8),
          InkWell(onTap: () => _addElem(form), borderRadius: BorderRadius.circular(8),
            child: Container(width: 36, height: 36, margin: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primaryMain, AppColors.primaryMain.withValues(alpha: 0.8)]),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: AppColors.primaryMain.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 18))),
        ]),
      ),
      Expanded(
        child: form.elementos.isEmpty
            ? Center(child: Text('Nenhum elemento', style: AppCss.minimumRegular.setColor(Colors.grey[400]!).setSize(13)))
            : ListView.separated(
                padding: const EdgeInsets.all(10),
                itemCount: form.elementos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                final e = form.elementos[i]; final on = i == _elemIdx;
                return InkWell(
                  onTap: () { setState(() => _elemIdx = i); _limparPos(); },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: on ? AppColors.primaryMain.withValues(alpha: 0.06) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: on ? AppColors.primaryMain.withValues(alpha: 0.35) : Colors.grey[200]!,
                        width: on ? 1.5 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: on
                              ? AppColors.primaryMain.withValues(alpha: 0.10)
                              : Colors.black.withValues(alpha: 0.04),
                          blurRadius: on ? 8 : 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e.nome.text.isEmpty ? 'Elemento ${i + 1}' : e.nome.text,
                            style: AppCss.smallBold.setSize(15), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 5),
                        Text('Qtde: ${e.quantidade.text.isEmpty ? '0' : e.quantidade.text} • Pos: ${e.posicoes.length}',
                            style: AppCss.minimumRegular.setColor(Colors.grey[500]!).setSize(12)),
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.scale_outlined, size: 12, color: _pesoTotalElemento(e) > 0 ? const Color(0xFF10B981) : Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(
                            'Unit: ${_formatPeso(_pesoUnitElemento(e))} • Total: ${_formatPeso(_pesoTotalElemento(e))} kg',
                            style: AppCss.minimumRegular.setColor(_pesoTotalElemento(e) > 0 ? const Color(0xFF10B981) : Colors.grey[400]!).setSize(11),
                          ),
                        ]),
                      ])),
                      InkWell(onTap: () async {
                        if (await showConfirmDialog('Excluir elemento?', 'Posições serão removidas.')) {
                          final elemId = _elementoDbIds[i];
                          if (elemId != null && elemId.length == 36) {
                            await planilhaCtrl.excluirElemento(elemId);
                          }
                          form.elementos.removeAt(i);
                          final novoMap = <int, String>{};
                          for (final entry in _elementoDbIds.entries) {
                            if (entry.key < i) novoMap[entry.key] = entry.value;
                            if (entry.key > i) novoMap[entry.key - 1] = entry.value;
                          }
                          _elementoDbIds.clear();
                          _elementoDbIds.addAll(novoMap);
                          if (_elemIdx >= form.elementos.length) _elemIdx = form.elementos.length - 1;
                          planilhaCtrl.formStream.update();
                        }
                      }, borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.delete_outline, size: 16, color: Colors.red[400]),
                        ),
                      ),
                    ]),
                  ),
                );
              }),
      ),
    ]);
  }

  void _addElem(PlanilhaCreateModel form) async {
    if (_eNome.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Nome do elemento é obrigatório'), backgroundColor: AppColors.error));
      return;
    }
    final n = ElementoCreateModel();
    n.nome.text = _eNome.text.trim();
    n.quantidade.text = _eQtde.text.isEmpty ? '1' : _eQtde.text;
    form.elementos.add(n);
    final idx = form.elementos.length - 1;
    _eNome.text = ''; _eQtde.text = '';
    setState(() => _elemIdx = idx);
    planilhaCtrl.formStream.update();
    // Auto-save
    final dbId = await planilhaCtrl.adicionarElemento(n);
    if (dbId != null) _elementoDbIds[idx] = dbId;
    Future.delayed(const Duration(milliseconds: 100), () => _pNum.focus.requestFocus());
  }

  // ── COL 2: Posições ────────────────────────────────────
  Widget _col2(ElementoCreateModel elem) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _hdr('POSIÇÕES — ${elem.nome.text}', Icons.list_alt_outlined, '${elem.posicoes.length}'),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          Row(children: [
            Expanded(child: AppField(label: 'Posição', type: TextInputType.number, controller: _pNum,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onEditingComplete: () => _fnBitola.requestFocus(), onChanged: (_) {})),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _campoCodigo('Bitola', _bitolaCtrl, _fnBitola, _pBitola?.label, () {
              _validarBitola();
              _fnForma.requestFocus();
            })),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(flex: 2, child: _campoCodigo('Forma', _formaCtrl, _fnForma,
                _pForma != null ? '${_pForma!.codigo} - ${_pForma!.descricao}' : null, () {
              _validarForma();
              _pQtde.text = '1';
              _pQtde.focus.requestFocus();
              _pQtde.controller.selection = TextSelection(baseOffset: 0, extentOffset: 1);
            })),
            const SizedBox(width: 8),
            Expanded(child: AppField(label: 'Qtde', type: TextInputType.number, controller: _pQtde,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onEditingComplete: () => _addPos(elem), onChanged: (_) {})),
            const SizedBox(width: 8),
            InkWell(onTap: () => _addPos(elem), borderRadius: BorderRadius.circular(8),
              child: Container(width: 36, height: 36, margin: const EdgeInsets.only(top: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.primaryMain, AppColors.primaryMain.withValues(alpha: 0.8)]),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: AppColors.primaryMain.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 18))),
          ]),
        ]),
      ),
      Expanded(
        child: elem.posicoes.isEmpty
            ? Center(child: Text('Nenhuma posição', style: AppCss.minimumRegular.setColor(Colors.grey[400]!).setSize(13)))
            : ListView.separated(
                padding: const EdgeInsets.all(10),
                itemCount: elem.posicoes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                final p = elem.posicoes[i];
                final on = _posicaoSelecionada?.id == p.id;
                return InkWell(
                  onTap: () {
                    _atualizarCompCtrls(p.formaSelecionada, posicao: p);
                    setState(() => _formaSelecionada = p.formaSelecionada);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: on ? AppColors.primaryMain.withValues(alpha: 0.05) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: on ? AppColors.primaryMain.withValues(alpha: 0.35) : Colors.grey[200]!,
                        width: on ? 1.5 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: on
                              ? AppColors.primaryMain.withValues(alpha: 0.10)
                              : Colors.black.withValues(alpha: 0.04),
                          blurRadius: on ? 8 : 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(children: [
                      Container(width: 36, height: 36,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primaryMain.withValues(alpha: 0.18), AppColors.primaryMain.withValues(alpha: 0.06)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(child: Text(p.posicao.text, style: AppCss.minimumBold.setColor(AppColors.primaryMain).setSize(14)))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.bitolaSelecionada?.label ?? 'Sem bitola', style: AppCss.minimumBold.setSize(14), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text('Forma: ${p.formaSelecionada?.codigo ?? '-'} • Qtde: ${p.qtde.text.isEmpty ? '0' : p.qtde.text}',
                            style: AppCss.minimumRegular.setColor(Colors.grey[500]!).setSize(12)),
                        const SizedBox(height: 3),
                        Row(children: [
                          Icon(Icons.scale_outlined, size: 12, color: _pesoTotalPosicao(p) > 0 ? const Color(0xFF10B981) : Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(
                            'Unit: ${_formatPeso(_pesoUnitPosicao(p))} • Total: ${_formatPeso(_pesoTotalPosicao(p))} kg',
                            style: AppCss.minimumRegular.setColor(_pesoTotalPosicao(p) > 0 ? const Color(0xFF10B981) : Colors.grey[400]!).setSize(11),
                          ),
                        ]),
                      ])),
                      InkWell(onTap: () async {
                        if (await showConfirmDialog('Excluir posição?', 'Posição ${p.posicao.text} será removida.')) {
                          final posId = p.id;
                          elem.posicoes.removeAt(i);
                          planilhaCtrl.formStream.update();
                          if (posId.length == 36) await planilhaCtrl.excluirPosicao(posId);
                        }
                      }, borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.delete_outline, size: 16, color: Colors.red[400]),
                        ),
                      ),
                    ]),
                  ),
                );
              }),
      ),
    ]);
  }

  // Campo código genérico (bitola/forma)
  Widget _campoCodigo(String label, TextEditingController ctrl, FocusNode fn, String? info, VoidCallback onSubmit) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$label (código):', style: AppCss.smallBold),
      const SizedBox(height: 4),
      TextField(controller: ctrl, focusNode: fn,
        style: AppCss.smallRegular,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          hintText: 'Código',
          suffixIcon: info != null ? const Icon(Icons.check_circle, color: Colors.green, size: 18) : null,
        ),
        onSubmitted: (_) => onSubmit(),
      ),
      if (info != null)
        Padding(padding: const EdgeInsets.only(top: 2),
          child: Text(info, style: AppCss.minimumRegular.setColor(AppColors.primaryMain).setSize(10))),
    ]);
  }

  void _validarBitola() {
    final cod = _bitolaCtrl.text.trim();
    if (cod.isEmpty) { setState(() => _pBitola = null); return; }
    final match = BackendClient.produtos.data.where((b) =>
        b.nome.toLowerCase() == cod.toLowerCase() || b.descricao.toLowerCase() == cod.toLowerCase()).firstOrNull;
    setState(() => _pBitola = match);
    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bitola "$cod" não encontrada'), backgroundColor: AppColors.error, duration: const Duration(seconds: 2)));
    }
  }

  void _validarForma() {
    final cod = _formaCtrl.text.trim();
    if (cod.isEmpty) { setState(() => _pForma = null); return; }
    final match = BackendClient.formas.data.where((f) => f.codigo.toLowerCase() == cod.toLowerCase()).firstOrNull;
    setState(() => _pForma = match);
    _atualizarCompCtrls(match);
    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Forma "$cod" não encontrada'), backgroundColor: AppColors.error, duration: const Duration(seconds: 2)));
    }
  }

  void _addPos(ElementoCreateModel elem) async {
    if (_pNum.text.trim().isEmpty) return;
    // Validar campos obrigatórios
    if (_pBitola == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Bitola é obrigatória'), backgroundColor: AppColors.error));
      _fnBitola.requestFocus();
      return;
    }
    if (_pForma == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Forma é obrigatória'), backgroundColor: AppColors.error));
      _fnForma.requestFocus();
      return;
    }
    final num = int.tryParse(_pNum.text) ?? 0;
    if (elem.posicoes.any((p) => (int.tryParse(p.posicao.text) ?? -1) == num)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Posição $num já existe'), backgroundColor: AppColors.error));
      return;
    }
    final n = PosicaoCreateModel();
    n.posicao.text = _pNum.text;
    n.bitolaSelecionada = _pBitola;
    n.formaSelecionada = _pForma;
    n.qtde.text = _pQtde.text.isEmpty ? '1' : _pQtde.text;
    elem.posicoes.add(n);
    _limparPos();
    planilhaCtrl.formStream.update();
    // Auto-save posição
    final elemId = _elementoDbIds[_elemIdx];
    if (elemId != null) {
      final dbId = await planilhaCtrl.adicionarPosicao(n, elemId);
      if (dbId != null) n.id = dbId;
    }
    Future.delayed(const Duration(milliseconds: 100), () => _pNum.focus.requestFocus());
  }

  void _limparPos() {
    _pNum.text = ''; _bitolaCtrl.text = ''; _formaCtrl.text = ''; _pQtde.text = '';
    setState(() { _pBitola = null; _pForma = null; });
  }

  void _salvarComprimento(int idx, FormaModel forma) {
    if (_posicaoSelecionada == null) return;
    if (idx >= forma.itens.length || idx >= _compCtrls.length) return;
    final trecho = forma.itens[idx].trecho;
    final valor = int.tryParse(_compCtrls[idx].text);
    if (valor != null) {
      _posicaoSelecionada!.comprimentos[trecho] = valor;
    } else {
      _posicaoSelecionada!.comprimentos.remove(trecho);
    }
    // Auto-save: atualizar posição no banco
    final elemId = _elementoDbIds[_elemIdx];
    if (elemId != null && _posicaoSelecionada!.id.length == 36) {
      planilhaCtrl.adicionarPosicaoAtualizada(_posicaoSelecionada!, elemId);
    }
    // Atualizar peso total da planilha
    setState(() {});
    planilhaCtrl.formStream.update();
    _atualizarPesoTotal(planilhaCtrl.form);
  }

  // ── COL 3: Preview Forma ───────────────────────────────
  Widget _col3() {
    // Usa forma da posição selecionada ou do formulário
    final forma = _formaSelecionada ?? _pForma;
    if (forma == null) return _empty('Selecione uma forma\npara ver o desenho', Icons.architecture_outlined);

    // Legendas customizadas: comprimento digitado ou trecho original
    final legendasCustom = List.generate(forma.itens.length, (i) {
      if (i < _compCtrls.length && _compCtrls[i].text.isNotEmpty) {
        return _compCtrls[i].text;
      }
      return forma.itens[i].trecho;
    });

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _hdr('FORMA ${forma.codigo}', Icons.architecture_outlined, null),
      // Desenho (altura fixa) com container decorado
      Container(
        height: 250,
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FormaPreviewWidget(
            itens: forma.itens, height: 230,
            mostrarLegenda: true,
            rotacaoExterna: forma.rotacao,
            legendasCustom: legendasCustom,
            mostrarVertices: false,
          ),
        ),
      ),
      // ── Metade inferior: trechos (1/3 da largura) ──
      Expanded(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Header com colunas
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(children: [
                SizedBox(width: 40, child: Text('Trecho', style: AppCss.minimumBold.setColor(Colors.grey[500]!).setSize(9), textAlign: TextAlign.center)),
                SizedBox(width: 70, child: Text('Comp.', style: AppCss.minimumBold.setColor(Colors.grey[500]!).setSize(9), textAlign: TextAlign.center)),
                const SizedBox(width: 4),
                Text('Var.', style: AppCss.minimumBold.setColor(Colors.grey[500]!).setSize(9)),
              ]),
            ),
            Expanded(
              child: forma.itens.isEmpty
                  ? Center(child: Text('Sem trechos', style: AppCss.minimumRegular.setColor(Colors.grey[400]!)))
                  : ListView.builder(
                      itemCount: forma.itens.length,
                      itemBuilder: (_, i) {
                        final t = forma.itens[i];
                        final trecho = t.trecho;
                        final isVariavel = _posicaoSelecionada?.variaveis[trecho] ?? false;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.primaryMain.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(child: Text(t.trecho,
                                  style: AppCss.minimumBold.setColor(AppColors.primaryMain).setSize(11))),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 70,
                              height: 32,
                              child: TextField(
                                controller: i < _compCtrls.length ? _compCtrls[i] : null,
                                focusNode: i < _compFns.length ? _compFns[i] : null,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: AppCss.smallRegular.setSize(13),
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onChanged: (_) => setState(() {}),
                                onSubmitted: (_) {
                                  // Salvar comprimento no modelo
                                  _salvarComprimento(i, forma);
                                  // Enter pula para próximo trecho
                                  if (i + 1 < _compFns.length) {
                                    _compFns[i + 1].requestFocus();
                                  }
                                },
                              ),
                            ),
                            SizedBox(
                              width: 28, height: 28,
                              child: Checkbox(
                                value: isVariavel,
                                onChanged: _posicaoSelecionada == null ? null : (v) {
                                  setState(() {
                                    _posicaoSelecionada!.variaveis[trecho] = v ?? false;
                                  });
                                  // Auto-save
                                  final elemId = _elementoDbIds[_elemIdx];
                                  if (elemId != null && _posicaoSelecionada!.id.length == 36) {
                                    planilhaCtrl.adicionarPosicaoAtualizada(_posicaoSelecionada!, elemId);
                                  }
                                },
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                activeColor: AppColors.primaryMain,
                              ),
                            ),
                            if (t.tipo == 'circulo') ...[
                              const SizedBox(width: 4),
                              Icon(Icons.circle_outlined, size: 14, color: Colors.grey[400]),
                            ],
                          ]),
                        );
                      },
                    ),
            ),
          ])),
          const Expanded(flex: 2, child: SizedBox()),
        ]),
      ),
    ]);
  }
}
