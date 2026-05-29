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
  TextController descricao = TextController();
  TextController telefoneFixo = TextController.phone();
  TextController prefixo = TextController();
  EnderecoModel? endereco;
  ObraStatus? status = ObraStatus.emAndamento;
  late bool isEdit;

  ObraCreateModel()
      : id = HashService.get,
        isEdit = false;

  ObraCreateModel.edit(ObraModel obra)
      : id = obra.id,
        isEdit = true {
    descricao.text = obra.descricao;
    telefoneFixo.text = obra.telefoneFixo;
    prefixo.text = obra.prefixo;
    endereco = obra.endereco;
    status = obra.status;
  }

  ObraModel toObraModel() => ObraModel(
        id: id,
        identificador: '',
        descricao: descricao.text,
        prefixo: prefixo.text.trim(),
        endereco: endereco,
        status: status!,
        telefoneFixo: telefoneFixo.text,
      );
}
