BEGIN;

-- Institutional ID numbers are globally unique across students and faculty.
-- Stop rather than silently choosing a record if legacy data contains duplicates.
DO $$
BEGIN
  IF EXISTS (
    SELECT person_id FROM school_registry
    GROUP BY person_id HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'Duplicate person_id values must be resolved before migration 005.';
  END IF;
END $$;

ALTER TABLE school_registry DROP CONSTRAINT IF EXISTS school_registry_pkey;
ALTER TABLE school_registry ADD CONSTRAINT school_registry_pkey PRIMARY KEY (person_id);
CREATE INDEX IF NOT EXISTS school_registry_kind_name
  ON school_registry (person_kind, last_name, first_name);

ALTER TABLE support_tickets
  ADD COLUMN IF NOT EXISTS person_id varchar(30);
ALTER TABLE support_tickets
  DROP CONSTRAINT IF EXISTS support_tickets_person_id_fkey;
ALTER TABLE support_tickets
  ADD CONSTRAINT support_tickets_person_id_fkey
  FOREIGN KEY (person_id) REFERENCES school_registry(person_id);
CREATE INDEX IF NOT EXISTS support_tickets_person_id
  ON support_tickets (person_id, created_at DESC);

COMMIT;
