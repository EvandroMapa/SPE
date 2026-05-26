/// Modelo de resultado compartilhado entre ImportaPdf e ImportaDxf.
/// Ambos os caminhos de importação produzem este resultado.
enum TipoImportacao { pdf, dxf }

class ImportacaoResultado {
  final String jsonBruto;
  final int totalElementos;
  final List<String> avisos;
  final TipoImportacao tipo;

  ImportacaoResultado({
    required this.jsonBruto,
    required this.totalElementos,
    this.avisos = const [],
    required this.tipo,
  });
}
