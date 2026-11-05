-- ============================================================================
-- Church Follow-Up: make one account the ADMINISTRATOR (and lock admin-only data)
-- Run in Supabase -> SQL Editor.  Safe to run more than once.
--
-- BEFORE running: create the login in Supabase -> Authentication -> Users ->
-- "Add user" -> "Create new user":  email = your admin email,
-- password = admin@123, and tick "Auto Confirm User".
-- Use the email admin@churchfollowup.app (it is fixed in the site code as ADMIN_LOGIN_EMAIL;
-- if you pick another email, change it there too). Staff do NOT use this account:
-- they sign in with their own accounts, then click "Admin login" and type the password.
-- ============================================================================

-- 1. Helper: is the signed-in user an admin? (reads profiles.role, same rule as the app)
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((
    select lower(regexp_replace(coalesce(p.role, ''), '[\s_-]+', '', 'g')) in ('admin','administrator','superadmin','owner')
    from public.profiles p where p.user_id = auth.uid() limit 1
  ), false);
$$;
grant execute on function public.is_admin() to authenticated;

-- 1b. Set (or reset) the admin account's password to admin@123
update auth.users
   set encrypted_password = crypt('admin@123', gen_salt('bf')),
       updated_at = now()
 where lower(email) = lower('admin@churchfollowup.app');

-- 2. Give the admin email the 'admin' role
update public.profiles set role = 'admin'
 where user_id = (select id from auth.users where lower(email) = lower('admin@churchfollowup.app'));
insert into public.profiles (user_id, role)
 select u.id, 'admin' from auth.users u
 where lower(u.email) = lower('admin@churchfollowup.app')
   and not exists (select 1 from public.profiles p where p.user_id = u.id);

-- 3. Server-side lock (RESTRICTIVE policies combine with whatever policies you already have).
--    Only admins may write these collections. Other collections (members, followups, attendance,
--    souls, staff, tasks, chat...) are left to the app's own rules because staff devices write
--    to them automatically (e.g. follow-up status, graduation, duty ticks).
do $$ begin
  execute 'drop policy if exists admin_only_insert on public.records';
  execute 'drop policy if exists admin_only_update on public.records';
  execute 'drop policy if exists admin_only_delete on public.records';
end $$;

create policy admin_only_insert on public.records as restrictive for insert to authenticated
  with check (collection not in ('events','projects','smallGroups','volunteers','servingAssignments','plans') or public.is_admin());
create policy admin_only_update on public.records as restrictive for update to authenticated
  using (collection not in ('events','projects','smallGroups','volunteers','servingAssignments','plans') or public.is_admin())
  with check (collection not in ('events','projects','smallGroups','volunteers','servingAssignments','plans') or public.is_admin());
create policy admin_only_delete on public.records as restrictive for delete to authenticated
  using (collection not in ('events','projects','smallGroups','volunteers','servingAssignments','plans') or public.is_admin());

-- 4. Check: should list your admin email with role 'admin'
select u.email, p.role from public.profiles p join auth.users u on u.id = p.user_id order by p.role, u.email;
