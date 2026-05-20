/// Configuração de variação para um trecho de uma posição.
/// Armazena a faixa (inicial/final), modo de distribuição e medidas geradas.
/// O multiplicador fica na posição (PosicaoCreateModel), não aqui.
class TrechoVariavelConfig {
  int inicial;
  int final_;
  String distribuicao; // 'linear' ou 'manual'
  List<int> medidas;

  TrechoVariavelConfig({
    this.inicial = 0,
    this.final_ = 0,
    this.distribuicao = 'linear',
    List<int>? medidas,
  }) : medidas = medidas ?? [];

  /// Gera medidas com interpolação linear.
  /// [qtdePosicao] = quantidade total da posição (ex: 20 peças).
  /// [multiplicador] = multiplicador da posição (ex: 2 = duas peças de cada medida).
  void gerarLinear(int qtdePosicao, {int multiplicador = 1}) {
    final medidasUnicas = multiplicador > 0
        ? qtdePosicao ~/ multiplicador
        : qtdePosicao;
    if (medidasUnicas <= 0) {
      medidas = [];
      return;
    }
    if (medidasUnicas == 1) {
      medidas = [inicial];
      return;
    }
    final passo = (final_ - inicial) / (medidasUnicas - 1);
    medidas = List.generate(
      medidasUnicas,
      (i) => (inicial + passo * i).round(),
    );
  }

  /// Retorna a lista expandida (com multiplicador aplicado).
  /// Ex: medidas=[100,150,200], multiplicador=2 → [100,100,150,150,200,200]
  List<int> medidasExpandidas(int multiplicador) {
    final resultado = <int>[];
    for (final m in medidas) {
      for (int j = 0; j < multiplicador; j++) {
        resultado.add(m);
      }
    }
    return resultado;
  }

  factory TrechoVariavelConfig.fromMap(Map<String, dynamic> map) {
    return TrechoVariavelConfig(
      inicial: (map['inicial'] as num?)?.toInt() ?? 0,
      final_: (map['final'] as num?)?.toInt() ?? 0,
      distribuicao: map['distribuicao'] ?? 'linear',
      medidas: (map['medidas'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'inicial': inicial,
      'final': final_,
      'distribuicao': distribuicao,
      'medidas': medidas,
    };
  }

  TrechoVariavelConfig copyWith({
    int? inicial,
    int? final_,
    String? distribuicao,
    List<int>? medidas,
  }) {
    return TrechoVariavelConfig(
      inicial: inicial ?? this.inicial,
      final_: final_ ?? this.final_,
      distribuicao: distribuicao ?? this.distribuicao,
      medidas: medidas ?? List<int>.from(this.medidas),
    );
  }
}
