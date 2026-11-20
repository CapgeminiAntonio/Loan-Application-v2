# Field Dictionary

| Table | Column | SQL type | JSON name | Nullable | Constraints / meaning |
|---|---|---|---|---|---|
| users | id | BIGSERIAL | id | no | Primary key |
| users | username | VARCHAR(50) | username | no | Unique login name |
| users | password_hash | VARCHAR(100) | - | no | BCrypt password hash only |
| users | full_name | VARCHAR(100) | fullName | no | Display name |
| users | role | VARCHAR(20) | role | no | CUSTOMER or OFFICER |
| users | created_at | TIMESTAMPTZ | - | no | Account creation time |
| loan_applications | id | BIGSERIAL | id | no | Primary key |
| loan_applications | reference | VARCHAR(20) | reference | no | Unique LA-000NNN sequence reference |
| loan_applications | customer_id | BIGINT | applicant.id | no | FK to a CUSTOMER user |
| loan_applications | amount | NUMERIC(12,2) | amount | no | 1000.00–50000.00 |
| loan_applications | term_months | SMALLINT | termMonths | no | 12, 24, 36, 48, or 60 |
| loan_applications | purpose | VARCHAR(30) | purpose | no | Allowed purpose enum |
| loan_applications | employment_status | VARCHAR(20) | employmentStatus | no | Allowed employment enum |
| loan_applications | monthly_income | NUMERIC(12,2) | monthlyIncome | no | Greater than 0, at most 1000000.00 |
| loan_applications | status | VARCHAR(20) | status | no | SUBMITTED, APPROVED, or REJECTED |
| loan_applications | submitted_at | TIMESTAMPTZ | submittedAt | no | UTC submission timestamp |
| loan_applications | request_key | UUID | - | no | Idempotency key, unique per customer |
| loan_applications | request_hash | CHAR(64) | - | no | SHA-256 canonical payload hash |
| loan_applications | decision_note | VARCHAR(1000) | decisionNote | yes | Required for REJECTED; optional for APPROVED |
| loan_applications | decided_by | BIGINT | decidedBy.id | yes | FK to an OFFICER user |
| loan_applications | decided_at | TIMESTAMPTZ | decidedAt | yes | UTC decision timestamp |
