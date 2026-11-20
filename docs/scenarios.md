# Data Scenarios

## Seed scenarios
- Alice: one SUBMITTED, one APPROVED, one REJECTED.
- Bob: two SUBMITTED applications with the same submitted timestamp (`2026-11-16T12:00:00Z`) to verify ID tie-breaking.
- Carol: no applications.
- Olivia: deciding officer for Alice's decided applications.
- Oscar: officer with no applications.

Password for every demo user: `Password123!`.

## Reset
Drop and recreate the `loans` database in pgAdmin, or run `./scripts/reset-db.sh` using local PostgreSQL command-line tools. Start the backend with the `dev` profile to apply migrations and load seed data.

## Empty queue
Apply `scripts/scenarios/empty-queue.sql` in pgAdmin. It decides only SUBMITTED rows and is rerunnable. Reset the database in pgAdmin or with `scripts/reset-db.sh` for seed state.

## Index verification
In pgAdmin run:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM loan_applications
WHERE status = 'SUBMITTED'
ORDER BY submitted_at, id;
```

The plan should use `ix_loan_app_pending_queue` or a backward/forward partial-index scan for a populated queue. In a tiny test database PostgreSQL may choose a sequential scan; `SET enable_seqscan = off` can be used for a forced plan check.

## Concurrency decision demo
1. Open two pgAdmin Query Tools and begin transactions.
2. Session A updates the target with status APPROVED.
3. Session B runs the same conditional update for REJECTED; it blocks while A is uncommitted.
4. Commit A. B should report `UPDATE 0` and its transaction should then read that the status is already decided.
