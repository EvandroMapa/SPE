import 'dart:developer';
import 'package:acoplan/app/core/client/models/cliente_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/supabase_service.dart';

class ClienteSupabaseCollection {
  static final ClienteSupabaseCollection _instance = ClienteSupabaseCollection._();
  ClienteSupabaseCollection._() { dataStream = AppStream.seed([]); }
  factory ClienteSupabaseCollection() => _instance;

  late final AppStream<List<ClienteModel>> dataStream;
  final String name = 'clientes';
  List<ClienteModel> get data => dataStream.value;
  bool _isStarted = false;

  Future<void> fetch() async { _isStarted = false; await start(lock: false); _isStarted = true; }

  Future<void> start({bool lock = true}) async {
    if (_isStarted && lock) return;
    _isStarted = true;
    try {
      final response = await SupabaseService.client.from(name).select('*, obras(*)');
      final items = List<Map<String, dynamic>>.from(response).map((e) {
        final obrasList = List<Map<String, dynamic>>.from(e['obras'] ?? []);
        return ClienteModel.fromSupabaseMap(e, obrasList);
      }).toList();
      dataStream.add(items);
    } catch (e) { log('Supabase Error (Cliente.start): $e'); }
  }

  bool _isListen = false;
  Future<void> listen() async {
    if (_isListen) return; _isListen = true;
    SupabaseService.client.from(name).stream(primaryKey: ['id']).listen((data) {
      // Nota: stream() do Supabase não suporta left joins complexos (*, obras(*)).
      // O listen acionará o update para clientes, e fetch cuidará das obras se precisarmos.
      // Aqui faremos um fetch manual apenas para puxar os relacionamentos também.
      fetch();
    });
  }

  Future<ClienteModel?> add(ClienteModel model) async {
    // Calcula o próximo código sequencial
    final proximoCodigo = data.isEmpty 
        ? 1 
        : data.map((c) => c.codigo).reduce((a, b) => a > b ? a : b) + 1;
    final modelComCodigo = model.copyWith(codigo: proximoCodigo);

    final insertedCliente = await SupabaseService.client.from(name).insert(modelComCodigo.toSupabaseMap()).select().single(); 
    final insertedClienteId = insertedCliente['id'] as String;

    if (modelComCodigo.obras.isNotEmpty) {
      // Obras novas não têm UUID (id de 36 chars) — deixar o banco gerar
      final obrasMaps = modelComCodigo.obras.map((o) {
        final map = o.toSupabaseMap(insertedClienteId);
        map.remove('id'); // banco gera com gen_random_uuid()
        return map;
      }).toList();
      await SupabaseService.client.from('obras').insert(obrasMaps);
    }

    await fetch(); 
    return modelComCodigo; 
  }

  Future<ClienteModel?> update(ClienteModel model) async {
    await SupabaseService.client.from(name).update(model.toSupabaseMap()).eq('id', model.id); 
    
    final currentObrasUUIDs = model.obras.where((e) => e.id.length == 36).map((e) => e.id).toList();
    if (currentObrasUUIDs.isEmpty) {
      await SupabaseService.client.from('obras').delete().eq('cliente_id', model.id);
    } else {
      await SupabaseService.client.from('obras').delete().eq('cliente_id', model.id).not('id', 'in', currentObrasUUIDs);
    }
    
    if (model.obras.isNotEmpty) {
      // Separar obras existentes (UUID válido) de novas
      final obrasExistentes = model.obras.where((o) => o.id.length == 36).toList();
      final obrasNovas = model.obras.where((o) => o.id.length != 36).toList();

      if (obrasExistentes.isNotEmpty) {
        final mapas = obrasExistentes.map((o) => o.toSupabaseMap(model.id)).toList();
        await SupabaseService.client.from('obras').upsert(mapas);
      }

      if (obrasNovas.isNotEmpty) {
        final mapas = obrasNovas.map((o) {
          final map = o.toSupabaseMap(model.id);
          map.remove('id'); // banco gera com gen_random_uuid()
          return map;
        }).toList();
        await SupabaseService.client.from('obras').insert(mapas);
      }
    }

    await fetch(); 
    return model; 
  }

  Future<void> delete(ClienteModel model) async {
    try { await SupabaseService.client.from(name).delete().eq('id', model.id); await fetch(); }
    catch (e) { log('Supabase Error (Cliente.delete): $e'); }
  }
}
