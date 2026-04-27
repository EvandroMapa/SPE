import 'package:acoplan/app/modules/cliente/ui/clientes_page.dart';
import 'package:acoplan/app/modules/fabricante/ui/fabricantes_page.dart';
import 'package:acoplan/app/modules/pedido_tecnico/ui/pedidos_tecnicos_page.dart';
import 'package:acoplan/app/modules/produto/ui/produtos_page.dart';
import 'package:acoplan/app/modules/projeto/ui/projetos_page.dart';
import 'package:acoplan/app/modules/forma/ui/formas_page.dart';

import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:flutter/material.dart';

enum AppModule {
  projetos,
  pedidosTecnicos,
  cliente,
  fabricantes,
  formas,
  produtos,
}

extension AppModuleExt on AppModule {
  Widget get widget {
    switch (this) {
      case AppModule.projetos:
        return const ProjetosPage();
      case AppModule.pedidosTecnicos:
        return const PedidosTecnicosPage();
      case AppModule.cliente:
        return const ClientesPage();
      case AppModule.fabricantes:
        return const FabricantesPage();
      case AppModule.formas:
        return const FormasPage();
      case AppModule.produtos:
        return const ProdutosPage();

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
      case AppModule.projetos:
        return Icons.architecture_outlined;
      case AppModule.pedidosTecnicos:
        return Icons.description_outlined;
      case AppModule.cliente:
        return Icons.group_outlined;
      case AppModule.fabricantes:
        return Icons.business_outlined;
      case AppModule.formas:
        return Icons.architecture;
      case AppModule.produtos:
        return Icons.inventory_2_outlined;

    }
  }

  String get label {
    switch (this) {
      case AppModule.projetos:
        return 'Projetos';
      case AppModule.pedidosTecnicos:
        return 'Pedidos Técnicos';
      case AppModule.cliente:
        return 'Clientes';
      case AppModule.fabricantes:
        return 'Fabricantes';
      case AppModule.formas:
        return 'Formas / Desenhos';
      case AppModule.produtos:
        return 'Produtos';

    }
  }
}
