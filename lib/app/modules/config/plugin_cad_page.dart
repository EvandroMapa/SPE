import 'package:acoplan/app/core/components/app_scaffold.dart';
import 'package:acoplan/app/core/services/notification_service.dart';
import 'package:acoplan/app/core/services/supabase_service.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:flutter/material.dart';

class PluginCadPage extends StatefulWidget {
  const PluginCadPage({super.key});

  @override
  State<PluginCadPage> createState() => _PluginCadPageState();
}

class _PluginCadPageState extends State<PluginCadPage> {
  bool _carregando = true;
  bool _salvando = false;

  // Cor do AutoCAD (index 0-255)
  int _corImportacao = 3; // verde padrão
  bool _marcarComX = true;

  // Cores AutoCAD mais usadas
  static const _coresAutoCad = <int, _CorCad>{
    1: _CorCad('Vermelho', Color(0xFFFF0000)),
    2: _CorCad('Amarelo', Color(0xFFFFFF00)),
    3: _CorCad('Verde', Color(0xFF00FF00)),
    4: _CorCad('Ciano', Color(0xFF00FFFF)),
    5: _CorCad('Azul', Color(0xFF0000FF)),
    6: _CorCad('Magenta', Color(0xFFFF00FF)),
    7: _CorCad('Branco', Color(0xFFFFFFFF)),
    8: _CorCad('Cinza escuro', Color(0xFF808080)),
    9: _CorCad('Cinza claro', Color(0xFFC0C0C0)),
    30: _CorCad('Laranja', Color(0xFFFF7F00)),
    40: _CorCad('Laranja claro', Color(0xFFFFBF00)),
    80: _CorCad('Verde oliva', Color(0xFF80FF00)),
    140: _CorCad('Azul claro', Color(0xFF00BFFF)),
    200: _CorCad('Roxo', Color(0xFF7F00FF)),
    210: _CorCad('Rosa', Color(0xFFFF007F)),
  };

  @override
  void initState() {
    super.initState();
    _carregarConfiguracoes();
  }

  Future<void> _carregarConfiguracoes() async {
    try {
      final rows = await SupabaseService.client
          .from('configuracoes')
          .select('chave, valor')
          .inFilter('chave', ['plugin_cad_cor_importacao', 'plugin_cad_marcar_x']);

      for (final r in rows) {
        final chave = r['chave'] as String;
        final valor = r['valor'] as String;
        if (chave == 'plugin_cad_cor_importacao') {
          _corImportacao = int.tryParse(valor) ?? 3;
        } else if (chave == 'plugin_cad_marcar_x') {
          _marcarComX = valor == 'true';
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _carregando = false);
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await SupabaseService.client.from('configuracoes').upsert({
        'chave': 'plugin_cad_cor_importacao',
        'valor': _corImportacao.toString(),
      });
      await SupabaseService.client.from('configuracoes').upsert({
        'chave': 'plugin_cad_marcar_x',
        'valor': _marcarComX.toString(),
      });
      NotificationService.showPositive(
        'Configurações salvas',
        'Plugin AutoCAD atualizado',
      );
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao salvar',
        e.toString(),
      );
    }
    if (mounted) setState(() => _salvando = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white, size: 20),
        backgroundColor: AppColors.primaryMain,
        title: Text('Plugin AutoCAD', style: AppCss.mediumBold.setColor(Colors.white)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _salvando
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : IconButton(
                    icon: const Icon(Icons.save_rounded, color: Colors.white),
                    tooltip: 'Salvar configurações',
                    onPressed: _salvar,
                  ),
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // ── Header ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C4A6E),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.architecture_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Plugin AutoCAD', style: AppCss.mediumBold.setColor(Colors.white)),
                        const SizedBox(height: 4),
                        Text(
                          'Configure como o plugin marca os elementos importados no desenho.',
                          style: AppCss.minimumRegular.setColor(Colors.white.withValues(alpha: 0.7)),
                        ),
                      ]),
                    ),
                  ]),
                ),

                const SizedBox(height: 32),

                // ── Seção 1: Cor de importação ──
                Text('Cor dos elementos importados', style: AppCss.smallBold),
                const SizedBox(height: 4),
                Text(
                  'Textos e marcações ficarão nesta cor após a importação.',
                  style: AppCss.minimumRegular.setColor(Colors.grey[500]!),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _coresAutoCad.entries.map((e) {
                    final selecionada = _corImportacao == e.key;
                    return Tooltip(
                      message: '${e.value.nome} (${e.key})',
                      preferBelow: false,
                      waitDuration: const Duration(milliseconds: 300),
                      child: InkWell(
                        onTap: () => setState(() => _corImportacao = e.key),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: e.value.cor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selecionada ? AppColors.primaryMain : Colors.grey[300]!,
                              width: selecionada ? 3 : 1,
                            ),
                            boxShadow: [
                              if (selecionada)
                                BoxShadow(
                                  color: e.value.cor.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                            ],
                          ),
                          child: selecionada
                              ? const Icon(Icons.check_rounded, color: Colors.black54, size: 22)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(children: [
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: _coresAutoCad[_corImportacao]?.cor ?? Colors.green,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Cor selecionada: ${_coresAutoCad[_corImportacao]?.nome ?? 'Índice $_corImportacao'} (AutoCAD: $_corImportacao)',
                      style: AppCss.minimumBold.setSize(13),
                    ),
                  ]),
                ),

                const SizedBox(height: 32),
                Divider(color: Colors.grey[200]),
                const SizedBox(height: 24),

                // ── Seção 2: Marcar com X ──
                Row(
                  children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Marcar área com X', style: AppCss.smallBold),
                        const SizedBox(height: 4),
                        Text(
                          'Desenha um X grande sobre a área selecionada após importação bem-sucedida.',
                          style: AppCss.minimumRegular.setColor(Colors.grey[500]!),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 16),
                    Switch.adaptive(
                      value: _marcarComX,
                      activeColor: AppColors.primaryMain,
                      onChanged: (v) => setState(() => _marcarComX = v),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Preview visual
                AnimatedOpacity(
                  opacity: _marcarComX ? 1.0 : 0.3,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: CustomPaint(
                      painter: _XPreviewPainter(
                        cor: _coresAutoCad[_corImportacao]?.cor ?? Colors.green,
                        mostrarX: _marcarComX,
                      ),
                      child: Center(
                        child: Text(
                          _marcarComX ? '✓ V101 importado' : 'Sem marcação X',
                          style: AppCss.minimumBold.setColor(
                            _marcarComX
                                ? (_coresAutoCad[_corImportacao]?.cor ?? Colors.green)
                                : Colors.grey[400]!,
                          ).setSize(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CorCad {
  final String nome;
  final Color cor;
  const _CorCad(this.nome, this.cor);
}

class _XPreviewPainter extends CustomPainter {
  final Color cor;
  final bool mostrarX;
  _XPreviewPainter({required this.cor, required this.mostrarX});

  @override
  void paint(Canvas canvas, Size size) {
    if (!mostrarX) return;
    final paint = Paint()
      ..color = cor.withValues(alpha: 0.4)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(16, 16),
      Offset(size.width - 16, size.height - 16),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - 16, 16),
      Offset(16, size.height - 16),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _XPreviewPainter old) =>
      old.cor != cor || old.mostrarX != mostrarX;
}
