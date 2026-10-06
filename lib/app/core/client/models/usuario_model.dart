import 'dart:convert';

import 'package:acoplan/app/core/client/enums/usuario_role.dart';
import 'package:acoplan/app/core/client/models/usuario_permission_model.dart';
import 'package:acoplan/app/core/client/models/usuario_tipo_model.dart';

class UsuarioModel {
  final String id;
  final String nome;
  final String email;
  /// Senha digitada no formulário. Nunca é lida nem gravada em public.usuarios:
  /// o login fica no Supabase Auth.
  final String senha;
  /// Id do login no Supabase Auth (auth.users).
  final String authUserId;
  final UsuarioRole role;
  final String usuarioTipoId;
  final UsuarioTipoModel? tipo;
  final UserPermissionModel permission;
  final List<String> deviceTokens;

  bool get isAdmin =>
      (tipo?.nome.toLowerCase() == 'administrador') ||
      role == UsuarioRole.administrador;

  bool get isOperador =>
      !isAdmin && (tipo?.isOperador ?? role == UsuarioRole.operador);
  bool get isArmador => !isAdmin && (tipo?.isArmador ?? false);
  bool get isNotOperador => isAdmin || (!isOperador && !isArmador);

  UsuarioModel({
    required this.id,
    required this.nome,
    required this.email,
    required this.senha,
    this.authUserId = '',
    required this.role,
    required this.usuarioTipoId,
    this.tipo,
    required this.permission,
    required this.deviceTokens,
  });

  UsuarioModel copyWith({
    String? id,
    String? nome,
    String? email,
    String? senha,
    String? authUserId,
    UsuarioRole? role,
    String? usuarioTipoId,
    UsuarioTipoModel? tipo,
    UserPermissionModel? permission,
    List<String>? deviceTokens,
  }) {
    return UsuarioModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      email: email ?? this.email,
      senha: senha ?? this.senha,
      authUserId: authUserId ?? this.authUserId,
      role: role ?? this.role,
      usuarioTipoId: usuarioTipoId ?? this.usuarioTipoId,
      tipo: tipo ?? this.tipo,
      permission: permission ?? this.permission,
      deviceTokens: deviceTokens ?? this.deviceTokens,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'email': email,
      'auth_user_id': authUserId,
      'role': role.index,
      'perfil_id': usuarioTipoId,
      'permission': permission.toMap(),
      'deviceTokens': deviceTokens,
    };
  }

  factory UsuarioModel.empty() => UsuarioModel(
        id: '',
        nome: '',
        email: '',
        senha: '',
        role: UsuarioRole.operador,
        usuarioTipoId: '',
        tipo: null,
        permission: UserPermissionModel.all(),
        deviceTokens: [],
      );

  factory UsuarioModel.fromMap(Map<String, dynamic> map) {
    return UsuarioModel(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      email: map['email'] ?? '',
      senha: map['senha'] ?? '',
      role: UsuarioRole.values[map['role'] is int ? map['role'] : 0],
      usuarioTipoId: (map['usuario_tipo_id'] ?? '').toString(),
      permission: map['permission'] != null
          ? UserPermissionModel.fromMap(map['permission'])
          : UserPermissionModel.all(),
      deviceTokens: map['deviceTokens'] != null
          ? List<String>.from(map['deviceTokens'])
          : [],
    );
  }

  factory UsuarioModel.fromSupabaseMap(Map<String, dynamic> map) {
    final tipo = map['perfis'] != null
        ? UsuarioTipoModel.fromSupabaseMap(map['perfis'])
        : null;

    final isAdmin = tipo?.nome.toLowerCase() == 'administrador' ||
        _parseRole(map['role']) == UsuarioRole.administrador;

    return UsuarioModel(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      email: map['email'] ?? '',
      senha: '',
      authUserId: (map['auth_user_id'] ?? '').toString(),
      role: _parseRole(map['role']),
      usuarioTipoId: (map['perfil_id'] ?? '').toString(),
      tipo: tipo,
      permission: isAdmin
          ? UserPermissionModel.all()
          : (map['permission'] != null
              ? UserPermissionModel.fromMap(map['permission'] is String
                  ? json.decode(map['permission'])
                  : map['permission'])
              : UserPermissionModel.all()),
      deviceTokens: map['deviceTokens'] != null
          ? List<String>.from(map['deviceTokens'] is String
              ? json.decode(map['deviceTokens'])
              : map['deviceTokens'])
          : [],
    );
  }

  static UsuarioRole _parseRole(dynamic role) {
    if (role is int) return UsuarioRole.values[role];
    if (role is String) {
      final idx = int.tryParse(role);
      if (idx != null) return UsuarioRole.values[idx];
      return UsuarioRole.values.firstWhere(
        (e) => e.name == role,
        orElse: () => UsuarioRole.operador,
      );
    }
    return UsuarioRole.operador;
  }

  Map<String, dynamic> toSupabaseMap() {
    final map = <String, dynamic>{
      'nome': nome,
      'email': email.trim().toLowerCase(),
      'role': role.index,
      'perfil_id': usuarioTipoId.isEmpty ? null : usuarioTipoId,
      'permission': json.encode(permission.toMap()),
      'deviceTokens': json.encode(deviceTokens),
    };
    if (authUserId.isNotEmpty) map['auth_user_id'] = authUserId;
    if (id.length == 36) {
      map['id'] = id;
    }
    return map;
  }

  String toJson() => json.encode(toMap());

  factory UsuarioModel.fromJson(String source) =>
      UsuarioModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'UsuarioModel(id: $id, nome: $nome, email: $email)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UsuarioModel &&
        other.id == id &&
        other.nome == nome &&
        other.email == email &&
        other.senha == senha &&
        other.role == role &&
        other.permission == permission;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        nome.hashCode ^
        email.hashCode ^
        senha.hashCode ^
        role.hashCode ^
        permission.hashCode;
  }
}
