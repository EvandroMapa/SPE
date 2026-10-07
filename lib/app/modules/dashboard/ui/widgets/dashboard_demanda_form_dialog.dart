part of '../dashboard_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Modal de Criação / Edição de Demanda Comercial
// ─────────────────────────────────────────────────────────────────────────────
class _DemandaFormDialog extends StatefulWidget {
  final DemandaModel? demanda;
  final void Function(DemandaModel) onSalvar;

  const _DemandaFormDialog({this.demanda, required this.onSalvar});

  @override
  State<_DemandaFormDialog> createState() => _DemandaFormDialogState();
}

class _DemandaFormDialogState extends State<_DemandaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _clienteNomeCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _enderecoCtrl = TextEditingController();
  final _obraNomeCtrl = TextEditingController();
  final _etapaProjetoCtrl = TextEditingController();
  final _caminhoPastaRedeCtrl = TextEditingController();
  final _solicitanteCtrl = TextEditingController();
  String _prioridade = 'normal';

  ClienteModel? _clienteSelecionado;
  ObraModel? _obraSelecionada;

  bool get _isEdicao => widget.demanda != null;

  @override
  void initState() {
    super.initState();
    if (_isEdicao) {
      final d = widget.demanda!;
      _clienteNomeCtrl.text = d.clienteNome;
      _telefoneCtrl.text = d.clienteTelefone;
      _enderecoCtrl.text = d.clienteEndereco;
      _obraNomeCtrl.text = d.obraNome;
      _etapaProjetoCtrl.text = d.etapaProjeto;
      _caminhoPastaRedeCtrl.text = d.caminhoPastaRede;
      _solicitanteCtrl.text = d.solicitanteComercial;
      _prioridade = d.prioridade;

      final clientes = BackendClient.clientes.data;
      if (d.clienteId.isNotEmpty) {
        _clienteSelecionado =
            clientes.where((c) => c.id == d.clienteId).firstOrNull;
      } else if (d.clienteNome.isNotEmpty) {
        _clienteSelecionado = clientes
            .where((c) => c.nome.toLowerCase() == d.clienteNome.toLowerCase())
            .firstOrNull;
      }

      if (_clienteSelecionado != null) {
        if (d.obraId.isNotEmpty) {
          _obraSelecionada = _clienteSelecionado!.obras
              .where((o) => o.id == d.obraId)
              .firstOrNull;
        } else if (d.obraNome.isNotEmpty) {
          _obraSelecionada = _clienteSelecionado!.obras.where((o) {
            final desc = o.descricao.isNotEmpty ? o.descricao : o.identificador;
            return desc.toLowerCase() == d.obraNome.toLowerCase();
          }).firstOrNull;
        }
      }
    } else {
      final usuarioLogado = appCtrl.usuario;
      if (usuarioLogado != null && usuarioLogado.nome.isNotEmpty) {
        _solicitanteCtrl.text = usuarioLogado.nome;
      }
    }
  }

  @override
  void dispose() {
    _clienteNomeCtrl.dispose();
    _telefoneCtrl.dispose();
    _enderecoCtrl.dispose();
    _obraNomeCtrl.dispose();
    _etapaProjetoCtrl.dispose();
    _caminhoPastaRedeCtrl.dispose();
    _solicitanteCtrl.dispose();
    super.dispose();
  }

  Future<void> _colarCaminhoClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = (data?.text?.replaceAll('"', '') ?? '').trim();
      if (text.isNotEmpty) {
        setState(() {
          _caminhoPastaRedeCtrl.text = text;
        });
        NotificationService.showPositive(
          'Caminho Colado',
          text,
          position: NotificationPosition.bottom,
        );
      } else {
        NotificationService.showPending(
          'Área de Transferência Vazia',
          'Copie o caminho da pasta no Explorer antes de colar.',
          position: NotificationPosition.bottom,
        );
      }
    } catch (_) {
      NotificationService.showNegative(
        'Permissão Negada',
        'Não foi possível ler a área de transferência. Use Ctrl+V no campo.',
        position: NotificationPosition.bottom,
      );
    }
  }

  Future<void> _selecionarPasta() async {
    try {
      // Só no app desktop (Windows): diálogo nativo de seleção de pasta
      final String? selectedDirectory = await FilePicker.getDirectoryPath(
        dialogTitle: 'Selecione a pasta do projeto',
      );
      if (selectedDirectory == null || selectedDirectory.trim().isEmpty) return;

      setState(() {
        _caminhoPastaRedeCtrl.text = selectedDirectory.trim();
      });

      NotificationService.showPositive(
        'Pasta Selecionada',
        selectedDirectory.trim(),
        position: NotificationPosition.bottom,
      );
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao abrir seletor',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientes = BackendClient.clientes.data;
    final usuarioLogado = appCtrl.usuario;
    final nomeCriador = _isEdicao
        ? (widget.demanda!.criadoPorNome.isNotEmpty
            ? widget.demanda!.criadoPorNome
            : widget.demanda!.solicitanteComercial)
        : (usuarioLogado?.nome.isNotEmpty == true
            ? usuarioLogado!.nome
            : (_solicitanteCtrl.text.isNotEmpty
                ? _solicitanteCtrl.text
                : 'Usuário Atual'));

    final titulo = _isEdicao
        ? 'Editar Demanda D-${widget.demanda!.codigo}'
        : 'Nova Demanda (Aguardando Detalhamento)';
    final subtitulo = _isEdicao
        ? 'Atualize os dados e informações cadastrais da demanda.'
        : 'Cadastre a solicitação na fila de aguardando detalhamento. O detalhamento técnico será gerado posteriormente pelo projetista responsável.';
    final icone = _isEdicao ? Icons.edit_note_rounded : Icons.add_task_rounded;
    final iconeCor = _isEdicao ? const Color(0xFF2563EB) : const Color(0xFF0F172A);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 580,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: iconeCor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icone, size: 20, color: iconeCor),
                        ),
                        const SizedBox(width: 10),
                        Text(titulo, style: AppCss.largeBold.setSize(18)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitulo,
                  style: AppCss.minimumRegular.setColor(const Color(0xFF64748B)),
                ),
                const SizedBox(height: 18),

                // Cliente (Seleção ou Digitação)
                if (clientes.isNotEmpty) ...[
                  ClienteBuscaField(
                    clientes: clientes,
                    selecionado: _clienteSelecionado,
                    onChanged: (val) {
                      setState(() {
                        _clienteSelecionado = val;
                        _obraSelecionada = null;
                        if (val != null) {
                          _clienteNomeCtrl.text = val.nome;
                          _telefoneCtrl.text = val.telefone;
                          final end = val.endereco;
                          final partesEnd = [
                            end.logradouro,
                            if (end.numero.isNotEmpty) end.numero,
                            if (end.bairro.isNotEmpty) end.bairro,
                            if (end.localidade.isNotEmpty)
                              '${end.localidade}/${end.estado}',
                          ].where((p) => p.isNotEmpty).join(', ');
                          _enderecoCtrl.text = partesEnd;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // Telefone e Endereço do Cliente
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        controller: _telefoneCtrl,
                        decoration: InputDecoration(
                          labelText: 'Telefone do Cliente',
                          hintText: '(00) 00000-0000',
                          prefixIcon: const Icon(Icons.phone_outlined, size: 16),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 6,
                      child: TextFormField(
                        controller: _enderecoCtrl,
                        decoration: InputDecoration(
                          labelText: 'Endereço do Cliente',
                          hintText: 'Rua, número, cidade...',
                          prefixIcon: const Icon(Icons.location_on_outlined, size: 16),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Obra do Cliente
                if (_clienteSelecionado != null &&
                    _clienteSelecionado!.obras.isNotEmpty) ...[
                  DropdownButtonFormField<ObraModel>(
                    decoration: InputDecoration(
                      labelText: 'Obra / Projeto',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                    key: ValueKey(_clienteSelecionado?.id ?? 'nenhum'),
                    initialValue: _obraSelecionada,
                    items: _clienteSelecionado!.obras.map((o) {
                      final labelObra = o.descricao.isNotEmpty
                          ? o.descricao
                          : (o.identificador.isNotEmpty
                              ? o.identificador
                              : 'Obra sem nome');
                      return DropdownMenuItem(
                        value: o,
                        child: Text(labelObra, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _obraSelecionada = val;
                        if (val != null) {
                          _obraNomeCtrl.text = val.descricao.isNotEmpty
                              ? val.descricao
                              : val.identificador;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  TextFormField(
                    controller: _obraNomeCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nome da Obra / Projeto',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Informe a obra' : null,
                  ),
                  const SizedBox(height: 12),
                ],

                // Etapa Específica do Projeto
                TextFormField(
                  controller: _etapaProjetoCtrl,
                  decoration: InputDecoration(
                    labelText: 'Escopo da demanda (ex.: estrutura completa)',
                    hintText: 'Ex: 1º Pavimento Tipo - Vigas e Lajes, Fundações...',
                    prefixIcon: const Icon(Icons.layers_outlined, size: 16),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Informe a etapa da obra'
                      : null,
                ),
                const SizedBox(height: 12),

                // Caminho da Pasta do Projeto na Rede / Computador
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _caminhoPastaRedeCtrl,
                        decoration: InputDecoration(
                          labelText:
                              'Caminho da Pasta do Projeto (Rede / Local)',
                          hintText:
                              r'Ex: \\servidor\projetos\obras\edificio_jardins ou C:\Projetos',
                          prefixIcon: const Icon(Icons.folder_shared_outlined,
                              size: 16),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_caminhoPastaRedeCtrl.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear_rounded,
                                      size: 16),
                                  onPressed: () => setState(
                                      () => _caminhoPastaRedeCtrl.clear()),
                                  tooltip: 'Limpar caminho',
                                ),
                              IconButton(
                                icon: const Icon(Icons.content_paste_rounded,
                                    size: 16),
                                onPressed: _colarCaminhoClipboard,
                                tooltip: 'Colar da área de transferência',
                              ),
                            ],
                          ),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        // No navegador não existe seletor de pasta com caminho:
                        // o caminho vem da área de transferência.
                        onPressed: kIsWeb ? _colarCaminhoClipboard : _selecionarPasta,
                        icon: Icon(kIsWeb ? Icons.content_paste_rounded : Icons.folder_open_rounded, size: 16),
                        label: Text(kIsWeb ? 'Colar caminho' : 'Navegar Pasta'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (kIsWeb)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      'No Explorador de Arquivos, clique na pasta e tecle Ctrl+Shift+C '
                      '(Copiar como caminho). Depois clique em "Colar caminho".',
                      style: AppCss.minimumRegular.setSize(11).setColor(const Color(0xFF64748B)),
                    ),
                  ),
                const SizedBox(height: 12),

                // Solicitante Comercial e Prioridade
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: TextFormField(
                        controller: _solicitanteCtrl,
                        decoration: InputDecoration(
                          labelText: 'Solicitante Comercial',
                          hintText: 'Ex: Carlos',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Informe o solicitante'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Prioridade',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                        initialValue: _prioridade,
                        items: const [
                          DropdownMenuItem(
                              value: 'normal', child: Text('Normal')),
                          DropdownMenuItem(
                              value: 'alta', child: Text('Alta')),
                          DropdownMenuItem(
                              value: 'urgente', child: Text('Urgente')),
                        ],
                        onChanged: (val) =>
                            setState(() => _prioridade = val ?? 'normal'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Assinatura do Criador (Informativo)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_outlined,
                          size: 16, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Demanda assinada por: $nomeCriador',
                          style: AppCss.minimumBold
                              .setSize(11.5)
                              .setColor(const Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Botões
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState?.validate() == true) {
                          final clienteNome = _clienteSelecionado?.nome ??
                              _clienteNomeCtrl.text.trim();
                          final obraNome = _obraSelecionada != null
                              ? (_obraSelecionada!.descricao.isNotEmpty
                                  ? _obraSelecionada!.descricao
                                  : _obraSelecionada!.identificador)
                              : _obraNomeCtrl.text.trim();

                          if (_isEdicao) {
                            final demandaAtualizada = widget.demanda!.copyWith(
                              clienteId: _clienteSelecionado?.id ??
                                  widget.demanda!.clienteId,
                              clienteNome: clienteNome.isNotEmpty
                                  ? clienteNome
                                  : widget.demanda!.clienteNome,
                              clienteTelefone: _telefoneCtrl.text.trim(),
                              clienteEndereco: _enderecoCtrl.text.trim(),
                              obraId: _obraSelecionada?.id ??
                                  widget.demanda!.obraId,
                              obraNome: obraNome.isNotEmpty
                                  ? obraNome
                                  : widget.demanda!.obraNome,
                              etapaProjeto: _etapaProjetoCtrl.text.trim(),
                              caminhoPastaRede:
                                  _caminhoPastaRedeCtrl.text.trim(),
                              solicitanteComercial:
                                  _solicitanteCtrl.text.trim(),
                              prioridade: _prioridade,
                            );
                            widget.onSalvar(demandaAtualizada);
                          } else {
                            final nova = DemandaModel(
                              id: '',
                              ordem: 0,
                              codigo: 0,
                              clienteId: _clienteSelecionado?.id ?? '',
                              clienteNome: clienteNome.isNotEmpty
                                  ? clienteNome
                                  : 'Cliente não informado',
                              clienteTelefone: _telefoneCtrl.text.trim(),
                              clienteEndereco: _enderecoCtrl.text.trim(),
                              obraId: _obraSelecionada?.id ?? '',
                              obraNome: obraNome.isNotEmpty
                                  ? obraNome
                                  : 'Obra não informada',
                              etapaProjeto: _etapaProjetoCtrl.text.trim(),
                              caminhoPastaRede:
                                  _caminhoPastaRedeCtrl.text.trim(),
                              solicitanteComercial:
                                  _solicitanteCtrl.text.trim(),
                              etapa: DemandaEtapa.aguardandoFila,
                              prioridade: _prioridade,
                              criadoPorId: usuarioLogado?.id ?? '',
                              criadoPorNome: nomeCriador,
                              criadoEm: DateTime.now(),
                            );
                            widget.onSalvar(nova);
                          }
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(_isEdicao ? 'Salvar Alterações' : 'Cadastrar na Fila'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
