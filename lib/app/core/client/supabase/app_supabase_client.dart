import 'dart:developer';
import 'package:acoplan/app/core/client/supabase/cliente_supabase_collection.dart';
import 'package:acoplan/app/core/client/supabase/fabricante_supabase_collection.dart';
import 'package:acoplan/app/core/client/supabase/bitola_supabase_collection.dart';
import 'package:acoplan/app/core/client/supabase/usuario_supabase_collection.dart';
import 'package:acoplan/app/core/client/supabase/usuario_tipo_supabase_collection.dart';
import 'package:acoplan/app/core/client/supabase/forma_supabase_collection.dart';
import 'package:acoplan/app/core/client/supabase/detalhamento_supabase_collection.dart';
import 'package:acoplan/app/core/client/supabase/pedido_tecnico_supabase_collection.dart';


import 'package:acoplan/app/core/client/supabase/demanda_supabase_collection.dart';

class AppSupabaseClient {
  static UsuarioSupabaseCollection usuarios = UsuarioSupabaseCollection();
  static UsuarioTipoSupabaseCollection usuarioTipos = UsuarioTipoSupabaseCollection();
  static ClienteSupabaseCollection clientes = ClienteSupabaseCollection();
  static BitolaSupabaseCollection bitolas = BitolaSupabaseCollection();
  static FabricanteSupabaseCollection fabricantes = FabricanteSupabaseCollection();
  static FormaSupabaseCollection formas = FormaSupabaseCollection();
  static DetalhamentoSupabaseCollection detalhamentos = DetalhamentoSupabaseCollection();
  static PedidoTecnicoSupabaseCollection pedidosTecnicos = PedidoTecnicoSupabaseCollection();
  static DemandaSupabaseCollection demandas = DemandaSupabaseCollection();


  static Future<void> init() async {
    try {
      // 1. Realtime primeiro
      usuarioTipos.listen();
      usuarios.listen();
      clientes.listen();
      bitolas.listen();
      fabricantes.listen();
      formas.listen();
      detalhamentos.listen();
      pedidosTecnicos.listen();
      demandas.listen();


      // 2. Dados iniciais. Bitolas antes dos detalhamentos (usadas no cálculo
      // de peso); o restante em paralelo.
      await Future.wait([
        usuarioTipos.fetch().catchError((e) => log('Error starting usuarioTipos: $e')),
        usuarios.fetch().catchError((e) => log('Error starting usuarios: $e')),
        clientes.fetch().catchError((e) => log('Error starting clientes: $e')),
        bitolas.fetch().catchError((e) => log('Error starting bitolas: $e')),
        fabricantes.fetch().catchError((e) => log('Error starting fabricantes: $e')),
        formas.fetch().catchError((e) => log('Error starting formas: $e')),
        pedidosTecnicos.fetch().catchError((e) => log('Error starting pedidosTecnicos: $e')),
        demandas.fetch().catchError((e) => log('Error starting demandas: $e')),
      ]);
      await detalhamentos.fetch().catchError((e) => log('Error starting detalhamentos: $e'));

    } catch (e) {
      log('AppSupabaseClient: Critical error during init: $e');
    }
  }
}
