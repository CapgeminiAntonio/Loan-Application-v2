CREATE TABLE users (
  id BIGSERIAL PRIMARY KEY,
  username VARCHAR(50) NOT NULL UNIQUE,
  password_hash VARCHAR(100) NOT NULL,
  full_name VARCHAR(100) NOT NULL,
  role VARCHAR(20) NOT NULL CHECK (role IN ('CUSTOMER','OFFICER')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE SEQUENCE loan_application_ref_seq;

CREATE TABLE loan_applications (
  id BIGSERIAL PRIMARY KEY,
  reference VARCHAR(20) NOT NULL UNIQUE,
  customer_id BIGINT NOT NULL REFERENCES users(id),
  amount NUMERIC(12,2) NOT NULL CHECK (amount BETWEEN 1000.00 AND 50000.00),
  term_months SMALLINT NOT NULL CHECK (term_months IN (12,24,36,48,60)),
  purpose VARCHAR(30) NOT NULL CHECK (purpose IN ('HOME_IMPROVEMENT','DEBT_CONSOLIDATION','VEHICLE','EDUCATION','MEDICAL','OTHER')),
  employment_status VARCHAR(20) NOT NULL CHECK (employment_status IN ('EMPLOYED','SELF_EMPLOYED','UNEMPLOYED','RETIRED','STUDENT')),
  monthly_income NUMERIC(12,2) NOT NULL CHECK (monthly_income > 0 AND monthly_income <= 1000000.00),
  status VARCHAR(20) NOT NULL DEFAULT 'SUBMITTED' CHECK (status IN ('SUBMITTED','APPROVED','REJECTED')),
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  request_key UUID NOT NULL,
  request_hash CHAR(64) NOT NULL,
  decision_note VARCHAR(1000),
  decided_by BIGINT REFERENCES users(id),
  decided_at TIMESTAMPTZ,
  CONSTRAINT uq_customer_request_key UNIQUE (customer_id, request_key),
  CONSTRAINT ck_decision_consistency CHECK (
    (status = 'SUBMITTED' AND decided_by IS NULL AND decided_at IS NULL AND decision_note IS NULL)
    OR (status IN ('APPROVED','REJECTED') AND decided_by IS NOT NULL AND decided_at IS NOT NULL)
  ),
  CONSTRAINT ck_reject_reason CHECK (
    status <> 'REJECTED' OR (decision_note IS NOT NULL AND length(btrim(decision_note)) > 0)
  )
);
