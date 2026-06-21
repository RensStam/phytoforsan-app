-- =====================================================================
-- PhytoForsan Relax — Supabase schema (fase 1)
-- Voer dit uit in de Supabase SQL editor van je test- en productieproject.
-- Geen betaal-/Mollie-logica. Alleen anon key in de frontend; beveiliging via RLS.
-- =====================================================================

-- ---------- Helper: is de huidige gebruiker admin? ----------
create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'admin'
  );
$$;

-- ---------- 1. profiles ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text,
  role text not null default 'user' check (role in ('user','tester','admin')),
  access_level text not null default 'free' check (access_level in ('free','deep','premium','admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_login_at timestamptz
);

-- Nieuwe auth-gebruiker → automatisch profiel (role=user, access=free)
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, display_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'display_name', new.email))
  on conflict (id) do nothing;
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- 2. categories ----------
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  description text,
  sort_order int not null default 0,
  status text not null default 'draft' check (status in ('draft','published','hidden','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------- 11. media_files (voor image_id referenties; eerst aanmaken) ----------
create table if not exists public.media_files (
  id uuid primary key default gen_random_uuid(),
  filename text not null,
  type text not null default 'image' check (type in ('image','audio','document','license_proof','other')),
  storage_path text,
  alt_text text,
  source text,
  license text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------- 3. protocols ----------
create table if not exists public.protocols (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  category_id uuid references public.categories(id) on delete set null,
  group_name text,
  short_description text,
  long_description text,
  evidence_text text,
  safety_text text,
  closing_text text,
  access_tier text not null default 'free' check (access_tier in ('free','deep','premium','admin')),
  requires_deep_access boolean not null default false,
  requires_premium boolean not null default false,
  status text not null default 'draft' check (status in ('draft','published','hidden','archived')),
  sort_order int not null default 0,
  image_id uuid references public.media_files(id) on delete set null,
  night boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists protocols_category_idx on public.protocols(category_id);
create index if not exists protocols_status_idx on public.protocols(status);

-- ---------- 4. protocol_phases ----------
create table if not exists public.protocol_phases (
  id uuid primary key default gen_random_uuid(),
  protocol_id uuid not null references public.protocols(id) on delete cascade,
  sort_order int not null default 0,
  title text,
  type text not null default 'breath' check (type in ('breath','free','humming','sound','silence','integration','warning')),
  duration_seconds int not null default 0 check (duration_seconds >= 0),
  inhale_seconds numeric not null default 0,
  hold_seconds numeric not null default 0,
  exhale_seconds numeric not null default 0,
  pause_seconds numeric not null default 0,
  instruction_text text,
  visual_mode text,
  cue text,            -- cue-woord voor rustfases (type=free)
  cue_in text,         -- cue-woord bij inademing (type=breath)
  cue_out text,        -- cue-woord bij uitademing (type=breath)
  sub_in text,         -- subtekst bij inademing (type=breath)
  sub_out text,        -- subtekst bij uitademing (type=breath)
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
-- Voor bestaande databases: voeg de kolommen toe als ze nog niet bestaan.
alter table public.protocol_phases add column if not exists cue_in text;
alter table public.protocol_phases add column if not exists cue_out text;
alter table public.protocol_phases add column if not exists sub_in text;
alter table public.protocol_phases add column if not exists sub_out text;
create index if not exists phases_protocol_idx on public.protocol_phases(protocol_id, sort_order);

-- ---------- 10. audio_tracks ----------
create table if not exists public.audio_tracks (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  original_filename text,
  internal_filename text,
  artist text,
  source text,
  license text,
  source_url text,
  profile_url text,
  duration_seconds numeric,
  storage_path text,
  claim_safe_description text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------- protocol_audio (koppeling) ----------
create table if not exists public.protocol_audio (
  id uuid primary key default gen_random_uuid(),
  protocol_id uuid not null references public.protocols(id) on delete cascade,
  audio_track_id uuid not null references public.audio_tracks(id) on delete cascade,
  audio_role text not null default 'background' check (audio_role in ('background','humming','cue','ending','test')),
  enabled boolean not null default true,
  loop boolean not null default true,
  volume numeric not null default 0.35 check (volume >= 0 and volume <= 1),
  start_offset numeric not null default 0,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists protocol_audio_protocol_idx on public.protocol_audio(protocol_id);

-- ---------- 12. license_records ----------
create table if not exists public.license_records (
  id uuid primary key default gen_random_uuid(),
  file_type text,
  file_id uuid,
  artist text,
  source text,
  license text,
  source_url text,
  profile_url text,
  proof_status text not null default 'pending' check (proof_status in ('not_needed','pending','saved','verified')),
  proof_file_url text,
  recorded_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------- 13. app_settings ----------
create table if not exists public.app_settings (
  key text primary key,
  value text,
  updated_at timestamptz not null default now()
);

-- ---------- user_access (toekomstige fijnmazige toegang) ----------
create table if not exists public.user_access (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  access_level text not null default 'free' check (access_level in ('free','deep','premium','admin')),
  granted_by uuid references public.profiles(id),
  source text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------- license_records koppelt later; placeholder voor toekomst ----------

-- =====================================================================
-- ROW LEVEL SECURITY
-- =====================================================================
alter table public.profiles        enable row level security;
alter table public.categories      enable row level security;
alter table public.protocols       enable row level security;
alter table public.protocol_phases enable row level security;
alter table public.audio_tracks    enable row level security;
alter table public.protocol_audio  enable row level security;
alter table public.media_files      enable row level security;
alter table public.license_records  enable row level security;
alter table public.app_settings     enable row level security;
alter table public.user_access      enable row level security;

-- profiles: eigen profiel lezen; admin leest alles; admin schrijft alles
create policy profiles_self_read on public.profiles for select using (id = auth.uid() or public.is_admin());
create policy profiles_self_update on public.profiles for update using (id = auth.uid()) with check (id = auth.uid() and role = (select role from public.profiles where id = auth.uid()));
create policy profiles_admin_all on public.profiles for all using (public.is_admin()) with check (public.is_admin());

-- categories: iedereen leest published; admin alles
create policy categories_public_read on public.categories for select using (status = 'published' or public.is_admin());
create policy categories_admin_write on public.categories for all using (public.is_admin()) with check (public.is_admin());

-- protocols: iedereen leest published; admin alles
create policy protocols_public_read on public.protocols for select using (status = 'published' or public.is_admin());
create policy protocols_admin_write on public.protocols for all using (public.is_admin()) with check (public.is_admin());

-- protocol_phases: leesbaar als bijbehorend protocol leesbaar is; admin schrijft
create policy phases_public_read on public.protocol_phases for select using (
  public.is_admin() or exists (
    select 1 from public.protocols p where p.id = protocol_id and p.status = 'published'
  )
);
create policy phases_admin_write on public.protocol_phases for all using (public.is_admin()) with check (public.is_admin());

-- audio_tracks / protocol_audio / media_files: publiek leesbaar, admin schrijft
create policy audio_public_read on public.audio_tracks for select using (true);
create policy audio_admin_write on public.audio_tracks for all using (public.is_admin()) with check (public.is_admin());

create policy protocol_audio_public_read on public.protocol_audio for select using (true);
create policy protocol_audio_admin_write on public.protocol_audio for all using (public.is_admin()) with check (public.is_admin());

create policy media_public_read on public.media_files for select using (true);
create policy media_admin_write on public.media_files for all using (public.is_admin()) with check (public.is_admin());

-- license_records: alleen admin
create policy license_admin_all on public.license_records for all using (public.is_admin()) with check (public.is_admin());

-- app_settings: iedereen leest, admin schrijft
create policy settings_public_read on public.app_settings for select using (true);
create policy settings_admin_write on public.app_settings for all using (public.is_admin()) with check (public.is_admin());

-- user_access: eigen rij lezen; admin alles
create policy user_access_self_read on public.user_access for select using (user_id = auth.uid() or public.is_admin());
create policy user_access_admin_write on public.user_access for all using (public.is_admin()) with check (public.is_admin());

-- =====================================================================
-- Eerste admin instellen (vervang het e-mailadres nadat je bent geregistreerd):
--   update public.profiles set role='admin', access_level='admin'
--   where email = 'rens@domeinstam.nl';
-- =====================================================================
