# Replace Personal Gmail and Twilio Accounts Before Deployment

You used personal accounts while following Steps 4 and 5 of
[README3.md](README3.md). That is acceptable only for local testing with fake
data. Complete this guide before deploying ReAccess Hub for real users.

This guide does not change the database and does not require a migration.

## 1. Do not publish the personal credentials

Do not copy personal Gmail App Passwords, Twilio Auth Tokens, `.env` files, or
screenshots containing secrets to GitHub, Render, Cloudflare, or documentation.

Do not delete the personal credentials yet. Keep the local worker stopped until
the office-owned accounts are ready and tested.

## 2. Prepare an office-controlled email account

Ask the CISO Office or authorized school administrator for a mailbox controlled
by the school, for example `ciso.office@gmail.com` or an approved Google
Workspace address.

The school should:

1. Own the account and recovery information.
2. Enable 2-Step Verification.
3. Store recovery codes in the approved office password manager or vault.
4. Add at least one second authorized account owner or recovery contact.
5. Create a Google App Password named `ReAccess Hub Worker`.

Do not use the normal Google password as `SMTP_PASSWORD`.

## 3. Replace Gmail values locally

1. In VS Code, press `Ctrl+P`.
2. Open `backend/.env`.
3. Replace the existing personal `SMTP_` values with the office values:

```dotenv
SMTP_HOST=smtp.gmail.com
SMTP_PORT=465
SMTP_FROM=OFFICE_EMAIL_ADDRESS
SMTP_USERNAME=OFFICE_EMAIL_ADDRESS
SMTP_PASSWORD=OFFICE_GOOGLE_APP_PASSWORD_WITHOUT_SPACES
```

4. Press `Ctrl+S`.
5. If the Docker notification worker uses the root `.env`, replace the same
   `SMTP_` values there too.
6. Never paste the completed values into a README or Git commit.

## 4. Decide whether production needs SMS

Twilio is optional. Choose one option.

### Option A - Deploy email only

Set every Twilio value to empty in the local worker and in Render:

```dotenv
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_FROM_NUMBER=
TWILIO_MESSAGING_SERVICE_SID=
```

### Option B - Use an office-controlled Twilio account

1. Ask the school to create or take ownership of a Twilio account.
2. Add authorized office administrators to the Twilio team.
3. Enable multi-factor authentication.
4. Use an approved SMS-capable number or Messaging Service.
5. Check Philippine messaging rules, sender registration, and country
   permissions.
6. Store the Account SID and Auth Token in the approved password manager.
7. Replace the personal `TWILIO_` values in `backend/.env`, the root `.env` when
   used by Docker, and the Render worker environment.

Use only one sender method:

```dotenv
TWILIO_ACCOUNT_SID=OFFICE_AC_VALUE
TWILIO_AUTH_TOKEN=OFFICE_PRIVATE_TOKEN
TWILIO_FROM_NUMBER=OFFICE_SMS_NUMBER
TWILIO_MESSAGING_SERVICE_SID=
```

Or:

```dotenv
TWILIO_ACCOUNT_SID=OFFICE_AC_VALUE
TWILIO_AUTH_TOKEN=OFFICE_PRIVATE_TOKEN
TWILIO_FROM_NUMBER=
TWILIO_MESSAGING_SERVICE_SID=OFFICE_MG_VALUE
```

## 5. Replace the values in Render

When creating the Render Background Worker from [README6.md](README6.md):

1. Open the worker in the Render dashboard.
2. Open **Environment**.
3. Enter the office `SMTP_` values.
4. Enter the office `TWILIO_` values, or leave all four empty for email-only
   deployment.
5. Save the changes.
6. Redeploy or restart the worker.
7. Do not put these secrets in the Flutter/Cloudflare environment. Only the
   backend notification worker needs them.

## 6. Test before removing the personal accounts

1. Use a fake request and an office-controlled recipient.
2. Start the notification worker.
3. Approve or message the fake request.
4. Confirm the email arrives from the office mailbox.
5. If SMS is enabled, confirm it arrives from the approved office sender.
6. Check the worker log for errors without copying secrets into screenshots.
7. Confirm Notification Delivery in Admin shows `SENT`.

## 7. Remove personal access after the office test passes

Only after the office-owned delivery test succeeds:

1. Delete or revoke the personal Google App Password used for ReAccess Hub.
2. Remove the personal Gmail values from local `.env` files and Render.
3. Rotate or revoke the personal Twilio Auth Token.
4. Remove personal Twilio team access if the school account no longer needs it.
5. Search the private deployment notes for accidentally copied secrets.
6. Record the change date and authorized maintainer in the private operations
   log without recording the secret values.

Do not deploy real student or faculty data until this checklist is complete.
