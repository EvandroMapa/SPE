import 'dart:convert';
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
  final String observacao;
  final DateTime criadoEm;
  final List<PedidoTecnicoElementoModel> elementos;

  PedidoTecnicoModel({
    required this.id,
    required this.codigo,
    required this.identificador,
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
  });

  factory PedidoTecnicoModel.empty() => PedidoTecnicoModel(
        id: HashService.get,
        codigo: 0,
        identificador: '',
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
      );

  bool get isAberto => status == 'aberto';

  double get pesoTotal =>
      elementos.fold(0.0, (s, e) => s + e.pesoTotal);

  factory PedidoTecnicoModel.fromSupabaseMap(
    Map<String, dynamic> map,
    List<Map<String, dynamic>> elementosRaw,
  ) {
    return PedidoTecnicoModel(
      id: map['id'] ?? '',
      codigo: int.tryParse(map['codigo']?.toString() ?? '0') ?? 0,
      identificador: map['identificador'] ?? '',
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
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    final map = <String, dynamic>{
      'identificador': identificador,
      'detalhamento_id': detalhamentoId,
      'detalhamento_codigo': detalhamentoCodigo,
      'cliente_id': clienteId,
      'cliente_nome': clienteNome,
      'obra_id': obraId,
      'obra_nome': obraNome,
      'status': status,
      'observacao': observacao,
    };
    if (codigo > 0) map['codigo'] = codigo;
    if (id.length == 36) map['id'] = id;
    return map;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'codigo': codigo,
        'identificador': identificador,
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
      };

  String toJson() => json.encode(toMap());

  PedidoTecnicoModel copyWith({
    String? id,
    int? codigo,
    String? identificador,
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
  }) =>
      PedidoTecnicoModel(
        id: id ?? this.id,
        codigo: codigo ?? this.codigo,
        identificador: identificador ?? this.identificador,
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

  PedidoTecnicoElementoModel({
    required this.id,
    required this.pedidoId,
    required this.elementoId,
    required this.elementoNome,
    required this.elementoQuantidade,
    int? quantidadeSolicitada,
    required this.pesoTotal,
  }) : quantidadeSolicitada = quantidadeSolicitada ?? elementoQuantidade;

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
    );
  }

  Map<String, dynamic> toSupabaseMap(String pedidoId) => {
        'pedido_id': pedidoId,
        'elemento_id': elementoId,
        'elemento_nome': elementoNome,
        'elemento_quantidade': elementoQuantidade,
        'quantidade_solicitada': quantidadeSolicitada,
        'peso_total': pesoTotal,
      };

  Map<String, dynamic> toMap() => {
        'id': id,
        'pedido_id': pedidoId,
        'elemento_id': elementoId,
        'elemento_nome': elementoNome,
        'elemento_quantidade': elementoQuantidade,
        'quantidade_solicitada': quantidadeSolicitada,
        'peso_total': pesoTotal,
      };
}
