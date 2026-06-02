import 'package:acoplan/app/core/client/models/detalhamento_model.dart';
import 'package:acoplan/app/core/client/models/pedido_tecnico_model.dart';

/// ViewModel de criação/edição de pedido técnico
class PedidoTecnicoCreateModel {
  String? id; // null = novo
  int codigo = 0;
  String? identificador; // null = gerar na criação

  // Seleções de contexto
  String clienteId = '';
  String clienteNome = '';
  String obraId = '';
  String obraNome = '';
  String obraPrefixo = ''; // prefixo da obra — usado no identificador do PT
  String detalhamentoId = '';
  int detalhamentoCodigo = 0;

  String observacao = '';

  /// Elementos selecionados para este pedido
  List<ElementoSelecionadoModel> elementosSelecionados = [];

  PedidoTecnicoCreateModel();

  bool get isEdit => id != null;

  bool get podeGerar => elementosSelecionados.isNotEmpty;

  /// Gera o identificador: prefixo.001
  String _gerarIdentificador(int codigo) {
    final prefixo = obraPrefixo.isNotEmpty ? obraPrefixo : obraNome;
    final seq = (codigo > 0 ? codigo : 1).toString().padLeft(3, '0');
    return '$prefixo.$seq';
  }

  /// Converte para PedidoTecnicoModel
  PedidoTecnicoModel toPedidoTecnicoModel() => PedidoTecnicoModel(
        id: id ?? '',
        codigo: codigo,
        identificador: identificador?.isNotEmpty == true
            ? identificador!
            : _gerarIdentificador(codigo),
        detalhamentoId: detalhamentoId,
        detalhamentoCodigo: detalhamentoCodigo,
        clienteId: clienteId,
        clienteNome: clienteNome,
        obraId: obraId,
        obraNome: obraNome,
        status: 'aberto',
        observacao: observacao,
        criadoEm: DateTime.now(),
        elementos: elementosSelecionados
            .map((e) => PedidoTecnicoElementoModel(
                  id: '',
                  pedidoId: id ?? '',
                  elementoId: e.elementoId,
                  elementoNome: e.nome,
                  elementoQuantidade: e.quantidade,
                  quantidadeSolicitada: e.quantidadeSolicitada,
                  pesoTotal: e.pesoSolicitado,
                ))
            .toList(),
      );

  /// Inicializa a partir de um pedido existente para edição
  factory PedidoTecnicoCreateModel.fromPedido(PedidoTecnicoModel pedido) {
    final m = PedidoTecnicoCreateModel();
    m.id = pedido.id;
    m.codigo = pedido.codigo;
    m.identificador = pedido.identificador;
    m.clienteId = pedido.clienteId;
    m.clienteNome = pedido.clienteNome;
    m.obraId = pedido.obraId;
    m.obraNome = pedido.obraNome;
    m.detalhamentoId = pedido.detalhamentoId;
    m.detalhamentoCodigo = pedido.detalhamentoCodigo;
    m.observacao = pedido.observacao;
    m.elementosSelecionados = pedido.elementos
        .map((e) => ElementoSelecionadoModel(
              elementoId: e.elementoId,
              nome: e.elementoNome,
              quantidade: e.elementoQuantidade,
              quantidadeSolicitada: e.quantidadeSolicitada,
              pesoTotal: e.pesoTotal,
            ))
        .toList();
    return m;
  }
}

/// Representa um elemento do detalhamento na tela de criação de pedido
class ElementoSelecionadoModel {
  final String elementoId;
  final String nome;
  final int quantidade;
  int quantidadeSolicitada;
  final double pesoTotal;

  ElementoSelecionadoModel({
    required this.elementoId,
    required this.nome,
    required this.quantidade,
    int? quantidadeSolicitada,
    required this.pesoTotal,
  }) : quantidadeSolicitada = quantidadeSolicitada ?? quantidade;

  /// Peso proporcional à quantidade solicitada
  double get pesoSolicitado =>
      quantidade > 0 ? (pesoTotal / quantidade) * quantidadeSolicitada : 0;

  factory ElementoSelecionadoModel.fromElementoModel(
    ElementoModel e, {
    int? quantidadeSolicitada,
  }) =>
      ElementoSelecionadoModel(
        elementoId: e.id,
        nome: e.nome,
        quantidade: e.quantidade,
        quantidadeSolicitada: quantidadeSolicitada,
        pesoTotal: e.pesoTotal,
      );
}

/// Estado de disponibilidade de um elemento do detalhamento
enum DisponibilidadeElemento {
  disponivel,
  emPedido,
}

/// Representa um elemento do detalhamento com metadados de disponibilidade
class ElementoDetalhamentoViewModel {
  final ElementoModel elemento;
  final DisponibilidadeElemento disponibilidade;

  /// Identificador do pedido que ocupa este elemento (se em pedido)
  final String? identificadorPedidoOcupante;

  bool get estaDisponivel =>
      disponibilidade == DisponibilidadeElemento.disponivel;

  ElementoDetalhamentoViewModel({
    required this.elemento,
    required this.disponibilidade,
    this.identificadorPedidoOcupante,
  });
}
