import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/components/app_scaffold.dart';
import 'package:acoplan/app/core/components/empty_data.dart';
import 'package:acoplan/app/core/components/stream_out.dart';
import 'package:acoplan/app/core/client/models/cliente_model.dart';
import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:acoplan/app/modules/cliente/cliente_controller.dart';
import 'package:acoplan/app/modules/cliente/ui/cliente_create_page.dart';
import 'package:flutter/material.dart';

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = '';

  // Ordenação
  String _ordenarPor = 'codigo'; // 'codigo' | 'nome' | 'obras'
  bool _ordenarAsc = false;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white, size: 20),
        backgroundColor: AppColors.primaryMain,
        title: Text('Clientes', style: AppCss.mediumBold.setColor(Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _openForm(null),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Busca ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _filter = val),
              decoration: InputDecoration(
                hintText: 'Buscar por nome, CNPJ ou telefone...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _filter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _filter = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          // ── Chips de ordenação ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ordenarChip('Código', 'codigo', Icons.tag),
                  const SizedBox(width: 6),
                  _ordenarChip('Nome', 'nome', Icons.person_outline),
                  const SizedBox(width: 6),
                  _ordenarChip('Obras', 'obras', Icons.construction_outlined),
                ],
              ),
            ),
          ),
          // ── Lista ──
          Expanded(
            child: StreamOut<List<ClienteModel>>(
              stream: clienteCtrl.clientesStream.listen,
              builder: (context, clientes) {
                // Filtrar
                var filtered = clientes.where((c) {
                  final query = _filter.toLowerCase();
                  return c.nome.toLowerCase().contains(query) ||
                      c.cnpj.contains(query) ||
                      c.telefone.contains(query) ||
                      c.codigo.toString().contains(query);
                }).toList();

                // Ordenar
                filtered.sort((a, b) {
                  int cmp;
                  switch (_ordenarPor) {
                    case 'nome':
                      cmp = a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
                      break;
                    case 'obras':
                      cmp = a.obras.length.compareTo(b.obras.length);
                      break;
                    default: // codigo
                      cmp = a.codigo.compareTo(b.codigo);
                  }
                  return _ordenarAsc ? cmp : -cmp;
                });

                if (filtered.isEmpty) {
                  return const EmptyData(message: 'Nenhum cliente encontrado');
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final cliente = filtered[index];
                    return _ClienteCard(
                      cliente: cliente,
                      onEditar: () => _openForm(cliente),
                      onExcluir: () => _confirmDelete(cliente),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _ordenarChip(String label, String campo, IconData icone) {
    final selecionado = _ordenarPor == campo;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_ordenarPor == campo) {
            _ordenarAsc = !_ordenarAsc;
          } else {
            _ordenarPor = campo;
            _ordenarAsc = campo == 'nome'; // texto = asc, números = desc
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selecionado
              ? AppColors.primaryMain.withValues(alpha: 0.10)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selecionado
                ? AppColors.primaryMain.withValues(alpha: 0.40)
                : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone,
                size: 13,
                color: selecionado ? AppColors.primaryMain : Colors.grey[500]),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppCss.minimumBold.setSize(12).setColor(
                    selecionado ? AppColors.primaryMain : Colors.grey[600]!,
                  ),
            ),
            if (selecionado) ...[
              const SizedBox(width: 3),
              Icon(
                _ordenarAsc ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: AppColors.primaryMain,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openForm(ClienteModel? cliente) async {
    await push(context, ClienteCreatePage(cliente: cliente));
  }

  void _confirmDelete(ClienteModel cliente) {
    // Verificar se alguma obra do cliente tem projeto vinculado
    final obrasIds = cliente.obras.map((o) => o.id).toSet();
    final obrasComProjeto = BackendClient.detalhamentos.data
        .where((d) => obrasIds.contains(d.obraId))
        .toList();

    if (obrasComProjeto.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(Icons.info_outline, size: 40, color: Colors.orange[700]),
          title: Text('Exclusão Bloqueada', textAlign: TextAlign.center, style: AppCss.mediumBold),
          content: Text(
            'Este cliente não pode ser excluído pois possui obras com projetos (detalhamentos) vinculados.\n\nExclua os projetos antes de excluir o cliente.',
            style: AppCss.smallRegular,
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryMain),
              onPressed: () => Navigator.pop(context),
              child: Text('Entendi', style: AppCss.smallBold.setColor(Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Cliente'),
        content: Text('Deseja realmente excluir o cliente ${cliente.nome}?'),
        actions: [
          TextButton(onPressed: () => pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              pop(context);
              clienteCtrl.onDelete(context, cliente);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Card do cliente na lista
// ─────────────────────────────────────────────────────────────
class _ClienteCard extends StatelessWidget {
  final ClienteModel cliente;
  final VoidCallback onEditar;
  final VoidCallback onExcluir;

  const _ClienteCard({
    required this.cliente,
    required this.onEditar,
    required this.onExcluir,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryMain.withValues(alpha: 0.15),
                AppColors.primaryMain.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              cliente.codigo.toString(),
              style: AppCss.smallBold
                  .setColor(AppColors.primaryMain)
                  .setSize(15),
            ),
          ),
        ),
        title: Text(
          cliente.nome,
          style: AppCss.smallBold.setSize(14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            if (cliente.cnpj.isNotEmpty || cliente.telefone.isNotEmpty)
              Text(
                [
                  if (cliente.cnpj.isNotEmpty) cliente.cnpj,
                  if (cliente.telefone.isNotEmpty) cliente.telefone,
                ].join(' • '),
                style: AppCss.minimumRegular.setColor(Colors.grey[600]!).setSize(12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 3),
            Row(children: [
              Icon(Icons.construction_outlined, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                '${cliente.obras.length} obra(s)',
                style: AppCss.minimumBold.setColor(Colors.grey[600]!).setSize(11),
              ),
            ]),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: 'Editar',
              child: InkWell(
                onTap: onEditar,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryMain.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.edit_outlined,
                      size: 18, color: AppColors.primaryMain),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Excluir',
              child: InkWell(
                onTap: onExcluir,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.delete_outline,
                      size: 18, color: AppColors.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
