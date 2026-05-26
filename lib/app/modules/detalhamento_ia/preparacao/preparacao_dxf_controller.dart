import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;
import 'package:flutter/foundation.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/modules/detalhamento_ia/preparacao/dxf_geometria.dart';
import 'package:acoplan/app/modules/detalhamento_ia/preparacao/models/elemento_preparado.dart';
import 'package:acoplan/app/modules/detalhamento_ia/importacao/importacao_resultado.dart';

/// Estado da preparação.
class PreparacaoState {
  DxfGeometria? geometria;
  Uint8List? pdfBytes;
  List<ElementoPreparado> elementos = [];
  String? elementoSelecionado;
  String? nomeArquivo;
  bool carregando = false;
  String? erro;
  bool get isPdf => pdfBytes != null;
}

/// Controller do módulo de preparação visual de DXF.
class PreparacaoDxfController {
  final state = PreparacaoState();
  final stateStream = AppStream<PreparacaoState>();

  // Regex do parser (mesmos do importa_dxf)
  static final _rePosicao = RegExp(
    r'(\d+)\s*N(\d+)\s*[øφ∅](\d+[.,]?\d*)\s*C\s*=\s*(\d+)',
  );
  static final _reElemento = RegExp(r'^[VPLEBSC]\d+$', caseSensitive: false);

  /// Carrega e parseia um arquivo DXF.
  Future<void> carregarDxf(String conteudo, String nomeArquivo) async {
    state.carregando = true;
    state.nomeArquivo = nomeArquivo;
    state.erro = null;
    stateStream.add(state);

    // Aguarda a UI renderizar o spinner
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      // Parseia geometria completa para renderizar o projeto
      state.geometria = DxfGeometria.extrair(conteudo, apenasTextos: false);
      state.elementos = [];
      state.elementoSelecionado = null;
      state.carregando = false;
      stateStream.add(state);
    } catch (e) {
      state.erro = 'Erro ao parsear DXF: $e';
      state.carregando = false;
      stateStream.add(state);
    }
  }

  /// Carrega um PDF para visualização.
  void carregarPdf(Uint8List bytes, String nomeArquivo) {
    debugPrint('=== carregarPdf: recebeu ${bytes.length} bytes, arquivo: $nomeArquivo ===');
    state.carregando = false;
    state.nomeArquivo = nomeArquivo;
    state.pdfBytes = bytes;
    state.geometria = null; // limpa DXF se tinha
    state.elementos = [];
    state.elementoSelecionado = null;
    state.erro = null;
    debugPrint('=== carregarPdf: state.pdfBytes agora tem ${state.pdfBytes?.length ?? 0} bytes ===');
    stateStream.add(state);
  }

  /// Adiciona um elemento a partir de seleção no PDF.
  void adicionarElementoPdf(String nome, Rect regiao, int pagina) {
    // Verificar se já existe
    final existente = state.elementos.indexWhere((e) => e.nome == nome);
    if (existente >= 0) {
      state.elementos[existente].boundingBox = regiao;
      state.elementos[existente].processandoIa = true;
    } else {
      state.elementos.add(ElementoPreparado(
        nome: nome,
        boundingBox: regiao,
        cor: CoresElemento.obterCor(state.elementos.length),
        posicoes: [],
        processandoIa: true,
      ));
    }
    stateStream.add(state);
  }

  /// Atualiza as posições de um elemento PDF com dados extraídos pela IA.
  void atualizarPosicoesPdf(String nome, List<ElementoPreparado> posicoes) {
    final idx = state.elementos.indexWhere((e) => e.nome == nome);
    if (idx >= 0) {
      state.elementos[idx].posicoes = posicoes.isEmpty
          ? []
          : posicoes.first.posicoes; // Fallback
    }
    stateStream.add(state);
  }

  /// Atualiza as posições de um elemento PDF (recebe lista de PosicaoPreparada).
  void atualizarPosicoesPdfList(String nome, List<PosicaoPreparada> posicoes) {
    final idx = state.elementos.indexWhere((e) => e.nome == nome);
    if (idx >= 0) {
      state.elementos[idx].posicoes = posicoes;
      state.elementos[idx].confirmado = true;
      state.elementos[idx].processandoIa = false;
    }
    stateStream.add(state);
  }

  /// Executa auto-detecção de elementos usando heurísticas.
  void autoDetectar() {
    final geo = state.geometria;
    if (geo == null) return;

    state.elementos.clear();
    
    // Encontrar rótulos de elementos
    final rotulos = <String, ({double x, double y})>{};
    for (final t in geo.textos) {
      final conteudo = t.conteudo.trim();
      if (_reElemento.hasMatch(conteudo)) {
        final nome = conteudo;
        if (!rotulos.containsKey(nome)) {
          rotulos[nome] = (x: t.x, y: t.y);
        }
      }
    }

    if (rotulos.isEmpty) return;

    // Calcular distância máxima adaptativa:
    // Usa metade da menor distância entre rótulos vizinhos
    double distMaxima = 2000; // fallback
    if (rotulos.length >= 2) {
      final posicoes = rotulos.values.toList();
      double menorDistEntreRotulos = double.infinity;
      for (int i = 0; i < posicoes.length; i++) {
        for (int j = i + 1; j < posicoes.length; j++) {
          final dx = posicoes[i].x - posicoes[j].x;
          final dy = posicoes[i].y - posicoes[j].y;
          final dist = (dx * dx + dy * dy);
          if (dist < menorDistEntreRotulos && dist > 0) {
            menorDistEntreRotulos = dist;
          }
        }
      }
      if (menorDistEntreRotulos < double.infinity) {
        // Metade da menor distância entre rótulos (quadrática)
        distMaxima = menorDistEntreRotulos * 0.6;
      }
    }

    // Encontrar descrições de posição
    final descricoes = <({int indice, String posicao, int quantidade, double bitola, int comprimento, double x, double y})>[];
    for (int i = 0; i < geo.textos.length; i++) {
      final t = geo.textos[i];
      final match = _rePosicao.firstMatch(t.conteudo.trim());
      if (match != null) {
        descricoes.add((
          indice: i,
          posicao: match.group(2)!,
          quantidade: int.parse(match.group(1)!),
          bitola: double.parse(match.group(3)!.replaceAll(',', '.')),
          comprimento: int.tryParse(match.group(4) ?? '') ?? 0,
          x: t.x,
          y: t.y,
        ));
      }
    }

    // Associar cada descrição ao rótulo mais próximo (com limite de distância)
    final posicoesPorElemento = <String, List<PosicaoPreparada>>{};
    final pontosPorElemento = <String, List<Offset>>{};

    for (final d in descricoes) {
      String? maisProximo;
      double menorDist = double.infinity;

      for (final entry in rotulos.entries) {
        final dx = d.x - entry.value.x;
        final dy = d.y - entry.value.y;
        final dist = dx * dx + dy * dy;
        if (dist < menorDist) {
          menorDist = dist;
          maisProximo = entry.key;
        }
      }

      // Só associar se dentro da distância máxima
      if (maisProximo != null && menorDist <= distMaxima) {
        posicoesPorElemento.putIfAbsent(maisProximo, () => []).add(
          PosicaoPreparada(
            posicao: d.posicao,
            quantidade: d.quantidade,
            bitolaMm: d.bitola,
            formaCodigo: 'Reta',
            comprimentos: d.comprimento > 0 ? {'A': d.comprimento} : {},
            x: d.x,
            y: d.y,
          ),
        );

        // Guardar pontos para calcular bbox
        pontosPorElemento.putIfAbsent(maisProximo, () => []).add(Offset(d.x, d.y));
      }
    }

    // Criar elementos preparados com bbox preciso
    int indice = 0;
    for (final entry in posicoesPorElemento.entries) {
      final nome = entry.key;
      final rotuloPos = rotulos[nome]!;
      
      // Consolidar posições duplicadas
      final posConsolidadas = <String, PosicaoPreparada>{};
      for (final p in entry.value) {
        if (!posConsolidadas.containsKey(p.posicao)) {
          posConsolidadas[p.posicao] = p;
        }
      }

      // Calcular bbox a partir de todos os pontos (rótulo + posições)
      final pontos = [Offset(rotuloPos.x, rotuloPos.y), ...pontosPorElemento[nome]!];
      double xMin = double.infinity, yMin = double.infinity;
      double xMax = double.negativeInfinity, yMax = double.negativeInfinity;
      for (final p in pontos) {
        if (p.dx < xMin) xMin = p.dx;
        if (p.dx > xMax) xMax = p.dx;
        if (p.dy < yMin) yMin = p.dy;
        if (p.dy > yMax) yMax = p.dy;
      }
      // Margem proporcional ao tamanho
      final margem = ((xMax - xMin) * 0.1).clamp(20, 200);
      final bbox = Rect.fromLTRB(xMin - margem, yMin - margem, xMax + margem, yMax + margem);

      state.elementos.add(ElementoPreparado(
        nome: nome,
        boundingBox: bbox,
        cor: CoresElemento.obterCor(indice),
        posicoes: posConsolidadas.values.toList(),
        confirmado: false,
      ));
      indice++;
    }

    // Ordenar por nome
    state.elementos.sort((a, b) => a.nome.compareTo(b.nome));

    stateStream.add(state);
  }

  /// Processa uma seleção retangular do canvas.
  /// Retorna o nome sugerido e as posições encontradas.
  ({String? nomeSugerido, List<PosicaoPreparada> posicoes}) processarSelecao(
    Rect regiao,
    List<int> textosIndices,
  ) {
    final geo = state.geometria;
    if (geo == null) return (nomeSugerido: null, posicoes: []);

    String? nomeSugerido;
    final posicoes = <PosicaoPreparada>[];

    for (final idx in textosIndices) {
      if (idx >= geo.textos.length) continue;
      final t = geo.textos[idx];
      final conteudo = t.conteudo.trim();

      // Verificar se é rótulo de elemento
      if (_reElemento.hasMatch(conteudo)) {
        nomeSugerido ??= conteudo;
        continue;
      }

      // Verificar se é descrição de posição
      final match = _rePosicao.firstMatch(conteudo);
      if (match != null) {
        posicoes.add(PosicaoPreparada(
          posicao: match.group(2)!,
          quantidade: int.parse(match.group(1)!),
          bitolaMm: double.parse(match.group(3)!.replaceAll(',', '.')),
          formaCodigo: 'Reta',
          comprimentos: int.tryParse(match.group(4) ?? '') != null
              ? {'A': int.parse(match.group(4)!)}
              : {},
          x: t.x,
          y: t.y,
        ));
      }
    }

    return (nomeSugerido: nomeSugerido, posicoes: posicoes);
  }

  /// Confirma um elemento com nome e bounding box.
  void confirmarElemento(String nome, Rect boundingBox, List<PosicaoPreparada> posicoes) {
    // Remover existente com mesmo nome
    state.elementos.removeWhere((e) => e.nome == nome);

    state.elementos.add(ElementoPreparado(
      nome: nome,
      boundingBox: boundingBox,
      cor: CoresElemento.obterCor(state.elementos.length),
      posicoes: posicoes,
      confirmado: true,
    ));

    // Reordenar
    state.elementos.sort((a, b) => a.nome.compareTo(b.nome));
    stateStream.add(state);
  }

  /// Remove um elemento.
  void removerElemento(String nome) {
    state.elementos.removeWhere((e) => e.nome == nome);
    if (state.elementoSelecionado == nome) {
      state.elementoSelecionado = null;
    }
    stateStream.add(state);
  }

  /// Seleciona/deseleciona um elemento no painel.
  void selecionarElemento(String? nome) {
    state.elementoSelecionado = nome;
    stateStream.add(state);
  }

  /// Gera o JSON de mapeamento (.spe.json).
  String gerarMapeamento() {
    final mapeamento = MapeamentoDxf(
      arquivoOrigem: state.nomeArquivo ?? 'desconhecido.dxf',
      elementos: state.elementos,
    );
    return mapeamento.toJsonString();
  }

  /// Carrega um mapeamento existente (.spe.json).
  void carregarMapeamento(String jsonStr) {
    try {
      final mapeamento = MapeamentoDxf.fromJsonString(jsonStr);
      state.elementos = mapeamento.elementos;
      stateStream.add(state);
    } catch (e) {
      state.erro = 'Erro ao carregar mapeamento: $e';
      stateStream.add(state);
    }
  }

  /// Exporta para o formato ImportacaoResultado (para integrar com o fluxo existente).
  ImportacaoResultado exportarParaImportacao() {
    final elementosJson = <Map<String, dynamic>>[];

    for (final elem in state.elementos) {
      if (elem.posicoes.isEmpty) continue;

      elementosJson.add({
        'nome': elem.nome,
        'quantidade': 1,
        'equivalentes': <String>[],
        'posicoes': elem.posicoes.map((p) => {
          'posicao': p.posicao,
          'quantidade': p.quantidade,
          'bitola_mm': p.bitolaMm,
          'forma_codigo': p.formaCodigo,
          'comprimentos': p.comprimentos,
        }).toList(),
      });
    }

    final jsonStr = jsonEncode({'elementos': elementosJson});

    return ImportacaoResultado(
      jsonBruto: jsonStr,
      totalElementos: elementosJson.length,
      avisos: [],
      tipo: TipoImportacao.dxf,
    );
  }

  /// Total de posições em todos os elementos.
  int get totalPosicoes => state.elementos.fold(0, (sum, e) => sum + e.posicoes.length);

  void dispose() {
    // AppStream não tem close, não precisa dispor
  }
}

/// Instância global do controller de preparação.
final preparacaoDxfCtrl = PreparacaoDxfController();
