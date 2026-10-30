# Immediate Update - Six-Character Faculty IDs

Complete this guide **before adding Faculty records or continuing deployment**.
It changes Faculty IDs to exactly six letters and/or numbers.

Accepted examples:

- `AB1234`
- `ACB123`
- `1921GA`
- `ABCDEF`
- `123456`

Spaces, hyphens, underscores, and IDs shorter or longer than six characters are
not accepted. Student IDs remain exactly six numbers.

This update changes a PostgreSQL validation rule, so migration
`008_faculty_id_format.sql` must be applied to the current database.

## 1. Stop the API and notification worker

1. Open the terminal running `dart run bin/server.dart`.
2. Press `Ctrl+C` once.
3. If a notification-worker terminal is running, open it and press `Ctrl+C`.
4. Leave Docker Desktop and the PostgreSQL container running.

## 2. Create and check a backup

Open a new VS Code PowerShell terminal. Copy and paste this entire block:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub'
New-Item -ItemType Directory -Force -Path 'C:\ReAccessBackups'
$backupStamp = Get-Date -Format 'yyyy-MM-dd-HHmmss'
$backupFile = "C:\ReAccessBackups\before-migration-008-$backupStamp.dump"
docker compose exec postgres pg_dump -U postgres -d reaccess_hub --format=custom --file=/tmp/before-008.dump
docker compose cp postgres:/tmp/before-008.dump $backupFile
Get-Item -LiteralPath $backupFile | Select-Object FullName,Length,LastWriteTime
docker compose exec postgres pg_restore --list /tmp/before-008.dump
```

Continue only when the backup file exists, its `Length` is greater than `0`,
and `pg_restore --list` shows database objects without an error.

## 3. Check existing IDs before changing the rule

Copy and paste:

```powershell
docker compose exec postgres psql -U postgres -d reaccess_hub -P pager=off -c "SELECT person_kind,person_id FROM school_registry WHERE (person_kind='STUDENT' AND person_id !~ '^[0-9]{6}$') OR (person_kind='FACULTY' AND person_id !~ '^[A-Z0-9]{6}$') ORDER BY person_kind,person_id;"
```

The correct result is:

```text
(0 rows)
```

If any Student or Faculty row appears, **stop**. Do not apply migration 008 and
do not delete the person. The ID and its related records need a separate,
reviewed correction plan.

## 4. Apply only migration 008

Copy and paste:

```powershell
docker compose cp backend/migrations/008_faculty_id_format.sql postgres:/tmp/008_faculty_id_format.sql
docker compose exec postgres psql -U postgres -d reaccess_hub -v ON_ERROR_STOP=1 -f /tmp/008_faculty_id_format.sql
```

The last line must be:

```text
COMMIT
```

If an error appears, stop. Keep the API off and keep the backup. Do not run
`docker compose down -v`.

## 5. Verify migration 008

Copy and paste:

```powershell
docker compose exec postgres psql -U postgres -d reaccess_hub -P pager=off -c "SELECT conname,pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid='school_registry'::regclass AND conname='school_registry_person_id_format_check';"
```

The result must contain both:

```text
^[0-9]{6}$
^[A-Z0-9]{6}$
```

## 6. Restart the backend and website

Terminal 1:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub\backend'
dart run bin/server.dart
```

Leave Terminal 1 running when it says `ReAccess API listening`.

Terminal 2:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub'
flutter run -d chrome --web-port 3000 --dart-define=API_BASE_URL=http://localhost:8080/api/v1
```

## 7. Test with a fake Faculty record

1. Sign in to Admin.
2. Open **Users**.
3. Select **Faculty**.
4. In **Add one user**, enter a fake Faculty ID such as `AB1234`.
5. Complete the other required fields and add the record.
6. Confirm it appears in the Faculty list.
7. Delete the fake record using the trash button when testing is finished.

Do not use a real person's information for this test.

## 8. Academic Period Edit button

The Academic Period Edit button does **not** need another migration. The
`academic_periods` table from migration 004 already allows the start and end
dates to be updated.

After restarting the updated API and Flutter website:

1. Sign in to Admin.
2. Open **Settings**.
3. Expand **Academic Period**.
4. Find the saved semester.
5. Click the edit/pencil button on the far right.
6. Change the semester, academic year, start date, or end date.
7. Click **Save changes**.
8. Wait for `Academic period updated.`

The system refuses a date range that overlaps another academic period. Existing
requests keep their connection to the same period because its database ID is not
changed.

## 9. Confirm the default institutions and programs

Migration 006 already adds these six institutions:

1. Institute of Computer Studies
2. Institute of Health Sciences
3. Institute of Art and Sciences
4. Institute of Teacher Education
5. Institute of Business and Financial Services
6. Institute of Criminal Justice Education

Their connected programs appear automatically under each institution in
**Settings > Institution** and in the Student request form. The updated Settings
page opens this list and its programs automatically.

To verify the current database without changing it, run:

```powershell
docker compose exec postgres psql -U postgres -d reaccess_hub -c "SELECT i.name AS institution,p.name AS program FROM institutions i LEFT JOIN institution_programs p ON p.institution_id=i.id AND p.active=true WHERE i.active=true ORDER BY i.name,p.name;"
```

The normal seeded result contains six institutions and sixteen programs. Do not
rerun migration 006 only to change their display order.
