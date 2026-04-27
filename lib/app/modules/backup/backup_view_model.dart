import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BackupUtils {
  String restoreTitle = 'Restaurar Backup';
  int restoreLenght = 0;
  int restoreIndex = 0;
}

class BackupModel {
  final String nome;
  final DateTime createdAt;

  BackupModel({required this.nome, required this.createdAt});

  factory BackupModel.fromFileObject(FileObject file) {
    DateTime createdAt;
    try {
      // Nome: backup_dd_MM_yyyy_HH_mm_ss.json
      final datePart =
          file.name.replaceAll('.json', '').replaceFirst('backup_', '');
      createdAt = DateFormat('dd_MM_yyyy_HH_mm_ss').parse(datePart);
    } catch (_) {
      createdAt = file.createdAt != null
          ? DateTime.parse(file.createdAt!)
          : DateTime.now();
    }
    return BackupModel(nome: file.name, createdAt: createdAt);
  }
}
