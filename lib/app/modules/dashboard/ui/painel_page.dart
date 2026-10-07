import 'package:acoplan/app/app_controller.dart';
import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/detalhamento_model.dart';
import 'package:acoplan/app/core/client/models/pedido_tecnico_model.dart';
import 'package:acoplan/app/core/enums/app_module.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/base/base_controller.dart';
import 'package:acoplan/app/modules/dashboard/demanda_controller.dart';
import 'package:acoplan/app/modules/dashboard/models/demanda_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Tela inicial: resumo do fluxo (Demandas → Detalhamentos → Pedidos técnicos).
class PainelPage extends StatefulWidget {
  const PainelPage({super.key});

  @override
  State<PainelPage> createState() => _PainelPageState();
}

class _PainelPageState extends State<PainelPage> {
  @override
  void initState() {
    setWebTitle('Painel');
    super.initState();
  }

  void _ir(AppModule m) {
    final u = appCtrl.usuario;
    if (u != null && !u.podeVer(m.area)) return;
    baseCtrl.setModule(m);
  }

  String _peso(double kg) => kg >= 1000
      ? '${NumberFormat('#,##0.0', 'pt_BR').format(kg / 1000)} t'
      : '${NumberFormat('#,##0', 'pt_BR').format(kg)} kg';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DemandaModel>>(
      stream: demandaCtrl.demandasStream.listen,
      builder: (context, _) => StreamBuilder<List<DetalhamentoModel>>(
        stream: BackendClient.detalhamentos.dataStream.listen,
        builder: (context, _) => StreamBuilder<List<PedidoTecnicoModel>>(
          stream: BackendClient.pedidosTecnicos.dataStream.listen,
          builder: (context, _) => _conteudo(context),
        ),
      ),
    );
  }

  Widget _conteudo(BuildContext context) {
    final usuario = appCtrl.usuario;
    final demandas = demandaCtrl.demandas.where((d) => !d.isArquivado).toList();
    final dets = BackendClient.detalhamentos.data
        .where((d) => !d.isArquivado)
        .toList();
    final pedidos = BackendClient.pedidosTecnicos.data;
    final abertos = pedidos.where((p) => p.isAberto).toList();

    int qtd(DemandaEtapa e) => demandas.where((d) => d.etapa == e).length;
    // Finalizadas com detalhamento ainda sem pedido técnico
    final idsComPedido = pedidos
        .where((p) => p.isAberto)
        .map((p) => p.detalhamentoId)
        .toSet();
    final aguardandoPedido = demandas
        .where((d) => d.liberadaParaPedido)
        .where(
          (d) => demandaCtrl
              .obterDetalhamentosDaDemanda(d)
              .any((det) => !idsComPedido.contains(det.id)),
        )
        .length;

    final urgentes =
        demandas
            .where((d) => d.prioridade == 'urgente' || d.prioridade == 'alta')
            .toList()
          ..sort(
            (a, b) => (a.prioridade == 'urgente' ? 0 : 1).compareTo(
              b.prioridade == 'urgente' ? 0 : 1,
            ),
          );
    final meus =
        dets
            .where((d) => usuario != null && d.funcionarioId == usuario.id)
            .toList()
          ..sort((a, b) => b.codigo.compareTo(a.codigo));
    final ultimosPedidos = [...pedidos]
      ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));

    final hora = DateTime.now().hour;
    final saudacao = hora < 12
        ? 'Bom dia'
        : (hora < 18 ? 'Boa tarde' : 'Boa noite');

    return Container(
      color: AppColors.neutralLightest,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '$saudacao, ${usuario?.nome.split(' ').first ?? ''}',
                    style: AppCss.largeBold.setSize(20),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat(
                      "EEEE, d 'de' MMMM",
                      'pt_BR',
                    ).format(DateTime.now()),
                    style: AppCss.minimumRegular
                        .setSize(13)
                        .setColor(AppColors.neutralMedium),
                  ),
                  const SizedBox(height: 16),
                  // ── Indicadores do fluxo (2 por linha no celular) ──
                  LayoutBuilder(
                    builder: (context, cons) {
                      _larguraIndicador = cons.maxWidth < 520
                          ? (cons.maxWidth - 12) / 2
                          : 220;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _indicador(
                            Symbols.inbox,
                            'Na fila',
                            '${qtd(DemandaEtapa.aguardandoFila)}',
                            'demandas aguardando',
                            AppColors.statusAguardando,
                            () => _ir(AppModule.demandas),
                          ),
                          _indicador(
                            Symbols.edit_note,
                            'Em detalhamento',
                            '${qtd(DemandaEtapa.emProducao) + qtd(DemandaEtapa.corrigindo)}',
                            'demandas em trabalho',
                            AppColors.statusProduzindo,
                            () => _ir(AppModule.demandas),
                          ),
                          _indicador(
                            Symbols.rule,
                            'Aguardando correção',
                            '${qtd(DemandaEtapa.aguardandoCorrecao)}',
                            'para revisar',
                            AppColors.statusAtencao,
                            () => _ir(AppModule.demandas),
                          ),
                          _indicador(
                            Symbols.task_alt,
                            'Liberadas',
                            '$aguardandoPedido',
                            'com detalhamento sem pedido',
                            AppColors.statusPronto,
                            () => _ir(AppModule.projetos),
                          ),
                          _indicador(
                            Symbols.receipt_long,
                            'Pedidos abertos',
                            '${abertos.length}',
                            _peso(
                              abertos.fold<double>(
                                0,
                                (s, p) => s + p.pesoTotal,
                              ),
                            ),
                            AppColors.primaryMain,
                            () => _ir(AppModule.pedidosTecnicos),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // ── Listas ──
                  LayoutBuilder(
                    builder: (context, cons) {
                      final secoes = [
                        _secao(
                          Symbols.priority_high,
                          'Urgentes e prioridade alta',
                          urgentes.isEmpty ? 'Nenhuma demanda urgente.' : null,
                          [
                            for (final d in urgentes.take(6))
                              _linha(
                                titulo: '${d.obraNome} • ${d.etapaProjeto}',
                                sub: '${d.clienteNome} • ${d.etapa.label}',
                                selo: d.prioridade.toUpperCase(),
                                corSelo: d.prioridade == 'urgente'
                                    ? AppColors.statusCritico
                                    : AppColors.statusAtencao,
                                onTap: () => _ir(AppModule.demandas),
                              ),
                          ],
                        ),
                        _secao(
                          Symbols.architecture,
                          'Meus detalhamentos',
                          meus.isEmpty
                              ? 'Nenhum detalhamento sob sua responsabilidade.'
                              : null,
                          [
                            for (final d in meus.take(6))
                              _linha(
                                titulo:
                                    '${d.codigo} • ${d.descricao.isNotEmpty ? d.descricao : d.obraNome}',
                                sub: '${d.clienteNome} • ${d.obraNome}',
                                selo: demandaCtrl
                                    .demandaDoDetalhamento(d)
                                    ?.etapa
                                    .label,
                                corSelo: AppColors.statusProduzindo,
                                onTap: () => _ir(AppModule.projetos),
                              ),
                          ],
                        ),
                        _secao(
                          Symbols.receipt_long,
                          'Últimos pedidos técnicos',
                          ultimosPedidos.isEmpty
                              ? 'Nenhum pedido emitido ainda.'
                              : null,
                          [
                            for (final p in ultimosPedidos.take(6))
                              _linha(
                                titulo: p.identificador.isNotEmpty
                                    ? p.identificador
                                    : 'PT ${p.codigo}',
                                sub:
                                    '${p.clienteNome} • ${DateFormat('dd/MM/yyyy').format(p.criadoEm.toLocal())} • ${_peso(p.pesoTotal)}',
                                selo: p.isAberto ? 'ABERTO' : 'CANCELADO',
                                corSelo: p.isAberto
                                    ? AppColors.statusPronto
                                    : AppColors.statusAguardando,
                                onTap: () => _ir(AppModule.pedidosTecnicos),
                              ),
                          ],
                        ),
                      ];
                      if (cons.maxWidth < 900) {
                        return Column(
                          children: [
                            for (final s in secoes)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: s,
                              ),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int i = 0; i < secoes.length; i++) ...[
                            if (i > 0) const SizedBox(width: 12),
                            Expanded(child: secoes[i]),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _larguraIndicador = 220;

  Widget _indicador(
    IconData icon,
    String titulo,
    String valor,
    String sub,
    Color cor,
    VoidCallback onTap,
  ) {
    final compacto = _larguraIndicador < 200;
    return SizedBox(
      width: _larguraIndicador,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: EdgeInsets.all(compacto ? 10 : 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.neutralLight),
            ),
            child: Row(
              children: [
                if (!compacto) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: cor, size: 22),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: AppCss.minimumBold
                            .setSize(12)
                            .setColor(AppColors.neutralMedium),
                      ),
                      Text(valor, style: AppCss.largeBold.setSize(22)),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppCss.minimumRegular
                            .setSize(11.5)
                            .setColor(AppColors.neutralMedium),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _secao(
    IconData icon,
    String titulo,
    String? vazio,
    List<Widget> linhas,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutralLight),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.neutralLightest),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.neutralMedium),
                const SizedBox(width: 8),
                Text(titulo, style: AppCss.minimumBold.setSize(14)),
              ],
            ),
          ),
          if (vazio != null)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                vazio,
                style: AppCss.minimumRegular
                    .setSize(12.5)
                    .setColor(AppColors.neutralMedium),
              ),
            )
          else
            ...linhas,
        ],
      ),
    );
  }

  Widget _linha({
    required String titulo,
    required String sub,
    String? selo,
    Color? corSelo,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.neutralLightest)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppCss.minimumBold.setSize(13),
                  ),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppCss.minimumRegular
                        .setSize(11.5)
                        .setColor(AppColors.neutralMedium),
                  ),
                ],
              ),
            ),
            if (selo != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (corSelo ?? AppColors.neutralMedium).withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  selo.toUpperCase(),
                  style: AppCss.minimumBold
                      .setSize(9)
                      .setColor(corSelo ?? AppColors.neutralMedium),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
