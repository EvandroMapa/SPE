import 'package:acoplan/app/app_controller.dart';
import 'package:acoplan/app/core/components/app_scaffold.dart';
import 'package:acoplan/app/core/components/cadastro/cadastro_form.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/core/utils/app_env.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/backup/ui/backups_page.dart';
import 'package:acoplan/app/modules/config/config_gerais_page.dart';
import 'package:acoplan/app/modules/config/plugin_cad_page.dart';
import 'package:acoplan/app/modules/usuario/ui/usuario_tipo_page.dart';
import 'package:acoplan/app/modules/usuario/ui/usuarios_page.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configurações em grupos, no mesmo padrão do PCP.
class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  @override
  void initState() {
    setWebTitle('Configurações');
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: AppColors.neutralLightest,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Configurações', style: AppCss.largeBold.setSize(18).setColor(Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _grupo('Pessoas e acesso', [
                    _item(Symbols.group, 'Usuários', 'Quem entra no sistema, login e perfil de cada um',
                        () => push(context, const UsuariosPage())),
                    _item(Symbols.badge, 'Perfis de acesso', 'Tipos de usuário e o que cada um pode fazer',
                        () => push(context, const UsuarioTipoPage())),
                  ]),
                  _grupo('Integrações', [
                    _item(Symbols.auto_awesome, 'Inteligência artificial',
                        'Chave da API do Google Gemini usada no detalhamento por I.A.', _dialogChaveIA),
                    _item(Symbols.architecture, 'Plugin AutoCAD', 'Cor e marcação dos textos importados',
                        () => push(context, const PluginCadPage())),
                  ]),
                  _grupo('Sistema', [
                    _item(Symbols.tune, 'Configurações gerais', 'Orientação de impressão das etiquetas',
                        () => push(context, const ConfigGeraisPage())),
                    _item(Symbols.backup, 'Backup', 'Cópias de segurança dos dados',
                        () => push(context, const BackupsPage())),
                  ]),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      kVersaoLabel,
                      textAlign: TextAlign.center,
                      style: AppCss.minimumRegular.setSize(11.5).setColor(AppColors.neutralMedium),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _grupo(String titulo, List<Widget> itens) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              titulo.toUpperCase(),
              style: AppCss.minimumBold.setSize(11.5).setColor(AppColors.neutralMedium).copyWith(letterSpacing: 0.8),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.neutralLight),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (int i = 0; i < itens.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: AppColors.neutralLightest),
                  itens[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(IconData icon, String titulo, String descricao, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.neutralLightest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: AppColors.neutralDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: AppCss.minimumBold.setSize(14.5)),
                    const SizedBox(height: 2),
                    Text(descricao, style: AppCss.minimumRegular.setSize(12.5).setColor(AppColors.neutralMedium)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.neutralMedium),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _dialogChaveIA() async {
    final prefs = await SharedPreferences.getInstance();
    final controller = TextEditingController(text: prefs.getString('gemini_api_key') ?? '');
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        var oculta = true;
        return CadastroDialog(
          icon: Symbols.auto_awesome,
          titulo: 'Inteligência artificial',
          largura: 520,
          onSalvar: () async {
            final apiKey = controller.text.trim();
            await prefs.setString('gemini_api_key', apiKey);
            await appCtrl.saveGlobalApiKey(apiKey);
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          },
          child: StatefulBuilder(
            builder: (context, setLocal) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Chave da API do Google Gemini (AI Studio). É usada para ler os PDFs e DXFs '
                  'no detalhamento por I.A. e vale para todos os usuários.',
                  style: AppCss.minimumRegular.setSize(13).setColor(AppColors.neutralDark),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  obscureText: oculta,
                  decoration: InputDecoration(
                    labelText: 'Chave da API',
                    suffixIcon: IconButton(
                      tooltip: oculta ? 'Mostrar' : 'Esconder',
                      style: IconButton.styleFrom(backgroundColor: Colors.transparent),
                      icon: Icon(oculta ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: AppColors.neutralMedium),
                      onPressed: () => setLocal(() => oculta = !oculta),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
