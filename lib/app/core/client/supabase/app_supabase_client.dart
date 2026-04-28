import 'dart:developer';
import 'package:acoplan/app/core/client/supabase/cliente_supabase_collection.dart';
import 'package:acoplan/app/core/client/supabase/fabricante_supabase_collection.dart';
import 'package:acoplan/app/core/client/supabase/produto_supabase_collection.dart';
import 'package:acoplan/app/core/client/supabase/usuario_supabase_collection.dart';
import 'package:acoplan/app/core/client/supabase/usuario_tipo_supabase_collection.dart';
import 'package:acoplan/app/core/client/supabase/forma_supabase_collection.dart';
import 'package:acoplan/app/core/client/supabase/planilha_supabase_collection.dart';


class AppSupabaseClient {
  static UsuarioSupabaseCollection usuarios = UsuarioSupabaseCollection();
  static UsuarioTipoSupabaseCollection usuarioTipos = UsuarioTipoSupabaseCollection();
  static ClienteSupabaseCollection clientes = ClienteSupabaseCollection();
  static ProdutoSupabaseCollection produtos = ProdutoSupabaseCollection();
  static FabricanteSupabaseCollection fabricantes = FabricanteSupabaseCollection();
  static FormaSupabaseCollection formas = FormaSupabaseCollection();
  static PlanilhaSupabaseCollection planilhas = PlanilhaSupabaseCollection();


  static Future<void> init() async {
    try {
      // 1. Realtime primeiro
      usuarioTipos.listen();
      usuarios.listen();
      clientes.listen();
      produtos.listen();
      fabricantes.listen();
      formas.listen();
      planilhas.listen();


      // 2. Fetches sequenciais (dados iniciais)
      await usuarioTipos.start().catchError((e) => log('Error starting usuarioTipos: $e'));
      await usuarios.start().catchError((e) => log('Error starting usuarios: $e'));
      await clientes.start().catchError((e) => log('Error starting clientes: $e'));
      await produtos.start().catchError((e) => log('Error starting produtos: $e'));
      await fabricantes.start().catchError((e) => log('Error starting fabricantes: $e'));
      await formas.start().catchError((e) => log('Error starting formas: $e'));
      await planilhas.start().catchError((e) => log('Error starting planilhas: $e'));

    } catch (e) {
      log('AppSupabaseClient: Critical error during init: $e');
    }
  }
}
