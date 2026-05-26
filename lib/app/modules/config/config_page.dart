import 'package:acoplan/app/app_controller.dart';
import 'package:acoplan/app/core/components/app_scaffold.dart';
import 'package:acoplan/app/core/components/divisor.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/usuario/ui/usuario_tipo_page.dart';
import 'package:acoplan/app/modules/usuario/ui/usuarios_page.dart';
import 'package:acoplan/app/modules/backup/ui/backups_page.dart';
import 'package:acoplan/app/modules/config/plugin_cad_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConfigPage extends StatelessWidget {
  const ConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white, size: 20),
        backgroundColor: AppColors.primaryMain,
        title: Text(
          'Configurações',
          style: AppCss.mediumBold.setColor(Colors.white),
        ),
      ),
      body: ListView(
        children: [
          _buildItem(
            context,
            Icons.people_outline_rounded,
            'Usuários',
            'Gerencie os usuários do sistema',
            () => push(context, const UsuariosPage()),
          ),
          const Divisor(),
          _buildItem(
            context,
            Icons.admin_panel_settings_outlined,
            'Perfis de Acesso',
            'Defina permissões para cada perfil',
            () => push(context, const UsuarioTipoPage()),
          ),
          const Divisor(),
          _buildItem(
            context,
            Icons.backup_outlined,
            'Backup',
            'Exportação e segurança dos dados',
            () {
              push(context, const BackupsPage());
            },
          ),
          const Divisor(),
          _buildItem(
            context,
            Icons.auto_awesome_outlined,
            'Inteligência Artificial (IA)',
            'Chaves de API e integrações',
            () {
              _showApiKeyDialog(context);
            },
          ),
          const Divisor(),
          _buildItem(
            context,
            Icons.settings_suggest_outlined,
            'Configurações Gerais',
            'Parâmetros globais do sistema',
            () {
              // Placeholder
            },
          ),
          const Divisor(),
          _buildItem(
            context,
            Icons.architecture_rounded,
            'Plugin AutoCAD',
            'Cores e marcações de importação',
            () => push(context, const PluginCadPage()),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryMain.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primaryMain, size: 24),
      ),
      title: Text(title, style: AppCss.smallBold),
      subtitle: Text(subtitle, style: AppCss.minimumRegular.setColor(AppColors.neutralDark)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  void _showApiKeyDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final currentKey = prefs.getString('gemini_api_key') ?? '';
    final controller = TextEditingController(text: currentKey);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Configuração da IA', style: AppCss.mediumBold),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Informe sua chave da API do Google Gemini (AI Studio). Ela será usada para processar os PDFs de projetos no robô de detalhamento.',
                style: AppCss.minimumRegular.setColor(Colors.grey[700]!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: AppCss.smallBold.setColor(Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final apiKey = controller.text.trim();
                await prefs.setString('gemini_api_key', apiKey);
                await appCtrl.saveGlobalApiKey(apiKey);

                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryMain),
              child: Text('Salvar', style: AppCss.smallBold.setColor(Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
