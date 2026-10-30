BEGIN;
-- Existing Office 365 records are separate from administrator login accounts.
CREATE TABLE IF NOT EXISTS school_registry (
  person_kind varchar(8) NOT NULL CHECK (person_kind IN ('STUDENT', 'FACULTY')),
  person_id varchar(30) NOT NULL,
  first_name varchar(100) NOT NULL,
  middle_name varchar(100) NOT NULL DEFAULT '',
  last_name varchar(100) NOT NULL,
  institute text NOT NULL,
  program text NOT NULL DEFAULT '',
  position varchar(20) NOT NULL DEFAULT '',
  school_email varchar(254) NOT NULL,
  active boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (person_kind, person_id),
  CHECK ((person_kind = 'STUDENT' AND person_id ~ '^[0-9]{6}$') OR
    (person_kind = 'FACULTY' AND person_id ~ '^[A-Z0-9-]{6,30}$' AND length(regexp_replace(person_id, '[^0-9]', '', 'g')) = 6))
);
CREATE TABLE IF NOT EXISTS request_monthly_counters (
  person_kind varchar(8) NOT NULL CHECK (person_kind IN ('STUDENT', 'FACULTY')),
  request_month char(7) NOT NULL,
  last_value integer NOT NULL CHECK (last_value > 0),
  PRIMARY KEY (person_kind, request_month)
);
CREATE TABLE IF NOT EXISTS account_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference varchar(40) NOT NULL UNIQUE,
  person_kind varchar(8) NOT NULL CHECK (person_kind IN ('STUDENT', 'FACULTY')),
  person_id varchar(30) NOT NULL,
  request_type varchar(12) NOT NULL CHECK (request_type IN ('SSPR', 'RECOVERY', 'UPDATE')),
  payload jsonb NOT NULL,
  payload_hash char(64) NOT NULL,
  verification_nonce varchar(64) NOT NULL UNIQUE,
  status varchar(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'IN_REVIEW', 'COMPLETED', 'REJECTED')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS account_requests_identity ON account_requests (person_kind, person_id);
CREATE INDEX IF NOT EXISTS account_requests_queue ON account_requests (status, created_at);
CREATE UNIQUE INDEX IF NOT EXISTS one_pending_sspr ON account_requests (person_kind, person_id)
  WHERE request_type = 'SSPR' AND status IN ('PENDING', 'IN_REVIEW');
INSERT INTO permissions (name, description) VALUES
  ('manage_requests', 'Read and review student and faculty account-service requests.'),
  ('manage_registry', 'Maintain the office account registry.')
ON CONFLICT (name) DO NOTHING;
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p
WHERE r.name = 'SUPER_ADMIN' AND p.name IN ('manage_requests', 'manage_registry')
ON CONFLICT DO NOTHING;
COMMIT;
