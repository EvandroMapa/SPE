-- =============================================================================
-- SPE — Migração 02: autenticação com Supabase Auth
-- =============================================================================
-- Rodar ANTES de publicar a nova versão do app (a nova versão faz login pelo
-- Supabase Auth). A versão antiga continua funcionando depois desta migração.
--
-- O que faz:
--   1. Cria um login (auth.users) para cada usuário de public.usuarios,
--      com a MESMA senha atual (armazenada como hash bcrypt).
--   2. Liga public.usuarios.auth_user_id ao login criado.
--   3. Cria RPCs para o app gerenciar logins (criar, trocar senha/e-mail, remover)
--      sem expor senhas.
--
-- A coluna public.usuarios.senha só é apagada na migração 03.
-- =============================================================================

begin;

create extension if not exists pgcrypto with schema extensions;

alter table public.usuarios
  add column if not exists auth_user_id uuid unique references auth.users(id) on delete set null;

-- O app novo não grava mais a senha em public.usuarios.
do $$
begin
  if exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'usuarios' and column_name = 'senha') then
    alter table public.usuarios alter column senha drop not null;
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
-- Função interna: cria (ou atualiza) um login no Supabase Auth
-- -----------------------------------------------------------------------------
create or replace function public.spe_upsert_login(p_email text, p_senha text, p_auth_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, extensions, auth
as $$
declare
  v_email text := lower(trim(p_email));
  v_id    uuid := p_auth_user_id;
begin
  if v_email is null or v_email = '' or position('@' in v_email) = 0 then
    raise exception 'E-mail inválido: %', coalesce(p_email, '') using errcode = 'P0001';
  end if;

  if v_id is null then
    select u.id into v_id from auth.users u where lower(u.email) = v_email;
  end if;

  if v_id is null then
    if coalesce(p_senha, '') = '' then
      raise exception 'Informe a senha do novo usuário.' using errcode = 'P0001';
    end if;

    v_id := gen_random_uuid();

    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change,
      email_change_token_current, phone_change_token, reauthentication_token
    ) values (
      '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
      v_email, crypt(p_senha, gen_salt('bf')), now(),
      '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, now(), now(),
      '', '', '', '', '', '', ''
    );

    insert into auth.identities (
      id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), v_id, v_id::text, 'email',
      jsonb_build_object('sub', v_id::text, 'email', v_email, 'email_verified', true),
      now(), now(), now()
    );
  else
    if exists (select 1 from auth.users u where lower(u.email) = v_email and u.id <> v_id) then
      raise exception 'Já existe outro usuário com o e-mail %.', v_email using errcode = 'P0001';
    end if;

    update auth.users u
       set email = v_email,
           encrypted_password = case when coalesce(p_senha, '') <> ''
                                     then crypt(p_senha, gen_salt('bf'))
                                     else u.encrypted_password end,
           email_confirmed_at = coalesce(u.email_confirmed_at, now()),
           updated_at = now()
     where u.id = v_id;

    update auth.identities i
       set identity_data = coalesce(i.identity_data, '{}'::jsonb) || jsonb_build_object('email', v_email),
           updated_at = now()
     where i.user_id = v_id and i.provider = 'email';
  end if;

  return v_id;
end;
$$;

revoke all on function public.spe_upsert_login(text, text, uuid) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 1 e 2. Migra os usuários existentes
-- -----------------------------------------------------------------------------
do $$
declare
  v_usuario record;
  v_auth_id uuid;
begin
  for v_usuario in
    select u.id, u.email, u.senha
      from public.usuarios u
     where u.auth_user_id is null
  loop
    if coalesce(trim(v_usuario.email), '') = '' or position('@' in v_usuario.email) = 0 then
      raise notice 'SPE: usuário % sem e-mail válido — não migrado', v_usuario.id;
      continue;
    end if;

    -- Já existe login com este e-mail ligado a outro usuário?
    if exists (
      select 1 from public.usuarios o
        join auth.users a on a.id = o.auth_user_id
       where lower(a.email) = lower(trim(v_usuario.email))
    ) then
      raise notice 'SPE: e-mail % duplicado — usuário % não migrado', v_usuario.email, v_usuario.id;
      continue;
    end if;

    if coalesce(v_usuario.senha, '') = '' then
      raise notice 'SPE: usuário % (%) sem senha — defina uma senha pelo app', v_usuario.id, v_usuario.email;
      continue;
    end if;

    v_auth_id := public.spe_upsert_login(v_usuario.email, v_usuario.senha, null);
    update public.usuarios set auth_user_id = v_auth_id where id = v_usuario.id;
  end loop;
end;
$$;

-- -----------------------------------------------------------------------------
-- 3. RPCs usadas pelo app (exigem usuário autenticado)
-- -----------------------------------------------------------------------------

-- Cria ou atualiza o login de um usuário. Retorna o auth_user_id.
--   p_auth_user_id = null  -> cria login novo (senha obrigatória)
--   p_senha vazia          -> mantém a senha atual
create or replace function public.definir_login_usuario(p_email text, p_senha text, p_auth_user_id uuid default null)
returns uuid
language plpgsql
security definer
set search_path = public, extensions, auth
as $$
begin
  if auth.uid() is null then
    raise exception 'Não autenticado.' using errcode = '42501';
  end if;
  if coalesce(p_senha, '') <> '' and length(p_senha) < 6 then
    raise exception 'A senha deve ter pelo menos 6 caracteres.' using errcode = 'P0001';
  end if;
  -- Criação: não reaproveita login de e-mail que já pertence a outro usuário
  if p_auth_user_id is null and exists (
    select 1 from public.usuarios o
      join auth.users a on a.id = o.auth_user_id
     where lower(a.email) = lower(trim(p_email))
  ) then
    raise exception 'Já existe um usuário com o e-mail %.', lower(trim(p_email)) using errcode = 'P0001';
  end if;
  return public.spe_upsert_login(p_email, p_senha, p_auth_user_id);
end;
$$;

-- Remove o login (usado ao excluir um usuário).
create or replace function public.remover_login_usuario(p_auth_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    raise exception 'Não autenticado.' using errcode = '42501';
  end if;
  if p_auth_user_id = auth.uid() then
    raise exception 'Você não pode remover o seu próprio login.' using errcode = 'P0001';
  end if;
  delete from auth.users where id = p_auth_user_id;
end;
$$;

revoke all on function public.definir_login_usuario(text, text, uuid) from public, anon;
revoke all on function public.remover_login_usuario(uuid) from public, anon;
grant execute on function public.definir_login_usuario(text, text, uuid) to authenticated;
grant execute on function public.remover_login_usuario(uuid) to authenticated;

commit;

-- Conferência: usuários que NÃO foram migrados (ver NOTICEs acima)
select id, nome, email from public.usuarios where auth_user_id is null;
