import 'package:acoplan/app/app_controller.dart';
import 'package:acoplan/app/core/enums/app_module.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/core/utils/app_env.dart';
import 'package:acoplan/app/modules/base/base_controller.dart';
import 'package:acoplan/app/modules/config/config_page.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Menu lateral no mesmo padrão do PCP: cabeçalho com o logo, item ativo no
/// vermelho da marca, grupos recolhíveis e versão no rodapé.
class AppDrawerMenu extends StatefulWidget {
  const AppDrawerMenu({super.key});

  @override
  State<AppDrawerMenu> createState() => _AppDrawerMenuState();
}

class _AppDrawerMenuState extends State<AppDrawerMenu> {
  static const _areasPrincipais = [
    AppModule.dashboard,
    AppModule.demandas,
    AppModule.projetos,
    AppModule.pedidosTecnicos,
  ];

  bool _pode(AppModule m) => appCtrl.usuario?.podeVer(m.area) ?? true;

  static const _cadastros = [
    AppModule.cliente,
    AppModule.bitolas,
    AppModule.formas,
  ];

  late bool _cadastrosAberto = _cadastros.contains(baseCtrl.moduleStream.value);

  void _navegar(AppModule module) {
    baseCtrl.setModule(module);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 290,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(),
      child: StreamBuilder<AppModule>(
        stream: baseCtrl.moduleStream.listen,
        initialData: baseCtrl.moduleStream.value,
        builder: (context, snap) {
          final atual = snap.data ?? AppModule.dashboard;
          final cadastroAtivo = _cadastros.contains(atual);
          return Column(
            children: [
              const _DrawerCabecalho(),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // Áreas de trabalho (cada perfil vê só as suas)
                    for (final m in _areasPrincipais)
                      if (_pode(m))
                        _DrawerItem(
                          module: m,
                          ativo: atual == m,
                          onTap: () => _navegar(m),
                        ),
                    _divisor(),
                    if (_pode(AppModule.cliente))
                      Theme(
                        // Sem as linhas que o ExpansionTile desenha ao abrir
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: _cadastrosAberto || cadastroAtivo,
                          onExpansionChanged: (v) => _cadastrosAberto = v,
                          iconColor: AppColors.neutralDark,
                          collapsedIconColor: AppColors.neutralDark,
                          tilePadding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                          ),
                          leading: Icon(
                            Symbols.folder_open,
                            color: AppColors.neutralDark,
                          ),
                          title: Text(
                            'Cadastros',
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.black,
                              fontWeight: cadastroAtivo
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          children: [
                            for (final m in _cadastros)
                              _DrawerItem(
                                module: m,
                                ativo: atual == m,
                                recuado: true,
                                onTap: () => _navegar(m),
                              ),
                          ],
                        ),
                      ),
                    _divisor(),
                  ],
                ),
              ),
              _divisor(),
              ListTile(
                leading: Icon(Icons.logout, color: AppColors.error, size: 22),
                title: Text(
                  'Sair',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  appCtrl.logout();
                },
              ),
              const _DrawerVersao(),
            ],
          );
        },
      ),
    );
  }

  Widget _divisor() =>
      Divider(height: 1, color: AppColors.black.withValues(alpha: 0.08));
}

class _DrawerCabecalho extends StatelessWidget {
  const _DrawerCabecalho();

  @override
  Widget build(BuildContext context) {
    final user = appCtrl.usuario;
    final perfil = user?.tipo?.nome ?? '';
    return Container(
      width: double.infinity,
      height: 190,
      color: AppColors.primaryMain,
      padding: EdgeInsets.fromLTRB(
        16,
        16 + MediaQuery.paddingOf(context).top,
        8,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo inteiro em quadrado branco (o círculo cortava o "2")
              Container(
                width: 60,
                height: 60,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Configurações',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.transparent,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const ConfigPage()));
                },
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
              ),
            ],
          ),
          const Spacer(),
          Text(
            user?.nome ?? 'Usuário',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppCss.mediumBold.setSize(15).setColor(Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            perfil.isNotEmpty ? perfil : (user?.email ?? ''),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppCss.minimumRegular
                .setSize(12.5)
                .setColor(Colors.white.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final AppModule module;
  final bool ativo;
  final bool recuado;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.module,
    required this.ativo,
    required this.onTap,
    this.recuado = false,
  });

  @override
  Widget build(BuildContext context) {
    // Item ativo: fundo vermelho-claro, faixa e ícone no vermelho da marca
    return Container(
      decoration: BoxDecoration(
        color: ativo ? AppColors.brandSoft : null,
        border: Border(
          left: BorderSide(
            color: ativo ? AppColors.brand : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: ListTile(
        dense: recuado,
        contentPadding: EdgeInsets.only(left: recuado ? 36 : 13, right: 16),
        leading: Icon(
          module.icon,
          size: recuado ? 20 : 24,
          color: ativo ? AppColors.brand : AppColors.neutralDark,
        ),
        title: Text(
          module.label,
          style: TextStyle(
            fontSize: recuado ? 14 : 15,
            color: AppColors.black,
            fontWeight: ativo ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Rodapé do menu: versão e commit, discretos. Selo DEV quando roda local.
class _DrawerVersao extends StatelessWidget {
  const _DrawerVersao();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.neutralLight)),
      ),
      child: Row(
        children: [
          if (kBuildHash == 'local') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.statusAtencao,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'DEV',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              kVersaoLabel,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: AppColors.neutralMedium),
            ),
          ),
        ],
      ),
    );
  }
}
