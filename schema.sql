-- Messa Supabase schema
create extension if not exists pgcrypto;

create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 username text not null unique,
 bio text default '',
 avatar_url text,
 created_at timestamptz not null default now()
);

create table if not exists public.posts (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 content text not null default '',
 media_url text,
 created_at timestamptz not null default now()
);

create table if not exists public.comments (
 id uuid primary key default gen_random_uuid(),
 post_id uuid not null references public.posts(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 content text not null,
 created_at timestamptz not null default now()
);

create table if not exists public.post_likes (
 post_id uuid not null references public.posts(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(post_id,user_id)
);

create table if not exists public.follows (
 follower_id uuid not null references public.profiles(id) on delete cascade,
 following_id uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(follower_id,following_id),
 check(follower_id<>following_id)
);

create table if not exists public.messages (
 id uuid primary key default gen_random_uuid(),
 sender_id uuid not null references public.profiles(id) on delete cascade,
 receiver_id uuid not null references public.profiles(id) on delete cascade,
 content text not null,
 created_at timestamptz not null default now()
);

create table if not exists public.communities (
 id uuid primary key default gen_random_uuid(),
 name text not null unique,
 description text default '',
 created_by uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now()
);

create table if not exists public.community_members (
 community_id uuid not null references public.communities(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(community_id,user_id)
);

create table if not exists public.notifications (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 actor_id uuid references public.profiles(id) on delete set null,
 type text not null,
 title text,
 body text,
 created_at timestamptz not null default now(),
 read_at timestamptz
);

-- New auth users get an empty profile. Username is taken from signUp metadata.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.profiles(id,username) values(new.id,coalesce(nullif(new.raw_user_meta_data->>'username',''),split_part(new.email,'@',1)));
 return new;
exception when unique_violation then
 insert into public.profiles(id,username) values(new.id,substr(split_part(new.email,'@',1),1,24)||'_'||substr(new.id::text,1,6));
 return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.comments enable row level security;
alter table public.post_likes enable row level security;
alter table public.follows enable row level security;
alter table public.messages enable row level security;
alter table public.communities enable row level security;
alter table public.community_members enable row level security;
alter table public.notifications enable row level security;

-- Re-runnable policies
DO $$ DECLARE r record; BEGIN
 FOR r IN SELECT policyname,tablename FROM pg_policies WHERE schemaname='public' AND tablename IN ('profiles','posts','comments','post_likes','follows','messages','communities','community_members','notifications') LOOP EXECUTE format('drop policy if exists %I on public.%I',r.policyname,r.tablename); END LOOP;
END $$;

create policy profiles_select on public.profiles for select to authenticated using (true);
create policy profiles_insert on public.profiles for insert to authenticated with check (auth.uid()=id);
create policy profiles_update on public.profiles for update to authenticated using (auth.uid()=id) with check (auth.uid()=id);

create policy posts_select on public.posts for select to authenticated using (true);
create policy posts_insert on public.posts for insert to authenticated with check (auth.uid()=user_id);
create policy posts_update on public.posts for update to authenticated using (auth.uid()=user_id) with check (auth.uid()=user_id);
create policy posts_delete on public.posts for delete to authenticated using (auth.uid()=user_id);

create policy comments_select on public.comments for select to authenticated using (true);
create policy comments_insert on public.comments for insert to authenticated with check (auth.uid()=user_id);
create policy comments_delete on public.comments for delete to authenticated using (auth.uid()=user_id);

create policy likes_select on public.post_likes for select to authenticated using (true);
create policy likes_insert on public.post_likes for insert to authenticated with check (auth.uid()=user_id);
create policy likes_delete on public.post_likes for delete to authenticated using (auth.uid()=user_id);

create policy follows_select on public.follows for select to authenticated using (true);
create policy follows_insert on public.follows for insert to authenticated with check (auth.uid()=follower_id);
create policy follows_delete on public.follows for delete to authenticated using (auth.uid()=follower_id);

create policy messages_select on public.messages for select to authenticated using (auth.uid()=sender_id or auth.uid()=receiver_id);
create policy messages_insert on public.messages for insert to authenticated with check (auth.uid()=sender_id);
create policy messages_delete on public.messages for delete to authenticated using (auth.uid()=sender_id);

create policy communities_select on public.communities for select to authenticated using (true);
create policy communities_insert on public.communities for insert to authenticated with check (auth.uid()=created_by);
create policy communities_update on public.communities for update to authenticated using (auth.uid()=created_by) with check (auth.uid()=created_by);
create policy community_members_select on public.community_members for select to authenticated using (true);
create policy community_members_insert on public.community_members for insert to authenticated with check (auth.uid()=user_id);
create policy community_members_delete on public.community_members for delete to authenticated using (auth.uid()=user_id);

create policy notifications_select on public.notifications for select to authenticated using (auth.uid()=user_id);
create policy notifications_update on public.notifications for update to authenticated using (auth.uid()=user_id) with check (auth.uid()=user_id);

-- Storage buckets and policies. Run once; harmless if buckets already exist.
insert into storage.buckets(id,name,public) values('avatars','avatars',true) on conflict(id) do nothing;
insert into storage.buckets(id,name,public) values('media','media',true) on conflict(id) do nothing;

drop policy if exists avatars_public_read on storage.objects;
drop policy if exists avatars_insert_own on storage.objects;
drop policy if exists avatars_update_own on storage.objects;
drop policy if exists avatars_delete_own on storage.objects;
drop policy if exists media_public_read on storage.objects;
drop policy if exists media_insert_own on storage.objects;
drop policy if exists media_delete_own on storage.objects;
create policy avatars_public_read on storage.objects for select using (bucket_id='avatars');
create policy avatars_insert_own on storage.objects for insert to authenticated with check (bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);
create policy avatars_update_own on storage.objects for update to authenticated using (bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);
create policy avatars_delete_own on storage.objects for delete to authenticated using (bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);
create policy media_public_read on storage.objects for select using (bucket_id='media');
create policy media_insert_own on storage.objects for insert to authenticated with check (bucket_id='media' and (storage.foldername(name))[1]=auth.uid()::text);
create policy media_delete_own on storage.objects for delete to authenticated using (bucket_id='media' and (storage.foldername(name))[1]=auth.uid()::text);

-- Realtime tables
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.posts;
