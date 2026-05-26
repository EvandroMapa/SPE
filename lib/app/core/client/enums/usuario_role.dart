enum UsuarioRole {
  administrador,
  coordenador,
  detalhador,
  vendedor,
  cliente,
  operador,
}

extension UsuarioRoleExtension on UsuarioRole {
  String? get label {
    switch (this) {
      case UsuarioRole.administrador:
        return 'Administrador';
      case UsuarioRole.coordenador:
        return 'Coordenador';
      case UsuarioRole.detalhador:
        return 'Detalhador';
      case UsuarioRole.vendedor:
        return 'Vendedor';
      case UsuarioRole.cliente:
        return 'Cliente';
      case UsuarioRole.operador:
        return 'Operador';
    }
  }
}
