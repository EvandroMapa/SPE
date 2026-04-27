import 'package:acoplan/app/app_controller.dart';
import 'package:acoplan/app/core/enums/app_module.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/modules/base/base_controller.dart';
import 'package:acoplan/app/modules/config/config_page.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:flutter/material.dart';

class AppSideBar extends StatelessWidget {
  const AppSideBar({super.key});

  @override
  Widget build(BuildContext context) {
    final user = appCtrl.usuario;

    return Container(
      width: 60,
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(
          right: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        children: [
          // ── Preview da Entidade (Topo) ──
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Tooltip(
                message: user.nome,
                preferBelow: false,
                waitDuration: const Duration(milliseconds: 300),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryMain,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryMain.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      user.nome.isNotEmpty ? user.nome[0].toUpperCase() : '?',
                      style: AppCss.minimumBold.setColor(Colors.white),
                    ),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),

          // ── Ícones do Menu ──
          Expanded(
            child: SingleChildScrollView(
              child: StreamBuilder<AppModule>(
                stream: baseCtrl.moduleStream.listen,
                builder: (context, snapshot) {
                  final currentModule = snapshot.data ?? AppModule.projetos;
                  return Column(
                    children: [
                      _buildItem(AppModule.projetos, currentModule),
                      _buildItem(AppModule.pedidosTecnicos, currentModule),
                      _buildItem(AppModule.cliente, currentModule),
                      _buildItem(AppModule.produtos, currentModule),
                      _buildItem(AppModule.fabricantes, currentModule),
                    ],
                  );
                },
              ),
            ),
          ),

          // ── Rodapé (Configurações) ──
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildIconButton(
              icon: Icons.settings_outlined,
              tooltip: 'Configurações',
              onTap: () => push(context, const ConfigPage()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(AppModule module, AppModule current) {
    final isSelected = module == current;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Tooltip(
        message: module.label,
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 300),
        child: InkWell(
          onTap: () => baseCtrl.setModule(module),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryMain.withValues(alpha: 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(
                      color: AppColors.primaryMain.withValues(alpha: 0.20),
                    )
                  : null,
            ),
            child: Icon(
              module.icon,
              size: 18,
              color: isSelected ? AppColors.primaryMain : Colors.grey[400],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Tooltip(
        message: tooltip,
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 300),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color?.withValues(alpha: 0.10) ?? Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: color ?? Colors.grey[400],
            ),
          ),
        ),
      ),
    );
  }
}
