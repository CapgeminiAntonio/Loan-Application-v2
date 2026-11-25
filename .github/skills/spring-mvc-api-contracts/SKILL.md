---
name: spring-mvc-api-contracts
description: Use when designing or implementing Spring MVC REST endpoints and their DTOs, validation, service boundaries, ownership/role checks, transaction rules, status codes, and JSON error mapping. Relevant to customer/officer application APIs such as T-04, T-05, and T-06.
user-invocable: false
disable-model-invocation: false
---

# Spring MVC API Contracts

Use this workflow when adding or changing Spring MVC endpoints. In this repository, read the root `AGENTS.md` shared sections and the full applicable task section first; its API and domain contracts are authoritative.

## Workflow

1. Inspect existing controllers, services, repositories, DTOs, exception handling, and related tests. Follow local naming and package patterns.
2. Keep responsibilities separated: controllers map HTTP and DTOs, services enforce business rules and current-user scope, repositories perform SQL. Controllers must not call repositories directly.
3. Model request/response DTOs with the project's established types and validation. Preserve exact JSON property names, response statuses, and the common error envelope, including field-error names.
4. Take identity from the authenticated session principal. Enforce role checks on the server. Perform customer ownership checks in the repository query; return the same `NOT_FOUND` response for absent and foreign records.
5. Keep money as `BigDecimal`; reject excess scale rather than rounding. Use the injected `Clock` for server timestamps.
6. Preserve task-specific persistence semantics:
   - **T-04 submission:** validate the idempotency key and payload, canonicalize and hash the request, use PostgreSQL `INSERT ... ON CONFLICT DO NOTHING RETURNING`, then read the existing row for replay/conflict. Do not recover from a uniqueness exception and query in the same aborted transaction.
   - **T-05 reads:** use the existing read-query repository methods, return empty lists as `200 []`, and do not expose another customer's data or officer identity in customer DTOs.
   - **T-06 decision:** validate `APPROVED`/`REJECTED` and rejection notes, take the officer and time from trusted server context, and call the existing atomic decision repository operation. Do not implement read-then-unconditional-update.
7. Update API documentation and tests with any endpoint behavior. If a contract must change, update all source-of-truth documents required by the root instructions.

## Review checklist

- Required and invalid inputs produce the contracted 400 response and field errors.
- Authentication, role, ownership, not-found, conflict, and empty-list semantics are explicit and tested.
- No client-supplied identity or decision timestamp is trusted.
- No silent fallback, broad catch, or raw exception/stack trace leaks through the API.
- Persistence behavior remains consistent with the existing database schema and repository contracts.
