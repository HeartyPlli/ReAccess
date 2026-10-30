BEGIN;

-- Student IDs remain exactly six numbers.
-- Faculty IDs become exactly six letters and/or numbers, with no spaces or
-- punctuation. Examples: AB1234, ACB123, 1921GA.
ALTER TABLE school_registry
  DROP CONSTRAINT IF EXISTS school_registry_check;
ALTER TABLE school_registry
  DROP CONSTRAINT IF EXISTS school_registry_person_id_format_check;
ALTER TABLE school_registry
  ADD CONSTRAINT school_registry_person_id_format_check
  CHECK (
    (person_kind = 'STUDENT' AND person_id ~ '^[0-9]{6}$') OR
    (person_kind = 'FACULTY' AND person_id ~ '^[A-Z0-9]{6}$')
  );

COMMIT;
