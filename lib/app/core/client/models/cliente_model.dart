import 'dart:convert';
import 'package:acoplan/app/core/enums/obra_status.dart';
import 'package:acoplan/app/core/models/endereco_model.dart';
import 'package:acoplan/app/core/services/hash_service.dart';

class ClienteModel {
  final String id;
  final int codigo;
  final String nome;
  final String telefone;
  final String cnpj;
  final EnderecoModel endereco;
  final List<ObraModel> obras;

  ClienteModel({
    required this.id,
    required this.codigo,
    required this.nome,
    required this.telefone,
    required this.cnpj,
    required this.endereco,
    required this.obras,
  });

  factory ClienteModel.empty() => ClienteModel(
        id: HashService.get,
        codigo: 0,
        nome: '',
        telefone: '',
        cnpj: '',
        endereco: EnderecoModel.empty(),
        obras: [],
      );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codigo': codigo,
      'nome': nome,
      'telefone': telefone,
      'cnpj': cnpj,
      'endereco': endereco.toMap(),
      'obras': obras.map((x) => x.toMap()).toList(),
    };
  }

  factory ClienteModel.fromMap(Map<String, dynamic> map) {
    return ClienteModel(
      id: map['id'] ?? '',
      codigo: int.tryParse(map['codigo']?.toString() ?? '0') ?? 0,
      nome: map['nome'] ?? '',
      telefone: map['telefone'] ?? '',
      cnpj: map['cnpj'] ?? '',
      endereco: EnderecoModel.fromMap(map['endereco'] ?? {}),
      obras: List<ObraModel>.from(
        (map['obras'] ?? []).map((x) => ObraModel.fromMap(x)),
      ),
    );
  }

  factory ClienteModel.fromSupabaseMap(Map<String, dynamic> map, List<Map<String, dynamic>> obrasRaw) {
    return ClienteModel(
      id: map['id'] ?? '',
      codigo: int.tryParse(map['codigo']?.toString() ?? '0') ?? 0,
      nome: map['nome'] ?? '',
      telefone: map['telefone'] ?? '',
      cnpj: map['cnpj'] ?? '',
      endereco: map['endereco'] != null && map['endereco'] is Map
          ? EnderecoModel.fromMap(Map<String, dynamic>.from(map['endereco']))
          : EnderecoModel.empty(),
      obras: obrasRaw.map((o) => ObraModel.fromSupabaseMap(o)).toList(),
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    final map = <String, dynamic>{
      'nome': nome,
      'telefone': telefone,
      'cnpj': cnpj,
      'endereco': endereco.toMap(),
    };
    if (codigo > 0) {
      map['codigo'] = codigo;
    }
    if (id.length == 36) {
      map['id'] = id;
    }
    return map;
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() => 'ClienteModel(id: $id, nome: $nome)';

  ClienteModel copyWith({
    String? id,
    int? codigo,
    String? nome,
    String? telefone,
    String? cnpj,
    EnderecoModel? endereco,
    List<ObraModel>? obras,
  }) {
    return ClienteModel(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      nome: nome ?? this.nome,
      telefone: telefone ?? this.telefone,
      cnpj: cnpj ?? this.cnpj,
      endereco: endereco ?? this.endereco,
      obras: obras ?? this.obras,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ClienteModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class ObraModel {
  final String id;
  final String identificador;
  final String descricao;
  final String telefoneFixo;
  final String prefixo; // ex: 'Evandro-Sitio' — prefixo do identificador do PT
  EnderecoModel? endereco;
  final ObraStatus status;

  factory ObraModel.empty() => ObraModel(
        id: HashService.get,
        identificador: '',
        descricao: '',
        telefoneFixo: '',
        prefixo: '',
        endereco: null,
        status: ObraStatus.emAndamento,
      );

  ObraModel({
    required this.id,
    required this.identificador,
    required this.descricao,
    required this.telefoneFixo,
    required this.prefixo,
    required this.endereco,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'identificador': identificador,
      'descricao': descricao,
      'telefoneFixo': telefoneFixo,
      'prefixo': prefixo,
      'endereco': endereco?.toMap(),
      'status': status.index,
    };
  }

  factory ObraModel.fromMap(Map<String, dynamic> map) {
    return ObraModel(
      id: map['id'] ?? '',
      identificador: map['identificador'] ?? '',
      descricao: map['descricao'] ?? '',
      telefoneFixo: map['telefoneFixo'] ?? '',
      prefixo: map['prefixo'] ?? '',
      endereco: map['endereco'] != null
          ? EnderecoModel.fromMap(map['endereco'])
          : null,
      status: ObraStatus.values[map['status'] ?? 0],
    );
  }

  factory ObraModel.fromSupabaseMap(Map<String, dynamic> map) {
    return ObraModel(
      id: map['id'] ?? '',
      identificador: map['identificador'] ?? '',
      descricao: map['nome'] ?? '',
      telefoneFixo: map['telefone'] ?? '',
      prefixo: map['prefixo'] ?? '',
      endereco: map['endereco'] != null
          ? EnderecoModel.fromMap(map['endereco'])
          : null,
      status: map['status'] != null
          ? ObraStatus.values[map['status']]
          : ObraStatus.emAndamento,
    );
  }

  Map<String, dynamic> toSupabaseMap(String clienteId) {
    final map = <String, dynamic>{
      'identificador': identificador,
      'nome': descricao,
      'cliente_id': clienteId,
      'telefone': telefoneFixo,
      'prefixo': prefixo,
      'status': status.index,
      'endereco': endereco?.toMap(),
    };
    if (id.length == 36) {
      map['id'] = id;
    }
    return map;
  }

  String toJson() => json.encode(toMap());

  factory ObraModel.fromJson(String source) =>
      ObraModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'ObraModel(id: $id, descricao: $descricao, telefoneFixo: $telefoneFixo, endereco: $endereco, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ObraModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

ObraModel obraDeleteObj = ObraModel(
  id: 'delete',
  identificador: '',
  descricao: '',
  prefixo: '',
  endereco: null,
  status: ObraStatus.emAndamento,
  telefoneFixo: '',
);
