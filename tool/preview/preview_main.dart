// Pré-visualização das telas com dados de exemplo, sem Supabase e sem login.
// Uso: flutter run -d web-server -t tool/preview/preview_main.dart
// e abrir http://localhost:<porta>/?tela=clientes (clientes, formas, bitolas,
// menu, bitola_form, config, usuarios, perfis, login).
import 'package:acoplan/app/app_controller.dart';
import 'package:acoplan/app/core/client/backend_client.dart';
import 'package:acoplan/app/core/client/enums/usuario_role.dart';
import 'package:acoplan/app/core/client/models/bitola_model.dart';
import 'package:acoplan/app/core/client/models/cliente_model.dart';
import 'package:acoplan/app/core/client/models/detalhamento_model.dart';
import 'package:acoplan/app/core/client/models/pedido_tecnico_model.dart';
import 'package:acoplan/app/core/client/models/forma_model.dart';
import 'package:acoplan/app/core/client/models/usuario_model.dart';
import 'package:acoplan/app/core/client/models/usuario_permission_model.dart';
import 'package:acoplan/app/core/client/models/usuario_tipo_model.dart';
import 'package:acoplan/app/core/components/drawer/app_drawer.dart';
import 'package:acoplan/app/core/enums/app_module.dart';
import 'package:acoplan/app/core/enums/obra_status.dart';
import 'package:acoplan/app/core/models/endereco_model.dart';
import 'package:acoplan/app/core/utils/app_theme.dart';
import 'package:acoplan/app/modules/base/base_controller.dart';
import 'package:acoplan/app/modules/base/base_page.dart';
import 'package:acoplan/app/modules/dashboard/models/demanda_model.dart';
import 'package:acoplan/app/modules/bitola/ui/bitola_create_page.dart';
import 'package:acoplan/app/modules/config/config_page.dart';
import 'package:acoplan/app/modules/sign/ui/sign_up_page.dart';
import 'package:acoplan/app/modules/usuario/ui/usuario_tipo_page.dart';
import 'package:acoplan/app/modules/usuario/ui/usuarios_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:overlay_support/overlay_support.dart';

ClienteModel _cliente(int cod, String nome, String cnpj, String tel, String cidade, int obras) {
  final end = EnderecoModel.empty()
    ..localidade = cidade
    ..estado = 'SC';
  return ClienteModel(
    id: 'c$cod',
    codigo: cod,
    nome: nome,
    telefone: tel,
    cnpj: cnpj,
    endereco: end,
    obras: [
      for (int i = 0; i < obras; i++)
        ObraModel(
            id: 'o$cod$i',
            identificador: '',
            descricao: 'Obra $i',
            telefoneFixo: '',
            prefixo: '',
            endereco: null,
            status: ObraStatus.emAndamento),
    ],
  );
}

FormaItemModel _t(String t, double c, double a) => FormaItemModel(trecho: t, comprimento: c, angulo: a, orientacao: 'Horário');

void _dadosDeExemplo() {
  final adm = UsuarioTipoModel(id: 'p1', nome: 'Administrador', isPermitirElementos: true, isPermitirEditarElementos: true, isOperador: false, isArmador: false, createdAt: DateTime(2026, 4, 23));
  final det = UsuarioTipoModel(id: 'p2', nome: 'Detalhista', isPermitirElementos: true, isPermitirEditarElementos: true, isOperador: false, isArmador: false, createdAt: DateTime(2026, 5, 2));
  BackendClient.usuarioTipos.dataStream.add([adm, det]);
  final eu = UsuarioModel(id: 'u1', nome: 'Evandro', email: 'evandromapa@gmail.com', senha: '', authUserId: 'a1', role: UsuarioRole.administrador, usuarioTipoId: 'p1', tipo: adm, permission: UserPermissionModel.all(), deviceTokens: []);
  BackendClient.usuarios.dataStream.add([
    eu,
    UsuarioModel(id: 'u2', nome: 'Carla Souza', email: 'carla@m2aco.com.br', senha: '', authUserId: 'a2', role: UsuarioRole.detalhador, usuarioTipoId: 'p2', tipo: det, permission: UserPermissionModel.all(), deviceTokens: []),
    UsuarioModel(id: 'u3', nome: 'teste', email: 'teste', senha: '', role: UsuarioRole.operador, usuarioTipoId: '', permission: UserPermissionModel.all(), deviceTokens: []),
  ]);
  appCtrl.usuarioStream.add(eu);

  BackendClient.clientes.dataStream.add([
    _cliente(12, 'Construtora Horizonte Ltda', '12.345.678/0001-90', '(47) 3333-1200', 'Joinville', 3),
    _cliente(11, 'Natália Xavier', '', '(47) 99812-4411', 'Jaraguá do Sul', 1),
    _cliente(10, 'Living Materiais', '98.765.432/0001-10', '', 'Blumenau', 0),
  ]);
  BackendClient.bitolas.dataStream.add([
    BitolaModel(id: 'b1', nome: '5.0', descricao: 'CA60 5.0 MM', massaFinal: 0.154, diametro: 5, codigoFinanceiro: '1005', sortIndex: 0),
    BitolaModel(id: 'b2', nome: '10.0', descricao: 'CA50 10.0 MM', massaFinal: 0.617, diametro: 10, codigoFinanceiro: '1010', sortIndex: 1),
    BitolaModel(id: 'b3', nome: '12.5', descricao: 'CA50 12.5 MM', massaFinal: 0.963, diametro: 12.5, sortIndex: 2),
  ]);
  BackendClient.formas.dataStream.add([
    FormaModel(id: 'f1', codigo: '1', descricao: 'Reta', imagem: '', itens: [_t('T1', 100, 0)], rotacao: 0),
    FormaModel(id: 'f2', codigo: '2', descricao: 'Estribo retangular', imagem: '', itens: [_t('T1', 30, 90), _t('T2', 15, 90), _t('T3', 30, 90), _t('T4', 15, 90), _t('T5', 5, 0)], rotacao: 0, fatorDobra: 4, descontoDobra: 8),
    FormaModel(id: 'f3', codigo: '3', descricao: 'Dobra em L', imagem: '', itens: [_t('T1', 80, 90), _t('T2', 20, 0)], rotacao: 0, fatorDobra: 1, descontoDobra: 2),
  ]);
}

void _dadosDashboard() {
  DemandaModel d(int cod, String cli, String obra, String etapaProj, DemandaEtapa etapa, {String prio = 'normal', String? det}) =>
      DemandaModel(
        id: 'd$cod', ordem: cod, codigo: cod, clienteId: 'c12', clienteNome: cli, obraId: 'o120', obraNome: obra,
        etapaProjeto: etapaProj, etapa: etapa, prioridade: prio, detalhamentoId: det,
        solicitanteComercial: 'Carlos (Comercial)', criadoPorNome: 'Evandro', criadoEm: DateTime(2026, 10, cod),
      );
  BackendClient.demandas.dataStream.add([
    d(1, 'Construtora Horizonte', 'Residencial Aurora', 'Fundações e blocos', DemandaEtapa.aguardandoFila, prio: 'urgente'),
    d(2, 'Natália Xavier', 'Casa Xavier', 'Vigas baldrame', DemandaEtapa.aguardandoFila),
    d(3, 'Living Materiais', 'Galpão Living', 'Pilares 1º pav.', DemandaEtapa.emProducao, prio: 'alta', det: 'det1'),
    d(4, 'Construtora Horizonte', 'Residencial Aurora', 'Lajes 2º pav.', DemandaEtapa.aguardandoCorrecao),
    d(5, 'Natália Xavier', 'Casa Xavier', 'Pilares', DemandaEtapa.finalizadoLiberado, det: 'det2'),
  ]);
  final b = BackendClient.bitolas.data;
  PosicaoModel pos(String n, int q, double c) => PosicaoModel(
      id: 'p$n$q', posicao: n, bitolaId: b[1].id, bitolaNome: '10.0 - CA50', formaId: 'f1', formaCodigo: '1', qtde: q, comprimentos: {'T1': c});
  BackendClient.detalhamentos.dataStream.add([
    DetalhamentoModel(id: 'det2', codigo: 42, clienteId: 'c11', clienteNome: 'Natália Xavier', obraId: 'o110', obraNome: 'Casa Xavier',
        desenho: 'E-03', pavimento: 'Pilares', demandaId: 'd5', funcionarioNome: 'Carla Souza', pesoTotal: 182.4,
        elementos: [ElementoModel(id: 'e1', nome: 'P1', quantidade: 4, pesoTotal: 0, posicoes: [pos('1', 4, 300), pos('2', 20, 110)])]),
    DetalhamentoModel(id: 'det1', codigo: 41, clienteId: 'c10', clienteNome: 'Living Materiais', obraId: 'o100', obraNome: 'Galpão Living',
        desenho: 'E-01', pavimento: 'Pilares 1º pav.', demandaId: 'd3', funcionarioNome: 'Evandro', pesoTotal: 1250.8, elementos: []),
  ]);
  BackendClient.pedidosTecnicos.dataStream.add([
    PedidoTecnicoModel(id: 'pt1', codigo: 7, identificador: 'Xavier-Casa.001', detalhamentoId: 'det2', detalhamentoCodigo: 42,
        clienteId: 'c11', clienteNome: 'Natália Xavier', obraId: 'o110', obraNome: 'Casa Xavier', status: 'aberto', observacao: '',
        criadoEm: DateTime(2026, 10, 5), resumoAco: {'peso_total': 182.4},
        elementos: [PedidoTecnicoElementoModel(id: 'x', pedidoId: 'pt1', elementoId: 'e1', elementoNome: 'P1', elementoQuantidade: 4, pesoTotal: 182.4)]),
  ]);
}

Widget _tela(String nome) {
  switch (nome) {
    case 'dashboard':
      _dadosDashboard();
      baseCtrl.setModule(AppModule.dashboard);
      return const BasePage();
    case 'clientes':
      baseCtrl.setModule(AppModule.cliente);
      return const BasePage();
    case 'formas':
      baseCtrl.setModule(AppModule.formas);
      return const BasePage();
    case 'bitolas':
      baseCtrl.setModule(AppModule.bitolas);
      return const BasePage();
    case 'menu':
      baseCtrl.setModule(AppModule.bitolas);
      return const Scaffold(body: Row(children: [AppDrawerMenu()]));
    case 'bitola_form':
      return BitolaCreatePage(produto: BackendClient.bitolas.data[1]);
    case 'config':
      return const ConfigPage();
    case 'usuarios':
      return const UsuariosPage();
    case 'perfis':
      return const UsuarioTipoPage();
    default:
      return const SignUpPage();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  _dadosDeExemplo();
  final nome = Uri.base.queryParameters['tela'] ?? 'login';
  runApp(OverlaySupport.global(
    child: MaterialApp(
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      navigatorKey: appCtrl.key,
      home: _tela(nome),
    ),
  ));
}
