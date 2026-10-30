# Blank Formal Letter Template

This folder contains `formal-letter.docx`. ReAccess Hub lets users download this
blank office form and can attach it to an approval email.

## Check or update the template

1. Open Windows File Explorer.
2. Go to:

```text
C:\Users\Admin\Documents\Thesis\Final System\reaccess_hub\backend\templates
```

3. Double-click `formal-letter.docx`.
4. In Microsoft Word, check the logo, title, instructions, blank fields, and
   signatory area with the CISO Office.
5. Make only approved changes.
6. Click **File > Save**.
7. Keep the file name exactly `formal-letter.docx`.
8. Keep it below 5 MB.
9. Close Word and test the download and email attachment in ReAccess Hub.

## Settings to use

For the local Dart API, put this in `backend/.env`:

```dotenv
LETTER_TEMPLATE_PATH=C:/Users/Admin/Documents/Thesis/Final System/reaccess_hub/backend/templates/formal-letter.docx
LETTER_TEMPLATE_URL=
```

For Docker or Render, use:

```dotenv
LETTER_TEMPLATE_PATH=/app/templates/formal-letter.docx
```

`LETTER_TEMPLATE_URL` is optional. If used online, it must be the public HTTPS
URL of the same approved blank file.

## Safety rules

- Keep this document blank; never save a filled student/faculty letter here.
- Do not put IDs, names, emails, phone numbers, or passwords in this folder.
- Back up an office-approved customized template in encrypted private storage.
- Restart the API after changing its environment settings.
