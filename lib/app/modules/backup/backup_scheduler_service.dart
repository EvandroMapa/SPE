import 'dart:async';
import 'dart:convert';

import 'package:acoplan/app/modules/backup/backup_controller.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── MODELO DE CONFIGURAÇÃO ──────────────────────────────────────────────────
class BackupScheduleConfig {
  static const _key = 'backup_schedule_config';

  bool enabled;
  List<int> dias; // 1=Seg, 2=Ter, 3=Qua, 4=Qui, 5=Sex, 6=Sáb, 7=Dom
  int hora;
  int minuto;
  DateTime? ultimoBackup;

  BackupScheduleConfig({
    this.enabled = false,
    List<int>? dias,
    this.hora = 8,
    this.minuto = 0,
    this.ultimoBackup,
  }) : dias = dias ?? [];

  factory BackupScheduleConfig.fromJson(Map<String, dynamic> j) =>
      BackupScheduleConfig(
        enabled: j['enabled'] ?? false,
        dias: (j['dias'] as List?)?.cast<int>() ?? [],
        hora: j['hora'] ?? 8,
        minuto: j['minuto'] ?? 0,
        ultimoBackup: j['ultimoBackup'] != null
            ? DateTime.tryParse(j['ultimoBackup'])
            : null,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'dias': dias,
        'hora': hora,
        'minuto': minuto,
        'ultimoBackup': ultimoBackup?.toIso8601String(),
      };

  static Future<BackupScheduleConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return BackupScheduleConfig();
    return BackupScheduleConfig.fromJson(jsonDecode(raw));
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
  }

  /// Próximo horário de backup (null se não habilitado ou sem dias)
  DateTime? get proximoBackup {
    if (!enabled || dias.isEmpty) return null;
    final now = DateTime.now();
    for (var offset = 0; offset < 8; offset++) {
      final day = now.add(Duration(days: offset));
      final weekDay = day.weekday; // 1=Seg...7=Dom
      if (!dias.contains(weekDay)) continue;
      final candidate = DateTime(day.year, day.month, day.day, hora, minuto);
      if (candidate.isAfter(now)) return candidate;
    }
    return null;
  }
}

// ─── SERVIÇO VERIFICADOR ─────────────────────────────────────────────────────
class BackupSchedulerService {
  static final BackupSchedulerService _instance = BackupSchedulerService._();
  BackupSchedulerService._();
  factory BackupSchedulerService() => _instance;

  Timer? _timer;
  BackupScheduleConfig? _config;
  BuildContext? _context;

  void start(BuildContext context) {
    _context = context;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _check());
    _check(); // verifica imediatamente também
  }

  void stop() => _timer?.cancel();

  Future<void> reload() async {
    _config = await BackupScheduleConfig.load();
  }

  Future<void> _check() async {
    _config ??= await BackupScheduleConfig.load();
    final cfg = _config!;
    if (!cfg.enabled || cfg.dias.isEmpty || _context == null) return;

    final now = DateTime.now();
    final weekDay = now.weekday;
    if (!cfg.dias.contains(weekDay)) return;
    if (now.hour != cfg.hora || now.minute != cfg.minuto) return;

    // Evita disparar duas vezes no mesmo minuto
    final ultimo = cfg.ultimoBackup;
    if (ultimo != null) {
      final diff = now.difference(ultimo).inMinutes.abs();
      if (diff < 2) return;
    }

    // Hora: faz o backup automático (sem diálogo de progresso bloqueante)
    cfg.ultimoBackup = now;
    await cfg.save();
    _config = cfg;

    await backupCtrl.onCreateBackupSilent();
  }
}
