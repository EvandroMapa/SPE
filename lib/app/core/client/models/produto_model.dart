import 'dart:convert';
import 'package:acoplan/app/core/services/hash_service.dart';

class ProdutoModel {
  final String id;
  final String nome;
  final String descricao;
  final double massaFinal;
  final String codigoFinanceiro;
  final int sortIndex;
  final double diametro; // mm — ex: 12.5 para vergalhão ø12,5mm

  factory ProdutoModel.empty() => ProdutoModel(
        id: HashService.get,
        nome: '',
        descricao: '',
        massaFinal: 0.0,
        codigoFinanceiro: '',
        sortIndex: 999,
        diametro: 0.0,
      );

  ProdutoModel({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.massaFinal,
    this.codigoFinanceiro = '',
    this.sortIndex = 999,
    this.diametro = 0.0,
  });

  String get label => '$nome - $descricao';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'descricao': descricao,
      'massa_final': massaFinal,
      'codigo_financeiro': codigoFinanceiro,
      'sort_index': sortIndex,
      'diametro': diametro,
    };
  }

  Map<String, dynamic> toSupabaseMap() {
    final map = <String, dynamic>{
      'nome': nome,
      'descricao': descricao,
      'massa_final': massaFinal,
      'codigo_financeiro': codigoFinanceiro,
      'sort_index': sortIndex,
      'diametro': diametro,
    };
    if (id.length == 36) {
      map['id'] = id;
    }
    return map;
  }

  factory ProdutoModel.fromSupabaseMap(Map<String, dynamic> map) {
    return ProdutoModel(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      descricao: map['descricao'] ?? '',
      massaFinal: double.tryParse(
              (map['massa_final'] ?? map['massaFinal'] ?? '0').toString()) ??
          0.0,
      codigoFinanceiro:
          (map['codigo_financeiro'] ?? map['codigoFinanceiro'] ?? '').toString(),
      sortIndex: (map['sort_index'] ?? map['sortIndex'] ?? 999) as int,
      diametro: (map['diametro'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() => 'ProdutoModel(id: $id, nome: $nome)';

  ProdutoModel copyWith({
    String? id,
    String? nome,
    String? descricao,
    double? massaFinal,
    String? codigoFinanceiro,
    int? sortIndex,
    double? diametro,
  }) {
    return ProdutoModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      massaFinal: massaFinal ?? this.massaFinal,
      codigoFinanceiro: codigoFinanceiro ?? this.codigoFinanceiro,
      sortIndex: sortIndex ?? this.sortIndex,
      diametro: diametro ?? this.diametro,
    );
  }
}
