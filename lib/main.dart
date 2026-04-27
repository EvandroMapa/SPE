import 'package:acoplan/app/app_controller.dart';
import 'package:acoplan/app/app_widget.dart';
import 'package:acoplan/app/core/models/service_model.dart';
import 'package:acoplan/app/core/router/route_config.dart';
import 'package:flutter/material.dart';

import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);

  await Service.initCoreServices();

  RouteConfig.setConfig();

  runApp(const App());

  Service.initAplicationServices().then((_) => appCtrl.onInit());
}

//asfasdfadsf
//asfdadsfsdf
