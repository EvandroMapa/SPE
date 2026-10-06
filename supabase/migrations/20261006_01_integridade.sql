-- =============================================================================
-- SPE — Migração 01: integridade de dados
-- =============================================================================
-- Pode ser executada com a versão ANTIGA do app em produção (é compatível).
-- Rodar no SQL Editor do Supabase ANTES de publicar a nova versão do app.
--
-- O que faz:
--   1. Códigos sequenciais (detalhamento, pedido, demanda) gerados no banco,
--      eliminando duplicatas quando dois usuários salvam ao mesmo tempo.
--   2. Sequencial do identificador do pedido por obra (Prefixo.001) no banco.
--   3. Chaves estrangeiras com ON DELETE CASCADE / SET NULL (exclusões atômicas).
--   4. Coluna elemento_snapshot em pedido_tecnico_elementos (histórico do pedido).
--   5. RPC salvar_pedido_tecnico: grava pedido + elementos numa única transação
--      e valida o saldo de peças (impede alocar a mesma peça em dois pedidos).
--   6. Trigger que impede renomear/excluir/reduzir elementos que estão em
--      pedido técnico aberto (proteção também contra o plugin do AutoCAD).
--   7. Realtime para elementos, posições e elementos de pedido.
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1. Códigos sequenciais gerados no banco
-- -----------------------------------------------------------------------------
-- O trigger SEMPRE sobrescreve o código enviado pelo cliente: versões antigas
-- do app e do plugin calculam "max + 1" localmente, o que gera duplicatas.

create sequence if not exists public.detalhamentos_codigo_seq;
create sequence if not exists public.pedidos_tecnicos_codigo_seq;
create sequence if not exists public.demandas_codigo_seq;

select setval('public.detalhamentos_codigo_seq',
              greatest(coalesce((select max(codigo) from public.detalhamentos), 0), 1),
              (select count(*) > 0 from public.detalhamentos));
select setval('public.pedidos_tecnicos_codigo_seq',
              greatest(coalesce((select max(codigo) from public.pedidos_tecnicos), 0), 1),
              (select count(*) > 0 from public.pedidos_tecnicos));
select setval('public.demandas_codigo_seq',
              greatest(coalesce((select max(codigo) from public.demandas), 0), 1),
              (select count(*) > 0 from public.demandas));

create or replace function public.spe_atribuir_codigo()
returns trigger
language plpgsql
as $$
begin
  new.codigo := nextval(tg_argv[0]::regclass);
  return new;
end;
$$;

drop trigger if exists spe_codigo on public.detalhamentos;
create trigger spe_codigo before insert on public.detalhamentos
  for each row execute function public.spe_atribuir_codigo('public.detalhamentos_codigo_seq');

drop trigger if exists spe_codigo on public.pedidos_tecnicos;
create trigger spe_codigo before insert on public.pedidos_tecnicos
  for each row execute function public.spe_atribuir_codigo('public.pedidos_tecnicos_codigo_seq');

drop trigger if exists spe_codigo on public.demandas;
create trigger spe_codigo before insert on public.demandas
  for each row execute function public.spe_atribuir_codigo('public.demandas_codigo_seq');

-- -----------------------------------------------------------------------------
-- 2. Identificador do pedido: "<prefixo>.<NNN>" sequencial por obra
-- -----------------------------------------------------------------------------
-- O cliente envia "<prefixo>.qualquer-coisa"; o banco calcula o NNN com lock
-- por obra, então dois pedidos simultâneos da mesma obra nunca colidem.

create or replace function public.spe_identificador_pedido()
returns trigger
language plpgsql
as $$
declare
  v_prefixo text;
  v_seq     int;
begin
  v_prefixo := split_part(coalesce(new.identificador, ''), '.', 1);
  perform pg_advisory_xact_lock(hashtext('spe_pedido_obra:' || coalesce(new.obra_id::text, '')));

  select coalesce(max((substring(p.identificador from '\.(\d+)$'))::int), 0) + 1
    into v_seq
    from public.pedidos_tecnicos p
   where p.obra_id is not distinct from new.obra_id;

  new.identificador := v_prefixo || '.' || lpad(v_seq::text, 3, '0');
  return new;
end;
$$;

drop trigger if exists spe_identificador on public.pedidos_tecnicos;
create trigger spe_identificador before insert on public.pedidos_tecnicos
  for each row execute function public.spe_identificador_pedido();

-- -----------------------------------------------------------------------------
-- 3. Chaves estrangeiras com ação de exclusão
-- -----------------------------------------------------------------------------
-- Recria a FK de (tabela.coluna -> pai.id) com a ação desejada. Se os tipos
-- forem incompatíveis, apenas avisa. NOT VALID: não falha por registros órfãos
-- antigos (gerados pelas exclusões não atômicas do app antigo), mas vale para
-- todas as operações daqui em diante.

create or replace function public.spe_definir_fk(
  p_tabela text, p_coluna text, p_pai text, p_acao text
) returns void
language plpgsql
as $$
declare
  v_con      record;
  v_tipo_col regtype;
  v_tipo_pai regtype;
  v_nome     text := p_tabela || '_' || p_coluna || '_fkey';
begin
  select a.atttypid::regtype into v_tipo_col
    from pg_attribute a
   where a.attrelid = ('public.' || p_tabela)::regclass and a.attname = p_coluna and not a.attisdropped;
  select a.atttypid::regtype into v_tipo_pai
    from pg_attribute a
   where a.attrelid = ('public.' || p_pai)::regclass and a.attname = 'id' and not a.attisdropped;

  if v_tipo_col is null or v_tipo_pai is null then
    raise notice 'SPE: %.% ou %.id não existe — FK ignorada', p_tabela, p_coluna, p_pai;
    return;
  end if;
  if v_tipo_col <> v_tipo_pai then
    raise notice 'SPE: tipos diferentes em %.% (%) e %.id (%) — FK ignorada',
      p_tabela, p_coluna, v_tipo_col, p_pai, v_tipo_pai;
    return;
  end if;

  for v_con in
    select c.conname
      from pg_constraint c
      join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any (c.conkey)
     where c.contype = 'f'
       and c.conrelid = ('public.' || p_tabela)::regclass
       and c.confrelid = ('public.' || p_pai)::regclass
       and a.attname = p_coluna
  loop
    execute format('alter table public.%I drop constraint %I', p_tabela, v_con.conname);
  end loop;

  execute format(
    'alter table public.%I add constraint %I foreign key (%I) references public.%I(id) on delete %s not valid',
    p_tabela, v_nome, p_coluna, p_pai, p_acao);
end;
$$;

select public.spe_definir_fk('posicoes',                 'elemento_id',    'elementos',        'cascade');
select public.spe_definir_fk('elementos',                'detalhamento_id','detalhamentos',    'cascade');
select public.spe_definir_fk('pedido_tecnico_elementos', 'pedido_id',      'pedidos_tecnicos', 'cascade');
select public.spe_definir_fk('demandas',                 'detalhamento_id','detalhamentos',    'set null');

drop function public.spe_definir_fk(text, text, text, text);

-- -----------------------------------------------------------------------------
-- 4. Snapshot do elemento no pedido
-- -----------------------------------------------------------------------------
-- Cópia do elemento (com posições) no momento em que o pedido foi salvo.
-- Reimprimir um pedido antigo gera exatamente o que foi produzido, mesmo que
-- o detalhamento tenha sido editado depois.

alter table public.pedido_tecnico_elementos
  add column if not exists elemento_snapshot jsonb;

-- -----------------------------------------------------------------------------
-- Funções auxiliares de saldo
-- -----------------------------------------------------------------------------

-- Quantidade total de um nome (pai ou equivalente) dentro do elemento.
create or replace function public.spe_qtde_nome_elemento(p_elemento_id text, p_nome text)
returns int
language sql
stable
as $$
  select case
    when el.nome = p_nome then el.quantidade
    else (
      select case
               when jsonb_typeof(eq) = 'object'
                 then coalesce(nullif(eq->>'quantidade', '')::numeric::int, el.quantidade)
               else el.quantidade
             end
        from jsonb_array_elements(coalesce(to_jsonb(el.elementos_equivalentes), '[]'::jsonb)) eq
       where (case when jsonb_typeof(eq) = 'object' then eq->>'nome' else eq #>> '{}' end) = p_nome
       limit 1
    )
  end
  from public.elementos el
  where el.id::text = p_elemento_id;
$$;

-- -----------------------------------------------------------------------------
-- 5. RPC: salvar pedido técnico de forma atômica
-- -----------------------------------------------------------------------------
-- p_pedido:    mapa do pedido (mesmas chaves de PedidoTecnicoModel.toSupabaseMap)
--              com "id" quando for edição.
-- p_elementos: lista de mapas de pedido_tecnico_elementos (sem pedido_id).
-- Retorna o pedido gravado com a lista "pedido_tecnico_elementos".

create or replace function public.salvar_pedido_tecnico(p_pedido jsonb, p_elementos jsonb)
returns jsonb
language plpgsql
as $$
declare
  v_id          uuid := nullif(p_pedido->>'id', '')::uuid;
  v_existe      boolean := false;
  v_status      text;
  v_cols        text;
  v_dados       jsonb;
  v_elem        jsonb;
  v_elemento_id text;
  v_nome        text;
  v_solicitada  int;
  v_anterior    int;
  v_outros      int;
  v_total       int;
  v_lista       jsonb;
  v_resultado   jsonb;
begin
  if p_elementos is null or jsonb_typeof(p_elementos) <> 'array' then
    p_elementos := '[]'::jsonb;
  end if;

  -- Serializa gravações de pedidos do mesmo detalhamento (validação de saldo).
  perform pg_advisory_xact_lock(hashtext('spe_pedido_det:' || coalesce(p_pedido->>'detalhamento_id', '')));

  if v_id is not null then
    select true, p.status into v_existe, v_status from public.pedidos_tecnicos p where p.id::text = v_id::text;
    v_existe := coalesce(v_existe, false);
  end if;
  v_status := coalesce(p_pedido->>'status', v_status, 'aberto');

  -- Validação de saldo (apenas pedidos abertos consomem peças)
  if v_status = 'aberto' then
    for v_elem in select * from jsonb_array_elements(p_elementos) loop
      v_elemento_id := v_elem->>'elemento_id';
      v_nome        := v_elem->>'elemento_nome';
      v_solicitada  := coalesce(nullif(v_elem->>'quantidade_solicitada', '')::numeric::int, 0);

      select coalesce(sum(pe.quantidade_solicitada), 0) into v_anterior
        from public.pedido_tecnico_elementos pe
       where pe.pedido_id::text = v_id::text and pe.elemento_id::text = v_elemento_id and pe.elemento_nome = v_nome;

      -- Só valida quando a quantidade aumenta (não trava edição de pedidos antigos)
      if v_solicitada > v_anterior then
        select coalesce(sum(pe.quantidade_solicitada), 0) into v_outros
          from public.pedido_tecnico_elementos pe
          join public.pedidos_tecnicos p on p.id = pe.pedido_id
         where p.status = 'aberto'
           and p.id::text is distinct from v_id::text
           and pe.elemento_id::text = v_elemento_id
           and pe.elemento_nome = v_nome;

        v_total := coalesce(public.spe_qtde_nome_elemento(v_elemento_id, v_nome), 0);

        if v_outros + v_solicitada > v_total then
          raise exception 'Saldo insuficiente para %: disponível %, solicitado %.',
            v_nome, greatest(v_total - v_outros, 0), v_solicitada
            using errcode = 'P0001';
        end if;
      end if;
    end loop;
  end if;

  -- Grava o pedido (somente colunas que existem na tabela)
  v_dados := p_pedido - 'id' - 'codigo' - 'created_at';

  select string_agg(format('%I', c.column_name), ', ')
    into v_cols
    from information_schema.columns c
   where c.table_schema = 'public' and c.table_name = 'pedidos_tecnicos'
     and v_dados ? c.column_name;

  if v_existe then
    execute format(
      'update public.pedidos_tecnicos set (%1$s) = (select %1$s from jsonb_populate_record(null::public.pedidos_tecnicos, $1)) where id::text = $2',
      v_cols) using v_dados, v_id::text;
  else
    if v_id is not null then
      v_dados := v_dados || jsonb_build_object('id', v_id);
      v_cols  := v_cols || ', id';
    end if;
    execute format(
      'insert into public.pedidos_tecnicos (%1$s) select %1$s from jsonb_populate_record(null::public.pedidos_tecnicos, $1) returning id',
      v_cols) into v_id using v_dados;
  end if;

  -- Substitui os elementos do pedido
  delete from public.pedido_tecnico_elementos where pedido_id::text = v_id::text;

  if jsonb_array_length(p_elementos) > 0 then
    select string_agg(format('%I', c.column_name), ', ')
      into v_cols
      from information_schema.columns c
     where c.table_schema = 'public' and c.table_name = 'pedido_tecnico_elementos'
       and c.column_name <> 'id'
       and (c.column_name = 'pedido_id'
            or exists (select 1 from jsonb_array_elements(p_elementos) e where e ? c.column_name));

    select jsonb_agg((e - 'id') || jsonb_build_object('pedido_id', v_id))
      into v_lista
      from jsonb_array_elements(p_elementos) e;

    execute format(
      'insert into public.pedido_tecnico_elementos (%1$s) select %1$s from jsonb_populate_recordset(null::public.pedido_tecnico_elementos, $1)',
      v_cols)
    using v_lista;
  end if;

  select to_jsonb(p) || jsonb_build_object(
           'pedido_tecnico_elementos',
           coalesce((select jsonb_agg(to_jsonb(pe)) from public.pedido_tecnico_elementos pe where pe.pedido_id::text = p.id::text), '[]'::jsonb))
    into v_resultado
    from public.pedidos_tecnicos p
   where p.id::text = v_id::text;

  return v_resultado;
end;
$$;

grant execute on function public.salvar_pedido_tecnico(jsonb, jsonb) to authenticated;

-- -----------------------------------------------------------------------------
-- 6. Proteção de elementos que estão em pedido técnico aberto
-- -----------------------------------------------------------------------------

create or replace function public.spe_proteger_elemento_em_pedido()
returns trigger
language plpgsql
as $$
declare
  v_aloc  record;
  v_nova  int;
begin
  for v_aloc in
    select pe.elemento_nome as nome, sum(pe.quantidade_solicitada)::int as qtde
      from public.pedido_tecnico_elementos pe
      join public.pedidos_tecnicos p on p.id = pe.pedido_id
     where p.status = 'aberto' and pe.elemento_id::text = old.id::text
     group by pe.elemento_nome
  loop
    if tg_op = 'DELETE' then
      raise exception 'O elemento % está em pedido técnico aberto (% peça(s)) e não pode ser excluído.',
        v_aloc.nome, v_aloc.qtde using errcode = 'P0001';
    end if;

    -- Quantidade que o nome passará a ter após o UPDATE
    if new.nome = v_aloc.nome then
      v_nova := new.quantidade;
    else
      select case
               when jsonb_typeof(eq) = 'object'
                 then coalesce(nullif(eq->>'quantidade', '')::numeric::int, new.quantidade)
               else new.quantidade
             end
        into v_nova
        from jsonb_array_elements(coalesce(to_jsonb(new.elementos_equivalentes), '[]'::jsonb)) eq
       where (case when jsonb_typeof(eq) = 'object' then eq->>'nome' else eq #>> '{}' end) = v_aloc.nome
       limit 1;
    end if;

    if v_nova is null then
      raise exception 'O elemento % está em pedido técnico aberto e não pode ser renomeado ou removido.',
        v_aloc.nome using errcode = 'P0001';
    end if;
    if v_nova < v_aloc.qtde then
      raise exception 'O elemento % tem % peça(s) em pedido técnico aberto; a quantidade não pode ser menor que isso.',
        v_aloc.nome, v_aloc.qtde using errcode = 'P0001';
    end if;
  end loop;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists spe_proteger_pedido on public.elementos;
create trigger spe_proteger_pedido
  before update of nome, quantidade, elementos_equivalentes or delete on public.elementos
  for each row execute function public.spe_proteger_elemento_em_pedido();

-- -----------------------------------------------------------------------------
-- 7. Realtime para as tabelas filhas
-- -----------------------------------------------------------------------------

do $$
declare
  v_tabela text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach v_tabela in array array['detalhamentos', 'elementos', 'posicoes',
                                    'pedidos_tecnicos', 'pedido_tecnico_elementos', 'demandas']
    loop
      if not exists (select 1 from pg_publication_tables
                      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = v_tabela) then
        execute format('alter publication supabase_realtime add table public.%I', v_tabela);
      end if;
    end loop;
  end if;
end;
$$;

commit;
