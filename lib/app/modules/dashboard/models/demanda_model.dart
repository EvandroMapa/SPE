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
