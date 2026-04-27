import 'package:acoplan/app/modules/backup/backup_controller.dart';
import 'package:flutter/material.dart';

class BackupRestoreDialog extends StatelessWidget {
  const BackupRestoreDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: backupCtrl.progressStream.listen,
      builder: (_, snap) {
        final msg = snap.data ?? 'Iniciando...';
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Processando...',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(
                'Não feche o aplicativo enquanto o processo estiver em andamento.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LinearProgressIndicator(),
              const SizedBox(height: 16),
              Text(msg, style: const TextStyle(fontSize: 13)),
            ],
          ),
        );
      },
    );
  }
}
