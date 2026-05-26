import 'dart:developer';
import 'package:acoplan/app/core/client/supabase/cliente_supabase_collection.dart';
import 'package:acoplan/app/core/client/supabase/fabricante_supabase_collection.dart';
import 'package:acoplan/app/core/client/supabase/bitola_supabase_collection.dart';
import 'package:acoplan/app/core/client/supabase/usuario_supabase_collection.dart';
import 'package:acoplan/app/core/client/supabase/usuario_tipo_supabase_collection.dart';
import 'package:acoplan/app/core/client/supabase/forma_supabase_collection.dart';
import 'package:acoplan/app/core/client/supabase/detalhamento_supabase_collection.dart';
import 'package:acoplan/app/core/client/supabase/pedido_tecnico_supabase_collection.dart';


class AppSupabaseClient {
  static UsuarioSupabaseCollection usuarios = UsuarioSupabaseCollection();
  static UsuarioTipoSupabaseCollection usuarioTipos = UsuarioTipoSupabaseCollection();
  static ClienteSupabaseCollection clientes = ClienteSupabaseCollection();
  static BitolaSupabaseCollection bitolas = BitolaSupabaseCollection();
  static FabricanteSupabaseCollection fabricantes = FabricanteSupabaseCollection();
  static FormaSupabaseCollection formas = FormaSupabaseCollection();
  static DetalhamentoSupabaseCollection detalhamentos = DetalhamentoSupabaseCollection();
  static PedidoTecnicoSupabaseCollection pedidosTecnicos = PedidoTecnicoSupabaseCollection();


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


      // 2. Fetches sequenciais (dados iniciais)
      await usuarioTipos.start().catchError((e) => log('Error starting usuarioTipos: $e'));
      await usuarios.start().catchError((e) => log('Error starting usuarios: $e'));
      await clientes.start().catchError((e) => log('Error starting clientes: $e'));
      await bitolas.start().catchError((e) => log('Error starting bitolas: $e'));
      await fabricantes.start().catchError((e) => log('Error starting fabricantes: $e'));
      await formas.start().catchError((e) => log('Error starting formas: $e'));
      await detalhamentos.start().catchError((e) => log('Error starting detalhamentos: $e'));
      await pedidosTecnicos.start().catchError((e) => log('Error starting pedidosTecnicos: $e'));

    } catch (e) {
      log('AppSupabaseClient: Critical error during init: $e');
    }
  }
}
