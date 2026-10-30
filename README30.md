# Admin Chat List - Permanently Delete a Support Conversation

This guide explains the delete button added to:

```text
Admin Portal > Messages > Public Help Chat
```

Each support conversation now shows the verified Student or Faculty ID and a
trash/delete button. The administrator must enter their current username and
password before the selected conversation is permanently deleted.

## 1. Understand what the delete button does

Deleting a support conversation:

- permanently removes the selected row from the `support_tickets` database
  table;
- removes that conversation from the Admin chat list;
- prevents the visitor from checking that conversation for another reply;
- keeps a `SUPPORT_DELETED` entry in `audit_logs`;
- does not delete the Student or Faculty from `school_registry`;
- does not delete account-service requests;
- does not delete administrator accounts; and
- does not affect other chat conversations.

The action cannot be undone from the Admin Portal. Only delete conversations
that the CISO Office is allowed to remove under its approved record-retention
procedure.

## 2. Database and migration information

This feature uses the existing `support_tickets` and `audit_logs` tables.

There is **no new SQL migration** to apply. Do not recreate the database and do
not run:

```text
docker compose down -v
```

The database changes only when an administrator confirms a deletion. At that
time, the selected support ticket is removed and a separate audit entry is
created.

## 3. Files used by this feature

The implementation is in:

```text
backend/lib/src/modules/support/support_routes.dart
backend/lib/src/modules/support/support_store.dart
lib/features/admin/presentation/pages/support_inbox.dart
lib/features/admin/presentation/pages/portal_list_page.dart
```

The backend tests are in:

```text
backend/test/support_test.dart
```

## 4. Create a database backup before first use

The feature is designed to delete one selected support conversation. Create a
backup before testing permanent deletion for the first time.

Open a new VS Code terminal and copy and paste:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub'
New-Item -ItemType Directory -Force -Path 'C:\ReAccessBackups'
$backupStamp = Get-Date -Format 'yyyy-MM-dd-HHmmss'
$backupFile = "C:\ReAccessBackups\before-chat-delete-$backupStamp.dump"
docker compose exec postgres pg_dump -U postgres -d reaccess_hub --format=custom --file=/tmp/before-chat-delete.dump
docker compose cp postgres\:/tmp/before-chat-delete.dump $backupFile
Get-Item -LiteralPath $backupFile | Select-Object FullName,Length,LastWriteTime
docker compose exec postgres pg_restore --list /tmp/before-chat-delete.dump
```

Stop if the backup file is missing, its size is `0`, or `pg_restore --list`
shows an error.

## 5. Check the code

Open a terminal at the project root and run:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub\backend'
dart format lib/src/modules/support/support_routes.dart lib/src/modules/support/support_store.dart test/support_test.dart
dart analyze
dart test
```

Then check Flutter from the project root:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub'
flutter analyze
flutter test
```

Continue only after analysis has no code issues and all tests pass.

## 6. Restart the local API

If the API is already running:

1. Find the terminal showing `ReAccess API listening`.
2. Click inside that terminal.
3. Press `Ctrl+C` once.

Start the API again:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub\backend'
dart run bin/server.dart
```

Leave the terminal open after this appears:

```text
ReAccess API listening on http://0.0.0.0:8080
```

Only one API should use port `8080`. If Windows says the port is already in use,
stop the older API terminal before running the command again.

## 7. Restart the local Flutter website

If Flutter is already running, use its terminal and press `R` for a full hot
restart. If the new button does not appear, stop Flutter with `Ctrl+C` and run:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub'
flutter run -d chrome --web-port 3000 --dart-define=API_BASE_URL=http://localhost:8080/api/v1
```

## 8. Create a safe test conversation

Use a fake or authorized test Student/Faculty record. Do not use an important
real conversation for the first test.

1. Open the public website.
2. Open the ReAccess Hub Assistant.
3. Ask a question.
4. Select **Ask the CISO Office**.
5. Enter the ID of the controlled test record.
6. Confirm the conversation is sent.
7. Sign in to the Admin Portal.
8. Open **Messages**.
9. Scroll to **Public Help Chat**.
10. Confirm the test conversation and its ID appear.

## 9. Permanently delete one conversation

1. Find the test conversation under **Public Help Chat**.
2. On the right side of that conversation, click the trash/delete button.
3. Read the warning carefully.
4. Enter the username of the administrator who is currently signed in.
5. Enter that administrator's current password.
6. Click **Confirm permanent delete**.
7. Wait for this message:

   ```text
   Support conversation permanently deleted.
   ```

8. Confirm the conversation disappears from the list.

If the credentials are wrong, the conversation is kept and the system displays
an error. Closing the confirmation window or clicking **Cancel** also keeps the
conversation.

## 10. Check the result

1. Refresh **Messages > Public Help Chat**.
2. Confirm only the selected conversation was removed.
3. Open **Audit Logs**.
4. Choose or look for `SUPPORT DELETED`.
5. Confirm the audit entry identifies the deleted support-ticket record.
6. Confirm the test Student or Faculty still appears under **Users**.
7. Confirm normal account-service requests still appear under **Requests**.

The public visitor's old **Check for office reply** button will return that the
conversation was not found or has expired. This is expected after permanent
deletion.

## 11. Apply the feature to the deployed system

The feature changes both the Flutter website and the Dart API. Updating only one
of them is not enough.

1. Finish all local tests first.
2. Push the changed source files to the private GitHub repository.
3. Open Render and deploy/restart the ReAccess API using the new commit.
4. Check the Render logs and confirm the API starts normally.
5. Build the Flutter website using the deployed API URL as explained in
   [README6.md](README6.md).
6. Upload the new `build/web` output to Cloudflare Pages.
7. Open the deployed website in a private/incognito browser window.
8. Sign in to Admin and confirm the trash button appears under **Messages >
   Public Help Chat**.
9. Create and delete one controlled test conversation.
10. Confirm the deletion audit entry appears.

Do not apply SQL to Supabase for this feature. No new Render environment variable
is required.

## 12. Safety and recovery

The Admin Portal has no undelete button. If an important conversation is deleted:

1. Stop further write activity if recovery is required.
2. Do not restore the entire production database without approval because that
   could overwrite newer requests and messages.
3. Give the backup filename, deletion time, support-ticket audit ID, and current
   database details to the authorized database maintainer.
4. Restore the backup into a separate recovery database first.
5. Let the maintainer recover only the approved record after checking conflicts
   and retention requirements.

## Final checklist

- [ ] A valid database backup was created before the first deletion test.
- [ ] Backend analysis and tests passed.
- [ ] Flutter analysis and tests passed.
- [ ] The API was restarted.
- [ ] Flutter was restarted or rebuilt.
- [ ] The delete button appears only in the Admin Public Help Chat list.
- [ ] Current administrator credentials are required.
- [ ] Cancel and wrong credentials keep the conversation.
- [ ] Confirmed deletion removes only the selected support conversation.
- [ ] The Student/Faculty registry record remains.
- [ ] A `SUPPORT_DELETED` audit entry remains.
- [ ] Both the API and Flutter website were redeployed for the online version.

