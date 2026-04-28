
import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/forma_model.dart';
import 'package:acoplan/app/core/models/app_stream.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/forma/forma_view_model.dart';
import 'package:flutter/material.dart';

final formaCtrl = FormaController();

class FormaController {
  static final FormaController _instance = FormaController._();
  FormaController._();
  factory FormaController() => _instance;

  final AppStream<List<FormaModel>> formasStream =
      BackendClient.formas.dataStream;
  List<FormaModel> get formas => formasStream.value;

  final AppStream<FormaCriarModel> formularioStream =
      AppStream<FormaCriarModel>();
  FormaCriarModel get formulario => formularioStream.value;

  // Rotação base do desenho (em graus), controlada pelos botões ↻/↺
  double rotacaoDesenho = 0;

  void rotacionarDesenho(double graus) {
    rotacaoDesenho = (rotacaoDesenho + graus) % 360;
    formulario.rotacao = rotacaoDesenho;
    formularioStream.update();
  }

  // Visibilidade das legendas T1, T2...
  bool mostrarLegenda = true;

  void toggleLegenda() {
    mostrarLegenda = !mostrarLegenda;
    formularioStream.update();
  }

  void inicializar(FormaModel? forma) {
    if (forma != null) {
      final f = FormaCriarModel.editar(forma);
      rotacaoDesenho = f.rotacao;
      formularioStream.add(f);
    } else {
      rotacaoDesenho = 0;
      final novoForm = FormaCriarModel();
      // Sugerir o último número cadastrado + 1
      int maiorCodigo = 0;
      for (var f in formas) {
        final cod = int.tryParse(f.codigo) ?? 0;
        if (cod > maiorCodigo) maiorCodigo = cod;
      }
      novoForm.codigo.text = (maiorCodigo + 1).toString();
      formularioStream.add(novoForm);
    }
  }

  Future<void> confirmar(BuildContext context) async {
    try {
      if (formulario.codigo.text.isEmpty || formulario.descricao.text.isEmpty) {
        throw Exception('Código e descrição são obrigatórios');
      }

      // Validação de duplicidade
      final codigoJaExiste = formas.any((f) => 
        f.codigo == formulario.codigo.text && f.id != formulario.id
      );
      if (codigoJaExiste) {
        int maiorCodigo = 0;
        for (var f in formas) {
          final cod = int.tryParse(f.codigo) ?? 0;
          if (cod > maiorCodigo) maiorCodigo = cod;
        }
        throw Exception('Já existe uma forma com o código ${formulario.codigo.text}. O próximo disponível é ${maiorCodigo + 1}');
      }

      if (formulario.is_edicao) {
        await BackendClient.formas.update(formulario.toFormaModel());
      } else {
        await BackendClient.formas.add(formulario.toFormaModel());
      }

      if (!context.mounted) return;
      pop(context);
      NotificationService.showPositive(
        'Forma ${formulario.is_edicao ? 'Editada' : 'Adicionada'}',
        'Operação realizada com sucesso',
      );
    } catch (e) {
      NotificationService.showNegative('Erro ao salvar', e.toString());
    }
  }

  Future<void> excluir(BuildContext context, FormaModel forma) async {
    try {
      await BackendClient.formas.delete(forma);
      NotificationService.showPositive('Forma Excluída', '');
    } catch (e) {
      NotificationService.showNegative('Erro ao excluir', e.toString());
    }
  }

  void adicionarItem() {
    // Zera o ângulo do último trecho antes de adicionar o próximo.
    // Esse campo só tem sentido quando o próximo trecho já foi posicionado.
    if (formulario.itens.isNotEmpty) {
      formulario.itens.last.angulo = 0;
      formulario.itens.last.orientacao = 'Horário';
    }
    final proximoN = formulario.itens.length + 1;
    final novoItem = FormaItemModel(
      trecho: 'T$proximoN',
      comprimento: 100,
      angulo: 0,
      orientacao: 'Horário',
    );
    formulario.itens.add(novoItem);
    formularioStream.update();

    // Dar foco no campo de ângulo do novo item
    Future.delayed(const Duration(milliseconds: 100), () {
      novoItem.focusNode.requestFocus();
    });
  }

  void adicionarItemDoCanvas(double anguloRelativo, String orientacaoParam) {
    if (formulario.itens.isNotEmpty) {
      formulario.itens.last.angulo = anguloRelativo;
      formulario.itens.last.orientacao = orientacaoParam;
    }
    final proximoN = formulario.itens.length + 1;
    formulario.itens.add(FormaItemModel(
      trecho: 'T$proximoN',
      comprimento: 150,
      angulo: 0,
      orientacao: 'Horário',
    ));
    formularioStream.update();
  }

  void removerItem(int index) {
    formulario.itens.removeAt(index);
    // Renumera em ordem numérica absoluta: T1, T2, T10...
    for (var i = 0; i < formulario.itens.length; i++) {
      formulario.itens[i].trecho = 'T${i + 1}';
    }
    formularioStream.update();
  }

  /// Substitui o desenho atual por um círculo especial.
  /// O diâmetro é representado por um único trecho do tipo 'circulo'.
  void adicionarCirculo() {
    if (formulario.itens.isNotEmpty) {
      NotificationService.showNegative(
        'Forma Especial',
        'Limpe o desenho antes de inserir um círculo.',
      );
      return;
    }
    rotacaoDesenho = 0;
    formulario.itens.add(FormaItemModel(
      trecho: 'T1',
      comprimento: 60,
      angulo: 0,
      orientacao: 'Horário',
      tipo: 'circulo',
    ));
    formularioStream.update();
  }

  void limparDesenho() {
    formulario.itens.clear();
    rotacaoDesenho = 0;
    formularioStream.update();
  }

}
