# Move the ReAccess Hub Database to Supabase

This guide moves PostgreSQL from this computer to Supabase. It does not deploy
the website or API; [README6.md](README6.md) does that afterward.

Practice with a separate Supabase staging project and fake data first. Never use
the production database as your first attempt.

## 1. Understand what changes

```text
Before: Flutter -> Dart API -> PostgreSQL on this computer
After:  Flutter -> Dart API -> PostgreSQL at Supabase
        Worker -------------> PostgreSQL at Supabase
```

The Flutter website still talks only to the Dart API. Do not put a Supabase key,
database password, or `JWT_SECRET` in Flutter.

ReAccess admin accounts remain in the `users` table. Creating a person in
Supabase Authentication does not create a ReAccess Hub administrator.

## 2. Choose exactly one migration path

| Your situation | Use |
| --- | --- |
| Old records are fake/disposable and the office approves a clean start | Path A in Section 8 |
| Old users, registry, requests, counters, messages, or logs must be kept | Path B in Section 9 |
| You are unsure | Path B after asking the office |

Do not run both paths on one Supabase project. Path A creates fresh tables and
seed data. Path B restores those same objects from a backup.

## 3. Install and check the PostgreSQL command-line tools

You need `psql`, `pg_dump`, and `pg_restore`.

1. Download the Windows installer from [PostgreSQL Downloads](https://www.postgresql.org/download/windows/).
2. Run the installer.
3. Keep **Command Line Tools** selected. A local server is optional if Docker is
   already your local database.
4. Finish the installer.
5. Close and reopen VS Code.
6. Open **Terminal > New Terminal** and run:

```powershell
psql --version
pg_dump --version
pg_restore --version
```
& "C:\Program Files\PostgreSQL\18\bin\pg_dump.exe" --version
& "C:\Program Files\PostgreSQL\18\bin\pg_restore.exe" --version

If a command is not recognized, find the installed `bin` folder, for example:

```text
C:\Program Files\PostgreSQL\17\bin
```

Then either add it to Windows PATH or use the full executable path. The number
may be different on your computer. Use client tools compatible with the source
and destination PostgreSQL versions.

## 4. Create the Supabase project

1. Open [Supabase](https://supabase.com/) and sign in with an office-controlled account.
2. Turn on multi-factor authentication for that account.
3. Choose the school's organization.
4. Click **New project**.
5. Name the practice project `reaccess-hub-staging`.
6. Choose a region near the application server. Singapore is a reasonable choice
   when approved for this school and available.
7. Use the password manager to generate a unique database owner password.
8. Paste it into the database-password field and save it in the password manager.
9. Choose the approved plan and click **Create new project**.
10. Wait until provisioning finishes.
11. Record the project reference, region, plan, and responsible maintainer in a
    private setup record. Do not record the password in that document.

Check current costs and backup coverage on the [Supabase pricing page](https://supabase.com/pricing)
before using real school data.

## 5. Disable the unused browser Data API

This project uses its own Dart API, so the Supabase-generated table API is not needed.

1. Open the Supabase project.
2. Open the **Data API** integration/settings area.
3. Find **Enable Data API**.
4. Turn it **Off**.
5. Confirm the change if asked.
6. Do not enable Realtime publication for ReAccess tables.

Supabase documents this setting in [Securing your API](https://supabase.com/docs/guides/api/securing-your-api).
The permissions in Section 10 are still required.

## 6. Copy the correct connection details

1. In the Supabase project, click **Connect** near the top.
2. For the long-running API, select **Session pooler**.
3. Copy the host, port, database, and username exactly. Do not guess the pooler host.
4. Save these non-secret details in the private setup record.
5. For `pg_dump`, `pg_restore`, and migrations, prefer the **Direct connection**
   when the workstation can reach its IP version. Supabase recommends direct
   connections for these tools.
6. If the workstation cannot reach the direct IPv6 endpoint, use an approved
   IPv6-capable maintenance environment or follow the provider's current guidance.
   Do not switch to the transaction pooler on port `6543` just to make it work.

The connection choices are explained in [Supabase PostgreSQL connections](https://supabase.com/docs/guides/database/connecting-to-postgres).

In PowerShell, create variables using the values copied from **Connect**:

```powershell
$sbHost = 'PASTE_THE_MAINTENANCE_HOST'
$sbPort = '5432'
$sbDatabase = 'postgres'
$sbOwner = 'postgres'
$env:PGSSLMODE = 'require'
```

For a shared session pooler, the owner username is normally
`postgres.PROJECT_REFERENCE`, not only `postgres`. Use the exact copied value.

Test the connection:

```powershell
psql -h $sbHost -p $sbPort -U $sbOwner -d $sbDatabase -W
```

At the password prompt, enter the Supabase database password. At `postgres=>`, run:

```sql
SELECT current_database(), current_user, version();
SELECT ssl FROM pg_stat_ssl WHERE pid = pg_backend_pid();
\q
```

Continue only when the intended project/user appears and SSL is true.

## 7. Create the restricted application login

The API and worker must not use the Supabase owner account.

1. Connect as the owner with the `psql` command from Section 6.
2. Check whether the role already exists:

```sql
SELECT rolname FROM pg_roles WHERE rolname = 'reaccess_app';
```

3. If it returns no row, paste:

```sql
CREATE ROLE reaccess_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE
  NOINHERIT NOREPLICATION NOBYPASSRLS;
\password reaccess_app
ALTER ROLE reaccess_app SET search_path = public;
GRANT CONNECT ON DATABASE postgres TO reaccess_app;
GRANT USAGE ON SCHEMA public TO reaccess_app;
\q
```

4. At the two password prompts, enter a new password generated by the password
   manager. Save it as `ReAccess Supabase application-role password`.

For the shared session pooler, the API username will normally be:

```text
reaccess_app.PROJECT_REFERENCE
```

For a direct connection it is `reaccess_app`. Use the exact form required by the
selected endpoint.

## 8. Path A - Start with an empty database

Skip this section if any old records must be kept.

1. Confirm the office approved discarding the old demo data.
2. Confirm this Supabase project does not already contain ReAccess tables.
3. Open VS Code at the repository root.
4. Set the Section 6 PowerShell variables.
5. Run the migrations one at a time:

```powershell
p/001_foundation.sql
psql -h $sbHost -p $sbPort -U $sbOwner -d $sbDatabase -W -v ON_ERROR_STOP=1 -f backend/migrations/002_support.sql
psql -h $sbHost -p $sbPort -U $sbOwner -d $sbDatabase -W -v ON_ERROR_STOP=1 -f backend/migrations/003_account_requests.sql
psql -h $sbHost -p $sbPort -U $sbOwner -d $sbDatabase -W -v ON_ERROR_STOP=1 -f backend/migrations/004_admin_portal.sql
psql -h $sbHost -p $sbPort -U $sbOwner -d $sbDatabase -W -v ON_ERROR_STOP=1 -f backend/migrations/005_registry_management.sql
psql -h $sbHost -p $sbPort -U $sbOwner -d $sbDatabase -W -v ON_ERROR_STOP=1 -f backend/migrations/006_rsql -h $sbHost -p $sbPort -U $sbOwner -d $sbDatabase -W -v ON_ERROR_STOP=1 -f backend/migrationsequest_configuration.sql
psql -h $sbHost -p $sbPort -U $sbOwner -d $sbDatabase -W -v ON_ERROR_STOP=1 -f backend/migrations/007_registry_edit_delete.sql
psql -h $sbHost -p $sbPort -U $sbOwner -d $sbDatabase -W -v ON_ERROR_STOP=1 -f backend/migrations/008_faculty_id_format.sql
```

6. After every command, run:

```powershell
$LASTEXITCODE
```

`0` means success. Stop on any other number. Do not continue and hope a later
migration fixes it.

7. Continue to Section 10. Do not run Path B on this project.

## 9. Path B - Keep the existing records

Skip this section if you completed Path A.

### 9.1 Freeze the old system

1. Schedule a maintenance window.
2. Confirm migrations `001` through `008` are already present on the old database.
3. Create and restore-test a backup using [README2.md](README2.md).
4. Stop every old API and notification worker:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub'
docker compose stop api notifications
```

5. Leave PostgreSQL running.
6. Record pending/failed/sent notification counts so old messages are not resent.

### 9.2 Create the final private dump

Use the local source owner account and the real source settings:

```powershell
$sourceHost = '127.0.0.1'
$sourcePort = '5432'
$sourceDatabase = 'reaccess_hub'
$sourceOwner = 'postgres'
$backupFile = 'C:\ReAccessBackups\reaccess-before-supabase.dump'
$env:PGSSLMODE = 'prefer'
pg_dump -h $sourceHost -p $sourcePort -U $sourceOwner -d $sourceDatabase -W --format=custom --schema=public --no-owner --no-privileges --file=$backupFile
Get-Item -LiteralPath $backupFile | Select-Object FullName,Length,LastWriteTime
pg_restore --list $backupFile
```

Check that `pg_dump` returns exit code `0`:

```powershell
$LASTEXITCODE
```

The dump includes personal information and password hashes. Keep it encrypted and private.

### 9.3 Make a restore list

Supabase already owns the `public` schema, so do not recreate that one namespace.

```powershell
pg_restore --list $backupFile | Set-Content -Encoding utf8 'C:\ReAccessBackups\restore-list.txt'
code 'C:\ReAccessBackups\restore-list.txt'
```

In the opened text file:

1. Find the line whose description is `SCHEMA - public`.
2. Add `;` to the very beginning of only that line.
3. If there is a `COMMENT - SCHEMA public` line, add `;` to that line too.
4. Do not comment out ReAccess tables, data, functions, indexes, triggers, or constraints.
5. Save with `Ctrl+S`.

If extension entries appear, ask the database maintainer to compare them with
Supabase **Database > Extensions**. Do not guess.

### 9.4 Restore once into the empty destination

Confirm the destination has no ReAccess tables. Then set the Supabase variables
from Section 6 and run:

```powershell
$env:PGSSLMODE = 'require'
pg_restore -h $sbHost -p $sbPort -U $sbOwner -d $sbDatabase -W --no-owner --no-privileges --exit-on-error --single-transaction --use-list='C:\ReAccessBackups\restore-list.txt' $backupFile
$LASTEXITCODE
```

`0` is required. Do not use `--clean`, `--create`, or restore managed Supabase
schemas such as `auth` or `storage`. Do not rerun all migrations after a complete
current-schema restore.

## 10. Apply the backend permissions and row policies

Do this after either Path A or Path B.

1. Connect as the Supabase owner with `psql`.
2. Paste the whole block below:

```sql
BEGIN;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO reaccess_app;

DO $setup$
DECLARE
  table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'users', 'roles', 'permissions', 'user_roles', 'role_permissions',
    'announcements', 'audit_logs', 'support_tickets', 'school_registry',
    'request_monthly_counters', 'account_requests', 'academic_periods',
    'portal_settings', 'request_messages', 'notification_outbox',
    'institutions', 'institution_programs'
  ] LOOP
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM PUBLIC, anon, authenticated, service_role', table_name);
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM reaccess_app', table_name);
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', table_name);
    EXECUTE format('DROP POLICY IF EXISTS reaccess_backend_access ON public.%I', table_name);
    EXECUTE format('CREATE POLICY reaccess_backend_access ON public.%I FOR ALL TO reaccess_app USING (true) WITH CHECK (true)', table_name);
    IF table_name = 'audit_logs' THEN
      EXECUTE format('GRANT SELECT, INSERT ON TABLE public.%I TO reaccess_app', table_name);
    ELSE
      EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.%I TO reaccess_app', table_name);
    END IF;
  END LOOP;
END;
$setup$;

REVOKE EXECUTE ON FUNCTION public.assign_request_semester() FROM PUBLIC, anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.stamp_audit_context() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.assign_request_semester() TO reaccess_app;
GRANT EXECUTE ON FUNCTION public.stamp_audit_context() TO reaccess_app;
COMMIT;
```

3. If any error appears, stop and have the database maintainer inspect it.
4. For every future migration, add restricted grants/policies for new objects.

The backend role intentionally reads/writes application rows, while the Dart API
checks user permissions. It must not be a superuser, table owner, or `BYPASSRLS` role.

## 11. Verify the migrated records

As the owner, run:

```sql
SELECT 'users' AS table_name, count(*) FROM public.users
UNION ALL SELECT 'school_registry', count(*) FROM public.school_registry
UNION ALL SELECT 'account_requests', count(*) FROM public.account_requests
UNION ALL SELECT 'audit_logs', count(*) FROM public.audit_logs
UNION ALL SELECT 'request_messages', count(*) FROM public.request_messages
UNION ALL SELECT 'notification_outbox', count(*) FROM public.notification_outbox;

SELECT * FROM public.request_monthly_counters ORDER BY person_kind, request_month;
SELECT status, channel, count(*) FROM public.notification_outbox GROUP BY 1, 2;
SELECT semester, academic_year, start_date, end_date FROM public.academic_periods;
```

For Path B, compare every table count with the frozen source. Keep the old monthly
counters; resetting them can reuse request references. Review old notification
jobs and Windows attachment paths before starting a Linux worker.

Now test as the app role. For the session pooler:

```powershell
$sbAppUser = 'reaccess_app.PASTE_PROJECT_REFERENCE'
psql -h $sbHost -p $sbPort -U $sbAppUser -d $sbDatabase -W
```

Then run:

```sql
SELECT current_user, current_database();
SELECT count(*) FROM public.account_requests;
SELECT has_table_privilege(current_user, 'public.audit_logs', 'SELECT') AS can_read,
       has_table_privilege(current_user, 'public.audit_logs', 'INSERT') AS can_add,
       has_table_privilege(current_user, 'public.audit_logs', 'UPDATE') AS can_edit,
       has_table_privilege(current_user, 'public.audit_logs', 'DELETE') AS can_delete,
       has_table_privilege(current_user, 'public.audit_logs', 'TRUNCATE') AS can_truncate;
\q
```

Expected audit result: `true, true, false, false, false`.

## 12. Point the local Dart API to Supabase

1. Make a private copy of the current `backend/.env` so you can return to local PostgreSQL.
2. In VS Code, press `Ctrl+P`, type `backend/.env`, and press Enter.
3. Replace the database section with the exact Session pooler values:

```dotenv
APP_ENV=development
API_HOST=0.0.0.0
API_PORT=8080
ALLOWED_ORIGINS=http://localhost:3000
DATABASE_HOST=PASTE_THE_SESSION_POOLER_HOST
DATABASE_PORT=5432
DATABASE_NAME=postgres
DATABASE_USER=reaccess_app.PASTE_PROJECT_REFERENCE
DATABASE_PASSWORD=PASTE_THE_APPLICATION_ROLE_PASSWORD
DATABASE_SSL=true
SKIP_DATABASE_CONNECTION=false
JWT_SECRET=PASTE_A_RANDOM_SECRET_OF_AT_LEAST_32_CHARACTERS
```

Do not add quotes. Do not use the owner password. Press `Ctrl+S`.

4. Start the API from `backend`:

```powershell
dart run bin/server.dart
```

5. In a separate root terminal, start Flutter:

```powershell
flutter run -d chrome --web-port 3000 --dart-define=API_BASE_URL=http://localhost:8080/api/v1
```

6. Sign in and confirm records are from Supabase.
7. If Path A has no admin, stop the API temporarily and run from `backend`:

```powershell
dart run bin/create_admin.dart
```

The supplied Docker Compose API always points to its `postgres` service. Use the
local Dart process for this test; README6 explains the production Render settings.

## 13. Run the staging acceptance test

Using fake records and consenting notification recipients:

1. Submit all six Student/Faculty request combinations.
2. Test wrong identity and duplicate SSPR rejection.
3. Confirm monthly request references continue correctly.
4. Approve, reject, reconsider, complete, and finish SSPR enrollment.
5. Test messages, academic periods, PDFs, and audit CSVs.
6. Restart the API and confirm records remain.
7. Test wrong admin credentials and unauthorized API access.
8. Test a controlled database outage and document recovery/restart behavior.

## 14. Final switch and rollback

1. Repeat the full process in the agreed maintenance window.
2. Stop old writers and make a fresh final backup. A rehearsal backup is stale.
3. Restore into a clean final project and compare counts again.
4. Keep the worker stopped until pending jobs and attachment paths are reviewed.
5. Deploy with [README6.md](README6.md).
6. Open public access only after the online acceptance test passes.
7. Keep the old database and encrypted backup for the approved recovery period.

If the new database has received requests, do not simply switch back. Stop both
systems and reconcile the newer records first so no requests or messages are lost.

## 15. Supabase backup steps

1. Open the Supabase project.
2. Go to **Database > Backups**.
3. Read the actual coverage and retention for the selected plan.
4. Keep separate encrypted logical backups according to school policy.
5. Practice a restore into a separate project.
6. After a managed restore, reset custom-role passwords if required and retest the app.

Supabase's current backup behavior is documented in [Database Backups](https://supabase.com/docs/guides/platform/backups).
Database backups do not replace backups of the letter file, secrets recovery
procedure, provider configuration, or application source.

## 16. Troubleshooting

| Problem | Check |
| --- | --- |
| Direct host cannot be reached | IP version support; use an approved maintenance environment |
| Tenant/user not found | Exact pooler host and `.PROJECT_REFERENCE` username suffix |
| Password authentication failed | Correct owner/app-role password; not dashboard password or API key |
| Permission denied | Section 10 grants, policies, `current_user`, and ownership |
| Rows visible as owner but not app role | RLS policy and SQL grants for `reaccess_app` |
| Table already exists | Destination was not empty or both paths were used |
| Restore version error | Compatible PostgreSQL client/server versions |
| SSL error | Correct host/port and `PGSSLMODE=require`; do not disable TLS |
| Login works locally but not production | Environment target, temporary password flag, and CORS |
| Worker attachment fails | Old Windows path in outbox or missing file in deployed image |

## Completion checklist

- [ ] Path A or Path B selected, never both.
- [ ] Staging rehearsal completed first.
- [ ] Owner and app-role passwords stored separately and securely.
- [ ] Data API disabled.
- [ ] Restricted grants and RLS policy verified.
- [ ] Records/counters match, or clean start is approved.
- [ ] API uses the restricted role and TLS.
- [ ] Strong admin works.
- [ ] Pending notification jobs reviewed.
- [ ] Backup, restore drill, and rollback plan pass.

Next: follow [README6.md](README6.md) to deploy the API, worker, and Flutter website.



## 12. Apply the fix to the deployed version

The local edit does not automatically update the online website.

1. Finish the local tests first.
2. Commit and push the corrected source to the private GitHub repository used by
   Render.
3. Open the Render dashboard.
4. Open the ReAccess API Web Service.
5. Open **Deploys**.
6. Confirm Render deploys the commit containing this correction. If automatic
   deployment is disabled, select **Manual Deploy > Deploy latest commit**.
7. Wait for the deployment to finish successfully.
8. Open the deployed website.
9. Test one Student and one Faculty identity verification using controlled test
   records.

No Render environment variable, Supabase migration, Flutter rebuild, notification
worker change, or database reset is required for this correction.

## 13. Roll back the local code if the edit was entered incorrectly

Use this only to restore the source file created in Step 2. It does not affect the
database.

1. Stop the API with `Ctrl+C`.
2. Run:

   ```powershell
   Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub'
   Copy-Item -LiteralPath 'backend\lib\src\modules\requests\request_store.dart.before-readme20' -Destination 'backend\lib\src\modules\requests\request_store.dart' -Force
   ```

3. Start the API again.
4. Ask the maintainer to review Steps 4 and 6 before trying the correction again.

## Final checklist

- [ ] The API was stopped before editing.
- [ ] A backup copy of `request_store.dart` exists.
- [ ] Only the two queries that use only `@id` were changed.
- [ ] The pending SSPR query still uses `parameters: params`.
- [ ] `dart format` finished.
- [ ] `dart analyze` reported no code issues.
- [ ] `dart test` passed.
- [ ] The API was restarted.
- [ ] Student verification was tested.
- [ ] Faculty verification was tested.
- [ ] The deployed API was updated and tested if the system is already online.
