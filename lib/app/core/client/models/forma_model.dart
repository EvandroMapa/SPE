
import 'package:flutter/material.dart';

class FormaModel {
  final String id;
  final String codigo;
  final String descricao;
  final String imagem;
  final List<FormaItemModel> itens;
  final double rotacao;
  /// Soma dos ângulos de dobra em equivalentes de 90°.
  /// Ex: 4 dobras 90° = 4.0 | 1 dobra 45° = 0.5
  final double fatorDobra;
  /// Desconto de dobra: multiplicador × diâmetro para calcular corte.
  /// Gerado = fatorDobra × 2, mas editável manualmente.
  final double descontoDobra;

  FormaModel({
    required this.id,
    required this.codigo,
    required this.descricao,
    required this.imagem,
    required this.itens,
    required this.rotacao,
    this.fatorDobra = 0.0,
    this.descontoDobra = 0.0,
  });

  /// Calcula fatorDobra a partir dos itens da forma.
  /// Uma dobra ocorre ENTRE dois trechos, logo o último item
  /// nunca tem dobra após ele — seu ângulo é ignorado.
  static double calcularFatorDobra(List<FormaItemModel> itens) {
    if (itens.length <= 1) return 0.0; // 1 só trecho = sem dobras
    return itens.take(itens.length - 1).fold(
        0.0, (s, item) => s + (item.angulo > 0 ? item.angulo / 90.0 : 0.0));
  }

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
      fatorDobra: (map['fator_dobra'] as num?)?.toDouble() ?? 0.0,
      descontoDobra: (map['desconto_dobra'] as num?)?.toDouble() ?? 0.0,
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
      'fator_dobra': fatorDobra,
      'desconto_dobra': descontoDobra,
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
  /// Grupo de simetria: '' = sem vínculo, 'A'/'B'/'C'/'D' = trechos espelhados.
  /// Trechos do mesmo grupo compartilham o comprimento na digitação.
  String grupoSimetria;
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
    this.grupoSimetria = '',
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
      grupoSimetria: map['grupo_simetria'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'trecho': trecho,
      'comprimento': comprimento,
      'angulo': angulo,
      'orientacao': orientacao,
      'tipo': tipo,
      'grupo_simetria': grupoSimetria,
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
