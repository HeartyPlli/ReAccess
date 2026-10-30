# ReAccess Hub Database - Beginner Guide

Use this guide after the local setup in [README.md](README.md). It explains what
the database stores, how to back it up, how to upgrade it, and how to add the
school registry records used to verify requests.

Use fake people while learning. A registry export and a database backup contain
private information and must stay outside this project folder.

## 1. Know what the database does

| Item | Simple meaning |
| --- | --- |
| `school_registry` | Trusted student and faculty account list |
| `account_requests` | Submitted SSPR, Recovery, and Update requests |
| `request_monthly_counters` | Creates unique monthly request numbers |
| `users` | Admin login accounts |
| `audit_logs` | Security and activity history |
| `notification_outbox` | Email and SMS jobs waiting for the worker |

The Flutter website must never connect directly to PostgreSQL. The safe path is:

```text
Browser -> Dart API -> PostgreSQL
```

## 2. New database: let Docker create it

Use this section only when you do not need old data.

1. Finish Steps 1 through 7 in [README.md](README.md).
2. Start Docker Desktop and wait for it to say it is running.
3. In VS Code, click **Terminal > New Terminal**.
4. Run:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub'
docker compose up -d postgres
docker compose ps
docker compose logs --tail 100 postgres
```

5. Look for `database system is ready to accept connections`.
6. Check the tables:

```powershell
docker compose exec postgres psql -U postgres -d reaccess_hub -c "\dt"
```

You should see tables including `users`, `school_registry`, `account_requests`,
`academic_periods`, `request_messages`, and `notification_outbox`.

The migration files are `backend/migrations/001_foundation.sql` through
`008_faculty_id_format.sql`. Docker runs them only when its database volume is
brand new. Restarting an existing container does not rerun them.

## 3. Back up an existing Docker database

Do this before a migration, bulk import, deployment, or major code update.

### 3.1 Create a private backup folder

1. Open Windows File Explorer.
2. Open `C:\`.
3. Click **New > Folder**.
4. Name it `ReAccessBackups`.
5. Right-click the folder, choose **Properties > Security**, and allow only the
   authorized maintainer accounts.
6. If the school provides encrypted storage, copy finished backups there too.

Do not create the backup folder inside `reaccess_hub` or a GitHub-synced folder.

### 3.2 Create the database dump

In a VS Code terminal at the project root, run:

```powershell
$backupStamp = Get-Date -Format 'yyyy-MM-dd-HHmmss'
$backupFile = "C:\ReAccessBackups\reaccess-$backupStamp.dump"
docker compose exec postgres pg_dump -U postgres -d reaccess_hub --format=custom --file=/tmp/reaccess-backup.dump
docker compose cp postgres:/tmp/reaccess-backup.dump $backupFile
Get-Item -LiteralPath $backupFile | Select-Object FullName,Length,LastWriteTime
```

Success means the last command shows a file with a size greater than `0`.

### 3.3 Check that the dump can be read

Run:

```powershell
docker compose exec postgres pg_restore --list /tmp/reaccess-backup.dump
```

You should see a long list of tables and other database objects. A file existing
is not enough; the school must also practice the restore in the next section.

### 3.4 Back up the other required files

Copy these to approved encrypted storage:

- `.env`
- `backend/.env`
- `backend/templates/formal-letter.docx`
- the matching source release or private repository revision

These contain secrets or configuration. Do not commit the copies to Git.

## 4. Practice restoring without touching the real database

This creates a separate database called `reaccess_restore_test`. It does not
replace `reaccess_hub`.

1. Keep the PostgreSQL container running.
2. If the backup file is no longer inside the container, copy it in. Replace the
   date in the path with your real file name:
"C:\ReAccessBackups\reaccess-2026-"
```powershell
docker compose cp 'C:\ReAccessBackups\reaccess-2026-10-29-120000.dump' postgres:/tmp/restore-test.dump
```
docker compose cp 'C:\ReAccessBackups\reaccess-2026-10-29-182354.dump' postgres:/tmp/restore-test.dump

""
3. Create the separate test database:

```powershell
docker compose exec postgres createdb -U postgres reaccess_restore_test
```

4. Restore into that test database:

```powershell
docker compose exec postgres pg_restore -U postgres -d reaccess_restore_test --no-owner --no-privileges --exit-on-error /tmp/restore-test.dump
```

5. Count important records:

```powershell
docker compose exec postgres psql -U postgres -d reaccess_restore_test -c "SELECT count(*) AS users FROM users; SELECT count(*) AS registry FROM school_registry; SELECT count(*) AS requests FROM account_requests;"
```

6. Record the date, backup file, result, and maintainer in a private operations log.
7. After the restore test is approved and no one needs the test database, remove
   only that test database:

```powershell
docker compose exec postgres dropdb -U postgres reaccess_restore_test
```

Read the database name twice before running the last command. Never type
`reaccess_hub` there.

## 5. Upgrade an existing database

Do not erase the Docker volume to get new tables. `docker compose down -v`
permanently deletes the local database volume.

1. Complete and verify the backup in Sections 3 and 4.
2. Tell users about the maintenance window.
3. Stop the API and notification worker but leave PostgreSQL running:

```powershell
docker compose stop api notifications
```

4. Check which tables already exist:

```powershell
docker compose exec postgres psql -U postgres -d reaccess_hub -c "\dt"
```

5. Apply only missing migrations, in number order. These commands show how to
   apply `003`, `004`, `005`, `006`, `007`, and `008`. Do not rerun a migration just because it appears
   in this example.

```powershell
docker compose cp backend/migrations/003_account_requests.sql postgres:/tmp/003.sql
docker compose exec postgres psql -U postgres -d reaccess_hub -v ON_ERROR_STOP=1 -f /tmp/003.sql

docker compose cp backend/migrations/004_admin_portal.sql postgres:/tmp/004.sql
docker compose exec postgres psql -U postgres -d reaccess_hub -v ON_ERROR_STOP=1 -f /tmp/004.sql

docker compose cp backend/migrations/005_registry_management.sql postgres:/tmp/005.sql
docker compose exec postgres psql -U postgres -d reaccess_hub -v ON_ERROR_STOP=1 -f /tmp/005.sql

docker compose cp backend/migrations/006_request_configuration.sql postgres:/tmp/006.sql
docker compose exec postgres psql -U postgres -d reaccess_hub -v ON_ERROR_STOP=1 -f /tmp/006.sql
docker compose cp backend/migrations/007_registry_edit_delete.sql postgres:/tmp/007.sql
docker compose exec postgres psql -U postgres -d reaccess_hub -v ON_ERROR_STOP=1 -f /tmp/007.sql
docker compose cp backend/migrations/008_faculty_id_format.sql postgres:/tmp/008.sql
docker compose exec postgres psql -U postgres -d reaccess_hub -v ON_ERROR_STOP=1 -f /tmp/008.sql
```

6. Stop immediately if any command shows an error.
7. Reapply the restricted application-role grants:

```powershell
docker compose exec postgres sh /docker-entrypoint-initdb.d/999-grant-app.sh
```

8. Check the tables again with `\dt`.
9. Start the API and test with fake data before reopening the system.

Migration `005` makes `school_registry.person_id` unique across the entire
registry. If the same ID exists as both Student and Faculty, the migration stops.
Ask the CISO Office which record is correct before changing anything.

## 6. Prepare a registry file for the admin page

The easiest format for **Admin > Manage Users > Import** is CSV.

You can prepare and save the CSV before the admin portal is ready. Steps 10-12
below require all three of these to be working first:

1. Activate or create the administrator using [README3.md](README3.md), Section 1.
2. Start the API using [README.md](README.md), Step 10.
3. Start Flutter using [README.md](README.md), Step 11.

If the login page says `Unable to connect to the server`, the page cannot reach
the API. This is not a CSV problem and does not mean the password is wrong. Start
the API, confirm `http://localhost:8080/health` opens, and then try signing in.
It is okay to stop after Step 9 here and return to Steps 10-12 after completing
the administrator setup.

1. In VS Code, click **File > New Text File**.
2. Paste this example:
 
```csv
person_kind,person_id,first_name,middle_name,last_name,institute,program,position,school_email,contact,gmail,active
STUDENT,244028,Heart,Quimbo,Cruz,Institute of Computer Studies,Bachelor of Science in Computer Science,,cagadasheart@gadtc.edu.ph,09486778394,cagadasheart2136@gmail.com,true
FACULTY,ABC111,Sample,,Sample,Institute of Computer Studies,,Full Time,sample@gadtc.edu.ph,09112233445,sample@gmail.com,true
```

3. Press `Ctrl+Shift+S` and save it as `registry-import.csv` in a private folder
   outside this repository.
4. Double-click the saved CSV to open it in Excel.
5. Replace the fake rows with the approved office data.
6. Keep the header names exactly as shown.
7. In Excel, click **File > Save As > Browse**.
8. For **Save as type**, choose **CSV UTF-8 (Comma delimited) (*.csv)**.
9. Click **Save** and accept the CSV-format warning if Excel shows one.
10. In ReAccess Hub, sign in as an authorized admin.
11. Open **Manage Users**.
12. Click the import control, choose the CSV, review the result, and keep the
    private source file according to school policy.

Imports accept at most 1,000 rows and 5 MB in the admin page. Existing IDs are
skipped and reported; valid new rows can still be added.

Required columns:

```text
person_kind, person_id, first_name, last_name, institute, school_email
```

Optional columns:

```text
middle_name, program, position, contact, gmail, active
```

Students need `program`; faculty need `position`. Use `STUDENT` or `FACULTY` for
`person_kind`. Do not invent institute or program spellings; use the choices
shown by the request form.

## 7. Import a large trusted JSON file from the terminal

Only a database maintainer should use this command. It can update existing
registry details.

1. In VS Code, click **File > New Text File**.
2. Paste this fake example:

```json
[
  {
    "personKind": "STUDENT",
    "fields": {
      "firstName": "Juan",
      "middleName": "",
      "lastName": "Cruz",
      "personId": "123456",
      "institute": "Institute of Computer Studies",
      "program": "Bachelor of Science in Computer Science",
      "schoolEmail": "cruzjuan@gadtc.edu.ph"
    }
  },
  {
    "personKind": "FACULTY",
    "fields": {
      "firstName": "Maria",
      "middleName": "",
      "lastName": "Santos",
      "personId": "FAC-654321",
      "institute": "Institute of Teacher Education",
      "position": "Full Time",
      "schoolEmail": "santosmaria@gadtc.edu.ph"
    }
  }
]
```

3. Replace the fake records with approved data.
4. Click **File > Save As** and save it outside the repository, for example
   `C:\PrivateReAccess\registry.json`.
5. Confirm `backend/.env` points to the intended database.
6. Back up the database first.
7. Open a terminal and run:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub\backend'
dart run bin/import_registry.dart 'C:\PrivateReAccess\registry.json'
```

8. Expect `Imported ... registry records`.
9. If it fails, no partial batch is committed. Fix the file and try again only
   after reading the error and confirming the database target.

The terminal importer accepts up to 10,000 records. An existing ID is updated,
but its active status is not changed by this JSON command.

## 8. Field rules to confirm with the CISO Office

- Student ID: exactly six digits, including leading zeroes.
- Faculty ID: letters and hyphens are allowed, but it must contain exactly six digits.
- Personal or alternate email: Gmail address.
- Philippine mobile: `09` plus nine digits, or `+639` plus nine digits.
- School email: normally lower-case `lastnamefirstname@gadtc.edu.ph`.
- Student uses institute and program; faculty uses institute and position.
- All three request types require an active matching registry row.
- SSPR also blocks another active pending enrollment for the same ID.

Name, ID, and institute matching is not strong proof of identity. Staff must
follow the CISO Office identity-check procedure before changing an account.

## 9. Test that the database really works

Use the fake Juan and Maria records or other approved test records.

1. Start PostgreSQL, API, and Flutter using [README.md](README.md).
2. Submit Student Account Recovery with matching data.
3. Change one name letter and verify that matching fails without revealing the
   saved registry record.
4. Submit Faculty Account Update and change only one contact field.
5. Submit SSPR for an active registry record.
6. Try the same SSPR again and confirm the pending request blocks it.
7. Sign in as admin and confirm every request has a unique reference.
8. Restart PostgreSQL and the API, then confirm the records still exist.
9. Stop PostgreSQL and confirm the website does not show a false success receipt.
10. Test without an admin token and confirm protected pages/API calls are rejected.

## 10. Important safety rules

- Never use `SKIP_DATABASE_CONNECTION=true` for real requests.
- Never place a PostgreSQL password or JWT secret in Flutter code or a
  `--dart-define` value.
- Never edit old audit rows to make a report look different.
- Never delete a Docker volume as an upgrade method.
- Never restore a backup over production until new records created after that
  backup have been identified and reconciled.
- Keep database port `5432` private; the supplied Docker setup binds it only to
  this computer.

Next: follow [README3.md](README3.md) to create real admins, configure semesters,
and set up Gmail and Twilio.
