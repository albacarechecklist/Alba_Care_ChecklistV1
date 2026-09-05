-- Alba Care Daily Checklist - Supabase schema
-- Run once in Supabase SQL Editor on a NEW project.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  role text not null default 'viewer' check (role in ('admin','quality','head_nurse','nurse','receptionist','operations','medical_director','viewer')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_permissions (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  can_submit boolean not null default false,
  can_view_reports boolean not null default false,
  can_export boolean not null default false,
  can_manage_users boolean not null default false,
  can_manage_areas boolean not null default false
);

create table if not exists public.areas (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  sort_order int not null default 0,
  item_count int not null default 0,
  is_active boolean not null default true,
  source_pages int[] not null default '{}',
  created_at timestamptz not null default now()
);

create table if not exists public.checklist_items (
  id uuid primary key default gen_random_uuid(),
  area_id uuid not null references public.areas(id) on delete cascade,
  item_no int not null,
  item_text text not null,
  is_active boolean not null default true,
  unique(area_id,item_no)
);

create table if not exists public.area_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  area_id uuid not null references public.areas(id) on delete cascade,
  assigned_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  unique(user_id,area_id)
);

create table if not exists public.submissions (
  id uuid primary key default gen_random_uuid(),
  area_id uuid not null references public.areas(id),
  checklist_date date not null default (timezone('Asia/Riyadh',now()))::date,
  submitted_by uuid not null references public.profiles(id),
  submitted_at timestamptz not null default now(),
  compliance_score numeric(5,2),
  c_count int not null default 0,
  nc_count int not null default 0,
  na_count int not null default 0,
  status text not null default 'submitted' check(status in ('draft','submitted')),
  unique(area_id,checklist_date)
);

create table if not exists public.responses (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.submissions(id) on delete cascade,
  checklist_item_id uuid not null references public.checklist_items(id),
  status text not null check(status in ('C','NC','NA')),
  action_plan text,
  unique(submission_id,checklist_item_id),
  constraint nc_requires_action check(status <> 'NC' or length(trim(coalesce(action_plan,''))) > 0)
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  message text not null,
  submission_id uuid references public.submissions(id) on delete cascade,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.app_settings (
  key text primary key,
  value text,
  updated_at timestamptz not null default now()
);
insert into public.app_settings(key,value) values ('admin_notification_email','') on conflict(key) do nothing;

-- Create profile automatically when an Auth user is created.
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.profiles(id,email,full_name,role)
  values(new.id,new.email,coalesce(new.raw_user_meta_data->>'full_name',new.email),coalesce(new.raw_user_meta_data->>'role','viewer'))
  on conflict(id) do nothing;
  insert into public.user_permissions(user_id) values(new.id) on conflict(user_id) do nothing;
  return new;
end;$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create or replace function public.is_admin(uid uuid) returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from profiles where id=uid and is_active and role='admin');
$$;
create or replace function public.has_perm(uid uuid,p text) returns boolean language plpgsql stable security definer set search_path=public as $$
declare ok boolean;
begin
 if public.is_admin(uid) then return true; end if;
 execute format('select coalesce(%I,false) from public.user_permissions where user_id=$1',p) into ok using uid;
 return coalesce(ok,false);
end;$$;
create or replace function public.is_assigned(uid uuid, aid uuid) returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from area_assignments where user_id=uid and area_id=aid);
$$;

-- In-app notification after every checklist submission/update.
create or replace function public.notify_submission() returns trigger language plpgsql security definer set search_path=public as $$
declare a_name text; u_name text;
begin
 select name into a_name from areas where id=new.area_id;
 select full_name into u_name from profiles where id=new.submitted_by;
 insert into notifications(recipient_user_id,title,message,submission_id)
 select p.id,'Checklist submitted',coalesce(u_name,'Staff')||' submitted '||coalesce(a_name,'area')||' - compliance '||coalesce(new.compliance_score::text,'N/A')||'%.',new.id
 from profiles p left join user_permissions up on up.user_id=p.id
 where p.is_active and (p.role in ('admin','quality','head_nurse','operations','medical_director') or coalesce(up.can_manage_users,false));
 return new;
end;$$;
drop trigger if exists submission_notification on submissions;
create trigger submission_notification after insert or update of submitted_at on submissions for each row when (new.status='submitted') execute function public.notify_submission();

-- RLS
alter table profiles enable row level security;
alter table user_permissions enable row level security;
alter table areas enable row level security;
alter table checklist_items enable row level security;
alter table area_assignments enable row level security;
alter table submissions enable row level security;
alter table responses enable row level security;
alter table notifications enable row level security;
alter table app_settings enable row level security;

create policy profiles_read on profiles for select to authenticated using (id=auth.uid() or public.has_perm(auth.uid(),'can_manage_users'));
create policy profiles_admin_update on profiles for update to authenticated using (public.has_perm(auth.uid(),'can_manage_users')) with check(public.has_perm(auth.uid(),'can_manage_users'));
create policy perms_read on user_permissions for select to authenticated using(user_id=auth.uid() or public.has_perm(auth.uid(),'can_manage_users'));
create policy perms_admin_all on user_permissions for all to authenticated using(public.has_perm(auth.uid(),'can_manage_users')) with check(public.has_perm(auth.uid(),'can_manage_users'));
create policy areas_read on areas for select to authenticated using(true);
create policy areas_admin on areas for all to authenticated using(public.has_perm(auth.uid(),'can_manage_areas')) with check(public.has_perm(auth.uid(),'can_manage_areas'));
create policy items_read on checklist_items for select to authenticated using(true);
create policy items_admin on checklist_items for all to authenticated using(public.has_perm(auth.uid(),'can_manage_areas')) with check(public.has_perm(auth.uid(),'can_manage_areas'));
create policy asg_read on area_assignments for select to authenticated using(user_id=auth.uid() or public.has_perm(auth.uid(),'can_manage_users'));
create policy asg_admin on area_assignments for all to authenticated using(public.has_perm(auth.uid(),'can_manage_users')) with check(public.has_perm(auth.uid(),'can_manage_users'));
create policy submissions_read on submissions for select to authenticated using(public.has_perm(auth.uid(),'can_view_reports') or submitted_by=auth.uid() or public.is_assigned(auth.uid(),area_id));
create policy submissions_insert on submissions for insert to authenticated with check(public.has_perm(auth.uid(),'can_submit') and (public.is_assigned(auth.uid(),area_id) or public.has_perm(auth.uid(),'can_manage_areas')) and submitted_by=auth.uid());
create policy submissions_update on submissions for update to authenticated using(public.has_perm(auth.uid(),'can_submit') and (public.is_assigned(auth.uid(),area_id) or public.has_perm(auth.uid(),'can_manage_areas'))) with check(public.has_perm(auth.uid(),'can_submit'));
create policy responses_read on responses for select to authenticated using(exists(select 1 from submissions s where s.id=submission_id and (public.has_perm(auth.uid(),'can_view_reports') or s.submitted_by=auth.uid() or public.is_assigned(auth.uid(),s.area_id))));
create policy responses_write on responses for all to authenticated using(exists(select 1 from submissions s where s.id=submission_id and public.has_perm(auth.uid(),'can_submit') and (public.is_assigned(auth.uid(),s.area_id) or public.has_perm(auth.uid(),'can_manage_areas')))) with check(exists(select 1 from submissions s where s.id=submission_id and public.has_perm(auth.uid(),'can_submit') and (public.is_assigned(auth.uid(),s.area_id) or public.has_perm(auth.uid(),'can_manage_areas'))));
create policy notifications_own on notifications for select to authenticated using(recipient_user_id=auth.uid());
create policy notifications_update_own on notifications for update to authenticated using(recipient_user_id=auth.uid()) with check(recipient_user_id=auth.uid());
create policy settings_admin on app_settings for all to authenticated using(public.is_admin(auth.uid())) with check(public.is_admin(auth.uid()));

-- Realtime tables
alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.submissions;
