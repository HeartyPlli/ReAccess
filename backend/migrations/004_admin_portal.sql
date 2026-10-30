BEGIN;
ALTER TABLE users ADD COLUMN IF NOT EXISTS username varchar(254);
UPDATE users SET username = lower(email) WHERE username IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS users_username_unique ON users (lower(username));
ALTER TABLE users ADD COLUMN IF NOT EXISTS token_version integer NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS must_change_password boolean NOT NULL DEFAULT false;
ALTER TABLE school_registry ADD COLUMN IF NOT EXISTS contact varchar(20) NOT NULL DEFAULT '';
ALTER TABLE school_registry ADD COLUMN IF NOT EXISTS gmail varchar(254) NOT NULL DEFAULT '';

CREATE TABLE IF NOT EXISTS academic_periods (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 semester varchar(30) NOT NULL,
 academic_year varchar(9) NOT NULL,
 start_date date NOT NULL,
 end_date date NOT NULL CHECK(end_date >= start_date),
 UNIQUE(semester, academic_year),
 EXCLUDE USING gist (daterange(start_date, end_date, '[]') WITH &&)
);
CREATE TABLE IF NOT EXISTS portal_settings (
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
 current_period uuid REFERENCES academic_periods(id)
);
INSERT INTO portal_settings(singleton) VALUES(true) ON CONFLICT DO NOTHING;
ALTER TABLE account_requests DROP CONSTRAINT IF EXISTS account_requests_status_check;
ALTER TABLE account_requests ADD CONSTRAINT account_requests_status_check
 CHECK(status IN ('PENDING','IN_REVIEW','APPROVED','REJECTED','COMPLETED'));
ALTER TABLE account_requests ADD COLUMN IF NOT EXISTS semester_id uuid REFERENCES academic_periods(id);
ALTER TABLE account_requests ADD COLUMN IF NOT EXISTS reviewer_notes varchar(2000) NOT NULL DEFAULT '';
ALTER TABLE account_requests ADD COLUMN IF NOT EXISTS requires_letter boolean NOT NULL DEFAULT false;
ALTER TABLE account_requests ADD COLUMN IF NOT EXISTS reviewed_by uuid REFERENCES users(id);
ALTER TABLE account_requests ADD COLUMN IF NOT EXISTS reviewed_at timestamptz;
ALTER TABLE account_requests ADD COLUMN IF NOT EXISTS completed_at timestamptz;
ALTER TABLE account_requests ADD COLUMN IF NOT EXISTS registry_applied boolean NOT NULL DEFAULT false;
ALTER TABLE account_requests ADD COLUMN IF NOT EXISTS work_payload jsonb;
DROP INDEX IF EXISTS one_pending_sspr;
CREATE UNIQUE INDEX one_pending_sspr ON account_requests(person_kind,person_id)
 WHERE request_type='SSPR' AND status IN('PENDING','IN_REVIEW','APPROVED','COMPLETED') AND registry_applied=false;
CREATE OR REPLACE FUNCTION assign_request_semester() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 SELECT id INTO NEW.semester_id FROM academic_periods
 WHERE (NEW.created_at AT TIME ZONE 'Asia/Manila')::date BETWEEN start_date AND end_date LIMIT 1;
 RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS account_request_semester ON account_requests;
CREATE TRIGGER account_request_semester BEFORE INSERT ON account_requests
 FOR EACH ROW EXECUTE FUNCTION assign_request_semester();

CREATE TABLE IF NOT EXISTS request_messages (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 request_id uuid NOT NULL REFERENCES account_requests(id),
 sender_id uuid NOT NULL REFERENCES users(id),
 body varchar(4000) NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE account_requests ADD COLUMN IF NOT EXISTS priority boolean NOT NULL DEFAULT false;
ALTER TABLE support_tickets ADD COLUMN IF NOT EXISTS priority boolean NOT NULL DEFAULT false;
CREATE TABLE IF NOT EXISTS notification_outbox (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 event_key varchar(160) NOT NULL,
 channel varchar(8) NOT NULL CHECK(channel IN ('EMAIL','SMS')),
 recipient varchar(254) NOT NULL,
 subject varchar(200) NOT NULL,
 body text NOT NULL,
 attachment_path text,
 status varchar(16) NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING','SENDING','SENT','FAILED')),
 attempts integer NOT NULL DEFAULT 0,
 available_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 last_error varchar(200),
 UNIQUE(event_key,channel,recipient)
);
INSERT INTO permissions(name,description) VALUES
 ('view_audit','Read and export audit records.'),
 ('manage_settings','Manage academic periods.')
ON CONFLICT(name) DO NOTHING;
INSERT INTO role_permissions(role_id,permission_id)
 SELECT r.id,p.id FROM roles r CROSS JOIN permissions p
 WHERE r.name='SUPER_ADMIN' AND p.name IN ('view_reports','view_audit','manage_settings')
 ON CONFLICT DO NOTHING;
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS actor_role varchar(50);
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS person_kind varchar(8);
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS semester_id uuid REFERENCES academic_periods(id);
CREATE OR REPLACE FUNCTION stamp_audit_context() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF NEW.user_id IS NOT NULL THEN
  SELECT r.name INTO NEW.actor_role FROM roles r JOIN user_roles ur ON ur.role_id=r.id
  WHERE ur.user_id=NEW.user_id ORDER BY (r.name='SUPER_ADMIN') DESC,r.name LIMIT 1;
 END IF;
 IF NEW.resource_type='account_request' THEN
  SELECT person_kind,semester_id INTO NEW.person_kind,NEW.semester_id FROM account_requests WHERE id::text=NEW.resource_id;
 END IF;
 IF NEW.semester_id IS NULL THEN
  SELECT id INTO NEW.semester_id FROM academic_periods WHERE (NEW.created_at AT TIME ZONE 'Asia/Manila')::date BETWEEN start_date AND end_date LIMIT 1;
 END IF;
 RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS audit_context ON audit_logs;
CREATE TRIGGER audit_context BEFORE INSERT ON audit_logs FOR EACH ROW EXECUTE FUNCTION stamp_audit_context();
COMMIT;
