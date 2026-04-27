import 'package:acoplan/app/core/client/http/viacep/viacep_model.dart';
import 'package:dio/dio.dart';

class ViacepProvider {
  static Future<ViacepEndereco?> getEndereco(String cep) async {
    try {
      final response = await Dio().get('https://viacep.com.br/ws/$cep/json/');
      return ViacepEndereco.fromJson(response.data);
    } catch (_) {
      return null;
    }
  }
}
