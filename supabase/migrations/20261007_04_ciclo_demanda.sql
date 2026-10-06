-- =============================================================================
-- SPE — Migração 04: ciclo Demanda → Projeto
-- =============================================================================
-- Rodar ANTES de publicar a versão do app com o ciclo de demandas.
-- Compatível com a versão atual do app (só acrescenta colunas e regras).
--
-- Ciclo:
--   Planejamento (Kanban da demanda) — a planilha (detalhamento) nasce dentro
--   da demanda com situação 'planejamento'. Uma demanda pode ter várias.
--   Desfecho (demanda em Finalizado):
--     'projeto'     → planilhas viram projeto; a demanda trava (não volta de coluna)
--     'orcamento'   → planilhas viram orçamento (podem virar projeto depois)
--     'desistencia' → planilhas canceladas; demanda arquivada
--   Projeto: pode ser cancelado (cliente desistiu — pedidos técnicos abertos
--   são cancelados junto) ou arquivado. Nunca volta para o planejamento.
--
-- O que faz:
--   1. detalhamentos.situacao (+ liberação e cancelamento)
--   2. demandas.desfecho
--   3. Tabela demanda_eventos (histórico de tudo que acontece)
--   4. Regras no banco (triggers) — valem para o app e para o plugin
--   5. RPCs: definir_desfecho_demanda, converter_orcamento_em_projeto,
--      cancelar_projeto
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1 e 2. Colunas
-- -----------------------------------------------------------------------------
-- Detalhamentos existentes (e os criados por versões antigas/plugin) são 'projeto'.
alter table public.detalhamentos
  add column if not exists situacao text not null default 'projeto',
  add column if not exists liberado_em timestamptz,
  add column if not exists liberado_por text,
  add column if not exists cancelado_em timestamptz,
  add column if not exists cancelado_por text,
  add column if not exists motivo_cancelamento text;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'detalhamentos_situacao_check') then
    alter table public.detalhamentos add constraint detalhamentos_situacao_check
      check (situacao in ('planejamento', 'orcamento', 'projeto', 'cancelado'));
  end if;
end;
$$;

alter table public.demandas
  add column if not exists desfecho text,
  add column if not exists desfecho_em timestamptz,
  add column if not exists desfecho_por text,
  add column if not exists motivo_desfecho text;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'demandas_desfecho_check') then
    alter table public.demandas add constraint demandas_desfecho_check
      check (desfecho is null or desfecho in ('projeto', 'orcamento', 'desistencia'));
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
-- 3. Histórico
-- -----------------------------------------------------------------------------
create table if not exists public.demanda_eventos (
  id              uuid primary key default gen_random_uuid(),
  demanda_id      text,
  detalhamento_id text,
  tipo            text not null,   -- criada, etapa, desfecho, arquivada, desarquivada,
                                   -- planilha_criada, liberada, convertida, cancelada
  de              text,
  para            text,
  motivo          text,
  usuario_nome    text,
  criado_em       timestamptz not null default now()
);
create index if not exists demanda_eventos_demanda_idx on public.demanda_eventos (demanda_id, criado_em);
create index if not exists demanda_eventos_detalhamento_idx on public.demanda_eventos (detalhamento_id, criado_em);

alter table public.demanda_eventos enable row level security;
drop policy if exists spe_autenticados on public.demanda_eventos;
create policy spe_autenticados on public.demanda_eventos
  for all to authenticated using (true) with check (true);
revoke all on public.demanda_eventos from anon;
grant select, insert on public.demanda_eventos to authenticated;

-- Nome do usuário logado (para o histórico)
create or replace function public.spe_usuario_atual()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select u.nome from public.usuarios u where u.auth_user_id = auth.uid() limit 1),
    'sistema');
$$;

create or replace function public.spe_registrar_evento(
  p_demanda_id text, p_detalhamento_id text, p_tipo text,
  p_de text default null, p_para text default null, p_motivo text default null
) returns void
language sql
as $$
  insert into public.demanda_eventos (demanda_id, detalhamento_id, tipo, de, para, motivo, usuario_nome)
  values (p_demanda_id, p_detalhamento_id, p_tipo, p_de, p_para, nullif(trim(coalesce(p_motivo, '')), ''),
          public.spe_usuario_atual());
$$;

-- -----------------------------------------------------------------------------
-- 4. Regras
-- -----------------------------------------------------------------------------

-- Demanda: depois do desfecho 'projeto' não muda de etapa e o desfecho não é desfeito.
create or replace function public.spe_regras_demanda()
returns trigger
language plpgsql
as $$
begin
  if old.desfecho = 'projeto' then
    if new.etapa is distinct from old.etapa then
      raise exception 'Esta demanda já virou projeto e não pode mais mudar de coluna (só arquivar).'
        using errcode = 'P0001';
    end if;
    if new.desfecho is distinct from old.desfecho then
      raise exception 'O desfecho "projeto" não pode ser desfeito.' using errcode = 'P0001';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists spe_regras_demanda on public.demandas;
create trigger spe_regras_demanda before update on public.demandas
  for each row execute function public.spe_regras_demanda();

-- Histórico automático das demandas (criação, etapa, arquivamento)
create or replace function public.spe_historico_demanda()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    perform public.spe_registrar_evento(new.id::text, null, 'criada', null, new.etapa, null);
    return new;
  end if;
  if new.etapa is distinct from old.etapa then
    perform public.spe_registrar_evento(new.id::text, null, 'etapa', old.etapa, new.etapa,
      case when new.etapa = 'aguardandoCorrecao' then new.motivo_correcao end);
  end if;
  if new.is_arquivado is distinct from old.is_arquivado then
    perform public.spe_registrar_evento(new.id::text, null,
      case when new.is_arquivado then 'arquivada' else 'desarquivada' end, null, null, null);
  end if;
  return new;
end;
$$;

drop trigger if exists spe_historico_demanda on public.demandas;
create trigger spe_historico_demanda after insert or update on public.demandas
  for each row execute function public.spe_historico_demanda();

-- Detalhamento: projeto/orçamento/cancelado nunca volta para planejamento;
-- cancelado não volta a projeto.
create or replace function public.spe_regras_detalhamento()
returns trigger
language plpgsql
as $$
begin
  if new.situacao is distinct from old.situacao then
    if new.situacao = 'planejamento' then
      raise exception 'Um projeto ou orçamento não pode voltar para o planejamento.' using errcode = 'P0001';
    end if;
    if old.situacao = 'cancelado' then
      raise exception 'Projeto cancelado não pode ser reativado.' using errcode = 'P0001';
    end if;
    if old.situacao = 'projeto' and new.situacao = 'orcamento' then
      raise exception 'Um projeto não pode voltar a ser orçamento.' using errcode = 'P0001';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists spe_regras_detalhamento on public.detalhamentos;
create trigger spe_regras_detalhamento before update of situacao on public.detalhamentos
  for each row execute function public.spe_regras_detalhamento();

-- Pedido técnico só pode ser criado a partir de projeto liberado
create or replace function public.spe_pedido_exige_projeto()
returns trigger
language plpgsql
as $$
declare
  v_situacao text;
begin
  select d.situacao into v_situacao from public.detalhamentos d
   where d.id::text = new.detalhamento_id::text;
  if v_situacao is not null and v_situacao <> 'projeto' then
    raise exception 'Pedido técnico só pode ser emitido de projeto liberado (situação atual: %).', v_situacao
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists spe_pedido_exige_projeto on public.pedidos_tecnicos;
create trigger spe_pedido_exige_projeto before insert on public.pedidos_tecnicos
  for each row execute function public.spe_pedido_exige_projeto();

-- -----------------------------------------------------------------------------
-- 5. RPCs
-- -----------------------------------------------------------------------------

-- Desfecho da demanda (só em Finalizado e só uma vez — orçamento pode virar projeto).
create or replace function public.definir_desfecho_demanda(
  p_demanda_id text, p_desfecho text, p_motivo text default null
) returns void
language plpgsql
as $$
declare
  v_demanda   record;
  v_usuario   text := public.spe_usuario_atual();
  v_planilhas int;
  v_det       record;
begin
  if p_desfecho not in ('projeto', 'orcamento', 'desistencia') then
    raise exception 'Desfecho inválido: %', p_desfecho using errcode = 'P0001';
  end if;

  select * into v_demanda from public.demandas where id::text = p_demanda_id for update;
  if not found then
    raise exception 'Demanda não encontrada.' using errcode = 'P0001';
  end if;
  if v_demanda.etapa <> 'finalizadoLiberado' then
    raise exception 'O desfecho só pode ser definido com a demanda em Finalizado.' using errcode = 'P0001';
  end if;
  if v_demanda.desfecho = 'projeto' then
    raise exception 'Esta demanda já virou projeto.' using errcode = 'P0001';
  end if;
  if v_demanda.desfecho = 'desistencia' then
    raise exception 'Esta demanda foi encerrada por desistência.' using errcode = 'P0001';
  end if;
  if p_desfecho = 'desistencia' and coalesce(trim(p_motivo), '') = '' then
    raise exception 'Informe o motivo da desistência.' using errcode = 'P0001';
  end if;

  select count(*) into v_planilhas from public.detalhamentos
   where demanda_id::text = p_demanda_id and situacao in ('planejamento', 'orcamento');
  if p_desfecho in ('projeto', 'orcamento') and v_planilhas = 0 then
    raise exception 'A demanda não tem planilha (detalhamento) para virar %.',
      case p_desfecho when 'projeto' then 'projeto' else 'orçamento' end using errcode = 'P0001';
  end if;

  for v_det in
    select id, situacao from public.detalhamentos
     where demanda_id::text = p_demanda_id and situacao in ('planejamento', 'orcamento')
  loop
    if p_desfecho = 'projeto' then
      update public.detalhamentos
         set situacao = 'projeto', liberado_em = now(), liberado_por = v_usuario
       where id = v_det.id;
      perform public.spe_registrar_evento(p_demanda_id, v_det.id::text, 'liberada', v_det.situacao, 'projeto', p_motivo);
    elsif p_desfecho = 'orcamento' then
      if v_det.situacao = 'planejamento' then
        update public.detalhamentos set situacao = 'orcamento' where id = v_det.id;
      end if;
    else
      update public.detalhamentos
         set situacao = 'cancelado', cancelado_em = now(), cancelado_por = v_usuario,
             motivo_cancelamento = p_motivo
       where id = v_det.id;
    end if;
  end loop;

  update public.demandas
     set desfecho = p_desfecho, desfecho_em = now(), desfecho_por = v_usuario,
         motivo_desfecho = nullif(trim(coalesce(p_motivo, '')), ''),
         is_arquivado = case when p_desfecho = 'desistencia' then true else is_arquivado end
   where id = v_demanda.id;

  perform public.spe_registrar_evento(p_demanda_id, null, 'desfecho', v_demanda.desfecho, p_desfecho, p_motivo);
end;
$$;

-- Orçamento aprovado pelo cliente vira projeto (a demanda passa a 'projeto').
create or replace function public.converter_orcamento_em_projeto(p_detalhamento_id text)
returns void
language plpgsql
as $$
declare
  v_det     record;
  v_usuario text := public.spe_usuario_atual();
begin
  select * into v_det from public.detalhamentos where id::text = p_detalhamento_id for update;
  if not found then
    raise exception 'Projeto não encontrado.' using errcode = 'P0001';
  end if;
  if v_det.situacao <> 'orcamento' then
    raise exception 'Só orçamentos podem ser convertidos em projeto.' using errcode = 'P0001';
  end if;

  update public.detalhamentos
     set situacao = 'projeto', liberado_em = now(), liberado_por = v_usuario
   where id = v_det.id;

  if v_det.demanda_id is not null then
    update public.demandas
       set desfecho = 'projeto', desfecho_em = now(), desfecho_por = v_usuario
     where id::text = v_det.demanda_id::text and desfecho is distinct from 'projeto';
  end if;

  perform public.spe_registrar_evento(v_det.demanda_id::text, p_detalhamento_id, 'convertida', 'orcamento', 'projeto', null);
end;
$$;

-- Cliente desistiu: cancela o projeto e os pedidos técnicos abertos dele.
-- Retorna quantos pedidos foram cancelados.
create or replace function public.cancelar_projeto(p_detalhamento_id text, p_motivo text)
returns int
language plpgsql
as $$
declare
  v_det     record;
  v_usuario text := public.spe_usuario_atual();
  v_pedidos int;
begin
  if coalesce(trim(p_motivo), '') = '' then
    raise exception 'Informe o motivo do cancelamento.' using errcode = 'P0001';
  end if;
  select * into v_det from public.detalhamentos where id::text = p_detalhamento_id for update;
  if not found then
    raise exception 'Projeto não encontrado.' using errcode = 'P0001';
  end if;
  if v_det.situacao = 'cancelado' then
    raise exception 'Este projeto já está cancelado.' using errcode = 'P0001';
  end if;
  if v_det.situacao = 'planejamento' then
    raise exception 'Planilha em planejamento: encerre pela demanda (desistência).' using errcode = 'P0001';
  end if;

  update public.pedidos_tecnicos
     set status = 'cancelado'
   where detalhamento_id::text = p_detalhamento_id and status = 'aberto';
  get diagnostics v_pedidos = row_count;

  update public.detalhamentos
     set situacao = 'cancelado', cancelado_em = now(), cancelado_por = v_usuario,
         motivo_cancelamento = trim(p_motivo)
   where id = v_det.id;

  perform public.spe_registrar_evento(v_det.demanda_id::text, p_detalhamento_id, 'cancelada', v_det.situacao,
    'cancelado', trim(p_motivo) || case when v_pedidos > 0 then format(' (%s pedido(s) técnico(s) cancelado(s))', v_pedidos) else '' end);
  return v_pedidos;
end;
$$;

revoke execute on function public.definir_desfecho_demanda(text, text, text) from anon;
revoke execute on function public.converter_orcamento_em_projeto(text) from anon;
revoke execute on function public.cancelar_projeto(text, text) from anon;
revoke execute on function public.spe_registrar_evento(text, text, text, text, text, text) from anon;
grant execute on function public.definir_desfecho_demanda(text, text, text) to authenticated;
grant execute on function public.converter_orcamento_em_projeto(text) to authenticated;
grant execute on function public.cancelar_projeto(text, text) to authenticated;
grant execute on function public.spe_registrar_evento(text, text, text, text, text, text) to authenticated;

-- Sequências de código (migração 01): garante uso pelo app logado. No Supabase
-- isso costuma vir das permissões padrão, mas não depende delas.
grant usage, select on all sequences in schema public to authenticated;

-- Realtime do histórico
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables
                      where pubname = 'supabase_realtime' and schemaname = 'public'
                        and tablename = 'demanda_eventos') then
    alter publication supabase_realtime add table public.demanda_eventos;
  end if;
end;
$$;

commit;
