CREATE INDEX ix_loan_app_customer_history
  ON loan_applications (customer_id, submitted_at DESC, id DESC);

CREATE INDEX ix_loan_app_pending_queue
  ON loan_applications (submitted_at, id)
  WHERE status = 'SUBMITTED';
