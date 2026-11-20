-- Marks every currently submitted application as approved by Olivia.
-- Safe to rerun; it affects only rows still in SUBMITTED status.
BEGIN;
WITH officer AS (
  SELECT id FROM users WHERE username = 'olivia' AND role = 'OFFICER'
)
UPDATE loan_applications
SET status = 'APPROVED',
    decision_note = NULL,
    decided_by = (SELECT id FROM officer),
    decided_at = now()
WHERE status = 'SUBMITTED';
COMMIT;
