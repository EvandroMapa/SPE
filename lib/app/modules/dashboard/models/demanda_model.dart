enum DemandaEtapa {
  aguardandoFila,     // 1 - Aguardando detalhamento (ordenação manual)
  emProducao,         // 2 - Em produção
  aguardandoCorrecao, // 3 - Aguardando correção
  corrigindo,         // 4 - Corrigindo
  finalizadoLiberado, // 5 - Finalizado / Liberado
}

extension DemandaEtapaExt on DemandaEtapa {
  String get label {
    switch (this) {
      case DemandaEtapa.aguardandoFila:
        return 'Aguardando detalhamento';
      case DemandaEtapa.emProducao:
        return 'Em produção';
      case DemandaEtapa.aguardandoCorrecao:
        return 'Aguardando correção';
      case DemandaEtapa.corrigindo:
        return 'Corrigindo';
      case DemandaEtapa.finalizadoLiberado:
        return 'Finalizado / Liberado';
    }
  }

  String get descricao {
    switch (this) {
      case DemandaEtapa.aguardandoFila:
        return 'Aguardando início do detalhamento';
      case DemandaEtapa.emProducao:
        return 'Detalhamento ativo';
      case DemandaEtapa.aguardandoCorrecao:
        return 'Aguardando revisão técnica';
      case DemandaEtapa.corrigindo:
        return 'Ajuste em execução';
      case DemandaEtapa.finalizadoLiberado:
        return 'Pronto para Pedido Técnico';
    }
  }
}

/// Decisão tomada quando a demanda chega em Finalizado.
enum DemandaDesfecho { projeto, orcamento, desistencia }

extension DemandaDesfechoExt on DemandaDesfecho {
  String get label {
    switch (this) {
      case DemandaDesfecho.projeto:
        return 'Virou projeto';
      case DemandaDesfecho.orcamento:
        return 'Orçamento';
      case DemandaDesfecho.desistencia:
        return 'Cliente desistiu';
    }
  }

  static DemandaDesfecho? parse(String? v) {
    for (final d in DemandaDesfecho.values) {
      if (d.name == v) return d;
    }
    return null;
  }
}

class DemandaModel {
  final String id;
  int ordem; // Posição para ordenação manual na fila
  final int codigo;
  final String clienteId;
  final String clienteNome;
  final String clienteTelefone;
  final String clienteEndereco;
  final String obraId;
  final String obraNome;
  final String etapaProjeto; // Ex: "Fundações e Blocos", "2º Pavimento - Vigas"
  final String caminhoPastaRede; // Ex: "\\servidor\projetos\obra_x"
  final String solicitanteComercial; // Ex: "Carlos (Comercial)"
  DemandaEtapa etapa;
  final String prioridade; // 'normal' | 'alta' | 'urgente'
  final String? detalhamentoId;
  final String? motivoCorrecao;
  final String criadoPorId;
  final String criadoPorNome; // Assinatura do usuário criador
  final bool isArquivado;
  final DateTime criadoEm;
  /// Gravados só pelo banco (RPC definir_desfecho_demanda).
  final DemandaDesfecho? desfecho;
  final DateTime? desfechoEm;
  final String desfechoPor;
  final String motivoDesfecho;

  /// Desfecho/trava da migração 04 não são mais usados (ver migração 05).
  bool get travada => false;

  /// Etapas (partes) da demanda: Sapatas, Vigas baldrame...
  final List<DemandaEtapaModel> etapas;

  /// Pedido técnico só pode ser emitido com a demanda nesta coluna.
  bool get liberadaParaPedido => etapa == DemandaEtapa.finalizadoLiberado;

  DemandaModel({
    required this.id,
    required this.ordem,
    required this.codigo,
    required this.clienteId,
    required this.clienteNome,
    this.clienteTelefone = '',
    this.clienteEndereco = '',
    required this.obraId,
    required this.obraNome,
    required this.etapaProjeto,
    this.caminhoPastaRede = '',
    this.solicitanteComercial = '',
    required this.etapa,
    this.prioridade = 'normal',
    this.detalhamentoId,
    this.motivoCorrecao,
    this.criadoPorId = '',
    this.criadoPorNome = '',
    this.isArquivado = false,
    required this.criadoEm,
    this.desfecho,
    this.desfechoEm,
    this.desfechoPor = '',
    this.motivoDesfecho = '',
    this.etapas = const [],
  });

  bool get temDetalhamento => detalhamentoId != null && detalhamentoId!.isNotEmpty;

  DemandaModel copyWith({
    String? id,
    int? ordem,
    int? codigo,
    String? clienteId,
    String? clienteNome,
    String? clienteTelefone,
    String? clienteEndereco,
    String? obraId,
    String? obraNome,
    String? etapaProjeto,
    String? caminhoPastaRede,
    String? solicitanteComercial,
    DemandaEtapa? etapa,
    String? prioridade,
    String? detalhamentoId,
    String? motivoCorrecao,
    String? criadoPorId,
    String? criadoPorNome,
    bool? isArquivado,
    DateTime? criadoEm,
  }) {
    return DemandaModel(
      id: id ?? this.id,
      ordem: ordem ?? this.ordem,
      codigo: codigo ?? this.codigo,
      clienteId: clienteId ?? this.clienteId,
      clienteNome: clienteNome ?? this.clienteNome,
      clienteTelefone: clienteTelefone ?? this.clienteTelefone,
      clienteEndereco: clienteEndereco ?? this.clienteEndereco,
      obraId: obraId ?? this.obraId,
      obraNome: obraNome ?? this.obraNome,
      etapaProjeto: etapaProjeto ?? this.etapaProjeto,
      caminhoPastaRede: caminhoPastaRede ?? this.caminhoPastaRede,
      solicitanteComercial: solicitanteComercial ?? this.solicitanteComercial,
      etapa: etapa ?? this.etapa,
      prioridade: prioridade ?? this.prioridade,
      detalhamentoId: detalhamentoId ?? this.detalhamentoId,
      motivoCorrecao: motivoCorrecao ?? this.motivoCorrecao,
      criadoPorId: criadoPorId ?? this.criadoPorId,
      criadoPorNome: criadoPorNome ?? this.criadoPorNome,
      isArquivado: isArquivado ?? this.isArquivado,
      criadoEm: criadoEm ?? this.criadoEm,
      desfecho: desfecho,
      desfechoEm: desfechoEm,
      desfechoPor: desfechoPor,
      motivoDesfecho: motivoDesfecho,
      etapas: etapas,
    );
  }

  factory DemandaModel.fromSupabaseMap(Map<String, dynamic> map) {
    DemandaEtapa etapaParse = DemandaEtapa.aguardandoFila;
    final etapaStr = map['etapa']?.toString() ?? '';
    for (final e in DemandaEtapa.values) {
      if (e.name == etapaStr) {
        etapaParse = e;
        break;
      }
    }

    return DemandaModel(
      id: map['id']?.toString() ?? '',
      ordem: int.tryParse(map['ordem']?.toString() ?? '1') ?? 1,
      codigo: int.tryParse(map['codigo']?.toString() ?? '0') ?? 0,
      clienteId: map['cliente_id']?.toString() ?? '',
      clienteNome: map['cliente_nome']?.toString() ?? '',
      clienteTelefone: map['cliente_telefone']?.toString() ?? '',
      clienteEndereco: map['cliente_endereco']?.toString() ?? '',
      obraId: map['obra_id']?.toString() ?? '',
      obraNome: map['obra_nome']?.toString() ?? '',
      etapaProjeto: map['etapa_projeto']?.toString() ?? '',
      caminhoPastaRede: map['caminho_pasta_rede']?.toString() ?? '',
      solicitanteComercial: map['solicitante_comercial']?.toString() ?? '',
      etapa: etapaParse,
      prioridade: map['prioridade']?.toString() ?? 'normal',
      detalhamentoId: map['detalhamento_id']?.toString(),
      motivoCorrecao: map['motivo_correcao']?.toString(),
      criadoPorId: map['criado_por_id']?.toString() ?? '',
      criadoPorNome: map['criado_por_nome']?.toString() ?? '',
      isArquivado: map['is_arquivado'] == true,
      criadoEm: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      desfecho: DemandaDesfechoExt.parse(map['desfecho']?.toString()),
      desfechoEm: DateTime.tryParse(map['desfecho_em']?.toString() ?? ''),
      desfechoPor: map['desfecho_por']?.toString() ?? '',
      motivoDesfecho: map['motivo_desfecho']?.toString() ?? '',
      etapas: (List<Map<String, dynamic>>.from(map['demanda_etapas'] as List? ?? const [])
              .map(DemandaEtapaModel.fromMap)
              .toList()
            ..sort((a, b) => a.ordem.compareTo(b.ordem))),
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    final map = <String, dynamic>{
      'ordem': ordem,
      'cliente_id': clienteId.isEmpty ? null : clienteId,
      'cliente_nome': clienteNome,
      'cliente_telefone': clienteTelefone.isEmpty ? null : clienteTelefone,
      'cliente_endereco': clienteEndereco.isEmpty ? null : clienteEndereco,
      'obra_id': obraId.isEmpty ? null : obraId,
      'obra_nome': obraNome,
      'etapa_projeto': etapaProjeto,
      'caminho_pasta_rede': caminhoPastaRede.isEmpty ? null : caminhoPastaRede,
      'solicitante_comercial':
          solicitanteComercial.isEmpty ? null : solicitanteComercial,
      'etapa': etapa.name,
      'prioridade': prioridade,
      'detalhamento_id': detalhamentoId,
      'motivo_correcao': motivoCorrecao,
      'criado_por_id': criadoPorId.isEmpty ? null : criadoPorId,
      'criado_por_nome': criadoPorNome.isEmpty ? null : criadoPorNome,
      'is_arquivado': isArquivado,
    };
    if (codigo > 0) {
      map['codigo'] = codigo;
    }
    if (id.isNotEmpty && id.length == 36) {
      map['id'] = id;
    }
    return map;
  }
}

/// Registro do histórico (tabela demanda_eventos).
class DemandaEvento {
  final String tipo; // criada, etapa, desfecho, arquivada, desarquivada, liberada, convertida, cancelada, planilha_criada
  final String? de;
  final String? para;
  final String motivo;
  final String usuarioNome;
  final DateTime criadoEm;
  final String? detalhamentoId;

  DemandaEvento({
    required this.tipo,
    this.de,
    this.para,
    this.motivo = '',
    this.usuarioNome = '',
    required this.criadoEm,
    this.detalhamentoId,
  });

  factory DemandaEvento.fromMap(Map<String, dynamic> m) => DemandaEvento(
        tipo: m['tipo']?.toString() ?? '',
        de: m['de']?.toString(),
        para: m['para']?.toString(),
        motivo: m['motivo']?.toString() ?? '',
        usuarioNome: m['usuario_nome']?.toString() ?? '',
        criadoEm: (DateTime.tryParse(m['criado_em']?.toString() ?? '') ?? DateTime.now()).toLocal(),
        detalhamentoId: m['detalhamento_id']?.toString(),
      );

  static String _etapa(String? nome) {
    for (final e in DemandaEtapa.values) {
      if (e.name == nome) return e.label;
    }
    return nome ?? '';
  }

  /// Texto legível do evento.
  String get descricao {
    switch (tipo) {
      case 'criada':
        return 'Demanda criada';
      case 'etapa':
        return '${_etapa(de)} → ${_etapa(para)}';
      case 'desfecho':
        return 'Desfecho: ${DemandaDesfechoExt.parse(para)?.label ?? para}';
      case 'arquivada':
        return 'Arquivada';
      case 'desarquivada':
        return 'Desarquivada';
      case 'planilha_criada':
        return 'Planilha criada';
      case 'liberada':
        return 'Planilha liberada como projeto';
      case 'convertida':
        return 'Orçamento convertido em projeto';
      case 'cancelada':
        return 'Projeto cancelado';
      case 'etapa_criada':
        return 'Etapa criada: ${para ?? ''}';
      case 'etapa_removida':
        return 'Etapa removida: ${de ?? ''}';
      case 'etapa_vinculo':
        return para == null || para!.isEmpty
            ? 'Etapa $motivo saiu do detalhamento'
            : 'Etapa $motivo vinculada a detalhamento';
      default:
        return tipo;
    }
  }
}

/// Etapa (parte) de uma demanda. Pode estar coberta por um detalhamento.
class DemandaEtapaModel {
  final String id;
  final String demandaId;
  final String nome;
  final int ordem;
  final String? detalhamentoId;

  const DemandaEtapaModel({
    required this.id,
    required this.demandaId,
    required this.nome,
    this.ordem = 0,
    this.detalhamentoId,
  });

  bool get temDetalhamento => detalhamentoId != null && detalhamentoId!.isNotEmpty;

  factory DemandaEtapaModel.fromMap(Map<String, dynamic> m) => DemandaEtapaModel(
        id: m['id']?.toString() ?? '',
        demandaId: m['demanda_id']?.toString() ?? '',
        nome: m['nome']?.toString() ?? '',
        ordem: int.tryParse(m['ordem']?.toString() ?? '0') ?? 0,
        detalhamentoId: m['detalhamento_id']?.toString(),
      );
}
