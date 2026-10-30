# ReAccess Hub - Start Here

ReAccess Hub is a Flutter website with a Dart API and a PostgreSQL database. It
handles student and faculty account-service requests for the CISO Office.

This page is the easiest local setup. Follow the numbered steps in order. Do not
skip a step because the website can open even when saving and login are broken.

## Which guide should I read?

| If you want to... | Read... |
| --- | --- |
| Run the whole project on this computer | This file |
| Set up, import, back up, or upgrade the database | [README2.md](README2.md) |
| Create admins, set semesters, email users, or send SMS | [README3.md](README3.md) |
| Test the system and prepare it for real users | [README4.md](README4.md) |
| Move PostgreSQL to Supabase | [README5.md](README5.md) |
| Put the website, API, and worker online | [README6.md](README6.md) |
| Apply the immediate six-character Faculty ID update | [README7.md](README7.md) |
| Replace personal Gmail/Twilio accounts before deployment | [README13.md](README13.md) |
| Fix Student/Faculty identity verification returning a request-service error | [README20.md](README20.md) |
| Enable permanent deletion for Admin Public Help Chat conversations | [README30.md](README30.md) |

## Before you begin

You need a Windows computer with:

- [VS Code](https://code.visualstudio.com/)
- [Flutter](https://docs.flutter.dev/get-started/install/windows/web)
- Google Chrome or Microsoft Edge
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)

Use made-up student information while learning. Never upload `.env`, database
backups, school registry files, passwords, or real student information to GitHub.

## Step 1 - Open the correct folder in VS Code

1. Start VS Code.
2. Click **File > Open Folder**.
3. Choose `C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub`.
4. Click **Select Folder**.
5. If VS Code asks whether you trust the folder, click **Yes, I trust the authors**
   only if this is your own approved project copy.
6. Click **Terminal > New Terminal**. A PowerShell panel opens at the bottom.
7. Run this command:

```powershell
Get-Location
```

The last folder shown must be `reaccess_hub`. If it is not, run:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub'
```

## Step 2 - Check the required programs

1. Start Docker Desktop from the Windows Start menu.
2. Wait until Docker Desktop says the engine is running.
3. Return to the VS Code terminal and run:

```powershell
flutter doctor
docker --version
docker compose version
```

If PowerShell says a command is not recognized, install that program, close VS
Code, reopen it, and run the checks again.

## Step 3 - Download the project packages

In the VS Code terminal, copy and run this whole block:

```powershell
flutter pub get
Push-Location backend
dart pub get
Pop-Location
```

Wait for each command to finish. Red error text must be fixed before continuing.

## Step 4 - Make the two settings files

The project uses two local settings files:

- `.env` is used by Docker Compose.
- `backend/.env` is used when the Dart API runs from a terminal.

The following command creates each file only when it does not already exist. It
does not overwrite your current settings.

```powershell
if (!(Test-Path .env)) { Copy-Item .env.example .env }
if (!(Test-Path backend/.env)) { Copy-Item backend/.env.example backend/.env }
```

Now open the files:

1. In the VS Code Explorer on the left, click `.env`.
2. In another tab, open the `backend` folder and click `.env`.
3. If you cannot see files beginning with a dot, press `Ctrl+P`, type `.env`, and
   press Enter. Repeat with `backend/.env`.

## Step 5 - Create the three secret values

You need three different secrets. Do not use the examples from `.env.example`.

1. Open a new terminal with **Terminal > New Terminal**.
2. Run this block three separate times:

```powershell
$secretBytes = [byte[]]::new(48)
[System.Security.Cryptography.RandomNumberGenerator]::Fill($secretBytes)
[Convert]::ToBase64String($secretBytes)
```

3. Save the first result in a password manager as `ReAccess local database app password`.
4. Save the second as `ReAccess local PostgreSQL owner password`.
5. Save the third as `ReAccess local JWT secret`.

Do not paste those values into this README, chat, screenshots, or GitHub.

## Step 6 - Fill in the root `.env`

In the root `.env` tab, find the lines below. Keep all other lines as they are.

```dotenv
APP_ENV=development
API_HOST=0.0.0.0
API_PORT=8080
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8081
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=reaccess_hub
DATABASE_USER=reaccess_app
DATABASE_PASSWORD=PASTE_THE_FIRST_SECRET_HERE
POSTGRES_ADMIN_PASSWORD=PASTE_THE_SECOND_SECRET_HERE
DATABASE_SSL=false
JWT_SECRET=PASTE_THE_THIRD_SECRET_HERE
ACCESS_TOKEN_MINUTES=15
REFRESH_TOKEN_DAYS=7
SKIP_DATABASE_CONNECTION=false
```

Replace only the three `PASTE_...` parts with the saved values. Do not add quotes.
Press `Ctrl+S` to save.

## Step 7 - Fill in `backend/.env`

Open `backend/.env` and make these lines match. The database password and JWT
secret must be the same first and third values used in the root `.env`.

```dotenv
APP_ENV=development
API_HOST=0.0.0.0
API_PORT=8080
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8081
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=reaccess_hub
DATABASE_USER=reaccess_app
DATABASE_PASSWORD=PASTE_THE_SAME_FIRST_SECRET_HERE
DATABASE_SSL=false
JWT_SECRET=PASTE_THE_SAME_THIRD_SECRET_HERE
ACCESS_TOKEN_MINUTES=15
REFRESH_TOKEN_DAYS=7
SKIP_DATABASE_CONNECTION=false
SMTP_HOST=smtp.gmail.com
SMTP_PORT=465
SMTP_FROM=
SMTP_USERNAME=
SMTP_PASSWORD=
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_FROM_NUMBER=
TWILIO_MESSAGING_SERVICE_SID=
LETTER_TEMPLATE_PATH=
LETTER_TEMPLATE_URL=
REPORT_FONT_PATH=
```

Leave optional email, SMS, AI, letter, and font settings empty for now. Press
`Ctrl+S`. Email and SMS are explained in [README3.md](README3.md).

## Step 8 - Start the new local database

In the terminal at the project root, run:

```powershell
docker compose up -d postgres
docker compose ps
docker compose logs --tail 80 postgres
```

Look for `database system is ready to accept connections`. The supplied Docker
setup creates a database, applies migrations `001` through `008`, and creates the
restricted `reaccess_app` login only the first time a new database volume starts.

If this computer already has project data, stop here and follow the backup and
upgrade steps in [README2.md](README2.md). Do not run `docker compose down -v` on
a database you want to keep.
 
## Step 9 - Create the local administrator

This repository contains a staged development account. It is not added to the
database until you run the command below.

1. In VS Code, click **Terminal > New Terminal**.
2. Run:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub\backend'
dart run bin/local_admin.dart
```

3. Expect `Local administrator created`.
4. If it says the user already exists, do not keep rerunning it. Try signing in.

Development login after activation:

```text
Username: admin
Temporary password: ABC123
```

This account is for local development only. Change the password immediately after
the first login. Use `dart run bin/create_admin.dart` for a real administrator.

## Step 10 - Start the API

Keep Docker Desktop and PostgreSQL running. In a new VS Code terminal, run:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub\backend'
dart run bin/server.dart
```

Leave this terminal open. The API should listen on port `8080`. To check it,
open [http://localhost:8080/health](http://localhost:8080/health) in a browser.

## Step 11 - Start the Flutter website

1. Click **Terminal > New Terminal** again. Do not close the API terminal.
2. Run:

```powershell
Set-Location 'C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub'
flutter run -d chrome --web-port 3000 --dart-define=API_BASE_URL=http://localhost:8080/api/v1
```

3. Wait for Chrome to open.
4. Open [http://localhost:3000](http://localhost:3000) for the public site.
5. Open [http://localhost:3000/#/admin/login](http://localhost:3000/#/admin/login)
   for the admin login.
6. Sign in, open **Settings**, and change the temporary password.

## Step 12 - Stop the project safely

1. In the Flutter terminal, press `Ctrl+C`.
2. In the API terminal, press `Ctrl+C`.
3. In a terminal at the project root, run:

```powershell
docker compose stop postgres
```

This stops the database without deleting it. Never add `-v` unless an authorized
maintainer has confirmed the database may be permanently erased.

## Step 13 - Start it again tomorrow

You do not repeat installation or recreate the admin. Run:

```powershell
docker compose up -d postgres
```

Then repeat Step 10 in one terminal and Step 11 in another.

## Step 14 - Run the automatic checks

From the project root:

```powershell
flutter analyze
flutter test
Push-Location backend
dart analyze
dart analyze
Pop-Location
```

All commands should end without errors. These checks do not prove that Gmail,
Twilio, backups, or a production database work; those need the manual checks in
[README4.md](README4.md).

## What to back up

Before migrations, deployment, or real use, back up:

1. The PostgreSQL database. Exact Docker commands are in [README2.md](README2.md).
2. `.env` and `backend/.env` into encrypted, access-controlled storage outside
   this repository.
3. `backend/templates/formal-letter.docx` if the office approved a customized copy.
4. The exact source release used to run the system.

A folder copied to the same computer is not enough protection. Keep an encrypted
copy on approved separate storage and practice restoring it.

## Quick problem guide

| Problem | What to do |
| --- | --- |
| `flutter` is not recognized | Install Flutter, add it to PATH, then restart VS Code |
| Docker command fails | Open Docker Desktop and wait for the engine |
| Port 5432 is already used | Stop the other PostgreSQL service or change the Docker port and matching settings |
| API says password authentication failed | Make `DATABASE_PASSWORD` identical in both `.env` files |
| Website opens but cannot save | Check the API terminal, database container, and `API_BASE_URL` |
| Login says invalid credentials | Apply migrations, run the admin command once, and use the changed password if already changed |
| Port 3000 or 8080 is busy | Stop the old process with `Ctrl+C`, or deliberately choose matching new ports |

## Main project folders

| Folder | What it contains |
| --- | --- |
| `lib/features/requests` | Student and faculty request pages |
| `lib/features/admin` | Admin portal |
| `backend/lib/src` | API and database logic |
| `backend/migrations` | Database changes, in order |
| `backend/bin` | Server, worker, import, and admin tools |
| `backend/templates` | Blank office letter template |
| `packages/request_contract` | Rules shared by frontend and backend |

Next: follow [README2.md](README2.md) to learn backups, registry imports, and
database upgrades before entering real information.
