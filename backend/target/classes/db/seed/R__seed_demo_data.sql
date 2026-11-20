INSERT INTO users (id, username, password_hash, full_name, role, created_at) VALUES
  (1, 'alice', '$2a$10$s8h7RhdVu9vACi4Ge5O6u.v859fHCmhha/F2x7gYDDQ32HjaBKawq', 'Alice Customer', 'CUSTOMER', '2026-10-01T09:00:00Z'),
  (2, 'bob', '$2a$10$s8h7RhdVu9vACi4Ge5O6u.v859fHCmhha/F2x7gYDDQ32HjaBKawq', 'Bob Borrower', 'CUSTOMER', '2026-10-01T09:00:00Z'),
  (3, 'carol', '$2a$10$s8h7RhdVu9vACi4Ge5O6u.v859fHCmhha/F2x7gYDDQ32HjaBKawq', 'Carol Newcomer', 'CUSTOMER', '2026-10-01T09:00:00Z'),
  (4, 'olivia', '$2a$10$s8h7RhdVu9vACi4Ge5O6u.v859fHCmhha/F2x7gYDDQ32HjaBKawq', 'Olivia Officer', 'OFFICER', '2026-10-01T09:00:00Z'),
  (5, 'oscar', '$2a$10$s8h7RhdVu9vACi4Ge5O6u.v859fHCmhha/F2x7gYDDQ32HjaBKawq', 'Oscar Officer', 'OFFICER', '2026-10-01T09:00:00Z')
ON CONFLICT (id) DO UPDATE SET
  username = EXCLUDED.username,
  password_hash = EXCLUDED.password_hash,
  full_name = EXCLUDED.full_name,
  role = EXCLUDED.role;

INSERT INTO loan_applications
  (id, reference, customer_id, amount, term_months, purpose, employment_status, monthly_income, status, submitted_at, request_key, request_hash, decision_note, decided_by, decided_at)
VALUES
  (1, 'LA-000001', 1, 12500.00, 36, 'VEHICLE', 'EMPLOYED', 4200.00, 'SUBMITTED', '2026-11-20T15:04:05Z', '10000000-0000-4000-8000-000000000001', repeat('1',64), NULL, NULL, NULL),
  (2, 'LA-000002', 1, 20000.00, 48, 'HOME_IMPROVEMENT', 'EMPLOYED', 6000.00, 'APPROVED', '2026-11-18T10:00:00Z', '10000000-0000-4000-8000-000000000002', repeat('2',64), 'Application meets all requirements.', 4, '2026-11-19T09:30:00Z'),
  (3, 'LA-000003', 1, 8000.00, 24, 'MEDICAL', 'EMPLOYED', 3000.00, 'REJECTED', '2026-11-17T10:00:00Z', '10000000-0000-4000-8000-000000000003', repeat('3',64), 'Monthly income does not support the requested amount.', 4, '2026-11-18T09:30:00Z'),
  (4, 'LA-000004', 2, 15000.00, 36, 'DEBT_CONSOLIDATION', 'SELF_EMPLOYED', 5000.00, 'SUBMITTED', '2026-11-16T12:00:00Z', '10000000-0000-4000-8000-000000000004', repeat('4',64), NULL, NULL, NULL),
  (5, 'LA-000005', 2, 18000.00, 24, 'EDUCATION', 'EMPLOYED', 5500.00, 'SUBMITTED', '2026-11-16T12:00:00Z', '10000000-0000-4000-8000-000000000005', repeat('5',64), NULL, NULL, NULL)
ON CONFLICT (id) DO UPDATE SET
  reference = EXCLUDED.reference,
  customer_id = EXCLUDED.customer_id,
  amount = EXCLUDED.amount,
  term_months = EXCLUDED.term_months,
  purpose = EXCLUDED.purpose,
  employment_status = EXCLUDED.employment_status,
  monthly_income = EXCLUDED.monthly_income,
  status = EXCLUDED.status,
  submitted_at = EXCLUDED.submitted_at,
  request_key = EXCLUDED.request_key,
  request_hash = EXCLUDED.request_hash,
  decision_note = EXCLUDED.decision_note,
  decided_by = EXCLUDED.decided_by,
  decided_at = EXCLUDED.decided_at;

SELECT setval(pg_get_serial_sequence('users','id'), (SELECT max(id) FROM users));
SELECT setval(pg_get_serial_sequence('loan_applications','id'), (SELECT max(id) FROM loan_applications));
SELECT setval('loan_application_ref_seq', 5, true);
