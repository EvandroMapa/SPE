import 'dart:convert';
import 'package:acoplan/app/core/client/models/trecho_variavel_config.dart';
import 'package:acoplan/app/core/services/hash_service.dart';

class PlanilhaModel {
  final String id;
  final int codigo;
  final String clienteId;
  final String clienteNome;
  final String obraId;
  final String obraNome;
  final List<ElementoModel> elementos;
  final double pesoTotal;

  PlanilhaModel({
    required this.id,
    required this.codigo,
    required this.clienteId,
    required this.clienteNome,
    required this.obraId,
    required this.obraNome,
    required this.elementos,
    this.pesoTotal = 0,
  });

  factory PlanilhaModel.empty() => PlanilhaModel(
        id: HashService.get,
        codigo: 0,
        clienteId: '',
        clienteNome: '',
        obraId: '',
        obraNome: '',
        elementos: [],
        pesoTotal: 0,
      );

  factory PlanilhaModel.fromSupabaseMap(
    Map<String, dynamic> map,
    List<Map<String, dynamic>> elementosRaw,
    List<Map<String, dynamic>> posicoesRaw,
  ) {
    // Agrupa posições por elemento_id
    final posicoesPorElemento = <String, List<Map<String, dynamic>>>{};
    for (final p in posicoesRaw) {
      final elemId = p['elemento_id'] as String? ?? '';
      posicoesPorElemento.putIfAbsent(elemId, () => []).add(p);
    }

    final elementos = elementosRaw.map((e) {
      final elemId = e['id'] as String? ?? '';
      return ElementoModel.fromSupabaseMap(e, posicoesPorElemento[elemId] ?? []);
    }).toList();

    return PlanilhaModel(
      id: map['id'] ?? '',
      codigo: int.tryParse(map['codigo']?.toString() ?? '0') ?? 0,
      clienteId: map['cliente_id'] ?? '',
      clienteNome: map['cliente_nome'] ?? '',
      obraId: map['obra_id'] ?? '',
      obraNome: map['obra_nome'] ?? '',
      elementos: elementos,
      pesoTotal: double.tryParse(map['peso_total']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    final map = <String, dynamic>{
      'cliente_id': clienteId,
      'cliente_nome': clienteNome,
      'obra_id': obraId,
      'obra_nome': obraNome,
      'peso_total': pesoTotal,
    };
    if (codigo > 0) {
      map['codigo'] = codigo;
    }
    if (id.length == 36) {
      map['id'] = id;
    }
    return map;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codigo': codigo,
      'cliente_id': clienteId,
      'cliente_nome': clienteNome,
      'obra_id': obraId,
      'obra_nome': obraNome,
      'peso_total': pesoTotal,
      'elementos': elementos.map((e) => e.toMap()).toList(),
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() => 'PlanilhaModel(id: $id, codigo: $codigo)';

  PlanilhaModel copyWith({
    String? id,
    int? codigo,
    String? clienteId,
    String? clienteNome,
    String? obraId,
    String? obraNome,
    List<ElementoModel>? elementos,
    double? pesoTotal,
  }) {
    return PlanilhaModel(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      clienteId: clienteId ?? this.clienteId,
      clienteNome: clienteNome ?? this.clienteNome,
      obraId: obraId ?? this.obraId,
      obraNome: obraNome ?? this.obraNome,
      elementos: elementos ?? this.elementos,
      pesoTotal: pesoTotal ?? this.pesoTotal,
    );
  }
}

class ElementoModel {
  final String id;
  final String nome;
  final int quantidade;
  final double pesoTotal;
  final List<PosicaoModel> posicoes;
  final List<String> elementosEquivalentes;

  ElementoModel({
    required this.id,
    required this.nome,
    required this.quantidade,
    required this.pesoTotal,
    required this.posicoes,
    this.elementosEquivalentes = const [],
  });

  /// Retorna a lista expandida: [nome] + elementosEquivalentes
  List<String> get todosNomes => [nome, ...elementosEquivalentes];

  /// Quantidade total considerando equivalentes
  int get quantidadeExpandida => quantidade * todosNomes.length;

  /// Peso total considerando equivalentes
  double get pesoExpandido => pesoTotal * todosNomes.length;

  factory ElementoModel.empty() => ElementoModel(
        id: HashService.get,
        nome: '',
        quantidade: 0,
        pesoTotal: 0,
        posicoes: [],
        elementosEquivalentes: [],
      );

  factory ElementoModel.fromSupabaseMap(
    Map<String, dynamic> map,
    List<Map<String, dynamic>> posicoesRaw,
  ) {
    return ElementoModel(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      quantidade: int.tryParse(map['quantidade']?.toString() ?? '0') ?? 0,
      pesoTotal: double.tryParse(map['peso_total']?.toString() ?? '0') ?? 0,
      posicoes: posicoesRaw.map((p) => PosicaoModel.fromSupabaseMap(p)).toList(),
      elementosEquivalentes: (map['elementos_equivalentes'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toSupabaseMap(String planilhaId) {
    final map = <String, dynamic>{
      'nome': nome,
      'quantidade': quantidade,
      'peso_total': pesoTotal,
      'planilha_id': planilhaId,
      'elementos_equivalentes': elementosEquivalentes,
    };
    if (id.length == 36) {
      map['id'] = id;
    }
    return map;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'quantidade': quantidade,
      'peso_total': pesoTotal,
      'posicoes': posicoes.map((p) => p.toMap()).toList(),
      'elementos_equivalentes': elementosEquivalentes,
    };
  }

  @override
  String toString() => 'ElementoModel(id: $id, nome: $nome)';
}

class PosicaoModel {
  final String id;
  final int posicao;
  final String bitolaId;
  final String bitolaNome;
  final String formaId;
  final String formaCodigo;
  final int qtde;
  final Map<String, int> comprimentos; // {"T1": 150, "T2": 200, ...}
  final Map<String, bool> variaveis;   // {"T1": true, ...}
  final Map<String, TrechoVariavelConfig> variaveisConfig; // config de variação por trecho
  final int multiplicador;               // multiplicador da posição (ex: 2 = duas peças de cada medida)
  final int comprimentoDeCorte;        // cm — calculado a partir da lógica de corte

  PosicaoModel({
    required this.id,
    required this.posicao,
    required this.bitolaId,
    required this.bitolaNome,
    required this.formaId,
    required this.formaCodigo,
    required this.qtde,
    this.comprimentos = const {},
    this.variaveis = const {},
    this.variaveisConfig = const {},
    this.multiplicador = 1,
    this.comprimentoDeCorte = 0,
  });

  factory PosicaoModel.empty() => PosicaoModel(
        id: HashService.get,
        posicao: 0,
        bitolaId: '',
        bitolaNome: '',
        formaId: '',
        formaCodigo: '',
        qtde: 0,
        comprimentos: {},
        variaveis: {},
        variaveisConfig: {},
      );

  factory PosicaoModel.fromSupabaseMap(Map<String, dynamic> map) {
    return PosicaoModel(
      id: map['id'] ?? '',
      posicao: int.tryParse(map['posicao']?.toString() ?? '0') ?? 0,
      bitolaId: map['bitola_id'] ?? '',
      bitolaNome: map['bitola_nome'] ?? '',
      formaId: map['forma_id'] ?? '',
      formaCodigo: map['forma_codigo'] ?? '',
      qtde: int.tryParse(map['qtde']?.toString() ?? '0') ?? 0,
      comprimentos: map['comprimentos'] != null
          ? Map<String, int>.from((map['comprimentos'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt())))
          : {},
      variaveis: map['variaveis'] != null
          ? Map<String, bool>.from((map['variaveis'] as Map).map((k, v) => MapEntry(k.toString(), v as bool)))
          : {},
      variaveisConfig: map['variaveis_config'] != null
          ? (map['variaveis_config'] as Map).map((k, v) =>
              MapEntry(k.toString(), TrechoVariavelConfig.fromMap(v as Map<String, dynamic>)))
          : {},
      multiplicador: int.tryParse(map['multiplicador']?.toString() ?? '1') ?? 1,
      comprimentoDeCorte: int.tryParse(map['comprimento_de_corte']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toSupabaseMap(String elementoId) {
    final map = <String, dynamic>{
      'posicao': posicao,
      'bitola_id': bitolaId,
      'bitola_nome': bitolaNome,
      'forma_id': formaId,
      'forma_codigo': formaCodigo,
      'qtde': qtde,
      'comprimentos': comprimentos,
      'variaveis': variaveis,
      'variaveis_config': variaveisConfig.map((k, v) => MapEntry(k, v.toMap())),
      'multiplicador': multiplicador,
      'elemento_id': elementoId,
      'comprimento_de_corte': comprimentoDeCorte,
    };
    if (id.length == 36) {
      map['id'] = id;
    }
    return map;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'posicao': posicao,
      'bitola_id': bitolaId,
      'bitola_nome': bitolaNome,
      'forma_id': formaId,
      'forma_codigo': formaCodigo,
      'qtde': qtde,
      'comprimentos': comprimentos,
      'variaveis': variaveis,
      'variaveis_config': variaveisConfig.map((k, v) => MapEntry(k, v.toMap())),
      'multiplicador': multiplicador,
      'comprimento_de_corte': comprimentoDeCorte,
    };
  }

  @override
  String toString() => 'PosicaoModel(id: $id, posicao: $posicao)';
}
