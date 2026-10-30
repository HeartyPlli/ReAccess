BEGIN;

CREATE TABLE IF NOT EXISTS institutions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name varchar(150) NOT NULL,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS institutions_name_unique
  ON institutions (lower(name));

CREATE TABLE IF NOT EXISTS institution_programs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  institution_id uuid NOT NULL REFERENCES institutions(id),
  name varchar(200) NOT NULL,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS institution_programs_name_unique
  ON institution_programs (institution_id, lower(name));

ALTER TABLE portal_settings
  ADD COLUMN IF NOT EXISTS student_request_limit integer NOT NULL DEFAULT 0;
ALTER TABLE portal_settings
  DROP CONSTRAINT IF EXISTS portal_settings_student_request_limit_check;
ALTER TABLE portal_settings
  ADD CONSTRAINT portal_settings_student_request_limit_check
  CHECK (student_request_limit BETWEEN 0 AND 100);
ALTER TABLE portal_settings
  ADD COLUMN IF NOT EXISTS student_request_limit_reset_at timestamptz NOT NULL DEFAULT now();

INSERT INTO institutions(name)
SELECT seed.name
FROM (VALUES
  ('Institute of Computer Studies'),
  ('Institute of Health Sciences'),
  ('Institute of Art and Sciences'),
  ('Institute of Teacher Education'),
  ('Institute of Business and Financial Services'),
  ('Institute of Criminal Justice Education')
) AS seed(name)
WHERE NOT EXISTS (
  SELECT 1 FROM institutions existing WHERE lower(existing.name)=lower(seed.name)
);

INSERT INTO institution_programs(institution_id,name)
SELECT institution.id, seed.program
FROM (VALUES
  ('Institute of Computer Studies','Bachelor of Science in Computer Science'),
  ('Institute of Health Sciences','Diploma in Midwifery'),
  ('Institute of Art and Sciences','Bachelor of Arts in Communication'),
  ('Institute of Art and Sciences','Bachelor of Arts in English Language'),
  ('Institute of Art and Sciences','Bachelor of Arts in Political Science'),
  ('Institute of Teacher Education','Bachelor of Elementary Education'),
  ('Institute of Teacher Education','Bachelor of Secondary Education Major in English'),
  ('Institute of Teacher Education','Bachelor of Secondary Education Major in Filipino'),
  ('Institute of Teacher Education','Bachelor of Secondary Education Major in Math'),
  ('Institute of Teacher Education','Bachelor of Secondary Education Major in Social Studies'),
  ('Institute of Business and Financial Services','Bachelor of Science in Business Administration Major in Human Resource Management'),
  ('Institute of Business and Financial Services','Bachelor of Science in Business Administration Major in Marketing Management'),
  ('Institute of Business and Financial Services','Bachelor of Science in Office Administration'),
  ('Institute of Business and Financial Services','Bachelor of Science in Business Administration Major in Financial Management'),
  ('Institute of Criminal Justice Education','Bachelor of Science in Criminology'),
  ('Institute of Criminal Justice Education','Bachelor of Science in Industrial Security Management')
) AS seed(institute,program)
JOIN institutions institution ON lower(institution.name)=lower(seed.institute)
WHERE NOT EXISTS (
  SELECT 1 FROM institution_programs existing
  WHERE existing.institution_id=institution.id
    AND lower(existing.name)=lower(seed.program)
);

COMMIT;
