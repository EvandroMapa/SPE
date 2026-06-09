import 'dart:convert';
import 'package:acoplan/app/core/client/models/bitola_model.dart';
import 'package:acoplan/app/core/client/models/forma_model.dart';
import 'package:acoplan/app/core/client/models/trecho_variavel_config.dart';
import 'package:acoplan/app/core/services/hash_service.dart';

class DetalhamentoModel {
  final String id;
  final int codigo;
  final String clienteId;
  final String clienteNome;
  final String obraId;
  final String obraNome;
  final List<ElementoModel> elementos;
  final double pesoTotal;

  DetalhamentoModel({
    required this.id,
    required this.codigo,
    required this.clienteId,
    required this.clienteNome,
    required this.obraId,
    required this.obraNome,
    required this.elementos,
    this.pesoTotal = 0,
  });

  factory DetalhamentoModel.empty() => DetalhamentoModel(
        id: HashService.get,
        codigo: 0,
        clienteId: '',
        clienteNome: '',
        obraId: '',
        obraNome: '',
        elementos: [],
        pesoTotal: 0,
      );

  factory DetalhamentoModel.fromSupabaseMap(
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

    return DetalhamentoModel(
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
  String toString() => 'DetalhamentoModel(id: $id, codigo: $codigo)';

  DetalhamentoModel copyWith({
    String? id,
    int? codigo,
    String? clienteId,
    String? clienteNome,
    String? obraId,
    String? obraNome,
    List<ElementoModel>? elementos,
    double? pesoTotal,
  }) {
    return DetalhamentoModel(
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

  Map<String, dynamic> toSupabaseMap(String detalhamentoId) {
    final map = <String, dynamic>{
      'nome': nome,
      'quantidade': quantidade,
      'peso_total': pesoTotal,
      'detalhamento_id': detalhamentoId,
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

  /// Calcula o peso unitário do elemento (1 unidade) a partir das posições,
  /// usando a massa linear das bitolas cadastradas.
  /// Replica a lógica do detalhamento/PDF para não depender do campo `peso_total` do banco.
  double calcularPesoUnitario(List<BitolaModel> bitolas) {
    double pesoUnit = 0;
    for (final pos in posicoes) {
      // Buscar massa linear da bitola
      final bitola = bitolas.where((b) => b.id == pos.bitolaId).firstOrNull;
      double massaLinear;
      if (bitola != null && bitola.massaFinal > 0) {
        massaLinear = bitola.massaFinal;
      } else {
        // Fallback: d²/162
        final str = pos.bitolaNome.split('-').first.replaceAll(RegExp(r'[^0-9.]'), '');
        final d = double.tryParse(str) ?? 0;
        massaLinear = (d * d) / 162;
      }
      if (massaLinear <= 0) continue;

      final temVar = pos.variaveisConfig.isNotEmpty &&
          pos.variaveis.values.any((v) => v);

      if (!temVar) {
        final somaCm = pos.comprimentos.values.fold<int>(0, (s, v) => s + v);
        pesoUnit += (somaCm / 100.0) * massaLinear * pos.qtde;
      } else {
        // Calcula peça a peça (cada peça pode ter comprimento diferente)
        for (int peca = 0; peca < pos.qtde; peca++) {
          int somaCm = 0;
          for (final entry in pos.comprimentos.entries) {
            final trecho = entry.key;
            final isVar = pos.variaveis[trecho] ?? false;
            if (isVar) {
              final config = pos.variaveisConfig[trecho]
                  ?? pos.variaveisConfig.values.firstOrNull;
              if (config != null && config.inicial > 0 && config.final_ > 0) {
                final expandidas = config.medidasExpandidas(pos.multiplicador);
                somaCm += peca < expandidas.length
                    ? expandidas[peca]
                    : (expandidas.isNotEmpty ? expandidas.last : 0);
              } else {
                somaCm += entry.value;
              }
            } else {
              somaCm += entry.value;
            }
          }
          pesoUnit += (somaCm / 100.0) * massaLinear;
        }
      }
    }
    return pesoUnit;
  }

  /// Peso total do elemento = peso unitário × quantidade
  double calcularPesoTotal(List<BitolaModel> bitolas) {
    return calcularPesoUnitario(bitolas) * quantidade;
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
  final Map<String, int> comprimentos;
  final Map<String, bool> variaveis;
  final Map<String, TrechoVariavelConfig> variaveisConfig;
  final int multiplicador;
  final double comprimentoDeCorte;
  final int ordem; // índice para ordenação persistida
  /// Snapshot do descontoDobra da forma no momento do salvamento.
  /// null = registro antigo (usa valor atual da forma como fallback).
  final double? descontoDobraSnapshot;
  /// Snapshot completo da forma (código, itens, rotação, ângulos) no momento do salvamento.
  /// null = registro antigo. Permite reconstituir o desenho em relatórios futuros.
  final Map<String, dynamic>? formaSnapshot;

  /// Reconstrói a FormaModel a partir do snapshot, ou null se não houver.
  FormaModel? get formaDoSnapshot => FormaModel.fromSnapshot(formaSnapshot);

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
    this.ordem = 0,
    this.descontoDobraSnapshot,
    this.formaSnapshot,
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
        descontoDobraSnapshot: null,
        formaSnapshot: null,
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
      comprimentoDeCorte: double.tryParse(map['comprimento_de_corte']?.toString() ?? '0') ?? 0.0,
      ordem: int.tryParse(map['ordem']?.toString() ?? '0') ?? 0,
      descontoDobraSnapshot: (map['desconto_dobra_snapshot'] as num?)?.toDouble(),
      formaSnapshot: map['forma_snapshot'] != null
          ? Map<String, dynamic>.from(map['forma_snapshot'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toSupabaseMap(String elementoId) {
    final map = <String, dynamic>{
      'posicao': posicao,
      'bitola_id': bitolaId.isNotEmpty ? bitolaId : null,
      'bitola_nome': bitolaNome,
      'forma_id': formaId.isNotEmpty ? formaId : null,
      'forma_codigo': formaCodigo,
      'qtde': qtde,
      'comprimentos': comprimentos,
      'variaveis': variaveis,
      'variaveis_config': variaveisConfig.map((k, v) => MapEntry(k, v.toMap())),
      'multiplicador': multiplicador,
      'elemento_id': elementoId,
      'comprimento_de_corte': double.parse(comprimentoDeCorte.toStringAsFixed(1)),
      'desconto_dobra_snapshot': descontoDobraSnapshot,
      'forma_snapshot': formaSnapshot,
    };
    if (ordem > 0) map['ordem'] = ordem;
    if (id.length == 36) {
      map['id'] = id;
    }
    return map;
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
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
      'desconto_dobra_snapshot': descontoDobraSnapshot,
      'forma_snapshot': formaSnapshot,
    };
    if (ordem > 0) map['ordem'] = ordem;
    return map;
  }

  @override
  String toString() => 'PosicaoModel(id: $id, posicao: $posicao)';
}
