import 'dart:convert';
import 'package:acoplan/app/core/services/supabase_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:acoplan/app/modules/detalhamento_ia/preparacao/preparacao_dxf_controller.dart';
import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/cliente_model.dart';
import 'package:acoplan/app/core/client/models/forma_model.dart';
import 'package:acoplan/app/core/client/models/detalhamento_model.dart';
import 'package:acoplan/app/core/client/models/bitola_model.dart';
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
import 'package:acoplan/app/modules/detalhamento/detalhamento_controller.dart';
import 'package:acoplan/app/modules/detalhamento/detalhamento_view_model.dart';
import 'package:acoplan/app/modules/forma/ui/forma_preview_widget.dart';
import 'package:acoplan/app/modules/detalhamento_ia/detalhamento_ia_controller.dart';
import 'package:acoplan/app/modules/detalhamento_ia/ui/ia_processing_widget.dart';
import 'package:acoplan/app/modules/detalhamento_ia/preparacao/ui/preparacao_dxf_widget.dart';
import 'package:acoplan/app/modules/detalhamento_ia/importacao/importacao_resultado.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:overlay_support/overlay_support.dart';

enum _Sec { dadosGerais, elementos, detalhamentoIA }

class DetalhamentoCreatePage extends StatefulWidget {
  final DetalhamentoModel? detalhamento;
  final bool isReadOnly;
  final bool skipInit;
  const DetalhamentoCreatePage({this.detalhamento, this.isReadOnly = false, this.skipInit = false, super.key});
  @override
  State<DetalhamentoCreatePage> createState() => _DetalhamentoCreatePageState();
}

class _DetalhamentoCreatePageState extends State<DetalhamentoCreatePage> {
  _Sec _sel = _Sec.dadosGerais;
  int _elemIdx = -1;
  int _excluindoElementoIdx = -1;
  bool get _isRO => widget.isReadOnly;

  // Elemento atual baseado no índice selecionado
  ElementoCreateModel? get _elemAtual =>
      _elemIdx >= 0 && _elemIdx < detalhamentoCtrl.form.elementos.length
          ? detalhamentoCtrl.form.elementos[_elemIdx]
          : null;

  // IDs reais do banco para cada elemento (indexado pela posição na lista)
  final Map<int, String> _elementoDbIds = {};

  // Posição selecionada (para mostrar desenho da forma)
  FormaModel? _formaSelecionada;
  PosicaoCreateModel? _posicaoSelecionada;
  bool _posicaoModificada = false;
  int _ultimaElemCount = 0; // Para detectar elementos novos via Realtime
  int _ultimaPosCount = 0; // Para detectar posições novas via Realtime
  DateTime _ultimoSaveComprimento = DateTime.fromMillisecondsSinceEpoch(0); // guard para não sobrescrever edição local

  // Scroll controllers para auto-scroll ao adicionar itens
  final ScrollController _elemScrollCtrl = ScrollController();
  final ScrollController _posScrollCtrl = ScrollController();

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

  /// Peso total do detalhamento = soma dos pesos totais de todos os elementos
  double _pesoTotalDetalhamento(DetalhamentoCreateModel form) {
    return form.elementos.fold<double>(0, (s, e) => s + _pesoTotalElemento(e));
  }

  /// Total de elementos considerando quantidade × (1 + equivalentes)
  int _totalElementosComEquivalentes(DetalhamentoCreateModel form) {
    return form.elementos.fold<int>(0, (s, e) => s + _qtdeTotalElemento(e));
  }

  /// Atualiza peso total da detalhamento no banco
  Future<void> _atualizarPesoTotal(DetalhamentoCreateModel form) async {
    final peso = _pesoTotalDetalhamento(form);
    await detalhamentoCtrl.atualizarPesoTotal(peso);
  }

  /// Atualiza peso do elemento atual no banco
  Future<void> _atualizarPesoElementoAtual() async {
    final elem = _elemAtual;
    final elemId = _elementoDbIds[_elemIdx];
    if (elem == null || elemId == null || elemId.length != 36) return;
    final peso = _pesoTotalElemento(elem);
    await detalhamentoCtrl.atualizarPesoElemento(elemId, peso);
  }

  // Elemento form
  final TextController _eNome = TextController();
  final TextController _eQtde = TextController();
  final TextController _eEquiv = TextController();
  List<String> _equivalentesTemp = [];
  int _editandoIdx = -1;
  bool _equivalentesExpandidos = true;
  bool _importacaoPendente = false;
  bool _salvandoImportacao = false;
  bool _elementoModificado = false;

  // Posição form
  final TextController _pNum = TextController();
  final TextController _pQtde = TextController();
  final _bitolaCtrl = TextEditingController();
  final _formaCtrl = TextEditingController();
  final _fnBitola = FocusNode();
  final _fnForma = FocusNode();
  BitolaModel? _pBitola;
  FormaModel? _pForma;
  String? _posicaoFocadaId;
  bool _editandoPosicao = false;


  @override
  void initState() {
    setWebTitle(widget.detalhamento != null ? 'Detalhamento' : 'Novo Detalhamento');
    if (!widget.skipInit) {
      detalhamentoCtrl.init(widget.detalhamento);
    }
    // Detectar modificações nos campos do elemento
    _eNome.controller.addListener(() {
      if (_editandoIdx != -1 && !_elementoModificado) {
        setState(() => _elementoModificado = true);
      }
    });
    _eQtde.controller.addListener(() {
      if (_editandoIdx != -1 && !_elementoModificado) {
        setState(() => _elementoModificado = true);
      }
    });
    // Detectar modificações nos campos de posição (ao digitar)
    _pNum.controller.addListener(() {
      if (_editandoPosicao && !_posicaoModificada) {
        setState(() => _posicaoModificada = true);
      }
    });
    _pQtde.controller.addListener(() {
      if (_editandoPosicao && !_posicaoModificada) {
        setState(() => _posicaoModificada = true);
      }
    });
    _bitolaCtrl.addListener(() {
      if (_editandoPosicao && !_posicaoModificada) {
        setState(() => _posicaoModificada = true);
      }
    });
    _formaCtrl.addListener(() {
      if (_editandoPosicao && !_posicaoModificada) {
        setState(() => _posicaoModificada = true);
      }
    });
    
    // Preencher IDs do banco para elementos existentes
    if (widget.detalhamento != null) {
      for (int i = 0; i < detalhamentoCtrl.form.elementos.length; i++) {
        _elementoDbIds[i] = detalhamentoCtrl.form.elementos[i].id;
      }
    }

    // Selecionar primeiro elemento ao editar (sem entrar em edição)
    if (widget.detalhamento != null) {
      if (detalhamentoCtrl.form.elementos.isNotEmpty) {
        _sel = _Sec.elementos;
        _elemIdx = 0;
        final primeiroElem = detalhamentoCtrl.form.elementos[0];
        _ultimaPosCount = primeiroElem.posicoes.length;
        if (primeiroElem.posicoes.isNotEmpty) {
          _posicaoFocadaId = primeiroElem.posicoes.first.id;
        }
      }
    }
    // Duplicação: abrir em Dados Gerais para confirmar cliente/obra
    if (widget.skipInit && widget.detalhamento == null) {
      _sel = _Sec.dadosGerais;
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
    _elemScrollCtrl.dispose();
    _posScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Detalhamento'),
        content: Text('Deseja realmente excluir o detalhamento ${widget.detalhamento!.codigo}?\nEsta ação não poderá ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      await BackendClient.detalhamentos.delete(widget.detalhamento!);
      if (mounted) {
        pop(context);
        NotificationService.showPositive('Sucesso', 'Detalhamento excluído');
      }
    }
  }

  Future<void> _anexarArquivoIa(DetalhamentoCreateModel form) async {
    final qtdExistentes = detalhamentoCtrl.form.elementos.length;

    if (qtdExistentes > 0) {
      final bool? confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: Icon(Icons.warning_amber_rounded, size: 40, color: Colors.orange[700]),
          title: const Text('Substituir elementos existentes?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: Color(0xFF334155), fontSize: 14, height: 1.5),
                  children: [
                    const TextSpan(text: 'Este detalhamento possui '),
                    TextSpan(
                      text: '$qtdExistentes elemento${qtdExistentes > 1 ? 's' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                    ),
                    const TextSpan(text: ' que ser'),
                    TextSpan(text: qtdExistentes > 1 ? 'ão ' : 'á '),
                    const TextSpan(
                      text: 'excluído',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                    ),
                    TextSpan(text: qtdExistentes > 1 ? 's' : ''),
                    const TextSpan(text: ' ao importar o novo arquivo.'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'A IA extrairá os dados do arquivo e substituirá os elementos atuais.',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMain,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );

      if (confirmar != true) return;
    }

    detalhamentoIaCtrl.setCliente(form.clienteSelecionado);
    detalhamentoIaCtrl.setObra(form.obraSelecionada);
    detalhamentoIaCtrl.pickFile();
  }

  Future<void> _tentarSair() async {
    if (_importacaoPendente) {
      final resposta = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: Icon(Icons.warning_amber_rounded, size: 40, color: Colors.orange[700]),
          title: const Text('Elementos não salvos'),
          content: const Text(
            'Existem elementos importados da IA que ainda não foram salvos no banco de dados. Se sair agora, eles serão perdidos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancelar'),
              child: const Text('Continuar editando'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMain,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, 'salvar'),
              child: const Text('Salvar e sair'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'sair'),
              child: Text('Sair sem salvar', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );

      if (resposta == 'salvar') {
        await _salvarElementosImportados();
        if (mounted) pop(context);
      } else if (resposta == 'sair') {
        // Limpar elementos não salvos
        detalhamentoCtrl.form.elementos.clear();
        detalhamentoCtrl.formStream.update();
        pop(context);
      }
      // 'cancelar' ou null = fica na tela
      return;
    }
    pop(context);
  }

  Future<void> _salvarElementosImportados() async {
    if (!_importacaoPendente || _salvandoImportacao) return;

    setState(() => _salvandoImportacao = true);

    try {
      // Garantir que a detalhamento exista no banco
      if (detalhamentoCtrl.detalhamentoDbId == null) {
        await detalhamentoCtrl.salvarDadosGerais();
      }

      if (detalhamentoCtrl.detalhamentoDbId == null) {
        NotificationService.showNegative('Erro', 'Não foi possível criar o detalhamento. Preencha cliente e obra.');
        setState(() => _salvandoImportacao = false);
        return;
      }

      final elementos = detalhamentoCtrl.form.elementos;
      for (int i = 0; i < elementos.length; i++) {
        final elem = elementos[i];

        // Salvar elemento
        final String? elemDbId = await detalhamentoCtrl.adicionarElemento(elem);
        if (elemDbId != null) {
          elem.id = elemDbId;
          _elementoDbIds[i] = elemDbId;

          // Salvar posições
          for (final pos in elem.posicoes) {
            final String? posDbId = await detalhamentoCtrl.adicionarPosicao(pos, elemDbId);
            if (posDbId != null) {
              pos.id = posDbId;
            }
          }
        }
      }

      detalhamentoCtrl.formStream.update();
      setState(() {
        _importacaoPendente = false;
        _salvandoImportacao = false;
      });

      NotificationService.showPositive(
        'Elementos salvos',
        '${elementos.length} elementos salvos no banco com sucesso.',
      );
    } catch (e) {
      setState(() => _salvandoImportacao = false);
      NotificationService.showNegative('Erro ao salvar', e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      resizeAvoid: true,
      backgroundColor: AppColors.neutralLightest,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => _tentarSair(),
          icon: Icon(Icons.arrow_back, color: AppColors.white),
        ),
        title: StreamOut(
          stream: detalhamentoCtrl.formStream.listen,
          builder: (_, form) {
            final pesoTotal = _pesoTotalDetalhamento(form);
            return Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${form.isEdit ? '' : 'Novo '}Detalhamento ${form.codigo}',
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
        stream: detalhamentoCtrl.formStream.listen,
        builder: (_, form) {
          // Sincronizar mapa de IDs dos elementos
          for (int j = 0; j < form.elementos.length; j++) {
            final id = form.elementos[j].id;
            if (id.isNotEmpty) _elementoDbIds[j] = id;
          }
          // Auto-selecionar último elemento se nenhum selecionado
          if (_elemIdx == -1 && form.elementos.isNotEmpty && _sel == _Sec.elementos) {
            _ultimaElemCount = form.elementos.length; // inicializa counter
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final lastIdx = form.elementos.length - 1;
              final e = form.elementos[lastIdx];
              setState(() {
                _elemIdx = lastIdx;
                _ultimaPosCount = e.posicoes.length;
                if (e.posicoes.isNotEmpty) {
                  _posicaoFocadaId = e.posicoes.first.id;
                }
              });
            });
          }
          // Corrigir _elemIdx se fora de bounds (ex: elemento deletado via plugin)
          if (_elemIdx >= form.elementos.length) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _elemIdx = -1;
                _posicaoSelecionada = null;
                _editandoIdx = -1;
                _formaSelecionada = null;
                _ultimaPosCount = 0;
              });
              _eNome.text = ''; _eQtde.text = ''; _eEquiv.text = '';
              _equivalentesTemp.clear();
              _limparPos();
              _atualizarCompCtrls(null);
            });
          }
          // ── Realtime sync: novos elementos (plugin) ──
          if (form.elementos.length > _ultimaElemCount && _ultimaElemCount > 0) {
            final novoIdx = form.elementos.length - 1;
            final e = form.elementos[novoIdx];
            _ultimaElemCount = form.elementos.length;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _elemIdx = novoIdx;
                _posicaoSelecionada = null;
                _posicaoFocadaId = null;
                _formaSelecionada = null;
                _ultimaPosCount = e.posicoes.length;
              });
              if (e.posicoes.isNotEmpty) {
                _focarPosicao(e.posicoes.first);
              }
              // Auto-scroll para o novo elemento
              if (_elemScrollCtrl.hasClients) {
                _elemScrollCtrl.animateTo(
                  _elemScrollCtrl.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOutCubic,
                );
              }
            });
          } else if (form.elementos.length != _ultimaElemCount) {
            _ultimaElemCount = form.elementos.length;
          }
          // ── Realtime sync: posições ──
          if (_elemIdx >= 0 && _elemIdx < form.elementos.length) {
            final elem = form.elementos[_elemIdx];
            // 1. Checar se nova posição chegou (prioridade)
            if (elem.posicoes.length > _ultimaPosCount && elem.posicoes.isNotEmpty) {
              _ultimaPosCount = elem.posicoes.length;
              final lastPosId = elem.posicoes.last.id;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                if (_elemIdx >= 0 && _elemIdx < detalhamentoCtrl.form.elementos.length) {
                  final curElem = detalhamentoCtrl.form.elementos[_elemIdx];
                  final pos = curElem.posicoes.where((p) => p.id == lastPosId).firstOrNull
                      ?? (curElem.posicoes.isNotEmpty ? curElem.posicoes.last : null);
                  if (pos != null) {
                    _focarPosicao(pos);
                  }
                  // Auto-scroll para a última posição
                  if (_posScrollCtrl.hasClients) {
                    _posScrollCtrl.animateTo(
                      _posScrollCtrl.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                    );
                  }
                }
              });
            } else if (elem.posicoes.length != _ultimaPosCount) {
              _ultimaPosCount = elem.posicoes.length;
            }
            // 2. Re-sync posição selecionada (só se já tem UUID)
            if (_posicaoSelecionada != null && _posicaoSelecionada!.id.length == 36) {
              final posId = _posicaoSelecionada!.id;
              final posAtualizada = elem.posicoes.where((p) => p.id == posId).firstOrNull;
              if (posAtualizada != null) {
                final recentementeSalvo = DateTime.now().difference(_ultimoSaveComprimento).inMilliseconds < 2000;

                // SÍNCRONO: preservar dados locais nos objetos da lista ANTES do render
                if (recentementeSalvo && !identical(posAtualizada, _posicaoSelecionada)) {
                  posAtualizada.comprimentos
                    ..clear()
                    ..addAll(_posicaoSelecionada!.comprimentos);
                  // Usa a forma mais recente do cadastro para recalcular
                  final formaAtual = posAtualizada.formaSelecionada ?? _posicaoSelecionada!.formaSelecionada;
                  if (formaAtual != null) {
                    final formaAtualizada = BackendClient.formas.data
                        .where((f) => f.id == formaAtual.id)
                        .firstOrNull;
                    posAtualizada.formaSelecionada = formaAtualizada ?? formaAtual;
                    posAtualizada.bitolaSelecionada = _posicaoSelecionada!.bitolaSelecionada;
                  }
                  posAtualizada.calcularComprimentoDeCorte();
                }

                if (posAtualizada.formaSelecionada != null && posAtualizada.formaSelecionada?.id != _formaSelecionada?.id && !_posicaoModificada) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _selecionarPosicao(posAtualizada);
                  });
                } else if (_formaSelecionada != null) {
                  // Atualizar referência
                  _posicaoSelecionada = posAtualizada;
                  // Atualizar controllers de texto (async, pós-render)
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    final qualquerCampoEmFoco = _compFns.any((fn) => fn.hasFocus);
                    for (int k = 0; k < _formaSelecionada!.itens.length && k < _compCtrls.length; k++) {
                      final trecho = _formaSelecionada!.itens[k].trecho;
                      final valor = posAtualizada.comprimentos[trecho];
                      final novoTexto = valor != null ? valor.toString() : '';
                      if (novoTexto.isNotEmpty && !qualquerCampoEmFoco && !recentementeSalvo && _compCtrls[k].text != novoTexto) {
                        _compCtrls[k].text = novoTexto;
                      }
                    }
                    // Só sincroniza campos do formulário se estiver em modo edição
                    final formEmEdicao = _posicaoModificada
                        || _pNum.focus.hasFocus
                        || _pQtde.focus.hasFocus
                        || _fnBitola.hasFocus
                        || _fnForma.hasFocus;
                    if (_editandoPosicao && !formEmEdicao) {
                      _pNum.text = posAtualizada.posicao.text;
                      _pQtde.text = posAtualizada.qtde.text;
                      if (posAtualizada.bitolaSelecionada != null) {
                        _bitolaCtrl.text = posAtualizada.bitolaSelecionada!.nome;
                        setState(() => _pBitola = posAtualizada.bitolaSelecionada);
                      }
                    }
                  });
                }
              } else {
                // Posição foi deletada remotamente — limpa tela
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _posicaoSelecionada = null;
                  _limparPos();
                  _atualizarCompCtrls(null);
                });
              }
            }
          }
          return Row(children: [_sidebar(form), Expanded(child: _content(form))]);
        },
      ),
    );
  }

  // ═══ SIDEBAR ═══════════════════════════════════════════
  Widget _sidebar(DetalhamentoCreateModel form) {
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
                    if (s == _Sec.detalhamentoIA) {
                      detalhamentoIaCtrl.setCliente(form.clienteSelecionado);
                      detalhamentoIaCtrl.setObra(form.obraSelecionada);
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
        Tooltip(message: 'Detalhamento ${form.codigo}', preferBelow: false,
          child: Container(margin: const EdgeInsets.symmetric(vertical: 14), width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.primaryMain, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.primaryMain.withValues(alpha: 0.5), blurRadius: 8)]),
            child: Center(child: Text(form.codigo.toString(), style: AppCss.mediumBold.setColor(AppColors.white).setSize(14))),
          ),
        ),
        const SizedBox(height: 8),
        item(_Sec.dadosGerais, Icons.badge_outlined, 'Dados Gerais'),
        item(_Sec.elementos, Icons.view_list_outlined, 'Elementos', habilitado: elementosHabilitado),
        item(_Sec.detalhamentoIA, Icons.auto_awesome_outlined, 'Detalhamento por I.A.', habilitado: iaHabilitado),
        const Spacer(),
        if (form.isEdit && !_isRO) Tooltip(message: 'Excluir Detalhamento ${form.codigo}', preferBelow: false,
          child: InkWell(onTap: _confirmDelete, borderRadius: BorderRadius.circular(8),
            child: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.delete_outline, size: 18, color: AppColors.error)),
          ),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }


  Widget _content(DetalhamentoCreateModel form) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 200),
    child: KeyedSubtree(key: ValueKey(_sel),
      child: _sel == _Sec.dadosGerais
          ? _dadosGerais(form)
          : _sel == _Sec.elementos
              ? _elemLayout(form)
              : _detalhamentoIaContent(form)),
  );

  // ═══ DADOS GERAIS ══════════════════════════════════════
  Widget _dadosGerais(DetalhamentoCreateModel form) {
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
            AppField(label: 'Detalhamento', controllerObj: TextEditingController(text: form.codigo.toString()), isDisable: true),
            const SizedBox(height: 16),
            AppDropDown<ClienteModel?>(label: 'Cliente', item: form.clienteSelecionado, itens: clientes,
              itemLabel: (e) => e?.nome ?? 'Selecione um cliente',
              onSelect: (e) { form.clienteSelecionado = e; form.obraSelecionada = null; detalhamentoCtrl.formStream.update(); }),
            const SizedBox(height: 16),
            AppDropDown<ObraModel?>(label: 'Obra', item: form.obraSelecionada, itens: obras,
              itemLabel: (e) => e?.descricao ?? 'Selecione uma obra',
              onSelect: (e) { form.obraSelecionada = e; detalhamentoCtrl.formStream.update(); }),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      if (!_isRO)
        InkWell(
          onTap: () async {
            if (widget.skipInit) {
              // Duplicação: mostrar spinner bloqueante
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => PopScope(
                  canPop: false,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12)],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppColors.primaryMain),
                          const SizedBox(height: 16),
                          Text('Duplicando projeto...', style: AppCss.smallBold),
                        ],
                      ),
                    ),
                  ),
                ),
              );

              final sucesso = await detalhamentoCtrl.duplicarCompleto();

              if (mounted) Navigator.pop(context); // Fechar spinner

              if (sucesso && mounted) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    icon: Icon(Icons.check_circle_outline, size: 48, color: const Color(0xFF10B981)),
                    content: Text(
                      'Projeto duplicado com sucesso!\nNovo código: ${detalhamentoCtrl.form.codigo}',
                      style: AppCss.smallRegular,
                      textAlign: TextAlign.center,
                    ),
                    actionsAlignment: MainAxisAlignment.center,
                    actions: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryMain),
                        onPressed: () {
                          Navigator.pop(ctx);
                          pop(context);
                        },
                        child: Text('OK', style: AppCss.smallBold.setColor(Colors.white)),
                      ),
                    ],
                  ),
                );
              }
            } else {
              await detalhamentoCtrl.salvarDadosGerais();
            }
          },
          child: Container(
            height: 44, width: double.infinity,
            decoration: BoxDecoration(color: AppColors.primaryMain, borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(
              widget.skipInit ? 'DUPLICAR PROJETO' : 'SALVAR DADOS GERAIS',
              style: AppCss.minimumBold.setColor(Colors.white).setSize(13).setLetterSpacing(1),
            )),
          ),
        ),
    ]);
  }

  // ═══ 3 COLUNAS ═════════════════════════════════════════
  Widget _elemLayout(DetalhamentoCreateModel form) {
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

  /// Header com badge + botão de ação opcional (ex: ordenar)
  Widget _hdrComAcao(String t, IconData ic, {String? badge, String? acaoTooltip, IconData? acaoIcon, bool acaoHabilitada = true, VoidCallback? onAcao}) => Container(
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
      if (acaoIcon != null) ...[
        const SizedBox(width: 6),
        Tooltip(
          message: acaoTooltip ?? '',
          waitDuration: const Duration(milliseconds: 400),
          child: InkWell(
            onTap: (acaoHabilitada && onAcao != null) ? onAcao : null,
            borderRadius: BorderRadius.circular(6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: acaoHabilitada
                    ? AppColors.primaryMain.withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(acaoIcon, size: 15,
                color: acaoHabilitada ? AppColors.primaryMain : Colors.grey[400]),
            ),
          ),
        ),
      ],
    ]),
  );

  // ── COL 1: Elementos ───────────────────────────────────
  Widget _col1(DetalhamentoCreateModel form) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _hdr('ELEMENTOS', Icons.layers_outlined, '${_totalElementosComEquivalentes(form)}'),
      // ── Barra de "Salvar Elementos" quando importação pendente ──
      if (_importacaoPendente && !_isRO)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            border: Border(bottom: BorderSide(color: Colors.orange[200]!)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Elementos importados não salvos',
                  style: AppCss.minimumRegular.setColor(Colors.orange[800]!).setSize(11),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _salvandoImportacao
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : InkWell(
                    onTap: _salvarElementosImportados,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [AppColors.primaryMain, AppColors.primaryMain.withValues(alpha: 0.85)]),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [BoxShadow(color: AppColors.primaryMain.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.save, color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          Text('Salvar Elementos', style: AppCss.minimumBold.setColor(Colors.white).setSize(11)),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
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
              // ── Seção de Equivalentes (colapsável ao editar) ────
              if (_editandoIdx != -1 && !_equivalentesExpandidos && _equivalentesTemp.isNotEmpty)
                // Modo colapsado: chip resumo
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: InkWell(
                    onTap: () => setState(() => _equivalentesExpandidos = true),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryMain.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primaryMain.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.people_outline, size: 16, color: AppColors.primaryMain),
                          const SizedBox(width: 8),
                          Text(
                            '${_equivalentesTemp.length} equivalente${_equivalentesTemp.length > 1 ? 's' : ''}',
                            style: AppCss.minimumBold.setColor(AppColors.primaryMain).setSize(13),
                          ),
                          const Spacer(),
                          Icon(Icons.expand_more, size: 18, color: AppColors.primaryMain.withValues(alpha: 0.6)),
                        ],
                      ),
                    ),
                  ),
                )
              else if (_editandoIdx != -1 && !_equivalentesExpandidos && _equivalentesTemp.isEmpty)
                // Modo colapsado sem equivalentes: botão para adicionar
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: InkWell(
                    onTap: () => setState(() => _equivalentesExpandidos = true),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.people_outline, size: 16, color: Colors.grey[400]),
                          const SizedBox(width: 8),
                          Text(
                            'Sem equivalentes',
                            style: AppCss.minimumRegular.setColor(Colors.grey[400]!).setSize(13),
                          ),
                          const Spacer(),
                          Icon(Icons.add, size: 16, color: Colors.grey[400]),
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
                // Modo expandido: campo + chips
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
                  // Botão recolher (só ao editar)
                  if (_editandoIdx != -1) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Recolher equivalentes',
                      child: InkWell(
                        onTap: () => setState(() => _equivalentesExpandidos = false),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.expand_less, size: 18, color: Colors.grey[500]),
                        ),
                      ),
                    ),
                  ],
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
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_editandoIdx != -1)
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _editandoIdx = -1;
                            _elementoModificado = false;
                            _eNome.text = ''; _eQtde.text = ''; _eEquiv.text = '';
                            _equivalentesTemp.clear();
                            _equivalentesExpandidos = true;
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
                controller: _elemScrollCtrl,
                padding: const EdgeInsets.all(10),
                itemCount: form.elementos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                final e = form.elementos[i]; final on = i == _elemIdx;
                return InkWell(
                  onTap: () async {
                    if (!await _verificarEdicaoPendente()) return;
                    setState(() {
                      _elemIdx = i;
                      _ultimaPosCount = e.posicoes.length;
                    });
                    // Limpa seleção de posição (apenas mostra a lista)
                    _limparPos();
                    _atualizarCompCtrls(null);
                    setState(() {
                      _posicaoSelecionada = null;
                      _posicaoFocadaId = null;
                      _editandoPosicao = false;
                      _formaSelecionada = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(duration: const Duration(milliseconds: 150),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── TARJA TOPO ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: on ? const Color(0xFF1E3A5F) : const Color(0xFF2C4A6E),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(11),
                              topRight: Radius.circular(11),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  e.nome.text.isEmpty ? 'Elemento ${i + 1}' : e.nome.text,
                                  style: AppCss.minimumBold.setColor(Colors.white).setSize(15),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!_isRO) ...[                                InkWell(onTap: () async {
                                  if (!await _verificarEdicaoPendente()) return;
                                  setState(() {
                                    _elemIdx = i;
                                    _editandoIdx = i;
                                    _elementoModificado = false;
                                    _eNome.text = e.nome.text;
                                    _eQtde.text = e.quantidade.text;
                                    _equivalentesTemp = List.from(e.elementosEquivalentes);
                                    _eEquiv.text = '';
                                    _equivalentesExpandidos = false;
                                  });
                                }, borderRadius: BorderRadius.circular(6),
                                  child: Tooltip(message: 'Editar elemento', preferBelow: false,
                                    child: Icon(Icons.edit_outlined, size: 14, color: Colors.white.withValues(alpha: 0.5)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(onTap: () async {
                                  if (await showConfirmDialog('Excluir elemento?', 'Posições serão removidas.')) {
                                    setState(() => _excluindoElementoIdx = i);
                                    try {
                                      final elemId = _elementoDbIds[i];
                                      if (elemId != null && elemId.length == 36) {
                                        await detalhamentoCtrl.excluirElemento(elemId);
                                      }
                                      _elemIdx = -1;
                                      _editandoIdx = -1;
                                      _elementoModificado = false;
                                      _posicaoSelecionada = null;
                                      _elementoDbIds.clear();
                                      final formAtual = detalhamentoCtrl.form;
                                      for (int j = 0; j < formAtual.elementos.length; j++) {
                                        final id = formAtual.elementos[j].id;
                                        if (id.isNotEmpty) _elementoDbIds[j] = id;
                                      }
                                      _eNome.text = ''; _eQtde.text = ''; _eEquiv.text = '';
                                      _equivalentesTemp.clear();
                                      _limparPos();
                                      _atualizarCompCtrls(null);
                                      setState(() {
                                        _formaSelecionada = null;
                                        _posicaoModificada = false;
                                        _excluindoElementoIdx = -1;
                                      });
                                    } catch (_) {
                                      setState(() => _excluindoElementoIdx = -1);
                                    }
                                  }
                                }, borderRadius: BorderRadius.circular(6),
                                  child: _excluindoElementoIdx == i
                                      ? const SizedBox(
                                          width: 16, height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                                        )
                                      : Tooltip(message: 'Excluir elemento', preferBelow: false,
                                          child: Icon(Icons.delete_outline, size: 16, color: Colors.white.withValues(alpha: 0.5)),
                                        ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // ── CORPO ──
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (e.elementosEquivalentes.isNotEmpty) ...[
                                Text('${e.nome.text}=${e.elementosEquivalentes.join('=')}',
                                    style: AppCss.minimumBold.setColor(AppColors.primaryMain).setSize(12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                              ],
                              Text('Qtde: ${e.quantidade.text.isEmpty ? '0' : e.quantidade.text} ${e.elementosEquivalentes.isNotEmpty ? '(Total: ${_qtdeTotalElemento(e)}) ' : ''}• Pos: ${e.posicoes.length}',
                                  style: AppCss.minimumRegular.setColor(Colors.grey[600]!).setSize(12)),
                              const SizedBox(height: 4),
                              Row(children: [
                                Icon(Icons.scale_outlined, size: 12, color: _pesoTotalElemento(e) > 0 ? const Color(0xFF10B981) : Colors.grey[400]),
                                const SizedBox(width: 4),
                                Text(
                                  'Unit: ${_formatPeso(_pesoUnitElemento(e))} • Total: ${_formatPeso(_pesoTotalElemento(e))} kg',
                                  style: AppCss.minimumRegular.setColor(_pesoTotalElemento(e) > 0 ? const Color(0xFF10B981) : Colors.grey[400]!).setSize(11),
                                ),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
      ),
    ]);
  }

  void _addElem(DetalhamentoCreateModel form) async {
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
      _editandoIdx = -1; _elementoModificado = false;
      _equivalentesExpandidos = true;
      _formaSelecionada = null;
    });
    detalhamentoCtrl.formStream.update();
    _ultimaElemCount = form.elementos.length; // sincroniza para não re-selecionar via Realtime
    // Auto-scroll para o novo elemento
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_elemScrollCtrl.hasClients) {
        _elemScrollCtrl.animateTo(
          _elemScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
        );
      }
    });
    // Auto-save
    final dbId = await detalhamentoCtrl.adicionarElemento(n);
    if (dbId != null) {
      _elementoDbIds[idx] = dbId;
      n.id = dbId;
    }
    Future.delayed(const Duration(milliseconds: 100), () => _pNum.focus.requestFocus());
  }

  void _updateElem(DetalhamentoCreateModel form) async {
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
      _editandoIdx = -1; _elementoModificado = false;
      _equivalentesExpandidos = true;
      _eNome.text = ''; _eQtde.text = ''; _eEquiv.text = '';
      _equivalentesTemp.clear();
    });
    detalhamentoCtrl.formStream.update();
    
    // Auto-save update
    await detalhamentoCtrl.atualizarElemento(elem);
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
                  readOnly: _editandoPosicao,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: _editandoPosicao,
                    fillColor: _editandoPosicao ? Colors.grey[100] : null,
                    suffixIcon: _editandoPosicao
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _limparPos();
                            _atualizarCompCtrls(null);
                            setState(() {
                              _formaSelecionada = null;
                              _posicaoSelecionada = null;
                              _posicaoFocadaId = null;
                              _editandoPosicao = false;
                            });
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
                controller: _posScrollCtrl,
                padding: const EdgeInsets.all(10),
                itemCount: elem.posicoes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (_, i) {
                final pRaw = elem.posicoes[i]; // ordem de inserção
                final on = (_posicaoFocadaId ?? _posicaoSelecionada?.id) == pRaw.id;
                // Usar dados locais (mais recentes) quando é a posição selecionada
                final p = (_posicaoSelecionada?.id == pRaw.id) && _posicaoSelecionada != null ? _posicaoSelecionada! : pRaw;
                return InkWell(
                  key: ValueKey(p.id),
                  onTap: () {
                    _focarPosicao(p);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── TARJA TOPO ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: on ? const Color(0xFF1E3A5F) : const Color(0xFF2C4A6E),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(11),
                              topRight: Radius.circular(11),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'N${p.posicao.text}',
                                style: AppCss.minimumBold.setColor(Colors.white).setSize(13),
                              ),
                              Text(
                                '  —  ',
                                style: AppCss.minimumRegular.setColor(Colors.white.withValues(alpha: 0.5)).setSize(13),
                              ),
                              Text(
                                '${p.qtde.text.isEmpty ? '0' : p.qtde.text}',
                                style: AppCss.minimumBold.setColor(Colors.white).setSize(13),
                              ),
                              Text(
                                '  ⌀ ',
                                style: AppCss.minimumBold.setColor(const Color(0xFF7DD3FC)).setSize(13),
                              ),
                              Text(
                                '${p.bitolaSelecionada?.nome ?? '-'}mm',
                                style: AppCss.minimumBold.setColor(Colors.white).setSize(13),
                              ),
                              const Spacer(),
                              if (!_isRO) ...[                                InkWell(
                                  onTap: () => _selecionarPosicao(p),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Tooltip(message: 'Editar posição', preferBelow: false,
                                    child: Icon(Icons.edit_outlined, size: 14, color: Colors.white.withValues(alpha: 0.5)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () async {
                                    if (await showConfirmDialog('Excluir posição?', 'Posição ${p.posicao.text} será removida.')) {
                                      final posId = p.id;
                                      if (_posicaoSelecionada == p || _posicaoSelecionada?.id == posId) {
                                        _posicaoSelecionada = null;
                                        _atualizarCompCtrls(null);
                                        _limparPos();
                                        setState(() => _formaSelecionada = null);
                                      }
                                      elem.posicoes.remove(p);
                                      detalhamentoCtrl.formStream.update();
                                      _atualizarPesoElementoAtual();
                                      _atualizarPesoTotal(detalhamentoCtrl.form);
                                      if (posId.length == 36) await detalhamentoCtrl.excluirPosicao(posId);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Tooltip(message: 'Excluir posição', preferBelow: false,
                                    child: Icon(Icons.delete_outline, size: 16, color: Colors.white.withValues(alpha: 0.5)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // ── CORPO (2 linhas compactas) ──
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Linha 1: Forma + Comprimentos
                              Builder(builder: (_) {
                                final somaCm = p.comprimentos.values.fold(0, (s, v) => s + v);
                                final corteCm = p.comprimentoDeCorte;
                                final temCompr = somaCm > 0;
                                return Row(children: [
                                  Icon(Icons.category_outlined, size: 11, color: Colors.grey[500]),
                                  const SizedBox(width: 3),
                                  Text(p.formaSelecionada?.codigo ?? '-',
                                      style: AppCss.minimumBold.setColor(Colors.grey[700]!).setSize(11)),
                                  const SizedBox(width: 10),
                                  Icon(Icons.straighten, size: 11, color: temCompr ? const Color(0xFF6366F1) : Colors.grey[400]),
                                  const SizedBox(width: 3),
                                  Text('${somaCm}cm', style: AppCss.minimumRegular.setColor(temCompr ? const Color(0xFF6366F1) : Colors.grey[400]!).setSize(11)),
                                  if (temCompr && corteCm != somaCm) ...[
                                    Text(' → ', style: AppCss.minimumRegular.setColor(Colors.grey[400]!).setSize(10)),
                                    Icon(Icons.content_cut, size: 10, color: const Color(0xFFF59E0B)),
                                    Text('${corteCm.toStringAsFixed(1)}cm', style: AppCss.minimumBold.setColor(const Color(0xFFF59E0B)).setSize(11)),
                                  ],
                                ]);
                              }),
                              const SizedBox(height: 3),
                              // Linha 2: Peso
                              Row(children: [
                                Icon(Icons.scale_outlined, size: 11, color: _pesoTotalPosicao(p) > 0 ? const Color(0xFF10B981) : Colors.grey[400]),
                                const SizedBox(width: 3),
                                Text(
                                  _temVariavel(p)
                                      ? 'Unit: var • Total: ${_formatPeso(_pesoTotalPosicao(p))} kg'
                                      : 'Unit: ${_formatPeso(_pesoUnitPosicao(p))} • Total: ${_formatPeso(_pesoTotalPosicao(p))} kg',
                                  style: AppCss.minimumRegular.setColor(_pesoTotalPosicao(p) > 0 ? const Color(0xFF10B981) : Colors.grey[400]!).setSize(11),
                                ),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),
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
    _abrirModalBusca<BitolaModel>(
      titulo: 'Buscar Bitola (F2)',
      itens: BackendClient.bitolas.data,
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
    final match = BackendClient.bitolas.data.where((b) =>
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
    // Se forma mudou em edição, zera trechos e variáveis da forma anterior
    if (_posicaoSelecionada != null && match != null && _posicaoSelecionada!.formaSelecionada?.codigo != match.codigo) {
      _posicaoSelecionada!.comprimentos.clear();
      _posicaoSelecionada!.variaveis.clear();
    }
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
      debugPrint('[_addPos EDIÇÃO] _pBitola=${_pBitola?.nome}, _pForma=${_pForma?.codigo}, _pQtde=${_pQtde.text}');
      debugPrint('[_addPos EDIÇÃO] posExistente ANTES: bitola=${posExistente.bitolaSelecionada?.nome}, forma=${posExistente.formaSelecionada?.codigo}, qtde=${posExistente.qtde.text}');
      posExistente.bitolaSelecionada = _pBitola;
      
      // Se trocou a forma, zera os comprimentos e variáveis
      if (posExistente.formaSelecionada?.codigo != _pForma!.codigo) {
        posExistente.formaSelecionada = _pForma;
        posExistente.descontoDobraSnapshot = _pForma!.descontoDobra;
        posExistente.formaSnapshot = _pForma!.toSnapshot();
        posExistente.comprimentos.clear();
        posExistente.variaveis.clear();
      }
      
      posExistente.qtde.text = _pQtde.text.isEmpty ? '1' : _pQtde.text;
      // Recalcula comprimento de corte com bitola/forma atualizados
      posExistente.calcularComprimentoDeCorte();
      debugPrint('[_addPos EDIÇÃO] posExistente DEPOIS: bitola=${posExistente.bitolaSelecionada?.nome}, forma=${posExistente.formaSelecionada?.codigo}, qtde=${posExistente.qtde.text}');
      
      
      _selecionarPosicao(posExistente);
      detalhamentoCtrl.formStream.update();
      
      if (_compFns.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 100), () => _focarPrimeiroTrecho(posExistente.formaSelecionada!));
      }
      
      // Auto-save update + atualiza pesos
      final elemId = _elementoDbIds[_elemIdx];
      debugPrint('[_addPos EDIÇÃO] elemId=$elemId, posExistente.id=${posExistente.id} (${posExistente.id.length} chars)');
      if (elemId != null && posExistente.id.length == 36) {
        debugPrint('[_addPos EDIÇÃO] ✅ Chamando adicionarPosicaoAtualizada');
        await detalhamentoCtrl.adicionarPosicaoAtualizada(posExistente, elemId);
      } else {
        debugPrint('[_addPos EDIÇÃO] ⚠️ NÃO salvou no banco — elemId=$elemId, id.length=${posExistente.id.length}');
      }
      _atualizarPesoElementoAtual();
      _atualizarPesoTotal(detalhamentoCtrl.form);
      // Sai do modo edição mas mantém foco no card (trechos visíveis)
      _limparPos();
      _focarPosicao(posExistente);
      return;
    }
    final n = PosicaoCreateModel();
    n.posicao.text = _pNum.text;
    n.bitolaSelecionada = _pBitola;
    n.formaSelecionada = _pForma;
    n.descontoDobraSnapshot = _pForma!.descontoDobra;
    n.formaSnapshot = _pForma!.toSnapshot();
    n.qtde.text = _pQtde.text.isEmpty ? '1' : _pQtde.text;
    n.calcularComprimentoDeCorte();
    elem.posicoes.add(n);
    _limparPos();

    // Foca a posição recém-adicionada (sem entrar em edição)
    _focarPosicao(n);
    _ultimaPosCount = elem.posicoes.length;

    detalhamentoCtrl.formStream.update();
    // Auto-scroll para a nova posição
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_posScrollCtrl.hasClients) {
        _posScrollCtrl.animateTo(
          _posScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
        );
      }
    });

    // Foca o primeiro campo de trecho da tela direita
    if (_compFns.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _focarPrimeiroTrecho(n.formaSelecionada!);
      });
    }

    // Auto-save posição + atualiza pesos
    final elemId = _elementoDbIds[_elemIdx];
    if (elemId != null) {
      debugPrint('[_addPos] ANTES do await adicionarPosicao — n.id=${n.id} (${n.id.length} chars), n.comprimentos=${n.comprimentos}');
      final dbId = await detalhamentoCtrl.adicionarPosicao(n, elemId);
      debugPrint('[_addPos] DEPOIS do await — dbId=$dbId, n.comprimentos=${n.comprimentos}, _posicaoSelecionada?.id=${_posicaoSelecionada?.id}');
      if (dbId != null) {
        n.id = dbId;
        debugPrint('[_addPos] n.id atualizado para $dbId — n.comprimentos=${n.comprimentos}');
        // Salva comprimentos que possam ter sido preenchidos DURANTE o await do UUID
        if (n.comprimentos.isNotEmpty) {
          debugPrint('[_addPos] Salvando comprimentos pendentes: ${n.comprimentos}');
          detalhamentoCtrl.adicionarPosicaoAtualizada(n, elemId);
        } else {
          debugPrint('[_addPos] ⚠️ n.comprimentos está VAZIO — nada a salvar');
        }
      }
    }
    _atualizarPesoElementoAtual();
    _atualizarPesoTotal(detalhamentoCtrl.form);
  }

  /// Verifica se há edição pendente (posição ou elemento) e pergunta se deseja descartar.
  Future<bool> _verificarEdicaoPendente() async {
    // Verifica edição de posição
    if (_editandoPosicao && _posicaoModificada) {
      final descartar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Posição com alterações'),
          content: const Text('A posição tem alterações não salvas. Deseja descartar?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continuar editando'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
              child: const Text('Descartar'),
            ),
          ],
        ),
      );
      if (!(descartar ?? false)) return false;
    }
    // Verifica edição de elemento
    if (_editandoIdx != -1 && _elementoModificado) {
      final descartar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Elemento com alterações'),
          content: const Text('O elemento tem alterações não salvas. Deseja descartar?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continuar editando'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
              child: const Text('Descartar'),
            ),
          ],
        ),
      );
      if (!(descartar ?? false)) return false;
      // Descartou: reseta modo edição do elemento
      setState(() { _editandoIdx = -1; _elementoModificado = false; });
      _eNome.text = ''; _eQtde.text = '';
    }
    return true;
  }

  /// Foca na posição sem preencher os campos de edição (clique no card)
  Future<void> _focarPosicao(PosicaoCreateModel p) async {
    if (!await _verificarEdicaoPendente()) return;
    // Atualiza a forma com o descontoDobra mais recente do cadastro
    if (p.formaSelecionada != null) {
      final formaAtualizada = BackendClient.formas.data
          .where((f) => f.id == p.formaSelecionada!.id)
          .firstOrNull;
      if (formaAtualizada != null) p.formaSelecionada = formaAtualizada;
    }
    _atualizarCompCtrls(p.formaSelecionada, posicao: p);
    _pNum.text = ''; _pQtde.text = ''; _bitolaCtrl.text = ''; _formaCtrl.text = '';
    setState(() {
      _posicaoSelecionada = p;
      _posicaoFocadaId = p.id;
      _editandoPosicao = false;
      _pBitola = null;
      _pForma = null;
      _formaSelecionada = p.formaSelecionada;
      _posicaoModificada = false;
    });
  }

  /// Seleciona e preenche os campos de edição (botão lápis)
  void _selecionarPosicao(PosicaoCreateModel p) {
    _pNum.text = p.posicao.text;
    _pBitola = p.bitolaSelecionada;
    _bitolaCtrl.text = p.bitolaSelecionada?.nome ?? '';
    _pForma = p.formaSelecionada;
    _formaCtrl.text = p.formaSelecionada?.codigo ?? '';
    _pQtde.text = p.qtde.text;
    _atualizarCompCtrls(p.formaSelecionada, posicao: p);
    setState(() {
      _posicaoSelecionada = p;
      _posicaoFocadaId = p.id;
      _editandoPosicao = true;
      _formaSelecionada = p.formaSelecionada;
      _posicaoModificada = false;
    });
  }

  void _limparPos() {
    _pNum.text = ''; _bitolaCtrl.text = ''; _formaCtrl.text = ''; _pQtde.text = '';
    setState(() { _pBitola = null; _pForma = null; _posicaoModificada = false; });
  }

  /// Foca o campo do trecho com menor número de rótulo (T1, T2...) independente
  /// da posição física do item na lista da forma.
  void _focarPrimeiroTrecho(FormaModel forma) {
    if (_compFns.isEmpty || forma.itens.isEmpty) return;
    final idxMenor = List.generate(forma.itens.length, (i) => i)
        .reduce((a, b) => forma.itens[a].numeroOrdem < forma.itens[b].numeroOrdem ? a : b);
    if (idxMenor < _compFns.length) _compFns[idxMenor].requestFocus();
  }

  void _salvarComprimento(int idx, FormaModel forma) {
    debugPrint('[_salvarComprimento] idx=$idx, _posicaoSelecionada=${_posicaoSelecionada?.id} (${_posicaoSelecionada?.id.length ?? 0} chars)');
    if (_posicaoSelecionada == null) { debugPrint('[_salvarComprimento] ⚠️ ABORTANDO — _posicaoSelecionada é null'); return; }
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

    // Atualiza a forma com o descontoDobra mais recente do cadastro
    final formaAtual = _posicaoSelecionada!.formaSelecionada;
    if (formaAtual != null) {
      final formaAtualizada = BackendClient.formas.data
          .where((f) => f.id == formaAtual.id)
          .firstOrNull;
      if (formaAtualizada != null) {
        _posicaoSelecionada!.formaSelecionada = formaAtualizada;
      }
    }

    // Recalcula comprimento de corte
    _posicaoSelecionada!.calcularComprimentoDeCorte();

    // Sincronizar dados de volta para o objeto na lista do form
    // (podem ser referências diferentes após Realtime sync)
    if (_elemIdx >= 0 && _elemIdx < detalhamentoCtrl.form.elementos.length) {
      final elemPosicoes = detalhamentoCtrl.form.elementos[_elemIdx].posicoes;
      final posNaLista = elemPosicoes.where((p) => p.id == _posicaoSelecionada!.id).firstOrNull;
      if (posNaLista != null && !identical(posNaLista, _posicaoSelecionada)) {
        posNaLista.comprimentos
          ..clear()
          ..addAll(_posicaoSelecionada!.comprimentos);
        posNaLista.comprimentoDeCorte = _posicaoSelecionada!.comprimentoDeCorte;
      }
    }

    // Auto-save: atualizar posição no banco
    final elemId = _elementoDbIds[_elemIdx];
    if (elemId != null && _posicaoSelecionada!.id.length == 36) {
      _ultimoSaveComprimento = DateTime.now();
      detalhamentoCtrl.adicionarPosicaoAtualizada(_posicaoSelecionada!, elemId);
    }
    // Atualizar pesos
    setState(() {});
    detalhamentoCtrl.formStream.update();
    _atualizarPesoElementoAtual();
    _atualizarPesoTotal(detalhamentoCtrl.form);
  }

  // ── COL 3: Preview Forma ───────────────────────────────
  Widget _col3() {
    // Com posição selecionada → usa a forma da posição
    // Sem posição selecionada → usa _pForma (formulário em preenchimento)
    final forma = _posicaoSelecionada != null ? _formaSelecionada : _pForma;
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
                  : Builder(builder: (_) {
                      // Exibe sempre em ordem T1, T2, T3... independente da ordem física da forma
                      final indicesOrdenados = List.generate(forma.itens.length, (idx) => idx)
                        ..sort((a, b) => forma.itens[a].numeroOrdem.compareTo(forma.itens[b].numeroOrdem));
                      return ListView.builder(
                        itemCount: forma.itens.length,
                        itemBuilder: (_, pos) {
                          final i = indicesOrdenados[pos]; // índice real → mapeia para _compCtrls[i]
                          final t = forma.itens[i];
                          final trecho = t.trecho;
                        final isVariavel = _posicaoSelecionada?.variaveis[trecho] ?? false;

                        // ── Lógica de grupo de simetria ──────────────────────
                        final grupo = t.grupoSimetria;
                        bool isFollower = false;
                        String liderTrecho = '';
                        if (grupo.isNotEmpty) {
                          // O líder é o item com o MENOR número de rótulo no grupo (T1 < T2 < T10...)
                          final itensDoGrupo = forma.itens.where((x) => x.grupoSimetria == grupo).toList();
                          final lider = itensDoGrupo.reduce((a, b) => a.numeroOrdem < b.numeroOrdem ? a : b);
                          isFollower = lider.trecho != trecho;
                          liderTrecho = isFollower ? lider.trecho : '';
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
                                onChanged: isFollower ? null : (val) {
                                  setState(() {});
                                  // Propaga imediatamente para os campos simétricos
                                  if (grupo.isNotEmpty && i < _compCtrls.length) {
                                    for (int j = 0; j < forma.itens.length; j++) {
                                      if (j == i || forma.itens[j].grupoSimetria != grupo) continue;
                                      if (j < _compCtrls.length && _compCtrls[j].text != val) {
                                        _compCtrls[j].text = val;
                                      }
                                    }
                                  }
                                },
                                onSubmitted: (_) {
                                  _salvarComprimento(i, forma);
                                  // Navega na ORDEM ALFABÉTICA (T1→T2→T3), não na ordem física
                                  final indicesOrdemAlfa = List.generate(forma.itens.length, (k) => k)
                                    ..sort((a, b) => forma.itens[a].numeroOrdem.compareTo(forma.itens[b].numeroOrdem));
                                  final posAtual = indicesOrdemAlfa.indexOf(i);
                                  // Encontra o próximo índice físico habilitado (não-follower) na ordem alfa
                                  int? nextFisico;
                                  for (int p = posAtual + 1; p < indicesOrdemAlfa.length; p++) {
                                    final j = indicesOrdemAlfa[p];
                                    final ng = forma.itens[j].grupoSimetria;
                                    bool isNextFollower = false;
                                    if (ng.isNotEmpty) {
                                      final itensGrp = forma.itens.where((x) => x.grupoSimetria == ng).toList();
                                      final liderGrp = itensGrp.reduce((a, b) => a.numeroOrdem < b.numeroOrdem ? a : b);
                                      isNextFollower = liderGrp.trecho != forma.itens[j].trecho;
                                    }
                                    if (!isNextFollower) { nextFisico = j; break; }
                                  }
                                  if (nextFisico != null && nextFisico < _compFns.length) {
                                    _compFns[nextFisico].requestFocus();
                                    _compCtrls[nextFisico].selection = TextSelection(baseOffset: 0, extentOffset: _compCtrls[nextFisico].text.length);
                                  } else {
                                    // Último trecho: salva e tira foco, mantém card e trechos visíveis
                                    _salvarComprimento(i, forma);
                                    final posParaSalvar = _posicaoSelecionada;
                                    final elemId = _elementoDbIds[_elemIdx];
                                    if (posParaSalvar != null && elemId != null && posParaSalvar.id.length == 36) {
                                      detalhamentoCtrl.adicionarPosicaoAtualizada(posParaSalvar, elemId);
                                    }
                                    // Garante highlight no card
                                    if (posParaSalvar != null && _posicaoFocadaId != posParaSalvar.id) {
                                      setState(() => _posicaoFocadaId = posParaSalvar.id);
                                    }
                                    FocusScope.of(context).unfocus();
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
                                        detalhamentoCtrl.adicionarPosicaoAtualizada(_posicaoSelecionada!, elemId);
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
                      );
                    }),
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
      final itensDoGrupoVar = forma.itens.where((x) => x.grupoSimetria == grupoVar).toList();
      final lider = itensDoGrupoVar.reduce((a, b) => a.numeroOrdem < b.numeroOrdem ? a : b);
      trechoConfig = lider.trecho;
      isFollowerVar = lider.trecho != forma.itens[_trechoVarIdx].trecho;
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
      detalhamentoCtrl.adicionarPosicaoAtualizada(_posicaoSelecionada!, elemId);
    }
    detalhamentoCtrl.formStream.update();
    _atualizarPesoElementoAtual();
    _atualizarPesoTotal(detalhamentoCtrl.form);
  }

  Widget _detalhamentoIaContent(DetalhamentoCreateModel form) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
                      Text('Importação de Projeto', style: AppCss.largeBold.setColor(AppColors.primaryMain)),
                      Text(
                        'Importe elementos de um arquivo PDF ou DXF.',
                        style: AppCss.minimumRegular.setColor(Colors.grey[600]!).setSize(14),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // -- Container 1: Importar Projeto --
              _buildIaCard(
                icone: Icons.tune,
                titulo: '1. Importar Projeto',
                descricao: 'Abra um arquivo PDF ou DXF, identifique os elementos visualmente e importe para o detalhamento.',
                botaoTexto: 'Abrir e Importar',
                botaoIcone: Icons.open_in_new,
                onTap: () => _abrirPreparacaoDxf(form),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIaCard({
    required IconData icone,
    required String titulo,
    required String descricao,
    required String botaoTexto,
    required IconData botaoIcone,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryMain.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icone, color: AppColors.primaryMain, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: AppCss.mediumBold.setColor(const Color(0xFF1E293B))),
                const SizedBox(height: 4),
                Text(descricao, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: onTap,
            icon: Icon(botaoIcone, size: 18),
            label: Text(botaoTexto),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  /// Abre a janela fullscreen de preparação de DXF.
  void _abrirPreparacaoDxf(DetalhamentoCreateModel form) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PreparacaoFullscreenDialog(),
    );
  }

  /// Importa arquivo .spe.json já tratado.
  Future<void> _importarArquivoTratado(DetalhamentoCreateModel form) async {
    detalhamentoIaCtrl.setCliente(form.clienteSelecionado);
    detalhamentoIaCtrl.setObra(form.obraSelecionada);
    detalhamentoIaCtrl.pickFile();
  }




  Widget _buildIaUploadArea(DetalhamentoIaState state, DetalhamentoCreateModel form) {
    // ── Estado: importando para o banco ──────────────────────
    if (state.status == IaStatus.importing) {
      return _buildImportandoArea(state);
    }

    if (state.status == IaStatus.analyzing || state.status == IaStatus.success) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IaProcessingWidget(
            state: state,
            fileName: state.fileName,
          ),
          if (state.status == IaStatus.success) ...[
            const SizedBox(height: 24),
            _buildSuccessResultArea(state),
          ],
        ],
      );
    }

    final bool isReadyForUpload = form.clienteSelecionado != null && form.obraSelecionada != null;

    return InkWell(
      onTap: isReadyForUpload
          ? () => _anexarArquivoIa(form)
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
                'Clique para anexar o arquivo PDF ou DXF',
                style: AppCss.mediumBold.setColor(isReadyForUpload ? const Color(0xFF475569) : Colors.grey[500]!),
              ),
              const SizedBox(height: 8),
              Text(
                isReadyForUpload ? 'Suporte para arquivos .pdf (IA) e .dxf (parser automático)' : 'Selecione o Cliente e Obra primeiro',
                style: AppCss.minimumRegular.setColor(Colors.grey[500]!).setSize(13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImportandoArea(DetalhamentoIaState state) {
    final progresso = state.totalParaImportar > 0
        ? state.elementosImportados / state.totalParaImportar
        : 0.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Spinner
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryMain.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    color: AppColors.primaryMain,
                    strokeWidth: 3,
                  ),
                  Icon(
                    Icons.save_outlined,
                    size: 28,
                    color: AppColors.primaryMain.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Título
            Text(
              'Importando elementos...',
              style: AppCss.largeBold.setColor(const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),

            // Subtítulo com contagem
            Text(
              '${state.elementosImportados} de ${state.totalParaImportar} elementos salvos no banco',
              style: AppCss.smallRegular.setColor(const Color(0xFF64748B)).setSize(14),
            ),
            const SizedBox(height: 20),

            // Barra de progresso
            SizedBox(
              width: 300,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progresso,
                  backgroundColor: const Color(0xFFE2E8F0),
                  color: AppColors.primaryMain,
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(progresso * 100).toStringAsFixed(0)}%',
              style: AppCss.smallBold.setColor(AppColors.primaryMain).setSize(14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessResultArea(DetalhamentoIaState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Resultado bruto retornado pela IA:',
              style: AppCss.minimumRegular.setColor(const Color(0xFF64748B)).setSize(14),
            ),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final importado = await detalhamentoIaCtrl.importarParaDetalhamentoAtual(context);
                    if (importado) {
                      setState(() {
                        _importacaoPendente = true;
                        _sel = _Sec.elementos;
                        // Atualiza mapeamento de IDs locais para o banco
                        _elementoDbIds.clear();
                        for (int i = 0; i < detalhamentoCtrl.form.elementos.length; i++) {
                          _elementoDbIds[i] = detalhamentoCtrl.form.elementos[i].id;
                        }
                        // Auto-seleciona primeiro elemento importado se houver
                        if (detalhamentoCtrl.form.elementos.isNotEmpty) {
                          _elemIdx = 0;
                          final e = detalhamentoCtrl.form.elementos.first;
                          if (e.posicoes.isNotEmpty) {
                            _selecionarPosicao(e.posicoes.first);
                          } else {
                            _limparPos();
                            _atualizarCompCtrls(null);
                            _formaSelecionada = null;
                          }
                        }
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
                  onPressed: detalhamentoIaCtrl.reset,
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
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 300,
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 48),
                    child: Text(
                      state.rawResult,
                      style: AppCss.minimumRegular.setColor(Colors.greenAccent).setSize(13).copyWith(fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Tooltip(
                  message: 'Copiar Conteúdo',
                  child: Material(
                    color: Colors.transparent,
                    child: IconButton(
                      icon: const Icon(Icons.copy, color: Colors.white70, size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: state.rawResult));
                        NotificationService.showPositive('Copiado!', 'Resultado copiado para a área de transferência.', position: NotificationPosition.bottom);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Diálogo fullscreen para preparação visual de DXF.
class _PreparacaoFullscreenDialog extends StatefulWidget {
  const _PreparacaoFullscreenDialog();

  @override
  State<_PreparacaoFullscreenDialog> createState() => _PreparacaoFullscreenDialogState();
}

class _PreparacaoFullscreenDialogState extends State<_PreparacaoFullscreenDialog> {
  bool _carregando = false;
  String? _nomeArquivo;

  Future<void> _escolherDxf() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    if (file.bytes == null) return;

    setState(() {
      _carregando = true;
      _nomeArquivo = file.name;
    });

    preparacaoDxfCtrl.carregarPdf(file.bytes!, file.name);

    setState(() => _carregando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF1E293B)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: [
              Icon(Icons.tune, color: AppColors.primaryMain, size: 22),
              const SizedBox(width: 10),
              Text(
                'Preparação de Arquivo',
                style: AppCss.mediumBold.setColor(const Color(0xFF1E293B)),
              ),
              if (_nomeArquivo != null) ...[
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMain.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _nomeArquivo!,
                    style: TextStyle(fontSize: 12, color: AppColors.primaryMain, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (_nomeArquivo == null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ElevatedButton.icon(
                  onPressed: _carregando ? null : _escolherDxf,
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text('Abrir PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryMain,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ElevatedButton.icon(
                  onPressed: _carregando ? null : _escolherDxf,
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Trocar Arquivo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryMain,
                    side: BorderSide(color: AppColors.primaryMain.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: const Color(0xFFE2E8F0)),
          ),
        ),
        body: _buildCorpo(),
      ),
    );
  }

  Widget _buildCorpo() {
    if (_carregando) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Analisando arquivo DXF...', style: TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    if (_nomeArquivo == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryMain.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.architecture, size: 48, color: AppColors.primaryMain.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 20),
            Text(
              'Nenhum arquivo selecionado',
              style: AppCss.mediumBold.setColor(Colors.grey[500]!),
            ),
            const SizedBox(height: 8),
            Text(
              'Clique em "Abrir Arquivo" para começar a preparação.',
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    // DXF/PDF carregado — mostrar canvas de preparação
    return PreparacaoDxfWidget(
      onImportar: () {
        try {
          final resultado = preparacaoDxfCtrl.exportarParaImportacao();

          if (resultado.totalElementos == 0) {
            NotificationService.showNegative(
              'Nenhum elemento para importar',
              'Selecione elementos no PDF antes de importar',
              position: NotificationPosition.bottom,
            );
            return;
          }

          // Parsear o JSON e criar os elementos no form do detalhamento
          String jsonText = resultado.jsonBruto.trim();
          if (jsonText.startsWith('```json')) jsonText = jsonText.substring(7);
          if (jsonText.startsWith('```')) jsonText = jsonText.substring(3);
          if (jsonText.endsWith('```')) jsonText = jsonText.substring(0, jsonText.length - 3);

          final data = jsonDecode(jsonText);
          final elementos = data['elementos'] as List? ?? [];

          for (final elMap in elementos) {
            final elem = ElementoCreateModel();
            elem.nome.text = elMap['nome']?.toString() ?? 'Elemento';
            elem.quantidade.text = elMap['quantidade']?.toString() ?? '1';

            final posicoes = elMap['posicoes'] as List? ?? [];
            for (final posMap in posicoes) {
              final pos = PosicaoCreateModel();
              pos.posicao.text = posMap['posicao']?.toString() ?? '';
              pos.qtde.text = posMap['quantidade']?.toString() ?? '1';

              final bitolaMm = double.tryParse(posMap['bitola_mm']?.toString() ?? '0') ?? 0;
              pos.bitolaSelecionada = BackendClient.bitolas.data.where((b) => b.diametro == bitolaMm * 10).firstOrNull;

              final formaCodigo = posMap['forma_codigo']?.toString() ?? '';
              pos.formaSelecionada = BackendClient.formas.data.where((f) => f.codigo.toLowerCase() == formaCodigo.toLowerCase()).firstOrNull;
              pos.descontoDobraSnapshot = pos.formaSelecionada?.descontoDobra;
              pos.formaSnapshot = pos.formaSelecionada?.toSnapshot();

              final comprimentosMap = posMap['comprimentos'] as Map? ?? {};
              for (final entry in comprimentosMap.entries) {
                pos.comprimentos[entry.key.toString()] = int.tryParse(entry.value?.toString() ?? '0') ?? 0;
              }

              if (pos.formaSelecionada != null) {
                pos.calcularComprimentoDeCorte();
              }

              elem.posicoes.add(pos);
            }

            detalhamentoCtrl.form.elementos.add(elem);
          }

          detalhamentoCtrl.formStream.update();

          NotificationService.showPositive(
            'Importação concluída',
            '${resultado.totalElementos} elementos importados',
            position: NotificationPosition.bottom,
          );

          Navigator.pop(context);
        } catch (e) {
          NotificationService.showNegative(
            'Erro ao importar',
            e.toString().length > 80 ? e.toString().substring(0, 80) : e.toString(),
            position: NotificationPosition.bottom,
          );
        }
      },
    );
  }
}
