-- =============================================================================
-- SPE — Migração 03: fechar o acesso anônimo (RLS) e apagar senhas em texto
-- =============================================================================
-- ⚠️  Rodar SOMENTE DEPOIS que:
--     - a nova versão do app estiver publicada (login pelo Supabase Auth) e
--       todos conseguirem entrar;
--     - o plugin do AutoCAD tiver sido atualizado (ele passa a pedir login).
--   Depois desta migração, a versão antiga do app e do plugin PARAM de funcionar.
--
-- O que faz:
--   1. Habilita RLS em todas as tabelas do schema public, liberando acesso
--      apenas para usuários autenticados.
--   2. Remove os privilégios do papel anon (a chave pública deixa de dar acesso).
--   3. Restringe o bucket de backups a usuários autenticados.
--   4. Apaga a coluna de senha em texto puro de public.usuarios.
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1 e 2. RLS: somente usuários autenticados
-- -----------------------------------------------------------------------------
do $$
declare
  v_tabela text;
begin
  for v_tabela in
    select c.relname
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind in ('r', 'p')
  loop
    execute format('alter table public.%I enable row level security', v_tabela);
    execute format('drop policy if exists spe_autenticados on public.%I', v_tabela);
    execute format(
      'create policy spe_autenticados on public.%I for all to authenticated using (true) with check (true)',
      v_tabela);
  end loop;
end;
$$;

revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;
revoke execute on all functions in schema public from anon;
alter default privileges in schema public revoke all on tables from anon;
alter default privileges in schema public revoke all on sequences from anon;
alter default privileges in schema public revoke execute on functions from anon;

-- -----------------------------------------------------------------------------
-- 3. Bucket de backups: somente autenticados
-- -----------------------------------------------------------------------------
do $$
declare
  v_pol record;
begin
  -- Remove políticas existentes que mencionam o bucket 'backups'
  for v_pol in
    select policyname
      from pg_policies
     where schemaname = 'storage' and tablename = 'objects'
       and (coalesce(qual, '') like '%backups%' or coalesce(with_check, '') like '%backups%')
  loop
    execute format('drop policy %I on storage.objects', v_pol.policyname);
  end loop;
end;
$$;

update storage.buckets set public = false where id = 'backups';

drop policy if exists spe_backups_autenticados on storage.objects;
create policy spe_backups_autenticados on storage.objects
  for all to authenticated
  using (bucket_id = 'backups')
  with check (bucket_id = 'backups');

-- -----------------------------------------------------------------------------
-- 4. Apaga as senhas em texto puro
-- -----------------------------------------------------------------------------
-- Usuários ainda sem login (auth_user_id nulo) precisam ter a senha definida
-- pelo app (tela de Usuários) — a senha antiga será perdida.
alter table public.usuarios drop column if exists senha;

commit;

-- Conferência: usuários sem login (não conseguirão entrar)
select id, nome, email from public.usuarios where auth_user_id is null;
