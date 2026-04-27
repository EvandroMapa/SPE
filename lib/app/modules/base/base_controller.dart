import 'package:acoplan/app/core/enums/app_module.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:flutter/material.dart';

final baseCtrl = BaseController();

class BaseController {
  static final BaseController _instance = BaseController._();
  BaseController._();
  factory BaseController() => _instance;

  final AppStream<AppModule> moduleStream = AppStream.seed(AppModule.projetos);
  final AppStream<List<Widget>> appBarActionsStream = AppStream.seed([]);

  void setModule(AppModule module) {
    moduleStream.add(module);
    appBarActionsStream.add([]);
  }
}
