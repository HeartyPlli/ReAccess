BEGIN;

-- Keep support-ticket history when a student or faculty registry record is
-- permanently deleted. Only the link to the deleted ID is cleared.
ALTER TABLE support_tickets
  DROP CONSTRAINT IF EXISTS support_tickets_person_id_fkey;
ALTER TABLE support_tickets
  ADD CONSTRAINT support_tickets_person_id_fkey
  FOREIGN KEY (person_id) REFERENCES school_registry(person_id)
  ON DELETE SET NULL;

COMMIT;
