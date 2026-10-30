# Setup and Next Steps

The setup instructions have been consolidated into two maintained guides:

1. [README: run the frontend, API and Docker deployment](../README.md)
2. [README2: migrate PostgreSQL, import records and complete production setup](../README2.md)

Use README2 when upgrading an existing database. Do not remove its volume to
rerun initialization scripts.

## Current Capabilities

- Public homepage with light/dark mode, local FAQs and browser-persisted chat.
- Student/faculty SSPR, recovery and update request forms.
- Real backend eligibility checks, signed verification tokens and transactional
  submissions with monthly reference numbers.
- Permission-protected admin request list and support inbox.
- Optional backend AI support and explicit Ask the CISO Office handoff action.
  Typed questions and handoff no longer open extra confirmation dialogs;
  deleting chat history still requires confirmation.

## Important Limits

PostgreSQL and institutional records must be configured before verification and
submission can succeed. Missing services do not produce simulated receipts.

Name and ID matching allows a request to be reviewed, not an automatic password
reset or account change. The staff approval workflow, stronger identity
challenge, email/SMS notifications and remaining administrator session controls
must be completed before production.

Do not place real personal records, database credentials or AI secrets in
Flutter code, assets, browser storage or Git.
