import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/modules/dashboard/models/demanda_model.dart';
import 'package:flutter/material.dart';

/// Cor de cada coluna do Kanban de demandas, usada nos selos de etapa.
extension DemandaEtapaCor on DemandaEtapa {
  Color get cor {
    switch (this) {
      case DemandaEtapa.aguardandoFila:
        return AppColors.statusAguardando;
      case DemandaEtapa.emProducao:
        return AppColors.statusProduzindo;
      case DemandaEtapa.aguardandoCorrecao:
      case DemandaEtapa.corrigindo:
        return AppColors.statusAtencao;
      case DemandaEtapa.finalizadoLiberado:
        return AppColors.statusPronto;
    }
  }
}
