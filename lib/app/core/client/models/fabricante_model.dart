class FabricanteModel {
  final String id;
  final String nome;

  FabricanteModel({required this.id, required this.nome});

  static FabricanteModel empty() =>
      FabricanteModel(id: 'register_unavailable', nome: 'Sem Registro');

  factory FabricanteModel.fromSupabaseMap(Map<String, dynamic> map) {
    return FabricanteModel(
      id: map['id'] as String,
      nome: map['nome'] as String,
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    final map = <String, dynamic>{'nome': nome};
    if (id.length == 36) {
      map['id'] = id;
    }
    return map;
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'nome': nome};
  }
}
