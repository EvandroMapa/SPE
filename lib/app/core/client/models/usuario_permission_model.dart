import 'dart:convert';

import 'package:acoplan/app/core/client/enums/user_permission_type.dart';
import 'package:flutter/foundation.dart';

class UserPermissionModel {
  final List<UserPermissionType> cliente;
  final List<UserPermissionType> pedido;
  final List<UserPermissionType> ordem;

  UserPermissionModel({
    required this.cliente,
    required this.pedido,
    required this.ordem,
  });

  UserPermissionModel copyWith({
    List<UserPermissionType>? cliente,
    List<UserPermissionType>? pedido,
    List<UserPermissionType>? ordem,
  }) {
    return UserPermissionModel(
      cliente: cliente ?? this.cliente,
      pedido: pedido ?? this.pedido,
      ordem: ordem ?? this.ordem,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cliente': cliente.map((x) => x.index).toList(),
      'pedido': pedido.map((x) => x.index).toList(),
      'ordem': ordem.map((x) => x.index).toList(),
    };
  }

  factory UserPermissionModel.fromMap(Map<String, dynamic> map) {
    List<UserPermissionType> parseList(dynamic list) {
      if (list == null || list is! List) return [];
      return list
          .map((x) {
            if (x is int) return UserPermissionType.values[x];
            if (x is String) {
              final idx = int.tryParse(x);
              if (idx != null) return UserPermissionType.values[idx];
            }
            return null;
          })
          .whereType<UserPermissionType>()
          .toList();
    }

    return UserPermissionModel(
      cliente: parseList(map['cliente'] ?? map['clientes']),
      pedido: parseList(map['pedido'] ?? map['pedidos']),
      ordem: parseList(map['ordem'] ?? map['ordens']),
    );
  }

  factory UserPermissionModel.all() {
    return UserPermissionModel(
      cliente: UserPermissionType.values.toList(),
      pedido: UserPermissionType.values.toList(),
      ordem: UserPermissionType.values.toList(),
    );
  }

  String toJson() => json.encode(toMap());

  factory UserPermissionModel.fromJson(String source) =>
      UserPermissionModel.fromMap(json.decode(source));

  @override
  String toString() =>
      'UserPermissionModel(cliente: $cliente, pedido: $pedido, ordem: $ordem)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserPermissionModel &&
        listEquals(other.cliente, cliente) &&
        listEquals(other.pedido, pedido) &&
        listEquals(other.ordem, ordem);
  }

  @override
  int get hashCode => cliente.hashCode ^ pedido.hashCode ^ ordem.hashCode;
}
