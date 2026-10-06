# Migrações do banco (Supabase)

Os scripts ficam em `migrations/` e são executados **manualmente** no SQL Editor do
Supabase (projeto `kyatsdowjljkhivvdvzo`), **nesta ordem**. Todos podem ser executados
mais de uma vez sem efeito colateral.

| # | Script | Quando rodar | Quebra a versão antiga? |
|---|--------|--------------|-------------------------|
| 1 | `20261006_01_integridade.sql` | Antes de publicar o app novo | Não |
| 2 | `20261006_02_auth.sql` | Antes de publicar o app novo | Não |
| 3 | `20261006_03_rls.sql` | Depois que todos entrarem no app novo **e** o plugin novo estiver instalado | **Sim** (app e plugin antigos param) |

## Passo a passo

1. **Backup**: em *Database → Backups*, confirme que existe um backup recente (ou faça um dump).
2. Rode o **01** e o **02** no SQL Editor.
   - O 02 termina listando os usuários que **não** ganharam login (sem e-mail válido,
     e-mail duplicado ou sem senha). Defina a senha deles pela tela *Usuários* do app novo.
3. Publique o app novo (push na `main` → Vercel).
4. Teste: entre com um usuário existente (mesma senha de antes), crie/edite um
   detalhamento, gere um pedido técnico e imprima.
5. Instale o plugin novo do AutoCAD (`autocad-plugin/deploy.ps1` ou o instalador).
   Na primeira vez ele pede login (mesmo e-mail e senha do app).
6. Rode o **03**. A partir daqui a chave pública (`anon`) não dá mais acesso aos dados
   e a coluna de senha em texto puro é apagada.

## O que cada script faz

**01 – integridade**
- Código sequencial de detalhamento, pedido e demanda gerado pelo banco (sem duplicatas).
- Sequencial do identificador do pedido (`Prefixo.001`) por obra, com lock.
- `ON DELETE CASCADE` em elementos/posições/elementos do pedido; demanda é desvinculada
  (`SET NULL`) quando o detalhamento é excluído.
- RPC `salvar_pedido_tecnico`: grava pedido + elementos numa transação e valida o saldo
  de peças (não deixa a mesma peça ir para dois pedidos abertos).
- Coluna `pedido_tecnico_elementos.elemento_snapshot`: cópia do elemento no momento do
  pedido — reimprimir um pedido antigo gera o que foi produzido.
- Trigger que impede renomear/excluir/reduzir elemento com peças em pedido aberto
  (vale também para o plugin).
- Realtime para `elementos`, `posicoes` e `pedido_tecnico_elementos`.

**02 – auth**
- Cria um login no Supabase Auth para cada usuário, com a **mesma senha** (hash bcrypt).
- Liga `usuarios.auth_user_id` ao login.
- RPCs `definir_login_usuario` e `remover_login_usuario`, usadas pela tela de usuários.

**03 – rls**
- RLS em todas as tabelas de `public`: só usuários autenticados acessam.
- Remove os privilégios do papel `anon`.
- Bucket `backups` privado e restrito a autenticados.
- Apaga a coluna `usuarios.senha`.

## Depois do 03

- **Backups antigos** (`backups/*.json`) contêm as senhas em texto puro. Como as senhas
  continuam as mesmas, recomenda-se pedir que todos troquem a senha e apagar esses
  arquivos antigos.
- A chave do Gemini (`configuracoes`) passa a ser legível só por usuários autenticados.
- Qualquer usuário autenticado pode gerenciar usuários (como antes). Se quiser restringir
  a administradores, ajuste as RPCs do script 02.

## Testes

Os scripts foram testados com PGlite (Postgres 18; só usam recursos disponíveis desde o 15) sobre um schema reconstruído a partir
dos models do app, incluindo dados órfãos, equivalentes no formato antigo (string) e
execução repetida. Ainda assim, rode primeiro num projeto de teste (*branch* do Supabase)
se possível.
