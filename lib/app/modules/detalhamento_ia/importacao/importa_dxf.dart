import 'dart:convert';
import 'dart:math';
import 'package:acoplan/app/modules/detalhamento_ia/importacao/importacao_resultado.dart';

/// Entidade de texto extraída do DXF.
class _DxfTexto {
  final String tipo; // TEXT ou MTEXT
  final String layer;
  final double x;
  final double y;
  final String conteudo;

  _DxfTexto({
    required this.tipo,
    required this.layer,
    required this.x,
    required this.y,
    required this.conteudo,
  });
}

/// Posição de armadura parseada.
class _PosicaoParsed {
  final String posicao;
  final int quantidade;
  final double bitolaMm;
  final String formaCodigo;
  final int? comprimento;
  final double x;
  final double y;

  _PosicaoParsed({
    required this.posicao,
    required this.quantidade,
    required this.bitolaMm,
    required this.formaCodigo,
    this.comprimento,
    required this.x,
    required this.y,
  });
}

/// Importação de projetos via DXF (parser determinístico).
///
/// Usa algoritmo de duas passadas:
/// - Passada 1: Associa descrições próximas em X ao título ACIMA mais próximo
/// - Passada 2: Descrições distantes são vinculadas via rótulos de SEÇÃO
class ImportaDxf {
  // Regex para posição completa: "2 N35 ø12.5 C=415" ou "64 N1 ø5.0 C=111"
  static final _rePosicao = RegExp(
    r'(\d+)\s*N(\d+)\s*[øφ∅](\d+[.,]?\d*)\s*C\s*=\s*(\d+)',
  );

  // Regex para distribuição: "15 N1 c/17.5" ou "12N12c/5"
  static final _reDistribuicao = RegExp(
    r'(\d+)\s*N(\d+)\s*c\s*/\s*(\d+[.,]?\d*)',
  );

  // Regex para rótulo de elemento: "V101", "P1", "L1", etc.
  static final _reElemento = RegExp(
    r'^[VPLEBSC]\d+',
    caseSensitive: false,
  );

  // Regex para rótulo de seção: "SEÇÃO A-A", "SEÇÃO B-B"
  static final _reSecao = RegExp(
    r'SE[CÇ][AÃ]O\s+([A-Z])\s*-\s*[A-Z]',
    caseSensitive: false,
  );


  /// Processa um arquivo DXF e retorna o JSON com os elementos estruturais.
  static ImportacaoResultado processar(String conteudoDxf) {
    final textos = _extrairTextos(conteudoDxf);
    final avisos = <String>[];

    // ══════════════════════════════════════════════════════════
    // CLASSIFICAÇÃO HÍBRIDA
    //
    // Rótulos de elementos (V101, P1): extraídos de layers
    //   conhecidos (DT-Título, DT-Textos) para evitar pegar
    //   rótulos da planta baixa que não são elementos detalhados.
    //
    // Descrições de posição (2 N35 ø12.5 C=415) e SEÇÕES:
    //   classificadas pelo CONTEÚDO, independente de layer.
    //   Isso torna o parser resiliente a variações de layer.
    // ══════════════════════════════════════════════════════════

    // ── 1) Rótulos de elementos ──────────────────────────────
    // Primário: layer DT-Título (contém os títulos dos detalhamentos)
    // Complemento: layer DT-Textos, MAS só prefixos já encontrados
    //   no DT-Título (ex: se há V101, aceita V118 do DT-Textos,
    //   mas rejeita P1, E1, B1 que são da planta baixa).
    final rotulosElementos = <String, ({double x, double y})>{};
    final prefixosValidos = <String>{};

    // Passo 1: DT-Título (fonte primária)
    for (final t in textos) {
      if (t.layer != 'DT-Título') continue;
      final conteudo = t.conteudo.trim();
      final matchElem = _reElemento.firstMatch(conteudo);
      if (matchElem != null && conteudo == matchElem.group(0)) {
        final nome = matchElem.group(0)!;
        rotulosElementos[nome] = (x: t.x, y: t.y);
        // Guardar o prefixo (ex: "V" de "V101")
        prefixosValidos.add(nome[0].toUpperCase());
      }
    }

    // Passo 2: DT-Textos (complemento — só prefixos já encontrados)
    for (final t in textos) {
      if (t.layer != 'DT-Textos') continue;
      final conteudo = t.conteudo.trim();
      final matchElem = _reElemento.firstMatch(conteudo);
      if (matchElem != null && conteudo == matchElem.group(0)) {
        final nome = matchElem.group(0)!;
        final prefixo = nome[0].toUpperCase();
        // Só aceita se o prefixo já apareceu no DT-Título
        if (prefixosValidos.contains(prefixo) && !rotulosElementos.containsKey(nome)) {
          rotulosElementos[nome] = (x: t.x, y: t.y);
        }
      }
    }

    // ── 2) Descrições de posição ─────────────────────────────
    // Primário: layer 'Descrição da armadura'
    // Fallback: qualquer layer (por conteúdo), caso o layer tenha nome diferente
    var descricoes = textos
        .where((t) => t.layer == 'Descrição da armadura')
        .toList();

    // Se não encontrou no layer conhecido, fallback por conteúdo
    if (descricoes.isEmpty) {
      descricoes = textos
          .where((t) {
            final c = t.conteudo.trim();
            return _rePosicao.hasMatch(c) || _reDistribuicao.hasMatch(c);
          })
          .toList();
    }

    // ── 3) SEÇÕEs (sempre por conteúdo, qualquer layer) ─────
    final secoesTextos = <_DxfTexto>[];
    for (final t in textos) {
      if (_reSecao.hasMatch(t.conteudo.trim())) {
        secoesTextos.add(t);
      }
    }

    if (rotulosElementos.isEmpty) {
      avisos.add('Nenhum rótulo de elemento encontrado nos layers DT-Título / DT-Textos');
    }
    if (descricoes.isEmpty) {
      avisos.add('Nenhuma descrição de armadura encontrada (ex: 2 N35 ø12.5 C=415)');
    }

    // ── Extrair rótulos de SEÇÃO ──────────────────────────
    final secaoParaElemento = _mapearSecoesParaElementos(
      secoesTextos, rotulosElementos,
    );

    // ── Parsear e agrupar posições de armadura ────────────
    final posicoesPorElemento = <String, List<_PosicaoParsed>>{};

    for (final d in descricoes) {
      final texto = d.conteudo.trim();

      // Tentar match de posição completa: "2 N35 ø12.5 C=415"
      final matchPos = _rePosicao.firstMatch(texto);
      if (matchPos != null) {
        final quantidade = int.parse(matchPos.group(1)!);
        final posicao = matchPos.group(2)!;
        final bitola = double.parse(matchPos.group(3)!.replaceAll(',', '.'));
        final comprimento = int.tryParse(matchPos.group(4)!);

        // Determinar forma pelo contexto
        String forma = 'Reta';
        if (texto.toLowerCase().contains('pele')) {
          forma = 'Pele';
        }

        // ── Comparar distância ao título ACIMA vs distância à SEÇÃO ──
        // O mais perto vence. Isso evita que a SEÇÃO roube posições
        // de elementos vizinhos e vice-versa.
        final matchTitulo = _matchDiretoComDist(d.x, d.y, rotulosElementos);
        final matchSecao = _matchViaSecaoComDist(d.x, d.y, secaoParaElemento);

        String? elemento;
        if (matchTitulo != null && matchSecao != null) {
          // Ambos encontrados — o mais perto vence
          elemento = matchSecao.dist < matchTitulo.dist
              ? matchSecao.elemento
              : matchTitulo.elemento;
        } else {
          elemento = matchSecao?.elemento ?? matchTitulo?.elemento;
        }

        // ── FALLBACK: Título mais próximo acima (sem limite de X) ──
        if (elemento == null) {
          elemento = _matchFallback(d.x, d.y, rotulosElementos);
        }

        if (elemento != null) {
          posicoesPorElemento
              .putIfAbsent(elemento, () => [])
              .add(_PosicaoParsed(
                posicao: posicao,
                quantidade: quantidade,
                bitolaMm: bitola,
                formaCodigo: forma,
                comprimento: comprimento,
                x: d.x,
                y: d.y,
              ));
        } else {
          avisos.add(
            'Posição N$posicao sem elemento em (${d.x.toStringAsFixed(0)}, ${d.y.toStringAsFixed(0)})',
          );
        }
        continue;
      }

      // Distribuição: "15 N1 c/17.5" — ignorar (a seção tem o total)
      if (_reDistribuicao.hasMatch(texto)) continue;
    }

    // ── Consolidar posições (mesma posição no mesmo elemento) ──
    final elementosJson = <Map<String, dynamic>>[];

    for (final entry in posicoesPorElemento.entries) {
      final nome = entry.key;
      final posicoes = entry.value;

      final posConsolidadas = <String, _PosicaoParsed>{};
      for (final p in posicoes) {
        if (posConsolidadas.containsKey(p.posicao)) {
          final existente = posConsolidadas[p.posicao]!;
          // Mesma posição em vistas diferentes — manter a de maior quantidade
          if (p.quantidade > existente.quantidade) {
            posConsolidadas[p.posicao] = p;
          }
        } else {
          posConsolidadas[p.posicao] = p;
        }
      }

      elementosJson.add({
        'nome': nome,
        'quantidade': 1,
        'equivalentes': <String>[],
        'posicoes': posConsolidadas.values.map((p) {
          return <String, dynamic>{
            'posicao': p.posicao,
            'quantidade': p.quantidade,
            'bitola_mm': p.bitolaMm,
            'forma_codigo': p.formaCodigo,
            'comprimentos': p.comprimento != null ? {'A': p.comprimento} : null,
          };
        }).toList(),
      });
    }

    // Ordenar elementos por nome
    elementosJson.sort((a, b) => (a['nome'] as String).compareTo(b['nome'] as String));

    final json = jsonEncode({'elementos': elementosJson});

    return ImportacaoResultado(
      jsonBruto: json,
      totalElementos: elementosJson.length,
      avisos: avisos,
      tipo: TipoImportacao.dxf,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Match direto: título ACIMA mais próximo (sem limite rígido de X)
  // ═══════════════════════════════════════════════════════════

  static ({String elemento, double dist})? _matchDiretoComDist(
    double x, double y,
    Map<String, ({double x, double y})> rotulos,
  ) {
    String? melhor;
    double menorDist = double.infinity;

    for (final entry in rotulos.entries) {
      final dx = (x - entry.value.x).abs();
      final dy = entry.value.y - y; // positivo = título está acima

      // Título deve estar ACIMA (ou quase no mesmo nível)
      if (dy < -50) continue;

      final dist = sqrt(dx * dx + dy * dy);
      if (dist < menorDist) {
        menorDist = dist;
        melhor = entry.key;
      }
    }

    if (melhor == null) return null;
    return (elemento: melhor, dist: menorDist);
  }

  // ═══════════════════════════════════════════════════════════
  // Match via SEÇÃO: retorna elemento + distância à SEÇÃO
  // ═══════════════════════════════════════════════════════════

  /// Mapeia cada rótulo de SEÇÃO ao elemento dono.
  ///
  /// Lógica: A SEÇÃO é colocada à DIREITA da elevação do elemento.
  /// O título mais próximo à ESQUERDA da SEÇÃO, na mesma faixa Y, é o dono.
  static Map<({double x, double y}), String> _mapearSecoesParaElementos(
    List<_DxfTexto> dtTextos,
    Map<String, ({double x, double y})> rotulos,
  ) {
    final mapa = <({double x, double y}), String>{};

    for (final t in dtTextos) {
      final match = _reSecao.firstMatch(t.conteudo.trim());
      if (match != null) {
        String? elementoDono;
        double menorDx = double.infinity;

        for (final entry in rotulos.entries) {
          // Título deve estar à ESQUERDA da seção
          if (entry.value.x >= t.x) continue;

          // Título deve estar na mesma faixa vertical (±600)
          final dy = (entry.value.y - t.y).abs();
          if (dy > 600) continue;

          final dx = t.x - entry.value.x;
          if (dx < menorDx) {
            menorDx = dx;
            elementoDono = entry.key;
          }
        }

        if (elementoDono != null) {
          mapa[(x: t.x, y: t.y)] = elementoDono;
        }
      }
    }

    return mapa;
  }

  /// Encontra o elemento via proximidade a um rótulo de SEÇÃO.
  /// Retorna o elemento + distância, ou null se nenhuma SEÇÃO estiver perto.
  static ({String elemento, double dist})? _matchViaSecaoComDist(
    double x, double y,
    Map<({double x, double y}), String> secaoParaElemento,
  ) {
    if (secaoParaElemento.isEmpty) return null;

    String? melhor;
    double menorDist = double.infinity;

    for (final entry in secaoParaElemento.entries) {
      final dx = (x - entry.key.x).abs();
      final dy = (y - entry.key.y).abs();
      final dist = sqrt(dx * dx + dy * dy);

      if (dist < menorDist && dist < 800) {
        menorDist = dist;
        melhor = entry.value;
      }
    }

    if (melhor == null) return null;
    return (elemento: melhor, dist: menorDist);
  }

  // ═══════════════════════════════════════════════════════════
  // FALLBACK — Título mais próximo acima
  // ═══════════════════════════════════════════════════════════

  static String? _matchFallback(
    double x, double y,
    Map<String, ({double x, double y})> rotulos,
  ) {
    String? melhor;
    double menorDist = double.infinity;

    for (final entry in rotulos.entries) {
      // Só títulos ACIMA (Y maior no DXF)
      if (entry.value.y < y - 50) continue;

      final dx = (x - entry.value.x).abs();
      final dy = (entry.value.y - y).abs();
      final dist = sqrt(dx * dx + dy * dy);
      if (dist < menorDist) {
        menorDist = dist;
        melhor = entry.key;
      }
    }

    return melhor;
  }

  // ═══════════════════════════════════════════════════════════
  // EXTRAÇÃO DE ENTIDADES DXF
  // ═══════════════════════════════════════════════════════════

  /// Extrai todas as entidades TEXT e MTEXT do conteúdo DXF.
  static List<_DxfTexto> _extrairTextos(String conteudo) {
    final linhas = conteudo.split('\n');
    final textos = <_DxfTexto>[];

    int i = 0;
    while (i < linhas.length - 1) {
      final code = linhas[i].trim();
      final val = linhas[i + 1].trim();

      if (code == '0' && (val == 'TEXT' || val == 'MTEXT')) {
        final tipo = val;
        String layer = '';
        String x = '0';
        String y = '0';
        String txt = '';

        int j = i + 2;
        while (j < linhas.length - 1) {
          final c = linhas[j].trim();
          final v = linhas[j + 1].trim();
          if (c == '0') break;
          if (c == '8') layer = v;
          if (c == '10') x = v;
          if (c == '20') y = v;
          if (c == '1') txt = v;
          j += 2;
        }

        if (txt.isNotEmpty) {
          textos.add(_DxfTexto(
            tipo: tipo,
            layer: layer,
            x: double.tryParse(x) ?? 0,
            y: double.tryParse(y) ?? 0,
            conteudo: txt,
          ));
        }

        i = j;
      } else {
        i += 2;
      }
    }

    return textos;
  }
}
