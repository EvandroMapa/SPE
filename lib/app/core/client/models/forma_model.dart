
import 'package:flutter/material.dart';

class FormaModel {
  final String id;
  final String codigo;
  final String descricao;
  final String imagem;
  final List<FormaItemModel> itens;

  FormaModel({
    required this.id,
    required this.codigo,
    required this.descricao,
    required this.imagem,
    required this.itens,
  });

  factory FormaModel.empty() => FormaModel(
        id: '',
        codigo: '',
        descricao: '',
        imagem: '',
        itens: [],
      );

  factory FormaModel.fromSupabaseMap(Map<String, dynamic> map) {
    return FormaModel(
      id: map['id'] ?? '',
      codigo: map['codigo'] ?? '',
      descricao: map['descricao'] ?? '',
      imagem: map['imagem'] ?? '',
      itens: (map['itens'] as List? ?? [])
          .map((e) => FormaItemModel.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    final map = <String, dynamic>{
      'codigo': codigo,
      'descricao': descricao,
      'imagem': imagem,
      'itens': itens.map((e) => e.toMap()).toList(),
    };
    if (id.isNotEmpty && id.length == 36) {
      map['id'] = id;
    }
    return map;
  }
}

class FormaItemModel {
  String trecho;    // código do trecho: "T1", "T2", ...
  int comprimento;  // tamanho do segmento (para o desenho)
  double angulo;
  String orientacao;
  FocusNode focusNode = FocusNode();

  FormaItemModel({
    required this.trecho,
    required this.comprimento,
    required this.angulo,
    required this.orientacao,
  });

  factory FormaItemModel.fromMap(Map<String, dynamic> map) {
    return FormaItemModel(
      trecho: map['trecho'] ?? 'T1',
      comprimento: (map['comprimento'] ?? 10).toInt(),
      angulo: (map['angulo'] ?? 0).toDouble(),
      orientacao: map['orientacao'] ?? 'Horário',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'trecho': trecho,
      'comprimento': comprimento,
      'angulo': angulo,
      'orientacao': orientacao,
    };
  }

  /// Extrai o número do código para ordenação (T1→1, T10→10)
  int get numeroOrdem {
    final s = trecho.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(s) ?? 0;
  }
}
