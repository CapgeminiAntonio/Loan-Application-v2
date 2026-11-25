# Backend Agent Instructions

These instructions apply to work under `backend/`. The repository-root `AGENTS.md` remains authoritative and applies in addition to this file; do not move or modify it as part of backend work.

## Before implementation

- Read the root `AGENTS.md` shared sections (§1–§5) and the complete task section for the work being done.
- Follow the API, domain, error, and database contracts in the root file. If a contract must change, update the root `AGENTS.md`, `docs/api.md`, and `docs/field-dictionary.md` as required there.
- Apply the relevant automatically loadable skills from `.github/skills/`. Do not require the user to invoke skills manually:
  - T-04: `spring-session-security`, `spring-mvc-api-contracts`, `spring-integration-testing`
  - T-05: `spring-mvc-api-contracts`, `spring-integration-testing`
  - T-06: `spring-mvc-api-contracts`, `spring-integration-testing`

## Scope and existing database foundation

The Spring/API implementation scope is T-04, T-05, and T-06:

- **T-04:** session authentication and security, customer submission API, validation, and idempotent application-level submission behavior.
- **T-05:** customer and officer read APIs, including owner scoping and role enforcement.
- **T-06:** officer decision API and business validation.

For this task setup, T-07, T-08, and T-09 are assumed complete. Reuse and verify their existing schema, migrations, indexes, seed data, read-query repository methods, and atomic decision operation. Do not redo database-foundation work. If a required foundation is missing or demonstrably incorrect, report the blocker instead of silently expanding scope.

T-04's submission insert/replay path is still part of the application feature: implement it against the existing schema and preserve the root contract's PostgreSQL `ON CONFLICT` algorithm. Do not confuse this with redoing T-07/T-08/T-09.

## Implementation rules

- Keep the existing Java 21, Spring Boot, Spring MVC, Spring Security, and `NamedParameterJdbcTemplate` patterns. Do not add JPA.
- Keep layers clear: controllers handle HTTP and DTO mapping; services enforce business rules, current-user scoping, and transactions; repositories contain SQL.
- Take customer and officer identities from the authenticated session principal, never from request data.
- Preserve `BigDecimal` money handling, scale validation without rounding, injected `Clock`, the exact JSON error contract, and required status codes.
- Keep customer DTOs free of other customers' data and officer identity. A missing or foreign customer application must have the same 404 response.
- For decisions, use the existing atomic repository operation; never replace it with a read-then-unconditional-update flow.
- Keep INFO logs free of personal data. Do not weaken server-side validation because the UI also validates.

## Tests and documentation

- Complete every task checklist with automated tests or the documented manual scenario required by the root `AGENTS.md`.
- Use MockMvc for HTTP, session, role, CSRF, validation, and error-contract behavior. Use real PostgreSQL through Testcontainers where database semantics or concurrency are under test; do not substitute H2.
- Inspect the current Maven test dependencies before relying on them. Add only dependencies required to satisfy the task's tests when they are absent.
- Update `docs/api.md` for endpoint behavior and examples. Update `docs/scenarios.md` for required manual/concurrency checks, and keep `README.md` correct when commands or startup behavior change.
- Run the backend verification command required by the root instructions before declaring a backend task done, and report any Docker/Testcontainers limitation explicitly.

The agent/skill configuration itself does not implement T-04, T-05, or T-06. It prepares future backend work to complete those tasks against the existing database foundation.
