import 'dart:convert';
import 'package:acoplan/app/core/client/models/detalhamento_model.dart';
import 'package:acoplan/app/core/services/hash_service.dart';

class PedidoTecnicoModel {
  final String id;
  final int codigo;
  final String identificador; // ex: 'Evandro-Sitio.001'
  final String detalhamentoId;
  final int detalhamentoCodigo;
  final String clienteId;
  final String clienteNome;
  final String obraId;
  final String obraNome;
  final String status; // 'aberto' | 'cancelado'
  final String tipoServico; // 'CD' | 'CDA'
  final String observacao;
  final DateTime criadoEm;
  final List<PedidoTecnicoElementoModel> elementos;
  /// Resumo de aço pré-calculado: {"bitolas": {...}, "elementos": {...}, "peso_total": ...}
  final Map<String, dynamic>? resumoAco;

  PedidoTecnicoModel({
    required this.id,
    required this.codigo,
    required this.identificador,
    this.tipoServico = 'CD',
    required this.detalhamentoId,
    required this.detalhamentoCodigo,
    required this.clienteId,
    required this.clienteNome,
    required this.obraId,
    required this.obraNome,
    required this.status,
    required this.observacao,
    required this.criadoEm,
    required this.elementos,
    this.resumoAco,
  });

  factory PedidoTecnicoModel.empty() => PedidoTecnicoModel(
        id: HashService.get,
        codigo: 0,
        identificador: '',
        tipoServico: 'CD',
        detalhamentoId: '',
        detalhamentoCodigo: 0,
        clienteId: '',
        clienteNome: '',
        obraId: '',
        obraNome: '',
        status: 'aberto',
        observacao: '',
        criadoEm: DateTime.now(),
        elementos: [],
        resumoAco: null,
      );

  bool get isAberto => status == 'aberto';

  /// Detalhamento como estava quando o pedido foi salvo: os elementos deste
  /// pedido vêm do snapshot gravado (se houver), os demais do detalhamento atual.
  /// Garante que reimprimir um pedido gere exatamente o que foi produzido.
  DetalhamentoModel? detalhamentoDoPedido(DetalhamentoModel? atual) {
    final snapshots = <String, ElementoModel>{};
    for (final e in elementos) {
      final snap = e.elementoDoSnapshot;
      if (snap != null) snapshots[e.elementoId] = snap;
    }
    if (snapshots.isEmpty) return atual;

    final base = atual ??
        DetalhamentoModel(
          id: detalhamentoId,
          codigo: detalhamentoCodigo,
          clienteId: clienteId,
          clienteNome: clienteNome,
          obraId: obraId,
          obraNome: obraNome,
          elementos: const [],
        );
    final idsAtuais = base.elementos.map((e) => e.id).toSet();
    return base.copyWith(elementos: [
      ...base.elementos.map((e) => snapshots[e.id] ?? e),
      ...snapshots.values.where((s) => !idsAtuais.contains(s.id)),
    ]);
  }

  double get pesoTotal {
    final pesoResumo =
        double.tryParse(resumoAco?['peso_total']?.toString() ?? '0') ?? 0;
    if (pesoResumo > 0) return pesoResumo;
    return elementos.fold(0.0, (s, e) => s + e.pesoTotal);
  }

  /// Converte a linha com os elementos aninhados (`pedido_tecnico_elementos`).
  factory PedidoTecnicoModel.fromSupabaseRow(Map<String, dynamic> row) =>
      PedidoTecnicoModel.fromSupabaseMap(
        row,
        List<Map<String, dynamic>>.from(row['pedido_tecnico_elementos'] as List? ?? const []),
      );

  factory PedidoTecnicoModel.fromSupabaseMap(
    Map<String, dynamic> map,
    List<Map<String, dynamic>> elementosRaw,
  ) {
    return PedidoTecnicoModel(
      id: map['id'] ?? '',
      codigo: int.tryParse(map['codigo']?.toString() ?? '0') ?? 0,
      identificador: map['identificador'] ?? '',
      tipoServico: (map['tipo_servico']?.toString().isNotEmpty == true)
          ? map['tipo_servico'].toString()
          : 'CD',
      detalhamentoId: map['detalhamento_id'] ?? '',
      detalhamentoCodigo:
          int.tryParse(map['detalhamento_codigo']?.toString() ?? '0') ?? 0,
      clienteId: map['cliente_id'] ?? '',
      clienteNome: map['cliente_nome'] ?? '',
      obraId: map['obra_id'] ?? '',
      obraNome: map['obra_nome'] ?? '',
      status: map['status'] ?? 'aberto',
      observacao: map['observacao'] ?? '',
      criadoEm: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      elementos: elementosRaw
          .map((e) => PedidoTecnicoElementoModel.fromSupabaseMap(e))
          .toList(),
      resumoAco: map['resumo_aco'] != null
          ? Map<String, dynamic>.from(map['resumo_aco'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    final map = <String, dynamic>{
      'identificador': identificador,
      'detalhamento_id': detalhamentoId,
      'detalhamento_codigo': detalhamentoCodigo,
      // IDs vazios viram null (o banco não aceita '' em coluna uuid)
      'cliente_id': clienteId.isEmpty ? null : clienteId,
      'cliente_nome': clienteNome,
      'obra_id': obraId.isEmpty ? null : obraId,
      'obra_nome': obraNome,
      'status': status,
      'observacao': observacao,
      'tipo_servico': tipoServico.isNotEmpty ? tipoServico : 'CD',
    };
    if (resumoAco != null) map['resumo_aco'] = resumoAco;
    if (codigo > 0) map['codigo'] = codigo;
    if (id.length == 36) map['id'] = id;
    return map;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'codigo': codigo,
        'identificador': identificador,
        'tipo_servico': tipoServico,
        'detalhamento_id': detalhamentoId,
        'detalhamento_codigo': detalhamentoCodigo,
        'cliente_id': clienteId,
        'cliente_nome': clienteNome,
        'obra_id': obraId,
        'obra_nome': obraNome,
        'status': status,
        'observacao': observacao,
        'created_at': criadoEm.toIso8601String(),
        'elementos': elementos.map((e) => e.toMap()).toList(),
        'resumo_aco': resumoAco,
      };

  String toJson() => json.encode(toMap());

  PedidoTecnicoModel copyWith({
    String? id,
    int? codigo,
    String? identificador,
    String? tipoServico,
    String? detalhamentoId,
    int? detalhamentoCodigo,
    String? clienteId,
    String? clienteNome,
    String? obraId,
    String? obraNome,
    String? status,
    String? observacao,
    DateTime? criadoEm,
    List<PedidoTecnicoElementoModel>? elementos,
    Map<String, dynamic>? resumoAco,
  }) =>
      PedidoTecnicoModel(
        id: id ?? this.id,
        codigo: codigo ?? this.codigo,
        identificador: identificador ?? this.identificador,
        tipoServico: tipoServico ?? this.tipoServico,
        detalhamentoId: detalhamentoId ?? this.detalhamentoId,
        detalhamentoCodigo: detalhamentoCodigo ?? this.detalhamentoCodigo,
        clienteId: clienteId ?? this.clienteId,
        clienteNome: clienteNome ?? this.clienteNome,
        obraId: obraId ?? this.obraId,
        obraNome: obraNome ?? this.obraNome,
        status: status ?? this.status,
        observacao: observacao ?? this.observacao,
        criadoEm: criadoEm ?? this.criadoEm,
        elementos: elementos ?? this.elementos,
        resumoAco: resumoAco ?? this.resumoAco,
      );

  @override
  String toString() =>
      'PedidoTecnicoModel(id: $id, codigo: $codigo, status: $status)';
}

class PedidoTecnicoElementoModel {
  final String id;
  final String pedidoId;
  final String elementoId;
  final String elementoNome;
  final int elementoQuantidade;
  final int quantidadeSolicitada;
  final double pesoTotal;
  /// Número sequencial da primeira posição deste elemento no pedido.
  /// As demais posições recebem sequenciaInicio+1, sequenciaInicio+2...
  /// null = pedido antigo (ainda não recalculado).
  final int? sequenciaInicio;
  /// Cópia do elemento (com posições) no momento em que o pedido foi salvo.
  /// null = pedido antigo (usa o detalhamento atual).
  final Map<String, dynamic>? elementoSnapshot;

  ElementoModel? get elementoDoSnapshot {
    final snap = elementoSnapshot;
    if (snap == null || snap.isEmpty) return null;
    return ElementoModel.fromSupabaseMap(
      snap,
      List<Map<String, dynamic>>.from(
        (snap['posicoes'] as List? ?? const []).map((p) => Map<String, dynamic>.from(p as Map)),
      ),
    );
  }

  PedidoTecnicoElementoModel({
    required this.id,
    required this.pedidoId,
    required this.elementoId,
    required this.elementoNome,
    required this.elementoQuantidade,
    int? quantidadeSolicitada,
    required this.pesoTotal,
    this.sequenciaInicio,
    this.elementoSnapshot,
  }) : quantidadeSolicitada = quantidadeSolicitada ?? elementoQuantidade;

  /// Retorna o número de sequência da posição de índice [indicePosicao] (base 0).
  /// Retorna null se ainda não houver sequência gravada.
  int? sequenciaDaPosicao(int indicePosicao) =>
      sequenciaInicio != null ? sequenciaInicio! + indicePosicao : null;

  factory PedidoTecnicoElementoModel.fromSupabaseMap(
      Map<String, dynamic> map) {
    final elemQtde = int.tryParse(map['elemento_quantidade']?.toString() ?? '0') ?? 0;
    return PedidoTecnicoElementoModel(
      id: map['id'] ?? '',
      pedidoId: map['pedido_id'] ?? '',
      elementoId: map['elemento_id'] ?? '',
      elementoNome: map['elemento_nome'] ?? '',
      elementoQuantidade: elemQtde,
      quantidadeSolicitada:
          int.tryParse(map['quantidade_solicitada']?.toString() ?? '') ?? elemQtde,
      pesoTotal:
          double.tryParse(map['peso_total']?.toString() ?? '0') ?? 0.0,
      sequenciaInicio: int.tryParse(map['sequencia_inicio']?.toString() ?? ''),
      elementoSnapshot: map['elemento_snapshot'] is Map
          ? Map<String, dynamic>.from(map['elemento_snapshot'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toSupabaseMap(String pedidoId) {
    final map = <String, dynamic>{
      'pedido_id': pedidoId,
      'elemento_id': elementoId,
      'elemento_nome': elementoNome,
      'elemento_quantidade': elementoQuantidade,
      'quantidade_solicitada': quantidadeSolicitada,
      'peso_total': pesoTotal,
    };
    if (sequenciaInicio != null) map['sequencia_inicio'] = sequenciaInicio;
    if (elementoSnapshot != null) map['elemento_snapshot'] = elementoSnapshot;
    return map;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'pedido_id': pedidoId,
        'elemento_id': elementoId,
        'elemento_nome': elementoNome,
        'elemento_quantidade': elementoQuantidade,
        'quantidade_solicitada': quantidadeSolicitada,
        'peso_total': pesoTotal,
        'sequencia_inicio': sequenciaInicio,
        'elemento_snapshot': elementoSnapshot,
      };
}
