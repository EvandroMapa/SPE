import 'package:acoplan/app/core/client/enums/user_permission_type.dart';
import 'package:acoplan/app/core/client/enums/usuario_role.dart';
import 'package:acoplan/app/core/client/models/usuario_model.dart';
import 'package:acoplan/app/core/client/models/usuario_permission_model.dart';
import 'package:acoplan/app/core/models/text_controller.dart';
import 'package:acoplan/app/core/services/hash_service.dart';

class UsuarioUtils {
  final TextController search = TextController();
}

class UsuarioCreateModel {
  final String id;
  TextController nome = TextController();
  TextController email = TextController();
  TextController senha = TextController();
  UsuarioPermissionCreateModel permission = UsuarioPermissionCreateModel();
  UsuarioRole? role;
  String usuarioTipoId = '';
  late bool isEdit;

  UsuarioCreateModel()
      : id = HashService.get,
        isEdit = false;

  UsuarioCreateModel.edit(UsuarioModel user)
      : id = user.id,
        isEdit = true {
    nome.text = user.nome;
    email.text = user.email;
    role = user.role;
    usuarioTipoId = user.usuarioTipoId;
    senha.text = user.senha;
    permission = UsuarioPermissionCreateModel.edit(user);
  }

  UsuarioModel toUsuarioModel() => UsuarioModel(
        id: id,
        nome: nome.text,
        email: email.text,
        role: role ?? UsuarioRole.operador,
        usuarioTipoId: usuarioTipoId,
        senha: senha.text,
        permission: permission.toUserPermissionModel(),
        deviceTokens: [],
      );
}

class UsuarioPermissionCreateModel {
  List<UserPermissionType> cliente = UserPermissionType.values.toList();
  List<UserPermissionType> pedido = UserPermissionType.values.toList();
  List<UserPermissionType> ordem = UserPermissionType.values.toList();

  UsuarioPermissionCreateModel();

  UsuarioPermissionCreateModel.edit(UsuarioModel user) {
    cliente = List<UserPermissionType>.from(user.permission.cliente);
    pedido = List<UserPermissionType>.from(user.permission.pedido);
    ordem = List<UserPermissionType>.from(user.permission.ordem);
  }

  UserPermissionModel toUserPermissionModel() =>
      UserPermissionModel(cliente: cliente, pedido: pedido, ordem: ordem);
}
