-- TrackMe multi-user schema (PROPOSAL - run in Supabase SQL Editor only after review)

-- 1. Profiles: one row per signed-in user
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  full_name text not null default '',
  bio text not null default '',
  avatar_url text,
  level int not null default 1,
  xp int not null default 0,
  current_streak int not null default 0,
  longest_streak int not null default 0,
  badges jsonb not null default '[]',
  main_tasks jsonb not null default '[]',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint username_format check (username ~ '^[a-z0-9_.]{3,20}$')
);
create unique index if not exists profiles_username_key on public.profiles (lower(username));

alter table public.profiles enable row level security;
create policy "profiles are readable by signed-in users" on public.profiles
  for select to authenticated using (true);
create policy "users insert their own profile" on public.profiles
  for insert to authenticated with check (auth.uid() = id);
create policy "users update their own profile" on public.profiles
  for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

-- Username availability check without exposing anything else
create or replace function public.username_available(name text)
returns boolean language sql security definer set search_path = public stable as $$
  select not exists (select 1 from public.profiles where lower(username) = lower(name));
$$;
grant execute on function public.username_available(text) to anon, authenticated;

-- 2. Friendships (requests + accepted friends)
create table if not exists public.friendships (
  id bigint generated always as identity primary key,
  requester uuid not null references public.profiles(id) on delete cascade,
  addressee uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted')),
  created_at timestamptz not null default now(),
  unique (requester, addressee),
  check (requester <> addressee)
);
alter table public.friendships enable row level security;
create policy "see your own friendships" on public.friendships
  for select to authenticated using (auth.uid() in (requester, addressee));
create policy "send a request as yourself" on public.friendships
  for insert to authenticated with check (auth.uid() = requester and status = 'pending');
create policy "addressee accepts" on public.friendships
  for update to authenticated using (auth.uid() = addressee) with check (status = 'accepted');
create policy "either side removes" on public.friendships
  for delete to authenticated using (auth.uid() in (requester, addressee));

-- 3. Avatars bucket: anyone can view, users write only their own folder (<user id>/...)
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true)
  on conflict (id) do nothing;
create policy "users upload own avatar" on storage.objects
  for insert to authenticated with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "users replace own avatar" on storage.objects
  for update to authenticated using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
