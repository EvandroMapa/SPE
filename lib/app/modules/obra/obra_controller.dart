import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/cliente_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/models/endereco_model.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:acoplan/app/core/services/supabase_service.dart';
import 'package:acoplan/app/modules/obra/obra_view_model.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

final obraCtrl = ObraController();

class ObraController {
  static final ObraController _instance = ObraController._();

  ObraController._();

  factory ObraController() => _instance;

  final AppStream<ObraCreateModel> formStream = AppStream<ObraCreateModel>();
  ObraCreateModel get form => formStream.value;

  /// Obras irmãs (do mesmo cliente) para validação local de duplicidade
  List<ObraModel> _obrasIrmas = [];

  /// ID do cliente pai (UUID = já existe no banco; outro = cliente novo)
  String? _clienteId;

  void init(
    ObraModel? obra,
    EnderecoModel? enderecoModel, {
    List<ObraModel> obrasIrmas = const [],
    String? clienteId,
  }) {
    _obrasIrmas = obrasIrmas;
    _clienteId = clienteId;
    formStream.add(
      obra != null ? ObraCreateModel.edit(obra) : ObraCreateModel(),
    );
    if (!form.isEdit) {
      form.endereco = enderecoModel;
      formStream.update();
    }
  }

  Future<void> onConfirm(value) async {
    try {
      onValid();

      final obra = formStream.value.toObraModel();

      // Cliente já existe no banco → salva obra diretamente no Supabase
      if (_clienteId != null && _clienteId!.length == 36) {
        ObraModel salva;
        if (form.isEdit) {
          // Atualiza obra existente
          final map = obra.toSupabaseMap(_clienteId!);
          await SupabaseService.client.from('obras').upsert(map);
          salva = obra;
        } else {
          // Insere nova obra e pega o UUID gerado pelo banco
          final map = obra.toSupabaseMap(_clienteId!);
          map.remove('id'); // banco gera com gen_random_uuid()
          final inserted = await SupabaseService.client
              .from('obras')
              .insert(map)
              .select()
              .single();
          salva = ObraModel.fromSupabaseMap(inserted);
        }
        // Atualiza o cache local
        await BackendClient.clientes.fetch();
        Navigator.pop(value, salva);
      } else {
        // Cliente ainda não salvo → apenas retorna o modelo local
        Navigator.pop(value, obra);
      }

      NotificationService.showPositive(
        'Obra ${form.isEdit ? 'Editada' : 'Adicionada'}',
        'Salvo com sucesso',
        position: NotificationPosition.bottom,
      );
    } catch (e) {
      NotificationService.showNegative(
        'Erro',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }

  void onValid() {
    if (form.descricao.text.length < 2) {
      throw Exception('Descrição deve conter no mínimo 3 caracteres');
    }
    if (form.status == null) {
      throw Exception('Selecione um status para a obra');
    }

    // Validação do prefixo
    final prefixo = form.prefixo.text.trim();
    if (prefixo.isEmpty) {
      throw Exception('Prefixo da obra é obrigatório (ex: Cliente-Obra)');
    }
    if (prefixo.length > 20) {
      throw Exception('Prefixo deve ter no máximo 20 caracteres');
    }
    if (!RegExp(r'^[\w\-\.]+$').hasMatch(prefixo)) {
      throw Exception('Prefixo deve conter apenas letras, números, hífen e ponto');
    }

    // Verifica duplicidade do prefixo em todas as obras do sistema
    final todasObras = BackendClient.clientes.data
        .expand((c) => c.obras)
        .toList()
      ..addAll(_obrasIrmas);

    final duplicadaPrefixo = todasObras.any((o) =>
        o.prefixo.trim().toLowerCase() == prefixo.toLowerCase() &&
        o.id != form.id);
    if (duplicadaPrefixo) {
      throw Exception('Já existe uma obra com o prefixo "$prefixo"');
    }
  }
}
