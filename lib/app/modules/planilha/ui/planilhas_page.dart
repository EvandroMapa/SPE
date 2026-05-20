import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/components/app_scaffold.dart';
import 'package:acoplan/app/core/components/empty_data.dart';
import 'package:acoplan/app/core/components/stream_out.dart';
import 'package:acoplan/app/core/client/models/planilha_model.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/planilha/planilha_controller.dart';
import 'package:acoplan/app/modules/planilha/ui/planilha_create_page.dart';
import 'package:acoplan/app/modules/planilha/pdf_planilha.dart';
import 'package:acoplan/app/modules/forma/forma_controller.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class PlanilhasPage extends StatefulWidget {
  const PlanilhasPage({super.key});

  @override
  State<PlanilhasPage> createState() => _PlanilhasPageState();
}

class _PlanilhasPageState extends State<PlanilhasPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white, size: 20),
        backgroundColor: AppColors.primaryMain,
        title: Text('Planilhamento',
            style: AppCss.mediumBold.setColor(Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _openForm(null),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _filter = val),
              decoration: const InputDecoration(
                hintText: 'Buscar planilha...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: StreamOut<List<PlanilhaModel>>(
              stream: planilhaCtrl.planilhasStream.listen,
              builder: (context, planilhas) {
                final filtered = planilhas.where((p) {
                  final query = _filter.toLowerCase();
                  return p.clienteNome.toLowerCase().contains(query) ||
                      p.obraNome.toLowerCase().contains(query) ||
                      p.codigo.toString().contains(query);
                }).toList();

                if (filtered.isEmpty) {
                  return const EmptyData(
                      message: 'Nenhuma planilha encontrada');
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final planilha = filtered[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[200]!),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primaryMain.withValues(alpha: 0.15), AppColors.primaryMain.withValues(alpha: 0.05)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              planilha.codigo.toString(),
                              style: AppCss.smallBold.setColor(AppColors.primaryMain).setSize(15),
                            ),
                          ),
                        ),
                        title: Text('Planilha ${planilha.codigo}', style: AppCss.smallBold.setSize(14)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              '${planilha.clienteNome} • ${planilha.obraNome} • ${planilha.elementos.length} elemento(s)',
                              style: AppCss.minimumRegular.setSize(11),
                            ),
                            const SizedBox(height: 3),
                            Row(children: [
                              Icon(Icons.scale_outlined, size: 12,
                                  color: planilha.pesoTotal > 0 ? const Color(0xFF10B981) : Colors.grey[400]),
                              const SizedBox(width: 4),
                              Text(
                                planilha.pesoTotal > 0 ? '${planilha.pesoTotal.toStringAsFixed(2)} kg' : 'Sem peso calculado',
                                style: AppCss.minimumBold
                                    .setColor(planilha.pesoTotal > 0 ? const Color(0xFF10B981) : Colors.grey[400]!)
                                    .setSize(11),
                              ),
                            ]),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tooltip(
                              message: 'Gerar PDF',
                              child: InkWell(
                                onTap: () => _gerarPDF(planilha),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Colors.orange),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: 'Editar',
                              child: InkWell(
                                onTap: () => _openForm(planilha),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(color: AppColors.primaryMain.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
                                  child: Icon(Icons.edit_outlined, size: 18, color: AppColors.primaryMain),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: 'Excluir',
                              child: InkWell(
                                onTap: () => _confirmDelete(planilha),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
                                  child: Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openForm(PlanilhaModel? planilha) async {
    if (planilha != null) {
      final estaVinculada = await BackendClient.planilhas.estaVinculadaAPedido(planilha.id);
      if (estaVinculada) {
        if (!mounted) return;
        NotificationService.showNeutral('Modo de Visualização', 'Esta planilha está em um Pedido Técnico e não pode ser alterada.', position: NotificationPosition.bottom);
        await push(context, PlanilhaCreatePage(planilha: planilha, isReadOnly: true));
        return;
      }
    }
    if (!mounted) return;
    await push(context, PlanilhaCreatePage(planilha: planilha));
  }

  void _gerarPDF(PlanilhaModel planilha) async {
    final pdfBytes = await PdfPlanilha.gerarRelatorio(planilha, formaCtrl.formas, BackendClient.produtos.data);
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'Planilha ${planilha.codigo} - ${planilha.clienteNome}',
    );
  }

  void _confirmDelete(PlanilhaModel planilha) async {
    final estaVinculada = await BackendClient.planilhas.estaVinculadaAPedido(planilha.id);
    if (estaVinculada) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(Icons.info_outline, size: 40, color: Colors.orange[700]),
          title: Text('Exclusão Bloqueada', textAlign: TextAlign.center, style: AppCss.mediumBold),
          content: Text(
            'Esta planilha não pode ser excluída pois possui elementos vinculados a um Pedido Técnico.\n\nRemova os elementos do pedido antes de excluir.',
            style: AppCss.smallRegular,
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryMain),
              onPressed: () => pop(context),
              child: Text('Entendi', style: AppCss.smallBold.setColor(Colors.white)),
            ),
          ],
        ),
      );
      return;
    }
    
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Planilha'),
        content: Text('Deseja realmente excluir a planilha ${planilha.codigo}?'),
        actions: [
          TextButton(onPressed: () => pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              pop(context);
              planilhaCtrl.onDelete(context, planilha);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
