---
name: spring-integration-testing
description: Use when testing Spring Boot REST APIs, especially MockMvc authentication/session/CSRF behavior, Bean Validation and JSON errors, PostgreSQL integration, or concurrent idempotent submissions and decisions. Relevant to backend tasks T-04, T-05, and T-06.
user-invocable: false
disable-model-invocation: false
---

# Spring Integration Testing

Use this workflow to verify Spring API behavior beyond isolated unit tests. Follow the root `AGENTS.md` task checklist and test conventions; tests are part of task completion, not optional follow-up.

## Workflow

1. Inspect the Maven build, existing test layout, test dependencies, database setup, and test profiles. Add a dependency only when the required tests need it and it is absent.
2. Use MockMvc and Spring Security test support for HTTP status/body, authentication, session, role, CSRF, validation, and error-handler behavior.
3. Use the project's real PostgreSQL integration setup (Testcontainers where prescribed) for database constraints, `ON CONFLICT`, transaction behavior, ordering, and concurrency. Do not use H2 as a substitute for PostgreSQL semantics.
4. Make tests deterministic: control time through the injected `Clock`, isolate database state, use explicit synchronization for concurrency tests, and assert persisted state as well as responses.
5. Cover the task-specific cases:
   - **T-04:** unauthenticated and wrong-role submission; raw invalid requests; missing/bad idempotency key; exact replay and changed-payload conflict; concurrent same-key submissions; login → `me` → submit → logout with CSRF.
   - **T-05:** customer ownership (including foreign ID indistinguishable from absent), role restrictions, empty-list responses, pending-only filtering, and stable ordering/tie-breaks.
   - **T-06:** decision validation and blank rejection reason, persisted decision fields, missing/already-decided responses, and competing HTTP decisions yielding one success and one conflict.
6. Run the smallest relevant test selector while iterating, then run the full backend verification command required by the task before reporting completion. State clearly what passed, failed, or could not run (for example, Docker unavailable).

## Quality bar

- Assert the exact public response contract, not just a successful status.
- Avoid sleeps for concurrency coordination; use latches/barriers and bounded waits.
- Do not make tests pass by weakening production validation, security, database constraints, or assertions.
- Document any required manual scenario that cannot be automated, following the repository's `docs/scenarios.md` conventions.
