import 'package:acoplan/app/core/client/supabase/app_supabase_client.dart';
import 'package:acoplan/app/core/services/supabase_service.dart';

abstract class Service {
  Future<void> initialize();

  static bool isInitialized = false;
  static bool isCoreInitialized = false;

  static final List<Service> _coreServices = [
    SupabaseService(),
  ];

  /// Conecta ao Supabase — chamado antes do runApp (rápido)
  static Future<void> initCoreServices() async {
    if (isCoreInitialized) return;
    isCoreInitialized = true;
    for (final service in _coreServices) {
      await service.initialize();
    }
  }

  /// Carrega os dados (queries ao banco). Chamado depois que o usuário está
  /// autenticado — com RLS, antes do login o banco não retorna nada.
  /// Pode ser chamado de novo (ex: novo login) para recarregar tudo.
  static Future<void> initAplicationServices() async {
    if (!isCoreInitialized) await initCoreServices();
    isInitialized = true;

    await AppSupabaseClient.init();
  }
}
