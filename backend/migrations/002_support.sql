BEGIN;
CREATE TABLE IF NOT EXISTS support_tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  visitor_token_hash char(64) NOT NULL,
  transcript jsonb NOT NULL CHECK (jsonb_typeof(transcript) = 'array'),
  status varchar(16) NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'ANSWERED')),
  reply varchar(4000),
  replied_by uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT now() + interval '30 days'
);
CREATE INDEX IF NOT EXISTS support_tickets_queue ON support_tickets (status, created_at);
INSERT INTO permissions (name, description)
VALUES ('manage_support', 'Read anonymous support conversations and send office replies.')
ON CONFLICT (name) DO NOTHING;
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p
WHERE r.name = 'SUPER_ADMIN' AND p.name = 'manage_support'
ON CONFLICT DO NOTHING;
COMMIT;
