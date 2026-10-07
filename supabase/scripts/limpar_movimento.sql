-- =============================================================================
-- Limpa o MOVIMENTO e mantém apenas os CADASTROS.
--
-- Apaga:   demandas, etapas e histórico das demandas, detalhamentos
--          (elementos e posições) e pedidos técnicos (e seus elementos).
-- Mantém:  clientes, obras, fabricantes, bitolas, formas, usuários, perfis
--          e configurações.
-- Zera a numeração: a próxima demanda/detalhamento/pedido volta a ser 1.
--
-- NÃO tem volta. Rode o passo 1 primeiro para conferir o que será apagado.
-- =============================================================================

-- PASSO 1 — conferência (só leitura)
select 'demandas' as tabela, count(*) from public.demandas
union all select 'demanda_etapas', count(*) from public.demanda_etapas
union all select 'demanda_eventos', count(*) from public.demanda_eventos
union all select 'detalhamentos', count(*) from public.detalhamentos
union all select 'elementos', count(*) from public.elementos
union all select 'posicoes', count(*) from public.posicoes
union all select 'pedidos_tecnicos', count(*) from public.pedidos_tecnicos
union all select 'pedido_tecnico_elementos', count(*) from public.pedido_tecnico_elementos;

-- PASSO 2 — limpeza (selecione daqui até o "commit" e rode)
-- Sem CASCADE de propósito: se algum cadastro apontar para estas tabelas,
-- o comando falha e nada é apagado.
begin;

truncate table
  public.pedido_tecnico_elementos,
  public.pedidos_tecnicos,
  public.posicoes,
  public.elementos,
  public.demanda_etapas,
  public.demanda_eventos,
  public.detalhamentos,
  public.demandas;

select setval('public.demandas_codigo_seq', 1, false);
select setval('public.detalhamentos_codigo_seq', 1, false);
select setval('public.pedidos_tecnicos_codigo_seq', 1, false);

commit;
