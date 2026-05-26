import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/cliente_model.dart';
import 'package:acoplan/app/core/components/app_drop_down.dart';
import 'package:acoplan/app/core/components/app_scaffold.dart';
import 'package:acoplan/app/core/components/stream_out.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/modules/detalhamento_ia/detalhamento_ia_controller.dart';
import 'package:acoplan/app/modules/detalhamento_ia/importacao/importacao_resultado.dart';
import 'package:acoplan/app/modules/detalhamento_ia/preparacao/ui/preparacao_dxf_widget.dart';
import 'package:acoplan/app/modules/detalhamento_ia/ui/ia_processing_widget.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:overlay_support/overlay_support.dart';

class DetalhamentoIaPage extends StatefulWidget {
  const DetalhamentoIaPage({super.key});

  @override
  State<DetalhamentoIaPage> createState() => _DetalhamentoIaPageState();
}

class _DetalhamentoIaPageState extends State<DetalhamentoIaPage> {
  bool _isDragging = false;

  @override
  void initState() {
    detalhamentoIaCtrl.init();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamOut(
        stream: detalhamentoIaCtrl.stateStream.listen,
        builder: (_, state) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // -- Header compacto --
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryMain.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.auto_awesome, color: AppColors.primaryMain, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text('Importação de Projeto', style: AppCss.largeBold.setColor(AppColors.primaryMain)),
                    const Spacer(),
                    if (state.fileName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryMain.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              state.tipoImportacao == TipoImportacao.pdf
                                  ? Icons.picture_as_pdf
                                  : Icons.architecture,
                              size: 14,
                              color: AppColors.primaryMain,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              state.fileName!,
                              style: TextStyle(fontSize: 12, color: AppColors.primaryMain, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // -- Container 1: Vínculo + Upload --
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      _stepBadge('1', true),
                      const SizedBox(width: 12),
                      Text('Vínculo', style: AppCss.mediumBold.setColor(const Color(0xFF1E293B)).setSize(13)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: AppDropDown<ClienteModel?>(
                          label: 'Cliente',
                          item: state.clienteSelecionado,
                          itens: BackendClient.clientes.data,
                          itemLabel: (e) => e?.nome ?? 'Selecione',
                          onSelect: detalhamentoIaCtrl.setCliente,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppDropDown<ObraModel?>(
                          label: 'Obra',
                          item: state.obraSelecionada,
                          itens: state.clienteSelecionado?.obras ?? [],
                          itemLabel: (e) => e?.descricao ?? 'Selecione',
                          onSelect: detalhamentoIaCtrl.setObra,
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: (state.clienteSelecionado != null && state.obraSelecionada != null)
                            ? detalhamentoIaCtrl.pickFile
                            : null,
                        icon: const Icon(Icons.upload_file, size: 18),
                        label: Text(state.fileName != null ? 'Trocar Arquivo' : 'Selecionar Arquivo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryMain,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // -- Container 2: Preparação do Arquivo --
                Expanded(
                  child: PreparacaoDxfWidget(
                    onImportar: () {
                      detalhamentoIaCtrl.importarDaPreparacao();
                      if (state.status == IaStatus.success) {
                        detalhamentoIaCtrl.importarDetalhamento(context);
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _stepBadge(String numero, bool ativo) {
    return Container(
      width: 24, height: 24,
      decoration: BoxDecoration(
        color: ativo ? AppColors.primaryMain : Colors.grey[300],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(numero, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Widget _buildContainer3(DetalhamentoIaState state) {
    if (state.status == IaStatus.success) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _stepBadge('3', true),
              const SizedBox(width: 12),
              Text('Resultado', style: AppCss.mediumBold.setColor(const Color(0xFF1E293B)).setSize(13)),
              const Spacer(),
              Text(
                '${state.elementosEncontrados} elementos extraídos',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => detalhamentoIaCtrl.importarDetalhamento(context),
                icon: const Icon(Icons.download_done, size: 16),
                label: const Text('Importar para Detalhamento', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryMain,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: detalhamentoIaCtrl.reset,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Novo', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryMain,
                  side: BorderSide(color: AppColors.primaryMain.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(10),
              child: SingleChildScrollView(
                child: Text(
                  state.rawResult,
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'monospace'),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (state.status == IaStatus.analyzing) {
      return Row(
        children: [
          _stepBadge('3', false),
          const SizedBox(width: 12),
          Text('Resultado', style: AppCss.mediumBold.setColor(Colors.grey[400]!).setSize(13)),
          const Spacer(),
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
          Text('Processando...', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      );
    }

    // Vazio
    return Row(
      children: [
        _stepBadge('3', false),
        const SizedBox(width: 12),
        Text('Resultado', style: AppCss.mediumBold.setColor(Colors.grey[400]!).setSize(13)),
        const Spacer(),
        Text(
          'Prepare o arquivo e clique "Importar →"',
          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
        ),
      ],
    );
  }

  Widget _buildUploadArea(DetalhamentoIaState state) {
    if (state.status == IaStatus.analyzing || state.status == IaStatus.success) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IaProcessingWidget(
            state: state,
            fileName: state.fileName,
          ),
          if (state.status == IaStatus.success) ...[
            const SizedBox(height: 24),
            Expanded(child: _buildSuccessResultArea(state)),
          ],
        ],
      );
    }

    final bool isReadyForUpload = state.clienteSelecionado != null && state.obraSelecionada != null;

    return DropTarget(
      onDragEntered: (details) => setState(() => _isDragging = true),
      onDragExited: (details) => setState(() => _isDragging = false),
      onDragDone: (details) async {
        if (!isReadyForUpload) {
          return;
        }
      },
      child: InkWell(
        onTap: isReadyForUpload ? detalhamentoIaCtrl.pickFile : null,
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
              style: BorderStyle.solid,
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
                  'Clique para anexar o arquivo PDF ou DXF',
                  style: AppCss.mediumBold.setColor(isReadyForUpload ? const Color(0xFF475569) : Colors.grey[500]!),
                ),
                const SizedBox(height: 8),
                Text(
                  isReadyForUpload 
                      ? 'Suporte para arquivos .pdf (IA) e .dxf (parser automático)'
                      : 'Selecione o Cliente e Obra primeiro',
                  style: AppCss.minimumRegular.setColor(Colors.grey[500]!).setSize(13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessResultArea(DetalhamentoIaState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              state.tipoImportacao == TipoImportacao.pdf
                  ? 'Resultado bruto retornado pela IA:'
                  : 'Resultado extraído do DXF:',
              style: AppCss.minimumRegular.setColor(const Color(0xFF64748B)).setSize(14),
            ),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => detalhamentoIaCtrl.importarDetalhamento(context),
                  icon: const Icon(Icons.download_done, size: 18),
                  label: const Text('Importar para Detalhamento'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryMain,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: detalhamentoIaCtrl.reset,
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
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 48),
                    child: Text(
                      state.rawResult,
                      style: AppCss.minimumRegular.setColor(Colors.greenAccent).setSize(13).copyWith(fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Tooltip(
                  message: 'Copiar Conteúdo',
                  child: Material(
                    color: Colors.transparent,
                    child: IconButton(
                      icon: const Icon(Icons.copy, color: Colors.white70, size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: state.rawResult));
                        NotificationService.showPositive('Copiado!', 'Resultado copiado para a área de transferência.', position: NotificationPosition.bottom);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTipoToggle(DetalhamentoIaState state) {
    final isPdf = state.tipoImportacao == TipoImportacao.pdf;
    final isProcessando = state.status == IaStatus.analyzing || state.status == IaStatus.success;

    return IgnorePointer(
      ignoring: isProcessando,
      child: Opacity(
        opacity: isProcessando ? 0.5 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _toggleBtn(
                icone: Icons.picture_as_pdf_outlined,
                label: 'PDF (IA)',
                selecionado: isPdf,
                onTap: () => detalhamentoIaCtrl.setTipoImportacao(TipoImportacao.pdf),
              ),
              _toggleBtn(
                icone: Icons.architecture_outlined,
                label: 'DXF (Parser)',
                selecionado: !isPdf,
                onTap: () => detalhamentoIaCtrl.setTipoImportacao(TipoImportacao.dxf),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleBtn({
    required IconData icone,
    required String label,
    required bool selecionado,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selecionado ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: selecionado
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 16, color: selecionado ? AppColors.primaryMain : Colors.grey[500]),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppCss.minimumRegular
                  .setColor(selecionado ? AppColors.primaryMain : Colors.grey[500]!)
                  .setSize(13)
                  .copyWith(fontWeight: selecionado ? FontWeight.w600 : FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }
}
