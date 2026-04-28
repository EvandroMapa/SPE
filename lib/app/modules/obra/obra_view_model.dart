import 'package:acoplan/app/core/client/models/cliente_model.dart';
import 'package:acoplan/app/core/enums/obra_status.dart';
import 'package:acoplan/app/core/models/endereco_model.dart';
import 'package:acoplan/app/core/models/text_controller.dart';
import 'package:acoplan/app/core/services/hash_service.dart';

class ObraUtils {
  final TextController search = TextController();
}

class ObraCreateModel {
  final String id;
  TextController identificador = TextController();
  TextController descricao = TextController();
  TextController telefoneFixo = TextController.phone();
  EnderecoModel? endereco;
  ObraStatus? status = ObraStatus.emAndamento;
  late bool isEdit;

  ObraCreateModel()
      : id = HashService.get,
        isEdit = false;

  ObraCreateModel.edit(ObraModel obra)
      : id = obra.id,
        isEdit = true {
    identificador.text = obra.identificador;
    descricao.text = obra.descricao;
    endereco = obra.endereco;
    status = obra.status;
  }

  ObraModel toObraModel() => ObraModel(
        id: id,
        identificador: identificador.text.trim(),
        descricao: descricao.text,
        endereco: endereco,
        status: status!,
        telefoneFixo: telefoneFixo.text,
      );
}
