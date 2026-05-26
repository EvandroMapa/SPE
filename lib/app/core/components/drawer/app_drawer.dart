import 'package:acoplan/app/app_controller.dart';
import 'package:acoplan/app/core/enums/app_module.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/modules/base/base_controller.dart';
import 'package:acoplan/app/modules/config/config_page.dart';
import 'package:flutter/material.dart';

class AppDrawerMenu extends StatefulWidget {
  const AppDrawerMenu({super.key});

  @override
  State<AppDrawerMenu> createState() => _AppDrawerMenuState();
}

class _AppDrawerMenuState extends State<AppDrawerMenu> {
  bool _cadastrosExpanded = false;

  void _navigate(AppModule module) {
    baseCtrl.setModule(module);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final user = appCtrl.usuario;

    return Drawer(
      width: 280,
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
            color: const Color(0xFF1A2233),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Avatar
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryMain,
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          user?.nome.isNotEmpty == true
                              ? user!.nome[0].toUpperCase()
                              : 'A',
                          style: AppCss.largeBold.setColor(Colors.white),
                        ),
                      ),
                    ),
                    // Botão Configurações
                    InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const ConfigPage(),
                        ));
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.settings_outlined,
                          color: Colors.white70,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  user?.nome ?? 'Usuário',
                  style: AppCss.mediumBold.setColor(Colors.white),
                ),
                Text(
                  user?.email ?? '',
                  style: AppCss.minimumRegular
                      .setColor(Colors.white60),
                ),
              ],
            ),
          ),

          // ── Itens do menu ────────────────────────────────────
          Expanded(
            child: StreamBuilder<AppModule>(
              stream: baseCtrl.moduleStream.listen,
              builder: (context, snap) {
                final current = snap.data ?? AppModule.projetos;
                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _buildItem(
                      icon: Icons.architecture_outlined,
                      label: 'Projetos',
                      module: AppModule.projetos,
                      current: current,
                    ),
                    _buildItem(
                      icon: Icons.description_outlined,
                      label: 'Pedidos Técnicos',
                      module: AppModule.pedidosTecnicos,
                      current: current,
                      hasExternalButton: true,
                    ),
                    const Divider(height: 1),

                    // ── Cadastros (expansível) ───────────────
                    _buildExpansionItem(
                      icon: Icons.add_circle_outline,
                      label: 'Cadastros',
                      expanded: _cadastrosExpanded,
                      onToggle: () => setState(
                          () => _cadastrosExpanded = !_cadastrosExpanded),
                      children: [
                        _buildSubItem(AppModule.cliente, current,
                            Icons.group_outlined, 'Clientes'),
                        _buildSubItem(AppModule.bitolas, current,
                            Icons.inventory_2_outlined, 'Bitolas'),
                        _buildSubItem(AppModule.fabricantes, current,
                            Icons.business_outlined, 'Fabricantes'),
                        _buildSubItem(AppModule.formas, current,
                            Icons.architecture, 'Formas'),

                      ],
                    ),
                    const Divider(height: 1),
                  ],
                );
              },
            ),
          ),

          // ── Rodapé: Sair ─────────────────────────────────────
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.exit_to_app_rounded,
                color: AppColors.error, size: 22),
            title: Text('Sair',
                style: AppCss.smallBold.setColor(AppColors.error)),
            onTap: () {
              Navigator.of(context).pop();
              appCtrl.logout();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildItem({
    required IconData icon,
    required String label,
    required AppModule module,
    required AppModule current,
    bool hasExternalButton = false,
  }) {
    final isSelected = module == current;
    return ListTile(
      selected: isSelected,
      selectedTileColor: AppColors.primaryMain.withValues(alpha: 0.06),
      leading: Icon(
        icon,
        size: 22,
        color: isSelected ? AppColors.primaryMain : const Color(0xFF555F6E),
      ),
      title: Text(
        label,
        style: AppCss.smallRegular.setColor(
          isSelected ? AppColors.primaryMain : const Color(0xFF1A2233),
        ),
      ),
      trailing: hasExternalButton
          ? _externalButton(module)
          : null,
      onTap: () => _navigate(module),
    );
  }

  Widget _externalButton(AppModule module) {
    return InkWell(
      onTap: () => _navigate(module),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF1A2233),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.open_in_new_rounded,
            color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildExpansionItem({
    required IconData icon,
    required String label,
    required bool expanded,
    required VoidCallback onToggle,
    required List<Widget> children,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, size: 22, color: const Color(0xFF555F6E)),
          title: Text(label,
              style: AppCss.smallRegular.setColor(const Color(0xFF1A2233))),
          trailing: AnimatedRotation(
            turns: expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child:
                const Icon(Icons.keyboard_arrow_down, color: Color(0xFF555F6E)),
          ),
          onTap: onToggle,
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSubItem(
      AppModule module, AppModule current, IconData icon, String label) {
    final isSelected = module == current;
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 48, right: 16),
      selected: isSelected,
      selectedTileColor: AppColors.primaryMain.withValues(alpha: 0.06),
      leading:
          Icon(icon, size: 20, color: isSelected ? AppColors.primaryMain : const Color(0xFF555F6E)),
      title: Text(
        label,
        style: AppCss.minimumRegular.setColor(
          isSelected ? AppColors.primaryMain : const Color(0xFF555F6E),
        ),
      ),
      onTap: () => _navigate(module),
    );
  }
}
