import 'package:acoplan/app/core/client/models/cliente_model.dart';
import 'package:acoplan/app/core/components/h.dart';
import 'package:acoplan/app/core/extensions/string_ext.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

/// Campo de cliente com busca: filtra por nome, CNPJ/CPF, código ou cidade
/// enquanto digita. Feito para listas grandes (centenas/milhares de clientes).
class ClienteBuscaField extends StatefulWidget {
  final List<ClienteModel> clientes;
  final ClienteModel? selecionado;
  final ValueChanged<ClienteModel?> onChanged;
  final String label;

  /// true: rótulo acima do campo, como o AppField dos formulários de cadastro.
  /// false: rótulo dentro da borda, como nos diálogos do Kanban.
  final bool rotuloAcima;
  final bool obrigatorio;
  final bool desabilitado;

  const ClienteBuscaField({
    required this.clientes,
    required this.selecionado,
    required this.onChanged,
    this.label = 'Cliente',
    this.rotuloAcima = false,
    this.obrigatorio = false,
    this.desabilitado = false,
    super.key,
  });

  @override
  State<ClienteBuscaField> createState() => _ClienteBuscaFieldState();
}

class _ClienteBuscaFieldState extends State<ClienteBuscaField> {
  static const _limite = 50;

  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.selecionado?.nome ?? '';
    _focus.addListener(_aoPerderFoco);
  }

  @override
  void didUpdateWidget(covariant ClienteBuscaField old) {
    super.didUpdateWidget(old);
    // Seleção trocada por fora (ex.: limpar o formulário)
    if (widget.selecionado?.id != old.selecionado?.id && !_focus.hasFocus) {
      _controller.text = widget.selecionado?.nome ?? '';
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_aoPerderFoco);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Ao sair do campo sem escolher, volta a mostrar o cliente selecionado.
  void _aoPerderFoco() {
    if (_focus.hasFocus) return;
    final nome = widget.selecionado?.nome ?? '';
    if (_controller.text != nome) _controller.text = nome;
  }

  static String _digitos(String s) => s.replaceAll(RegExp(r'\D'), '');

  List<ClienteModel> _filtrar(String busca) {
    final ordenados = [...widget.clientes]..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    final termo = busca.toCompare;
    // Campo mostrando o próprio selecionado: lista tudo para permitir trocar
    if (termo.isEmpty || busca == widget.selecionado?.nome) return ordenados.take(_limite).toList();

    final numeros = _digitos(busca);
    final comeca = <ClienteModel>[];
    final contem = <ClienteModel>[];
    for (final c in ordenados) {
      final nome = c.nome.toCompare;
      if (nome.startsWith(termo)) {
        comeca.add(c);
      } else if (nome.contains(termo) ||
          c.endereco.localidade.toCompare.contains(termo) ||
          '${c.codigo}' == busca.trim() ||
          (numeros.length >= 3 && (_digitos(c.cnpj).contains(numeros) || _digitos(c.telefone).contains(numeros)))) {
        contem.add(c);
      }
    }
    return [...comeca, ...contem].take(_limite).toList();
  }

  @override
  Widget build(BuildContext context) {
    final campo = TypeAheadField<ClienteModel>(
      controller: _controller,
      focusNode: _focus,
      hideOnEmpty: false,
      hideOnUnfocus: true,
      debounceDuration: const Duration(milliseconds: 120),
      constraints: const BoxConstraints(maxHeight: 340),
      suggestionsCallback: (busca) => _filtrar(busca),
      builder: (context, controller, focus) => TextField(
        controller: controller,
        focusNode: focus,
        enabled: !widget.desabilitado,
        onChanged: (texto) {
          // Digitou algo diferente do selecionado: desfaz a seleção
          if (widget.selecionado != null && texto != widget.selecionado!.nome) widget.onChanged(null);
          setState(() {});
        },
        decoration: InputDecoration(
          labelText: widget.rotuloAcima ? null : widget.label,
          hintText: 'Digite para buscar (nome, CNPJ, cidade...)',
          isDense: !widget.rotuloAcima,
          border: widget.rotuloAcima ? null : OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIcon: controller.text.isEmpty || widget.desabilitado
              ? null
              : IconButton(
                  tooltip: 'Limpar',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: AppColors.neutralDark,
                  ),
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    controller.clear();
                    widget.onChanged(null);
                    focus.requestFocus();
                    setState(() {});
                  },
                ),
        ),
      ),
      itemBuilder: (context, c) {
        final detalhes = [
          'C-${c.codigo}',
          if (c.cnpj.isNotEmpty) c.cnpj,
          if (c.endereco.localidade.isNotEmpty)
            c.endereco.estado.isNotEmpty ? '${c.endereco.localidade}/${c.endereco.estado}' : c.endereco.localidade,
        ].join(' • ');
        final atual = c.id == widget.selecionado?.id;
        return Container(
          color: atual ? AppColors.brandSoft : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppCss.mediumBold.setSize(13.5)),
              const SizedBox(height: 2),
              Text(
                detalhes,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppCss.minimumRegular.setSize(11.5).setColor(AppColors.neutralMedium),
              ),
            ],
          ),
        );
      },
      emptyBuilder: (context) => Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          'Nenhum cliente encontrado',
          style: AppCss.minimumRegular.setSize(13).setColor(AppColors.neutralMedium),
        ),
      ),
      onSelected: (c) {
        _controller.text = c.nome;
        widget.onChanged(c);
        _focus.unfocus();
        setState(() {});
      },
    );

    if (!widget.rotuloAcima) return campo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${widget.label}:${widget.obrigatorio ? '*' : ''}', style: AppCss.smallBold),
        const H(4),
        campo,
      ],
    );
  }
}
