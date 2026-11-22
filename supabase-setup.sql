-- JamByrd database setup (run once in the Supabase SQL editor).
-- Tables are only reachable through the jb_* functions, which need a song's
-- secret id, so nobody can list or browse other people's songs.

create table if not exists public.songs (
  id text primary key check (char_length(id) between 16 and 40),
  name text not null default 'Untitled song',
  bpm int not null default 100,
  beats int not null default 4,
  count_in int not null default 1,
  guide text not null default 'click',
  drum_style text not null default 'rock',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.tracks (
  id text primary key check (char_length(id) between 8 and 40),
  song_id text not null references public.songs(id) on delete cascade,
  position int not null default 0,
  name text not null default '',
  player text not null default '',
  inst text not null default 'none',
  vol real not null default 0.8,
  pan real not null default 0,
  clip_path text,
  clip_start double precision,
  clip_sr int,
  clip_len int,
  updated_at timestamptz not null default now()
);
create index if not exists tracks_song_idx on public.tracks(song_id);

alter table public.songs enable row level security;
alter table public.tracks enable row level security;
-- no policies: direct table access is blocked; the functions below do the work.

create or replace function public.jb_get_song(p_id text)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'song', row_to_json(s),
    'tracks', coalesce((select json_agg(t order by t.position, t.id) from public.tracks t where t.song_id = s.id), '[]'::json))
  from public.songs s where s.id = p_id
$$;

create or replace function public.jb_save_song(p_id text, p json)
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into public.songs (id, name, bpm, beats, count_in, guide, drum_style, updated_at)
  values (p_id,
          left(coalesce(p->>'name', 'Untitled song'), 60),
          greatest(40, least(240, coalesce((p->>'bpm')::int, 100))),
          coalesce((p->>'beats')::int, 4),
          coalesce((p->>'count_in')::int, 1),
          coalesce(p->>'guide', 'click'),
          coalesce(p->>'drum_style', 'rock'),
          now())
  on conflict (id) do update set
    name = excluded.name, bpm = excluded.bpm, beats = excluded.beats, count_in = excluded.count_in,
    guide = excluded.guide, drum_style = excluded.drum_style, updated_at = now();
end $$;

create or replace function public.jb_upsert_track(p_song text, p json)
returns void language plpgsql security definer set search_path = public as $$
declare v_id text := p->>'id';
begin
  if not exists (select 1 from public.songs where id = p_song) then raise exception 'song not found'; end if;
  if not exists (select 1 from public.tracks where id = v_id)
     and (select count(*) from public.tracks where song_id = p_song) >= 16 then
    raise exception 'track limit reached';
  end if;
  insert into public.tracks (id, song_id, position, name, player, inst, vol, pan, clip_path, clip_start, clip_sr, clip_len, updated_at)
  values (v_id, p_song, coalesce((p->>'position')::int, 0), left(coalesce(p->>'name', ''), 40), left(coalesce(p->>'player', ''), 40),
          coalesce(p->>'inst', 'none'), coalesce((p->>'vol')::real, 0.8), coalesce((p->>'pan')::real, 0),
          p->>'clip_path', (p->>'clip_start')::double precision, (p->>'clip_sr')::int, (p->>'clip_len')::int, now())
  on conflict (id) do update set
    position = excluded.position, name = excluded.name, player = excluded.player, inst = excluded.inst,
    vol = excluded.vol, pan = excluded.pan, clip_path = excluded.clip_path, clip_start = excluded.clip_start,
    clip_sr = excluded.clip_sr, clip_len = excluded.clip_len, updated_at = now()
  where public.tracks.song_id = p_song;
  update public.songs set updated_at = now() where id = p_song;
end $$;

create or replace function public.jb_delete_track(p_song text, p_track text)
returns void language sql security definer set search_path = public as $$
  delete from public.tracks where id = p_track and song_id = p_song;
$$;

revoke all on function public.jb_get_song(text), public.jb_save_song(text, json),
  public.jb_upsert_track(text, json), public.jb_delete_track(text, text) from public;
grant execute on function public.jb_get_song(text), public.jb_save_song(text, json),
  public.jb_upsert_track(text, json), public.jb_delete_track(text, text) to anon, authenticated;

-- Audio takes: public files (unguessable paths), uploads allowed, no listing.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('takes', 'takes', true, 52428800, array['audio/wav'])
on conflict (id) do update set public = true, file_size_limit = 52428800, allowed_mime_types = array['audio/wav'];

drop policy if exists "jambyrd upload takes" on storage.objects;
create policy "jambyrd upload takes" on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'takes' and name ~ '^[A-Za-z0-9]{16,40}/[A-Za-z0-9]{8,40}\.wav$');
