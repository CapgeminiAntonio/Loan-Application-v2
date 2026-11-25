---
name: spring-session-security
description: Use when implementing or debugging Spring Boot web authentication with Spring Security and server-side sessions, including JSON login/logout, session fixation protection, CSRF, role authorization, or JSON 401/403 responses. Especially relevant to session-based REST APIs such as this project's T-04.
user-invocable: false
disable-model-invocation: false
---

# Spring Session Security

Use this workflow for Spring Security session-based web APIs. For this repository, first read the root `AGENTS.md` sections 3.3–3.4 and the complete T-04 section; those contracts override generic guidance here.

## Workflow

1. Inspect the project's Spring Security version, existing security configuration, principal types, and authentication tests before changing code.
2. Keep authentication session-backed. For a custom JSON login, authenticate through the configured `AuthenticationManager`, protect against session fixation, and explicitly save the `SecurityContext` through the session-backed repository.
3. Keep CSRF enabled. Follow the application's cookie-to-header contract and ensure tokens are issued on safe requests where the client needs them. Exempt only the endpoint explicitly permitted by the API contract.
4. Apply URL authorization by role and keep 401 and 403 responses in the application's JSON error shape. Avoid default HTML, redirects, or success-shaped fallback responses.
5. Resolve user identity from the authenticated principal. Never trust an owner/officer ID supplied by the request.
6. Add or update HTTP tests for successful login/session persistence, `me`, logout, unauthenticated access, wrong-role access, CSRF acceptance/rejection, and the agreed JSON error body.

## Guardrails

- Do not replace sessions with JWTs or disable CSRF globally unless the project contract is deliberately changed.
- Do not assume a custom controller login persists authentication automatically; verify session context persistence.
- Do not use a broad exception handler to hide authentication/configuration errors.
- Keep security configuration consistent with the existing Spring version and project conventions.
