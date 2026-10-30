# ReAccess Hub Admin, Email, SMS, and Letter Setup

Use this guide after [README.md](README.md) and [README2.md](README2.md). It tells
you exactly how to create administrators, set the school period, configure the
blank letter, and start email/SMS delivery.

## 0. Apply migrations 006 and 007 before using the new features

The Institution, Program, and Student Request Limit settings need
`006_request_configuration.sql`. Editing and permanently deleting a Student or
Faculty record needs `007_registry_edit_delete.sql`.

Your existing database already has migrations 001-005. Migration 006 may also
already be present if you followed an earlier version of this file. The commands
below safely run 006 and then 007 in the correct order. Do not recreate the
database and do not delete its Docker volume.

### 0.1 Stop programs that write to the database

1. In the API terminal, press `Ctrl+C`.
2. In the notification-worker terminal, press `Ctrl+C` if it is running.
3. Leave Docker Desktop and the PostgreSQL container running.

### 0.2 Create a backup first

Open a new VS Code terminal at the project root and run:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub'
New-Item -ItemType Directory -Force -Path 'C:\ReAccessBackups'
$backupStamp = Get-Date -Format 'yyyy-MM-dd-HHmmss'
$backupFile = "C:\ReAccessBackups\before-migrations-006-007-$backupStamp.dump"
docker compose exec postgres pg_dump -U postgres -d reaccess_hub --format=custom --file=/tmp/before-007.dump
docker compose cp postgres:/tmp/before-007.dump $backupFile
Get-Item -LiteralPath $backupFile | Select-Object FullName,Length,LastWriteTime
docker compose exec postgres pg_restore --list /tmp/before-007.dump
```

Stop if the file is missing, has size `0`, or `pg_restore --list` reports an
error. Keep the backup outside the repository in approved encrypted storage.

### 0.3 Apply migrations 006 and 007, one at a time

From the project root run:

```powershell
docker compose cp backend/migrations/006_request_configuration.sql postgres:/tmp/006_request_configuration.sql
docker compose exec postgres psql -U postgres -d reaccess_hub -v ON_ERROR_STOP=1 -f /tmp/006_request_configuration.sql
docker compose cp backend/migrations/007_registry_edit_delete.sql postgres:/tmp/007_registry_edit_delete.sql
docker compose exec postgres psql -U postgres -d reaccess_hub -v ON_ERROR_STOP=1 -f /tmp/007_registry_edit_delete.sql
docker compose exec postgres sh /docker-entrypoint-initdb.d/999-grant-app.sh
```

You must see `COMMIT` after migration 006 and another `COMMIT` after migration
007. If an error appears, stop and keep the API off until the exact error is
reviewed. Do not run `docker compose down -v`.

### 0.4 Verify the new database objects

Run these read-only checks:

```powershell
docker compose exec postgres psql -U postgres -d reaccess_hub -c "SELECT count(*) AS institutions FROM institutions; SELECT count(*) AS programs FROM institution_programs;"
docker compose exec postgres psql -U postgres -d reaccess_hub -c "SELECT student_request_limit,student_request_limit_reset_at FROM portal_settings WHERE singleton=true;"
docker compose exec postgres psql -U postgres -d reaccess_hub -c "SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname='support_tickets_person_id_fkey';"
```

Expected starting values are six institutions, sixteen programs, and a student
request limit of `0`. The last command must include `ON DELETE SET NULL`.

### 0.5 Restart the application

Terminal 1:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub\backend'
dart run bin/server.dart
```

Terminal 2:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub'
flutter run -d chrome --web-port 3000 --dart-define=API_BASE_URL=http://localhost:8080/api/v1
```

Sign in, open **Settings**, and check Institution and Student Request Limit.
Then open **Users**. Migration 006 and migration 007 do not delete existing
requests, registry records, administrators, periods, messages, support tickets,
or audit rows.

### 0.6 Learn how Edit and Delete work

To edit a Student or Faculty record:

1. In the left menu, click **Users**.
2. Click **Students** or **Faculty** above the list.
3. Click anywhere on the person's row.
4. Change the name, institute, program or position, email, contact number,
   Gmail address, or Active switch.
5. The ID number and user type are locked. To use a different ID or type,
   create a new record instead.
6. At the bottom of the window, enter your current administrator username and
   password.
7. Click **Confirm and save**.
8. Wait for `User data updated in the database.`

To permanently delete a Student or Faculty registry record:

1. Find the person in **Users**.
2. On the far right of that person's row, click the trash/delete button.
3. Read the warning carefully. This removes the registry record from the
   database and cannot be undone through the Admin page.
4. Enter your current administrator username and password.
5. Click **Confirm permanent delete**.
6. Wait for `User data permanently deleted from the database.`

Deleting a registry record does not erase old account requests or audit logs.
Old support tickets are also kept, but their link to the deleted ID becomes
blank. This keeps the system history available for review.

## 1. Create an administrator

### Choice A - Use the local learning account

Use this only with `APP_ENV=development` on your own computer.

1. Start the database and apply migrations `001` through `007`.
2. In VS Code, click **Terminal > New Terminal**.
3. Run:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub\backend'
dart run bin/local_admin.dart
```

4. Open [http://localhost:3000/#/admin/login](http://localhost:3000/#/admin/login).
5. Enter username `admin` and temporary password `ABC123`.
6. Open **Settings** and change the password immediately.

Do not use this temporary password online or with real school information.

### Choice B - Create a real administrator

1. Confirm `backend/.env` points to the correct database.
2. Back up the database using [README2.md](README2.md).
3. Click **Terminal > New Terminal** and run:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub\backend'
dart run bin/create_admin.dart
```

4. The terminal asks five questions. Enter values like these, but use the real
   authorized office account and a unique password:

```text
Admin email: authorized.office.account@example.com
Username: ciso_admin
First name: CISO
Last name: Administrator
Password: use a password-manager-generated password of 12 to 72 characters
```

5. The password is hidden while you type. That is normal.
6. Expect `Administrator created`.
7. Sign in and confirm the account has the expected dashboard access.

The username may use letters, numbers, `.`, `_`, and `-`. Do not create a second
account because the first command looked slow; check the login first.






## 2. Set the academic year and semester

Do this before collecting requests so reports receive the correct period.

1. Start the database, API, and website.
2. Sign in as a `SUPER_ADMIN`.
3. In the left menu, click **Settings**.
4. Find the academic period section.
5. Click the add/new-period button.
6. Enter the values approved by the school. Example only:

```text
Semester: First Semester
Academic year: 2026-2027
Start date: 2026-08-01
End date: 2026-12-20
```

7. Click **Save**.
8. Confirm the period appears in the list.

Periods must not overlap. The server uses the Asia/Manila date. If the school
calendar differs from the example, use the approved dates, not the example.

## 3. Set up the blank formal letter

The project already contains `backend/templates/formal-letter.docx`.

1. In Windows File Explorer, open:

```text
C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub\backend\templates
```

2. Double-click `formal-letter.docx` to open it in Microsoft Word.
3. Ask the CISO Office to verify the logo, wording, signatories, and blank fields.
4. If edits are approved, click **File > Save** in Word.
5. Keep the file blank. Never store a completed student letter in this public
   template folder.
6. Keep the file below 5 MB.

For a local Dart API, open `backend/.env` and set this exact path:

```dotenv
LETTER_TEMPLATE_PATH=C:/Users/Admin/Documents/Thesis/Final System/reaccess_hub/backend/templates/formal-letter.docx
LETTER_TEMPLATE_URL=
REPORT_FONT_PATH=C:/Windows/Fonts/arial.ttf
```

Do not add quotes. Forward slashes avoid Windows backslash confusion. Leave the
URL blank during local testing. For Docker, the root `.env` should use:

```dotenv
LETTER_TEMPLATE_PATH=/app/templates/formal-letter.docx
```

Restart the API after changing an environment file. Then open Student Account
Recovery and test the letter button. In admin request review, test **Provide
letter** only after email is configured.

## 4. Set up Gmail email

Use a dedicated office-controlled Google or Google Workspace mailbox. Do not use
a student's personal account.

### 4.1 Turn on Google 2-Step Verification

1. Open [Google Account Security](https://myaccount.google.com/security) in a browser.
2. Sign in to the office mailbox.
3. Under **How you sign in to Google**, click **2-Step Verification**.
4. Follow Google's steps and confirm it is on.
5. Store recovery information according to office policy.

### 4.2 Create a Google App Password

1. Open [Google App Passwords](https://myaccount.google.com/apppasswords).
2. Sign in again if asked.
3. Enter an app name such as `ReAccess Hub Worker`.
4. Click **Create**.
5. Copy the generated 16-character password immediately into the office password
   manager. Google will not show the same value again.

Google only offers App Passwords when the account and its policy allow them. If
the option is missing, ask the Google Workspace administrator. Do not put the
normal Google password in this project. Google explains the requirements in its
[App Password help](https://support.google.com/accounts/answer/185833).

### 4.3 Put Gmail settings in `backend/.env`

1. In VS Code, press `Ctrl+P`.
2. Type `backend/.env` and press Enter.
3. Find the `SMTP_` lines.
4. Replace them with the block below. Change the two email values to the real
   office mailbox. Change the password to the App Password, with spaces removed.

```dotenv
SMTP_HOST=smtp.gmail.com
SMTP_PORT=465
SMTP_FROM=ciso.office@gmail.com
SMTP_USERNAME=ciso.office@gmail.com
SMTP_PASSWORD=PASTE_16_CHARACTER_GOOGLE_APP_PASSWORD_HERE
```

5. Press `Ctrl+S`.
6. Never copy this completed file into Git or a screenshot.

If you use Docker for the worker, put the same `SMTP_` values in the root `.env`.
Port `465` uses TLS. Keep `SMTP_FROM` and `SMTP_USERNAME` the same unless Google
Workspace has an approved sender alias.

## 5. Set up Twilio SMS (optional)

Skip this section if the office will use email only. Leaving every `TWILIO_`
value blank disables SMS delivery.

1. Sign in to the [Twilio Console](https://console.twilio.com/).
2. On the Console home page, find **Account SID** and **Auth Token**.
3. Click the show/copy control for the Auth Token and store it in the password manager.
4. Open **Messaging**.
5. Obtain an SMS-capable Twilio phone number or create a Messaging Service.
6. If using a phone number, copy it in international form, such as `+1...`.
7. If using a Messaging Service, copy its SID, which begins with `MG`.
8. Check country permissions and registration rules for messages sent to the
   Philippines. Trial accounts may send only to verified recipients.
9. Use only office-owned or consenting test phone numbers.

In `backend/.env`, use one of the following choices.

Phone-number choice:

```dotenv
TWILIO_ACCOUNT_SID=PASTE_THE_AC_VALUE_HERE
TWILIO_AUTH_TOKEN=PASTE_THE_PRIVATE_TOKEN_HERE
TWILIO_FROM_NUMBER=+PASTE_THE_SMS_CAPABLE_NUMBER_HERE
TWILIO_MESSAGING_SERVICE_SID=
```

Messaging-Service choice:

```dotenv
TWILIO_ACCOUNT_SID=PASTE_THE_AC_VALUE_HERE
TWILIO_AUTH_TOKEN=PASTE_THE_PRIVATE_TOKEN_HERE
TWILIO_FROM_NUMBER=
TWILIO_MESSAGING_SERVICE_SID=PASTE_THE_MG_VALUE_HERE
```

Do not fill both sender choices unless the maintainer intentionally wants the
Messaging Service to take precedence. The worker uses Twilio's
[Messages API](https://www.twilio.com/docs/messaging/api/message-resource).

## 6. Start the notification worker

The API saves notification jobs. A separate worker sends them.

1. Start PostgreSQL, the API, and Flutter first.
2. Click **Terminal > New Terminal**.
3. Run:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub\backend'
dart run bin/notification_worker.dart
```

4. Leave the worker terminal open.
5. To process only one queued job while testing, stop it with `Ctrl+C` and run:

```powershell
dart run bin/notification_worker.dart --once
```

For Docker instead of a local Dart worker:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub'
docker compose --profile notifications up -d --build notifications
docker compose logs -f notifications
```

Press `Ctrl+C` to stop following logs; that does not stop the container.

## 7. Send one controlled test

1. Use a fake registry person whose email/phone belongs to an authorized tester.
2. Submit a request from the public page.
3. Sign in as admin.
4. Open **Requests** and click **View** on the test request.
5. Approve it and choose notification options.
6. If the approved blank Word file is required, turn on **Provide letter**.
7. Confirm the decision.
8. In the request review, inspect **Notification Delivery**.
9. Check the real Gmail inbox and Spam folder.
10. Check the real phone if SMS was enabled.
11. Check the Gmail Sent folder and Twilio message logs if delivery is uncertain.

`SENT` in ReAccess Hub means Gmail or Twilio accepted the message. It does not
prove the person received or read it. Do not blindly retry an uncertain job;
check provider logs first because a second attempt can create a duplicate.

## 8. Process a request correctly

1. Open **Requests**.
2. Use filters to find Student/Faculty and SSPR/Recovery/Update.
3. Click **View**.
4. Compare submitted information with the office's trusted identity procedure.
5. Add reviewer notes without placing passwords in them.
6. Approve or reject the request.
7. Complete the actual Microsoft 365 action outside this app.
8. Only then click **Done**.
9. For SSPR, use **Complete SSPR enrollment** after the real enrollment is complete.
10. Confirm the item leaves the work queue and the audit history is correct.

The app does not automatically change Microsoft 365 accounts. Staff perform that
work in the authorized Microsoft administration system.

## 9. Export reports safely

1. Open **Reports**.
2. Set User Type, Semester, Request Type, Status, and dates.
3. Click the search button or press Enter.
4. Click **Export Report** for PDF.
5. Use the browser print/download controls if a preview opens.
6. Open **Audit Logs**, apply filters, and use **Export CSV**.
7. Store exports in approved private storage and remove them when the retention
   period ends.

Exports are limited to 5,000 rows. Narrow the filters if the result is larger.

## 10. Reset a forgotten administrator password

There is intentionally no public password-reset shortcut.

1. Verify the account owner using the CISO Office procedure.
2. Confirm `backend/.env` points to the intended database.
3. Back up the database.
4. Open a terminal and run:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub\backend'
dart run bin/reset_admin.dart
```

5. Enter the existing admin email.
6. Enter a new username and a password of 12 to 72 characters.
7. Enter the same password again.
8. Only after identity verification, type `RESET` exactly.
9. Expect `Credentials reset; previous sessions revoked`.

## 11. Stop email and SMS safely

Local worker: select its terminal and press `Ctrl+C`.

Docker worker:

```powershell
docker compose stop notifications
```

Stopping the worker does not delete queued jobs. Review old pending jobs before
starting it again so outdated messages are not unexpectedly sent.

## 12. Final admin checklist

- [ ] Strong administrator created; temporary password changed.
- [ ] Academic period added with approved dates.
- [ ] Blank Word template reviewed by the office.
- [ ] Gmail uses an App Password, not a normal password.
- [ ] Twilio sender and country permissions checked, or SMS intentionally disabled.
- [ ] Worker tested with a consenting recipient.
- [ ] Provider logs checked independently.
- [ ] Staff understand that Microsoft 365 changes happen outside this app.
- [ ] Reports and exported personal data have an approved storage/retention rule.

Next: use [README4.md](README4.md) for the complete acceptance test, monitoring,
backup schedule, and launch-readiness checklist.
