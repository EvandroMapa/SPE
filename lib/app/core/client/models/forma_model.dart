
import 'package:flutter/material.dart';

class FormaModel {
  final String id;
  final String codigo;
  final String descricao;
  final String imagem;
  final List<FormaItemModel> itens;
  final double rotacao;

  FormaModel({
    required this.id,
    required this.codigo,
    required this.descricao,
    required this.imagem,
    required this.itens,
    required this.rotacao,
  });

  factory FormaModel.empty() => FormaModel(
        id: '',
        codigo: '',
        descricao: '',
        imagem: '',
        itens: [],
        rotacao: 0,
      );

  factory FormaModel.fromSupabaseMap(Map<String, dynamic> map) {
    return FormaModel(
      id: map['id'] ?? '',
      codigo: map['codigo'] ?? '',
      descricao: map['descricao'] ?? '',
      imagem: map['imagem'] ?? '',
      rotacao: (map['rotacao'] ?? 0).toDouble(),
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
      'rotacao': rotacao,
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
  double _angulo = 0;
  String orientacao;
  /// Tipo do trecho: 'linear' (padrão) ou 'circulo'
  String tipo;
  FocusNode focusNode = FocusNode();
  late TextEditingController anguloController;

  double get angulo => _angulo;
  set angulo(double valor) {
    _angulo = valor;
    // Sincroniza o controller de texto sem mover o cursor
    final novoTexto = valor.toInt().toString();
    if (anguloController.text != novoTexto) {
      anguloController.text = novoTexto;
    }
  }

  FormaItemModel({
    required this.trecho,
    required this.comprimento,
    required double angulo,
    required this.orientacao,
    this.tipo = 'linear',
  }) {
    _angulo = angulo;
    anguloController = TextEditingController(text: angulo.toInt().toString());
  }

  factory FormaItemModel.fromMap(Map<String, dynamic> map) {
    return FormaItemModel(
      trecho: map['trecho'] ?? 'T1',
      comprimento: (map['comprimento'] ?? 10).toInt(),
      angulo: (map['angulo'] ?? 0).toDouble(),
      orientacao: map['orientacao'] ?? 'Horário',
      tipo: map['tipo'] ?? 'linear',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'trecho': trecho,
      'comprimento': comprimento,
      'angulo': angulo,
      'orientacao': orientacao,
      'tipo': tipo,
    };
  }

  void dispose() {
    focusNode.dispose();
    anguloController.dispose();
  }

  /// Extrai o número do código para ordenação (T1→1, T10→10)
  int get numeroOrdem {
    final s = trecho.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(s) ?? 0;
  }
}
