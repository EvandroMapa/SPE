import 'package:flutter/foundation.dart';
import 'package:acoplan/app/core/models/service_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sf;

class SupabaseService implements Service {
  static const String _defaultUrl = 'https://kyatsdowjljkhivvdvzo.supabase.co';
  static const String _defaultAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt5YXRzZG93amxqa2hpdnZkdnpvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY5NzIyODcsImV4cCI6MjA5MjU0ODI4N30.l21LY_n5zwn-vt8mi0KpxCXN7PYplR7pI-G589InwY0';

  @override
  Future<void> initialize() async {
    const envUrl = String.fromEnvironment('SUPABASE_URL');
    const envKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    final url = envUrl.isNotEmpty ? envUrl : _defaultUrl;
    final anonKey = envKey.isNotEmpty ? envKey : _defaultAnonKey;

    try {
      await sf.Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );
      debugPrint('Supabase: Initialized successfully with URL: $url');
    } catch (e) {
      debugPrint('Supabase: Error during initialization: $e');
    }
  }

  static sf.SupabaseClient get client => sf.Supabase.instance.client;
}
