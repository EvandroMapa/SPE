// import 'package:acoplan/app/core/client/models/cliente_model.dart';
// import 'package:acoplan/app/core/client/firestore/firestore_client.dart';
// import 'package:acoplan/app/core/components/app_field.dart';
// import 'package:acoplan/app/core/components/app_scaffold.dart';
// import 'package:acoplan/app/core/components/divisor.dart';
// import 'package:acoplan/app/core/components/empty_data.dart';
// import 'package:acoplan/app/core/components/stream_out.dart';
// import 'package:acoplan/app/core/utils/app_colors.dart';
// import 'package:acoplan/app/core/utils/app_css.dart';
// import 'package:acoplan/app/core/utils/global_resource.dart';
// import 'package:acoplan/app/modules/cliente/cliente_controller.dart';
// import 'package:acoplan/app/modules/cliente/cliente_view_model.dart';
// import 'package:acoplan/app/modules/cliente/ui/cliente_create_page.dart';
// import 'package:flutter/material.dart';

// class ObraSelectPage extends StatefulWidget {
//   const ObraSelectPage({super.key});

//   @override
//   State<ObraSelectPage> createState() => _ObraSelectPageState();
// }

// class _ObraSelectPageState extends State<ObraSelectPage> {
//   @override
//   Widget build(BuildContext context) {
//     return AppScaffold(
//       appBar: AppBar(
//         title: Text('Obraes', style: AppCss.largeBold.setColor(AppColors.white)),
//         actions: [
//           IconButton(
//               onPressed: () => push(context, const ObraCreatePage()),
//               icon: Icon(
//                 Icons.add,
//                 color: AppColors.white,
//               ))
//         ],
//         backgroundColor: AppColors.primaryMain,
//       ),
//       body: StreamOut<List<ObraModel>>(
//         stream: FirestoreClient.clientes.dataStream.listen,
//         child: (_, __) => StreamOut<ObraUtils>(
//           stream: clienteCtrl.utilsStream.listen,
//           child: (_, utils) {
//             final clientes = clienteCtrl.getObraesFiltered(utils.search.text, __).toList();
//             return Column(
//               children: [
//                 Padding(
//                   padding: const EdgeInsets.all(16),
//                   child: AppField(
//                     hint: 'Pesquisar',
//                     controller: utils.search,
//                     suffixIcon: Icons.search,
//                     onChanged: (_) => clienteCtrl.utilsStream.update(),
//                   ),
//                 ),
//                 Expanded(
//                   child: clientes.isEmpty
//                       ? const EmptyData()
//                       : ListView.separated(
//                           itemCount: clientes.length,
//                           separatorBuilder: (_, i) => const Divisor(),
//                           itemBuilder: (_, i) => _itemObraWidget(clientes[i]),
//                         ),
//                 ),
//               ],
//             );
//           },
//         ),
//       ),
//     );
//   }

//   ListTile _itemObraWidget(ObraModel cliente) {
//     return ListTile(
//       onTap: () => Navigator.pop(context, cliente),
//       contentPadding: const EdgeInsets.symmetric(horizontal: 16),
//       title: Text(
//         cliente.nome,
//         style: AppCss.mediumBold,
//       ),
//       subtitle: Text(
//         'Tel: ${cliente.telefone} - Endereço: ${cliente.endereco} - Qtd. Obras: ${cliente.obras.length}',
//       ),
//       trailing: Icon(
//         Icons.arrow_forward_ios,
//         size: 14,
//         color: AppColors.neutralMedium,
//       ),
//     );
//   }
// }
