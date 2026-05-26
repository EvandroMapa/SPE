import 'dart:convert';
import 'dart:html' as html;

import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/supabase_service.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/backup/backup_view_model.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final backupCtrl = BackupController();

class BackupController {
  static final BackupController _instance = BackupController._();
  BackupController._();
  factory BackupController() => _instance;

  static const _bucket = 'backups';

  final AppStream<List<BackupModel>> backupsStream =
      AppStream<List<BackupModel>>();
  List<BackupModel> get backups => backupsStream.value;

  // Stream de progresso para exibir na UI
  final AppStream<String> progressStream = AppStream<String>();

  Future<void> onInit() async {
    await onFetch();
  }

  // ─── LISTAR BACKUPS ──────────────────────────────────────────────────────
  Future<void> onFetch() async {
    try {
      final List<FileObject> items =
          await SupabaseService.client.storage.from(_bucket).list();

      final list = items
          .where((f) => f.name.endsWith('.json'))
          .map((f) => BackupModel.fromFileObject(f))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      backupsStream.add(list);
    } catch (e) {
      print('BackupController.onFetch erro: $e');
      backupsStream.add([]);
    }
  }

  // ─── CRIAR BACKUP ────────────────────────────────────────────────────────
  Future<void> onCreateBackup(BuildContext context) async {
    final tables = [
      'perfis',
      'usuarios',
      'clientes',
      'fabricantes',
      'bitolas',
    ];

    // Exibe diálogo de progresso (não modal, com stream)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _BackupProgressDialog(),
    );

    try {
      final Map<String, dynamic> data = {};

      for (var i = 0; i < tables.length; i++) {
        final table = tables[i];
        progressStream.add(
          '(${i + 1}/${tables.length}) Exportando: $table...',
        );
        try {
          data[table] = await SupabaseService.client.from(table).select();
        } catch (_) {
          data[table] = [];
        }
      }

      progressStream.add('Gerando arquivo JSON...');
      final bytes = utf8.encode(jsonEncode(data));
      final name =
          'backup_${DateFormat('dd_MM_yyyy_HH_mm_ss').format(DateTime.now())}.json';

      progressStream.add('Enviando para o servidor...');
      await SupabaseService.client.storage.from(_bucket).uploadBinary(
            name,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'application/json',
              upsert: true,
            ),
          );

      progressStream.add('Preparando download local...');
      final b64 = base64Encode(bytes);
      html.AnchorElement(href: 'data:application/octet-stream;base64,$b64')
        ..setAttribute('download', name)
        ..click();

      pop(contextGlobal); // fecha o progress dialog
      await onFetch(); // atualiza a lista
    } catch (e) {
      pop(contextGlobal); // fecha o progress dialog
      NotificationService.showNegative('Erro', 'Erro ao criar backup:\n$e');
    }
  }

  // ─── CRIAR BACKUP (SILENCIOSO - para agendamento automático) ─────────────
  Future<void> onCreateBackupSilent() async {
    try {
      final tables = [
        'perfis',
        'usuarios',
        'clientes',
        'fabricantes',
        'bitolas',
      ];

      final Map<String, dynamic> data = {};
      for (final table in tables) {
        try {
          data[table] = await SupabaseService.client.from(table).select();
        } catch (_) {
          data[table] = [];
        }
      }

      final bytes = utf8.encode(jsonEncode(data));
      final name =
          'backup_${DateFormat('dd_MM_yyyy_HH_mm_ss').format(DateTime.now())}.json';

      await SupabaseService.client.storage.from(_bucket).uploadBinary(
            name,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'application/json',
              upsert: true,
            ),
          );

      await onFetch();
      print('✅ Backup automático realizado: $name');
    } catch (e) {
      print('❌ Erro no backup automático: $e');
    }
  }

  Future<void> onDownloadBackup(BackupModel backup) async {
    try {
      progressStream.add('Baixando ${backup.nome}...');
      final bytes = await SupabaseService.client.storage
          .from(_bucket)
          .download(backup.nome);

      final b64 = base64Encode(bytes);
      html.AnchorElement(href: 'data:application/octet-stream;base64,$b64')
        ..setAttribute('download', backup.nome)
        ..click();
    } catch (e) {
      NotificationService.showNegative('Erro', 'Erro ao baixar backup:\n$e');
    }
  }

  // ─── RESTAURAR BACKUP ────────────────────────────────────────────────────
  Future<void> onRestoreBackup(BuildContext context) async {
    final result = await fp.FilePicker.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null) return;
    if (result.files.first.bytes == null) {
      NotificationService.showNegative('Erro', 'Não foi possível ler o arquivo selecionado.');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _BackupProgressDialog(),
    );

    try {
      progressStream.add('Lendo arquivo...');
      final Map<String, dynamic> data =
          jsonDecode(utf8.decode(result.files.first.bytes!));

      final deleteOrder = [
        'bitolas',
        'fabricantes',
        'clientes',
        'usuarios',
        'perfis',
      ];

      // 2. Deleta (filhos -> pais)
      for (var i = 0; i < deleteOrder.length; i++) {
        final table = deleteOrder[i];
        progressStream
            .add('(${i + 1}/${deleteOrder.length}) Limpando: $table...');
        try {
          final rows = await SupabaseService.client.from(table).select('id');
          final ids = rows.map((r) => r['id']).toList();
          for (var j = 0; j < ids.length; j += 200) {
            final chunk = ids.sublist(j, (j + 200).clamp(0, ids.length));
            await SupabaseService.client
                .from(table)
                .delete()
                .inFilter('id', chunk);
          }
        } catch (_) {}
      }

      // 3. Insere (pais -> filhos)
      final insertOrder = deleteOrder.reversed.toList();
      for (var i = 0; i < insertOrder.length; i++) {
        final table = insertOrder[i];
        final rows = (data[table] as List?)?.cast<Map<String, dynamic>>();
        if (rows == null || rows.isEmpty) continue;
        progressStream
            .add('(${i + 1}/${insertOrder.length}) Restaurando: $table...');
        try {
          for (var j = 0; j < rows.length; j += 500) {
            final chunk = rows.sublist(j, (j + 500).clamp(0, rows.length));
            await SupabaseService.client.from(table).upsert(chunk);
          }
        } catch (e) {
          print('Erro ao restaurar $table: $e');
        }
      }

      progressStream.add('Concluído! Recarregando...');
      await Future.delayed(const Duration(seconds: 1));
      html.window.location.reload();
    } catch (e) {
      pop(contextGlobal);
      NotificationService.showNegative('Erro', 'Erro ao restaurar backup:\n$e');
    }
  }
}

// ─── DIÁLOGO DE PROGRESSO ────────────────────────────────────────────────────
class _BackupProgressDialog extends StatelessWidget {
  const _BackupProgressDialog();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: backupCtrl.progressStream.listen,
      builder: (_, snap) {
        final msg = snap.data ?? 'Iniciando...';
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Processando',
              style: TextStyle(fontWeight: FontWeight.bold)),
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
