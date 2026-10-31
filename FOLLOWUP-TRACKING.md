# Follow-Up tracking: what was added

Built on top of the existing single-file app. No new tables or collections, so Supabase sync works unchanged: the new fields live on existing `members`, `followups` and `souls` records.

## Fields added
| Record | Field | Meaning |
|---|---|---|
| followup | `status: "resolved"` | Shown as **Done** |
| followup | `completedAt` (ISO date-time), `completedBy`, `completedSource` (`logged` or `baseline`) | Exact time the Follow-Up was completed. Set automatically whenever status becomes Done, cleared if reopened |
| followup | `priority` (`high`/`medium`/`low`, optional) | Manual override. When empty, priority is calculated automatically |
| member | `graduatedAt`, `graduatedFrom`, `health: "green"`, `register {addedAt, weeks, source}` | Set automatically on graduation |
| member / soul | `placeholder: true` | Marks the 33 opening-count placeholders |
| followup | `reopenedAt`, `reopenedFor`, `reopenCount`, `reason: "lapse"` | Set when a Done Follow-Up is reopened automatically because the person went Missing. `reopenedFor` is the last week they attended (or `never`) and identifies the lapse |

## Rules
- **Week** = Sunday to Saturday. Attended = ticked at Sunday Service or Wednesday Midweek Service.
- The week a person joins is a grace week: counts if attended, never counts as missed. The current week stays pending until it ends.
- **Attending** / **Missing**: Missing = 2+ missed weeks in a row, or has never attended after the grace week.
- **Health**: Green = 4+ consecutive weeks (graduates) · Amber = building · Red = Missing · Grey = new, not yet due. Regularity % = attended weeks of the last 8.
- **Graduation** (checked on every save): 4 consecutive weeks -> green, removed from New Converts / Guests, type becomes Member, appears in Church People Register.
- **Priority (auto)**: High = Missing, negative/left response, or check-in overdue 3+ days · Medium = check-in due or unreachable · Low = otherwise. High open items get a red border and an URGENT flag and sort first.
- **October count**: 33 souls for 2026-10, earliest 33 marked Done. Placeholders `#01`-`#33` (ids `soul_oct2026_NN`) fill any gap, dated 2026-10-31. Runs once; on signed-in devices it waits for the first sync so nothing is duplicated.
- **Auto-reopen**: if a person in New Converts / Guests has a Done Follow-Up and then turns Missing (2+ missed weeks in a row, or never attended after the grace week), the Follow-Up reopens as Open, High priority, due today, with a note saying why. Checked on load and on every save. It reopens once per lapse: closing it again while they are still Missing keeps it closed, and a new lapse after they return reopens it again. People who already have an open case, graduated people, archived people and the unnamed October placeholders are skipped.
- **Follow-Up categories**: the Follow-Up page has category chips: Souls won (has a soul record), New converts (new converts and guests not yet graduated), Missed services (church members whose follow-up came from a missed Sunday or midweek service), and Other (only shown when there is something in it). A person appears in the first category that fits. With All selected, cases are grouped under a heading per category. The priority chips count within the selected category.
- **New-case alerts**: a Follow-Up counts as new on a device when it is open and that device has not seen it yet (a new case, a missed-service case, a new soul, or a Done case that was reopened). The count shows as a red number on the Follow-Up button in the top bar, on the Follow-Up menu item, and on the installed app icon (Badging API). Opening the Follow-Up page clears it. When the app is open but not in view and alerts are switched on ("Turn on alerts" button in the top bar), a phone notification appears and tapping it opens the Follow-Up page. The first time this runs on a device, existing open cases are treated as already seen. Seen state is kept per device in localStorage.
- **Limit**: alerts are produced by the app itself, so they only update while the app is open or running in the background. Getting a notification while the app is fully closed needs a push server, which is not part of this single-file app. `service-worker.js` is now registered by the app, serves the app page network-first so updates arrive, and handles notification taps.
- **Admin dashboard**: a page called Admin dashboard in the menu, visible only when the signed-in account's role (from the Supabase `profiles` table) is `admin`. It shows totals, a searchable People list with Delete, a Tasks list with Edit / Delete / Add, Staff & roles, recent activity, and export / backup buttons.
- **Admin-only controls**: adding people (Add person, quick-add +, CSV import), deleting people, adding / editing / deleting projects and tasks, adding / editing staff, member-growth plans, restoring a backup and resetting demo data. For every other role these buttons are removed from the screen, and the app refuses the action even if it is triggered another way. Everyone can still use Team Chat, attendance, follow-ups, souls, messages, and change a task's status.
- **Team Chat name**: "You are chatting as" is now a text box where you type your name (press Enter). Staff names are offered as suggestions. Use the same name as on the Staff page so @tags for you reach you.
- **Important**: these restrictions are enforced in the app. For strict protection against someone using the database directly, the same rules should also be set as Supabase row-level security policies.
- **Admin role detection**: the role from the Supabase `profiles` table is read ignoring capital letters and spaces (`Admin`, `ADMIN`, `administrator` all count as admin). It is re-read when the app opens, when you return to it, and every 5 minutes, so changing someone to admin in Supabase works without signing out. A small label next to Sign out shows the role the app sees. To make an account an admin in Supabase: `update profiles set role = 'admin' where user_id = (select id from auth.users where email = 'you@example.com');`

