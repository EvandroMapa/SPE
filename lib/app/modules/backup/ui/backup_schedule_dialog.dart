import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/modules/backup/backup_scheduler_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Future<void> showBackupScheduleDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => const BackupScheduleDialog(),
  );
}

class BackupScheduleDialog extends StatefulWidget {
  const BackupScheduleDialog({super.key});

  @override
  State<BackupScheduleDialog> createState() => _BackupScheduleDialogState();
}

class _BackupScheduleDialogState extends State<BackupScheduleDialog> {
  BackupScheduleConfig? _config;
  bool _loading = true;

  final _diasNomes = {
    1: 'Seg',
    2: 'Ter',
    3: 'Qua',
    4: 'Qui',
    5: 'Sex',
    6: 'Sáb',
    7: 'Dom',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cfg = await BackupScheduleConfig.load();
    setState(() {
      _config = cfg;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await _config!.save();
    await BackupSchedulerService().reload();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _config!.hora, minute: _config!.minuto),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _config!.hora = picked.hour;
        _config!.minuto = picked.minute;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _config == null) {
      return const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final proximo = _config!.proximoBackup;

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryMain.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.schedule_rounded,
                color: AppColors.primaryMain, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Backup Automático', style: AppCss.largeBold),
              Text(
                'Configure dias e horário',
                style: AppCss.smallRegular.copyWith(color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // ── Toggle ativo ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: _config!.enabled
                    ? Colors.green.shade50
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _config!.enabled
                      ? Colors.green.shade200
                      : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _config!.enabled
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    color: _config!.enabled ? Colors.green : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Agendamento ativo', style: AppCss.mediumBold),
                        Text(
                          _config!.enabled
                              ? 'Backups automáticos habilitados'
                              : 'Clique para habilitar',
                          style: AppCss.smallRegular.copyWith(
                            color: _config!.enabled
                                ? Colors.green.shade700
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _config!.enabled,
                    activeThumbColor: Colors.green,
                    onChanged: (v) => setState(() => _config!.enabled = v),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Dias da semana ────────────────────────────────────────────
            Text('Dias da semana', style: AppCss.mediumBold),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _diasNomes.entries.map((e) {
                final selected = _config!.dias.contains(e.key);
                return _DayButton(
                  label: e.value,
                  selected: selected,
                  color: AppColors.primaryMain,
                  onTap: () => setState(() {
                    if (selected) {
                      _config!.dias.remove(e.key);
                    } else {
                      _config!.dias
                        ..add(e.key)
                        ..sort();
                    }
                  }),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // ── Horário ───────────────────────────────────────────────────
            Text('Horário do backup', style: AppCss.mediumBold),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickTime,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryMain.withValues(alpha: 0.05),
                      AppColors.primaryMain.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primaryMain.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        color: AppColors.primaryMain, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      '${_config!.hora.toString().padLeft(2, '0')}:${_config!.minuto.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryMain,
                        letterSpacing: 2,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryMain.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Alterar',
                        style: AppCss.smallRegular
                            .copyWith(color: AppColors.primaryMain),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Próximo backup ────────────────────────────────────────────
            if (proximo != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_available_rounded,
                        color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Próximo: ${DateFormat("EEE, dd/MM 'às' HH:mm", 'pt_BR').format(proximo)}',
                        style: AppCss.smallRegular
                            .copyWith(color: Colors.green.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_config!.ultimoBackup != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Último automático: ${DateFormat('dd/MM/yyyy HH:mm').format(_config!.ultimoBackup!)}',
                  style: AppCss.smallRegular.copyWith(color: Colors.grey[500]),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar',
              style: TextStyle(
                  color: Colors.grey[600], fontWeight: FontWeight.w500)),
        ),
        const SizedBox(width: 4),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryMain,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          icon: const Icon(Icons.save_rounded, size: 18),
          label: const Text('Salvar configuração',
              style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: _save,
        ),
      ],
    );
  }
}

// ─── BOTÃO DE DIA ─────────────────────────────────────────────────────────────
class _DayButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _DayButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? color : Colors.transparent,
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }
}
