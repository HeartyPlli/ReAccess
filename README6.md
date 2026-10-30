# Put ReAccess Hub Online - Beginner Deployment Guide

This guide deploys:

- PostgreSQL on Supabase
- the Dart API on a Render Web Service
- the notification worker on a Render Background Worker
- the Flutter website on Cloudflare Pages

Finish [README5.md](README5.md) first. Use a staging setup before production.
Provider screens and prices can change, so compare each screen with the linked
official documentation.

If Gmail or Twilio was configured with a personal account during local testing,
complete [README13.md](README13.md) before adding production worker secrets.

## 1. Understand the online layout

```text
Student/Admin browser
        |
        v
Cloudflare Pages (Flutter website)
        |
        v
Render Web Service (Dart API) ------> Supabase PostgreSQL
                                            ^
Render Background Worker ------------------|
        |
        +----> Gmail SMTP
        +----> Twilio SMS (optional)
```

The website is public. The database, passwords, Gmail App Password, Twilio token,
and JWT secret are never placed in the Flutter build.

## 2. Create the required accounts

Use office-controlled accounts, not a student's or one developer's personal account.

1. Create or choose a [GitHub](https://github.com/) organization/account for the private source.
2. Create or choose a [Render](https://render.com/) team/account.
3. Create or choose a [Cloudflare](https://dash.cloudflare.com/) account.
4. Confirm the production [Supabase](https://supabase.com/) project from README5.
5. Turn on multi-factor authentication for each provider.
6. Store recovery codes in the approved password manager or secure office vault.
7. Add a second authorized owner so one lost account does not lock out the school.
8. Review current plans, data location, limits, and costs with the office.
9. Add provider billing alerts before launch.

Render documents Web Services and Background Workers here:
[Web Services](https://render.com/docs/web-services) and
[Background Workers](https://render.com/docs/background-workers).

## 3. Check that no secret will be uploaded

In VS Code, open a terminal at the project root and check that `.gitignore`
contains the secret-file rules:

```powershell
Select-String -Path .gitignore -Pattern '^\.env$','^backend/\.env$','^backend/\.local-admin\.json$','registry\*\.json'
```

The matching rules should be printed. Also run:

```powershell
Get-ChildItem -Recurse -File -Include '*.dump','registry*.json','*.pem','*.key' | Select-Object FullName
```

Move any private backup, registry, or key out of the repository before continuing.
Do not delete the only copy; move it to approved encrypted storage.

## 4. Put the source in a private GitHub repository

Skip repository creation only if the approved private repository already exists.

### 4.1 Create the empty private repository in the browser

1. Sign in to GitHub.
2. Click the `+` button in the top-right corner.
3. Click **New repository**.
4. Choose the office organization/owner.
5. Enter repository name `reaccess-hub`.
6. Select **Private**.
7. Do not add a README, `.gitignore`, or license because this folder already has them.
8. Click **Create repository**.
9. Copy the HTTPS repository URL. It looks like:

```text
https://github.com/OFFICE-OWNER/reaccess-hub.git
```

### 4.2 Upload the local source

The current folder may not yet be a Git repository. In the VS Code terminal run:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub'
git init
git check-ignore .env backend/.env backend/.local-admin.json
git add .
git status --short
```

The `git check-ignore` command should print all three paths. Read the status list
before committing. `.env`, `backend/.env`, `.local-admin.json`, database dumps,
and registry exports must not appear.

If Git has never been used on this computer, set the maintainer identity first.
Open GitHub **Profile picture > Settings > Emails** and use the verified office
email shown there:

```powershell
git config user.name "Authorized Maintainer Name"
git config user.email "verified-office-email@example.com"
```

Replace both example values. Then run:

```powershell
git commit -m "Prepare ReAccess Hub deployment"
git branch -M main
git remote add origin https://github.com/OFFICE-OWNER/reaccess-hub.git
git push -u origin main
```

Replace only `OFFICE-OWNER` with the actual GitHub owner. If Git asks you to sign
in, complete the browser/device sign-in. Do not use an account password as a Git
password; follow GitHub's current authentication prompt.

After upload, open the repository on GitHub and visually confirm no secret files
or personal-data exports are present.

## 5. Check the Docker image locally

The Docker image builds from the repository root because the backend depends on
`packages/request_contract`.

1. Start Docker Desktop.
2. In the project root run:

```powershell
docker build -f backend/Dockerfile -t reaccess-api-test .
```

3. Expect a successful build.
4. Check that the blank letter was included:

```powershell
docker run --rm reaccess-api-test ls -l /app/templates/formal-letter.docx
```

Do not change the build context to `backend`; the shared package would be missing.

## 6. Reserve the Cloudflare Pages website name

The API needs the website's exact origin for CORS, so reserve this first.

### Choice A - Use Wrangler (recommended for this guide)

1. Install the current Node.js LTS release from [nodejs.org](https://nodejs.org/).
2. Close and reopen VS Code.
3. In the project root, run:

```powershell
node --version
npm --version
npx wrangler login
```

4. A browser opens. Sign in to Cloudflare and approve Wrangler access.
5. Back in the terminal run:

```powershell
npx wrangler pages project create
```

6. When asked for a project name, enter an available name such as `reaccess-hub-tcgc`.
7. When asked for the production branch, enter `main`.
8. Record the assigned URL, for example:

```text
https://reaccess-hub-tcgc.pages.dev
```

Use your actual URL in every later step. Cloudflare's official steps are in
[Pages Direct Upload](https://developers.cloudflare.com/pages/get-started/direct-upload/).

### Choice B - Use the Cloudflare dashboard

1. Open the Cloudflare dashboard.
2. Open **Workers & Pages**.
3. Click **Create application > Get started > Drag and drop your files**.
4. Enter the project name.
5. Create the project. Upload happens later in Section 9.

An origin contains only the scheme and host:

```text
https://reaccess-hub-tcgc.pages.dev
```

Do not add `/`, `/#/admin/login`, or `/api/v1` to `ALLOWED_ORIGINS`.

## 7. Deploy the Dart API on Render

### 7.1 Connect GitHub to Render

1. Sign in to Render.
2. Click **New > Web Service**.
3. Choose **Git Provider**.
4. Connect GitHub if asked.
5. Grant Render access only to the approved private repository when possible.
6. Select `reaccess-hub` and the `main` branch.

### 7.2 Fill in the service form

Use these values:

| Render field | Value to enter |
| --- | --- |
| Name | `reaccess-api` or another approved unique name |
| Region | Same/near Supabase; Singapore when available and approved |
| Runtime/Language | `Docker` |
| Branch | `main` |
| Root Directory | leave blank |
| Dockerfile Path | `backend/Dockerfile` |
| Docker Build Context | `.` if the field is shown |
| Docker Command | leave blank |
| Health Check Path | `/health` |

Choose an approved instance plan. A production school service and continuously
running worker need a plan that meets the required availability and capacity.

### 7.3 Add the API environment values

In the Render service form or **Environment** page, add each key/value separately.
Do not include quotes.

| Key | Value |
| --- | --- |
| `APP_ENV` | `production` |
| `API_HOST` | `0.0.0.0` |
| `API_PORT` | `10000` |
| `ALLOWED_ORIGINS` | your exact Pages origin from Section 6 |
| `DATABASE_HOST` | exact Supabase Session pooler host |
| `DATABASE_PORT` | `5432` |
| `DATABASE_NAME` | `postgres` |
| `DATABASE_USER` | `reaccess_app.PROJECT_REFERENCE` |
| `DATABASE_PASSWORD` | application-role password from README5 |
| `DATABASE_SSL` | `true` |
| `SKIP_DATABASE_CONNECTION` | `false` |
| `JWT_SECRET` | unique random secret of at least 32 characters |
| `ACCESS_TOKEN_MINUTES` | `15` |
| `REFRESH_TOKEN_DAYS` | `7` |
| `REPORT_FONT_PATH` | `/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf` |
| `LETTER_TEMPLATE_PATH` | `/app/templates/formal-letter.docx` |
| `LETTER_TEMPLATE_URL` | leave empty unless an approved public HTTPS file exists |

To generate the production JWT secret on the trusted workstation, run:

```powershell
$secretBytes = New-Object byte[] 48
$secretMaker = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$secretMaker.GetBytes($secretBytes)
$secretMaker.Dispose()
[Convert]::ToBase64String($secretBytes)
```

Paste the result only into Render's secret environment field and the approved
password manager. Do not reuse a database password, Supabase API key, or example.

Optional `AI_API_KEY` and `AI_MODEL` stay empty unless the office intentionally
configures the supported backend integration. Never put them in Flutter.

### 7.4 Create and check the service

1. Click **Create Web Service**.
2. Open **Deploys/Events** and watch the build.
3. Open **Logs** and confirm the server starts without a database error.
4. Copy the Render URL, for example:

```text
https://reaccess-api.onrender.com
```

5. Open this in the browser, replacing the example host:

```text
https://reaccess-api.onrender.com/health
```

6. Or check from PowerShell:

```powershell
Invoke-RestMethod 'https://reaccess-api.onrender.com/health'
```

The API base used by Flutter is the Render URL plus `/api/v1`.

## 8. Create or confirm the production admin

Do not create a duplicate if README5 already created a strong administrator.

1. On the trusted workstation, make a private backup of `backend/.env`.
2. Temporarily set `backend/.env` to the production Supabase application role,
   `DATABASE_SSL=true`, `APP_ENV=production`, and a valid JWT secret.
3. Open a VS Code terminal and run:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub\backend'
dart run bin/create_admin.dart
```

4. Enter the real authorized office admin and a password-manager-generated password.
5. Restore the local `backend/.env` immediately after this maintenance task so
   daily development cannot accidentally edit production.

## 9. Build and upload the Flutter website

### 9.1 Build with the real API URL

In the project root, replace the example Render host and run:

```powershell
flutter pub get
flutter build web --no-web-resources-cdn --dart-define=API_BASE_URL=https://reaccess-api.onrender.com/api/v1
$LASTEXITCODE
```

`0` means the build succeeded. The output is `build/web`.

Do not use `localhost` in a production build; it would point to each visitor's
own computer. Changing a Cloudflare dashboard variable later does not change a
URL already compiled into Flutter. Rebuild and upload when the API URL changes.

### 9.2 Upload with Wrangler

Use the exact Cloudflare project name from Section 6:

```powershell
npx wrangler pages deploy build/web --project-name reaccess-hub-tcgc --branch main
```

Open the URL printed by Wrangler. Only `build/web` is uploaded—not the backend,
`.env`, or database files.

### 9.3 Upload using the dashboard instead

1. Open Cloudflare **Workers & Pages**.
2. Open the Pages project.
3. Click **Create a new deployment**.
4. In Windows File Explorer, open the project and then `build\web`.
5. Drag the `web` build folder into the upload area, or use the dashboard's
   supported folder/ZIP method.
6. Click **Save and Deploy**.

### 9.4 Check the live website

1. Open the canonical `pages.dev` address.
2. Open `https://YOUR_SITE.pages.dev/#/admin/login`.
3. Press `F12` and open the **Network** tab.
4. Try an admin sign-in.
5. Confirm requests go to the Render URL, not `localhost`.
6. If the browser reports CORS, make `ALLOWED_ORIGINS` exactly equal to the
   canonical Pages origin and redeploy the API.

The current backend uses only the first `ALLOWED_ORIGINS` value. Use one canonical
website origin unless the middleware is changed and tested.

## 10. Deploy the notification worker on Render

### 10.1 Create the Background Worker

1. In Render, click **New > Background Worker**.
2. Select the same GitHub repository and `main` branch.
3. Use the same region and Docker runtime as the API.
4. Leave **Root Directory** blank.
5. Set **Dockerfile Path** to `backend/Dockerfile`.
6. Set build context to `.` if shown.
7. Set **Docker Command** to:

```text
/app/bin/notification_worker
```

8. Choose the approved plan.
9. Do not configure a web port or health-check path; a Background Worker does not
   receive browser requests.

### 10.2 Add worker environment values

Add these values separately:

| Key | Value |
| --- | --- |
| `APP_ENV` | `production` |
| `DATABASE_HOST` | same Supabase Session pooler host as API |
| `DATABASE_PORT` | `5432` |
| `DATABASE_NAME` | `postgres` |
| `DATABASE_USER` | same restricted app username |
| `DATABASE_PASSWORD` | same application-role password |
| `DATABASE_SSL` | `true` |
| `SKIP_DATABASE_CONNECTION` | `false` |
| `JWT_SECRET` | same valid backend secret required by configuration |
| `SMTP_HOST` | `smtp.gmail.com` |
| `SMTP_PORT` | `465` |
| `SMTP_FROM` | approved office Gmail address |
| `SMTP_USERNAME` | same approved Gmail address |
| `SMTP_PASSWORD` | Google App Password, not the normal password |
| `TWILIO_ACCOUNT_SID` | Twilio `AC...` value, or leave empty |
| `TWILIO_AUTH_TOKEN` | Twilio private token, or leave empty |
| `TWILIO_FROM_NUMBER` | SMS sender, or leave empty when using Messaging Service |
| `TWILIO_MESSAGING_SERVICE_SID` | `MG...` value, or leave empty |
| `LETTER_TEMPLATE_PATH` | `/app/templates/formal-letter.docx` |

At least one notification channel must be configured for useful worker operation.
The image already contains the blank letter at `/app/templates/formal-letter.docx`.

### 10.3 Test one delivery

1. Deploy the worker and open its logs.
2. Use a fake request with a consenting office recipient.
3. Approve it in the deployed admin portal.
4. Check **Notification Delivery** on the request.
5. Check the real inbox/phone and provider logs.
6. Test the blank-letter attachment when selected.
7. Do not start a second local worker against production while troubleshooting.

## 11. Run the full online acceptance test

Record every result using [README4.md](README4.md).

- [ ] Homepage works on desktop and phone.
- [ ] Light and dark themes work.
- [ ] Strong admin login works; wrong password fails.
- [ ] All six Student/Faculty request combinations work.
- [ ] Wrong identity and duplicate SSPR are rejected.
- [ ] References remain unique.
- [ ] Approve, reject, reconsider, Done, and SSPR completion persist.
- [ ] Messages and priority persist.
- [ ] Gmail and optional SMS arrive at controlled recipients.
- [ ] Blank letter opens/attaches correctly.
- [ ] PDF and CSV exports follow filters.
- [ ] Sign-out and expired sessions block protected access.
- [ ] API/worker restart without losing data.
- [ ] A staging database outage has a documented recovery result.

The `/health` page alone proves only that the API process responds.

## 12. Add a school domain later (optional)

Ask the authorized school DNS administrator before touching DNS.

1. In Cloudflare Pages, open the project.
2. Open **Custom domains** and click **Set up a domain**.
3. Enter the approved site name, such as `reaccess.school-domain.edu.ph`.
4. Follow the exact DNS instructions shown by Cloudflare.
5. Wait for domain verification and HTTPS activation.
6. In Render API **Settings > Custom Domains**, optionally add the approved API name.
7. Follow Render's DNS instructions and test `/health` over HTTPS.
8. Change API `ALLOWED_ORIGINS` to the final website origin and redeploy.
9. If the API hostname changed, rebuild Flutter with the new full API URL and upload.
10. Test old and new links before announcing the domain.

Do not change the school's MX/email records or unrelated DNS entries.

## 13. Daily and weekly operation

Every day:

1. Check pending requests and failed notification jobs.
2. Check Render API and worker logs/events.
3. Check Supabase health/capacity.
4. Check Gmail/Twilio alerts and unusual activity.

Every week or on the approved schedule:

1. Confirm backups completed.
2. Review billing and capacity.
3. Review old pending jobs and error trends.
4. Remove access for staff who no longer need it.

Every month:

1. Restore a backup into a separate test project/database.
2. Run a small acceptance test.
3. Record the restore result.

## 14. Release an update

1. Test changes against staging.
2. Back up production before schema changes.
3. Commit and push the reviewed source.
4. Apply only new migrations as the database owner.
5. Add permissions/policies for new database objects.
6. Deploy matching API and worker versions.
7. Build Flutter with the intended production API URL.
8. Upload `build/web` to the production Pages project.
9. Run affected acceptance tests.
10. Record the prior working versions for rollback.

## 15. Roll back safely

1. Stop new submissions if bad records could be created.
2. Stop the worker if wrong/duplicate messages could be sent.
3. Select the previous tested Render deployments and Pages deployment only if
   they are compatible with the current database schema.
4. Do not undo a migration just because application code was rolled back.
5. Before restoring a database backup, identify and reconcile all newer requests.
6. Verify the recovered system before reopening it.

## 16. Troubleshooting

| Problem | What to check |
| --- | --- |
| Docker build cannot find shared package | Build context must be repository root `.` |
| Render says no open port | `API_HOST=0.0.0.0` and `API_PORT=10000` |
| API cannot connect to Supabase | Exact host, port, suffixed role username, password, TLS |
| `/health` works but login fails | Database/admin/permissions; health does not query every workflow |
| Website requests go to localhost | Rebuild with the full Render `API_BASE_URL` |
| Browser says CORS | Exact canonical site origin in first `ALLOWED_ORIGINS` value |
| Cloudflare shows old website | Check deployment URL, rebuild result, and browser cache |
| Worker waits for a port | It was created as Web Service; use Background Worker |
| Worker exits or sends nothing | Notification channel values and database errors in logs |
| Gmail rejects credentials | 2-Step Verification, App Password, Workspace policy |
| SMS fails | Sender capability, country permission, verified recipient, format, balance |
| Letter approval fails | File in image and exact `/app/templates/formal-letter.docx` path |
| A preview URL cannot call API | Only canonical production origin is allowed; use staging for previews |

## Final production checklist

- [ ] Private GitHub repository contains no secrets or personal-data backups.
- [ ] Supabase migration, restricted app role, RLS, and backups are verified.
- [ ] Data API remains disabled for this backend-only design.
- [ ] Docker image includes the shared package, font, and approved blank letter.
- [ ] Render API and worker use the intended production database.
- [ ] Cloudflare build uses the real HTTPS Render API URL.
- [ ] One canonical CORS origin is configured.
- [ ] Strong admin and academic period are ready.
- [ ] Real controlled email/SMS delivery is tested.
- [ ] Full online acceptance test passes.
- [ ] Backup restore drill and rollback plan pass.
- [ ] Billing alerts, owners, and daily response procedure are written down.
- [ ] CISO Office approves the launch link.
