import 'package:acoplan/app/modules/cliente/ui/clientes_page.dart';
import 'package:acoplan/app/modules/dashboard/ui/dashboard_page.dart';
import 'package:acoplan/app/modules/dashboard/ui/painel_page.dart';
import 'package:acoplan/app/modules/fabricante/ui/fabricantes_page.dart';
import 'package:acoplan/app/modules/bitola/ui/bitolas_page.dart';
import 'package:acoplan/app/modules/detalhamento_ia/ui/detalhamento_ia_page.dart';
import 'package:acoplan/app/modules/forma/ui/formas_page.dart';

import 'package:acoplan/app/core/client/models/usuario_model.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Áreas que um perfil de acesso pode enxergar (perfis.modulos).
enum AppArea { painel, demandas, detalhamentos, pedidos, cadastros }

extension AppAreaExt on AppArea {
  String get label {
    switch (this) {
      case AppArea.painel:
        return 'Painel';
      case AppArea.demandas:
        return 'Demandas';
      case AppArea.detalhamentos:
        return 'Detalhamentos';
      case AppArea.pedidos:
        return 'Pedidos técnicos';
      case AppArea.cadastros:
        return 'Cadastros';
    }
  }

  String get descricao {
    switch (this) {
      case AppArea.painel:
        return 'Resumo do trabalho e indicadores';
      case AppArea.demandas:
        return 'Kanban: fila e fluxo das demandas';
      case AppArea.detalhamentos:
        return 'Planilhas de detalhamento (inclui I.A.)';
      case AppArea.pedidos:
        return 'Pedidos técnicos enviados à produção';
      case AppArea.cadastros:
        return 'Clientes, bitolas e formas';
    }
  }
}

extension UsuarioAreasExt on UsuarioModel {
  /// Administrador e perfis sem configuração enxergam tudo.
  bool podeVer(AppArea area) {
    if (isAdmin) return true;
    final modulos = tipo?.modulos;
    if (modulos == null) return true;
    return modulos.contains(area.name);
  }
}

enum AppModule {
  dashboard, // Painel
  demandas,
  projetos, // Detalhamentos
  detalhamentoIA,
  pedidosTecnicos,
  cliente,
  fabricantes,
  formas,
  bitolas,
}

extension AppModuleExt on AppModule {
  Widget get widget {
    switch (this) {
      case AppModule.dashboard:
        return const PainelPage();
      case AppModule.demandas:
        return const DashboardPage(aba: 0);
      case AppModule.projetos:
        return const DashboardPage(aba: 1);
      case AppModule.detalhamentoIA:
        return const DetalhamentoIaPage();
      case AppModule.pedidosTecnicos:
        return const DashboardPage(aba: 2);
      case AppModule.cliente:
        return const ClientesPage();
      case AppModule.fabricantes:
        return const FabricantesPage();
      case AppModule.formas:
        return const FormasPage();
      case AppModule.bitolas:
        return const BitolasPage();
    }
  }

  AppArea get area {
    switch (this) {
      case AppModule.dashboard:
        return AppArea.painel;
      case AppModule.demandas:
        return AppArea.demandas;
      case AppModule.projetos:
      case AppModule.detalhamentoIA:
        return AppArea.detalhamentos;
      case AppModule.pedidosTecnicos:
        return AppArea.pedidos;
      case AppModule.cliente:
      case AppModule.fabricantes:
      case AppModule.formas:
      case AppModule.bitolas:
        return AppArea.cadastros;
    }
  }

  PreferredSizeWidget? appBar(BuildContext context) {
    return AppBar(
      iconTheme: const IconThemeData(color: Colors.white, size: 20),
      backgroundColor: AppColors.primaryMain,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppCss.mediumBold.setSize(20).setColor(Colors.white)),
        ],
      ),
    );
  }

  IconData get icon {
    switch (this) {
      case AppModule.dashboard:
        return Symbols.space_dashboard;
      case AppModule.demandas:
        return Symbols.view_kanban;
      case AppModule.projetos:
        return Symbols.architecture;
      case AppModule.detalhamentoIA:
        return Symbols.auto_awesome;
      case AppModule.pedidosTecnicos:
        return Symbols.receipt_long;
      case AppModule.cliente:
        return Symbols.groups;
      case AppModule.fabricantes:
        return Symbols.factory;
      case AppModule.formas:
        return Symbols.polyline;
      case AppModule.bitolas:
        return Symbols.stacks;
    }
  }

  String get label {
    switch (this) {
      case AppModule.dashboard:
        return 'Painel';
      case AppModule.demandas:
        return 'Demandas';
      case AppModule.projetos:
        return 'Detalhamentos';
      case AppModule.detalhamentoIA:
        return 'Detalhamento por I.A.';
      case AppModule.pedidosTecnicos:
        return 'Pedidos técnicos';
      case AppModule.cliente:
        return 'Clientes';
      case AppModule.fabricantes:
        return 'Fabricantes';
      case AppModule.formas:
        return 'Formas';
      case AppModule.bitolas:
        return 'Bitolas';
    }
  }
}
