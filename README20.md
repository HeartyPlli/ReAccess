# Fix Identity Verification Showing “Request Service Is Unavailable”

Use this guide when the Student or Faculty request form reaches **Identity
Verification**, but pressing **Verify Identity** shows:

```text
The request service is unavailable. Please try again later.
```

This problem is caused by two incorrect SQL parameter lists in the Dart API.
It is not caused by the information typed into the form.

## Important: what this fix changes

This fix changes only one Dart source file:

```text
backend/lib/src/modules/requests/request_store.dart
```

It does **not**:

- change the database structure;
- add or apply a migration;
- delete or edit database records;
- reset PostgreSQL;
- change API addresses;
- change administrator accounts; or
- require `docker compose down -v`.

Do not recreate the database. A database backup is not required for this code-only
fix, but keep your normal database backups.

## 1. Stop the API

1. Find the terminal running this command:

   ```text
   dart run bin/server.dart
   ```

2. Click inside that terminal.
3. Press `Ctrl+C` once.
4. Leave Docker Desktop and PostgreSQL running.
5. The Flutter website may remain open.

## 2. Make a backup copy of the Dart file

Open a new VS Code terminal and copy and paste:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub'
Copy-Item -LiteralPath 'backend\lib\src\modules\requests\request_store.dart' -Destination 'backend\lib\src\modules\requests\request_store.dart.before-readme20' -Force
Get-Item -LiteralPath 'backend\lib\src\modules\requests\request_store.dart.before-readme20' | Select-Object FullName,Length,LastWriteTime
```

Continue only if PowerShell shows the backup filename and its size is greater
than `0`.

## 3. Open the correct file in VS Code

1. In VS Code, look at the Explorer on the left.
2. Open `backend`.
3. Open `lib`.
4. Open `src`.
5. Open `modules`.
6. Open `requests`.
7. Click `request_store.dart`.
8. Press `Ctrl+F`.
9. Search for:

   ```text
   final params
   ```

You should arrive inside a method named `_verify`.

## 4. Correct the school registry query

Find this exact block:

```dart
final records = await session.execute(
  Sql.named(
    'SELECT * FROM school_registry WHERE person_id = @id AND active = true',
  ),
  parameters: params,
);
```

Replace only that block with:

```dart
final records = await session.execute(
  Sql.named(
    'SELECT * FROM school_registry WHERE person_id = @id AND active = true',
  ),
  parameters: {'id': data['personId']},
);
```

The query uses only `@id`, so its parameter list must contain only `id`.

## 5. Do not change the pending SSPR query

A few lines below, you will see a query beginning with:

```sql
SELECT 1 FROM account_requests
WHERE person_kind = @kind AND person_id = @id
```

Leave this line unchanged:

```dart
parameters: params,
```

That query uses both `@kind` and `@id`, so it needs both values.

Do not use VS Code **Replace All**. Only two specific lines must be changed.

## 6. Correct the Faculty request-count query

Press `Ctrl+F` and search for:

```text
SELECT count(*) FROM account_requests WHERE person_id
```

Find this block:

```dart
: await session.execute(
    Sql.named(
      'SELECT count(*) FROM account_requests WHERE person_id = @id',
    ),
    parameters: params,
  );
```

Replace only that block with:

```dart
: await session.execute(
    Sql.named(
      'SELECT count(*) FROM account_requests WHERE person_id = @id',
    ),
    parameters: {'id': data['personId']},
  );
```

This prevents the same error when Faculty information is verified.

Press `Ctrl+S` to save the file.

## 7. Check that the three parameter lists are correct

Open a VS Code terminal and run:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub\backend'
rg -n "parameters:" lib\src\modules\requests\request_store.dart
```

Inside the `_verify` method, the important result must be:

1. The school registry query uses:

   ```dart
   parameters: {'id': data['personId']},
   ```

2. The pending SSPR query still uses:

   ```dart
   parameters: params,
   ```

3. The Student request-limit query uses `id` and `type`.
4. The Faculty count query uses:

   ```dart
   parameters: {'id': data['personId']},
   ```

## 8. Format and check the backend

From the `backend` folder, copy and paste these commands one at a time:

```powershell
dart format lib/src/modules/requests/request_store.dart
```

```powershell
dart analyze
```

```powershell
dart test
```

Continue only when analysis has no code issues and all tests pass. If a command
shows a Dart syntax error, compare your edited blocks with Steps 4 and 6.

## 9. Start the API again

In a terminal, run:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub\backend'
dart run bin/server.dart
```

Wait until this appears:

```text
ReAccess API listening on http://0.0.0.0:8080
```

The command is supposed to keep running. Do not wait for it to finish and do not
close that terminal.

## 10. Test Student identity verification

1. Refresh the ReAccess Hub website.
2. Start a Student request.
3. Use a fake or authorized test Student that already exists in **Admin > Users**.
4. Enter the Student information exactly as stored in Admin.
5. Reach **Identity Verification**.
6. Click **Verify Identity**.
7. Confirm the request moves to the next step.

If the page now says the information does not match, the code fix is working.
Check the spelling, ID, active status, institute, and program against **Admin >
Users**.

If the page says there is already a pending SSPR enrollment, use a different test
record or finish the existing request. That is a normal safety rule.

## 11. Test Faculty identity verification

1. Start a Faculty request.
2. Use a fake or authorized Faculty record already present in **Admin > Users**.
3. Enter its six-character Faculty ID and matching information.
4. Click **Verify Identity**.
5. Confirm it moves to the next step.

Testing both Student and Faculty is important because the original problem existed
in two places.


