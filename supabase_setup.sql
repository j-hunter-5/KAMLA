-- RED THREAD ARCHIVE // ONE-TIME SUPABASE SETUP
-- Run this once in Supabase -> SQL Editor -> New query -> Run.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  handle text unique not null
    check (handle ~ '^[a-z0-9_-]{3,24}$'),
  role text not null default 'member'
    check (role in ('member', 'moderator', 'admin')),
  created_at timestamptz not null default now()
);

create table if not exists public.threads (
  id bigint generated always as identity primary key,
  author_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 120),
  body text not null check (char_length(body) between 1 and 5000),
  created_at timestamptz not null default now(),
  pinned boolean not null default false,
  locked boolean not null default false
);

create table if not exists public.replies (
  id bigint generated always as identity primary key,
  thread_id bigint not null references public.threads(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 5000),
  created_at timestamptz not null default now()
);

create index if not exists threads_author_idx on public.threads(author_id);
create index if not exists threads_created_idx on public.threads(created_at desc);
create index if not exists replies_thread_idx on public.replies(thread_id);
create index if not exists replies_author_idx on public.replies(author_id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, handle)
  values (
    new.id,
    lower(coalesce(
      new.raw_user_meta_data ->> 'handle',
      'researcher_' || substr(new.id::text, 1, 8)
    ))
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.threads enable row level security;
alter table public.replies enable row level security;

revoke all on public.profiles from anon, authenticated;
revoke all on public.threads from anon, authenticated;
revoke all on public.replies from anon, authenticated;

grant select on public.profiles to anon, authenticated;
grant select on public.threads to anon, authenticated;
grant select on public.replies to anon, authenticated;
grant update on public.profiles to authenticated;
grant insert, delete on public.threads to authenticated;
grant insert, delete on public.replies to authenticated;
grant usage, select on sequence public.threads_id_seq to authenticated;
grant usage, select on sequence public.replies_id_seq to authenticated;

-- Re-running this script is safe: recreate policies cleanly.
drop policy if exists "profiles are public" on public.profiles;
drop policy if exists "users update own profile" on public.profiles;
drop policy if exists "threads are public" on public.threads;
drop policy if exists "users create own threads" on public.threads;
drop policy if exists "users delete own threads" on public.threads;
drop policy if exists "replies are public" on public.replies;
drop policy if exists "users create own replies" on public.replies;
drop policy if exists "users delete own replies" on public.replies;

create policy "profiles are public"
on public.profiles for select
to anon, authenticated
using (true);

create policy "users update own profile"
on public.profiles for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

create policy "threads are public"
on public.threads for select
to anon, authenticated
using (true);

create policy "users create own threads"
on public.threads for insert
to authenticated
with check ((select auth.uid()) = author_id);

create policy "users delete own threads"
on public.threads for delete
to authenticated
using ((select auth.uid()) = author_id);

create policy "replies are public"
on public.replies for select
to anon, authenticated
using (true);

create policy "users create own replies"
on public.replies for insert
to authenticated
with check (
  (select auth.uid()) = author_id
  and exists (
    select 1
    from public.threads
    where threads.id = replies.thread_id
      and threads.locked = false
  )
);

create policy "users delete own replies"
on public.replies for delete
to authenticated
using ((select auth.uid()) = author_id);
