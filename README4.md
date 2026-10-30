# ReAccess Hub Testing, Backup, and Launch Checklist

This guide helps a beginner prove that the system works before real students use
it. A page looking correct is not proof that records, email, SMS, or backups work.

## 1. Make a test record sheet

1. Open Excel or Google Sheets.
2. Create these column headings:

```text
Date | Tester | Test | Expected result | Actual result | Pass/Fail | Evidence | Fix needed
```

3. Save it in the office's private project folder.
4. Do not put passwords, tokens, or real student details in it.

Use the sheet for every test below. A test is complete only when the actual result
is written down.

## 2. Start the complete local system

Open four VS Code terminals.

Terminal 1, database:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub'
docker compose up -d postgres
docker compose ps
```

Terminal 2, API:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub\backend'
dart run bin/server.dart
```

Terminal 3, website:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub'
flutter run -d chrome --web-port 3000 --dart-define=API_BASE_URL=http://localhost:8080/api/v1
```

Terminal 4, notification worker:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub\backend'
dart run bin/notification_worker.dart
```

If email and SMS are not configured, leave Terminal 4 stopped and record that
provider delivery has not been tested.

## 3. Run the automatic checks

Open one more terminal and run:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub'
flutter analyze
flutter test
Push-Location backend
dart analyze
dart test
Pop-Location
```

Record each result. Fix errors before launch. These commands still do not test a
real browser-to-database-to-provider workflow.

## 4. Test every public request type

There are six combinations:

```text
Student SSPR
Student Account Recovery
Student Account Update
Faculty SSPR
Faculty Account Recovery
Faculty Account Update
```

For each combination:

1. Use an approved fake registry person.
2. Leave one required field empty and confirm the page shows an error.
3. Enter an invalid ID, Gmail, or phone and confirm it is rejected.
4. Enter matching data and complete verification.
5. Submit the request.
6. Save the receipt/reference in the private test sheet.
7. Sign in as admin and find the same reference.
8. Confirm every submitted field is correct.
9. Reject one test request.
10. Reopen/reconsider it and approve it.
11. Perform the pretend office action, then mark it Done.
12. Confirm its status, history, and notification jobs are correct.

Also test these special cases:

- Change one identity field; verification must fail without revealing stored data.
- Submit SSPR twice for one ID; the active pending duplicate must be blocked.
- Click Submit twice; it must not create two requests.
- Sign out; protected admin information must no longer open.
- Stop PostgreSQL; submission must not display a false success.

## 5. Test the admin pages

1. Open **Dashboard** and compare totals with the test requests.
2. Open **Requests** and test every filter.
3. Open one rejected request and test reconsideration.
4. Open **Users** and test Student/Faculty filters.
5. On an approved test record, use **Edit Contacts** and confirm the original
   submitted value remains in history.
6. Open **Messages**, send a test reply, and check the notification job.
7. Mark and unmark a test conversation as priority.
8. Open **Reports**, filter to one request type, and export PDF.
9. Open **Audit Logs**, use the same period, and export CSV.
10. Confirm each export follows the visible filters and keeps names readable.

Do not silently edit identity fields to make a request match. Re-verify identity
through the office process.

## 6. Test phone, tablet, theme, and keyboard use

1. Open the website in Chrome.
2. Press `F12` to open Developer Tools.
3. Click the phone/tablet icon in the DevTools toolbar.
4. Choose a small phone size.
5. Reload and use the public form and admin navigation.
6. Repeat at tablet and desktop sizes.
7. Test light theme and dark theme.
8. Press `Tab` repeatedly and confirm focus is visible and follows a sensible order.
9. Use Enter/Space to activate controls where expected.
10. Zoom the browser to 200% and confirm important content is still usable.

Record any clipped text, hidden button, unreadable contrast, or keyboard trap.

## 7. Test Gmail and Twilio for real

Use only office-owned or consenting recipients.

1. Start the worker.
2. Approve one fake request with email enabled.
3. Confirm ReAccess Hub shows the job status.
4. Confirm the email appears in the real inbox or Spam folder.
5. Confirm the sender, subject, request reference, and attachment are correct.
6. If SMS is enabled, send one test and check the real phone.
7. Open Gmail Sent and Twilio message logs to compare provider status.
8. Send a staff message and a completion notification.
9. Stop the worker when finished if more queued messages must not be processed.

Remember: provider acceptance is not the same as final delivery or reading. The
current project does not process delivery webhooks or incoming email/SMS replies.

## 8. Create a backup schedule

Use the exact Docker backup commands in [README2.md](README2.md).

Ask the CISO Office to approve a written schedule such as:

| When | Action | Person responsible |
| --- | --- | --- |
| Every night | Encrypted database backup | Named maintainer |
| Every week | Check backup file and logs | Second named reviewer |
| Every month | Restore into a separate test database | Database maintainer |
| Before every migration/release | Manual backup and restore check | Release owner |

For each restore drill:

1. Use a separate test database.
2. Restore the newest backup.
3. Count users, registry rows, requests, audit rows, and notification jobs.
4. Sign in and open a sample request if the test environment allows it.
5. Record the result and any repair needed.
6. Never overwrite production for a practice restore.

A successful backup message is not enough. The restore drill proves whether the
backup is usable.

## 9. Set up simple monitoring

For local use:

1. Run `docker compose ps` and confirm PostgreSQL is healthy.
2. Open `http://localhost:8080/health` and confirm the API responds.
3. Read the API and worker terminal errors.
4. In admin request review, check failed or old pending notification jobs.

For an online deployment:

1. In Render, open the API service and check **Events**, **Logs**, and health.
2. Open the worker and check failed/restarting events.
3. In Supabase, check project health, database capacity, and backup status.
4. In Gmail/Twilio, check provider alerts and failed sends.
5. Add billing alerts to every paid provider.
6. Write who receives alerts and who is allowed to restart services.

## 10. Security work required before wider use

The following items need implementation or an approved operational control. Do
not mark them complete only because the UI works.

- Stronger identity proof before sensitive account changes.
- Multi-factor authentication or another strong admin-login control.
- Deployment-level per-client rate limits for login, verification, submission,
  and chat endpoints.
- Persistent refresh-session design and reviewed logout/session revocation.
- Real delivery callbacks if the office needs final email/SMS delivery status.
- Tested monitoring and alert ownership.
- Written retention rules for requests, logs, exports, and backups.
- Regular access review for admins and maintainers.
- Security review before Microsoft Graph automation is added.

The current app does not automatically perform Microsoft 365 password resets or
account enrollment. Staff must verify identity and complete that work outside the app.

## 11. Launch-day steps

1. Freeze changes and record the approved source release.
2. Create and verify a fresh backup.
3. Confirm the API and worker point to the same intended database.
4. Confirm a strong admin can sign in.
5. Confirm the current academic period.
6. Submit one controlled request.
7. Process it and verify notification delivery.
8. Check reports and audit history.
9. Have the CISO Office approve the public link.
10. Monitor logs and the request queue closely after opening access.

## 12. Safe rollback steps

If a release causes wrong records or messages:

1. Stop public submissions if they could make the problem worse.
2. Stop the notification worker so it does not send more jobs.
3. Record all requests/messages created after the last good backup.
4. Roll the API and website back only to versions compatible with the current schema.
5. Do not automatically undo a database migration.
6. If a database restore is required, reconcile newer records first; a restore can
   erase everything created after the backup.
7. Test the recovered system before reopening it.

## 13. Troubleshooting

| What you see | What to check next |
| --- | --- |
| Website opens, but requests fail | API terminal, `API_BASE_URL`, database status |
| `/health` works, but login fails | Database credentials, admin record, migrations, permissions |
| Data disappears after restart | Wrong database target or an accidentally disposable database |
| Recovery/update cannot verify | Registry spelling, active flag, ID, email, institute/program/position |
| SSPR duplicate is accepted | Migration/constraint status and test setup |
| Email stays pending | Worker running and `SMTP_` values present |
| Gmail rejects login | 2-Step Verification, App Password, mailbox policy |
| SMS is not received | Twilio sender, destination permissions, trial limits, balance, E.164 number |
| Letter option fails | Correct file exists and `LETTER_TEMPLATE_PATH` is exact |
| PDF has bad characters | Valid `REPORT_FONT_PATH` and supported font file |
| Export seems incomplete | 5,000-row limit and active filters |
| A backup exists but restore fails | Client/server version, damaged file, missing roles/extensions, wrong command |

## 14. Final approval checklist

- [ ] Automatic tests pass.
- [ ] All six public request combinations pass.
- [ ] Duplicate, invalid, double-click, sign-out, and outage cases pass.
- [ ] Admin decisions, work queues, registry updates, and audit history pass.
- [ ] PDF and CSV exports match filters.
- [ ] Mobile, desktop, themes, keyboard, and 200% zoom are usable.
- [ ] Gmail and optional Twilio are confirmed on real test recipients.
- [ ] Database backup and separate restore drill pass.
- [ ] Monitoring, billing alerts, and responsible people are written down.
- [ ] Strong admin and current academic period are ready.
- [ ] The CISO Office approves the identity procedure and launch.

For cloud database migration continue to [README5.md](README5.md). For online
hosting after Supabase, continue to [README6.md](README6.md).
