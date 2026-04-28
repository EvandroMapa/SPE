import 'package:acoplan/app/core/client/supabase/app_supabase_client.dart';
import 'package:acoplan/app/core/client/supabase/cliente_supabase_collection.dart';
import 'package:acoplan/app/core/client/supabase/fabricante_supabase_collection.dart';
import 'package:acoplan/app/core/client/supabase/produto_supabase_collection.dart';
import 'package:acoplan/app/core/client/supabase/usuario_supabase_collection.dart';
import 'package:acoplan/app/core/client/supabase/usuario_tipo_supabase_collection.dart';
import 'package:acoplan/app/core/client/supabase/forma_supabase_collection.dart';
import 'package:acoplan/app/core/client/supabase/planilha_supabase_collection.dart';

class BackendClient {
  static UsuarioSupabaseCollection get usuarios => AppSupabaseClient.usuarios;
  static UsuarioTipoSupabaseCollection get usuarioTipos => AppSupabaseClient.usuarioTipos;
  static ClienteSupabaseCollection get clientes => AppSupabaseClient.clientes;
  static ProdutoSupabaseCollection get produtos => AppSupabaseClient.produtos;
  static FabricanteSupabaseCollection get fabricantes => AppSupabaseClient.fabricantes;
  static FormaSupabaseCollection get formas => AppSupabaseClient.formas;
  static PlanilhaSupabaseCollection get planilhas => AppSupabaseClient.planilhas;
}
