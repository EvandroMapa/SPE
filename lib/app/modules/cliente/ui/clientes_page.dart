import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/models/cliente_model.dart';
import 'package:acoplan/app/core/components/cadastro/cadastro_lista.dart';
import 'package:acoplan/app/core/components/empty_data.dart';
import 'package:acoplan/app/core/components/stream_out.dart';
import 'package:acoplan/app/core/models/text_controller.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/base/base_controller.dart';
import 'package:acoplan/app/modules/cliente/cliente_controller.dart';
import 'package:acoplan/app/modules/cliente/ui/cliente_create_page.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

enum _Ordem { codigo, nome, obras }

class _ClientesPageState extends State<ClientesPage> {
  final TextController _busca = TextController();
  _Ordem _ordem = _Ordem.codigo;

  @override
  void initState() {
    super.initState();
    setWebTitle('Clientes');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      baseCtrl.appBarActionsStream.add([
        CadastroBotaoNovo('Novo cliente', onTap: () => _abrir(null)),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamOut<List<ClienteModel>>(
      stream: clienteCtrl.clientesStream.listen,
      builder: (context, todos) {
        final q = _busca.text.trim().toLowerCase();
        final clientes = todos.where((c) {
          if (q.isEmpty) return true;
          return c.nome.toLowerCase().contains(q) ||
              c.cnpj.contains(q) ||
              c.telefone.contains(q) ||
              c.codigo.toString() == q ||
              c.obras.any((o) => o.descricao.toLowerCase().contains(q));
        }).toList()
          ..sort((a, b) => switch (_ordem) {
                _Ordem.nome => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()),
                _Ordem.obras => b.obras.length.compareTo(a.obras.length),
                _Ordem.codigo => b.codigo.compareTo(a.codigo),
              });

        return Container(
          color: AppColors.neutralLightest,
          child: Column(
            children: [
              CadastroBusca(
                hint: 'Buscar por nome, CNPJ, telefone ou obra',
                controller: _busca,
                contador: clientes.length == 1 ? '1 cliente' : '${clientes.length} clientes',
                onChanged: () => setState(() {}),
                acoes: [_menuOrdem()],
              ),
              Expanded(
                child: clientes.isEmpty
                    ? EmptyData(message: q.isEmpty ? 'Nenhum cliente cadastrado' : 'Nenhum cliente encontrado')
                    : CadastroLista(
                        onRefresh: () => BackendClient.clientes.fetch(),
                        itens: clientes.map(_linha).toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _menuOrdem() {
    const rotulos = {
      _Ordem.codigo: 'Mais recentes',
      _Ordem.nome: 'Nome (A-Z)',
      _Ordem.obras: 'Mais obras',
    };
    return PopupMenuButton<_Ordem>(
      tooltip: 'Ordenar',
      position: PopupMenuPosition.under,
      color: Colors.white,
      initialValue: _ordem,
      onSelected: (o) => setState(() => _ordem = o),
      itemBuilder: (_) => [
        for (final e in rotulos.entries) PopupMenuItem(value: e.key, child: Text(e.value)),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.neutralLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort, size: 18, color: AppColors.neutralDark),
            const SizedBox(width: 6),
            Text(rotulos[_ordem]!, style: AppCss.minimumBold.setSize(12.5).setColor(AppColors.neutralDark)),
          ],
        ),
      ),
    );
  }

  Widget _linha(ClienteModel cliente) {
    final cidade = [cliente.endereco.localidade, cliente.endereco.estado]
        .where((e) => e.trim().isNotEmpty)
        .join(' / ');
    final obras = cliente.obras.length;
    return CadastroLinha(
      onTap: () => _abrir(cliente),
      leading: const CadastroIcone(Symbols.person),
      titulo: cliente.nome,
      selos: [CadastroSelo('Cód. ${cliente.codigo}')],
      pares: [
        ('CNPJ/CPF', cliente.cnpj),
        ('Telefone', cliente.telefone),
        ('Cidade', cidade),
        ('Obras', obras == 0 ? 'nenhuma' : '$obras'),
      ],
      // Excluir no menu, longe de um clique acidental
      trailing: CadastroMenu([
        CadastroAcao(Icons.edit_outlined, 'Editar cliente', () => _abrir(cliente)),
        CadastroAcao(Icons.delete_outline, 'Excluir cliente', () => _excluir(cliente), destrutiva: true),
      ]),
    );
  }

  void _abrir(ClienteModel? cliente) => push(context, ClienteCreatePage(cliente: cliente));

  void _excluir(ClienteModel cliente) {
    // Cliente com obra que tem projeto (detalhamento) não pode ser excluído
    final obrasIds = cliente.obras.map((o) => o.id).toSet();
    final temProjeto = BackendClient.detalhamentos.data.any((d) => obrasIds.contains(d.obraId));

    if (temProjeto) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          icon: Icon(Icons.info_outline, size: 40, color: AppColors.statusAtencao),
          title: Text('Exclusão bloqueada', textAlign: TextAlign.center, style: AppCss.mediumBold),
          content: Text(
            'Este cliente tem obras com projetos (detalhamentos) vinculados.\n\n'
            'Exclua os projetos antes de excluir o cliente.',
            style: AppCss.smallRegular,
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primaryMain),
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Excluir cliente', style: AppCss.largeBold),
        content: Text('Deseja realmente excluir o cliente ${cliente.nome}?'),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.neutralDark,
              side: BorderSide(color: AppColors.neutralLight),
            ),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(dialogContext);
              clienteCtrl.onDelete(context, cliente);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}
