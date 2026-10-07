-- =============================================================================
-- SPE — Migração 05: etapas da demanda, áreas por perfil e trava do pedido
-- =============================================================================
-- Rodar ANTES de publicar a versão com Painel / Demandas / Detalhamentos /
-- Pedidos técnicos separados. Compatível com a versão atual do app.
--
-- Modelo:
--   Demanda (Kanban) → Etapas da demanda (Sapatas, Vigas baldrame...) →
--   Detalhamentos (cada um cobre 1 ou mais etapas; pode ganhar/perder etapas)
--   → Pedido técnico (só com a demanda em Finalizado / Liberado).
--
-- O que faz:
--   1. Tabela demanda_etapas (etapa → detalhamento que a cobre)
--   2. perfis.modulos: áreas que cada perfil enxerga (null = todas)
--   3. Trava: pedido técnico só se a demanda do detalhamento estiver em
--      Finalizado / Liberado (detalhamento sem demanda continua livre)
--   4. Desativa as regras de desfecho da migração 04 (orçamento/desistência e
--      "não voltar de coluna"). O histórico (demanda_eventos) continua.
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1. Etapas da demanda
-- -----------------------------------------------------------------------------
do $$
declare
  v_tipo_dem text;
  v_tipo_det text;
begin
  select format_type(a.atttypid, a.atttypmod) into v_tipo_dem
    from pg_attribute a where a.attrelid = 'public.demandas'::regclass and a.attname = 'id';
  select format_type(a.atttypid, a.atttypmod) into v_tipo_det
    from pg_attribute a where a.attrelid = 'public.detalhamentos'::regclass and a.attname = 'id';

  if to_regclass('public.demanda_etapas') is null then
    execute format($f$
      create table public.demanda_etapas (
        id              uuid primary key default gen_random_uuid(),
        demanda_id      %s not null references public.demandas(id) on delete cascade,
        nome            text not null,
        ordem           int not null default 0,
        detalhamento_id %s references public.detalhamentos(id) on delete set null,
        created_at      timestamptz not null default now()
      )$f$, v_tipo_dem, v_tipo_det);
  end if;
end;
$$;

create index if not exists demanda_etapas_demanda_idx on public.demanda_etapas (demanda_id, ordem);
create index if not exists demanda_etapas_detalhamento_idx on public.demanda_etapas (detalhamento_id);

alter table public.demanda_etapas enable row level security;
drop policy if exists spe_autenticados on public.demanda_etapas;
create policy spe_autenticados on public.demanda_etapas
  for all to authenticated using (true) with check (true);
revoke all on public.demanda_etapas from anon;
grant select, insert, update, delete on public.demanda_etapas to authenticated;

-- Histórico das etapas (criação, vínculo com detalhamento, exclusão)
create or replace function public.spe_historico_etapa()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    perform public.spe_registrar_evento(new.demanda_id::text, new.detalhamento_id::text, 'etapa_criada', null, new.nome, null);
  elsif tg_op = 'DELETE' then
    perform public.spe_registrar_evento(old.demanda_id::text, old.detalhamento_id::text, 'etapa_removida', old.nome, null, null);
    return old;
  elsif new.detalhamento_id is distinct from old.detalhamento_id then
    perform public.spe_registrar_evento(new.demanda_id::text, coalesce(new.detalhamento_id, old.detalhamento_id)::text,
      'etapa_vinculo', old.detalhamento_id::text, new.detalhamento_id::text, new.nome);
  end if;
  return new;
end;
$$;

drop trigger if exists spe_historico_etapa on public.demanda_etapas;
create trigger spe_historico_etapa after insert or update or delete on public.demanda_etapas
  for each row execute function public.spe_historico_etapa();

-- -----------------------------------------------------------------------------
-- 2. Áreas por perfil
-- -----------------------------------------------------------------------------
-- Lista de áreas (ex: ["painel","demandas","detalhamentos","pedidos"]).
-- null = todas (perfis existentes continuam vendo tudo).
alter table public.perfis add column if not exists modulos jsonb;

-- -----------------------------------------------------------------------------
-- 3. Trava do pedido técnico: demanda em Finalizado / Liberado
-- -----------------------------------------------------------------------------
drop trigger if exists spe_pedido_exige_projeto on public.pedidos_tecnicos;
drop function if exists public.spe_pedido_exige_projeto();

create or replace function public.spe_pedido_exige_demanda_liberada()
returns trigger
language plpgsql
as $$
declare
  v_etapa text;
begin
  select dm.etapa into v_etapa
    from public.detalhamentos d
    join public.demandas dm on dm.id::text = d.demanda_id::text
   where d.id::text = new.detalhamento_id::text;
  -- Detalhamento sem demanda (avulso/antigo): sem trava
  if v_etapa is not null and v_etapa <> 'finalizadoLiberado' then
    raise exception 'Pedido técnico só pode ser emitido com a demanda em Finalizado / Liberado.'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists spe_pedido_exige_demanda_liberada on public.pedidos_tecnicos;
create trigger spe_pedido_exige_demanda_liberada before insert on public.pedidos_tecnicos
  for each row execute function public.spe_pedido_exige_demanda_liberada();

-- -----------------------------------------------------------------------------
-- 4. Desativa as regras de desfecho da migração 04
-- -----------------------------------------------------------------------------
drop trigger if exists spe_regras_demanda on public.demandas;
drop trigger if exists spe_regras_detalhamento on public.detalhamentos;
-- Situação deixa de ser usada: tudo volta a ser detalhamento normal
update public.detalhamentos set situacao = 'projeto' where situacao <> 'projeto';

commit;
