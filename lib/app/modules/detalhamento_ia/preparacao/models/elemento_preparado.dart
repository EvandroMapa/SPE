import 'dart:convert';
import 'dart:ui' show Color, Rect;

/// Cores para elementos no canvas.
class CoresElemento {
  static const _cores = [
    Color(0xFF3B82F6), // azul
    Color(0xFF10B981), // verde
    Color(0xFFF59E0B), // amarelo
    Color(0xFFEF4444), // vermelho
    Color(0xFF8B5CF6), // roxo
    Color(0xFFEC4899), // rosa
    Color(0xFF06B6D4), // ciano
    Color(0xFFF97316), // laranja
    Color(0xFF14B8A6), // teal
    Color(0xFF6366F1), // indigo
    Color(0xFFD946EF), // fuchsia
    Color(0xFF84CC16), // lime
  ];

  static Color obterCor(int indice) => _cores[indice % _cores.length];
}

/// Posição de armadura preparada para importação.
class PosicaoPreparada {
  String posicao;
  int quantidade;
  double bitolaMm;
  String formaCodigo;
  Map<String, int> comprimentos;
  final double x;
  final double y;

  PosicaoPreparada({
    required this.posicao,
    required this.quantidade,
    required this.bitolaMm,
    required this.formaCodigo,
    this.comprimentos = const {},
    required this.x,
    required this.y,
  });

  Map<String, dynamic> toJson() => {
    'posicao': posicao,
    'quantidade': quantidade,
    'bitola_mm': bitolaMm,
    'forma_codigo': formaCodigo,
    'comprimentos': comprimentos,
    'x': x,
    'y': y,
  };

  factory PosicaoPreparada.fromJson(Map<String, dynamic> json) => PosicaoPreparada(
    posicao: json['posicao'] as String,
    quantidade: json['quantidade'] as int,
    bitolaMm: (json['bitola_mm'] as num).toDouble(),
    formaCodigo: json['forma_codigo'] as String,
    comprimentos: (json['comprimentos'] as Map<String, dynamic>?)
        ?.map((k, v) => MapEntry(k, (v as num).toInt())) ?? {},
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
  );
}

/// Elemento estrutural preparado pelo usuário no canvas.
class ElementoPreparado {
  String nome;
  Rect boundingBox;
  Color cor;
  List<PosicaoPreparada> posicoes;
  bool confirmado;
  bool processandoIa;

  ElementoPreparado({
    required this.nome,
    required this.boundingBox,
    required this.cor,
    this.posicoes = const [],
    this.confirmado = false,
    this.processandoIa = false,
  });

  Map<String, dynamic> toJson() => {
    'nome': nome,
    'bounding_box': {
      'x_min': boundingBox.left,
      'y_min': boundingBox.top,
      'x_max': boundingBox.right,
      'y_max': boundingBox.bottom,
    },
    'confirmado': confirmado,
    'posicoes': posicoes.map((p) => p.toJson()).toList(),
  };

  factory ElementoPreparado.fromJson(Map<String, dynamic> json, int indice) {
    final bb = json['bounding_box'] as Map<String, dynamic>;
    return ElementoPreparado(
      nome: json['nome'] as String,
      boundingBox: Rect.fromLTRB(
        (bb['x_min'] as num).toDouble(),
        (bb['y_min'] as num).toDouble(),
        (bb['x_max'] as num).toDouble(),
        (bb['y_max'] as num).toDouble(),
      ),
      cor: CoresElemento.obterCor(indice),
      posicoes: (json['posicoes'] as List)
          .map((p) => PosicaoPreparada.fromJson(p as Map<String, dynamic>))
          .toList(),
      confirmado: json['confirmado'] as bool? ?? false,
    );
  }
}

/// Modelo do arquivo .spe.json de mapeamento.
class MapeamentoDxf {
  final int versao;
  final String arquivoOrigem;
  final DateTime criadoEm;
  DateTime editadoEm;
  final List<ElementoPreparado> elementos;

  MapeamentoDxf({
    this.versao = 1,
    required this.arquivoOrigem,
    DateTime? criadoEm,
    DateTime? editadoEm,
    this.elementos = const [],
  }) : criadoEm = criadoEm ?? DateTime.now(),
       editadoEm = editadoEm ?? DateTime.now();

  String toJsonString() {
    return const JsonEncoder.withIndent('  ').convert({
      'versao': versao,
      'arquivo_origem': arquivoOrigem,
      'criado_em': criadoEm.toIso8601String(),
      'editado_em': editadoEm.toIso8601String(),
      'elementos': elementos.map((e) => e.toJson()).toList(),
    });
  }

  factory MapeamentoDxf.fromJsonString(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    final elementos = (json['elementos'] as List)
        .asMap()
        .entries
        .map((entry) => ElementoPreparado.fromJson(
              entry.value as Map<String, dynamic>, entry.key))
        .toList();
    return MapeamentoDxf(
      versao: json['versao'] as int? ?? 1,
      arquivoOrigem: json['arquivo_origem'] as String,
      criadoEm: DateTime.tryParse(json['criado_em'] as String? ?? '') ?? DateTime.now(),
      editadoEm: DateTime.tryParse(json['editado_em'] as String? ?? '') ?? DateTime.now(),
      elementos: elementos,
    );
  }
}
