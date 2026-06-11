
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

  /// Serializa todos os dados da forma (incluindo desenho) para snapshot histórico.
  /// Sempre inclui o id — use para preservar o estado no momento do detalhamento.
  Map<String, dynamic> toSnapshot() {
    final map = toSupabaseMap();
    if (id.isNotEmpty) map['id'] = id;
    return map;
  }

  /// Reconstrói uma FormaModel a partir de um snapshot armazenado.
  static FormaModel? fromSnapshot(Map<String, dynamic>? snapshot) {
    if (snapshot == null || snapshot.isEmpty) return null;
    return FormaModel.fromSupabaseMap(snapshot);
  }
}

class FormaItemModel {
  String trecho;    // código do trecho: "T1", "T2", ...
  double _comprimento = 10.0;
  double _angulo = 0;
  String orientacao;
  /// Tipo do trecho: 'linear' (padrão) ou 'circulo'
  String tipo;
  /// Grupo de simetria: '' = sem vínculo, 'A'/'B'/'C'/'D' = trechos espelhados.
  /// Trechos do mesmo grupo compartilham o comprimento na digitação.
  String grupoSimetria;
  /// Se true, o comprimento deste trecho é sugerido automaticamente no detalhamento
  /// usando a fórmula: floor(diâmetro_bitola_mm) cm. Ex: ø12,5mm → 12cm.
  bool ancoragemAutomatica;
  /// Se true, desenha uma linha perpendicular (divisória) no ponto final deste trecho
  /// — puramente visual, aparece no preview e no PDF.
  bool linhaDivisoria;
  
  FocusNode focoComprimento = FocusNode();
  FocusNode focoAngulo = FocusNode();
  FocusNode get focusNode => focoAngulo;
  
  late TextEditingController comprimentoController;
  late TextEditingController anguloController;

  double get comprimento => _comprimento;
  set comprimento(double valor) {
    _comprimento = valor;
    // Sincroniza o controller de texto sem mover o cursor se o valor já for igual
    final novoTexto = valor.toString().replaceAll(RegExp(r'\.0$'), '');
    if (comprimentoController.text != novoTexto) {
      comprimentoController.text = novoTexto;
    }
  }

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
    required double comprimento,
    required double angulo,
    required this.orientacao,
    this.tipo = 'linear',
    this.grupoSimetria = '',
    this.ancoragemAutomatica = false,
    this.linhaDivisoria = false,
  }) {
    _comprimento = comprimento;
    _angulo = angulo;
    comprimentoController = TextEditingController(text: comprimento.toString().replaceAll(RegExp(r'\.0$'), ''));
    anguloController = TextEditingController(text: angulo.toInt().toString());
  }

  factory FormaItemModel.fromMap(Map<String, dynamic> map) {
    return FormaItemModel(
      trecho: map['trecho'] ?? 'T1',
      comprimento: (map['comprimento'] ?? 10.0).toDouble(),
      angulo: (map['angulo'] ?? 0).toDouble(),
      orientacao: map['orientacao'] ?? 'Horário',
      tipo: map['tipo'] ?? 'linear',
      grupoSimetria: map['grupo_simetria'] ?? '',
      ancoragemAutomatica: map['ancoragem_automatica'] as bool? ?? false,
      linhaDivisoria: map['linha_divisoria'] as bool? ?? false,
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
      'ancoragem_automatica': ancoragemAutomatica,
      'linha_divisoria': linhaDivisoria,
    };
  }

  void dispose() {
    focoComprimento.dispose();
    focoAngulo.dispose();
    comprimentoController.dispose();
    anguloController.dispose();
  }

  /// Extrai o número do código para ordenação (T1→1, T10→10)
  int get numeroOrdem {
    final s = trecho.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(s) ?? 0;
  }
}
