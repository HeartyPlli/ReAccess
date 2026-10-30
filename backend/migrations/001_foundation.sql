CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email varchar(254) NOT NULL UNIQUE,
  password_hash text NOT NULL,
  first_name varchar(100) NOT NULL,
  last_name varchar(100) NOT NULL,
  status varchar(30) NOT NULL DEFAULT 'ACTIVE',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name varchar(50) NOT NULL UNIQUE,
  description text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name varchar(80) NOT NULL UNIQUE,
  description text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_roles (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role_id uuid NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, role_id)
);

CREATE TABLE IF NOT EXISTS role_permissions (
  role_id uuid NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  permission_id uuid NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE IF NOT EXISTS announcements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title varchar(160) NOT NULL,
  description text NOT NULL,
  published_at timestamptz,
  status varchar(30) NOT NULL DEFAULT 'DRAFT',
  created_by uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  action varchar(80) NOT NULL,
  resource_type varchar(80) NOT NULL,
  resource_id varchar(120),
  description text,
  ip_address inet,
  user_agent text,
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO roles (name, description)
VALUES
  ('SUPER_ADMIN', 'Full system access.'),
  ('ADMIN', 'School administration access.'),
  ('REGISTRAR', 'Enrollment and student record access.'),
  ('TEACHER', 'Class, attendance, and grade access by assignment.'),
  ('ACCOUNTING', 'Payment and billing access.'),
  ('STUDENT', 'Own student records only.')
ON CONFLICT (name) DO NOTHING;

INSERT INTO permissions (name, description)
VALUES
  ('manage_users', 'Create, update, disable, and assign user access.'),
  ('manage_students', 'Manage student records.'),
  ('manage_teachers', 'Manage teacher records.'),
  ('manage_enrollment', 'Manage enrollment records.'),
  ('manage_subjects', 'Manage subjects.'),
  ('manage_sections', 'Manage sections.'),
  ('manage_grades', 'Manage grades with record-level checks.'),
  ('manage_attendance', 'Manage attendance with record-level checks.'),
  ('manage_schedules', 'Manage schedules.'),
  ('manage_announcements', 'Manage public announcements.'),
  ('view_reports', 'View administrative reports.'),
  ('manage_payments', 'Manage payments.'),
  ('view_own_grades', 'View own grades only.'),
  ('view_own_attendance', 'View own attendance only.')
ON CONFLICT (name) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'SUPER_ADMIN'
ON CONFLICT DO NOTHING;
