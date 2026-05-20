import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/cliente_model.dart';
import 'package:acoplan/app/core/client/models/forma_model.dart';
import 'package:acoplan/app/core/client/models/planilha_model.dart';
import 'package:acoplan/app/core/client/models/produto_model.dart';
import 'package:acoplan/app/core/client/models/trecho_variavel_config.dart';
import 'package:acoplan/app/core/components/app_drop_down.dart';
import 'package:acoplan/app/core/components/app_field.dart';
import 'package:acoplan/app/core/components/app_scaffold.dart';
import 'package:acoplan/app/core/components/stream_out.dart';
import 'package:acoplan/app/core/dialogs/confirm_dialog.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/core/models/text_controller.dart';
import 'package:acoplan/app/modules/planilha/planilha_controller.dart';
import 'package:acoplan/app/modules/planilha/planilha_view_model.dart';
import 'package:acoplan/app/modules/forma/ui/forma_preview_widget.dart';
import 'package:acoplan/app/modules/planilhamento_ia/planilhamento_ia_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:overlay_support/overlay_support.dart';

enum _Sec { dadosGerais, elementos, planilhamentoIA }

class PlanilhaCreatePage extends StatefulWidget {
  final PlanilhaModel? planilha;
  final bool isReadOnly;
  final bool skipInit;
  const PlanilhaCreatePage({this.planilha, this.isReadOnly = false, this.skipInit = false, super.key});
  @override
  State<PlanilhaCreatePage> createState() => _PlanilhaCreatePageState();
}

class _PlanilhaCreatePageState extends State<PlanilhaCreatePage> {
  _Sec _sel = _Sec.dadosGerais;
  int _elemIdx = -1;
  bool get _isRO => widget.isReadOnly;

  // Elemento atual baseado no índice selecionado
  ElementoCreateModel? get _elemAtual =>
      _elemIdx >= 0 && _elemIdx < planilhaCtrl.form.elementos.length
          ? planilhaCtrl.form.elementos[_elemIdx]
          : null;

  // IDs reais do banco para cada elemento (indexado pela posição na lista)
  final Map<int, String> _elementoDbIds = {};

  // Posição selecionada (para mostrar desenho da forma)
  FormaModel? _formaSelecionada;
  PosicaoCreateModel? _posicaoSelecionada;
  bool _posicaoModificada = false;

  // Controllers dos comprimentos dos trechos
  List<TextEditingController> _compCtrls = [];
  List<FocusNode> _compFns = [];

  // Trecho variável selecionado para painel lateral
  int _trechoVarIdx = -1;
  final _varInicialFn = FocusNode();
  final _varFinalFn = FocusNode();
  final _varMultFn = FocusNode();
  final _varInicialCtrl = TextEditingController();
  final _varFinalCtrl = TextEditingController();
  final _varMultCtrl = TextEditingController();
  List<FocusNode> _manualFns = [];
  List<TextEditingController> _manualCtrls = [];

  void _atualizarManualCtrls(List<int> medidas) {
    for (final fn in _manualFns) { fn.dispose(); }
    _manualFns = List.generate(medidas.length, (_) => FocusNode());
    _manualCtrls = List.generate(medidas.length, (i) =>
        TextEditingController(text: medidas[i].toString()));
  }

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

  /// Verifica se a posição tem algum trecho variável configurado
  bool _temVariavel(PosicaoCreateModel pos) {
    return pos.variaveisConfig.isNotEmpty &&
        pos.variaveis.values.any((v) => v);
  }

  /// Peso unitário (para posição SEM trechos variáveis) =
  /// comprimento bruto (soma dos trechos, cm→m) × massa linear (kg/m)
  double _pesoUnitPosicao(PosicaoCreateModel pos) {
    if (pos.bitolaSelecionada == null) return 0;
    final massaLinear = pos.bitolaSelecionada!.massaFinal; // kg/m
    final somaCm = pos.comprimentos.values.fold(0, (s, v) => s + v);
    return (somaCm / 100.0) * massaLinear;
  }

  /// Peso total de uma posição.
  /// Se tem trecho variável: calcula peça a peça (cada peça pode ter
  /// comprimento diferente). Não pode usar atalho soma×qtde.
  /// Se não tem variável: peso unitário × quantidade.
  double _pesoTotalPosicao(PosicaoCreateModel pos) {
    if (pos.bitolaSelecionada == null) return 0;
    final massaLinear = pos.bitolaSelecionada!.massaFinal;
    final qtde = int.tryParse(pos.qtde.text) ?? 1;

    if (!_temVariavel(pos)) {
      return _pesoUnitPosicao(pos) * qtde;
    }

    // Calcula peça a peça
    double pesoTotal = 0;
    for (int peca = 0; peca < qtde; peca++) {
      int somaCm = 0;
      for (final entry in pos.comprimentos.entries) {
        final trecho = entry.key;
        final isVar = pos.variaveis[trecho] ?? false;
        if (isVar) {
          // Busca config: própria ou do líder do grupo
          final config = pos.variaveisConfig[trecho]
              ?? pos.variaveisConfig.values.firstOrNull;
          if (config != null && config.inicial > 0 && config.final_ > 0) {
            final expandidas = config.medidasExpandidas(pos.multiplicador);
            somaCm += peca < expandidas.length
                ? expandidas[peca]
                : (expandidas.isNotEmpty ? expandidas.last : 0);
          } else {
            somaCm += entry.value; // config incompleta, usa valor fixo
          }
        } else {
          somaCm += entry.value; // trecho fixo
        }
      }
      pesoTotal += (somaCm / 100.0) * massaLinear;
    }
    return pesoTotal;
  }

  /// Peso unitário de um elemento = somatório dos pesos totais das posições
  double _pesoUnitElemento(ElementoCreateModel elem) {
    return elem.posicoes.fold<double>(0, (s, p) => s + _pesoTotalPosicao(p));
  }

  int _qtdeTotalElemento(ElementoCreateModel elem) {
    final qtde = int.tryParse(elem.quantidade.text) ?? 1;
    final numEquiv = 1 + elem.elementosEquivalentes.length;
    return qtde * numEquiv;
  }

  /// Peso total de um elemento = peso unitário × quantidade do elemento × (1 + num equivalentes)
  double _pesoTotalElemento(ElementoCreateModel elem) {
    return _pesoUnitElemento(elem) * _qtdeTotalElemento(elem);
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

  /// Atualiza peso do elemento atual no banco
  Future<void> _atualizarPesoElementoAtual() async {
    final elem = _elemAtual;
    final elemId = _elementoDbIds[_elemIdx];
    if (elem == null || elemId == null || elemId.length != 36) return;
    final peso = _pesoTotalElemento(elem);
    await planilhaCtrl.atualizarPesoElemento(elemId, peso);
  }

  // Elemento form
  final TextController _eNome = TextController();
  final TextController _eQtde = TextController();
  final TextController _eEquiv = TextController();
  List<String> _equivalentesTemp = [];
  int _editandoIdx = -1;

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
    if (!widget.skipInit) {
      planilhaCtrl.init(widget.planilha);
    }
    
    // Preencher IDs do banco para elementos existentes
    if (widget.planilha != null) {
      for (int i = 0; i < planilhaCtrl.form.elementos.length; i++) {
        _elementoDbIds[i] = planilhaCtrl.form.elementos[i].id;
      }
    }

    // Auto-selecionar primeiro elemento e primeira posição ao editar ou importar
    if (widget.planilha != null || widget.skipInit) {
      if (planilhaCtrl.form.elementos.isNotEmpty) {
        _sel = _Sec.elementos;
        _elemIdx = 0;
        final primeiroElem = planilhaCtrl.form.elementos[0];
        if (primeiroElem.posicoes.isNotEmpty) {
          final primeiraPosicao = primeiroElem.posicoes[0];
          _pNum.text = primeiraPosicao.posicao.text;
          _pBitola = primeiraPosicao.bitolaSelecionada;
          _bitolaCtrl.text = primeiraPosicao.bitolaSelecionada?.nome ?? '';
          _pForma = primeiraPosicao.formaSelecionada;
          _formaCtrl.text = primeiraPosicao.formaSelecionada?.codigo ?? '';
          _pQtde.text = primeiraPosicao.qtde.text;
          _atualizarCompCtrls(primeiraPosicao.formaSelecionada, posicao: primeiraPosicao);
          _formaSelecionada = primeiraPosicao.formaSelecionada;
        }
      }
    }

    _fnBitola.onKeyEvent = (node, event) {
      if (event.logicalKey == LogicalKeyboardKey.f2) {
        if (event is KeyDownEvent) {
          Future.microtask(() => _abrirBuscaBitola());
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
    // Tratamento legado/web por garantia
    _fnBitola.onKey = (node, event) {
      if (event.logicalKey == LogicalKeyboardKey.f2) {
        if (event.runtimeType.toString() == 'RawKeyDownEvent') {
          Future.microtask(() => _abrirBuscaBitola());
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };

    _fnForma.onKeyEvent = (node, event) {
      if (event.logicalKey == LogicalKeyboardKey.f2) {
        if (event is KeyDownEvent) {
          Future.microtask(() => _abrirBuscaForma());
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
    _fnForma.onKey = (node, event) {
      if (event.logicalKey == LogicalKeyboardKey.f2) {
        if (event.runtimeType.toString() == 'RawKeyDownEvent') {
          Future.microtask(() => _abrirBuscaForma());
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };

    // Listener de perda de foco no campo posição para checar duplicata
    _pNum.focus.addListener(_onPosicaoFocusChange);

    super.initState();
  }

  void _onPosicaoFocusChange() {
    if (_pNum.focus.hasFocus) return; // só age ao perder foco
    // Delay: o onTap do card de posição (que chama _selecionarPosicao) dispara
    // DEPOIS da perda de foco. O microtask garante que o check roda após o onTap.
    Future.microtask(() {
      if (!mounted) return;
      if (_pNum.focus.hasFocus) return;         // foco voltou: ignora
      if (_posicaoSelecionada != null) return;  // selecionou uma posição: edição, não bloqueia
      if (_pNum.text.trim().isEmpty) return;    // campo vazio: ignora
      final elem = _elemAtual;
      if (elem == null) return;
      final num = int.tryParse(_pNum.text) ?? 0;
      final existe = elem.posicoes.any((p) => (int.tryParse(p.posicao.text) ?? -1) == num);
      if (existe) {
        NotificationService.showNegative(
          'Posição já existe',
          'Clique na posição $num para editá-la',
          position: NotificationPosition.bottom,
        );
        Future.microtask(() {
          if (!mounted) return;
          _pNum.focus.requestFocus();
          _pNum.controller.selection = TextSelection(
            baseOffset: 0, extentOffset: _pNum.text.length,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _pNum.focus.removeListener(_onPosicaoFocusChange);
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
    Widget item(_Sec s, IconData ic, String tip, {bool habilitado = true}) {
      final on = _sel == s;
      final cor = !habilitado
          ? Colors.grey[350]!
          : on ? AppColors.primaryMain : Colors.grey[400]!;
      return Tooltip(
        message: habilitado ? tip : 'Salve os dados gerais primeiro',
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 300),
        child: InkWell(
          onTap: habilitado
              ? () {
                  setState(() {
                    _sel = s;
                    if (s == _Sec.planilhamentoIA) {
                      planilhamentoIaCtrl.setCliente(form.clienteSelecionado);
                      planilhamentoIaCtrl.setObra(form.obraSelecionada);
                    }
                  });
                }
              : () => NotificationService.showNegative(
                    'Dados não salvos',
                    'Salve os dados gerais antes de acessar esta seção',
                    position: NotificationPosition.bottom,
                  ),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: on && habilitado
                  ? AppColors.primaryMain.withValues(alpha: 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: on && habilitado
                  ? Border.all(color: AppColors.primaryMain.withValues(alpha: 0.20))
                  : null,
            ),
            child: Stack(alignment: Alignment.center, children: [
              Icon(ic, size: 18, color: cor),
              if (!habilitado)
                Positioned(
                  right: 4, bottom: 4,
                  child: Icon(Icons.lock_outline, size: 9, color: Colors.grey[400]),
                ),
            ]),
          ),
        ),
      );
    }

    final elementosHabilitado = form.isEdit;
    final iaHabilitado = elementosHabilitado && !_isRO;

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
        item(_Sec.elementos, Icons.view_list_outlined, 'Elementos', habilitado: elementosHabilitado),
        item(_Sec.planilhamentoIA, Icons.auto_awesome_outlined, 'Planilhamento IA', habilitado: iaHabilitado),
        const Spacer(),
        if (form.isEdit && !_isRO) Tooltip(message: 'Excluir Planilha ${form.codigo}', preferBelow: false,
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
      child: _sel == _Sec.dadosGerais
          ? _dadosGerais(form)
          : _sel == _Sec.elementos
              ? _elemLayout(form)
              : _planilhamentoIaContent(form)),
  );

  // ═══ DADOS GERAIS ══════════════════════════════════════
  Widget _dadosGerais(PlanilhaCreateModel form) {
    final clientes = BackendClient.clientes.data;
    final obras = form.clienteSelecionado?.obras ?? [];
    return ListView(padding: const EdgeInsets.all(24), children: [
      Row(children: [Icon(Icons.badge_outlined, color: AppColors.primaryMain, size: 20), const SizedBox(width: 12),
        Text('DADOS GERAIS', style: AppCss.mediumBold.setSize(16).setLetterSpacing(1))]),
      const SizedBox(height: 24),
      IgnorePointer(
        ignoring: _isRO,
        child: Container(padding: const EdgeInsets.all(24),
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
      ),
      const SizedBox(height: 16),
      if (!_isRO)
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
      if (!_isRO)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(flex: 3, child: AppField(label: 'Nome', controller: _eNome,
                  isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  onEditingComplete: () {
                    if (_eNome.text.trim().isEmpty) return;
                    if (_eQtde.text.isEmpty) _eQtde.text = '1';
                    _eQtde.focus.requestFocus();
                    _eQtde.controller.selection = TextSelection(baseOffset: 0, extentOffset: _eQtde.text.length);
                  }, onChanged: (val) {
                    if (val.isNotEmpty && _eQtde.text.isEmpty) {
                      _eQtde.text = '1';
                    }
                  })),
                const SizedBox(width: 8),
                Expanded(child: AppField(label: 'Qtde', type: TextInputType.number, controller: _eQtde,
                  isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onEditingComplete: () => _eEquiv.focus.requestFocus(), onChanged: (_) {})),
              ]),
              const SizedBox(height: 8),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: AppField(label: 'Equivalentes', controller: _eEquiv,
                  isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  suffixIcon: Icons.add,
                  onSuffix: () {
                    final text = _eEquiv.text.trim();
                    if (text.isNotEmpty && !_equivalentesTemp.contains(text) && text != _eNome.text.trim()) {
                      setState(() {
                        _equivalentesTemp.add(text);
                        _eEquiv.text = '';
                      });
                    }
                  },
                  onEditingComplete: () {
                    final text = _eEquiv.text.trim();
                    if (text.isNotEmpty && !_equivalentesTemp.contains(text) && text != _eNome.text.trim()) {
                      setState(() {
                        _equivalentesTemp.add(text);
                        _eEquiv.text = '';
                      });
                    }
                  }, onChanged: (_) {})),
              ]),
              if (_equivalentesTemp.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _equivalentesTemp.map((eq) => Chip(
                      label: Text(eq, style: AppCss.minimumBold.setColor(AppColors.primaryMain)),
                      backgroundColor: AppColors.primaryMain.withValues(alpha: 0.1),
                      deleteIcon: Icon(Icons.close, size: 14, color: AppColors.primaryMain),
                      onDeleted: () => setState(() => _equivalentesTemp.remove(eq)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )).toList(),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_editandoIdx != -1)
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _editandoIdx = -1;
                            _eNome.text = ''; _eQtde.text = ''; _eEquiv.text = '';
                            _equivalentesTemp.clear();
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.red[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Cancelar', style: AppCss.smallBold.setColor(Colors.red[400]!)),
                        ),
                      ),
                    ),
                  if (_editandoIdx != -1) const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _editandoIdx != -1 ? _updateElem(form) : _addElem(form),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: _editandoIdx != -1 
                            ? [Colors.green[600]!, Colors.green[500]!] 
                            : [AppColors.primaryMain, AppColors.primaryMain.withValues(alpha: 0.8)]),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: (_editandoIdx != -1 ? Colors.green : AppColors.primaryMain).withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_editandoIdx != -1 ? Icons.check : Icons.add, color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Text(_editandoIdx != -1 ? 'Salvar Edição' : 'Adicionar Elemento', style: AppCss.smallBold.setColor(Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
            ),
          ],
        ),
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
                  onTap: () {
                    setState(() {
                      _elemIdx = i;
                      _editandoIdx = i;
                      _eNome.text = e.nome.text;
                      _eQtde.text = e.quantidade.text;
                      _equivalentesTemp = List.from(e.elementosEquivalentes);
                      _eEquiv.text = '';
                    });
                    // Auto-selecionar primeira posição do elemento
                    if (e.posicoes.isNotEmpty) {
                      _selecionarPosicao(e.posicoes.first);
                    } else {
                      _limparPos();
                      _atualizarCompCtrls(null);
                      setState(() => _formaSelecionada = null);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: on ? AppColors.primaryMain : Colors.grey[200]!,
                        width: on ? 1.5 : 1,
                      ),
                      boxShadow: [
                        if (on) BoxShadow(
                          color: AppColors.primaryMain.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ) else BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e.nome.text.isEmpty ? 'Elemento ${i + 1}' : e.nome.text,
                            style: AppCss.smallBold.setSize(15), maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (e.elementosEquivalentes.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text('= ${e.elementosEquivalentes.join(', ')}',
                              style: AppCss.minimumBold.setColor(AppColors.primaryMain).setSize(12), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                        const SizedBox(height: 5),
                        Text('Qtde: ${e.quantidade.text.isEmpty ? '0' : e.quantidade.text} ${e.elementosEquivalentes.isNotEmpty ? '(Total: ${_qtdeTotalElemento(e)}) ' : ''}• Pos: ${e.posicoes.length}',
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
                      if (!_isRO) InkWell(onTap: () async {
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
                          // Limpar preview da forma e estado da posição
                          _limparPos();
                          _atualizarCompCtrls(null);
                          setState(() => _formaSelecionada = null);
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
      NotificationService.showNegative('Campo obrigatório', 'Informe o nome do elemento', position: NotificationPosition.bottom);
      return;
    }
    final n = ElementoCreateModel();
    n.nome.text = _eNome.text.trim();
    n.quantidade.text = _eQtde.text.isEmpty ? '1' : _eQtde.text;
    
    // Adiciona o que estiver pendente no campo de equivalentes antes de salvar
    final pendente = _eEquiv.text.trim();
    if (pendente.isNotEmpty && !_equivalentesTemp.contains(pendente) && pendente != n.nome.text) {
      _equivalentesTemp.add(pendente);
    }
    
    n.elementosEquivalentes = List.from(_equivalentesTemp);
    
    form.elementos.add(n);
    final idx = form.elementos.length - 1;
    _eNome.text = ''; _eQtde.text = ''; _eEquiv.text = '';
    _equivalentesTemp.clear();
    // Limpar colunas de posição e forma
    _limparPos();
    _atualizarCompCtrls(null);
    setState(() {
      _elemIdx = idx;
      _editandoIdx = -1;
      _formaSelecionada = null;
    });
    planilhaCtrl.formStream.update();
    // Auto-save
    final dbId = await planilhaCtrl.adicionarElemento(n);
    if (dbId != null) {
      _elementoDbIds[idx] = dbId;
      n.id = dbId;
    }
    Future.delayed(const Duration(milliseconds: 100), () => _pNum.focus.requestFocus());
  }

  void _updateElem(PlanilhaCreateModel form) async {
    if (_eNome.text.trim().isEmpty) return;
    if (_editandoIdx < 0 || _editandoIdx >= form.elementos.length) return;
    
    final elem = form.elementos[_editandoIdx];
    elem.nome.text = _eNome.text.trim();
    elem.quantidade.text = _eQtde.text.isEmpty ? '1' : _eQtde.text;
    
    final pendente = _eEquiv.text.trim();
    if (pendente.isNotEmpty && !_equivalentesTemp.contains(pendente) && pendente != elem.nome.text) {
      _equivalentesTemp.add(pendente);
    }
    
    elem.elementosEquivalentes = List.from(_equivalentesTemp);
    
    setState(() {
      _editandoIdx = -1;
      _eNome.text = ''; _eQtde.text = ''; _eEquiv.text = '';
      _equivalentesTemp.clear();
    });
    planilhaCtrl.formStream.update();
    
    // Auto-save update
    await planilhaCtrl.atualizarElemento(elem);
  }

  // ── COL 2: Posições ────────────────────────────────────
  Widget _col2(ElementoCreateModel elem) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _hdr('POSIÇÕES — ${elem.nome.text}', Icons.list_alt_outlined, '${elem.posicoes.length}'),
      if (!_isRO) Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Posição:', style: AppCss.smallBold),
                const SizedBox(height: 4),
                TextField(
                  controller: _pNum.controller, focusNode: _pNum.focus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppCss.smallRegular,
                  readOnly: _posicaoSelecionada != null,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: _posicaoSelecionada != null,
                    fillColor: _posicaoSelecionada != null ? Colors.grey[100] : null,
                    suffixIcon: _posicaoSelecionada != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _limparPos();
                            _atualizarCompCtrls(null);
                            setState(() => _formaSelecionada = null);
                          },
                        )
                      : null,
                  ),
                  onSubmitted: (_) {
                    // Só avança se não houver duplicata (o listener de foco também verifica)
                    final num = int.tryParse(_pNum.text) ?? 0;
                    final elem = _elemAtual;
                    final duplicata = _posicaoSelecionada == null &&
                        elem != null &&
                        elem.posicoes.any((p) => (int.tryParse(p.posicao.text) ?? -1) == num);
                    if (!duplicata) _fnBitola.requestFocus();
                  },
                ),
              ]),
            ),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _campoBitola()),
          ]),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 2, child: _campoForma()),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Qtde:', style: AppCss.smallBold),
                const SizedBox(height: 4),
                TextField(
                  controller: _pQtde.controller, focusNode: _pQtde.focus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppCss.smallRegular,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (_) {
                    if (_posicaoSelecionada != null) setState(() => _posicaoModificada = true);
                  },
                  onSubmitted: (_) => _addPos(elem),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: _posicaoModificada
                  ? 'Salvar posição'
                  : _posicaoSelecionada != null
                      ? 'Edite os campos para alterar a posição'
                      : 'Adicionar posição',
              child: InkWell(
                onTap: (_posicaoSelecionada != null && !_posicaoModificada)
                    ? null
                    : () => _addPos(elem),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36, height: 36,
                  margin: const EdgeInsets.only(top: 28),
                  decoration: BoxDecoration(
                    gradient: (_posicaoSelecionada != null && !_posicaoModificada)
                        ? LinearGradient(colors: [Colors.grey[300]!, Colors.grey[300]!])
                        : LinearGradient(colors: [
                            _posicaoModificada ? const Color(0xFF10B981) : AppColors.primaryMain,
                            _posicaoModificada ? const Color(0xFF059669) : AppColors.primaryMain.withValues(alpha: 0.8),
                          ]),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: (_posicaoSelecionada != null && !_posicaoModificada)
                        ? []
                        : [BoxShadow(
                            color: (_posicaoModificada ? const Color(0xFF10B981) : AppColors.primaryMain).withValues(alpha: 0.3),
                            blurRadius: 6, offset: const Offset(0, 2),
                          )],
                  ),
                  child: Icon(
                    _posicaoModificada ? Icons.check : Icons.add,
                    color: (_posicaoSelecionada != null && !_posicaoModificada)
                        ? Colors.grey[400]
                        : Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
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
                final posOrdenadas = [...elem.posicoes]..sort((a, b) =>
                    (int.tryParse(a.posicao.text) ?? 0).compareTo(int.tryParse(b.posicao.text) ?? 0));
                final p = posOrdenadas[i];
                final on = _posicaoSelecionada?.id == p.id;
                return InkWell(
                  onTap: () {
                    _selecionarPosicao(p);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: on ? AppColors.primaryMain : Colors.grey[200]!,
                        width: on ? 1.5 : 1,
                      ),
                      boxShadow: [
                        if (on) BoxShadow(
                          color: AppColors.primaryMain.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ) else BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(children: [
                      Container(width: 36, height: 36,
                        decoration: BoxDecoration(
                          gradient: on ? null : LinearGradient(
                            colors: [AppColors.primaryMain.withValues(alpha: 0.18), AppColors.primaryMain.withValues(alpha: 0.06)],
                          ),
                          color: on ? AppColors.primaryMain : null,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(child: Text('N${p.posicao.text}', style: AppCss.minimumBold.setColor(on ? Colors.white : AppColors.primaryMain).setSize(14)))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Bitola ${p.bitolaSelecionada?.nome ?? '-'}', style: AppCss.minimumBold.setSize(14), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text('Forma: ${p.formaSelecionada?.codigo ?? '-'} • Qtde: ${p.qtde.text.isEmpty ? '0' : p.qtde.text}',
                            style: AppCss.minimumRegular.setColor(Colors.grey[500]!).setSize(12)),
                        const SizedBox(height: 3),
                        Builder(builder: (_) {
                          final somaCm = p.comprimentos.values.fold(0, (s, v) => s + v);
                          final corteCm = p.comprimentoDeCorte;
                          final temCompr = somaCm > 0;
                          final cor = temCompr ? const Color(0xFF6366F1) : Colors.grey[400]!;
                          return Row(children: [
                            Icon(Icons.straighten, size: 12, color: cor),
                            const SizedBox(width: 4),
                            Text('${somaCm}cm', style: AppCss.minimumRegular.setColor(cor).setSize(11)),
                            if (temCompr && corteCm != somaCm) ...[
                              Text('  →  ', style: AppCss.minimumRegular.setColor(Colors.grey[400]!).setSize(11)),
                              Icon(Icons.content_cut, size: 11, color: const Color(0xFFF59E0B)),
                              const SizedBox(width: 3),
                              Text('${corteCm}cm', style: AppCss.minimumBold.setColor(const Color(0xFFF59E0B)).setSize(11)),
                            ],
                          ]);
                        }),
                        const SizedBox(height: 3),
                        Row(children: [
                          Icon(Icons.scale_outlined, size: 12, color: _pesoTotalPosicao(p) > 0 ? const Color(0xFF10B981) : Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(
                            _temVariavel(p)
                                ? 'Unit: var • Total: ${_formatPeso(_pesoTotalPosicao(p))} kg'
                                : 'Unit: ${_formatPeso(_pesoUnitPosicao(p))} • Total: ${_formatPeso(_pesoTotalPosicao(p))} kg',
                            style: AppCss.minimumRegular.setColor(_pesoTotalPosicao(p) > 0 ? const Color(0xFF10B981) : Colors.grey[400]!).setSize(11),
                          ),
                        ]),
                      ])),
                      if (!_isRO) InkWell(onTap: () async {
                        if (await showConfirmDialog('Excluir posição?', 'Posição ${p.posicao.text} será removida.')) {
                          final posId = p.id;
                          elem.posicoes.remove(p);
                          planilhaCtrl.formStream.update();
                          _atualizarPesoElementoAtual();
                          _atualizarPesoTotal(planilhaCtrl.form);
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

  Widget _campoBitola() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Bitola (cód / F2):', style: AppCss.smallBold),
      const SizedBox(height: 4),
      TextField(
        controller: _bitolaCtrl, focusNode: _fnBitola,
        style: AppCss.smallRegular,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          hintText: 'Cód ou F2',
          suffixIcon: _pBitola != null ? const Icon(Icons.check_circle, color: Colors.green, size: 18) : null,
        ),
        onSubmitted: (_) {
          if (_validarBitola()) {
            _fnForma.requestFocus();
          } else {
            // Código errado ou vazio: seleciona o texto, não pula de campo, e abre a busca
            _fnBitola.requestFocus();
            _bitolaCtrl.selection = TextSelection(baseOffset: 0, extentOffset: _bitolaCtrl.text.length);
            Future.microtask(() => _abrirBuscaBitola());
          }
        },
      ),

    ]);
  }

  Widget _campoForma() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Forma (cód / F2):', style: AppCss.smallBold),
      const SizedBox(height: 4),
      TextField(
        controller: _formaCtrl, focusNode: _fnForma,
        style: AppCss.smallRegular,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          hintText: 'Cód ou F2',
          suffixIcon: _pForma != null ? const Icon(Icons.check_circle, color: Colors.green, size: 18) : null,
        ),
        onSubmitted: (_) {
          if (_validarForma()) {
            _pQtde.text = '1';
            _pQtde.focus.requestFocus();
            _pQtde.controller.selection = const TextSelection(baseOffset: 0, extentOffset: 1);
          } else {
            // Código errado ou vazio: não pula, seleciona o texto, abre a busca
            _fnForma.requestFocus();
            _formaCtrl.selection = TextSelection(baseOffset: 0, extentOffset: _formaCtrl.text.length);
            Future.microtask(() => _abrirBuscaForma());
          }
        },
      ),

    ]);
  }

  Future<void> _abrirModalBusca<T>({
    required String titulo,
    required List<T> itens,
    required String Function(T) tituloItem,
    required String Function(T) subtituloItem,
    required bool Function(T, String) filtro,
    required void Function(T) onSelected,
    Widget Function(T)? trailingBuilder,
    double itemHeight = 65.0, // estimativa de altura por item para auto-scroll
  }) async {
    String query = '';
    int navIdx = -1;
    final scrollCtrl = ScrollController();
    final fnSearch = FocusNode();
    final fnKeyboard = FocusNode();

    void scrollToIndex(int idx) {
      if (!scrollCtrl.hasClients || idx < 0) return;
      final offset = (idx * itemHeight).clamp(
        0.0,
        scrollCtrl.position.maxScrollExtent,
      );
      scrollCtrl.animateTo(
        offset,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    }

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtrados = itens.where((e) => filtro(e, query)).toList();

            void navegarLista(int delta) {
              final novoIdx = (navIdx + delta).clamp(-1, filtrados.length - 1);
              setModalState(() => navIdx = novoIdx);
              WidgetsBinding.instance.addPostFrameCallback((_) => scrollToIndex(novoIdx));
            }

            return KeyboardListener(
              focusNode: fnKeyboard,
              onKeyEvent: (event) {
                if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  navegarLista(1);
                } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  navegarLista(-1);
                } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                  Navigator.pop(context);
                } else if (event.logicalKey == LogicalKeyboardKey.enter) {
                  if (filtrados.isEmpty) return;
                  final item = navIdx >= 0 && navIdx < filtrados.length
                      ? filtrados[navIdx]
                      : filtrados.first;
                  Navigator.pop(context);
                  onSelected(item);
                }
              },
              child: AlertDialog(
                title: Text(titulo, style: AppCss.mediumBold),
                content: SizedBox(
                  width: 600,
                  height: 600,
                  child: Column(
                    children: [
                      TextField(
                        focusNode: fnSearch,
                        autofocus: true,
                        style: AppCss.smallRegular,
                        decoration: InputDecoration(
                          hintText: 'Digite para buscar • ↑↓ navegar • Enter selecionar',
                          prefixIcon: Icon(Icons.search, color: AppColors.primaryMain),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: AppColors.primaryMain, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (v) => setModalState(() { query = v; navIdx = -1; }),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: filtrados.isEmpty
                          ? Center(child: Text('Nenhum item encontrado',
                              style: AppCss.smallRegular.setColor(Colors.grey[400]!)))
                          : Scrollbar(
                              controller: scrollCtrl,
                              thumbVisibility: true,
                              child: ListView.separated(
                                controller: scrollCtrl,
                                itemCount: filtrados.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final item = filtrados[i];
                                  final destacado = i == navIdx;
                                  return InkWell(
                                    onTap: () {
                                      Navigator.pop(context);
                                      onSelected(item);
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 100),
                                      color: destacado
                                          ? AppColors.primaryMain.withValues(alpha: 0.08)
                                          : Colors.transparent,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(tituloItem(item),
                                                    style: AppCss.smallBold.setColor(
                                                      destacado ? AppColors.primaryMain : Colors.black87,
                                                    )),
                                                const SizedBox(height: 2),
                                                Text(subtituloItem(item),
                                                    style: AppCss.minimumRegular.setColor(Colors.grey[600]!)),
                                              ],
                                            ),
                                          ),
                                          if (trailingBuilder != null) ...[
                                            const SizedBox(width: 12),
                                            trailingBuilder(item),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancelar', style: AppCss.smallBold.setColor(Colors.grey[600]!)),
                  )
                ],
              ),
            );
          },
        );
      },
    );
    // Delay para aguardar animação de fechamento antes de liberar recursos
    Future.delayed(const Duration(milliseconds: 400), () {
      try { scrollCtrl.dispose(); } catch (_) {}
      try { fnSearch.dispose(); } catch (_) {}
      try { fnKeyboard.dispose(); } catch (_) {}
    });
  }

  void _abrirBuscaBitola() {
    _abrirModalBusca<ProdutoModel>(
      titulo: 'Buscar Bitola (F2)',
      itens: BackendClient.produtos.data,
      tituloItem: (p) => p.nome,
      subtituloItem: (p) => p.descricao,
      filtro: (p, q) => p.nome.toLowerCase().contains(q.toLowerCase()) || p.descricao.toLowerCase().contains(q.toLowerCase()),
      onSelected: (p) {
        _bitolaCtrl.text = p.nome;
        _validarBitola();
        _fnForma.requestFocus();
      },
    );
  }

  void _abrirBuscaForma() {
    _abrirModalBusca<FormaModel>(
      titulo: 'Buscar Forma (F2)',
      itens: BackendClient.formas.data,
      tituloItem: (f) => f.codigo,
      subtituloItem: (f) => f.descricao,
      filtro: (f, q) => f.codigo.toLowerCase().contains(q.toLowerCase()) || f.descricao.toLowerCase().contains(q.toLowerCase()),
      trailingBuilder: (f) {
        return Container(
          width: 150, height: 150,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: FormaPreviewWidget(
                itens: f.itens,
                height: 150,
                mostrarLegenda: false,
                mostrarVertices: false,
                rotacaoExterna: f.rotacao,
              ),
            ),
          ),
        );
      },
      onSelected: (f) {
        _formaCtrl.text = f.codigo;
        _validarForma();
        _pQtde.text = '1';
        _pQtde.focus.requestFocus();
        _pQtde.controller.selection = const TextSelection(baseOffset: 0, extentOffset: 1);
      },
      itemHeight: 180,
    );
  }

  bool _validarBitola() {
    final cod = _bitolaCtrl.text.trim();
    if (cod.isEmpty) { setState(() => _pBitola = null); return false; }
    final match = BackendClient.produtos.data.where((b) =>
        b.nome.toLowerCase() == cod.toLowerCase() || b.descricao.toLowerCase() == cod.toLowerCase()).firstOrNull;
    setState(() {
      _pBitola = match;
      if (match != null && _posicaoSelecionada != null) _posicaoModificada = true;
    });
    if (match == null) return false;
    return true;
  }

  bool _validarForma() {
    final cod = _formaCtrl.text.trim();
    if (cod.isEmpty) { 
      setState(() {
        _pForma = null;
        _formaSelecionada = null;
      });
      _atualizarCompCtrls(null, posicao: _posicaoSelecionada);
      return false; 
    }
    final match = BackendClient.formas.data.where((f) => f.codigo.toLowerCase() == cod.toLowerCase()).firstOrNull;
    setState(() {
      _pForma = match;
      _formaSelecionada = match;
      if (match != null && _posicaoSelecionada != null) _posicaoModificada = true;
    });
    _atualizarCompCtrls(match, posicao: _posicaoSelecionada);
    if (match == null) {
      return false;
    }
    return true;
  }

  void _addPos(ElementoCreateModel elem) async {
    if (_pNum.text.trim().isEmpty) return;
    // Validar campos obrigatórios
    if (_pBitola == null) {
      NotificationService.showNegative('Bitola obrigatória', 'Informe a bitola antes de continuar', position: NotificationPosition.bottom);
      _fnBitola.requestFocus();
      return;
    }
    if (_pForma == null) {
      NotificationService.showNegative('Forma obrigatória', 'Informe a forma antes de continuar', position: NotificationPosition.bottom);
      _fnForma.requestFocus();
      return;
    }
    final num = int.tryParse(_pNum.text) ?? 0;
    
    // Se posição com esse número já existe e não está em edição, bloquear
    final posExistente = elem.posicoes.where((p) => (int.tryParse(p.posicao.text) ?? -1) == num).firstOrNull;
    if (posExistente != null && _posicaoSelecionada == null) {
      NotificationService.showNegative('Posição já existe', 'Clique na posição $num para editá-la', position: NotificationPosition.bottom);
      return;
    }
    if (posExistente != null && _posicaoSelecionada != null) {
      posExistente.bitolaSelecionada = _pBitola;
      
      // Se trocou a forma, zera os comprimentos e variáveis
      if (posExistente.formaSelecionada?.codigo != _pForma!.codigo) {
        posExistente.formaSelecionada = _pForma;
        posExistente.comprimentos.clear();
        posExistente.variaveis.clear();
      }
      
      posExistente.qtde.text = _pQtde.text.isEmpty ? '1' : _pQtde.text;
      // Recalcula comprimento de corte com bitola/forma atualizados
      posExistente.calcularComprimentoDeCorte();
      
      _limparPos();
      planilhaCtrl.formStream.update();
      
      _atualizarCompCtrls(posExistente.formaSelecionada, posicao: posExistente);
      setState(() => _formaSelecionada = posExistente.formaSelecionada);
      
      if (_compFns.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 100), () => _compFns.first.requestFocus());
      }
      
      // Auto-save update + atualiza pesos
      final elemId = _elementoDbIds[_elemIdx];
      if (elemId != null && posExistente.id.length == 36) {
        await planilhaCtrl.adicionarPosicaoAtualizada(posExistente, elemId);
      }
      _atualizarPesoElementoAtual();
      _atualizarPesoTotal(planilhaCtrl.form);
      return;
    }
    final n = PosicaoCreateModel();
    n.posicao.text = _pNum.text;
    n.bitolaSelecionada = _pBitola;
    n.formaSelecionada = _pForma;
    n.qtde.text = _pQtde.text.isEmpty ? '1' : _pQtde.text;
    n.calcularComprimentoDeCorte(); // calcula com os dados da forma e bitola
    elem.posicoes.add(n);
    _limparPos();
    planilhaCtrl.formStream.update();

    // Seleciona automaticamente a posição criada
    _atualizarCompCtrls(n.formaSelecionada, posicao: n);
    setState(() => _formaSelecionada = n.formaSelecionada);

    // Foca o primeiro campo de trecho da tela direita
    if (_compFns.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _compFns.first.requestFocus();
      });
    }

    // Auto-save posição + atualiza pesos
    final elemId = _elementoDbIds[_elemIdx];
    if (elemId != null) {
      final dbId = await planilhaCtrl.adicionarPosicao(n, elemId);
      if (dbId != null) n.id = dbId;
    }
    _atualizarPesoElementoAtual();
    _atualizarPesoTotal(planilhaCtrl.form);
  }

  void _selecionarPosicao(PosicaoCreateModel p) {
    _pNum.text = p.posicao.text;
    _pBitola = p.bitolaSelecionada;
    _bitolaCtrl.text = p.bitolaSelecionada?.nome ?? '';
    _pForma = p.formaSelecionada;
    _formaCtrl.text = p.formaSelecionada?.codigo ?? '';
    _pQtde.text = p.qtde.text;
    _atualizarCompCtrls(p.formaSelecionada, posicao: p);
    setState(() {
      _formaSelecionada = p.formaSelecionada;
      _posicaoModificada = false;
    });
  }

  void _limparPos() {
    _pNum.text = ''; _bitolaCtrl.text = ''; _formaCtrl.text = ''; _pQtde.text = '';
    setState(() { _pBitola = null; _pForma = null; _posicaoModificada = false; });
  }

  void _salvarComprimento(int idx, FormaModel forma) {
    if (_posicaoSelecionada == null) return;
    if (idx >= forma.itens.length || idx >= _compCtrls.length) return;
    final item = forma.itens[idx];
    final trecho = item.trecho;

    // Se o trecho é variável, não processa aqui (gerenciado pelo painel)
    final isVar = _posicaoSelecionada!.variaveis[trecho] ?? false;
    if (isVar) return;

    final valor = int.tryParse(_compCtrls[idx].text);

    // Salva o trecho atual
    if (valor != null) {
      _posicaoSelecionada!.comprimentos[trecho] = valor;
    } else {
      _posicaoSelecionada!.comprimentos.remove(trecho);
    }

    // Propaga para trechos do mesmo grupo de simetria
    final grupo = item.grupoSimetria;
    if (grupo.isNotEmpty) {
      for (int j = 0; j < forma.itens.length; j++) {
        if (j == idx) continue;
        if (forma.itens[j].grupoSimetria == grupo) {
          final trechoJ = forma.itens[j].trecho;
          // Não sobrescreve followers variáveis
          if (_posicaoSelecionada!.variaveis[trechoJ] ?? false) continue;
          if (valor != null) {
            _posicaoSelecionada!.comprimentos[trechoJ] = valor;
          } else {
            _posicaoSelecionada!.comprimentos.remove(trechoJ);
          }
          // Sincroniza o controller visual
          if (j < _compCtrls.length) {
            _compCtrls[j].text = valor?.toString() ?? '';
          }
        }
      }
    }

    // Recalcula comprimento de corte
    _posicaoSelecionada!.calcularComprimentoDeCorte();
    // Auto-save: atualizar posição no banco
    final elemId = _elementoDbIds[_elemIdx];
    if (elemId != null && _posicaoSelecionada!.id.length == 36) {
      planilhaCtrl.adicionarPosicaoAtualizada(_posicaoSelecionada!, elemId);
    }
    // Atualizar pesos no banco
    setState(() {});
    planilhaCtrl.formStream.update();
    _atualizarPesoElementoAtual();
    _atualizarPesoTotal(planilhaCtrl.form);
  }

  // ── COL 3: Preview Forma ───────────────────────────────
  Widget _col3() {
    // Usa forma da posição selecionada ou do formulário
    final forma = _formaSelecionada ?? _pForma;
    if (forma == null) return _empty('Selecione uma forma\npara ver o desenho', Icons.architecture_outlined);

    // Legendas customizadas: comprimento digitado ou trecho original
    final legendasCustom = List.generate(forma.itens.length, (i) {
      final trecho = forma.itens[i].trecho;
      // Trecho variável: exibe "var X a Y"
      if (_posicaoSelecionada != null) {
        final isVar = _posicaoSelecionada!.variaveis[trecho] ?? false;
        if (isVar) {
          // Busca config: própria ou do líder do grupo
          TrechoVariavelConfig? cfg;
          if (_posicaoSelecionada!.variaveisConfig.containsKey(trecho)) {
            cfg = _posicaoSelecionada!.variaveisConfig[trecho]!;
          } else {
            // Follower: busca config do líder do mesmo grupo
            final grupo = forma.itens[i].grupoSimetria;
            if (grupo.isNotEmpty) {
              final lider = forma.itens.firstWhere(
                  (x) => x.grupoSimetria == grupo && _posicaoSelecionada!.variaveisConfig.containsKey(x.trecho),
                  orElse: () => forma.itens[i]);
              cfg = _posicaoSelecionada!.variaveisConfig[lider.trecho];
            }
          }
          if (cfg != null && cfg.inicial > 0 && cfg.final_ > 0) {
            return 'var ${cfg.inicial} a ${cfg.final_}';
          }
        }
      }
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
                SizedBox(width: 44, child: Center(child: Text('Trecho', style: AppCss.minimumBold.setColor(Colors.grey[500]!).setSize(10)))),
                const SizedBox(width: 8),
                SizedBox(width: 80, child: Center(child: Text('Comp.', style: AppCss.minimumBold.setColor(Colors.grey[500]!).setSize(10)))),
                const SizedBox(width: 8),
                Expanded(child: Center(child: Text('Var.', style: AppCss.minimumBold.setColor(Colors.grey[500]!).setSize(10)))),
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

                        // ── Lógica de grupo de simetria ──────────────────────
                        final grupo = t.grupoSimetria;
                        bool isFollower = false;
                        String liderTrecho = '';
                        if (grupo.isNotEmpty) {
                          // O líder é o primeiro item da lista com esse grupo
                          final liderIdx = forma.itens.indexWhere((x) => x.grupoSimetria == grupo);
                          isFollower = liderIdx != i;
                          liderTrecho = isFollower ? forma.itens[liderIdx].trecho : '';
                        }

                        // Cor do grupo para badge
                        Color? grupoCor;
                        if (grupo.isNotEmpty) {
                          switch (grupo) {
                            case 'A': grupoCor = const Color(0xFF6366F1); break;
                            case 'B': grupoCor = const Color(0xFFF59E0B); break;
                            case 'C': grupoCor = const Color(0xFF10B981); break;
                            case 'D': grupoCor = const Color(0xFFEC4899); break;
                          }
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: isFollower ? Colors.grey[50] : Colors.white,
                            border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                            // Badge do trecho (com cor do grupo se houver)
                            SizedBox(
                              width: 44,
                              child: Center(
                                child: Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                    color: grupoCor != null
                                        ? grupoCor.withValues(alpha: 0.12)
                                        : AppColors.primaryMain.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: grupoCor != null
                                        ? Border.all(color: grupoCor.withValues(alpha: 0.4), width: 1)
                                        : null,
                                  ),
                                  child: Center(child: Text(t.trecho,
                                      style: AppCss.minimumBold.setColor(
                                        grupoCor ?? AppColors.primaryMain).setSize(11))),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Transform.translate(
                              offset: const Offset(0, 6),
                              child: SizedBox(
                                width: 80,
                                height: 34,
                                child: Builder(builder: (_) {
                                  // Determina se é variável e busca config (própria ou do líder)
                                  final bloqueado = isFollower || isVariavel;
                                  TrechoVariavelConfig? varCfg;
                                  if (isVariavel && _posicaoSelecionada != null) {
                                    varCfg = _posicaoSelecionada!.variaveisConfig[trecho];
                                    if (varCfg == null && grupo.isNotEmpty) {
                                      final lider = forma.itens.firstWhere(
                                          (x) => x.grupoSimetria == grupo && _posicaoSelecionada!.variaveisConfig.containsKey(x.trecho),
                                          orElse: () => forma.itens[i]);
                                      varCfg = _posicaoSelecionada!.variaveisConfig[lider.trecho];
                                    }
                                  }
                                  // Atualiza controller com "X var Y" se variável
                                  if (varCfg != null && varCfg.inicial > 0 && varCfg.final_ > 0 && i < _compCtrls.length) {
                                    final varText = '${varCfg.inicial} var ${varCfg.final_}';
                                    if (_compCtrls[i].text != varText) {
                                      _compCtrls[i].text = varText;
                                    }
                                  }
                                  return TextField(
                                controller: i < _compCtrls.length ? _compCtrls[i] : null,
                                focusNode: i < _compFns.length ? _compFns[i] : null,
                                readOnly: bloqueado || _isRO,
                                keyboardType: TextInputType.number,
                                inputFormatters: isVariavel ? [] : [FilteringTextInputFormatter.digitsOnly],
                                style: AppCss.smallBold.setSize(isVariavel ? 10 : 13).setColor(
                                  isVariavel ? Colors.orange[800]! : (isFollower ? Colors.grey[500]! : Colors.black87)),
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: isVariavel ? Colors.orange.withValues(alpha: 0.08) : (isFollower ? Colors.grey[100] : Colors.grey[50]),
                                  hintText: isFollower && liderTrecho.isNotEmpty ? '= $liderTrecho' : null,
                                  hintStyle: AppCss.minimumRegular.setColor(Colors.grey[400]!).setSize(11),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                  isDense: true,
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isVariavel ? Colors.orange.withValues(alpha: 0.4) : (isFollower ? Colors.grey[200]! : Colors.grey[300]!))),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: bloqueado ? Colors.grey[300]! : AppColors.primaryMain, width: 1.5)),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onChanged: isFollower ? null : (_) => setState(() {}),
                                onSubmitted: (_) {
                                  _salvarComprimento(i, forma);
                                  // Enter pula para o próximo trecho (líder pula followers, follower vai sequencial)
                                  int next = i + 1;
                                  if (!isFollower) {
                                    // Líder: pula followers do mesmo grupo
                                    while (next < forma.itens.length) {
                                      final ng = forma.itens[next].grupoSimetria;
                                      final isNextFollower = ng.isNotEmpty &&
                                          forma.itens.indexWhere((x) => x.grupoSimetria == ng) != next;
                                      if (!isNextFollower) break;
                                      next++;
                                    }
                                  }
                                  if (next < _compFns.length) {
                                    _compFns[next].requestFocus();
                                    _compCtrls[next].selection = TextSelection(baseOffset: 0, extentOffset: _compCtrls[next].text.length);
                                  } else {
                                    _salvarComprimento(i, forma);
                                    final posParaSalvar = _posicaoSelecionada;
                                    final elemId = _elementoDbIds[_elemIdx];
                                    if (posParaSalvar != null && elemId != null && posParaSalvar.id.length == 36) {
                                      planilhaCtrl.adicionarPosicaoAtualizada(posParaSalvar, elemId);
                                    }
                                    _atualizarCompCtrls(null);
                                    setState(() {
                                      _formaSelecionada = null;
                                      _posicaoSelecionada = null;
                                      _posicaoModificada = false;
                                      _pBitola = null;
                                      _pForma = null;
                                    });
                                    Future.delayed(const Duration(milliseconds: 150), () {
                                      if (!mounted) return;
                                      _pNum.text = '';
                                      _bitolaCtrl.clear();
                                      _formaCtrl.clear();
                                      _pQtde.text = '';
                                      _pNum.focus.requestFocus();
                                    });
                                  }
                                },
                              );
                             }),
                            ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Center(
                                child: SizedBox(
                                  width: 24, height: 24,
                                  child: Checkbox(
                                    value: isVariavel,
                                    activeColor: isFollower ? Colors.grey[400] : AppColors.primaryMain,
                                    onChanged: _isRO || _posicaoSelecionada == null || isFollower ? null : (v) {
                                      setState(() {
                                        final marcado = v ?? false;
                                        _posicaoSelecionada!.variaveis[trecho] = marcado;
                                        // Propaga para followers do mesmo grupo
                                        if (grupo.isNotEmpty) {
                                          for (final item in forma.itens) {
                                            if (item.grupoSimetria == grupo && item.trecho != trecho) {
                                              _posicaoSelecionada!.variaveis[item.trecho] = marcado;
                                              if (!marcado) {
                                                _posicaoSelecionada!.variaveisConfig.remove(item.trecho);
                                              }
                                            }
                                          }
                                        }
                                        if (marcado) {
                                          _trechoVarIdx = i;
                                          if (!_posicaoSelecionada!.variaveisConfig.containsKey(trecho)) {
                                            _posicaoSelecionada!.variaveisConfig[trecho] = TrechoVariavelConfig();
                                          }
                                        } else {
                                          _posicaoSelecionada!.variaveisConfig.remove(trecho);
                                          _posicaoSelecionada!.comprimentos.remove(trecho);
                                          if (i < _compCtrls.length) _compCtrls[i].text = '';
                                          // Zera followers do grupo
                                          if (grupo.isNotEmpty) {
                                            for (int j = 0; j < forma.itens.length; j++) {
                                              final item = forma.itens[j];
                                              if (item.grupoSimetria == grupo && item.trecho != trecho) {
                                                _posicaoSelecionada!.comprimentos.remove(item.trecho);
                                                if (j < _compCtrls.length) _compCtrls[j].text = '';
                                              }
                                            }
                                          }
                                          if (_trechoVarIdx == i) _trechoVarIdx = -1;
                                        }
                                      });
                                      // Auto-save
                                      final elemId = _elementoDbIds[_elemIdx];
                                      if (elemId != null && _posicaoSelecionada!.id.length == 36) {
                                        planilhaCtrl.adicionarPosicaoAtualizada(_posicaoSelecionada!, elemId);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                            // Botão de abrir painel variável (espaço fixo)
                            SizedBox(
                              width: 24, height: 24,
                              child: isVariavel
                                  ? GestureDetector(
                                      onTap: () {
                                        setState(() => _trechoVarIdx = i);
                                        Future.delayed(const Duration(milliseconds: 100), () {
                                          _varInicialFn.requestFocus();
                                          if (_varInicialCtrl.text.isNotEmpty) {
                                            _varInicialCtrl.selection = TextSelection(
                                                baseOffset: 0, extentOffset: _varInicialCtrl.text.length);
                                          }
                                        });
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: _trechoVarIdx == i
                                              ? AppColors.primaryMain.withValues(alpha: 0.15)
                                              : Colors.orange.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: _trechoVarIdx == i
                                                ? AppColors.primaryMain
                                                : Colors.orange.withValues(alpha: 0.4),
                                            width: _trechoVarIdx == i ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Icon(Icons.unfold_more, size: 14,
                                            color: _trechoVarIdx == i ? AppColors.primaryMain : Colors.orange[700]),
                                      ),
                                    )
                                  : null,
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
          // ── Painel de configuração do trecho variável ──
          Expanded(flex: 2, child: _painelVariavel(forma)),
        ]),
      ),
    ]);
  }

  // ── Painel lateral de variável ──────────────────────────────
  Widget _painelVariavel(FormaModel forma) {
    if (_trechoVarIdx < 0 ||
        _trechoVarIdx >= forma.itens.length ||
        _posicaoSelecionada == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.unfold_more, size: 32, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text('Marque "Var." e clique ⇕\npara configurar variação',
              textAlign: TextAlign.center,
              style: AppCss.minimumRegular.setColor(Colors.grey[400]!).setSize(11)),
        ]),
      );
    }

    final trecho = forma.itens[_trechoVarIdx].trecho;
    final isVar = _posicaoSelecionada!.variaveis[trecho] ?? false;
    if (!isVar) {
      return Center(
        child: Text('Trecho $trecho não é variável',
            style: AppCss.minimumRegular.setColor(Colors.grey[400]!)),
      );
    }

    // Se é follower, redireciona para o líder do grupo
    String trechoConfig = trecho;
    bool isFollowerVar = false;
    final grupoVar = forma.itens[_trechoVarIdx].grupoSimetria;
    if (grupoVar.isNotEmpty) {
      final liderIdx = forma.itens.indexWhere((x) => x.grupoSimetria == grupoVar);
      if (liderIdx >= 0) {
        trechoConfig = forma.itens[liderIdx].trecho;
        isFollowerVar = liderIdx != _trechoVarIdx;
      }
    }

    final config = _posicaoSelecionada!.variaveisConfig.putIfAbsent(
        trechoConfig, () => TrechoVariavelConfig());
    final qtde = int.tryParse(_posicaoSelecionada!.qtde.text) ?? 0;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.06),
          border: Border(bottom: BorderSide(color: Colors.orange.withValues(alpha: 0.2))),
        ),
        child: Row(children: [
          Icon(Icons.unfold_more, size: 16, color: Colors.orange[700]),
          const SizedBox(width: 6),
          Text('$trechoConfig — Variação', style: AppCss.smallBold.setColor(Colors.orange[800]!).setSize(12)),
          const Spacer(),
          if (qtde > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('$qtde pç', style: AppCss.minimumBold.setColor(Colors.orange[700]!).setSize(10)),
            ),
        ]),
      ),

      // Campos: Inicial / Final
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Builder(builder: (_) {
          // Atualiza controllers com valores atuais
          if (_varInicialCtrl.text != (config.inicial > 0 ? config.inicial.toString() : '')) {
            _varInicialCtrl.text = config.inicial > 0 ? config.inicial.toString() : '';
          }
          if (_varFinalCtrl.text != (config.final_ > 0 ? config.final_.toString() : '')) {
            _varFinalCtrl.text = config.final_ > 0 ? config.final_.toString() : '';
          }
          final mult = _posicaoSelecionada!.multiplicador;
          if (_varMultCtrl.text != (mult > 0 ? mult.toString() : '')) {
            _varMultCtrl.text = mult > 0 ? mult.toString() : '';
          }
          return Row(children: [
            Expanded(child: _varField('Inicial', _varInicialCtrl, focusNode: isFollowerVar ? null : _varInicialFn, nextFocus: isFollowerVar ? null : _varFinalFn, nextCtrl: _varFinalCtrl, readOnly: isFollowerVar || _isRO, onChanged: (v) {
              config.inicial = v;
              _recalcularVariavel(config, qtde, trechoConfig);
            })),
            const SizedBox(width: 8),
            Expanded(child: _varField('Final', _varFinalCtrl, focusNode: isFollowerVar ? null : _varFinalFn, nextFocus: isFollowerVar ? null : _varMultFn, nextCtrl: _varMultCtrl, readOnly: isFollowerVar || _isRO, onChanged: (v) {
              config.final_ = v;
              _recalcularVariavel(config, qtde, trechoConfig);
            })),
          ]);
        }),
      ),

      // Multiplicador
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(children: [
          Expanded(child: _varField('Multiplicador', _varMultCtrl, focusNode: isFollowerVar ? null : _varMultFn, readOnly: isFollowerVar || _isRO, onChanged: (v) {
            _posicaoSelecionada!.multiplicador = v.clamp(1, 100);
            // Recalcula todos os trechos variáveis da posição
            for (final entry in _posicaoSelecionada!.variaveisConfig.entries) {
              final cfg = entry.value;
              if (cfg.inicial > 0 && cfg.final_ > 0 && cfg.distribuicao == 'linear') {
                cfg.gerarLinear(qtde, multiplicador: _posicaoSelecionada!.multiplicador);
              }
            }
            _salvarConfigVariavel(trechoConfig);
            setState(() {});
          })),
          const SizedBox(width: 8),
          // Toggle linear/manual
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Distribuição', style: AppCss.minimumRegular.setColor(Colors.grey[500]!).setSize(10)),
                const SizedBox(height: 4),
                Row(children: [
                  _distBtn('Linear', config.distribuicao == 'linear', isFollowerVar || _isRO ? null : () {
                    config.distribuicao = 'linear';
                    _recalcularVariavel(config, qtde, trechoConfig);
                  }),
                  const SizedBox(width: 4),
                  _distBtn('Manual', config.distribuicao == 'manual', isFollowerVar || _isRO ? null : () {
                    setState(() => config.distribuicao = 'manual');
                    _atualizarManualCtrls(config.medidas);
                    if (config.medidas.isNotEmpty) {
                      Future.delayed(const Duration(milliseconds: 150), () {
                        if (_manualFns.isNotEmpty) {
                          _manualFns[0].requestFocus();
                          if (_manualCtrls[0].text.isNotEmpty) {
                            _manualCtrls[0].selection = TextSelection(
                                baseOffset: 0, extentOffset: _manualCtrls[0].text.length);
                          }
                        }
                      });
                    }
                  }),
                ]),
              ],
            ),
          ),
        ]),
      ),

      // Validação
      if (qtde > 0 && _posicaoSelecionada!.multiplicador > 1 && qtde % _posicaoSelecionada!.multiplicador != 0)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red[400]),
              const SizedBox(width: 4),
              Expanded(child: Text(
                'Qtde ($qtde) não é divisível por multiplicador (${_posicaoSelecionada!.multiplicador})',
                style: AppCss.minimumRegular.setColor(Colors.red[600]!).setSize(10),
              )),
            ]),
          ),
        ),

      const SizedBox(height: 6),

      // Divisor
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          Expanded(child: Divider(color: Colors.grey[200])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              config.medidas.isEmpty
                  ? 'Preencha inicial e final'
                  : '${config.medidas.length} medida(s)${_posicaoSelecionada!.multiplicador > 1 ? ' × ${_posicaoSelecionada!.multiplicador}' : ''}',
              style: AppCss.minimumBold.setColor(Colors.grey[400]!).setSize(10),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey[200])),
        ]),
      ),

      const SizedBox(height: 4),

      // Lista de medidas
      Expanded(
        child: config.medidas.isEmpty
            ? Center(child: Text('Sem medidas', style: AppCss.minimumRegular.setColor(Colors.grey[300]!)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: config.medidas.length,
                itemBuilder: (_, i) {
                  final isManual = config.distribuicao == 'manual';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: i.isEven ? Colors.grey[50] : Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(children: [
                      SizedBox(
                        width: 28,
                        child: Text('#${i + 1}',
                            style: AppCss.minimumRegular.setColor(Colors.grey[400]!).setSize(10)),
                      ),
                      if (isManual && !isFollowerVar && !_isRO)
                        SizedBox(
                          width: 60,
                          height: 26,
                          child: TextField(
                            controller: i < _manualCtrls.length ? _manualCtrls[i] : null,
                            focusNode: i < _manualFns.length ? _manualFns[i] : null,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            textAlign: TextAlign.center,
                            style: AppCss.minimumBold.setSize(11),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                              isDense: true,
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: BorderSide(color: Colors.grey[300]!)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(color: Colors.orange, width: 1.5)),
                            ),
                            onTap: () {
                              if (i < _manualCtrls.length && _manualCtrls[i].text.isNotEmpty) {
                                _manualCtrls[i].selection = TextSelection(
                                    baseOffset: 0, extentOffset: _manualCtrls[i].text.length);
                              }
                            },
                            onSubmitted: (val) {
                              final v = int.tryParse(val);
                              if (v != null && v > 0) {
                                setState(() => config.medidas[i] = v);
                                _salvarConfigVariavel(trechoConfig);
                              }
                              // Enter → próximo campo
                              final next = i + 1;
                              if (next < _manualFns.length) {
                                _manualFns[next].requestFocus();
                                Future.microtask(() {
                                  if (next < _manualCtrls.length && _manualCtrls[next].text.isNotEmpty) {
                                    _manualCtrls[next].selection = TextSelection(
                                        baseOffset: 0, extentOffset: _manualCtrls[next].text.length);
                                  }
                                });
                              }
                            },
                          ),
                        )
                      else
                        Text('${config.medidas[i]}',
                            style: AppCss.minimumBold.setColor(Colors.grey[700]!).setSize(12)),
                      const SizedBox(width: 6),
                      Text('cm', style: AppCss.minimumRegular.setColor(Colors.grey[400]!).setSize(10)),
                      if (_posicaoSelecionada!.multiplicador > 1) ...[
                        const Spacer(),
                        Text('× ${_posicaoSelecionada!.multiplicador}',
                            style: AppCss.minimumRegular.setColor(Colors.orange[600]!).setSize(10)),
                      ],
                    ]),
                  );
                },
              ),
      ),
    ]);
  }

  Widget _varField(String label, TextEditingController ctrl, {FocusNode? focusNode, FocusNode? nextFocus, TextEditingController? nextCtrl, bool readOnly = false, required void Function(int) onChanged}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppCss.minimumRegular.setColor(Colors.grey[500]!).setSize(10)),
      const SizedBox(height: 4),
      SizedBox(
        height: 30,
        child: TextField(
          controller: ctrl,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          readOnly: readOnly,
          style: AppCss.smallBold.setSize(12).setColor(readOnly ? Colors.grey[500]! : Colors.black87),
          decoration: InputDecoration(
            filled: true,
            fillColor: readOnly ? Colors.grey[100] : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
            isDense: true,
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey[300]!)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Colors.orange, width: 1.5)),
          ),
          onTap: () {
            if (ctrl.text.isNotEmpty) {
              ctrl.selection = TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);
            }
          },
          onSubmitted: (val) {
            final v = int.tryParse(val) ?? 0;
            onChanged(v);
            if (nextFocus != null) {
              nextFocus.requestFocus();
              // Seleciona conteúdo do próximo campo
              if (nextCtrl != null && nextCtrl.text.isNotEmpty) {
                Future.microtask(() {
                  nextCtrl.selection = TextSelection(baseOffset: 0, extentOffset: nextCtrl.text.length);
                });
              }
            }
          },
        ),
      ),
    ]);
  }

  Widget _distBtn(String label, bool ativo, VoidCallback? onTap) {
    final desabilitado = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: desabilitado ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: ativo ? Colors.orange.withValues(alpha: 0.15) : Colors.grey[100],
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: ativo ? Colors.orange : Colors.grey[300]!,
              width: ativo ? 1.5 : 1,
            ),
          ),
          child: Text(label,
              style: AppCss.minimumBold
                  .setColor(ativo ? Colors.orange[800]! : Colors.grey[500]!)
                  .setSize(10)),
        ),
      ),
    );
  }

  void _recalcularVariavel(TrechoVariavelConfig config, int qtde, String trecho) {
    if (config.inicial <= 0 || config.final_ <= 0 || qtde <= 0) {
      setState(() => config.medidas = []);
      return;
    }
    final mult = _posicaoSelecionada?.multiplicador ?? 1;
    config.gerarLinear(qtde, multiplicador: mult);

    // Atualiza controller do líder com "X var Y"
    final forma = _formaSelecionada ?? _pForma;
    if (forma != null) {
      final idx = forma.itens.indexWhere((x) => x.trecho == trecho);
      if (idx >= 0 && idx < _compCtrls.length) {
        _compCtrls[idx].text = '${config.inicial} var ${config.final_}';
      }
    }

    setState(() {});
    _atualizarManualCtrls(config.medidas);
    _salvarConfigVariavel(trecho);
  }

  void _salvarConfigVariavel(String trecho) {
    if (_posicaoSelecionada == null) return;
    // Atualiza o comprimento base com o valor inicial
    final config = _posicaoSelecionada!.variaveisConfig[trecho];
    if (config != null && config.inicial > 0) {
      _posicaoSelecionada!.comprimentos[trecho] = config.inicial;
    }

    // Sincroniza followers do mesmo grupo de simetria
    final forma = _formaSelecionada ?? _pForma;
    if (forma != null && config != null) {
      final liderItem = forma.itens.firstWhere((x) => x.trecho == trecho, orElse: () => forma.itens.first);
      final grupo = liderItem.grupoSimetria;
      if (grupo.isNotEmpty) {
        final varText = config.inicial > 0 && config.final_ > 0
            ? '${config.inicial} var ${config.final_}' : '';
        for (int j = 0; j < forma.itens.length; j++) {
          final item = forma.itens[j];
          if (item.grupoSimetria == grupo && item.trecho != trecho) {
            // Atualiza comprimento do follower
            if (config.inicial > 0) {
              _posicaoSelecionada!.comprimentos[item.trecho] = config.inicial;
            }
            // Atualiza controller visual do follower
            if (j < _compCtrls.length && varText.isNotEmpty) {
              _compCtrls[j].text = varText;
            }
          }
        }
      }
    }

    _posicaoSelecionada!.calcularComprimentoDeCorte();
    final elemId = _elementoDbIds[_elemIdx];
    if (elemId != null && _posicaoSelecionada!.id.length == 36) {
      planilhaCtrl.adicionarPosicaoAtualizada(_posicaoSelecionada!, elemId);
    }
    planilhaCtrl.formStream.update();
    _atualizarPesoElementoAtual();
    _atualizarPesoTotal(planilhaCtrl.form);
  }

  Widget _planilhamentoIaContent(PlanilhaCreateModel form) {
    return StreamOut<PlanilhamentoIaState>(
      stream: planilhamentoIaCtrl.stateStream.listen,
      builder: (_, state) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // -- Header --
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryMain.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.auto_awesome, color: AppColors.primaryMain, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Planilhamento IA', style: AppCss.largeBold.setColor(AppColors.primaryMain)),
                          Text('Importe elementos processados por IA diretamente para esta planilha.', style: AppCss.minimumRegular.setColor(Colors.grey[600]!).setSize(14)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // -- Informações do vínculo --
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('1. Vínculo do Projeto', style: AppCss.mediumBold.setColor(const Color(0xFF1E293B))),
                        const SizedBox(height: 8),
                        Text(
                          'Cliente: ${form.clienteSelecionado?.nome ?? "-"}\nObra: ${form.obraSelecionada?.descricao ?? "-"}',
                          style: AppCss.minimumRegular.setSize(14).setColor(Colors.grey[700]!),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // -- Upload Area --
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('2. Arquivo do Projeto', style: AppCss.mediumBold.setColor(const Color(0xFF1E293B))),
                          const SizedBox(height: 16),
                          Expanded(
                            child: _buildIaUploadArea(state, form),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIaUploadArea(PlanilhamentoIaState state, PlanilhaCreateModel form) {
    if (state.status == IaStatus.analyzing) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryMain.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: CircularProgressIndicator(
                color: AppColors.primaryMain,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Lendo projeto com IA...',
              style: AppCss.largeBold.setColor(const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            Text(
              'Arquivo: ${state.fileName}',
              style: AppCss.minimumRegular.setColor(const Color(0xFF64748B)).setSize(14),
            ),
            const SizedBox(height: 4),
            Text(
              'Extraindo posições, bitolas e formas estruturais. Isso pode levar alguns segundos.',
              style: AppCss.minimumRegular.setColor(Colors.grey[500]!).setSize(13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (state.status == IaStatus.success) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Projeto Processado com Sucesso!',
                      style: AppCss.largeBold.setColor(const Color(0xFF1E293B)),
                    ),
                    Text(
                      'A IA retornou o seguinte resultado bruto (JSON):',
                      style: AppCss.minimumRegular.setColor(const Color(0xFF64748B)).setSize(14),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final importado = await planilhamentoIaCtrl.importarParaPlanilhaAtual(context);
                  if (importado) {
                    setState(() {
                      _sel = _Sec.elementos;
                    });
                  }
                },
                icon: const Icon(Icons.download_done, size: 18),
                label: const Text('Confirmar Importação'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryMain,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: planilhamentoIaCtrl.reset,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Novo Arquivo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryMain,
                  side: BorderSide(color: AppColors.primaryMain),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: SingleChildScrollView(
                child: Text(
                  state.rawResult,
                  style: AppCss.minimumRegular.setColor(Colors.greenAccent).setSize(13).copyWith(fontFamily: 'monospace'),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final bool isReadyForUpload = form.clienteSelecionado != null && form.obraSelecionada != null;

    return InkWell(
      onTap: isReadyForUpload
          ? () {
              planilhamentoIaCtrl.setCliente(form.clienteSelecionado);
              planilhamentoIaCtrl.setObra(form.obraSelecionada);
              planilhamentoIaCtrl.pickFile();
            }
          : null,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isReadyForUpload ? const Color(0xFFF8FAFC) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isReadyForUpload ? const Color(0xFFCBD5E1) : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isReadyForUpload ? Colors.white : Colors.grey[200],
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (isReadyForUpload)
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
                  ],
                ),
                child: Icon(
                  Icons.upload_file_outlined,
                  size: 40,
                  color: isReadyForUpload ? AppColors.primaryMain : Colors.grey[400],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Clique para anexar o arquivo PDF aqui',
                style: AppCss.mediumBold.setColor(isReadyForUpload ? const Color(0xFF475569) : Colors.grey[500]!),
              ),
              const SizedBox(height: 8),
              Text(
                isReadyForUpload ? 'Suporte apenas para arquivos .pdf' : 'Selecione o Cliente e Obra primeiro',
                style: AppCss.minimumRegular.setColor(Colors.grey[500]!).setSize(13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
