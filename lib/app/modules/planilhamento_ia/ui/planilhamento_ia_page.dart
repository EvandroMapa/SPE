import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/cliente_model.dart';
import 'package:acoplan/app/core/components/app_drop_down.dart';
import 'package:acoplan/app/core/components/app_scaffold.dart';
import 'package:acoplan/app/core/components/stream_out.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/modules/planilhamento_ia/planilhamento_ia_controller.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

class PlanilhamentoIaPage extends StatefulWidget {
  const PlanilhamentoIaPage({super.key});

  @override
  State<PlanilhamentoIaPage> createState() => _PlanilhamentoIaPageState();
}

class _PlanilhamentoIaPageState extends State<PlanilhamentoIaPage> {
  bool _isDragging = false;

  @override
  void initState() {
    planilhamentoIaCtrl.init();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamOut(
        stream: planilhamentoIaCtrl.stateStream.listen,
        builder: (_, state) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // -- Header --
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryMain.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.auto_awesome, color: AppColors.primaryMain, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Planilhamento IA', style: AppCss.largeBold.setColor(AppColors.primaryMain)),
                            Text('Faça upload do seu projeto em PDF e deixe a IA extrair os elementos estruturais.', style: AppCss.minimumRegular.setColor(Colors.grey[600]!).setSize(14)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // -- Seleção de Cliente e Obra --
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('1. Vínculo do Projeto', style: AppCss.mediumBold.setColor(const Color(0xFF1E293B))),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: AppDropDown<ClienteModel?>(
                                  label: 'Cliente',
                                  item: state.clienteSelecionado,
                                  itens: BackendClient.clientes.data,
                                  itemLabel: (e) => e?.nome ?? 'Selecione um cliente',
                                  onSelect: planilhamentoIaCtrl.setCliente,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: AppDropDown<ObraModel?>(
                                  label: 'Obra',
                                  item: state.obraSelecionada,
                                  itens: state.clienteSelecionado?.obras ?? [],
                                  itemLabel: (e) => e?.descricao ?? 'Selecione uma obra',
                                  onSelect: planilhamentoIaCtrl.setObra,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // -- Upload Area --
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('2. Arquivo do Projeto', style: AppCss.mediumBold.setColor(const Color(0xFF1E293B))),
                            const SizedBox(height: 16),
                            Expanded(
                              child: _buildUploadArea(state),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUploadArea(PlanilhamentoIaState state) {
    if (state.status == IaStatus.analyzing) {
      return _buildProcessingState(state);
    }
    if (state.status == IaStatus.success) {
      return _buildSuccessState(state);
    }

    final bool isReadyForUpload = state.clienteSelecionado != null && state.obraSelecionada != null;

    return DropTarget(
      onDragEntered: (details) => setState(() => _isDragging = true),
      onDragExited: (details) => setState(() => _isDragging = false),
      onDragDone: (details) async {
        if (!isReadyForUpload) {
          return;
        }
        // Tratamento de drag-and-drop de arquivo...
        // Como o file_picker e o drop_target divergem no web/desktop,
        // vamos focar no botão clique para MVP da IA.
      },
      child: InkWell(
        onTap: isReadyForUpload ? planilhamentoIaCtrl.pickFile : null,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _isDragging 
                ? AppColors.primaryMain.withValues(alpha: 0.05) 
                : (isReadyForUpload ? const Color(0xFFF8FAFC) : Colors.grey[100]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isDragging 
                  ? AppColors.primaryMain 
                  : (isReadyForUpload ? const Color(0xFFCBD5E1) : Colors.grey[300]!),
              width: 2,
              style: BorderStyle.solid, // Flutter doesn't natively support dashed easily without a plugin
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isReadyForUpload ? Colors.white : Colors.grey[200],
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (isReadyForUpload)
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
                    ],
                  ),
                  child: Icon(
                    Icons.upload_file_outlined,
                    size: 40,
                    color: isReadyForUpload ? AppColors.primaryMain : Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Clique ou arraste o arquivo PDF aqui',
                  style: AppCss.mediumBold.setColor(isReadyForUpload ? const Color(0xFF475569) : Colors.grey[500]!),
                ),
                const SizedBox(height: 8),
                Text(
                  isReadyForUpload ? 'Suporte apenas para arquivos .pdf' : 'Selecione o Cliente e Obra primeiro',
                  style: AppCss.minimumRegular.setColor(Colors.grey[500]!).setSize(13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingState(PlanilhamentoIaState state) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryMain.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              color: AppColors.primaryMain,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Lendo projeto com IA...',
            style: AppCss.largeBold.setColor(const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),
          Text(
            'Arquivo: ${state.fileName}',
            style: AppCss.minimumRegular.setColor(const Color(0xFF64748B)).setSize(14),
          ),
          const SizedBox(height: 4),
          Text(
            'Extraindo posições, bitolas e formas estruturais. Isso pode levar alguns segundos.',
            style: AppCss.minimumRegular.setColor(Colors.grey[500]!).setSize(13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState(PlanilhamentoIaState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Projeto Processado com Sucesso!',
                    style: AppCss.largeBold.setColor(const Color(0xFF1E293B)),
                  ),
                  Text(
                    'A IA retornou o seguinte resultado bruto (JSON):',
                    style: AppCss.minimumRegular.setColor(const Color(0xFF64748B)).setSize(14),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => planilhamentoIaCtrl.importarPlanilha(context),
              icon: const Icon(Icons.download_done, size: 18),
              label: const Text('Importar para Planilha'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMain,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: planilhamentoIaCtrl.reset,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Novo Arquivo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryMain,
                side: BorderSide(color: AppColors.primaryMain),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: SingleChildScrollView(
              child: Text(
                state.rawResult,
                style: AppCss.minimumRegular.setColor(Colors.greenAccent).setSize(13).copyWith(fontFamily: 'monospace'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
