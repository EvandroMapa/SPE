import 'dart:convert';
import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/components/app_scaffold.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/core/utils/download_util.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _isExporting = false;

  Future<void> _exportarDados() async {
    setState(() => _isExporting = true);
    try {
      final String timestamp =
          DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      
      final Map<String, dynamic> backupData = {
        'metadata': {
          'timestamp': DateTime.now().toIso8601String(),
          'versao': '1.0',
        },
        'usuarios': BackendClient.usuarios.data.map((e) => e.toMap()).toList(),
        'perfis': BackendClient.usuarioTipos.data.map((e) => e.toSupabaseMap()).toList(),
        'clientes': BackendClient.clientes.data.map((e) => e.toMap()).toList(),
        'produtos': BackendClient.produtos.data.map((e) => e.toMap()).toList(),
        'fabricantes': BackendClient.fabricantes.data.map((e) => e.toMap()).toList(),
      };

      final jsonString = json.encode(backupData);
      DownloadUtil.downloadJson('backup_spe_$timestamp.json', jsonString);
      
      NotificationService.showPositive('Backup Concluído', 'O arquivo foi baixado com sucesso.');
    } catch (e) {
      NotificationService.showNegative('Erro no Backup', e.toString());
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white, size: 20),
        backgroundColor: AppColors.primaryMain,
        title: Text(
          'Backup',
          style: AppCss.mediumBold.setColor(Colors.white),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.security_rounded,
                size: 80,
                color: AppColors.primaryMain,
              ),
              const SizedBox(height: 24),
              Text(
                'Exportação de Dados',
                style: AppCss.largeBold,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Faça o download de todos os registros do sistema (Usuários, Perfis, Clientes, Produtos e Fabricantes) em formato JSON seguro.',
                style: AppCss.mediumRegular.setColor(AppColors.neutralDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: _isExporting ? null : _exportarDados,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryMain,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isExporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(
                  _isExporting ? 'GERANDO BACKUP...' : 'BAIXAR BACKUP COMPLETO',
                  style: AppCss.smallBold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
