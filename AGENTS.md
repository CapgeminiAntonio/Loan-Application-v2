# AGENTS.md — Loan Application System

You are a coding agent building a small loan-application system:

- **Frontend:** Angular (standalone components, typed reactive forms, `HttpClient`)
- **Backend:** Java 21, Spring Boot 3.x, Spring MVC, Spring Security (server-side sessions)
- **Database:** PostgreSQL 16, schema managed by Flyway

Customers submit loan applications and track them. Loan officers review the pending queue and approve or reject.

This file is the source of truth for **scope, contracts, and conventions**. Before you write code for a task, read the whole section for that task **and** the shared sections (§1–§5). If you must change a contract (an endpoint, a DTO, a column, an error code), update this file, `docs/api.md`, and `docs/field-dictionary.md` in the same change.

---

## 0. How to work

1. Follow the task order in §6. **T-07 comes first.** Everyone else builds on its schema.
2. Keep each task in its own commit or PR. Start the message with the task ID, for example `T-04: idempotent loan submission`.
3. A task is done only when **every** item in its completion checklist is covered by an automated test or a documented manual check in `docs/scenarios.md`.
4. Never weaken a server-side rule because the UI already enforces it. The server is the authority.
5. Never store plaintext passwords, real personal data, or secrets in the repo.
6. Keep `README.md` correct. If a command, port, profile, or seed user changes, update the README in the same change.
7. Run the full test suites before you finish a task (see README → *Running tests*).

---

## 1. Repository layout

```
/
├── AGENTS.md
├── README.md
├── docker-compose.yml            # PostgreSQL 16 for local dev
├── docs/
│   ├── api.md                    # request/response examples for every endpoint
│   ├── field-dictionary.md       # every column/field, type, constraint, meaning
│   └── scenarios.md              # seed scenarios, reset steps, concurrency demos
├── scripts/
│   ├── reset-db.sh               # drop + recreate + migrate + seed
│   └── scenarios/                # optional SQL scenario overlays (see T-08)
├── backend/
│   ├── mvnw, pom.xml
│   └── src/
│       ├── main/java/com/example/loans/
│       │   ├── LoansApplication.java
│       │   ├── config/           # SecurityConfig, JacksonConfig, CsrfCookieFilter
│       │   ├── auth/             # AuthController, CurrentUser, UserDetailsService impl
│       │   ├── user/             # UserRepository, User record
│       │   ├── application/      # loan application domain
│       │   │   ├── customer/     # CustomerApplicationController/Service + DTOs
│       │   │   ├── officer/      # OfficerApplicationController/Service + DTOs
│       │   │   ├── LoanApplicationRepository.java
│       │   │   └── model/        # enums, records
│       │   └── common/error/     # ApiError, GlobalExceptionHandler, exceptions
│       ├── main/resources/
│       │   ├── application.yml
│       │   ├── application-dev.yml
│       │   ├── db/migration/     # V1__schema.sql, V2__indexes.sql, ...
│       │   └── db/seed/          # R__seed_demo_data.sql (dev profile only)
│       └── test/java/...         # Testcontainers integration tests
└── frontend/
    ├── package.json, angular.json, proxy.conf.json
    └── src/app/
        ├── core/                 # auth service, guards, interceptors, api error model
        ├── customer/             # application form, list, detail
        ├── officer/              # queue, review/decision
        ├── shared/               # status badge, money pipe, error/empty/loading components
        └── app.routes.ts
```

Package names are suggestions. Keep the customer/officer split.

---

## 2. Domain model and rules (shared by every task)

### 2.1 Roles
`CUSTOMER`, `OFFICER`. Each user has exactly one role. Users are **seeded only**; there is no sign-up.

### 2.2 Application status lifecycle
```
SUBMITTED ──(officer approves)──▶ APPROVED
    │
    └─────(officer rejects)────▶ REJECTED
```
`APPROVED` and `REJECTED` are final. An application leaves `SUBMITTED` **exactly once**.

### 2.3 Loan fields and validation (enforce in DB, server, and UI)

| Field | Type (Java / SQL / JSON) | Rule |
|---|---|---|
| `amount` | `BigDecimal` / `NUMERIC(12,2)` / string `"12500.00"` | Required. Between 1,000.00 and 50,000.00. At most 2 decimal places. |
| `termMonths` | `int` / `SMALLINT` / number | Required. One of `12, 24, 36, 48, 60`. |
| `purpose` | enum / `VARCHAR(30)` + CHECK / string | Required. One of `HOME_IMPROVEMENT, DEBT_CONSOLIDATION, VEHICLE, EDUCATION, MEDICAL, OTHER`. |
| `employmentStatus` | enum / `VARCHAR(20)` + CHECK / string | Required. One of `EMPLOYED, SELF_EMPLOYED, UNEMPLOYED, RETIRED, STUDENT`. |
| `monthlyIncome` | `BigDecimal` / `NUMERIC(12,2)` / string | Required. Greater than 0 and at most 1,000,000.00. At most 2 decimal places. |

The limits above are the agreed defaults. Define them in **one** place per layer: a backend `LoanRules` constants class, the frontend `loan-rules.ts`, and the DB CHECK constraints. Keep all three in sync.

**Money rules**
- Use `BigDecimal` for money in Java. Never use `double` or `float`. Normalize with `setScale(2)`. A value with more than 2 decimal places is a validation error; do not round it.
- JSON responses serialize money as **strings** with 2 decimals (`@JsonFormat(shape = STRING)` or a global serializer). Requests accept a string or a number.
- In Angular, keep money as a string in the form and the API models. Format it for display with a pipe. Do no floating-point arithmetic on money.

### 2.4 Decision rules
- `decision` is `APPROVED` or `REJECTED`. Nothing else is accepted.
- `note` is visible to the customer and holds at most 1,000 characters. It is **required and must not be blank** for `REJECTED`, and optional for `APPROVED`.
- The server sets `decidedBy` (the officer from the session) and `decidedAt` (server clock, UTC). The client never sends either.
- Status, note, officer, and timestamp are written **together in one statement**.

### 2.5 Reference numbers
The server generates a human-readable reference: `LA-` followed by a 6-digit zero-padded number from a DB sequence, for example `LA-000042`. It is unique (UNIQUE constraint) and never comes from the client.

### 2.6 Dates
Store dates as `TIMESTAMPTZ` and model them as `Instant` / `OffsetDateTime` in Java. JSON uses ISO-8601 UTC, for example `"2026-11-20T15:04:05Z"`. Angular displays them in the browser's locale.

---

## 3. API contract

Base path: `/api`. Everything is JSON. Authentication uses a server-side session cookie (`JSESSIONID`). The Angular dev server proxies `/api` to `http://localhost:8080`, so the browser sees a **same-origin** app and needs no CORS.

### 3.1 Endpoints

| Method | Path | Role | Task | Success |
|---|---|---|---|---|
| POST | `/api/auth/login` | public | T-04 | 200 `CurrentUser` |
| POST | `/api/auth/logout` | any authenticated | T-04 | 204 |
| GET | `/api/auth/me` | any authenticated | T-04 | 200 `CurrentUser` (401 if no session) |
| POST | `/api/customer/applications` | CUSTOMER | T-04 | 201 new, or 200 replay → `CustomerApplicationDetail` |
| GET | `/api/customer/applications` | CUSTOMER | T-05 | 200 `CustomerApplicationSummary[]` (newest first) |
| GET | `/api/customer/applications/{id}` | CUSTOMER (owner) | T-05 | 200 `CustomerApplicationDetail` |
| GET | `/api/officer/applications/pending` | OFFICER | T-05 | 200 `OfficerQueueItem[]` (oldest first) |
| GET | `/api/officer/applications/{id}` | OFFICER | T-05 | 200 `OfficerApplicationDetail` (any status) |
| POST | `/api/officer/applications/{id}/decision` | OFFICER | T-06 | 200 `OfficerApplicationDetail` |

### 3.2 DTOs

```jsonc
// CurrentUser
{ "id": 1, "username": "alice", "fullName": "Alice Customer", "role": "CUSTOMER" }

// LoanApplicationRequest (POST /api/customer/applications)
// Header: Idempotency-Key: <UUID v4>   (required)
{ "amount": "12500.00", "termMonths": 36, "purpose": "VEHICLE",
  "employmentStatus": "EMPLOYED", "monthlyIncome": "4200.00" }

// CustomerApplicationSummary
{ "id": 17, "reference": "LA-000017", "amount": "12500.00", "termMonths": 36,
  "submittedAt": "2026-11-20T15:04:05Z", "status": "SUBMITTED" }

// CustomerApplicationDetail  (summary fields plus the following)
{ ..., "purpose": "VEHICLE", "employmentStatus": "EMPLOYED", "monthlyIncome": "4200.00",
  "decisionNote": null, "decidedAt": null }

// OfficerQueueItem
{ "id": 17, "reference": "LA-000017", "applicantName": "Alice Customer",
  "amount": "12500.00", "termMonths": 36, "purpose": "VEHICLE",
  "submittedAt": "2026-11-20T15:04:05Z" }

// OfficerApplicationDetail  (CustomerApplicationDetail fields plus the following)
{ ..., "applicant": { "id": 1, "fullName": "Alice Customer", "username": "alice" },
  "decidedBy": null /* or { "id": 4, "fullName": "Olivia Officer" } */ }

// DecisionRequest
{ "decision": "REJECTED", "note": "Monthly income does not support the requested amount." }
```

Customer DTOs **never** include another user's data or the deciding officer's identity.

### 3.3 Error format (every non-2xx response)

```json
{
  "timestamp": "2026-11-20T15:04:05Z",
  "status": 400,
  "code": "VALIDATION_FAILED",
  "message": "One or more fields are invalid.",
  "path": "/api/customer/applications",
  "fieldErrors": [ { "field": "amount", "message": "Amount must be between 1,000.00 and 50,000.00." } ]
}
```

`fieldErrors` is always present; it is an empty array when there are none. Use `field` names that match the JSON property names exactly, so Angular can map each error onto its form control.

| HTTP | `code` | When |
|---|---|---|
| 400 | `VALIDATION_FAILED` | Bean validation or business validation fails, including a blank rejection reason |
| 400 | `MALFORMED_REQUEST` | Unparseable JSON, unknown enum value, or a missing or invalid `Idempotency-Key` |
| 401 | `UNAUTHENTICATED` | No session, or a bad login |
| 403 | `FORBIDDEN` | Wrong role, or a missing or invalid CSRF token |
| 404 | `NOT_FOUND` | Application does not exist, **or belongs to another customer** (do not reveal existence) |
| 409 | `IDEMPOTENCY_KEY_REUSED` | Same customer and key, but a different payload |
| 409 | `ALREADY_DECIDED` | Decision attempted on an application that is no longer `SUBMITTED` |
| 503 | `SERVICE_UNAVAILABLE` | DB unreachable (map `DataAccessResourceFailureException` etc.) |
| 500 | `INTERNAL_ERROR` | Anything else; never leak stack traces |

Spring Security's own 401 and 403 responses must use this same JSON body. Use a custom `AuthenticationEntryPoint` and `AccessDeniedHandler`; do not use the default HTML or redirect responses.

### 3.4 Sessions and CSRF
- Use Spring Security with server-side `HttpSession` and BCrypt password hashes.
- The custom JSON login endpoint authenticates with `AuthenticationManager`, protects against session fixation by changing the session ID, and **explicitly saves** the `SecurityContext` through `HttpSessionSecurityContextRepository`. Spring Security 6 does not do this automatically for custom endpoints.
- Logout invalidates the session and clears the cookie.
- CSRF stays **enabled**. Set up the cookie-to-header pattern for single-page apps:
  - `CookieCsrfTokenRepository.withHttpOnlyFalse()` with cookie `XSRF-TOKEN`.
  - Use `CsrfTokenRequestAttributeHandler` (plain, not XOR) so the raw cookie value is accepted from the header.
  - Add a small `CsrfCookieFilter` that calls `csrfToken.getToken()` so the cookie is issued on every response, including `GET /api/auth/me`.
  - `POST /api/auth/login` may be CSRF-exempt. Every other mutating endpoint is protected.
  - Angular: `provideHttpClient(withXsrfConfiguration({ cookieName: 'XSRF-TOKEN', headerName: 'X-XSRF-TOKEN' }))`.
  - After login and logout the token rotates. The frontend calls `GET /api/auth/me` right after login to pick up the fresh cookie.
- URL authorization:
  - `/api/auth/login` permitAll
  - `/api/customer/**` hasRole CUSTOMER
  - `/api/officer/**` hasRole OFFICER
  - everything else under `/api/**` authenticated
- Every service method that reads or writes customer data takes the **current user ID from the session** (`@AuthenticationPrincipal`). It never takes it from a path variable, query parameter, or body.

### 3.5 Idempotent submission (T-04, with T-07)
- The client sends the `Idempotency-Key: <uuid>` header. It is required; if it is missing or not a UUID, return 400 `MALFORMED_REQUEST`.
- The server computes a `request_hash`: SHA-256 hex of the canonical payload `amount|termMonths|purpose|employmentStatus|monthlyIncome`, with money normalized to scale 2 using `toPlainString()`.
- Insert with:
  ```sql
  INSERT INTO loan_applications (...) VALUES (...)
  ON CONFLICT (customer_id, request_key) DO NOTHING
  RETURNING id;
  ```
  - If a row comes back: **201 Created**, with a `Location` header and the detail body.
  - If no row comes back: `SELECT` the existing row by `(customer_id, request_key)`.
    - If the hash matches: **200 OK**, with the original detail body and the header `Idempotent-Replayed: true`.
    - If the hash differs: **409 `IDEMPOTENCY_KEY_REUSED`**.
- This pattern is safe under concurrency. PostgreSQL makes the second insert wait for the first transaction, then skip, and the following `SELECT` in READ COMMITTED sees the committed row. **Do not** use catch-`DataIntegrityViolationException`-then-select inside the same transaction: PostgreSQL aborts the transaction after a constraint error.

### 3.6 Atomic decision (T-06, with T-09)
```sql
UPDATE loan_applications
   SET status = :status, decision_note = :note, decided_by = :officerId, decided_at = :now
 WHERE id = :id AND status = 'SUBMITTED';
```
- 1 row updated → success. Re-read and return the detail.
- 0 rows updated → if the ID does not exist, **404**; otherwise **409 `ALREADY_DECIDED`**. Never overwrite.
- Do not "read the status, then update" without the `WHERE status = 'SUBMITTED'` guard.

---

## 4. Database schema (T-07 owns it; everyone codes against it)

`V1__schema.sql`, in outline. The agent writes the final SQL and keeps this shape:

```sql
CREATE TABLE users (
  id             BIGSERIAL PRIMARY KEY,
  username       VARCHAR(50)  NOT NULL UNIQUE,
  password_hash  VARCHAR(100) NOT NULL,
  full_name      VARCHAR(100) NOT NULL,
  role           VARCHAR(20)  NOT NULL CHECK (role IN ('CUSTOMER','OFFICER')),
  created_at     TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE SEQUENCE loan_application_ref_seq;

CREATE TABLE loan_applications (
  id                 BIGSERIAL PRIMARY KEY,
  reference          VARCHAR(20)   NOT NULL UNIQUE,
  customer_id        BIGINT        NOT NULL REFERENCES users(id),
  amount             NUMERIC(12,2) NOT NULL CHECK (amount BETWEEN 1000.00 AND 50000.00),
  term_months        SMALLINT      NOT NULL CHECK (term_months IN (12,24,36,48,60)),
  purpose            VARCHAR(30)   NOT NULL CHECK (purpose IN ('HOME_IMPROVEMENT','DEBT_CONSOLIDATION','VEHICLE','EDUCATION','MEDICAL','OTHER')),
  employment_status  VARCHAR(20)   NOT NULL CHECK (employment_status IN ('EMPLOYED','SELF_EMPLOYED','UNEMPLOYED','RETIRED','STUDENT')),
  monthly_income     NUMERIC(12,2) NOT NULL CHECK (monthly_income > 0 AND monthly_income <= 1000000.00),
  status             VARCHAR(20)   NOT NULL DEFAULT 'SUBMITTED' CHECK (status IN ('SUBMITTED','APPROVED','REJECTED')),
  submitted_at       TIMESTAMPTZ   NOT NULL DEFAULT now(),
  request_key        UUID          NOT NULL,
  request_hash       CHAR(64)      NOT NULL,
  decision_note      VARCHAR(1000),
  decided_by         BIGINT        REFERENCES users(id),
  decided_at         TIMESTAMPTZ,
  CONSTRAINT uq_customer_request_key UNIQUE (customer_id, request_key),
  CONSTRAINT ck_decision_consistency CHECK (
    (status = 'SUBMITTED' AND decided_by IS NULL AND decided_at IS NULL AND decision_note IS NULL)
    OR (status IN ('APPROVED','REJECTED') AND decided_by IS NOT NULL AND decided_at IS NOT NULL)
  ),
  CONSTRAINT ck_reject_reason CHECK (
    status <> 'REJECTED' OR (decision_note IS NOT NULL AND length(btrim(decision_note)) > 0)
  )
);
```

**`V2__indexes.sql` (T-08)**
```sql
CREATE INDEX ix_loan_app_customer_history ON loan_applications (customer_id, submitted_at DESC, id DESC);
CREATE INDEX ix_loan_app_pending_queue    ON loan_applications (submitted_at, id) WHERE status = 'SUBMITTED';
```

**Role rules the DB cannot express:** `customer_id` must point to a CUSTOMER and `decided_by` to an OFFICER. The service layer enforces both, and integration tests cover them.

**Migrations are immutable once merged.** Fix problems with a new `V<n>__...sql`.

**Seed data:** `db/seed/R__seed_demo_data.sql` is a repeatable Flyway migration. It loads **only** in the `dev` profile (`spring.flyway.locations=classpath:db/migration,classpath:db/seed`), so tests and production never get demo data unless they ask for it.

All demo users share the password **`Password123!`**. Use this pre-computed BCrypt hash, and add a unit test that checks `BCryptPasswordEncoder.matches("Password123!", hash)`:

```
$2a$10$s8h7RhdVu9vACi4Ge5O6u.v859fHCmhha/F2x7gYDDQ32HjaBKawq
```

| username | role | full name | seeded applications |
|---|---|---|---|
| `alice` | CUSTOMER | Alice Customer | 1× SUBMITTED, 1× APPROVED (with note), 1× REJECTED (with reason) |
| `bob` | CUSTOMER | Bob Borrower | 2× SUBMITTED (older than alice's, to test ordering) |
| `carol` | CUSTOMER | Carol Newcomer | none (empty-list scenario) |
| `olivia` | OFFICER | Olivia Officer | is the `decided_by` on alice's decided applications |
| `oscar` | OFFICER | Oscar Officer | none |

All names are fictional. Give seeded rows fixed `submitted_at` values, and include two pending rows with the **same** `submitted_at` to prove the ID tie-breaker. Seeded `request_key` values are fixed UUIDs. Advance `loan_application_ref_seq` past the seeded references with `setval`.

---

## 5. Engineering conventions

### Backend
- Spring Boot 3.x on Java 21, built with the Maven wrapper.
- Dependencies: `spring-boot-starter-web`, `-security`, `-validation`, `-jdbc`, `flyway-core`, `flyway-database-postgresql`, `postgresql`. Tests use `spring-boot-starter-test`, `spring-security-test`, and `testcontainers` (postgresql and junit-jupiter).
- Data access uses `NamedParameterJdbcTemplate` with explicit SQL. This keeps `ON CONFLICT`, the conditional `UPDATE`, and the queue ordering visible and reviewable. Do not add JPA.
- Layers: Controller (HTTP, DTO mapping, `@Valid`) → Service (rules, `@Transactional`, current-user scoping) → Repository (SQL only). Controllers never call repositories directly.
- Validate with Bean Validation on request DTOs (`@NotNull`, `@DecimalMin`, `@DecimalMax`, `@Digits(integer=10, fraction=2)`, a custom `@AllowedTerm`) and repeat the business rules in the service, such as the rejection reason requirement.
- One `@RestControllerAdvice` produces the §3.3 error body for every exception type.
- Use Java `record`s for DTOs and enums for status, role, purpose, employment status, and decision.
- Inject `java.time.Clock` so tests can control timestamps.
- Write integration tests against a real PostgreSQL through Testcontainers. Do not use H2: `ON CONFLICT`, partial indexes, and CHECK behavior must be real.
- Log at INFO for submissions and decisions (IDs and references only, no personal data).

### Frontend
- Use the current stable Angular with standalone components, `provideRouter`, `provideHttpClient(withInterceptors(...), withXsrfConfiguration(...))`, and typed reactive forms.
- `proxy.conf.json` maps `/api` → `http://localhost:8080`. All HTTP calls use relative URLs (`/api/...`).
- `core/auth.service.ts` holds the current user (a signal or `BehaviorSubject`). On startup, an app initializer calls `GET /api/auth/me`.
- Guards: `authGuard` (redirects to `/login`) and `roleGuard('CUSTOMER' | 'OFFICER')`. If the role is wrong, redirect to that role's home.
- An error interceptor maps responses to a typed `ApiError`. On 401 (except from `/api/auth/me`) it clears the user and redirects to `/login`.
- Customers and officers get **separate layouts and navigation**. Neither sees the other's menu items.
- Every data view handles **loading, empty, error/unavailable (with Retry), and success** states. Put shared components in `shared/`.
- Money inputs use `type="text" inputmode="decimal"` with a regex validator `^\d+(\.\d{1,2})?$`. Do not use `type="number"`.
- Every interactive element is accessible: it has a label, error messages are linked with `aria-describedby`, and focus moves to the first invalid field when a submit is blocked.
- Unit tests use the Angular testing utilities with `HttpTestingController`.

### Routes
| Path | Role | Component |
|---|---|---|
| `/login` | public | LoginComponent |
| `/customer/applications` | CUSTOMER | ApplicationListComponent (customer home) |
| `/customer/applications/new` | CUSTOMER | ApplicationFormComponent |
| `/customer/applications/:id` | CUSTOMER | ApplicationDetailComponent |
| `/officer/queue` | OFFICER | PendingQueueComponent (officer home) |
| `/officer/applications/:id` | OFFICER | ReviewComponent |

---

## 6. Task order

```
Day 1:  T-07 (schema + seed)  ──▶  T-04 (session + submission)
                              ├──▶ T-08 (read queries + indexes) ──▶ T-05 (read APIs)
                              └──▶ T-09 (atomic update)          ──▶ T-06 (decision API)
Then:   T-01 (form) after T-04 · T-02 (customer views) after T-05 · T-03 (officer UI) after T-05 + T-06
```

Frontend work may start earlier against the contracts in §3, but a frontend task is **complete** only once it is integrated with the real API and seed data.

---

## 7. Tasks

### T-07 · US-01 — Schema, migrations, and seed data
**Stack:** PostgreSQL / Java · **Do this first.**

**Goal:** Create the shared data foundation early on day one, so every task builds on the same model.

**Implementation steps**
1. Create `docker-compose.yml` with `postgres:16` (database `loans`, user `loans`, password `loans`, port `5432`, named volume `loans-db-data`).
2. Write `V1__schema.sql` exactly as in §4: the `users` and `loan_applications` tables, primary and foreign keys, role and status CHECKs, and `NUMERIC(12,2)` money columns.
3. Add the allowed-term, amount-range, positive-income, and NOT NULL constraints, plus the decision-consistency and rejection-reason CHECKs.
4. Add the `UNIQUE (customer_id, request_key)` constraint and agree with T-04 on the `ON CONFLICT` handling (§3.5).
5. Write `R__seed_demo_data.sql` with the fictional users and applications from §4. Store BCrypt hashes only.
6. Write `scripts/reset-db.sh`. It runs `docker compose down -v && docker compose up -d db`, waits for readiness with `pg_isready`, and prints the next step: start the backend with the `dev` profile so Flyway migrates and seeds.
7. Write `docs/field-dictionary.md`, covering every column with its type, nullability, constraint, JSON name, and meaning.

**Deliverables**
- A versioned migration and fictional seed and reset scripts.
- A shared field dictionary and database startup instructions in the README.

**Completion checklist**
- [ ] A fresh database can be initialized by following the README alone. Verify on a clean volume.
- [ ] Keys and constraints prevent invalid core data. Add a test per constraint: a bad term, an amount out of range, income ≤ 0, an unknown status, a REJECTED row with a blank note, a decided row without `decided_by`, and a duplicate `(customer_id, request_key)`.
- [ ] The schema is merged and announced before other tasks build on it.

---

### T-04 · US-01 — Session login and submission API
**Stack:** Java Spring MVC

**Goal:** Build the login and session foundation on the seeded users, and the customer loan submission endpoint. The server enforces validation and duplicate prevention.

**Implementation steps**
1. Write `SecurityConfig` per §3.4: a JSON login, logout, and `me` endpoint; JSON 401 and 403 handlers; CSRF in the SPA cookie pattern; and role-based URL rules.
2. Write a `UserDetailsService` backed by `users`, and a `CurrentUser` principal exposing `id`, `username`, `fullName`, and `role`.
3. Write `POST /api/customer/applications`:
   - Validate the DTO (§2.3). Money is `BigDecimal`; reject values with more than 2 decimal places instead of rounding.
   - Take `customer_id` from the session principal and **ignore** any client-supplied owner fields.
   - Generate `reference` from the sequence and set `submitted_at` from `Clock` and `status = SUBMITTED`.
   - Apply the idempotency algorithm from §3.5 (201 / 200 replay / 409).
4. Document every endpoint in `docs/api.md` with request and response examples, covering success, validation failure (with `fieldErrors`), 401, 403, replay, and key conflict.

**Deliverables**
- Session endpoints, access-control support, and the submission controller and service.
- Documented request and response examples and field and error behavior.

**Completion checklist**
- [ ] Unauthenticated submission → 401. Submission as an officer → 403. Tested with MockMvc and a real session.
- [ ] The server rejects invalid requests even when browser validation is bypassed. Test a raw POST for each invalid field, a 3-decimal amount, a bad enum, and a missing key.
- [ ] Retries create one record: the same key and payload sent twice → one row, 201 then 200. **Concurrent** requests with the same key (two threads released by a `CountDownLatch`, against Testcontainers) → exactly one row, and both responses carry the same `id`.
- [ ] The same key with a changed payload → 409 `IDEMPOTENCY_KEY_REUSED`, and the original row is unchanged.
- [ ] Login → `me` → submit → logout works with CSRF enabled.

---

### T-08 · US-02, US-03 — Read repositories, indexes, and scenarios
**Stack:** PostgreSQL / Java

**Goal:** Write the repository queries behind customer tracking and the officer's pending queue, and share the method contracts with T-05.

**Implementation steps**
1. Write these `LoanApplicationRepository` methods, with signatures agreed with T-05:
   - `List<ApplicationRow> findByCustomer(long customerId)` — `WHERE customer_id = :customerId ORDER BY submitted_at DESC, id DESC`
   - `Optional<ApplicationRow> findByIdAndCustomer(long id, long customerId)` — the ownership check is **in the SQL**
   - `List<QueueRow> findPendingQueue()` — `WHERE status = 'SUBMITTED' ORDER BY submitted_at ASC, id ASC`, joined to `users` for the applicant name
   - `Optional<OfficerDetailRow> findDetailForOfficer(long id)` — joined to the applicant and (left-joined) to the deciding officer
2. Add `V2__indexes.sql` (§4) and confirm with `EXPLAIN` that the queue query can use the partial index. Paste the plan into `docs/scenarios.md`.
3. Write the seed scenarios: multiple customers, a customer without applications (`carol`), pending, approved, and rejected examples, and two pending rows with equal `submitted_at`.
4. Add the **empty pending queue** scenario as `scripts/scenarios/empty-queue.sql`. It decides every SUBMITTED row as `olivia`, in a way that is safe to rerun. Document how to apply it and how to reset (`scripts/reset-db.sh`).

**Deliverables**
- Repository methods, queries, and supporting indexes.
- Repeatable data scenarios for UI and API integration, documented in `docs/scenarios.md`.

**Completion checklist**
- [ ] Customer query methods cannot return another customer's application. Test `findByIdAndCustomer(bobsAppId, aliceId)` → empty.
- [ ] The pending queue is filtered (no APPROVED or REJECTED rows) and ordered by `submitted_at`, then `id`. The tie case is tested.
- [ ] Scenario setup and reset steps are documented and work from a clean volume.

---

### T-05 · US-02, US-03 — Customer and officer read APIs
**Stack:** Java Spring MVC

**Goal:** Expose the customer list and detail endpoints and the officer queue and detail endpoints, using T-08's queries. The server performs every role and ownership check.

**Implementation steps**
1. `GET /api/customer/applications` → the current customer's summaries, newest first. An empty list is `200 []`, never 404.
2. `GET /api/customer/applications/{id}` → `findByIdAndCustomer(id, currentUserId)`. A missing **or foreign** ID → 404 `NOT_FOUND`, with the same response either way.
3. `GET /api/officer/applications/pending` → SUBMITTED only, oldest first, with the ID tie-breaker and `applicantName`. Empty → `200 []`.
4. `GET /api/officer/applications/{id}` → the full detail with the applicant and decision information (any status).
5. Agree with the Angular tasks on the empty-list, 404, date, and error formats (§3.3). Add example payloads to `docs/api.md` for pending, approved, rejected, empty, not-found, and unavailable (503).

**Deliverables**
- Customer and officer read controllers, services, and DTOs.
- Example payloads for the pending, approved, rejected, empty, and unavailable results.

**Completion checklist**
- [ ] Changing an application ID in the URL cannot expose another customer's record (alice → bob's ID → 404).
- [ ] Customers calling `/api/officer/**` → 403. Officers calling `/api/customer/**` → 403.
- [ ] The officer queue excludes decided requests and uses stable oldest-first ordering.
- [ ] Customer DTOs never contain `decidedBy` or another user's data.

---

### T-09 · US-04 — Atomic decision persistence
**Stack:** PostgreSQL / Java

**Goal:** Provide the repository operation that moves an application out of SUBMITTED exactly once, including when officers act concurrently.

**Implementation steps**
1. Write `int decide(long id, Decision status, String note, long officerId, Instant decidedAt)` using the conditional `UPDATE` in §3.6.
2. Write status, note, officer, and timestamp in **one statement**, inside the caller's transaction.
3. Return the affected row count, or a `DecisionOutcome` enum (`UPDATED`, `NOT_FOUND`, `ALREADY_DECIDED`) worked out with a follow-up `SELECT EXISTS` when the count is 0. Agree on which one with T-06.
4. The DB constraints from T-07 (`ck_decision_consistency`, `ck_reject_reason`) are the last line of defense. Verify they reject inconsistent writes.
5. Document a manual demo in `docs/scenarios.md`: two `psql` sessions, `BEGIN` in both, run the UPDATE in A, run the UPDATE in B (B blocks), `COMMIT` A, and B reports `UPDATE 0`.

**Deliverables**
- The atomic decision repository method and the agreed service contract.
- A documented success and conflict integration scenario.

**Completion checklist**
- [ ] Of two competing decisions, one wins and the earlier decision is preserved. Test with two threads and a latch: one gets `UPDATED`, the other `ALREADY_DECIDED`, and the row holds the winner's values.
- [ ] Rejected decisions store a nonblank reason, and all decision fields are consistent (CHECK constraint tests).
- [ ] Decided applications no longer appear in `findPendingQueue()`.

---

### T-06 · US-04 — Decision API and business validation
**Stack:** Java Spring MVC

**Goal:** Write the officer decision endpoint. It validates the decision, calls the atomic repository update, and turns an already-decided application into a conflict response.

**Implementation steps**
1. `POST /api/officer/applications/{id}/decision` with a `DecisionRequest`.
2. Accept only `APPROVED` or `REJECTED`; anything else → 400. A `REJECTED` decision with a null or blank `note` → 400 `VALIDATION_FAILED` with `fieldErrors[{field:"note"}]`. Trim the note, and store `null` for a blank approval note.
3. Take the officer from the session, and the timestamp from the injected `Clock`.
4. Call T-09's `decide(...)` inside an `@Transactional` service method. On `UPDATED`, return 200 with the fresh `OfficerApplicationDetail`; on `NOT_FOUND`, return 404; on `ALREADY_DECIDED`, return 409 `ALREADY_DECIDED` with the message *"This application has already been decided."* Never overwrite.
5. Document the success, invalid-decision, blank-reason, 401, 403, 404, and 409 responses in `docs/api.md`.

**Deliverables**
- The officer decision controller, service, and validation.
- Documented success, invalid-decision, unauthorized, and conflict responses.

**Completion checklist**
- [ ] Only officers can decide (customer → 403, anonymous → 401). Blank rejection reasons are rejected.
- [ ] Status, note, officer, and time are persisted together. Verify them by reading the row back.
- [ ] Competing decisions through the HTTP layer produce one 200 and one 409.

---

### T-01 · US-01 — Loan application form
**Stack:** Angular · **Depends on T-04.**

**Goal:** Build the customer application form and connect it to the submission API. Keep the entered data on failure, so the customer can correct the request or retry it.

**Implementation steps**
1. Write `ApplicationFormComponent` at `/customer/applications/new`, with inputs for amount, term (a select limited to the allowed values), purpose (select), employment status (select), and monthly income.
2. Add validators for required, range, and 2-decimal format, using the shared `loan-rules.ts`. Show a clear message under each field once it is touched or a submit is attempted.
3. Write `LoanApplicationService.submit(payload, idempotencyKey)`, which sends the `Idempotency-Key` header.
4. Manage the idempotency key:
   - Generate a key with `crypto.randomUUID()` on the first submit attempt, and store it together with a snapshot of the payload.
   - On **retry with an unchanged payload** (after a network error, timeout, or 5xx), **reuse the same key**.
   - If the user **edits the form** after a failure, discard the old key; the next submit generates a new one.
   - On success, clear the key. "Submit another application" resets the form and the key.
5. Disable the submit button and show a spinner while the request is pending, to block double clicks.
6. On success (201 **or** 200 replay), show a confirmation with the **reference** and the status **SUBMITTED**, plus a link to the detail page.
7. On failure, **keep every input**:
   - 400 → map each `fieldErrors[]` entry onto its form control (a `server` error key) and show the message beside the field.
   - 0, 5xx, or 503 → show a banner ("We couldn't submit your application. Your details are saved — please try again.") with a **Retry** button that reuses the key.
   - 409 `IDEMPOTENCY_KEY_REUSED` → generate a new key and ask the user to submit again.
   - 401 → the interceptor redirects to login.

**Deliverables**
- A working Angular form and submission service.
- Submission integrated with the real API and seed data.

**Completion checklist**
- [ ] Invalid inputs cannot be submitted, and server field errors appear beside their fields. Test by stubbing a 400 response.
- [ ] A successful request shows its reference and SUBMITTED status.
- [ ] Retrying a failed request keeps the inputs and does not create a second application. Unit test: two calls carry the same header value. Manual check: stop the backend, submit, restart it, retry, and see one row.

---

### T-02 · US-02 — Customer application list and details
**Stack:** Angular · **Depends on T-05.**

**Goal:** Give a customer a read-only view of their applications and decisions, served by the real customer APIs.

**Implementation steps**
1. Write `ApplicationListComponent` (customer home), showing reference, amount, term, submission date, and status badge. Each row links to its detail page.
2. Write `ApplicationDetailComponent`, showing every submitted field read-only, plus the decision note and decision date when they exist. For SUBMITTED applications show "Awaiting review".
3. Handle these states: loading (skeleton or spinner); empty ("You haven't applied yet" with a link to the form); unavailable or error ("We couldn't load your applications" with **Retry**); and 404 detail ("Application not found" with a back link).
4. Fetch fresh data every time the list route activates, so new decisions appear when the customer returns. The default route reuse already does this. Also add a manual **Refresh** button.

**Deliverables**
- The customer list and detail routes and HTTP service methods.
- Read-only submitted details and a visible decision outcome.

**Completion checklist**
- [ ] Only the signed-in customer's records are shown. Log in as alice, then as bob, and compare against the seed.
- [ ] Pending, approved, and rejected examples display correctly (alice's seed data).
- [ ] An empty list (carol) and a failed or unavailable detail page are easy to understand.

---

### T-03 · US-03, US-04 — Officer queue and decision screens
**Stack:** Angular · **Depends on T-05 and T-06.**

**Goal:** Build the officer's pending queue, review screen, and approve and reject controls, with navigation kept separate from the customer's.

**Implementation steps**
1. Write `PendingQueueComponent` (officer home), showing the queue oldest first in server order (do **not** re-sort on the client): reference, applicant, amount, term, purpose, and submitted date. Each row opens the review page.
2. Write `ReviewComponent`, showing the applicant and every loan field, plus the status. If the application is already decided, show the decision and hide the controls.
3. Decision controls: **Approve** and **Reject** buttons and a "Note to customer" textarea (at most 1,000 characters, with a counter).
   - Reject requires a nonblank note. Block the submit and explain why: "A reason is required when rejecting."
   - Disable both buttons while the request is saving.
4. On success, show a toast ("Application LA-000017 approved") and navigate back to the queue, which reloads.
5. On **409 `ALREADY_DECIDED`**, show "Another officer has already decided this application." with a **Back to queue** button that reloads the queue.
6. Handle these states: empty queue ("No applications waiting for review"), loading, and error with Retry.
7. Give the officer layout its own navigation (Queue, Logout). Officers never see customer links, and the reverse.

**Deliverables**
- The officer queue, detail, and decision UI connected to the real APIs.
- Clear validation, successful-decision, empty-queue, and conflict states.

**Completion checklist**
- [ ] Only pending requests appear, and every required review field is visible.
- [ ] Rejecting without a reason is prevented and clearly explained, and the server's 400 is also handled.
- [ ] A completed decision removes the item from the queue. A conflict prompts a refresh. Manual check: open the same application as olivia and oscar in two browsers, and decide in both.

---

## 8. Final acceptance (run before you call the project done)

1. `./scripts/reset-db.sh` → start the backend (dev) → start the frontend. Everything comes up using only the README.
2. Backend tests pass: `cd backend && ./mvnw verify` (Docker required for Testcontainers).
3. Frontend tests and build pass: `cd frontend && npm test -- --watch=false && npm run build`.
4. Manual end-to-end check: alice submits → olivia sees it at the correct place in the queue → olivia rejects it without a reason (blocked) → with a reason (success) → alice sees REJECTED and the reason.
5. `docs/api.md`, `docs/field-dictionary.md`, `docs/scenarios.md`, and `README.md` all match the code.
