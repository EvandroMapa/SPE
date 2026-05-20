import 'package:acoplan/app/app_controller.dart';
import 'package:acoplan/app/core/enums/app_module.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/modules/base/base_controller.dart';
import 'package:acoplan/app/modules/config/config_page.dart';
import 'package:flutter/material.dart';

class AppHoverSidebar extends StatefulWidget {
  const AppHoverSidebar({super.key});

  @override
  State<AppHoverSidebar> createState() => _AppHoverSidebarState();
}

class _AppHoverSidebarState extends State<AppHoverSidebar> {
  bool _isHovered = false;
  bool _cadastrosExpanded = false;

  void _navigate(AppModule module) {
    baseCtrl.setModule(module);
    setState(() {
      _isHovered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = appCtrl.usuario;
    final width = _isHovered ? 280.0 : 60.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(right: BorderSide(color: Color(0xFFE2E8F0))),
          boxShadow: _isHovered
              ? [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: _isHovered ? 180 : 80,
              padding: _isHovered 
                  ? const EdgeInsets.fromLTRB(16, 24, 16, 20)
                  : const EdgeInsets.fromLTRB(0, 16, 0, 16),
              color: const Color(0xFF1A2233),
              child: _isHovered
                  ? _buildExpandedHeader(user)
                  : _buildCollapsedHeader(user),
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
                        label: 'Planilha Manual',
                        module: AppModule.projetos,
                        current: current,
                      ),
                      _buildItem(
                        icon: Icons.auto_awesome_outlined,
                        label: 'Planilhamento IA',
                        module: AppModule.planilhamentoIA,
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
                      if (_isHovered)
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
                          ],
                        )
                      else
                        _buildCollapsedIcon(
                          icon: Icons.add_circle_outline,
                          isSelected: current == AppModule.cliente || current == AppModule.bitolas || current == AppModule.fabricantes,
                        ),
                      
                      const Divider(height: 1),
                    ],
                  );
                },
              ),
            ),

            // ── Rodapé: Sair ─────────────────────────────────────
            const Divider(height: 1),
            InkWell(
              onTap: () => appCtrl.logout(),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: _isHovered ? MainAxisAlignment.start : MainAxisAlignment.center,
                  children: [
                    Icon(Icons.exit_to_app_rounded, color: AppColors.error, size: 22),
                    if (_isHovered) ...[
                      const SizedBox(width: 16),
                      Text('Sair', style: AppCss.smallBold.setColor(AppColors.error)),
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedHeader(user) {
    return Center(
      child: Tooltip(
        message: user?.nome ?? 'Usuário',
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryMain,
          ),
          child: Center(
            child: Text(
              user?.nome.isNotEmpty == true ? user!.nome[0].toUpperCase() : 'A',
              style: AppCss.smallBold.setColor(Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedHeader(user) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
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
                  setState(() => _isHovered = false);
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            user?.email ?? '',
            style: AppCss.minimumRegular.setColor(Colors.white60),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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
    
    if (!_isHovered) {
      return _buildCollapsedIcon(icon: icon, isSelected: isSelected, tooltip: label, module: module);
    }

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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: hasExternalButton
          ? _externalButton(module)
          : null,
      onTap: () => _navigate(module),
    );
  }

  Widget _buildCollapsedIcon({required IconData icon, required bool isSelected, String? tooltip, AppModule? module}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Tooltip(
          message: tooltip ?? '',
          child: InkWell(
            onTap: module != null ? () => _navigate(module) : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryMain.withValues(alpha: 0.10) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 22,
                color: isSelected ? AppColors.primaryMain : const Color(0xFF555F6E),
              ),
            ),
          ),
        ),
      ),
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
              style: AppCss.smallRegular.setColor(const Color(0xFF1A2233)),
              maxLines: 1, overflow: TextOverflow.ellipsis,),
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
        maxLines: 1, overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _navigate(module),
    );
  }
}
